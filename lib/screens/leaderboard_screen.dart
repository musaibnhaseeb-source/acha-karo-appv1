import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../state/app_state.dart';
import '../data/tiers.dart';

// Extracted out of board_screen.dart's Leaderboard segment so it can be its own destination —
// now reached from a Home tile instead of living inside the Board tab. All-Time only for the
// pilot — the "This Week" toggle was removed since it was already just an honest placeholder
// showing identical data to All-Time (real weekly-window tracking needs data this app doesn't
// collect yet), ready to bring back once that's real.
class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key});
  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final entries = <(String, String, int, bool, int)>[
      (state.user.name, state.user.city, state.user.points, true, state.user.badges.length),
      for (final o in otherUsers) (o.name, o.city, o.points, false, o.badgeCount),
    ]..sort((a, b) => b.$3.compareTo(a.$3));

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(icon: const Icon(Icons.arrow_back, color: AppColors.text), onPressed: () => Navigator.of(context).pop()),
        title: Text('Leaderboard', style: AppFonts.inter(size: 14, weight: FontWeight.w600)),
        centerTitle: true,
      ),
      body: Container(
        decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: wallpaperSwatches[context.watch<AppState>().wallpaperSwatchIndex])),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(18, 10, 18, 30),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('👑 Leaderboard', style: AppFonts.fraunces(size: 22, weight: FontWeight.w600)),
                const SizedBox(height: 14),
                // "This Week" toggle removed for the pilot — it was already just an honest
                // placeholder showing the same ranking as All-Time (real weekly-window tracking
                // needs data this app doesn't collect yet), so hiding it rather than showing a
                // toggle that doesn't actually do anything different is the right call here.
                // Was "🔄 Resets every Monday — live standing" — removed for the pilot since the
                // weekly-reset concept is tied to the still-pending "This Week" feature, already
                // hidden above. Kept as an all-time-only standing, no misleading claim about
                // resets that don't actually happen yet.
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(color: AppColors.oliveCard, borderRadius: BorderRadius.circular(12)),
                  child: Text('🏆 All-time standing', style: AppFonts.inter(size: 11, color: AppColors.textSoft)),
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
      ),
    );
  }
}
