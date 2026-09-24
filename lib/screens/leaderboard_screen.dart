import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../theme/app_theme.dart';
import '../state/app_state.dart';
import '../widgets/animated_wallpaper.dart';
import '../data/tiers.dart';

enum LeaderboardMode { allTime, thisWeek }

// Extracted out of board_screen.dart's Leaderboard segment so it can be its own destination —
// now reached from a Home tile instead of living inside the Board tab. "This Week" is real now
// (see weekly_leaderboard.sql) — was previously removed since the old version was an honest
// placeholder duplicating All-Time. The toggle itself only shows when
// remoteConfig.weeklyLeaderboardActive is true, same database-driven activation pattern as
// campaigns/Town Voice. Real cross-user data throughout, via the get_public_profiles RPC (safe
// public columns only — no direct select on profiles).
class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key});
  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  LeaderboardMode mode = LeaderboardMode.allTime;

  @override
  void initState() {
    super.initState();
    // Refreshed on open, not just relying on the one-time load at sign-in — points change
    // often (approvals, new submissions), so this keeps the standing reasonably current.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AppState>().loadLeaderboard();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final uid = Supabase.instance.client.auth.currentUser?.id;
    final weeklyOn = state.remoteConfig.weeklyLeaderboardActive;
    final effectiveMode = weeklyOn ? mode : LeaderboardMode.allTime;

    final entries = effectiveMode == LeaderboardMode.allTime
        ? <(String, String, int, bool, int)>[
            (state.user.name, state.user.city, state.user.points, true, state.user.badges.length),
            for (final o in state.realLeaderboard.where((e) => e.id != uid)) (o.name, o.city, o.points, false, o.badgeCount),
          ]
        : <(String, String, int, bool, int)>[
            for (final o in state.weeklyLeaderboard) (o.name, o.city, o.points, o.id == uid, 0),
          ];
    entries.sort((a, b) => b.$3.compareTo(a.$3));

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(icon: const Icon(Icons.arrow_back, color: AppColors.text), onPressed: () => Navigator.of(context).pop()),
        title: Text('Leaderboard', style: AppFonts.inter(size: 14, weight: FontWeight.w600)),
        centerTitle: true,
      ),
      // Real bug fixed here: Container(decoration: gradient, child: SafeArea(...)) only fills
      // as much height as its content needs — on a short screen (few leaderboard entries), the
      // background stopped short of the bottom, showing black underneath instead of the
      // wallpaper. A Stack with the gradient as a Positioned.fill layer decouples the background
      // from content height entirely, so it always covers the full screen regardless of how much
      // content is actually in it.
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
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(18, 10, 18, 30),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('👑 Leaderboard', style: AppFonts.fraunces(size: 22, weight: FontWeight.w600)),
                const SizedBox(height: 14),
                if (weeklyOn) ...[
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(color: AppColors.bg1.withOpacity(0.35), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0x1FF6F5EC))),
                    child: Row(children: [
                      Expanded(child: _SegBtn(label: 'All-Time', active: mode == LeaderboardMode.allTime, onTap: () => setState(() => mode = LeaderboardMode.allTime))),
                      Expanded(child: _SegBtn(label: 'This Week', active: mode == LeaderboardMode.thisWeek, onTap: () => setState(() => mode = LeaderboardMode.thisWeek))),
                    ]),
                  ),
                  const SizedBox(height: 10),
                ],
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(color: AppColors.oliveCard, borderRadius: BorderRadius.circular(12)),
                  child: Text(
                    effectiveMode == LeaderboardMode.allTime ? '🏆 All-time standing' : '🔄 Resets every Monday — this week\'s standing',
                    style: AppFonts.inter(size: 11, color: AppColors.textSoft),
                  ),
                ),
                const SizedBox(height: 10),
                ...entries.asMap().entries.map((e) {
                  final i = e.key;
                  final (name, city, points, isMe, badgeCount) = e.value;
                  final tier = getUserTier(badgeCount);
                  final medalColor = i == 0 ? AppColors.gold : (i == 1 ? AppColors.textSoft : (i == 2 ? AppColors.rust : AppColors.oliveCardStrong));
                  return Container(
                    margin: const EdgeInsets.only(bottom: 6),
                    padding: EdgeInsets.symmetric(horizontal: isMe ? 10 : 4, vertical: 10),
                    decoration: isMe ? BoxDecoration(color: AppColors.oliveCard, borderRadius: BorderRadius.circular(10)) : null,
                    child: Row(children: [
                      Container(
                        width: 26, height: 26,
                        decoration: BoxDecoration(shape: BoxShape.circle, color: medalColor),
                        alignment: Alignment.center,
                        child: Text('${i + 1}', style: AppFonts.plexMono(size: 11, weight: FontWeight.w700, color: i < 3 ? AppColors.inkOnGold : AppColors.text)),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(name + (isMe ? ' (you)' : ''), style: AppFonts.inter(size: 12.5, weight: FontWeight.w600)),
                          Text(city, style: AppFonts.plexMono(size: 9.5, color: AppColors.textSoft)),
                        ]),
                      ),
                      Row(children: [Text(tier.icon, style: const TextStyle(fontSize: 13)), const SizedBox(width: 3), Text(tier.name, style: AppFonts.nastaliq(size: 13, color: AppColors.gold))]),
                      const SizedBox(width: 10),
                      Text('$points', style: AppFonts.plexMono(size: 12, weight: FontWeight.w600)),
                    ]),
                  );
                }),
              ],
            ),
          ),
        ),
        ],
      ),
    );
  }
}

class _SegBtn extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _SegBtn({required this.label, required this.active, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(color: active ? AppColors.gold : Colors.transparent, borderRadius: BorderRadius.circular(9)),
        alignment: Alignment.center,
        child: Text(label, textAlign: TextAlign.center, style: AppFonts.plexMono(size: 10, weight: FontWeight.w600, color: active ? AppColors.inkOnGold : AppColors.textSoft)),
      ),
    );
  }
}
