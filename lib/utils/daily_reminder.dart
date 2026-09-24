import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz;
import '../theme/app_theme.dart';
import 'notifications.dart';

// Daily Guddi reminder — LOCAL scheduled notifications only. No server, no push, no DB, no
// personal data: the only things stored are three on-device flags (asked / enabled / which
// message comes next / the chosen time). Android only; a no-op on web.
//
// Scheduling: instead of one repeating alarm, a batch of one-shot reminders is scheduled at the
// person's chosen time (default 8:30 pm), device-local, spaced out to back off when the app isn't being opened:
//   reminders 1–3 daily, 4–7 every other day, then weekly (about a month ahead in total).
// Every app open (and every deed) cancels and rebuilds the batch, which is what "resets" the
// back-off. Today's slot is skipped if a deed was already logged today. Inexact scheduling, so
// no exact-alarm permission; the manifest's boot receiver re-registers them after a restart.
class DailyReminder {
  static const _askedKey = 'ak_daily_reminder_asked';
  static const _enabledKey = 'ak_daily_reminder_enabled';
  static const _nextMessageKey = 'ak_daily_reminder_next_msg';
  static const _timeKey = 'ak_daily_reminder_minutes'; // chosen time, minutes after midnight

  // Default reminder time — 8:30 pm. People who can't do their deed then pick their own time.
  static const int sendHour = 20;
  static const int sendMinute = 30;
  static const TimeOfDay defaultTime = TimeOfDay(hour: sendHour, minute: sendMinute);
  static const int _firstId = 7300; // notification ids 7300–7309 belong to the reminder
  // Day offsets (from the first reminder day) for each scheduled reminder.
  static const List<int> _dayOffsets = [0, 1, 2, 4, 6, 8, 10, 17, 24, 31];

  // Rotated so the same line never shows on two consecutive days. (A streak line was dropped:
  // the in-app streak isn't a persisted, real value yet.)
  static const List<(String en, String ur)> messages = [
    ('Guddi is waiting 💛 Did you do an acha kaam today?', 'گڈی انتظار کر رہی ہے 💛 آج کوئی اچھا کام کیا؟'),
    ('Small things count. Helped someone today? Do one acha kaam in 30 seconds.', 'چھوٹی باتیں بھی اہم ہیں۔ آج ایک اچھا کام کریں، صرف 30 سیکنڈ!'),
    ('Before the day ends, do one good thing 💛', 'دن ختم ہونے سے پہلے، ایک اچھا کام کریں 💛'),
    ('Guddi missed you today 🙂 Anything kind happen?', 'گڈی نے آج آپ کو یاد کیا 🙂 کوئی اچھا کام ہوا؟'),
  ];

  static bool get supported => !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  static Future<SharedPreferences?> _prefs() async {
    try {
      return await SharedPreferences.getInstance();
    } catch (_) {
      return null;
    }
  }

  static Future<bool> wasAsked() async => (await _prefs())?.getBool(_askedKey) ?? false;
  static Future<bool> isEnabled() async => (await _prefs())?.getBool(_enabledKey) ?? false;

  static Future<TimeOfDay> reminderTime() async {
    final m = (await _prefs())?.getInt(_timeKey);
    if (m == null || m < 0 || m >= 24 * 60) return defaultTime;
    return TimeOfDay(hour: m ~/ 60, minute: m % 60);
  }

  // Saves the chosen time and rebuilds the batch at it (a no-op schedule when reminders are off).
  static Future<void> setReminderTime(TimeOfDay t, {required bool loggedToday}) async {
    if (!supported) return;
    await (await _prefs())?.setInt(_timeKey, t.hour * 60 + t.minute);
    await reschedule(loggedToday: loggedToday);
  }

  static String formatTime(TimeOfDay t) {
    final h12 = t.hourOfPeriod == 0 ? 12 : t.hourOfPeriod;
    return '$h12:${t.minute.toString().padLeft(2, '0')} ${t.period == DayPeriod.am ? 'am' : 'pm'}';
  }

  static Future<TimeOfDay?> pickTime(BuildContext context, TimeOfDay initial) => showTimePicker(
        context: context,
        initialTime: initial,
        helpText: 'Reminder time',
      );

  // The in-context ask ("Want a daily reminder from Guddi?"). Shown at most once per device —
  // a "No thanks" is respected and never asked again (Settings can still turn it on).
  static Future<void> maybeAsk(BuildContext context, {required bool loggedToday}) async {
    if (!supported || await wasAsked() || !context.mounted) return;
    final initial = await reminderTime();
    if (!context.mounted) return;
    final chosen = await showDialog<TimeOfDay>(context: context, builder: (_) => _ReminderAskDialog(initial: initial));
    final yes = chosen != null;
    final prefs = await _prefs();
    await prefs?.setBool(_askedKey, true);
    if (yes) {
      await prefs?.setInt(_timeKey, chosen.hour * 60 + chosen.minute);
      final allowed = await requestNotificationPermission();
      await prefs?.setBool(_enabledKey, allowed);
      if (allowed) await reschedule(loggedToday: loggedToday);
    } else {
      await prefs?.setBool(_enabledKey, false);
    }
  }

  // Settings switch. Turning it on asks for the notification permission if needed; returns the
  // resulting on/off state (false if the person — or the phone — said no).
  static Future<bool> setEnabled(bool on, {required bool loggedToday}) async {
    if (!supported) return false;
    final prefs = await _prefs();
    await prefs?.setBool(_askedKey, true);
    var enabled = on;
    if (on) enabled = await requestNotificationPermission();
    await prefs?.setBool(_enabledKey, enabled);
    await reschedule(loggedToday: loggedToday); // schedules, or cancels when off
    return enabled;
  }

  static Future<void> reschedule({required bool loggedToday}) async {
    if (!supported) return;
    try {
      await cancelAll();
      if (!await isEnabled() || !await notificationsAllowed()) return;

      final prefs = await _prefs();
      final start = (prefs?.getInt(_nextMessageKey) ?? 0) % messages.length;
      await prefs?.setInt(_nextMessageKey, (start + 1) % messages.length);

      final time = await reminderTime();
      final planned = plan(now: DateTime.now(), loggedToday: loggedToday, startMessage: start, hour: time.hour, minute: time.minute);
      for (var i = 0; i < planned.length; i++) {
        final (local, messageIndex) = planned[i];
        final (en, ur) = messages[messageIndex];
        await notificationsPlugin.zonedSchedule(
          _firstId + i,
          'Acha Karo',
          en,
          tz.TZDateTime.from(local, tz.UTC), // the exact instant of the chosen time on this phone's clock
          NotificationDetails(
            android: AndroidNotificationDetails(
              'acha_karo_daily_reminder',
              'Daily reminder',
              channelDescription: 'One gentle evening nudge from Guddi',
              importance: Importance.defaultImportance,
              priority: Priority.defaultPriority,
              styleInformation: BigTextStyleInformation('$en\n$ur'),
            ),
          ),
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
        );
      }
    } catch (_) {
      // Reminders are a nicety — never let a scheduling problem affect the app.
    }
  }

  // Pure schedule planning (unit-tested): the local date/time of each reminder and which message
  // it uses. Starts today at the chosen time unless that's already passed or a deed was logged
  // today. Built from local wall-clock dates, so each reminder lands at that local time.
  static List<(DateTime, int)> plan({
    required DateTime now,
    required bool loggedToday,
    required int startMessage,
    int hour = sendHour,
    int minute = sendMinute,
  }) {
    final todaySlot = DateTime(now.year, now.month, now.day, hour, minute);
    final firstDay = (!loggedToday && now.isBefore(todaySlot)) ? 0 : 1;
    return [
      for (var i = 0; i < _dayOffsets.length; i++)
        (
          DateTime(now.year, now.month, now.day + firstDay + _dayOffsets[i], hour, minute),
          (startMessage + i) % messages.length,
        ),
    ];
  }

  static Future<void> cancelAll() async {
    if (!supported) return;
    try {
      await initNotifications();
      for (var i = 0; i < _dayOffsets.length; i++) {
        await notificationsPlugin.cancel(_firstId + i);
      }
    } catch (_) {}
  }
}

// Returns the chosen time on "Yes", null on "No thanks". The time can be changed right here, so
// someone who can't do their deed at 8:30 pm isn't sent to Settings for it.
class _ReminderAskDialog extends StatefulWidget {
  final TimeOfDay initial;
  const _ReminderAskDialog({required this.initial});
  @override
  State<_ReminderAskDialog> createState() => _ReminderAskDialogState();
}

class _ReminderAskDialogState extends State<_ReminderAskDialog> {
  late TimeOfDay _time = widget.initial;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.bg2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        Image.asset('assets/images/guddi/guddi_small.webp', height: 90, fit: BoxFit.contain),
        const SizedBox(height: 10),
        Text('Want a daily reminder from Guddi?', textAlign: TextAlign.center, style: AppFonts.fraunces(size: 16, weight: FontWeight.w600)),
        const SizedBox(height: 6),
        Text(
          'One gentle nudge at ${DailyReminder.formatTime(_time)}. You can turn it off anytime in Settings.',
          textAlign: TextAlign.center,
          style: AppFonts.inter(size: 12.5, color: AppColors.textSoft, height: 1.4),
        ),
        TextButton.icon(
          onPressed: () async {
            final t = await DailyReminder.pickTime(context, _time);
            if (t != null && mounted) setState(() => _time = t);
          },
          icon: const Icon(Icons.schedule, size: 16, color: AppColors.gold),
          label: Text('Change time', style: AppFonts.inter(size: 12.5, weight: FontWeight.w600, color: AppColors.gold)),
        ),
      ]),
      actionsAlignment: MainAxisAlignment.center,
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text('No thanks', style: AppFonts.inter(size: 13, color: AppColors.textSoft)),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(_time),
          child: Text('Yes, remind me', style: AppFonts.inter(size: 13, weight: FontWeight.w700, color: AppColors.gold)),
        ),
      ],
    );
  }
}
