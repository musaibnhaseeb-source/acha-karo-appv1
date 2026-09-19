import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';

// New — real system notifications with sound, not just the in-app list. Uses
// flutter_local_notifications (shows the actual notification) alongside permission_handler
// (specifically for the Android 13+ POST_NOTIFICATIONS prompt, the same category of runtime
// permission camera/location already use). Genuinely new territory for this project — first
// native notification package added — worth extra care on first real test.
final FlutterLocalNotificationsPlugin _notificationsPlugin = FlutterLocalNotificationsPlugin();

Future<void> initNotifications() async {
  try {
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidSettings);
    await _notificationsPlugin.initialize(initSettings);
  } catch (_) {
    // Doesn't block app startup if this fails for any reason — notifications just won't show
    // locally, same "don't let a secondary feature break the primary flow" principle used
    // elsewhere in this app.
  }
}

// Requested once, early — same category of runtime permission as camera/location, just prompted
// proactively rather than tied to a specific action, since there's no single natural "moment"
// like there is for taking a photo.
Future<void> requestNotificationPermission() async {
  try {
    await Permission.notification.request();
  } catch (_) {
    // If this fails or is denied, local notifications just silently won't show — the in-app
    // notification list still works regardless, so nothing else breaks.
  }
}

Future<void> showLocalNotification({required String title, required String body}) async {
  try {
    const androidDetails = AndroidNotificationDetails(
      'acha_karo_channel',
      'Acha Karo Notifications',
      channelDescription: 'Deed approvals, feedback responses, and other updates',
      importance: Importance.high,
      priority: Priority.high,
    );
    const notificationDetails = NotificationDetails(android: androidDetails);
    await _notificationsPlugin.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title,
      body,
      notificationDetails,
    );
  } catch (_) {
    // Same reasoning — a failure here shouldn't affect anything else the app is doing.
  }
}
