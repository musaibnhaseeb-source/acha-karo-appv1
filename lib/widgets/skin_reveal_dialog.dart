import 'dart:math';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'campaign_icon.dart';

// New — real confetti + skin reveal, shown when a skin is actually redeemed. Built with
// Flutter's own AnimationController/CustomPainter rather than a new third-party confetti
// package, keeping this consistent with how carefully new dependencies have been treated
// throughout this project — no new pubspec entry needed for this.
class _ConfettiPiece {
  final double startX;
  final double fallSpeed;
  final double swayAmount;
  final double swaySpeed;
  final double rotationSpeed;
  final Color color;
  final double size;
  _ConfettiPiece({required this.startX, required this.fallSpeed, required this.swayAmount, required this.swaySpeed, required this.rotationSpeed, required this.color, required this.size});
}

class _ConfettiPainter extends CustomPainter {
  final List<_ConfettiPiece> pieces;
  final double progress; // 0..1
  _ConfettiPainter(this.pieces, this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    for (final piece in pieces) {
      final y = piece.fallSpeed * progress * size.height * 1.3 - 40;
      if (y < -20 || y > size.height + 20) continue;
      final x = piece.startX * size.width + sin(progress * piece.swaySpeed * 2 * pi) * piece.swayAmount;
      final rotation = progress * piece.rotationSpeed * 2 * pi;

      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(rotation);
      final paint = Paint()..color = piece.color.withOpacity((1 - progress * 0.3).clamp(0.0, 1.0));
      canvas.drawRect(Rect.fromCenter(center: Offset.zero, width: piece.size, height: piece.size * 0.5), paint);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _ConfettiPainter oldDelegate) => oldDelegate.progress != progress;
}

// Real, public entry point — call this after a genuine, successful redemption.
Future<void> showSkinRevealDialog(BuildContext context, {required String icon, required String name}) {
  return showDialog(
    context: context,
    barrierDismissible: true,
    barrierColor: Colors.black.withOpacity(0.75),
    builder: (context) => _SkinRevealDialog(icon: icon, name: name),
  );
}

class _SkinRevealDialog extends StatefulWidget {
  final String icon;
  final String name;
  const _SkinRevealDialog({required this.icon, required this.name});

  @override
  State<_SkinRevealDialog> createState() => _SkinRevealDialogState();
}

class _SkinRevealDialogState extends State<_SkinRevealDialog> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late List<_ConfettiPiece> _pieces;

  @override
  void initState() {
    super.initState();
    final rand = Random();
    const colors = [AppColors.gold, AppColors.olive, Color(0xFF5B8FA8), Color(0xFFE39B84)];
    _pieces = List.generate(45, (i) => _ConfettiPiece(
          startX: rand.nextDouble(),
          fallSpeed: 0.7 + rand.nextDouble() * 0.5,
          swayAmount: 20 + rand.nextDouble() * 30,
          swaySpeed: 1 + rand.nextDouble() * 2,
          rotationSpeed: 1 + rand.nextDouble() * 3,
          color: colors[rand.nextInt(colors.length)],
          size: 6 + rand.nextDouble() * 6,
        ));
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 2200))..forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(24),
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          // Confetti layer, sized to a generous area above and around the card itself.
          SizedBox(
            width: 340,
            height: 420,
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, _) => CustomPaint(painter: _ConfettiPainter(_pieces, _controller.value), size: const Size(340, 420)),
            ),
          ),
          // The actual reveal card, with its own small scale-in for a bit of real weight to the
          // moment, separate from the confetti's own timing.
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.7, end: 1.0),
            duration: const Duration(milliseconds: 500),
            curve: Curves.elasticOut,
            builder: (context, scale, child) => Transform.scale(scale: scale, child: child),
            child: Container(
              width: 260,
              padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
              decoration: BoxDecoration(
                color: AppColors.bg2,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: AppColors.gold, width: 2),
                boxShadow: [BoxShadow(color: AppColors.gold.withOpacity(0.35), blurRadius: 30, spreadRadius: 4)],
              ),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Text('YOU GOT A NEW SKIN', style: AppFonts.plexMono(size: 10, weight: FontWeight.w700, color: AppColors.gold).copyWith(letterSpacing: 1)),
                const SizedBox(height: 20),
                CampaignIcon(icon: widget.icon, size: 64),
                const SizedBox(height: 16),
                Text(widget.name, textAlign: TextAlign.center, style: AppFonts.fraunces(size: 18, weight: FontWeight.w600)),
                const SizedBox(height: 24),
                GestureDetector(
                  onTap: () => Navigator.of(context).pop(),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
                    decoration: BoxDecoration(color: AppColors.gold, borderRadius: BorderRadius.circular(100)),
                    child: Text('Nice!', style: AppFonts.inter(size: 13, weight: FontWeight.w700, color: AppColors.inkOnGold)),
                  ),
                ),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}
