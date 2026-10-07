import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:shared_preferences/shared_preferences.dart';
import '../data/deed_catalog.dart';

// "Points credited" phone notifications for rows in the notifications table (deed approved by a
// moderator, rejected, feedback answered). Fires on EVERY notifications load, cold start included
// — before, only ids that appeared during the same session ever fired, so a cold start (the usual
// case) showed nothing.
//
// A per-account marker (newest created_at already handled) lives in SharedPreferences:
// - first run of this version for an account (no marker): nothing fires, the marker is set to
//   the newest row — no flood of old history
// - after that: unread rows newer than the marker fire, then the marker moves forward
// - more than 2 at once: ONE summary instead
// - sign-out deletes the marker (clearAll)
// Uses the same local-notification setup as the daily reminder; never prompts for permission.
// Known limit: only runs while the app is opened/resumed (real push while closed = FCM, later).

class PhoneNotification {
  final String title;
  final String body;
  const PhoneNotification(this.title, this.body);
  @override
  String toString() => '$title | $body';
}

class PointsNotifierCopy {
  static const approvedTitle = 'Acha kaam approved! 🎉';
  static const approvedBody = '{deed}: +{x} points credited.';
  static const approvedBodyNoPoints = '{deed} approved.';
  static const summaryTitle = 'Acha kaam approved! 🎉';
  static const summaryBody = '{n} acha kaam approved, +{x} points credited.';
  static const summaryMore = ' {m} more update(s) in the app.';
  static const updatesTitle = 'Acha Karo';
  static const updatesBody = '{n} new updates in the app.';
  static const feedbackTitle = 'Your feedback got a reply 💬';
  static const deedFallbackName = 'Your acha kaam';
}

class _Row {
  final String type;
  final String title;
  final String body;
  final DateTime createdAt;
  final bool read;
  _Row(this.type, this.title, this.body, this.createdAt, this.read);
}

// Admin writes the raw deed key (e.g. "cleanStreet") into title/body. Swapped for its display name.
String _withDeedNames(String text) {
  var out = text;
  for (final e in deedCatalog.entries) {
    out = out.replaceAll(RegExp('\\b${RegExp.escape(e.key)}\\b'), e.value.name);
  }
  return out;
}

String? _deedName(String text) {
  for (final e in deedCatalog.entries) {
    if (RegExp('\\b${RegExp.escape(e.key)}\\b').hasMatch(text)) return e.value.name;
  }
  return null;
}

bool _isApproved(_Row r) => r.type == 'taskActioned' && '${r.title} ${r.body}'.toLowerCase().contains('approved') && !'${r.title} ${r.body}'.toLowerCase().contains('not approved');
int? _points(_Row r) {
  final m = RegExp(r'\+\s*(\d+)').firstMatch(r.body) ?? RegExp(r'\+\s*(\d+)').firstMatch(r.title);
  return m == null ? null : int.tryParse(m.group(1)!);
}

PhoneNotification approvedNotification({required String? deedName, required int? points}) {
  final name = deedName ?? PointsNotifierCopy.deedFallbackName;
  return PhoneNotification(
    PointsNotifierCopy.approvedTitle,
    points == null ? PointsNotifierCopy.approvedBodyNoPoints.replaceAll('{deed}', name) : PointsNotifierCopy.approvedBody.replaceAll('{deed}', name).replaceAll('{x}', '$points'),
  );
}

PhoneNotification _single(_Row r) {
  if (_isApproved(r)) return approvedNotification(deedName: _deedName('${r.title} ${r.body}'), points: _points(r));
  if (r.type == 'feedback') return PhoneNotification(PointsNotifierCopy.feedbackTitle, r.body);
  // Rejected and anything else: neutral, the row's own wording, with deed names readable.
  return PhoneNotification(_withDeedNames(r.title), _withDeedNames(r.body));
}

// Pure planning step (tested). rows: notifications rows (any order). marker: newest created_at
// already handled, or null on the first run. Returns what to show and the new marker.
({List<PhoneNotification> show, DateTime? marker}) planPhoneNotifications(List<Map<String, dynamic>> rows, DateTime? marker) {
  final parsed = <_Row>[];
  for (final r in rows) {
    final created = DateTime.tryParse(r['created_at'] as String? ?? '');
    if (created == null) continue;
    parsed.add(_Row(r['type'] as String? ?? '', r['title'] as String? ?? '', r['body'] as String? ?? '', created.toUtc(), r['read'] as bool? ?? false));
  }
  parsed.sort((a, b) => a.createdAt.compareTo(b.createdAt)); // oldest first
  final newest = parsed.isEmpty ? null : parsed.last.createdAt;
  if (marker == null) {
    // First run for this account on this version: remember where we are, show nothing.
    return (show: const [], marker: newest ?? DateTime.now().toUtc());
  }
  final fresh = parsed.where((r) => !r.read && r.createdAt.isAfter(marker)).toList();
  final nextMarker = newest != null && newest.isAfter(marker) ? newest : marker;
  if (fresh.isEmpty) return (show: const [], marker: nextMarker);
  if (fresh.length <= 2) return (show: fresh.map(_single).toList(), marker: nextMarker);

  final approved = fresh.where(_isApproved).toList();
  final others = fresh.length - approved.length;
  if (approved.isEmpty) {
    return (show: [PhoneNotification(PointsNotifierCopy.updatesTitle, PointsNotifierCopy.updatesBody.replaceAll('{n}', '${fresh.length}'))], marker: nextMarker);
  }
  final pts = approved.fold<int>(0, (sum, r) => sum + (_points(r) ?? 0));
  var body = PointsNotifierCopy.summaryBody.replaceAll('{n}', '${approved.length}').replaceAll('{x}', '$pts');
  if (others > 0) body += PointsNotifierCopy.summaryMore.replaceAll('{m}', '$others');
  return (show: [PhoneNotification(PointsNotifierCopy.summaryTitle, body)], marker: nextMarker);
}

class PointsNotifier {
  static const _prefix = 'ak_notif_marker_';

  // Reads this account's marker, plans, saves the new marker, returns what to show.
  static Future<List<PhoneNotification>> process(String uid, List<Map<String, dynamic>> rows) async {
    if (kIsWeb) return const []; // no phone notifications in the browser, so no marker either
    SharedPreferences prefs;
    try {
      prefs = await SharedPreferences.getInstance();
    } catch (_) {
      return const []; // no storage: show nothing rather than risk repeats
    }
    final saved = prefs.getString('$_prefix$uid');
    final plan = planPhoneNotifications(rows, saved == null ? null : DateTime.tryParse(saved));
    if (plan.marker != null) await prefs.setString('$_prefix$uid', plan.marker!.toUtc().toIso8601String());
    return plan.show;
  }

  // Sign-out: forget every account's marker on this phone.
  static Future<void> clearAll() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      for (final k in prefs.getKeys().where((k) => k.startsWith(_prefix)).toList()) {
        await prefs.remove(k);
      }
    } catch (_) {}
  }
}
