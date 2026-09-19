import 'package:flutter/material.dart';

// New — a real YouTube-branded visual (red rounded rectangle, white play triangle, matching the
// actual YouTube icon's proportions) instead of a generic ▶️ emoji, per direction. Shared here
// since it's used in both Hall of Fame and Limited Edition Items — one real widget, not
// duplicated styling in two places that could quietly drift apart later.
class YoutubeIcon extends StatelessWidget {
  final double size;
  const YoutubeIcon({super.key, this.size = 32});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size * 0.7,
      decoration: BoxDecoration(
        color: const Color(0xFFFF0000),
        borderRadius: BorderRadius.circular(size * 0.22),
      ),
      alignment: Alignment.center,
      child: CustomPaint(
        size: Size(size * 0.32, size * 0.32),
        painter: _PlayTrianglePainter(),
      ),
    );
  }
}

class _PlayTrianglePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, size.height / 2)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(path, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
