import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../theme/app_theme.dart';
import '../state/app_state.dart';
import '../widgets/animated_wallpaper.dart';
import '../utils/daily_reminder.dart';
import '../data/guddi_content.dart';

// Ported from the original's known settings sheet — text scale, sound, wallpaper color. Nothing
// new decided here, same logic as already established earlier in this whole project.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  void _confirmSignOut(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.bg2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text('Sign out?', style: AppFonts.fraunces(size: 16, weight: FontWeight.w600)),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text("You'll need to sign in again with a code sent to your email.", style: AppFonts.inter(size: 12.5, color: AppColors.textSoft)),
          // Offline mode: deeds still waiting on this phone are deleted on sign-out — say so first.
          if (context.read<AppState>().waitingDeeds.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              OfflineLines.signOutWarning.replaceAll('{n}', '${context.read<AppState>().waitingDeeds.length}'),
              key: const ValueKey('signout-waiting-warning'),
              style: AppFonts.inter(size: 12.5, weight: FontWeight.w600, color: const Color(0xFFE39B84)),
            ),
          ],
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: Text('Cancel', style: AppFonts.inter(size: 13, color: AppColors.textSoft))),
          TextButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              // RootScreen's auth-state listener (in main.dart) handles clearing local state and
              // navigating back to Login once this fires — nothing else needed here.
              await Supabase.instance.client.auth.signOut();
            },
            child: Text('Sign out', style: AppFonts.inter(size: 13, weight: FontWeight.w700, color: const Color(0xFFE39B84))),
          ),
        ],
      ),
    );
  }

  void _showDeleteAccountDialog(BuildContext context) {
    final reasonController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.bg2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text('Delete account', style: AppFonts.fraunces(size: 16, weight: FontWeight.w600)),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(
            "This submits a request to our team — your account isn't deleted immediately. We'll delete it within 30 days, along with your acha kaam, photos and locations. Let us know why you're leaving, if you're willing to share.",
            style: AppFonts.inter(size: 12, color: AppColors.textSoft, height: 1.4),
          ),
          const SizedBox(height: 14),
          Container(
            decoration: BoxDecoration(color: AppColors.oliveCard, borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0x33F6F5EC))),
            child: TextField(
              controller: reasonController,
              maxLines: 3,
              style: AppFonts.inter(size: 13),
              decoration: InputDecoration(
                border: InputBorder.none,
                contentPadding: const EdgeInsets.all(10),
                hintText: 'Reason (optional)',
                hintStyle: AppFonts.inter(size: 13, color: AppColors.textSoft.withOpacity(0.5)),
              ),
            ),
          ),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: Text('Cancel', style: AppFonts.inter(size: 13, color: AppColors.textSoft))),
          TextButton(
            onPressed: () async {
              final reason = reasonController.text.trim();
              final error = await context.read<AppState>().submitAccountDeletionRequest(reason.isEmpty ? null : reason);
              if (!ctx.mounted) return;
              Navigator.of(ctx).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(error ?? "Request submitted — your account will be deleted within 30 days."), duration: const Duration(seconds: 5)),
              );
            },
            child: Text('Submit request', style: AppFonts.inter(size: 13, weight: FontWeight.w700, color: const Color(0xFFE39B84))),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(icon: const Icon(Icons.arrow_back, color: AppColors.text), onPressed: () => Navigator.of(context).pop()),
        title: Text('Settings', style: AppFonts.inter(size: 14, weight: FontWeight.w600)),
        centerTitle: true,
      ),
      // Same real bug fixed here as the other screens in this batch.
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
            child: AnimatedWallpaper(gradientColors: wallpaperSwatches[context.watch<AppState>().wallpaperSwatchIndex]),
          ),
        SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(18, 10, 18, 30),
            children: [
              Text('Text size', style: AppFonts.fraunces(size: 15, weight: FontWeight.w600)),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(color: AppColors.oliveCard, borderRadius: BorderRadius.circular(12)),
                child: Row(children: [
                  _TextScaleBtn(label: 'A−', active: state.textScale == 'down', onTap: () => context.read<AppState>().setTextScale('down')),
                  _TextScaleBtn(label: 'A', active: state.textScale == 'default', onTap: () => context.read<AppState>().setTextScale('default')),
                  _TextScaleBtn(label: 'A+', active: state.textScale == 'up', onTap: () => context.read<AppState>().setTextScale('up')),
                ]),
              ),
              // "Sound effects" toggle removed — the app has no sounds, so it controlled nothing.
              if (DailyReminder.supported) ...[
                const SizedBox(height: 24),
                const _DailyReminderTile(),
              ],
              const SizedBox(height: 24),
              Text('Wallpaper', style: AppFonts.fraunces(size: 15, weight: FontWeight.w600)),
              const SizedBox(height: 10),
              Row(
                children: List.generate(wallpaperSwatches.length, (i) {
                  final active = state.wallpaperSwatchIndex == i;
                  return Padding(
                    padding: const EdgeInsets.only(right: 10),
                    child: GestureDetector(
                      onTap: () => context.read<AppState>().setWallpaperSwatch(i),
                      child: Container(
                        width: 46, height: 46,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: wallpaperSwatches[i]),
                          border: Border.all(color: active ? AppColors.gold : Colors.transparent, width: 2),
                        ),
                      ),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 32),
              // New — there was no way to sign out anywhere in the app before this. Confirms
              // first since this is a meaningful action, not just a visual preference toggle
              // like everything else on this screen.
              GestureDetector(
                onTap: () => _confirmSignOut(context),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  decoration: BoxDecoration(color: AppColors.rust.withOpacity(0.14), borderRadius: BorderRadius.circular(13), border: Border.all(color: AppColors.rust.withOpacity(0.35))),
                  alignment: Alignment.center,
                  child: Text('Sign out', style: AppFonts.inter(size: 13.5, weight: FontWeight.w700, color: const Color(0xFFE39B84))),
                ),
              ),
              const SizedBox(height: 10),
              // New — pilot-scoped: submits a request for a moderator to review and action
              // manually, rather than the app deleting the account itself. Real self-service
              // deletion needs server-side access this app deliberately doesn't hold.
              GestureDetector(
                onTap: () => _showDeleteAccountDialog(context),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  decoration: BoxDecoration(border: Border.all(color: const Color(0x29F6F5EC)), borderRadius: BorderRadius.circular(13)),
                  child: Text('Delete account', textAlign: TextAlign.center, style: AppFonts.inter(size: 12.5, color: AppColors.textSoft)),
                ),
              ),
            ],
          ),
        ),
        ],
      ),
    );
  }
}

// Local on/off + time for the daily Guddi reminder (stored on this device only). Turning it on
// asks for the notification permission if it hasn't been granted yet.
class _DailyReminderTile extends StatefulWidget {
  const _DailyReminderTile();
  @override
  State<_DailyReminderTile> createState() => _DailyReminderTileState();
}

class _DailyReminderTileState extends State<_DailyReminderTile> {
  bool? _enabled; // null while loading
  TimeOfDay _time = DailyReminder.defaultTime;
  bool _busy = false;
  bool _blocked = false; // switched on, but the phone has notifications off for the app

  @override
  void initState() {
    super.initState();
    Future.wait([DailyReminder.isEnabled(), DailyReminder.reminderTime()]).then((r) {
      if (mounted) setState(() { _enabled = r[0] as bool; _time = r[1] as TimeOfDay; });
    });
  }

  Future<void> _toggle(bool on) async {
    setState(() => _busy = true);
    final result = await DailyReminder.setEnabled(on, loggedToday: context.read<AppState>().loggedDeedToday);
    if (!mounted) return;
    setState(() {
      _enabled = result;
      _busy = false;
      _blocked = on && !result; // Android won't show the prompt again once it's been refused
    });
  }

  Future<void> _changeTime() async {
    final t = await DailyReminder.pickTime(context, _time);
    if (t == null || !mounted) return;
    setState(() => _time = t);
    await DailyReminder.setReminderTime(t, loggedToday: context.read<AppState>().loggedDeedToday);
  }

  @override
  Widget build(BuildContext context) {
    final on = _enabled ?? false;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
      decoration: BoxDecoration(color: AppColors.oliveCard, borderRadius: BorderRadius.circular(14)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Daily reminder from Guddi', style: AppFonts.inter(size: 13, weight: FontWeight.w600)),
              const SizedBox(height: 2),
              Text('One gentle nudge at ${DailyReminder.formatTime(_time)}', style: AppFonts.inter(size: 11, color: AppColors.textSoft)),
            ]),
          ),
          Switch(
            value: on,
            activeTrackColor: AppColors.gold,
            onChanged: (_enabled == null || _busy) ? null : _toggle,
          ),
        ]),
        // Time can be picked any time, even while off — it's used as soon as reminders are on.
        TextButton.icon(
          style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(0, 36), tapTargetSize: MaterialTapTargetSize.shrinkWrap),
          onPressed: _enabled == null ? null : _changeTime,
          icon: const Icon(Icons.schedule, size: 16, color: AppColors.gold),
          label: Text('Change time', style: AppFonts.inter(size: 12, weight: FontWeight.w600, color: AppColors.gold)),
        ),
        if (_blocked) ...[
          const SizedBox(height: 4),
          Text(
            'Notifications are turned off for Acha Karo on this phone. To allow them: Settings → Apps → Acha Karo → Notifications → turn on. Then switch the reminder on again here.',
            style: AppFonts.inter(size: 11, color: const Color(0xFFE39B84), height: 1.4),
          ),
        ],
        Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            tilePadding: EdgeInsets.zero,
            childrenPadding: const EdgeInsets.only(bottom: 4),
            dense: true,
            iconColor: AppColors.textSoft,
            collapsedIconColor: AppColors.textSoft,
            title: Text('Reminders not arriving?', style: AppFonts.inter(size: 12, weight: FontWeight.w600, color: AppColors.textSoft)),
            children: [
              Text(
                'Some phones (for example Xiaomi, Oppo, Vivo, Infinix and Tecno) stop apps in the background to save battery, which can block reminders:\n'
                "1. Open your phone's Settings → Apps → Acha Karo.\n"
                '2. Under Battery, choose "No restrictions" (or turn off battery optimisation).\n'
                '3. If you see "Auto-start" or "Allow background activity", turn it on.\n'
                '4. Make sure Notifications are allowed.\n'
                'Opening Acha Karo also refreshes your reminders.',
                style: AppFonts.inter(size: 11, color: AppColors.textSoft, height: 1.45),
              ),
            ],
          ),
        ),
      ]),
    );
  }
}

class _TextScaleBtn extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _TextScaleBtn({required this.label, required this.active, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(color: active ? AppColors.gold : Colors.transparent, borderRadius: BorderRadius.circular(9)),
          alignment: Alignment.center,
          child: Text(label, style: AppFonts.inter(size: 13, weight: FontWeight.w700, color: active ? AppColors.inkOnGold : AppColors.textSoft)),
        ),
      ),
    );
  }
}
