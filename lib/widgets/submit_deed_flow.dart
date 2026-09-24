import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../state/app_state.dart';
import 'submit_deed_modal.dart';
import 'thank_you_animation.dart';
import 'daily_milestone_animation.dart';
import 'tier_up_animation.dart';
import 'first_deed.dart';
import 'approval_notify_ask.dart';
import '../utils/daily_reminder.dart';
import '../data/guddi_content.dart';

// Extracted from HomeScreen's _openSubmitModal — was private to that one screen, now shared so
// the campaign quick-action CTA (and anywhere else that needs this later) gets the exact same
// complete flow: real GPS capture, real moderation checks, real cooldowns, full animation
// sequence. Nothing about coming from a campaign skips any of that — it's the identical code
// path as tapping a category deed on Home.
void openSubmitDeedFlow(BuildContext context, String type, {String? campaignId, GuddiLine? photoHint}) {
  // Captured before submitting — only true when real history has loaded and it's empty, so the
  // first-deed celebration can never fire from an unknown/unloaded state.
  final isFirstDeed = context.read<AppState>().needsFirstDeed;
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => SubmitDeedModal(type: type, campaignId: campaignId, photoHint: photoHint),
  ).then((result) async {
    if (result is! SubmitResult || !context.mounted) return;
    // Real fix here too — this used to celebrate with the thank-you animation regardless of
    // whether the submission actually went through. Now checked first: a cooldown-blocked
    // attempt gets an honest message instead of a false "thanks" animation.
    if (result.blockedByCooldown) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Still on cooldown — try again shortly.")));
      return;
    }
    // A deed was just logged — today's Guddi reminder is no longer needed.
    DailyReminder.reschedule(loggedToday: true);
    if (isFirstDeed) {
      await _showOverlay(context, (onDone) => FirstDeedCelebration(wasFlagged: result.flagged, onDone: onDone));
    } else {
      await _showOverlay(context, (onDone) => ThankYouAnimation(wasFlagged: result.flagged, onDone: onDone));
    }
    final gender = context.mounted ? context.read<AppState>().user.gender : null;
    for (final threshold in result.newMilestones) {
      if (!context.mounted) return;
      await _showOverlay(context, (onDone) => DailyMilestoneAnimation(threshold: threshold, gender: gender, onDone: onDone));
    }
    if (result.leveledUpTier != null && context.mounted) {
      await _showOverlay(context, (onDone) => TierUpAnimation(tier: result.leveledUpTier!, onDone: onDone));
    }
    // Went to a moderator? Offer "get told when it's approved" (once per device, only if
    // notifications aren't already allowed). If that was shown, the reminder ask waits for a later
    // deed so nobody gets two permission dialogs back to back.
    if (result.flagged && context.mounted && await maybeAskApprovalNotifications(context)) return;
    // In-context ask for the daily reminder, right after a deed — only ever once per device.
    if (context.mounted) await DailyReminder.maybeAsk(context, loggedToday: true);
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
