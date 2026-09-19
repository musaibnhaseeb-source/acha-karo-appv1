import 'dart:math';
import 'package:flutter/material.dart';

// Extracted out of campaign_detail_screen.dart so the roadmap's mystery-box mechanic can reuse
// the exact same flip animation rather than a second copy. Same visual/timing as before —
// nothing about the campaign card's own behavior changes. The one addition is the optional
// onTap override: campaign_detail_screen.dart doesn't use it (falls back to self-flip,
// identical to before), but the mystery box grid needs it — tapping ONE box should reveal ALL
// boxes together, not just the one tapped, which needs an external trigger per card rather than
// each card only ever responding to its own tap.
class FlipCard extends StatefulWidget {
  final Widget front;
  final Widget back;
  final VoidCallback? onTap;
  const FlipCard({super.key, required this.front, required this.back, this.onTap});
  @override
  State<FlipCard> createState() => FlipCardState();
}

class FlipCardState extends State<FlipCard> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  bool _showFront = true;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 500));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  // Public — lets a parent holding a GlobalKey<FlipCardState> per card trigger a flip
  // externally. Needed for "tap one box, all boxes reveal together" rather than only the
  // tapped card flipping on its own.
  void flip() {
    if (_controller.isAnimating) return;
    if (_showFront) {
      _controller.forward();
    } else {
      _controller.reverse();
    }
    _showFront = !_showFront;
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap ?? flip, // external control takes over when provided; otherwise
      // self-flips exactly as before — campaign_detail_screen.dart's usage is unaffected.
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          final angle = _controller.value * pi;
          final isBack = angle > pi / 2;
          final displayAngle = isBack ? angle - pi : angle;
          return Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.0015)
              ..rotateY(displayAngle),
            child: isBack ? widget.back : widget.front,
          );
        },
      ),
    );
  }
}
