// Real streak + Mon–Sun week row, computed from the signed-in user's own deed history (the same
// `deeds` rows AppState already loads with `.eq('user_id', uid)` — no extra query, nobody else's
// data). Pure functions on plain dates so they're unit-testable without Supabase or a clock.
//
// Rules:
// - A day "counts" when it has at least one approved or pending deed. Rejected deeds don't count
//   (otherwise a rejected submission would still keep a streak alive).
// - Days are the phone's local calendar days.
// - The streak runs back from today; if nothing is done yet today, it runs back from yesterday,
//   so a live streak doesn't show as 0 all morning just because today's deed isn't in yet.

DateTime dateOnly(DateTime t) {
  final l = t.toLocal();
  return DateTime(l.year, l.month, l.day);
}

// Calendar-safe day step (DateTime(y, m, d - 1) rolls over months/years correctly).
DateTime _addDays(DateTime day, int n) => DateTime(day.year, day.month, day.day + n);

/// Local calendar days with at least one counted (approved or pending) deed.
Set<DateTime> activeDeedDays(Iterable<({DateTime createdAt, String status})> deeds) {
  return {
    for (final d in deeds)
      if (d.status != 'rejected') dateOnly(d.createdAt),
  };
}

/// Consecutive active days ending today — or ending yesterday when today has nothing yet.
int currentStreak(Set<DateTime> activeDays, DateTime now) {
  final today = dateOnly(now);
  var day = activeDays.contains(today) ? today : _addDays(today, -1);
  var streak = 0;
  while (activeDays.contains(day)) {
    streak++;
    day = _addDays(day, -1);
  }
  return streak;
}

/// Monday..Sunday of the week containing [now].
List<DateTime> currentWeekDays(DateTime now) {
  final today = dateOnly(now);
  final monday = _addDays(today, -(today.weekday - DateTime.monday));
  return [for (var i = 0; i < 7; i++) _addDays(monday, i)];
}

/// Whole days since the most recent active day before today (null if there is none).
int? daysSinceLastActive(Set<DateTime> activeDays, DateTime now) {
  final today = dateOnly(now);
  DateTime? last;
  for (final d in activeDays) {
    if (d.isBefore(today) && (last == null || d.isAfter(last))) last = d;
  }
  if (last == null) return null;
  return (today.difference(last).inHours / 24).round(); // round() absorbs any DST hour
}
