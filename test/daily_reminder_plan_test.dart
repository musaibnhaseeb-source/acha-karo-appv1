import 'package:flutter/material.dart' show TimeOfDay;
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

  group('chosen reminder time', () {
    test('every reminder lands at the chosen local time, same back-off', () {
      final p = DailyReminder.plan(now: morning, loggedToday: false, startMessage: 0, hour: 7, minute: 15);
      for (final (at, _) in p) {
        expect((at.hour, at.minute), (7, 15));
      }
      // 7:15 am already passed at 9:00 → starts tomorrow; back-off spacing unchanged.
      expect(p.first.$1, DateTime(2026, 9, 25, 7, 15));
      expect(p.map((e) => e.$1.difference(p.first.$1).inDays).toList(), [0, 1, 2, 4, 6, 8, 10, 17, 24, 31]);
    });

    test('a later time today is still used today', () {
      expect(DailyReminder.plan(now: morning, loggedToday: false, startMessage: 0, hour: 22, minute: 45).first.$1, DateTime(2026, 9, 24, 22, 45));
      expect(DailyReminder.plan(now: morning, loggedToday: true, startMessage: 0, hour: 22, minute: 45).first.$1, DateTime(2026, 9, 25, 22, 45));
    });

    test('default stays 8:30 pm; formatting', () {
      expect(DailyReminder.defaultTime, const TimeOfDay(hour: 20, minute: 30));
      expect(DailyReminder.formatTime(const TimeOfDay(hour: 20, minute: 30)), '8:30 pm');
      expect(DailyReminder.formatTime(const TimeOfDay(hour: 0, minute: 5)), '12:05 am');
      expect(DailyReminder.formatTime(const TimeOfDay(hour: 12, minute: 0)), '12:00 pm');
    });
  });
}
