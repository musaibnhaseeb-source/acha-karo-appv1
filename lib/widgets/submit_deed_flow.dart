import 'dart:async';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../state/app_state.dart';
import 'submit_deed_modal.dart';
import 'thank_you_animation.dart';
import 'daily_milestone_animation.dart';
import 'tier_up_animation.dart';

// Permission helper — requests camera and location permissions before opening the submission modal.
// Returns false if permissions denied, true if granted or already granted.
Future<bool> _requestDeedSubmissionPermissions() async {
  final cameraStatus = await Permission.camera.request();
  final locationStatus = await Permission.location.request();
  
  return cameraStatus.isGranted && locationStatus.isGranted;
}

// Extracted from HomeScreen's _openSubmitModal — was private to that one screen, now shared so
// the campaign quick-action CTA (and anywhere else that needs this later) gets the exact same
// complete flow: real GPS capture, real moderation checks, real cooldowns, full animation
// sequence. Nothing about coming from a campaign skips any of that — it's the identical code
// path as tapping a category deed on Home.
void openSubmitDeedFlow(BuildContext context, String type) async {
  // Request permissions BEFORE opening the modal
  final hasPermissions = await _requestDeedSubmissionPermissions();
  if (!hasPermissions) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Camera and location permissions are required to submit a deed.'),
          duration: Duration(seconds: 3),
        ),
      );
    }
    return;
  }

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => SubmitDeedModal(type: type),
  ).then((result) async {
    if (result is! SubmitResult || !context.mounted) return;
    await _showOverlay(context, (onDone) => ThankYouAnimation(wasFlagged: result.flagged, onDone: onDone));
    final gender = context.mounted ? context.read<AppState>().user.gender : null;
    for (final threshold in result.newMilestones) {
      if (!context.mounted) return;
      await _showOverlay(context, (onDone) => DailyMilestoneAnimation(threshold: threshold, gender: gender, onDone: onDone));
    }
    if (result.leveledUpTier != null && context.mounted) {
      await _showOverlay(context, (onDone) => TierUpAnimation(tier: result.leveledUpTier!, onDone: onDone));
    }
  });
}

Future<void> _showOverlay(BuildContext context, Widget Function(VoidCallback onDone) builder) {
  final completer = Completer<void>();
  late OverlayEntry entry;
  entry = OverlayEntry(
    builder: (ctx) => Positioned.fill(
      child: builder(() {
        entry.remove();
        if (!completer.isCompleted) completer.complete();
      }),
    ),
  );
  Overlay.of(context).insert(entry);
  return completer.future;
}
