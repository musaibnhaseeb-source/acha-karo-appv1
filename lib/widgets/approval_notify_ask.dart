import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_theme.dart';
import '../utils/notifications.dart';
import 'guddi_home.dart';

// In-context notification-permission ask for people whose deed went to a moderator: "Get told
// when it's approved?". Asked at most once per device, and only if notifications aren't already
// allowed — the daily-reminder ask was the only other place that ever requested the permission.
// Returns true if the ask was shown (so the caller skips any other prompt this time).
const _askedKey = 'ak_approval_notify_asked';

Future<bool> maybeAskApprovalNotifications(BuildContext context) async {
  if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return false;
  SharedPreferences? prefs;
  try {
    prefs = await SharedPreferences.getInstance();
  } catch (_) {
    return false;
  }
  if (prefs.getBool(_askedKey) ?? false) return false;
  if (await notificationsAllowed()) return false;
  if (!context.mounted) return false;
  await prefs.setBool(_askedKey, true);
  final yes = await showDialog<bool>(context: context, builder: (_) => const _ApprovalAskDialog());
  if (yes == true) await requestNotificationPermission();
  return true;
}

class _ApprovalAskDialog extends StatelessWidget {
  const _ApprovalAskDialog();
  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.bg2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        Image.asset(GuddiPoses.chatty, height: 96, fit: BoxFit.contain),
        const SizedBox(height: 10),
        Text('Get told when it\'s approved?', textAlign: TextAlign.center, style: AppFonts.fraunces(size: 16, weight: FontWeight.w600)),
        const SizedBox(height: 6),
        Text(
          'Your acha kaam is with a moderator. Allow notifications and Guddi can let you know once it\'s been checked.',
          textAlign: TextAlign.center,
          style: AppFonts.inter(size: 12.5, color: AppColors.textSoft, height: 1.4),
        ),
      ]),
      actionsAlignment: MainAxisAlignment.center,
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text('Not now', style: AppFonts.inter(size: 13, color: AppColors.textSoft)),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: Text('Yes, tell me', style: AppFonts.inter(size: 13, weight: FontWeight.w700, color: AppColors.gold)),
        ),
      ],
    );
  }
}
