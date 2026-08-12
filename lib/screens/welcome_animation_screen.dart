import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/confetti_overlay.dart';

// Ported from the welcome-anim-screen / spawnConfetti() in the original — shown once, right
// after Profile Setup completes, before landing on Home. Same ~2.2s hold + 0.5s fade-out timing
// as the original. Now built on the shared confetti_overlay.dart components (extracted after
// this screen and the new thank-you/milestone animations turned out to need the same particle
// system three times).
class WelcomeAnimationScreen extends StatefulWidget {
  final String name;
  final VoidCallback onDone;
  const WelcomeAnimationScreen({super.key, required this.name, required this.onDone});

  @override
  State<WelcomeAnimationScreen> createState() => _WelcomeAnimationScreenState();
}

class _WelcomeAnimationScreenState extends State<WelcomeAnimationScreen> with TickerProviderStateMixin {
  late final AnimationController _confettiController;
  late final AnimationController _fadeController;
  late final List<ConfettiPiece> _pieces;

  @override
  void initState() {
    super.initState();
    _pieces = generateConfettiPieces(32);
    _confettiController = AnimationController(vsync: this, duration: const Duration(milliseconds: 2200))..forward();
    _fadeController = AnimationController(vsync: this, duration: const Duration(milliseconds: 500), value: 1);

    Future.delayed(const Duration(milliseconds: 2200), () async {
      if (!mounted) return;
      await _fadeController.reverse();
      if (mounted) widget.onDone();
    });
  }

  @override
  void dispose() {
    _confettiController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeController,
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment(-1, -1),
            end: Alignment(1, 1),
            colors: [AppColors.bg2, AppColors.bg1, AppColors.bg4],
            stops: [0.0, 0.55, 1.0],
          ),
        ),
        child: Stack(children: [
          ConfettiLayer(controller: _confettiController, pieces: _pieces),
          Center(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              PopInText(delay: const Duration(milliseconds: 0), child: Text('خوش آمدید', style: AppFonts.nastaliq(size: 44, color: AppColors.gold))),
              const SizedBox(height: 10),
              PopInText(delay: const Duration(milliseconds: 350), child: Text(widget.name, style: AppFonts.fraunces(size: 24, weight: FontWeight.w600))),
            ]),
          ),
        ]),
      ),
    );
  }
}
