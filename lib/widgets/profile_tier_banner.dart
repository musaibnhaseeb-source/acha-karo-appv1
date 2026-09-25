import 'package:flutter/material.dart';
import '../data/guddi_content.dart';
import '../data/tiers.dart';
import '../theme/app_theme.dart';
import 'guddi_home.dart';
import 'tier_progress.dart';

// Profile's tier banner (Musa's pick, "Profile B" — Marketing pattern 4): tier-coloured card with
// the emblem, Urdu tier name, next-tier bar and Guddi (cheer; strong + "Guddi kuch bhi ban sakti
// hai…" at the top tier), then the user's 3 best badges. Own data only (badge ids in AppState).
class ProfileTierBanner extends StatelessWidget {
  final List<String> earnedBadgeIds;
  const ProfileTierBanner({super.key, required this.earnedBadgeIds});

  @override
  Widget build(BuildContext context) {
    final badgeCount = earnedBadgeIds.length;
    final tier = getUserTier(badgeCount);
    final color = tierFrameColor(tier);
    final top = nextTierFor(badgeCount) == null;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      SizedBox(
        height: 180,
        child: Stack(clipBehavior: Clip.none, children: [
          Positioned.fill(
            top: 20,
            child: Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 124, 12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(22),
                gradient: LinearGradient(begin: Alignment.centerLeft, end: Alignment.centerRight, colors: [color.withOpacity(0.38), AppColors.bg2]),
                border: Border.all(color: color.withOpacity(0.6), width: 1.5),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
                Row(children: [
                  Text(tier.icon, style: const TextStyle(fontSize: 34)),
                  const SizedBox(width: 8),
                  Flexible(child: Text(tier.name, style: AppFonts.nastaliq(size: 24, color: AppColors.text))),
                ]),
                const SizedBox(height: 2),
                NextTierLabel(badgeCount: badgeCount),
                const SizedBox(height: 8),
                TierBar(value: tierProgress(badgeCount), color: color),
                if (top) ...[
                  const SizedBox(height: 8),
                  Text(GuddiCelebrationLines.topTier.roman, maxLines: 2, style: AppFonts.inter(size: 11, weight: FontWeight.w600)),
                ],
              ]),
            ),
          ),
          Positioned(
            right: 6, bottom: 0,
            child: ShaderMask(
              blendMode: BlendMode.dstIn,
              shaderCallback: (r) => const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.white, Colors.white, Colors.transparent],
                stops: [0, 0.82, 1],
              ).createShader(r),
              child: Image.asset(top ? GuddiPoses.strong : GuddiPoses.cheer, height: 180, fit: BoxFit.contain),
            ),
          ),
        ]),
      ),
      const SizedBox(height: 10),
      ShowcaseBadgesRow(badges: showcaseBadges(earnedBadgeIds), color: color),
    ]);
  }
}
