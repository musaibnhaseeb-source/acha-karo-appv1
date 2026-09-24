import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

// System notifications (Android). Two uses: showing a real notification when a new in-app
// notification row arrives (deed approved, feedback answered…), and the local daily Guddi
// reminder (see daily_reminder.dart). Nothing here asks for permission on its own — the
// Android 13+ prompt only ever comes from requestNotificationPermission(), which is called in
// context (after the onboarding tour or a deed), never at app start. No-ops on web.
final FlutterLocalNotificationsPlugin notificationsPlugin = FlutterLocalNotificationsPlugin();

Future<void>? _init;

// Safe to call any number of times; the plugin is only initialized once. Does not prompt.
Future<void> initNotifications() => _init ??= _doInit();

Future<void> _doInit() async {
  if (kIsWeb) return;
  try {
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidSettings);
    await notificationsPlugin.initialize(initSettings);
  } catch (_) {
    // Doesn't block the app — notifications just won't show.
  }
}

AndroidFlutterLocalNotificationsPlugin? get _android =>
    notificationsPlugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

// Shows the Android 13+ system prompt if it hasn't been answered yet (older Android: already
// allowed). Returns whether notifications are allowed afterwards.
Future<bool> requestNotificationPermission() async {
  if (kIsWeb) return false;
  try {
    await initNotifications();
    return await _android?.requestNotificationsPermission() ?? false;
  } catch (_) {
    return false;
  }
}

// Whether notifications are currently allowed for the app — never prompts.
Future<bool> notificationsAllowed() async {
  if (kIsWeb) return false;
  try {
    await initNotifications();
    return await _android?.areNotificationsEnabled() ?? false;
  } catch (_) {
    return false;
  }
}

Future<void> showLocalNotification({required String title, required String body}) async {
  if (kIsWeb) return;
  try {
    await initNotifications();
    const androidDetails = AndroidNotificationDetails(
      'acha_karo_channel',
      'Acha Karo Notifications',
      channelDescription: 'Deed approvals, feedback responses, and other updates',
      importance: Importance.high,
      priority: Priority.high,
    );
    const notificationDetails = NotificationDetails(android: androidDetails);
    await notificationsPlugin.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title,
      body,
      notificationDetails,
    );
  } catch (_) {
    // Same reasoning — a failure here shouldn't affect anything else the app is doing.
  }
}
