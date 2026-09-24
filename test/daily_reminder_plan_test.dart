import 'package:flutter_test/flutter_test.dart';
import 'package:acha_karo/utils/daily_reminder.dart';

// The daily reminder's schedule planning: 8:30 pm local, skip today when a deed was already
// logged (or 8:30 pm has passed), back-off spacing (3 daily → every other day → weekly), and
// message rotation that never repeats on consecutive days.

void main() {
  final morning = DateTime(2026, 9, 24, 9, 0);
  final lateNight = DateTime(2026, 9, 24, 22, 0);

  test('every reminder is at 8:30 pm local', () {
    for (final (at, _) in DailyReminder.plan(now: morning, loggedToday: false, startMessage: 0)) {
      expect(at.hour, 20);
      expect(at.minute, 30);
    }
  });

  test('starts today when nothing logged yet and 8:30 pm is still ahead', () {
    final first = DailyReminder.plan(now: morning, loggedToday: false, startMessage: 0).first.$1;
    expect(first, DateTime(2026, 9, 24, 20, 30));
  });

  test("skips today once a deed was logged today", () {
    final first = DailyReminder.plan(now: morning, loggedToday: true, startMessage: 0).first.$1;
    expect(first, DateTime(2026, 9, 25, 20, 30));
  });

  test('skips today when 8:30 pm has already passed', () {
    final first = DailyReminder.plan(now: lateNight, loggedToday: false, startMessage: 0).first.$1;
    expect(first, DateTime(2026, 9, 25, 20, 30));
  });

  test('back-off: 3 daily, then every other day up to 7, then weekly', () {
    final days = DailyReminder.plan(now: morning, loggedToday: false, startMessage: 0).map((p) => p.$1.difference(DateTime(2026, 9, 24, 20, 30)).inDays).toList();
    expect(days, [0, 1, 2, 4, 6, 8, 10, 17, 24, 31]);
  });

  test('messages rotate and never repeat on consecutive reminders', () {
    for (var start = 0; start < DailyReminder.messages.length; start++) {
      final idx = DailyReminder.plan(now: morning, loggedToday: false, startMessage: start).map((p) => p.$2).toList();
      expect(idx.first, start);
      for (var i = 1; i < idx.length; i++) {
        expect(idx[i], isNot(idx[i - 1]));
      }
    }
  });

  test('rolls over month ends correctly', () {
    final first = DailyReminder.plan(now: DateTime(2026, 9, 30, 21, 0), loggedToday: false, startMessage: 0).first.$1;
    expect(first, DateTime(2026, 10, 1, 20, 30));
  });

  test('all 4 approved messages present, EN + UR, no streak line', () {
    expect(DailyReminder.messages.length, 4);
    for (final (en, ur) in DailyReminder.messages) {
      expect(en, isNotEmpty);
      expect(ur, isNotEmpty);
      expect(en.toLowerCase().contains('streak'), isFalse);
    }
  });
}
