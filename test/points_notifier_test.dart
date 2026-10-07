import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:acha_karo/utils/points_notifier.dart';

// "Points credited" phone notifications: fire on cold start, no flood on first run, summary for
// more than 2, deed display names (never raw keys), marker cleared on sign-out.

Map<String, dynamic> row(String id, String at, {String type = 'taskActioned', String title = 'Deed approved', String body = 'Your litter submission was approved — +15 points.', bool read = false}) =>
    {'id': id, 'type': type, 'title': title, 'body': body, 'created_at': at, 'read': read};

void main() {
  final t0 = DateTime.utc(2026, 10, 7, 10);

  test('first run for an account: nothing fires, marker set to the newest row', () {
    final plan = planPhoneNotifications([row('1', '2026-10-01T10:00:00Z'), row('2', '2026-10-05T10:00:00Z')], null);
    expect(plan.show, isEmpty);
    expect(plan.marker, DateTime.utc(2026, 10, 5, 10));
  });

  test('cold start after an approval: fires with the deed name and points, marker advances', () {
    final plan = planPhoneNotifications([row('1', '2026-10-07T11:00:00Z')], t0);
    expect(plan.show.single.title, 'Acha kaam approved! 🎉');
    expect(plan.show.single.body, 'Clear litter: +15 points credited.');
    expect(plan.show.single.body, isNot(contains('litter submission')));
    expect(plan.marker, DateTime.utc(2026, 10, 7, 11));
    // Same rows again (resume): nothing new.
    expect(planPhoneNotifications([row('1', '2026-10-07T11:00:00Z')], plan.marker).show, isEmpty);
  });

  test('already-read and older rows never fire', () {
    final plan = planPhoneNotifications([row('1', '2026-10-07T09:00:00Z'), row('2', '2026-10-07T11:00:00Z', read: true)], t0);
    expect(plan.show, isEmpty);
  });

  test('more than 2 new rows: one summary with the total points', () {
    final plan = planPhoneNotifications([
      row('1', '2026-10-07T11:00:00Z'),
      row('2', '2026-10-07T11:01:00Z', body: 'Your litter submission was approved — +15 points.'),
      row('3', '2026-10-07T11:02:00Z', body: 'Your litter submission was approved — +30 points.'),
    ], t0);
    expect(plan.show, hasLength(1));
    expect(plan.show.single.body, '3 acha kaam approved, +60 points credited.');
  });

  test('summary mentions other updates; two rows still fire separately', () {
    final mixed = planPhoneNotifications([
      row('1', '2026-10-07T11:00:00Z'),
      row('2', '2026-10-07T11:01:00Z'),
      row('3', '2026-10-07T11:02:00Z', title: 'Deed rejected', body: 'Your litter submission was rejected.'),
    ], t0);
    expect(mixed.show.single.body, '2 acha kaam approved, +30 points credited. 1 more update(s) in the app.');
    final two = planPhoneNotifications([row('1', '2026-10-07T11:00:00Z'), row('2', '2026-10-07T11:01:00Z')], t0);
    expect(two.show, hasLength(2));
  });

  test('rejected stays neutral, with the deed name instead of the key; feedback gets a friendly title', () {
    final plan = planPhoneNotifications([
      row('1', '2026-10-07T11:00:00Z', title: 'Deed rejected', body: 'Your litter submission was rejected.'),
      row('2', '2026-10-07T11:01:00Z', type: 'feedback', title: 'Feedback response', body: 'Thanks, fixed!'),
    ], t0);
    expect(plan.show[0].title, 'Deed rejected');
    expect(plan.show[0].body, 'Your Clear litter submission was rejected.');
    expect(plan.show[1].title, 'Your feedback got a reply 💬');
    expect(plan.show[1].body, 'Thanks, fixed!');
  });

  test('process(): marker per account in prefs; first run quiet, then fires; clearAll on sign-out', () async {
    SharedPreferences.setMockInitialValues({});
    final rows = [row('1', '2026-10-07T11:00:00Z')];
    expect(await PointsNotifier.process('u1', rows), isEmpty); // first run
    final later = [...rows, row('2', '2026-10-07T12:00:00Z')];
    expect(await PointsNotifier.process('u1', later), hasLength(1));
    expect(await PointsNotifier.process('u1', later), isEmpty);
    expect(await PointsNotifier.process('u2', later), isEmpty, reason: 'another account starts quiet too');

    await PointsNotifier.clearAll();
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getKeys().where((k) => k.startsWith('ak_notif_marker_')), isEmpty);
    expect(await PointsNotifier.process('u1', later), isEmpty, reason: 'after sign-out it is a first run again: no flood');
  });
}
