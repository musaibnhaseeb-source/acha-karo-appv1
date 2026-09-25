import 'package:flutter/material.dart';
import '../data/guddi_content.dart';
import '../data/tiers.dart';
import '../theme/app_theme.dart';
import 'guddi_home.dart';
import 'tier_progress.dart';

// Home's top section (Musa's pick, "Home A" — Marketing patterns 1–3): a time-tinted banner card
// with Guddi's line and ONE action, a compact today / streak / next-tier strip, and the
// story-style daily idea card. Presentation only; everything shown is the user's own data.

List<Color> _bandGradient(int hour) {
  if (hour >= 21 || hour < 5) return const [Color(0xFF1A2342), Color(0xFF0B1022)]; // night
  if (hour < 12) return const [Color(0xFF5A4A1C), Color(0xFF1B2A17)]; // morning, warm
  if (hour < 17) return const [Color(0xFF3C4A2C), Color(0xFF14231A)]; // day, olive
  return const [Color(0xFF5A2E22), Color(0xFF1E1A14)]; // evening, dusk
}

class HomeBanner extends StatelessWidget {
  final GuddiHomeMood mood;
  final int hour;
  final String actionLabel;
  final VoidCallback? onAct;
  const HomeBanner({super.key, required this.mood, required this.hour, required this.actionLabel, required this.onAct});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 190,
      child: Stack(clipBehavior: Clip.none, children: [
        Positioned.fill(
          top: 24,
          child: Container(
            padding: const EdgeInsets.fromLTRB(16, 14, 124, 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: _bandGradient(hour)),
              border: Border.all(color: AppColors.gold.withOpacity(0.35)),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  if (mood.roman != null)
                    Text(mood.roman!, maxLines: 3, overflow: TextOverflow.ellipsis, style: AppFonts.inter(size: 14, weight: FontWeight.w600, height: 1.3)),
                  if (mood.en != null) ...[
                    const SizedBox(height: 3),
                    Text(mood.en!, maxLines: 2, overflow: TextOverflow.ellipsis, style: AppFonts.inter(size: 10.5, color: AppColors.textSoft)),
                  ],
                ]),
              ),
              SizedBox(
                height: 40,
                child: ElevatedButton(
                  onPressed: onAct,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.gold,
                    foregroundColor: AppColors.inkOnGold,
                    disabledBackgroundColor: AppColors.text.withOpacity(0.08),
                    shape: const StadiumBorder(),
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                  ),
                  child: Text(actionLabel, style: AppFonts.inter(size: 12.5, weight: FontWeight.w700, color: onAct != null ? AppColors.inkOnGold : AppColors.textSoft)),
                ),
              ),
            ]),
          ),
        ),
        // Guddi pops out of the card's top edge.
        Positioned(right: 4, bottom: 0, child: GuddiFigure(pose: mood.pose, night: mood.night, width: 124, height: 190)),
      ]),
    );
  }
}

/// Today ring · 🔥 streak · "N badges to <next tier>" with a thin bar.
class HomeProgressStrip extends StatelessWidget {
  final int streak;
  final bool doneToday;
  final int badgeCount;
  final bool historyLoaded; // today ring + streak need real deed history; tier part doesn't
  const HomeProgressStrip({super.key, required this.streak, required this.doneToday, required this.badgeCount, required this.historyLoaded});

  @override
  Widget build(BuildContext context) {
    final color = tierFrameColor(getUserTier(badgeCount));
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(color: AppColors.bg2, borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0x14F6F5EC))),
      child: Row(children: [
        if (historyLoaded) ...[
          Semantics(
            label: doneToday ? "Today's acha kaam done" : "Today's acha kaam not done yet",
            child: SizedBox(
              width: 40, height: 40,
              child: Stack(alignment: Alignment.center, children: [
                CircularProgressIndicator(value: doneToday ? 1 : 0, strokeWidth: 4, color: AppColors.gold, backgroundColor: AppColors.text.withOpacity(0.1)),
                Text(doneToday ? '✓' : 'Aaj', style: AppFonts.inter(size: doneToday ? 15 : 10, weight: FontWeight.w700, color: doneToday ? AppColors.gold : AppColors.textSoft)),
              ]),
            ),
          ),
          const SizedBox(width: 12),
          // Hidden at 0 — never a "0 day streak".
          if (streak > 0) ...[
            Text('🔥 $streak din', style: AppFonts.inter(size: 13, weight: FontWeight.w700, color: AppColors.gold)),
            Container(width: 1, height: 28, margin: const EdgeInsets.symmetric(horizontal: 12), color: AppColors.text.withOpacity(0.12)),
          ],
        ],
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            NextTierLabel(badgeCount: badgeCount),
            const SizedBox(height: 6),
            TierBar(value: tierProgress(badgeCount), color: color, height: 6),
          ]),
        ),
      ]),
    );
  }
}

/// Story-style daily idea: big Roman Urdu text, explain (chalk) Guddi, "Acha kaam karein",
/// "kal naya idea".
class StoryIdeaCard extends StatelessWidget {
  final AchaKaamIdea idea;
  final VoidCallback? onDo; // null while the global cooldown is on
  const StoryIdeaCard({super.key, required this.idea, required this.onDo});

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 170),
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
            shaderCallback: (r) => const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.white, Colors.white, Colors.transparent],
              stops: [0, 0.8, 1],
            ).createShader(r),
            child: Image.asset(GuddiPoses.explain, height: 168, fit: BoxFit.contain),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 118, 14),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('GUDDI KA AAJ KA IDEA 💡', style: AppFonts.plexMono(size: 9, color: AppColors.gold)),
            const SizedBox(height: 8),
            Text(idea.roman, style: AppFonts.fraunces(size: 19, weight: FontWeight.w700, height: 1.2)),
            const SizedBox(height: 3),
            Text(idea.en, style: AppFonts.inter(size: 11, color: AppColors.textSoft)),
            if (idea.involvesPerson) ...[
              const SizedBox(height: 5),
              Text('📷 ${kPhotoTheDeedHint.roman}', style: AppFonts.inter(size: 10.5, weight: FontWeight.w600, color: AppColors.olive)),
            ],
            const SizedBox(height: 14),
            Wrap(spacing: 10, runSpacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
              SizedBox(
                height: 38,
                child: ElevatedButton(
                  onPressed: onDo,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.gold,
                    foregroundColor: AppColors.inkOnGold,
                    disabledBackgroundColor: AppColors.text.withOpacity(0.08),
                    shape: const StadiumBorder(),
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 18),
                  ),
                  child: Text('Acha kaam karein', style: AppFonts.inter(size: 13, weight: FontWeight.w700, color: onDo != null ? AppColors.inkOnGold : AppColors.textSoft)),
                ),
              ),
              Text('kal naya idea', style: AppFonts.plexMono(size: 9, color: AppColors.textSoft)),
            ]),
          ]),
        ),
      ]),
    );
  }
}
