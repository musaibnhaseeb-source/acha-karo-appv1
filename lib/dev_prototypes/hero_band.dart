import 'dart:async';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'monuments.dart';

// Ported from the SVG <pattern id="ajrakLogo"> in the original — a repeating 22x22-unit tile:
// dark red background, a diamond outline connecting the tile's edge midpoints, and a small
// ring+dot motif at the tile's center. Scaled proportionally to whatever size it's painted at,
// same ratio as the original's 80x80 viewBox with 22x22 tiles.
class AjrakPatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final tile = size.width * (22 / 80);
    canvas.drawRect(Offset.zero & size, Paint()..color = const Color(0xFF7A1626));

    final diamondPaint = Paint()
      ..color = const Color(0xFFF0E6D2).withOpacity(0.4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = tile * (0.6 / 22);
    final ringPaint = Paint()
      ..color = const Color(0xFF1B2A45).withOpacity(0.85)
      ..style = PaintingStyle.stroke
      ..strokeWidth = tile * (0.7 / 22);
    final dotPaint = Paint()..color = const Color(0xFFF3D688);

    for (double y = -tile; y < size.height + tile; y += tile) {
      for (double x = -tile; x < size.width + tile; x += tile) {
        final path = Path()
          ..moveTo(x + tile * 0.5, y)
          ..lineTo(x + tile, y + tile * 0.5)
          ..lineTo(x + tile * 0.5, y + tile)
          ..lineTo(x, y + tile * 0.5)
          ..close();
        canvas.drawPath(path, diamondPaint);
        final center = Offset(x + tile * 0.5, y + tile * 0.5);
        canvas.drawCircle(center, tile * (3.4 / 22), ringPaint);
        canvas.drawCircle(center, tile * (1.2 / 22), dotPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// Ported from .marquee-wrap/.marquee-track — a continuously auto-scrolling strip of Pakistani
// monuments behind the logo. The original uses a pure-CSS keyframe (translateX 0 to -50% over
// 26s, with the content duplicated once for a seamless loop). Flutter has no CSS-keyframe
// equivalent, so this approximates it with a timer-driven auto-scroll instead — content is
// tripled (not just doubled) so the jump-back-to-0 at the wrap point is less noticeable, but it
// is a real jump, not a perfectly seamless loop like the original CSS technique achieves.
class MonumentMarquee extends StatefulWidget {
  const MonumentMarquee({super.key});
  @override
  State<MonumentMarquee> createState() => _MonumentMarqueeState();
}

class _MonumentMarqueeState extends State<MonumentMarquee> {
  final ScrollController _scrollController = ScrollController();
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _startScrolling());
  }

  void _startScrolling() {
    const frameMs = 16;
    const loopMs = 26000; // same 26s loop duration as the original CSS animation
    _timer = Timer.periodic(const Duration(milliseconds: frameMs), (_) {
      if (!_scrollController.hasClients) return;
      final max = _scrollController.position.maxScrollExtent;
      if (max <= 0) return;
      final oneSetWidth = max / 2; // content is tripled; scroll through one set's width, then jump back
      double next = _scrollController.offset + (oneSetWidth / (loopMs / frameMs));
      if (next >= oneSetWidth) next = 0;
      _scrollController.jumpTo(next);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final items = [...monuments, ...monuments, ...monuments];
    return IgnorePointer(
      child: ListView(
        controller: _scrollController,
        scrollDirection: Axis.horizontal,
        physics: const NeverScrollableScrollPhysics(),
        children: items.map(_buildItem).toList(),
      ),
    );
  }

  Widget _buildItem(Monument m) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: const BoxDecoration(border: Border(right: BorderSide(color: Color(0x24F6F5EC)))),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Text(m.icon, style: const TextStyle(fontSize: 13)),
          const SizedBox(width: 6),
          Text(m.name, style: AppFonts.plexMono(size: 10, weight: FontWeight.w600, color: AppColors.text)),
        ]),
      );
}

// Ported from .hero-band / .logo-mark — the marquee running behind a fixed logo square in the
// top-left, with the Ajrak pattern, a dark overlay, a radial vignette, a gold ring border, and
// the Urdu wordmark centered on top.
class HeroBand extends StatelessWidget {
  const HeroBand({super.key});
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 80,
      child: Stack(children: [
        Positioned.fill(
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0x66050A06),
              border: const Border.symmetric(horizontal: BorderSide(color: Color(0x24F6F5EC))),
            ),
            child: const MonumentMarquee(),
          ),
        ),
        const Positioned(left: 24, top: 0, width: 80, height: 80, child: _LogoMark()),
      ]),
    );
  }
}

class _LogoMark extends StatelessWidget {
  const _LogoMark();
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.6), blurRadius: 22, offset: const Offset(0, 12))],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(children: [
          CustomPaint(size: const Size(80, 80), painter: AjrakPatternPainter()),
          Container(color: const Color(0x85080303)), // .logo-darken
          Container(
            decoration: const BoxDecoration(
              gradient: RadialGradient(
                center: Alignment(0, -0.08),
                radius: 0.75,
                colors: [Color(0x800A0303), Color(0x400A0303), Color(0x0D0A0303)],
                stops: [0.0, 0.45, 0.75],
              ),
            ),
          ), // .logo-vignette
          Center(
            child: Padding(
              padding: const EdgeInsets.only(top: 5),
              child: Text('اچھا کرو', style: AppFonts.nastaliq(size: 17, color: const Color(0xFFF6F5EC))),
            ),
          ), // .logo-text
          Positioned.fill(
            child: Container(
              margin: const EdgeInsets.all(4),
              decoration: BoxDecoration(border: Border.all(color: const Color(0x8CF3D688)), borderRadius: BorderRadius.circular(14)),
            ),
          ), // .logo-ring
        ]),
      ),
    );
  }
}
