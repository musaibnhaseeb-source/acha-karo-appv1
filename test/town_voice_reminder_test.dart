import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:acha_karo/data/remote_config.dart';
import 'package:acha_karo/utils/town_voice_reminder.dart';

// Town Voice "Notify me": 30 min before town_voice_starts_at, follows admin time changes,
// cancelled when off / no time / past / sign-out, its own notification id, local-time labels.

class FakeScheduler implements ReminderScheduler {
  bool isAllowed = true;
  bool grantOnRequest = true;
  int requests = 0;
  final Map<int, (DateTime, String)> scheduled = {};
  @override
  Future<bool> allowed() async => isAllowed;
  @override
  Future<bool> requestPermission() async {
    requests++;
    isAllowed = grantOnRequest;
    return isAllowed;
  }

  @override
  Future<void> schedule(int id, DateTime atUtc, String title, String body) async => scheduled[id] = (atUtc, body);
  @override
  Future<void> cancel(int id) async => scheduled.remove(id);
}

TownVoiceConfig tv({bool active = true, DateTime? startsAt}) =>
    TownVoiceConfig(streamUrl: '', dayLabel: 'Saturday', timeLabel: '7 pm', durationLabel: '15 min', active: active, startsAt: startsAt);

void main() {
  final now = DateTime.utc(2026, 10, 7, 12);
  final start = DateTime.utc(2026, 10, 10, 14, 0);
  late FakeScheduler fake;

  setUp(() {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    SharedPreferences.setMockInitialValues({});
    fake = FakeScheduler();
    TownVoiceReminder.scheduler = fake;
  });
  tearDown(() => debugDefaultTargetPlatformOverride = null);

  test('fire time: 30 min before; at the start if closer than that; none if off / unset / past', () {
    expect(TownVoiceReminder.fireTime(active: true, startsAt: start, now: now), DateTime.utc(2026, 10, 10, 13, 30));
    expect(TownVoiceReminder.fireTime(active: true, startsAt: start, now: DateTime.utc(2026, 10, 10, 13, 50)), start);
    expect(TownVoiceReminder.fireTime(active: false, startsAt: start, now: now), isNull);
    expect(TownVoiceReminder.fireTime(active: true, startsAt: null, now: now), isNull);
    expect(TownVoiceReminder.fireTime(active: true, startsAt: start, now: start.add(const Duration(minutes: 1))), isNull);
  });

  test('opt in schedules it; an admin time change moves it', () async {
    expect(await TownVoiceReminder.optIn(uid: 'u1', tv: tv(startsAt: start.add(const Duration(days: 365)))), isTrue);
    final later = start.add(const Duration(days: 400));
    await TownVoiceReminder.sync(uid: 'u1', tv: tv(startsAt: later), now: now);
    expect(fake.scheduled[TownVoiceReminder.notificationId]!.$1, later.subtract(const Duration(minutes: 30)));
    expect(fake.scheduled[TownVoiceReminder.notificationId]!.$2, TownVoiceReminderCopy.body);
  });

  test('cancelled when Town Voice is off, the time is removed, or it has passed', () async {
    await TownVoiceReminder.optIn(uid: 'u1', tv: tv(startsAt: start));
    for (final config in [tv(active: false, startsAt: start), tv(startsAt: null)]) {
      await TownVoiceReminder.sync(uid: 'u1', tv: tv(startsAt: start), now: now);
      expect(fake.scheduled, isNotEmpty);
      await TownVoiceReminder.sync(uid: 'u1', tv: config, now: now);
      expect(fake.scheduled, isEmpty);
    }
    await TownVoiceReminder.sync(uid: 'u1', tv: tv(startsAt: start), now: start.add(const Duration(hours: 1)));
    expect(fake.scheduled, isEmpty);
  });

  test('not opted in: nothing scheduled; another account does not inherit the opt-in', () async {
    await TownVoiceReminder.sync(uid: 'u1', tv: tv(startsAt: start), now: now);
    expect(fake.scheduled, isEmpty);
    await TownVoiceReminder.optIn(uid: 'u1', tv: tv(startsAt: start));
    await TownVoiceReminder.sync(uid: 'u2', tv: tv(startsAt: start), now: now);
    expect(fake.scheduled, isEmpty);
  });

  test('permission is asked only on the button, and a "no" saves nothing', () async {
    fake.isAllowed = false;
    fake.grantOnRequest = false;
    await TownVoiceReminder.sync(uid: 'u1', tv: tv(startsAt: start), now: now);
    expect(fake.requests, 0, reason: 'config loads never prompt');
    expect(await TownVoiceReminder.optIn(uid: 'u1', tv: tv(startsAt: start)), isFalse);
    expect(fake.requests, 1);
    expect(await TownVoiceReminder.isOptedIn('u1'), isFalse);
  });

  test('sign-out cancels it and forgets the opt-in', () async {
    await TownVoiceReminder.optIn(uid: 'u1', tv: tv(startsAt: start));
    await TownVoiceReminder.sync(uid: 'u1', tv: tv(startsAt: start), now: now);
    expect(fake.scheduled, isNotEmpty);
    await TownVoiceReminder.signOut();
    expect(fake.scheduled, isEmpty);
    expect(await TownVoiceReminder.isOptedIn('u1'), isFalse);
  });

  test("its id never clashes with the daily reminder's (7300–7309)", () {
    expect(TownVoiceReminder.notificationId, isNot(inInclusiveRange(7300, 7309)));
  });

  test('labels are the UTC start time converted to this phone\'s local time', () {
    final (day, time) = TownVoiceReminder.localLabels(start);
    final l = start.toLocal();
    final h12 = l.hour % 12 == 0 ? 12 : l.hour % 12;
    expect(time, '$h12:${l.minute.toString().padLeft(2, '0')} ${l.hour < 12 ? 'am' : 'pm'}');
    expect(day, contains('${l.day} Oct'));
    // A UTC instant and the same instant written with an offset give the same labels.
    expect(TownVoiceReminder.localLabels(DateTime.parse('2026-10-10T19:00:00+05:00')), (day, time));
  });
}
