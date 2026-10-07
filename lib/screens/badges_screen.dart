import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../state/app_state.dart';
import '../widgets/animated_wallpaper.dart';
import '../data/badges.dart';
import '../data/guddi_content.dart';

// Ported from #overlayBadges / renderBadgesOverlay() in the original — badges grouped by
// category, each showing its unlock state with a tier pill (or "LOCKED").
class BadgesScreen extends StatelessWidget {
  const BadgesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final unlockedIds = state.user.badges;
    // Offline mode: badges that deeds still waiting on the phone would unlock. Shown as WAITING,
    // not earned — nothing is written until the server has the deeds.
    final waitingIds = state.waitingBadgeIds;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(icon: const Icon(Icons.arrow_back, color: AppColors.text), onPressed: () => Navigator.of(context).pop()),
        title: Text('Badges', style: AppFonts.inter(size: 14, weight: FontWeight.w600)),
        centerTitle: true,
      ),
      // Same real bug fixed here as Leaderboard/Contact/Notifications — background wasn't
      // filling full height on shorter content, showing black underneath.
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
                Text('🏅 Badges', style: AppFonts.fraunces(size: 22, weight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text('${unlockedIds.length} of ${badgeDefs.length} unlocked · every milestone counts', style: AppFonts.inter(size: 12, color: AppColors.textSoft)),
                const SizedBox(height: 18),
                ...badgeCategoryDefs.map((cat) {
                  final inCat = badgeDefs.where((b) => b.category == cat.key).toList();
                  if (inCat.isEmpty) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          Text(cat.icon, style: const TextStyle(fontSize: 16)),
                          const SizedBox(width: 8),
                          Expanded(child: Text(cat.name, style: AppFonts.fraunces(size: 14.5, weight: FontWeight.w600))),
                          Text('${inCat.length}', style: AppFonts.plexMono(size: 10, color: AppColors.textSoft)),
                        ]),
                        const SizedBox(height: 10),
                        GridView.count(
                          crossAxisCount: 2,
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          crossAxisSpacing: 10,
                          mainAxisSpacing: 10,
                          childAspectRatio: 1.5,
                          children: inCat.map((b) {
                            final unlocked = unlockedIds.contains(b.id);
                            final waiting = !unlocked && waitingIds.contains(b.id);
                            return Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: AppColors.oliveCard,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: unlocked ? AppColors.gold.withOpacity(0.35) : Colors.transparent),
                              ),
                              child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
                                Opacity(opacity: unlocked ? 1 : (waiting ? 0.7 : 0.35), child: Text(b.icon, style: const TextStyle(fontSize: 22))),
                                const SizedBox(height: 6),
                                Text(b.name, style: AppFonts.inter(size: 11, weight: FontWeight.w600, color: unlocked ? AppColors.text : AppColors.textSoft), maxLines: 2, overflow: TextOverflow.ellipsis),
                                const SizedBox(height: 3),
                                Text(b.req, style: AppFonts.inter(size: 9, color: AppColors.textSoft), maxLines: 2, overflow: TextOverflow.ellipsis),
                                const SizedBox(height: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: unlocked ? AppColors.gold.withOpacity(0.18) : AppColors.bg2.withOpacity(0.4),
                                    borderRadius: BorderRadius.circular(100),
                                  ),
                                  child: Text(
                                    unlocked ? '✓ ${b.tier.toUpperCase()}' : (waiting ? '⏳ ${OfflineLines.waitingBadge}' : 'LOCKED'),
                                    style: AppFonts.plexMono(size: 8.5, weight: FontWeight.w700, color: unlocked ? AppColors.gold : AppColors.textSoft),
                                  ),
                                ),
                              ]),
                            );
                          }).toList(),
                        ),
                      ],
                    ),
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
