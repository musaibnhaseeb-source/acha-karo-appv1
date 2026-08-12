import 'dart:math';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

const List<Color> confettiColors = [
  AppColors.gold,
  AppColors.olive,
  AppColors.rust,
  Color(0xFF6FA8D6),
  AppColors.text,
];

class ConfettiPiece {
  final double leftFraction;
  final Color color;
  final double delayFraction;
  final double durationFraction;
  final double rotations;
  ConfettiPiece({required this.leftFraction, required this.color, required this.delayFraction, required this.durationFraction, required this.rotations});
}

List<ConfettiPiece> generateConfettiPieces(int count) {
  final rand = Random();
  return List.generate(count, (_) {
    return ConfettiPiece(
      leftFraction: rand.nextDouble(),
      color: confettiColors[rand.nextInt(confettiColors.length)],
      delayFraction: rand.nextDouble() * 0.18,
      durationFraction: 0.6 + rand.nextDouble() * 0.4,
      rotations: 1.67,
    );
  });
}

// Reusable confetti layer — extracted from WelcomeAnimationScreen so it's shared with the
// simplified per-deed thank-you animation and the 3/5/7-deed daily milestone animation, rather
// than three copies of the same particle logic.
class ConfettiLayer extends StatelessWidget {
  final AnimationController controller;
  final List<ConfettiPiece> pieces;
  const ConfettiLayer({super.key, required this.controller, required this.pieces});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        return LayoutBuilder(builder: (context, constraints) {
          return Stack(
            children: pieces.map((p) {
              final localT = ((controller.value - p.delayFraction) / p.durationFraction).clamp(0.0, 1.0);
              if (localT <= 0) return const SizedBox.shrink();
              final dy = localT * 480;
              final rotation = localT * p.rotations * 2 * pi;
              final opacity = (1 - localT).clamp(0.0, 1.0);
              return Positioned(
                left: p.leftFraction * constraints.maxWidth,
                top: -12 + dy,
                child: Opacity(
                  opacity: opacity,
                  child: Transform.rotate(angle: rotation, child: Container(width: 7, height: 13, color: p.color.withOpacity(0.95))),
                ),
              );
            }).toList(),
          );
        });
      },
    );
  }
}

// Same pop-in used by the welcome screen's text — extracted for reuse.
class PopInText extends StatefulWidget {
  final Widget child;
  final Duration delay;
  const PopInText({super.key, required this.child, required this.delay});
  @override
  State<PopInText> createState() => _PopInTextState();
}

class _PopInTextState extends State<PopInText> {
  bool _started = false;
  @override
  void initState() {
    super.initState();
    Future.delayed(widget.delay, () {
      if (mounted) setState(() => _started = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_started) return Opacity(opacity: 0, child: widget.child);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 700),
      curve: Curves.elasticOut,
      builder: (context, value, _) {
        final clamped = value.clamp(0.0, 1.0);
        return Opacity(
          opacity: clamped,
          child: Transform.translate(
            offset: Offset(0, 14 * (1 - value)),
            child: Transform.scale(scale: 0.9 + (0.1 * value), child: widget.child),
          ),
        );
      },
    );
  }
}
