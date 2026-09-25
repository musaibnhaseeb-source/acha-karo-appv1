import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'confetti_overlay.dart';
import 'guddi_home.dart';

// Replaces the original's per-category emoji-burst animations (env/animal/civic/social/health
// each had their own emoji set) with one simplified universal animation, per the simplification
// direction: confetti + شکریہ (thank you), shown for every submission regardless of category.
// The subtitle changes depending on whether the submission was instantly approved or sent to a
// moderator — "give a thank you regardless" applies to both outcomes.
class ThankYouAnimation extends StatefulWidget {
  final bool wasFlagged;
  final VoidCallback onDone;
  const ThankYouAnimation({super.key, required this.wasFlagged, required this.onDone});

  @override
  State<ThankYouAnimation> createState() => _ThankYouAnimationState();
}

class _ThankYouAnimationState extends State<ThankYouAnimation> with SingleTickerProviderStateMixin {
  late final AnimationController _confettiController;
  late final List<ConfettiPiece> _pieces;
  final String _pose = randomFromPool(GuddiPoses.cheerPool);

  @override
  void initState() {
    super.initState();
    _pieces = generateConfettiPieces(24);
    _confettiController = AnimationController(vsync: this, duration: const Duration(milliseconds: 1600))..forward();
    Future.delayed(const Duration(milliseconds: 1800), () {
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
      color: AppColors.bg1.withOpacity(0.55),
      child: Stack(children: [
        ConfettiLayer(controller: _confettiController, pieces: _pieces),
        Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            GuddiPopIn(pose: _pose), // one of the cheer pool, picked when this opens
            const SizedBox(height: 26),
            PopInText(delay: Duration.zero, child: Text('شکریہ', style: AppFonts.nastaliq(size: 40, color: AppColors.gold))),
            const SizedBox(height: 20), // Nastaliq glyphs dip well below their line box
            PopInText(
              delay: const Duration(milliseconds: 250),
              // Matches the daily-milestone animation's caption styling (plexMono, same weight)
              // rather than a distinct "warning" look — explicitly set decoration: none too, so
              // there's no chance of an inherited underline from anywhere up the widget tree.
              // Content differs (approved vs pending), but the visual treatment is the same
              // celebratory family either way, not an alarm/error style.
              child: Text(
                widget.wasFlagged
                    ? 'Sent for review — points credited shortly after a moderator checks it.'
                    : 'Acha kaam done, points credited!',
                textAlign: TextAlign.center,
                style: AppFonts.plexMono(
                  size: 11,
                  weight: FontWeight.w700,
                  color: widget.wasFlagged ? AppColors.olive : AppColors.text,
                ).copyWith(decoration: TextDecoration.none),
              ),
            ),
          ]),
        ),
      ]),
    );
  }
}
