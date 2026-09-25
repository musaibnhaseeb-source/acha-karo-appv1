import 'package:flutter_test/flutter_test.dart';
import 'package:acha_karo/utils/deed_streak.dart';
import 'package:acha_karo/widgets/guddi_home.dart';
import 'package:acha_karo/data/guddi_content.dart';
import 'package:acha_karo/utils/daily_reminder.dart';

// Real streak + week row (from the user's own deed history) and Guddi's Home mood selection.

({DateTime createdAt, String status}) deed(DateTime at, [String status = 'approved']) => (createdAt: at, status: status);

void main() {
  final thu = DateTime(2026, 9, 24, 10); // a Thursday

  group('streak', () {
    test('counts consecutive days ending today', () {
      final days = activeDeedDays([deed(DateTime(2026, 9, 22, 9)), deed(DateTime(2026, 9, 23, 20)), deed(DateTime(2026, 9, 24, 8))]);
      expect(currentStreak(days, thu), 3);
    });

    test('still alive (from yesterday) when nothing done yet today', () {
      final days = activeDeedDays([deed(DateTime(2026, 9, 22, 9)), deed(DateTime(2026, 9, 23, 20))]);
      expect(currentStreak(days, thu), 2);
    });

    test('broken by a gap day', () {
      final days = activeDeedDays([deed(DateTime(2026, 9, 21, 9)), deed(DateTime(2026, 9, 24, 8))]);
      expect(currentStreak(days, thu), 1);
      expect(currentStreak(activeDeedDays([deed(DateTime(2026, 9, 21))]), thu), 0);
    });

    test('pending counts, rejected does not', () {
      final days = activeDeedDays([deed(DateTime(2026, 9, 23, 9), 'pending'), deed(DateTime(2026, 9, 24, 8), 'rejected')]);
      expect(days.contains(DateTime(2026, 9, 24)), isFalse);
      expect(currentStreak(days, thu), 1);
    });

    test('several deeds on one day count once; crosses month boundaries', () {
      final days = activeDeedDays([
        deed(DateTime(2026, 8, 31, 9)), deed(DateTime(2026, 9, 1, 9)), deed(DateTime(2026, 9, 1, 18)),
      ]);
      expect(currentStreak(days, DateTime(2026, 9, 1, 20)), 2);
    });

    test('no history = 0', () => expect(currentStreak({}, thu), 0));
  });

  test('week is Monday..Sunday of the current week', () {
    final w = currentWeekDays(thu);
    expect(w.first, DateTime(2026, 9, 21));
    expect(w.last, DateTime(2026, 9, 27));
    expect(currentWeekDays(DateTime(2026, 9, 21, 1)).first, DateTime(2026, 9, 21)); // Monday itself
    expect(currentWeekDays(DateTime(2026, 9, 27, 23)).first, DateTime(2026, 9, 21)); // Sunday
  });

  test('days since last active (before today)', () {
    final days = activeDeedDays([deed(DateTime(2026, 9, 20)), deed(DateTime(2026, 9, 24))]);
    expect(daysSinceLastActive(days, thu), 4);
    expect(daysSinceLastActive({}, thu), isNull);
  });

  group('Guddi mood', () {
    GuddiHomeMood mood(int hour, {bool loaded = true, bool first = false, bool done = false, bool rejected = false, int streak = 0, int? since = 1}) =>
        pickGuddiHomeMood(
          now: DateTime(2026, 9, 24, hour),
          historyLoaded: loaded,
          needsFirstDeed: first,
          doneToday: done,
          rejectedTodayOnly: rejected,
          streak: streak,
          daysSinceLast: since,
        );

    test('no line until history has loaded', () {
      expect(mood(9, loaded: false).line, isNull);
      expect(mood(9, loaded: false).pool, GuddiPoses.happyPool);
    });
    test('morning / day / evening / night, nothing done', () {
      expect(mood(8).pool, GuddiPoses.happyPool);
      expect(mood(8).line, GuddiLines.morning);
      expect(mood(14).line, GuddiLines.day);
      expect(mood(19).line, GuddiLines.evening);
      expect(mood(19).night, isFalse);
      expect(mood(22).line, GuddiLines.evening);
      expect(mood(22).night, isTrue);
      expect(mood(2).pose, GuddiPoses.rest);
      expect(mood(2).line, GuddiLines.lateNight);
    });
    test('done today', () {
      expect(mood(10, done: true).pool, GuddiPoses.cheerPool);
      expect(mood(10, done: true, streak: 4).roman, contains('4 din'));
      expect(mood(22, done: true).pose, GuddiPoses.rest);
      expect(mood(22, done: true).line, GuddiLines.doneNight);
    });
    test('first deed, rejected, comeback, streak alive', () {
      expect(mood(10, first: true, since: null).line, GuddiLines.firstDeed);
      expect(mood(10, rejected: true).pose, GuddiPoses.frown);
      expect(mood(10, since: 5).pose, GuddiPoses.worried);
      expect(mood(10, streak: 3).roman, 'Lagatar 3 din! Aaj bhi acha kaam karein? 🔥');
    });
    test('copy rules: no religious framing, never log/likhein', () {
      final all = [
        GuddiLines.firstDeed, GuddiLines.morning, GuddiLines.day, GuddiLines.evening, GuddiLines.lateNight,
        GuddiLines.streakAlive, GuddiLines.comeback, GuddiLines.rejectedToday, GuddiLines.done, GuddiLines.doneStreak,
        GuddiLines.doneNight, GuddiCelebrationLines.strong, GuddiCelebrationLines.topTier, kPhotoTheDeedHint,
      ];
      final text = [for (final l in all) '${l.roman} ${l.en ?? ''}', for (final i in achaKaamIdeas) '${i.roman} ${i.en}'].join(' ').toLowerCase();
      for (final banned in ['neki', 'sawab', 'deen', 'likh', ' log ', 'log karein']) {
        expect(text.contains(banned), isFalse, reason: banned);
      }
    });
  });

  group('pose pools', () {
    test('moments where the emotion matters stay fixed', () {
      for (final pool in [
        pickGuddiHomeMood(now: DateTime(2026, 9, 24, 2), historyLoaded: true, needsFirstDeed: false, doneToday: false, rejectedTodayOnly: false, streak: 0, daysSinceLast: 1).pool,
        pickGuddiHomeMood(now: DateTime(2026, 9, 24, 10), historyLoaded: true, needsFirstDeed: false, doneToday: false, rejectedTodayOnly: true, streak: 0, daysSinceLast: 1).pool,
        pickGuddiHomeMood(now: DateTime(2026, 9, 24, 10), historyLoaded: true, needsFirstDeed: false, doneToday: false, rejectedTodayOnly: false, streak: 0, daysSinceLast: 6).pool,
      ]) {
        expect(pool.length, 1);
      }
    });

    test('stable for this app open (same offset → same pose), taps cycle the whole pool', () {
      for (final pool in [GuddiPoses.happyPool, GuddiPoses.cheerPool, GuddiPoses.ideaPool]) {
        expect(pickFromPool(pool), pickFromPool(pool));
        final seen = {for (var i = 0; i < pool.length; i++) pickFromPool(pool, offset: i)};
        expect(seen, pool.toSet());
        expect(pickFromPool(pool, offset: pool.length), pickFromPool(pool));
      }
    });

    test('pools only use the approved poses (no guddi_small, no excluded art)', () {
      final all = {...GuddiPoses.happyPool, ...GuddiPoses.cheerPool, ...GuddiPoses.ideaPool};
      expect(all.any((p) => p.contains('small')), isFalse);
      expect(all.contains(GuddiPoses.power), isFalse); // top tier only
      expect(all.contains(GuddiPoses.strong), isFalse); // milestones / tier-up only
    });
  });

  group('copy rules (Musa)', () {
    // Every user-facing string in guddi_content.dart + the daily reminder texts.
    final all = <String>[
      for (final l in [
        GuddiLines.firstDeed, GuddiLines.morning, GuddiLines.day, GuddiLines.evening, GuddiLines.lateNight,
        GuddiLines.streakAlive, GuddiLines.comeback, GuddiLines.rejectedToday, GuddiLines.done, GuddiLines.doneStreak,
        GuddiLines.doneNight, GuddiCelebrationLines.strong, GuddiCelebrationLines.topTier, kPhotoTheDeedHint,
      ]) ...[l.roman, if (l.en != null) l.en!],
      for (final i in achaKaamIdeas) ...[i.roman, i.en],
      for (final (en, ur) in DailyReminder.messages) ...[en, ur],
    ];

    test('never a bare "karein" / "کریں" — always "acha kaam karein"', () {
      final bareRoman = RegExp(r'(?<!acha kaam )karein', caseSensitive: false);
      final bareUrdu = RegExp(r'(?<!اچھا کام )کریں');
      for (final s in all) {
        expect(bareRoman.hasMatch(s), isFalse, reason: s);
        expect(bareUrdu.hasMatch(s), isFalse, reason: s);
      }
    });

    test('no "small" acha kaam (chhota / small / چھوٹا)', () {
      for (final s in all) {
        expect(RegExp(r'chhot|\bsmall\b|چھوٹ', caseSensitive: false).hasMatch(s), isFalse, reason: s);
      }
    });
  });

  test("today's idea is stable for a day, rotates daily, skips cooling-down deeds", () {
    final a = pickTodaysIdea(DateTime(2026, 9, 24), (_) => false);
    expect(pickTodaysIdea(DateTime(2026, 9, 24), (_) => false), same(a));
    expect(pickTodaysIdea(DateTime(2026, 9, 25), (_) => false), isNot(same(a)));
    expect(pickTodaysIdea(DateTime(2026, 9, 24), (t) => t == a.deedType).deedType, isNot(a.deedType));
  });
}
