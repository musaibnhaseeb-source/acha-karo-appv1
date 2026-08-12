import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../theme/app_theme.dart';
import '../state/app_state.dart';

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
        content: Text("You'll need to sign in again with a code sent to your email.", style: AppFonts.inter(size: 12.5, color: AppColors.textSoft)),
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
            "This submits a request to our team — your account isn't deleted immediately. Let us know why you're leaving, if you're willing to share.",
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
                SnackBar(content: Text(error ?? "Request submitted — we'll be in touch.")),
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
      body: Container(
        decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: wallpaperSwatches[context.watch<AppState>().wallpaperSwatchIndex])),
        child: SafeArea(
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
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(color: AppColors.oliveCard, borderRadius: BorderRadius.circular(14)),
                child: Row(children: [
                  Expanded(child: Text('Sound effects', style: AppFonts.inter(size: 13, weight: FontWeight.w600))),
                  Switch(
                    value: state.soundEnabled,
                    activeTrackColor: AppColors.gold,
                    onChanged: (_) => context.read<AppState>().toggleSound(),
                  ),
                ]),
              ),
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
      ),
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
