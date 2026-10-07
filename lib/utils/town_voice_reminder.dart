import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform, TargetPlatform, visibleForTesting;
import 'package:flutter/material.dart' show TimeOfDay;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz;
import '../data/remote_config.dart';
import 'notifications.dart';
import 'daily_reminder.dart';

// Town Voice "🔔 Notify me": one local notification 30 minutes before the session starts
// (app_config.town_voice_starts_at, UTC), or at the start time itself if it's closer than that.
// - Opt-in is per account (SharedPreferences), asked in context on the button — never at cold start.
// - Every config load re-syncs it: an admin time change moves it; Town Voice off, no start time,
//   or a start time already passed cancels it. Sign-out cancels it and forgets the opt-in.
// - Once scheduled it fires with no internet (it's on the phone). Reading the time needs internet.
// Same local-notification setup as the daily reminder (exact alarms not needed: inexact is fine
// for a 30-minute heads-up). Fixed id 7400, away from the daily reminder's 7300–7309.

class TownVoiceReminderCopy {
  static const title = 'Town Voice shuru hone wala hai 🎙️';
  static const body = '30 minute mein live. Aa jao!';
  // Proposed (not in the brief): when it's set less than 30 minutes before the start, it fires at
  // the start itself, so "30 minute mein" would be wrong.
  static const bodyAtStart = 'Town Voice ab live hai. Aa jao!';
  static const set = '🔔 Reminder set';
  static const cancelHint = 'Tap to cancel';
  static const notify = '🔔 Notify me';
  static const setSnack = "Reminder set — we'll ping you 30 minutes before.";
  static const cancelledSnack = 'Reminder cancelled.';
  static const permissionOffSnack = 'Notifications are off for Acha Karo. Turn them on in phone settings to get the reminder.';
}

// The notification calls, swappable in tests.
abstract class ReminderScheduler {
  Future<bool> allowed();
  Future<bool> requestPermission();
  Future<void> schedule(int id, DateTime atUtc, String title, String body);
  Future<void> cancel(int id);
}

class _PluginScheduler implements ReminderScheduler {
  @override
  Future<bool> allowed() => notificationsAllowed();
  @override
  Future<bool> requestPermission() => requestNotificationPermission();
  @override
  Future<void> schedule(int id, DateTime atUtc, String title, String body) async {
    await initNotifications();
    await notificationsPlugin.zonedSchedule(
      id,
      title,
      body,
      tz.TZDateTime.from(atUtc, tz.UTC),
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'acha_karo_channel',
          'Acha Karo Notifications',
          channelDescription: 'Deed approvals, feedback responses, and other updates',
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  @override
  Future<void> cancel(int id) async {
    await initNotifications();
    await notificationsPlugin.cancel(id);
  }
}

class TownVoiceReminder {
  static const int notificationId = 7400; // daily reminder: 7300–7309
  static const Duration lead = Duration(minutes: 30);
  static const _optInPrefix = 'ak_tv_reminder_';

  @visibleForTesting
  static ReminderScheduler scheduler = _PluginScheduler();

  static bool get supported => !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  // When to fire (UTC), or null = nothing should be scheduled. Pure; tested.
  static DateTime? fireTime({required bool active, required DateTime? startsAt, required DateTime now}) {
    if (!active || startsAt == null) return null;
    final start = startsAt.toUtc();
    final n = now.toUtc();
    if (!start.isAfter(n)) return null; // already started / over
    final early = start.subtract(lead);
    return early.isAfter(n) ? early : start;
  }

  // Whether the button shows at all: Town Voice on and a start time still ahead.
  static bool canRemind(TownVoiceConfig tv, {DateTime? now}) => fireTime(active: tv.active, startsAt: tv.startsAt, now: now ?? DateTime.now()) != null;

  // Date/time labels in the phone's own time zone, e.g. ("Sat, 12 Oct", "7:30 pm").
  static (String, String) localLabels(DateTime startsAtUtc) {
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final l = startsAtUtc.toLocal();
    return ('${days[l.weekday - 1]}, ${l.day} ${months[l.month - 1]}', DailyReminder.formatTime(TimeOfDay(hour: l.hour, minute: l.minute)));
  }

  static Future<SharedPreferences?> _prefs() async {
    try {
      return await SharedPreferences.getInstance();
    } catch (_) {
      return null;
    }
  }

  static Future<bool> isOptedIn(String uid) async => (await _prefs())?.getBool('$_optInPrefix$uid') ?? false;

  // On every config load (and after opting in): schedule for the current start time, or cancel.
  static Future<void> sync({required String? uid, required TownVoiceConfig tv, DateTime? now}) async {
    if (!supported || uid == null) return; // no account yet (cold start before session): leave as is
    try {
      final at = fireTime(active: tv.active, startsAt: tv.startsAt, now: now ?? DateTime.now());
      await scheduler.cancel(notificationId);
      if (at == null || !await isOptedIn(uid) || !await scheduler.allowed()) return;
      final atStart = at.isAtSameMomentAs(tv.startsAt!.toUtc());
      await scheduler.schedule(notificationId, at, TownVoiceReminderCopy.title, atStart ? TownVoiceReminderCopy.bodyAtStart : TownVoiceReminderCopy.body);
    } catch (_) {
      // A reminder is a nicety — never let scheduling affect the app.
    }
  }

  // "Notify me" tapped: asks for notification permission here, in context, if needed.
  // Returns false if notifications aren't allowed (nothing is saved then).
  static Future<bool> optIn({required String uid, required TownVoiceConfig tv}) async {
    if (!supported) return false;
    final allowed = await scheduler.allowed() || await scheduler.requestPermission();
    if (!allowed) return false;
    await (await _prefs())?.setBool('$_optInPrefix$uid', true);
    await sync(uid: uid, tv: tv);
    return true;
  }

  static Future<void> optOut(String uid) async {
    await (await _prefs())?.remove('$_optInPrefix$uid');
    try {
      await scheduler.cancel(notificationId);
    } catch (_) {}
  }

  // Sign-out: cancel and forget every opt-in on this phone.
  static Future<void> signOut() async {
    try {
      await scheduler.cancel(notificationId);
    } catch (_) {}
    final prefs = await _prefs();
    if (prefs == null) return;
    for (final k in prefs.getKeys().where((k) => k.startsWith(_optInPrefix)).toList()) {
      await prefs.remove(k);
    }
  }
}
