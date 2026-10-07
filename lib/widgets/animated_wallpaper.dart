import 'dart:ui' as ui;
import 'package:flutter/material.dart';

// Ported from .blob-a/.blob-b/.blob-c + their @keyframes floatA/floatB/floatC in the original —
// flagged as missing back when this was first discussed (only the flat gradient had been
// ported). Same 3 blobs, same colors, same float durations (14s/18s/20s), same easing shape.
//
// Performance: each blob's blur (sigma 38, like the original's filter:blur(38px)) is rendered
// ONCE into a small image when the wallpaper is created; every frame after that only moves and
// scales that image. It used to re-run three large blurs on every frame (60 times a second, for
// as long as the app was open), and the whole screen repainted with it. A RepaintBoundary now
// keeps the wallpaper's animation from repainting the content drawn on top of it.
class AnimatedWallpaper extends StatefulWidget {
  final List<Color> gradientColors;
  const AnimatedWallpaper({super.key, required this.gradientColors});

  @override
  State<AnimatedWallpaper> createState() => _AnimatedWallpaperState();
}

class _BlobSpec {
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
  const _BlobSpec({required this.size, this.left, this.right, this.top, this.bottom, this.leftPercent, required this.dx, required this.dy, required this.scale, required this.color});
}

const _blobs = [
  _BlobSpec(size: 260, left: -60, top: -40, dx: 50, dy: 70, scale: 1.15, color: Color(0x808C9A5C)),
  _BlobSpec(size: 300, right: -90, top: 220, dx: -40, dy: -60, scale: 1.2, color: Color(0xBF193A24)),
  _BlobSpec(size: 220, leftPercent: 0.2, bottom: -80, dx: 30, dy: -40, scale: 1.1, color: Color(0x4DD9A62E)),
];

const double _blurSigma = 38;
// A gaussian blur visibly reaches ~3 sigma past the circle's edge.
const double _blurPad = _blurSigma * 3;

// The blurred blob, drawn once. Rendered at 1 image pixel per logical pixel: the content is a
// very soft blur with no edges or detail, so upscaling it on high-density screens looks the same
// as rendering it at full density, at a fraction of the memory (~1 MB per blob instead of ~10).
ui.Image _renderBlurredBlob(_BlobSpec b) {
  final extent = b.size + _blurPad * 2;
  final center = Offset(extent / 2, extent / 2);
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  final paint = Paint()
    ..shader = RadialGradient(colors: [b.color, b.color.withOpacity(0)]).createShader(Rect.fromCircle(center: center, radius: b.size / 2))
    ..imageFilter = ui.ImageFilter.blur(sigmaX: _blurSigma, sigmaY: _blurSigma);
  canvas.drawCircle(center, b.size / 2, paint);
  final picture = recorder.endRecording();
  final image = picture.toImageSync(extent.ceil(), extent.ceil());
  picture.dispose();
  return image;
}

class _AnimatedWallpaperState extends State<AnimatedWallpaper> with TickerProviderStateMixin {
  late final List<AnimationController> _controllers;
  late final List<ui.Image> _images;

  @override
  void initState() {
    super.initState();
    _controllers = [
      AnimationController(vsync: this, duration: const Duration(seconds: 14))..repeat(reverse: true),
      AnimationController(vsync: this, duration: const Duration(seconds: 18))..repeat(reverse: true),
      AnimationController(vsync: this, duration: const Duration(seconds: 20))..repeat(reverse: true),
    ];
    _images = [for (final b in _blobs) _renderBlurredBlob(b)];
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    for (final i in _images) {
      i.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: Stack(
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
              for (var i = 0; i < _blobs.length; i++) _Blob(controller: _controllers[i], spec: _blobs[i], image: _images[i]),
            ]),
          ),
        ],
      ),
    );
  }
}

class _Blob extends StatelessWidget {
  final AnimationController controller;
  final _BlobSpec spec;
  final ui.Image image;
  const _Blob({required this.controller, required this.spec, required this.image});

  @override
  Widget build(BuildContext context) {
    final extent = spec.size + _blurPad * 2;
    // Laid out at the circle's size, exactly as before; the blur spills past it on every side.
    final blurred = SizedBox(
      width: spec.size,
      height: spec.size,
      child: OverflowBox(
        minWidth: extent,
        maxWidth: extent,
        minHeight: extent,
        maxHeight: extent,
        child: RawImage(image: image, width: extent, height: extent, fit: BoxFit.fill, filterQuality: FilterQuality.low),
      ),
    );
    final resolvedLeft = spec.leftPercent != null ? MediaQuery.of(context).size.width * spec.leftPercent! : spec.left;
    return Positioned(
      left: resolvedLeft,
      right: spec.right,
      top: spec.top,
      bottom: spec.bottom,
      child: AnimatedBuilder(
        animation: controller,
        child: blurred,
        builder: (context, child) {
          final t = controller.value; // 0..1, reversing — same idea as the original's 0%→50%→100% keyframe
          return Transform.translate(
            offset: Offset(spec.dx * t, spec.dy * t),
            child: Transform.scale(scale: 1 + (spec.scale - 1) * t, child: child),
          );
        },
      ),
    );
  }
}
