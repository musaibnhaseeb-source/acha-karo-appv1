import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../data/tiers.dart';
import 'confetti_overlay.dart';
import 'guddi_home.dart';
import '../data/guddi_content.dart';

// Was previously just a SnackBar — upgraded to a real full-screen animation matching the
// thank-you/daily-milestone celebrations, ported from playTierUpAnim() in the original (same
// idea: tier icon + Urdu tier name, biggest confetti burst of the three since this is the
// rarest, most significant celebration).
class TierUpAnimation extends StatefulWidget {
  final TierDef tier;
  final VoidCallback onDone;
  const TierUpAnimation({super.key, required this.tier, required this.onDone});

  @override
  State<TierUpAnimation> createState() => _TierUpAnimationState();
}

class _TierUpAnimationState extends State<TierUpAnimation> with SingleTickerProviderStateMixin {
  late final AnimationController _confettiController;
  late final List<ConfettiPiece> _pieces;

  @override
  void initState() {
    super.initState();
    _pieces = generateConfettiPieces(40); // biggest burst of the three celebration animations
    _confettiController = AnimationController(vsync: this, duration: const Duration(milliseconds: 2400))..forward();
    Future.delayed(const Duration(milliseconds: 2400), () {
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
    // The anime sword-drawn pose is a different art style, kept for the single biggest moment
    // (reaching the top tier) so it reads as a deliberate power-up. Every other tier-up gets the
    // calm sword-hilt "getting stronger" pose.
    final topTier = widget.tier.key == tierDefs.last.key;
    return Container(
      color: AppColors.bg1.withOpacity(0.7),
      child: Stack(children: [
        ConfettiLayer(controller: _confettiController, pieces: _pieces),
        Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            GuddiPopIn(pose: topTier ? GuddiPoses.power : GuddiPoses.strong, screenFraction: topTier ? 0.32 : 0.26, maxHeight: topTier ? 260 : 210),
            const SizedBox(height: 26),
            PopInText(delay: Duration.zero, child: Text(widget.tier.icon, style: const TextStyle(fontSize: 56))),
            const SizedBox(height: 10),
            PopInText(delay: const Duration(milliseconds: 250), child: Text(widget.tier.name, style: AppFonts.nastaliq(size: 40, color: AppColors.gold))),
            const SizedBox(height: 8),
            PopInText(
              delay: const Duration(milliseconds: 450),
              child: Text('Tier up!', style: AppFonts.plexMono(size: 12, weight: FontWeight.w700, color: AppColors.text)),
            ),
            const SizedBox(height: 10),
            PopInText(
              delay: const Duration(milliseconds: 600),
              child: GuddiCaption(topTier ? GuddiCelebrationLines.topTier : GuddiCelebrationLines.strong),
            ),
          ]),
        ),
      ]),
    );
  }
}
