import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme/app_theme.dart';
import '../state/app_state.dart';
import '../widgets/animated_wallpaper.dart';
import '../utils/youtube.dart';
import '../utils/town_voice_reminder.dart';
import '../data/remote_config.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Rebuilt for real, replacing the earlier "launching soon" placeholder — controlled entirely by
// app_config.town_voice_active now (see town_voice_activation.sql), no code change needed to
// flip it on/off, same pattern already established for campaigns. Real leader data (via
// state.townVoiceLeader, itself fixed to use real accounts rather than mock ones in this same
// batch) — no synthetic data anywhere. Past Town Voices intentionally shows genuinely empty
// rather than the original design's hardcoded example winners, since there's no real database
// tracking of actual past winners yet — matches the "blank until real" principle already used
// elsewhere in this project (the heatmap → city chart, deed locations, etc.) rather than
// introducing fake data.
class TownVoiceScreen extends StatelessWidget {
  const TownVoiceScreen({super.key});

  Future<void> _watchOnYoutube(BuildContext context, String rawUrl) async {
    final videoId = extractYoutubeVideoId(rawUrl);
    if (videoId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Couldn't recognize this stream link — check it in Supabase.")));
      return;
    }
    final uri = Uri.parse('https://www.youtube.com/watch?v=$videoId');
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not open the stream.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final tv = state.remoteConfig.townVoice;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(icon: const Icon(Icons.arrow_back, color: AppColors.text), onPressed: () => Navigator.of(context).pop()),
        title: Text('Town Voice', style: AppFonts.inter(size: 14, weight: FontWeight.w600)),
        centerTitle: true,
      ),
      // Same real bug fixed here as the other screens in this batch — background wasn't filling
      // full height on shorter content (e.g. the "launching soon" placeholder specifically).
      body: Stack(
        // Real, genuine root-cause fix: Stack defaults to StackFit.loose, meaning it sizes
        // itself to its non-Positioned child (SafeArea), which in turn sizes to its OWN content
        // rather than filling available space. Every previous attempt only ever changed the
        // background widget itself, never addressed this — the Positioned background was
        // always being clipped down to match the Stack's own, content-sized bounds, regardless
        // of what explicit size it was given. This forces the Stack itself to fill available
        // space unconditionally, which is the actual fix.
        fit: StackFit.expand,
        children: [
          Positioned(
            top: 0,
            left: 0,
            width: MediaQuery.of(context).size.width,
            height: MediaQuery.of(context).size.height,
            child: AnimatedWallpaper(gradientColors: wallpaperSwatches[state.wallpaperSwatchIndex]),
          ),
          SafeArea(
            child: tv.active ? _ActiveContent(state: state, tv: tv, onWatch: () => _watchOnYoutube(context, tv.streamUrl)) : const _ComingSoon(),
          ),
        ],
      ),
    );
  }
}

class _ComingSoon extends StatelessWidget {
  const _ComingSoon();
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(28),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🎙️', style: TextStyle(fontSize: 48)),
            const SizedBox(height: 20),
            Text('Launching soon', style: AppFonts.fraunces(size: 20, weight: FontWeight.w600), textAlign: TextAlign.center),
            const SizedBox(height: 12),
            Text(
              "We're giving ourselves time to accumulate real users first — so when Town Voice launches, you'll actually have a meaningful audience, and your time will be worth it.",
              textAlign: TextAlign.center,
              style: AppFonts.inter(size: 13, color: AppColors.textSoft, height: 1.6),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActiveContent extends StatelessWidget {
  final AppState state;
  final dynamic tv;
  final VoidCallback onWatch;
  const _ActiveContent({required this.state, required this.tv, required this.onWatch});

  @override
  Widget build(BuildContext context) {
    final (leaderName, leaderPoints) = state.townVoiceLeader;
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 10, 18, 30),
      children: [
        Text('🎙️ Town Voice', style: AppFonts.fraunces(size: 22, weight: FontWeight.w600)),
        const SizedBox(height: 4),
        Text("Every week, the leaderboard's top spot earns 15 minutes to speak.", style: AppFonts.inter(size: 12, color: AppColors.textSoft)),
        const SizedBox(height: 16),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(color: AppColors.oliveCard, borderRadius: BorderRadius.circular(18)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("This week's provisional speaker", style: AppFonts.plexMono(size: 10, color: AppColors.textSoft)),
              const SizedBox(height: 6),
              Text(leaderName, style: AppFonts.fraunces(size: 20, weight: FontWeight.w600)),
              Text('$leaderPoints pts so far', style: AppFonts.inter(size: 12, color: AppColors.textSoft)),
              const SizedBox(height: 14),
              Row(children: [
                // With a real start time (town_voice_starts_at) the date/time are shown in this
                // phone's own time zone; otherwise the admin's text labels, as before.
                Expanded(child: _InfoChip(label: 'Date', value: tv.startsAt != null ? TownVoiceReminder.localLabels(tv.startsAt!).$1 : tv.dayLabel)),
                const SizedBox(width: 8),
                Expanded(child: _InfoChip(label: 'Time', value: tv.startsAt != null ? TownVoiceReminder.localLabels(tv.startsAt!).$2 : tv.timeLabel)),
                const SizedBox(width: 8),
                Expanded(child: _InfoChip(label: 'Length', value: tv.durationLabel)),
              ]),
              const SizedBox(height: 14),
              Text(
                'Streamed live on YouTube — link activates shortly before start time and stays as the recording afterward.',
                style: AppFonts.inter(size: 11.5, color: AppColors.textSoft, height: 1.5),
              ),
              const SizedBox(height: 14),
              Row(children: [
                // Only when there's a real start time still ahead (see TownVoiceReminder), and only
                // in the Android app — the browser version has no local notifications.
                if (TownVoiceReminder.supported && TownVoiceReminder.canRemind(tv)) ...[
                  Expanded(child: _NotifyMeButton(tv: tv)),
                  const SizedBox(width: 8),
                ],
                Expanded(
                  child: GestureDetector(
                    onTap: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Add to calendar — coming soon.'))),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(color: AppColors.bg2.withOpacity(0.4), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0x29F6F5EC))),
                      alignment: Alignment.center,
                      child: Text('📅 Add to calendar', style: AppFonts.inter(size: 12.5, weight: FontWeight.w700)),
                    ),
                  ),
                ),
              ]),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: onWatch,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFFFF3B30), Color(0xFFC1272D)]), borderRadius: BorderRadius.circular(12)),
                  alignment: Alignment.center,
                  child: Text('▶️ Watch on YouTube', style: AppFonts.inter(size: 13, weight: FontWeight.w700, color: Colors.white)),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text('Past Town Voices', style: AppFonts.fraunces(size: 15, weight: FontWeight.w600)),
        ]),
        const SizedBox(height: 10),
        // Genuinely empty — no real tracking of past winners exists in the database yet, and
        // showing the original design's hardcoded example winners would be exactly the kind of
        // mock data this was asked to avoid.
        Text('No past Town Voices recorded yet.', style: AppFonts.inter(size: 12, color: AppColors.textSoft)),
      ],
    );
  }
}

class _InfoChip extends StatelessWidget {
  final String label;
  final String value;
  const _InfoChip({required this.label, required this.value});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(color: AppColors.bg1.withOpacity(0.3), borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0x24F6F5EC))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: AppFonts.plexMono(size: 8.5, color: AppColors.textSoft)),
        const SizedBox(height: 3),
        Text(value, style: AppFonts.inter(size: 12, weight: FontWeight.w600)),
      ]),
    );
  }
}

// "🔔 Notify me" ⇄ "🔔 Reminder set" (tap to cancel). Permission is asked here, in context.
class _NotifyMeButton extends StatefulWidget {
  final TownVoiceConfig tv;
  const _NotifyMeButton({required this.tv});
  @override
  State<_NotifyMeButton> createState() => _NotifyMeButtonState();
}

class _NotifyMeButtonState extends State<_NotifyMeButton> {
  bool? _set; // null while the saved choice is read
  bool _busy = false;

  String? get _uid => Supabase.instance.client.auth.currentUser?.id;

  @override
  void initState() {
    super.initState();
    final uid = _uid;
    if (uid == null) {
      _set = false;
    } else {
      TownVoiceReminder.isOptedIn(uid).then((v) {
        if (mounted) setState(() => _set = v);
      });
    }
  }

  Future<void> _toggle() async {
    final uid = _uid;
    if (uid == null || _busy || _set == null) return;
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    if (_set!) {
      await TownVoiceReminder.optOut(uid);
      _set = false;
      messenger.showSnackBar(const SnackBar(content: Text(TownVoiceReminderCopy.cancelledSnack)));
    } else {
      final ok = await TownVoiceReminder.optIn(uid: uid, tv: widget.tv);
      _set = ok;
      messenger.showSnackBar(SnackBar(content: Text(ok ? TownVoiceReminderCopy.setSnack : TownVoiceReminderCopy.permissionOffSnack)));
    }
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final set = _set ?? false;
    return GestureDetector(
      key: const ValueKey('town-voice-notify'),
      onTap: _toggle,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        constraints: const BoxConstraints(minHeight: 44),
        decoration: BoxDecoration(
          color: set ? AppColors.oliveCardStrong : AppColors.gold,
          borderRadius: BorderRadius.circular(12),
          border: set ? Border.all(color: AppColors.gold.withOpacity(0.5)) : null,
        ),
        alignment: Alignment.center,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(set ? TownVoiceReminderCopy.set : TownVoiceReminderCopy.notify, style: AppFonts.inter(size: 12.5, weight: FontWeight.w700, color: set ? AppColors.gold : AppColors.inkOnGold)),
          if (set) Text(TownVoiceReminderCopy.cancelHint, style: AppFonts.inter(size: 9.5, color: AppColors.textSoft)),
        ]),
      ),
    );
  }
}
