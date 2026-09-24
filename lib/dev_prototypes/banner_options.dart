import 'package:flutter/material.dart';
import '../data/badges.dart';
import '../data/guddi_content.dart';
import '../data/tiers.dart';
import '../theme/app_theme.dart';
import '../widgets/guddi_home.dart';

// DEV PROTOTYPES — Home + Profile banner options for Musa to pick from (Marketing's
// home-profile-design-patterns.md, patterns 1–4). Not imported by the app. Widgets take plain
// values (tier, badge count, streak…) so the chosen one moves into lib/widgets unchanged; all of
// them only ever show the user's OWN data that AppState already holds.

// ---- shared helpers ------------------------------------------------------------------------

TierDef? nextTierFor(int badgeCount) {
  for (final t in tierDefs) {
    if (t.min > badgeCount) return t;
  }
  return null; // already at the top tier
}

/// 0..1 progress from the current tier's threshold to the next one's.
double tierProgress(int badgeCount) {
  final cur = getUserTier(badgeCount);
  final next = nextTierFor(badgeCount);
  if (next == null) return 1;
  return ((badgeCount - cur.min) / (next.min - cur.min)).clamp(0.0, 1.0);
}

// One frame colour per tier (PUBG/Careem-style rank frames).
const Map<String, Color> tierFrameColors = {
  'chick': Color(0xFFE9C46A),
  'cat': Color(0xFFC08457),
  'parrot': Color(0xFF7CB66B),
  'bear': Color(0xFFA47551),
  'cheetah': Color(0xFFD9A62E),
  'lion': Color(0xFFE4843C),
  'eagle': Color(0xFF9EC5E8),
};

const _tierRank = {'rainbow': 5, 'platinum': 4, 'gold': 3, 'silver': 2, 'bronze': 1};

/// The user's 3 best earned badges (highest badge tier first) — automatic, so no new storage.
List<BadgeDef> showcaseBadges(List<String> earnedIds) {
  final earned = badgeDefs.where((b) => earnedIds.contains(b.id)).toList()
    ..sort((a, b) => (_tierRank[b.tier] ?? 0).compareTo(_tierRank[a.tier] ?? 0));
  return earned.take(3).toList();
}

String badgesToNext(int badgeCount) {
  final next = nextTierFor(badgeCount);
  if (next == null) return 'Top tier reached';
  final n = next.min - badgeCount;
  return '$n badge${n == 1 ? '' : 's'} to ${next.icon}';
}

class _TierBar extends StatelessWidget {
  final double value;
  final Color color;
  final double height;
  const _TierBar({required this.value, required this.color, this.height = 8});
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

/// "3 badges to 🦜 طوطو" with the Urdu tier name in Nastaliq.
class _NextTierLabel extends StatelessWidget {
  final int badgeCount;
  final double size;
  const _NextTierLabel({required this.badgeCount, this.size = 11});
  @override
  Widget build(BuildContext context) {
    final next = nextTierFor(badgeCount);
    if (next == null) return Text('Top tier reached 🦅', style: AppFonts.inter(size: size, weight: FontWeight.w600, color: AppColors.gold));
    return Row(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.center, children: [
      Text(badgesToNext(badgeCount), style: AppFonts.inter(size: size, weight: FontWeight.w600, color: AppColors.textSoft)),
      const SizedBox(width: 4),
      Text(next.name, style: AppFonts.nastaliq(size: size + 1, color: AppColors.gold)),
    ]);
  }
}

// ---- HOME option A: banner card + compact progress strip ----------------------------------

List<Color> _bandGradient(int hour) {
  if (hour >= 21 || hour < 5) return const [Color(0xFF1A2342), Color(0xFF0B1022)]; // night
  if (hour < 12) return const [Color(0xFF5A4A1C), Color(0xFF1B2A17)]; // morning, warm
  if (hour < 17) return const [Color(0xFF3C4A2C), Color(0xFF14231A)]; // day, olive
  return const [Color(0xFF5A2E22), Color(0xFF1E1A14)]; // evening, dusk
}

class HomeBannerA extends StatelessWidget {
  final GuddiHomeMood mood;
  final int hour;
  final VoidCallback onAct;
  const HomeBannerA({super.key, required this.mood, required this.hour, required this.onAct});
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 190,
      child: Stack(clipBehavior: Clip.none, children: [
        Positioned.fill(
          top: 24,
          child: Container(
            padding: const EdgeInsets.fromLTRB(16, 16, 128, 16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: _bandGradient(hour)),
              border: Border.all(color: AppColors.gold.withOpacity(0.35)),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(mood.roman ?? '', style: AppFonts.inter(size: 14, weight: FontWeight.w600, height: 1.3)),
                if (mood.en != null) ...[
                  const SizedBox(height: 3),
                  Text(mood.en!, style: AppFonts.inter(size: 10.5, color: AppColors.textSoft)),
                ],
              ]),
              SizedBox(
                height: 40,
                child: ElevatedButton(
                  onPressed: onAct,
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.gold, foregroundColor: AppColors.inkOnGold, shape: const StadiumBorder(), elevation: 0, padding: const EdgeInsets.symmetric(horizontal: 16)),
                  child: Text('Aaj ka acha kaam karein', style: AppFonts.inter(size: 12.5, weight: FontWeight.w700, color: AppColors.inkOnGold)),
                ),
              ),
            ]),
          ),
        ),
        // Guddi pops out of the top edge of the card.
        Positioned(
          right: 4, bottom: 0,
          child: GuddiFigure(pose: mood.pose, night: mood.night, width: 124, height: 190),
        ),
      ]),
    );
  }
}

class HomeProgressStripA extends StatelessWidget {
  final int streak;
  final bool doneToday;
  final int badgeCount;
  const HomeProgressStripA({super.key, required this.streak, required this.doneToday, required this.badgeCount});
  @override
  Widget build(BuildContext context) {
    final tier = getUserTier(badgeCount);
    final color = tierFrameColors[tier.key] ?? AppColors.gold;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(color: AppColors.bg2, borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0x14F6F5EC))),
      child: Row(children: [
        // Today ring
        SizedBox(
          width: 40, height: 40,
          child: Stack(alignment: Alignment.center, children: [
            CircularProgressIndicator(value: doneToday ? 1 : 0.0001, strokeWidth: 4, color: AppColors.gold, backgroundColor: AppColors.text.withOpacity(0.1)),
            Text(doneToday ? '✓' : 'Aaj', style: AppFonts.inter(size: doneToday ? 15 : 10, weight: FontWeight.w700, color: doneToday ? AppColors.gold : AppColors.textSoft)),
          ]),
        ),
        const SizedBox(width: 12),
        if (streak > 0) ...[
          Text('🔥 $streak din', style: AppFonts.inter(size: 13, weight: FontWeight.w700, color: AppColors.gold)),
          Container(width: 1, height: 28, margin: const EdgeInsets.symmetric(horizontal: 12), color: AppColors.text.withOpacity(0.12)),
        ],
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _NextTierLabel(badgeCount: badgeCount),
            const SizedBox(height: 6),
            _TierBar(value: tierProgress(badgeCount), color: color, height: 6),
          ]),
        ),
      ]),
    );
  }
}

// ---- HOME option B: open hero (current) + one progress rail ----------------------------------

class HomeProgressRailB extends StatelessWidget {
  final Widget weekRow; // the existing WeekRowCard content
  final int badgeCount;
  const HomeProgressRailB({super.key, required this.weekRow, required this.badgeCount});
  @override
  Widget build(BuildContext context) {
    final tier = getUserTier(badgeCount);
    final color = tierFrameColors[tier.key] ?? AppColors.gold;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      weekRow,
      const SizedBox(height: 8),
      Container(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
        decoration: BoxDecoration(color: AppColors.bg2, borderRadius: BorderRadius.circular(16), border: Border.all(color: color.withOpacity(0.35))),
        child: Row(children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: color, width: 2), color: color.withOpacity(0.12)),
            alignment: Alignment.center,
            child: Text(tier.icon, style: const TextStyle(fontSize: 20)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _NextTierLabel(badgeCount: badgeCount, size: 11.5),
              const SizedBox(height: 7),
              _TierBar(value: tierProgress(badgeCount), color: color),
            ]),
          ),
        ]),
      ),
    ]);
  }
}

/// Story-style idea card: big Roman Urdu text, explain pose, "Karein", "kal naya idea".
class StoryIdeaCardB extends StatelessWidget {
  final AchaKaamIdea idea;
  final VoidCallback? onDo;
  const StoryIdeaCardB({super.key, required this.idea, required this.onDo});
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 170,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [AppColors.gold.withOpacity(0.28), AppColors.bg2]),
        border: Border.all(color: AppColors.gold.withOpacity(0.5)),
      ),
      child: Stack(children: [
        Positioned(
          right: -6, bottom: -4,
          child: ShaderMask(
            blendMode: BlendMode.dstIn,
            shaderCallback: (r) => const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.white, Colors.white, Colors.transparent], stops: [0, 0.8, 1]).createShader(r),
            child: Image.asset(GuddiPoses.explain, height: 168, fit: BoxFit.contain),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 118, 14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Text('GUDDI KA AAJ KA IDEA 💡', style: AppFonts.plexMono(size: 9, color: AppColors.gold)),
            ]),
            const SizedBox(height: 8),
            Text(idea.roman, maxLines: 3, overflow: TextOverflow.ellipsis, style: AppFonts.fraunces(size: 19, weight: FontWeight.w700, height: 1.2)),
            const SizedBox(height: 3),
            Text(idea.en, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppFonts.inter(size: 11, color: AppColors.textSoft)),
            const Spacer(),
            Row(children: [
              SizedBox(
                height: 36,
                child: ElevatedButton(
                  onPressed: onDo,
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.gold, foregroundColor: AppColors.inkOnGold, shape: const StadiumBorder(), elevation: 0, padding: const EdgeInsets.symmetric(horizontal: 18)),
                  child: Text('Karein', style: AppFonts.inter(size: 13, weight: FontWeight.w700, color: AppColors.inkOnGold)),
                ),
              ),
              const SizedBox(width: 10),
              Text('kal naya idea', style: AppFonts.plexMono(size: 9, color: AppColors.textSoft)),
            ]),
          ]),
        ),
      ]),
    );
  }
}

// ---- PROFILE option A: rank frame card ------------------------------------------------------

class _ShowcaseRow extends StatelessWidget {
  final List<BadgeDef> badges;
  final Color color;
  const _ShowcaseRow({required this.badges, required this.color});
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

class ProfileTierCardA extends StatelessWidget {
  final int badgeCount;
  final List<String> earnedIds;
  const ProfileTierCardA({super.key, required this.badgeCount, required this.earnedIds});
  @override
  Widget build(BuildContext context) {
    final tier = getUserTier(badgeCount);
    final color = tierFrameColors[tier.key] ?? AppColors.gold;
    final idx = tierDefs.indexWhere((t) => t.key == tier.key);
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
      decoration: BoxDecoration(
        color: AppColors.bg2,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: color.withOpacity(0.55), width: 1.5),
        boxShadow: [BoxShadow(color: color.withOpacity(0.18), blurRadius: 24)],
      ),
      child: Column(children: [
        Container(
          width: 96, height: 96,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(colors: [color.withOpacity(0.35), color.withOpacity(0.05)]),
            border: Border.all(color: color, width: 3),
          ),
          alignment: Alignment.center,
          child: Text(tier.icon, style: const TextStyle(fontSize: 46)),
        ),
        const SizedBox(height: 4),
        Text(tier.name, style: AppFonts.nastaliq(size: 26, color: color)),
        const SizedBox(height: 10), // Nastaliq dips below its line box
        Text('TIER ${idx + 1} OF ${tierDefs.length}', style: AppFonts.plexMono(size: 9)),
        const SizedBox(height: 12),
        Row(children: [
          Text('$badgeCount badges', style: AppFonts.inter(size: 11, weight: FontWeight.w600)),
          const Spacer(),
          _NextTierLabel(badgeCount: badgeCount),
        ]),
        const SizedBox(height: 6),
        _TierBar(value: tierProgress(badgeCount), color: color, height: 9),
        const SizedBox(height: 14),
        Align(alignment: Alignment.centerLeft, child: Text('SHOWCASE', style: AppFonts.plexMono(size: 9))),
        const SizedBox(height: 6),
        _ShowcaseRow(badges: showcaseBadges(earnedIds), color: color),
      ]),
    );
  }
}

// ---- PROFILE option B: Guddi tier banner ----------------------------------------------------

class ProfileTierBannerB extends StatelessWidget {
  final int badgeCount;
  final List<String> earnedIds;
  const ProfileTierBannerB({super.key, required this.badgeCount, required this.earnedIds});
  @override
  Widget build(BuildContext context) {
    final tier = getUserTier(badgeCount);
    final color = tierFrameColors[tier.key] ?? AppColors.gold;
    final top = nextTierFor(badgeCount) == null;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      SizedBox(
        height: 180,
        child: Stack(clipBehavior: Clip.none, children: [
          Positioned.fill(
            top: 20,
            child: Container(
              padding: const EdgeInsets.fromLTRB(16, 14, 124, 14),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(22),
                gradient: LinearGradient(begin: Alignment.centerLeft, end: Alignment.centerRight, colors: [color.withOpacity(0.38), AppColors.bg2]),
                border: Border.all(color: color.withOpacity(0.6), width: 1.5),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
                Row(children: [
                  Text(tier.icon, style: const TextStyle(fontSize: 34)),
                  const SizedBox(width: 8),
                  Text(tier.name, style: AppFonts.nastaliq(size: 24, color: AppColors.text)),
                ]),
                const SizedBox(height: 2),
                _NextTierLabel(badgeCount: badgeCount),
                const SizedBox(height: 8),
                _TierBar(value: tierProgress(badgeCount), color: color),
                if (top) ...[
                  const SizedBox(height: 8),
                  Text(GuddiCelebrationLines.topTier.roman, style: AppFonts.inter(size: 11, weight: FontWeight.w600)),
                ],
              ]),
            ),
          ),
          Positioned(
            right: 6, bottom: 0,
            child: ShaderMask(
              blendMode: BlendMode.dstIn,
              shaderCallback: (r) => const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.white, Colors.white, Colors.transparent], stops: [0, 0.82, 1]).createShader(r),
              child: Image.asset(top ? GuddiPoses.strong : GuddiPoses.cheer, height: 180, fit: BoxFit.contain),
            ),
          ),
        ]),
      ),
      const SizedBox(height: 10),
      _ShowcaseRow(badges: showcaseBadges(earnedIds), color: color),
    ]);
  }
}
