import 'dart:ui' as ui;
import 'package:flutter/material.dart';

// Ported from .blob-a/.blob-b/.blob-c + their @keyframes floatA/floatB/floatC in the original —
// flagged as missing back when this was first discussed (only the flat gradient had been
// ported). Same 3 blobs, same colors, same float durations (14s/18s/20s), same easing shape.
class AnimatedWallpaper extends StatefulWidget {
  final List<Color> gradientColors;
  const AnimatedWallpaper({super.key, required this.gradientColors});

  @override
  State<AnimatedWallpaper> createState() => _AnimatedWallpaperState();
}

class _AnimatedWallpaperState extends State<AnimatedWallpaper> with TickerProviderStateMixin {
  late final AnimationController _a;
  late final AnimationController _b;
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _a = AnimationController(vsync: this, duration: const Duration(seconds: 14))..repeat(reverse: true);
    _b = AnimationController(vsync: this, duration: const Duration(seconds: 18))..repeat(reverse: true);
    _c = AnimationController(vsync: this, duration: const Duration(seconds: 20))..repeat(reverse: true);
  }

  @override
  void dispose() {
    _a.dispose();
    _b.dispose();
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: widget.gradientColors),
            ),
          ),
        ),
        ClipRect(
          child: Stack(children: [
            _Blob(controller: _a, size: 260, left: -60, top: -40, dx: 50, dy: 70, scale: 1.15, color: const Color(0x808C9A5C)),
            _Blob(controller: _b, size: 300, right: -90, top: 220, dx: -40, dy: -60, scale: 1.2, color: const Color(0xBF193A24)),
            _Blob(controller: _c, size: 220, leftPercent: 0.2, bottom: -80, dx: 30, dy: -40, scale: 1.1, color: const Color(0x4DD9A62E)),
          ]),
        ),
      ],
    );
  }
}

class _Blob extends StatelessWidget {
  final AnimationController controller;
  final double size;
  final double? left;
  final double? right;
  final double? top;
  final double? bottom;
  final double? leftPercent; // for the one blob positioned by percentage in the original (20%)
  final double dx;
  final double dy;
  final double scale;
  final Color color;

  const _Blob({
    required this.controller,
    required this.size,
    this.left,
    this.right,
    this.top,
    this.bottom,
    this.leftPercent,
    required this.dx,
    required this.dy,
    required this.scale,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        final t = controller.value; // 0..1, reversing — same idea as the original's 0%→50%→100% keyframe
        final offset = Offset(dx * t, dy * t);
        final currentScale = 1 + (scale - 1) * t;
        Widget blob = Container(
          width: size,
          height: size,
          decoration: BoxDecoration(shape: BoxShape.circle, gradient: RadialGradient(colors: [color, color.withOpacity(0)])),
        );
        blob = Transform.translate(offset: offset, child: Transform.scale(scale: currentScale, child: blob));
        // ImageFiltered gives the same soft blur as the original's filter:blur(38px), without
        // needing a new package.
        blob = ImageFiltered(imageFilter: ui.ImageFilter.blur(sigmaX: 38, sigmaY: 38), child: blob);

        final resolvedLeft = leftPercent != null ? MediaQuery.of(context).size.width * leftPercent! : left;
        return Positioned(left: resolvedLeft, right: right, top: top, bottom: bottom, child: blob);
      },
    );
  }
}
