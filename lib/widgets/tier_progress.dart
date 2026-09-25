import 'package:flutter/material.dart';
import '../data/badges.dart';
import '../data/tiers.dart';
import '../theme/app_theme.dart';

// Tier progress pieces shared by Home's progress strip and Profile's tier banner. All computed
// from the user's OWN badge count / earned badge ids, which AppState already holds — no queries.

TierDef? nextTierFor(int badgeCount) {
  for (final t in tierDefs) {
    if (t.min > badgeCount) return t;
  }
  return null; // already at the top tier
}

/// 0..1 progress from the current tier's threshold to the next one's (1 at the top tier).
double tierProgress(int badgeCount) {
  final cur = getUserTier(badgeCount);
  final next = nextTierFor(badgeCount);
  if (next == null) return 1;
  return ((badgeCount - cur.min) / (next.min - cur.min)).clamp(0.0, 1.0);
}

// One frame colour per tier (rank-frame style).
const Map<String, Color> tierFrameColors = {
  'chick': Color(0xFFE9C46A),
  'cat': Color(0xFFC08457),
  'parrot': Color(0xFF7CB66B),
  'bear': Color(0xFFA47551),
  'cheetah': Color(0xFFD9A62E),
  'lion': Color(0xFFE4843C),
  'eagle': Color(0xFF9EC5E8),
};

Color tierFrameColor(TierDef tier) => tierFrameColors[tier.key] ?? AppColors.gold;

const _badgeTierRank = {'rainbow': 5, 'platinum': 4, 'gold': 3, 'silver': 2, 'bronze': 1};

/// The user's 3 best earned badges (highest badge tier first) — picked automatically.
List<BadgeDef> showcaseBadges(List<String> earnedIds) {
  final earned = badgeDefs.where((b) => earnedIds.contains(b.id)).toList()
    ..sort((a, b) => (_badgeTierRank[b.tier] ?? 0).compareTo(_badgeTierRank[a.tier] ?? 0));
  return earned.take(3).toList();
}

class TierBar extends StatelessWidget {
  final double value;
  final Color color;
  final double height;
  const TierBar({super.key, required this.value, required this.color, this.height = 8});
  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(height),
      child: Stack(children: [
        Container(height: height, color: AppColors.text.withOpacity(0.1)),
        FractionallySizedBox(
          widthFactor: value,
          child: Container(height: height, decoration: BoxDecoration(gradient: LinearGradient(colors: [color.withOpacity(0.7), color]))),
        ),
      ]),
    );
  }
}

/// "3 badges to 🦜 طوطو" (Urdu tier name in Nastaliq), or "Top tier reached 🦅".
class NextTierLabel extends StatelessWidget {
  final int badgeCount;
  final double size;
  const NextTierLabel({super.key, required this.badgeCount, this.size = 11});
  @override
  Widget build(BuildContext context) {
    final next = nextTierFor(badgeCount);
    if (next == null) return Text('Top tier reached 🦅', style: AppFonts.inter(size: size, weight: FontWeight.w600, color: AppColors.gold));
    final n = next.min - badgeCount;
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Flexible(child: Text('$n badge${n == 1 ? '' : 's'} to ${next.icon}', overflow: TextOverflow.ellipsis, style: AppFonts.inter(size: size, weight: FontWeight.w600, color: AppColors.textSoft))),
      const SizedBox(width: 4),
      Text(next.name, style: AppFonts.nastaliq(size: size + 1, color: AppColors.gold)),
    ]);
  }
}

/// Three showcase slots; empty slots show a dash.
class ShowcaseBadgesRow extends StatelessWidget {
  final List<BadgeDef> badges;
  final Color color;
  const ShowcaseBadgesRow({super.key, required this.badges, required this.color});
  @override
  Widget build(BuildContext context) {
    return Row(children: [
      for (var i = 0; i < 3; i++) ...[
        if (i > 0) const SizedBox(width: 8),
        Expanded(
          child: Container(
            height: 66,
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
            decoration: BoxDecoration(
              color: i < badges.length ? color.withOpacity(0.10) : AppColors.text.withOpacity(0.04),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: i < badges.length ? color.withOpacity(0.45) : AppColors.text.withOpacity(0.08)),
            ),
            child: i < badges.length
                ? Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Text(badges[i].icon, style: const TextStyle(fontSize: 20)),
                    const SizedBox(height: 3),
                    Text(badges[i].name, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppFonts.inter(size: 9.5, weight: FontWeight.w600)),
                  ])
                : Center(child: Text('—', style: AppFonts.inter(size: 14, color: AppColors.textSoft))),
          ),
        ),
      ],
    ]);
  }
}
