import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'confetti_overlay.dart';
import 'guddi_home.dart';
import '../data/guddi_content.dart';

// Ported from the original's DAILY_MILESTONE_CAPTIONS / playDailyMilestoneAnim() — this never
// existed in the Flutter port until now. Same three thresholds, same exact Urdu text.
String milestoneText(int threshold, String? gender) {
  if (threshold == 7) return gender == 'male' ? 'شہزادہ' : 'شہزادی'; // prince / princess — defaults feminine for other/unset, matching the original
  if (threshold == 5) return 'او خیر';
  return 'واہ جی واہ'; // 3
}

String milestoneCaption(int threshold) => '$threshold deeds today';

class DailyMilestoneAnimation extends StatefulWidget {
  final int threshold;
  final String? gender;
  final VoidCallback onDone;
  const DailyMilestoneAnimation({super.key, required this.threshold, required this.gender, required this.onDone});

  @override
  State<DailyMilestoneAnimation> createState() => _DailyMilestoneAnimationState();
}

class _DailyMilestoneAnimationState extends State<DailyMilestoneAnimation> with SingleTickerProviderStateMixin {
  late final AnimationController _confettiController;
  late final List<ConfettiPiece> _pieces;

  @override
  void initState() {
    super.initState();
    _pieces = generateConfettiPieces(30);
    _confettiController = AnimationController(vsync: this, duration: const Duration(milliseconds: 2200))..forward();
    Future.delayed(const Duration(milliseconds: 2200), () {
      if (mounted) widget.onDone();
    });
  }

  @override
  void dispose() {
    _confettiController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.bg1.withOpacity(0.65),
      child: Stack(children: [
        ConfettiLayer(controller: _confettiController, pieces: _pieces),
        Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            // 3 deeds: wink + thumbs up. 5 and 7 are the big ones: sword-hilt "getting stronger".
            GuddiPopIn(pose: widget.threshold >= 5 ? GuddiPoses.strong : GuddiPoses.cheer),
            const SizedBox(height: 26),
            PopInText(delay: Duration.zero, child: Text(milestoneText(widget.threshold, widget.gender), style: AppFonts.nastaliq(size: 40, color: AppColors.gold))),
            const SizedBox(height: 20), // Nastaliq glyphs dip well below their line box
            PopInText(
              delay: const Duration(milliseconds: 300),
              child: Text(milestoneCaption(widget.threshold), style: AppFonts.plexMono(size: 11, weight: FontWeight.w700, color: AppColors.text).copyWith(decoration: TextDecoration.none)),
            ),
            if (widget.threshold >= 5) ...[
              const SizedBox(height: 10),
              const PopInText(delay: Duration(milliseconds: 500), child: GuddiCaption(GuddiCelebrationLines.strong)),
            ],
          ]),
        ),
      ]),
    );
  }
}
