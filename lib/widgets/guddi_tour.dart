import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

// First-deed onboarding — a short, skippable Guddi-guided tour over Home. Purely presentational:
// it reads nothing and writes nothing (the caller decides when to show it and remembers the
// outcome locally via OnboardingStore). Built only from Flutter's own animation primitives.

enum GuddiTourResult { cta, later, skipped }

class GuddiTourStep {
  final GlobalKey? target; // widget to spotlight; null = centred Guddi, no spotlight
  final String image; // asset path
  final String? leadEn; // optional extra first line (the returning-user "Welcome back!")
  final String? leadUr; // its Urdu, shown under the Urdu body line
  final String en;
  final String ur;
  const GuddiTourStep({this.target, required this.image, this.leadEn, this.leadUr, required this.en, required this.ur});
}

// Pushed as a transparent route over Home, so the real screen stays visible (and scrollable to
// bring a target into view) underneath the dimmed overlay. The Android back button counts as Skip.
Future<GuddiTourResult> showGuddiTour(BuildContext context, List<GuddiTourStep> steps) async {
  final result = await Navigator.of(context).push<GuddiTourResult>(
    PageRouteBuilder<GuddiTourResult>(
      opaque: false,
      barrierDismissible: false,
      transitionDuration: const Duration(milliseconds: 250),
      reverseTransitionDuration: const Duration(milliseconds: 200),
      pageBuilder: (_, __, ___) => _GuddiTour(steps: steps),
      transitionsBuilder: (_, anim, __, child) => FadeTransition(opacity: anim, child: child),
    ),
  );
  return result ?? GuddiTourResult.skipped;
}

class _GuddiTour extends StatefulWidget {
  final List<GuddiTourStep> steps;
  const _GuddiTour({required this.steps});
  @override
  State<_GuddiTour> createState() => _GuddiTourState();
}

class _GuddiTourState extends State<_GuddiTour> with TickerProviderStateMixin {
  late final AnimationController _enter; // per-step slide/fade-in
  late final AnimationController _bob; // gentle idle float, loops
  int _index = 0;
  Rect? _hole;
  bool _measuring = false;

  GuddiTourStep get _step => widget.steps[_index];
  bool get _isLast => _index == widget.steps.length - 1;

  @override
  void initState() {
    super.initState();
    _enter = AnimationController(vsync: this, duration: const Duration(milliseconds: 420));
    _bob = AnimationController(vsync: this, duration: const Duration(milliseconds: 1600))..repeat(reverse: true);
    WidgetsBinding.instance.addPostFrameCallback((_) => _showStep(0));
  }

  @override
  void dispose() {
    _enter.dispose();
    _bob.dispose();
    super.dispose();
  }

  Future<void> _showStep(int i) async {
    setState(() {
      _index = i;
      _hole = null;
      _measuring = widget.steps[i].target != null;
    });
    final targetContext = widget.steps[i].target?.currentContext;
    if (targetContext != null) {
      // Scrolls Home (underneath) so the target is on screen before the spotlight lands on it.
      await Scrollable.ensureVisible(targetContext, duration: const Duration(milliseconds: 350), alignment: 0.3);
      await WidgetsBinding.instance.endOfFrame;
      if (!mounted) return;
      final box = targetContext.mounted ? targetContext.findRenderObject() as RenderBox? : null;
      if (box != null && box.hasSize && box.attached) {
        final origin = box.localToGlobal(Offset.zero);
        _hole = (origin & box.size).inflate(8);
      }
    }
    if (!mounted) return;
    setState(() => _measuring = false);
    _enter.forward(from: 0);
  }

  void _next() {
    if (_isLast) return;
    _showStep(_index + 1);
  }

  void _finish(GuddiTourResult r) => Navigator.of(context).pop(r);

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final hole = _hole;
    // Content sits on whichever half of the screen the spotlight ISN'T in.
    final contentAtTop = hole != null && hole.center.dy > size.height * 0.55;

    return Material(
        type: MaterialType.transparency,
        child: Stack(children: [
          // Dim layer with a cut-out; also swallows taps so Home can't be used mid-tour.
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {},
              child: CustomPaint(painter: _SpotlightPainter(hole: hole)),
            ),
          ),
          if (!_measuring)
            Positioned(
              left: 16,
              right: 16,
              top: contentAtTop ? MediaQuery.of(context).padding.top + 56 : null,
              bottom: contentAtTop ? null : MediaQuery.of(context).padding.bottom + 24,
              child: hole == null ? _centredContent(size) : _sideContent(),
            ),
          // Skip — top right, every step.
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            right: 8,
            child: TextButton(
              onPressed: () => _finish(GuddiTourResult.skipped),
              child: Text('Skip', style: AppFonts.inter(size: 13.5, weight: FontWeight.w700, color: AppColors.textSoft)),
            ),
          ),
        ]),
    );
  }

  // No spotlight: big Guddi in the middle, card underneath.
  Widget _centredContent(Size size) {
    return Column(mainAxisSize: MainAxisSize.min, children: [
      _animatedGuddi(height: math.min(260, size.height * 0.32), fromLeft: false),
      const SizedBox(height: 12),
      _animatedCard(),
    ]);
  }

  // Spotlight on something: smaller Guddi beside the card. Her width is capped so the card keeps
  // enough room on narrow phones (some poses are nearly square).
  Widget _sideContent() {
    final maxGuddiWidth = MediaQuery.of(context).size.width * 0.28;
    return Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
      ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxGuddiWidth),
        child: _animatedGuddi(height: 170, fromLeft: true),
      ),
      const SizedBox(width: 8),
      Expanded(child: _animatedCard()),
    ]);
  }

  Widget _animatedGuddi({required double height, required bool fromLeft}) {
    final slide = Tween<Offset>(begin: fromLeft ? const Offset(-0.6, 0) : const Offset(0, 0.25), end: Offset.zero)
        .animate(CurvedAnimation(parent: _enter, curve: Curves.easeOutBack));
    return FadeTransition(
      opacity: _enter,
      child: SlideTransition(
        position: slide,
        child: AnimatedBuilder(
          animation: _bob,
          builder: (_, child) => Transform.translate(
            offset: Offset(0, -6 * Curves.easeInOut.transform(_bob.value)),
            child: child,
          ),
          child: Image.asset(_step.image, height: height, fit: BoxFit.contain, gaplessPlayback: true),
        ),
      ),
    );
  }

  Widget _animatedCard() {
    final slide = Tween<Offset>(begin: const Offset(0, 0.15), end: Offset.zero)
        .animate(CurvedAnimation(parent: _enter, curve: const Interval(0.15, 1, curve: Curves.easeOutCubic)));
    return FadeTransition(
      opacity: CurvedAnimation(parent: _enter, curve: const Interval(0.15, 1)),
      child: SlideTransition(position: slide, child: _card()),
    );
  }

  Widget _card() {
    final step = _step;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
      decoration: BoxDecoration(
        color: AppColors.bg2,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.gold.withOpacity(0.45)),
        boxShadow: const [BoxShadow(color: Color(0x66000000), blurRadius: 18, offset: Offset(0, 8))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
        if (step.leadEn != null) ...[
          Text(step.leadEn!, style: AppFonts.inter(size: 13, weight: FontWeight.w700, color: AppColors.gold, height: 1.35)),
          const SizedBox(height: 4),
        ],
        Text(step.en, style: AppFonts.inter(size: 15, weight: FontWeight.w600, color: AppColors.text, height: 1.35)),
        const SizedBox(height: 6),
        if (step.leadUr != null)
          Text(
            step.leadUr!,
            textDirection: TextDirection.rtl,
            textAlign: TextAlign.right,
            style: AppFonts.nastaliq(size: 16, color: AppColors.gold),
          ),
        Text(
          step.ur,
          textDirection: TextDirection.rtl,
          textAlign: TextAlign.right,
          style: AppFonts.nastaliq(size: 17, color: AppColors.textSoft),
        ),
        const SizedBox(height: 12),
        if (_isLast) ...[
          _PrimaryButton(label: 'Do my first deed', onTap: () => _finish(GuddiTourResult.cta)),
          const SizedBox(height: 4),
          Center(
            child: TextButton(
              onPressed: () => _finish(GuddiTourResult.later),
              child: Text('Later', style: AppFonts.inter(size: 13, weight: FontWeight.w600, color: AppColors.textSoft)),
            ),
          ),
        ] else
          Row(children: [
            Flexible(child: _Dots(count: widget.steps.length, index: _index)),
            const SizedBox(width: 8),
            _PrimaryButton(label: 'Next', compact: true, onTap: _next),
          ]),
      ]),
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final bool compact;
  const _PrimaryButton({required this.label, required this.onTap, this.compact = false});
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: compact ? 22 : 16, vertical: compact ? 10 : 13),
        decoration: BoxDecoration(color: AppColors.gold, borderRadius: BorderRadius.circular(compact ? 100 : 14)),
        alignment: compact ? null : Alignment.center,
        child: Text(label, style: AppFonts.inter(size: compact ? 13.5 : 15, weight: FontWeight.w700, color: AppColors.inkOnGold)),
      ),
    );
  }
}

class _Dots extends StatelessWidget {
  final int count;
  final int index;
  const _Dots({required this.count, required this.index});
  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(count, (i) {
        final active = i == index;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.only(right: 5),
          width: active ? 16 : 6,
          height: 6,
          decoration: BoxDecoration(color: active ? AppColors.gold : AppColors.textSoft.withOpacity(0.35), borderRadius: BorderRadius.circular(100)),
        );
      }),
    );
  }
}

class _SpotlightPainter extends CustomPainter {
  final Rect? hole;
  _SpotlightPainter({required this.hole});

  @override
  void paint(Canvas canvas, Size size) {
    final dim = Paint()..color = const Color(0xC7050B06);
    final full = Path()..addRect(Offset.zero & size);
    if (hole == null) {
      canvas.drawPath(full, dim);
      return;
    }
    final rrect = RRect.fromRectAndRadius(hole!, const Radius.circular(16));
    final cut = Path()..addRRect(rrect);
    canvas.drawPath(Path.combine(PathOperation.difference, full, cut), dim);
    canvas.drawRRect(
      rrect,
      Paint()
        ..color = AppColors.gold
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  @override
  bool shouldRepaint(_SpotlightPainter old) => old.hole != hole;
}
