import 'dart:async';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../data/guddi_content.dart';
import 'guddi_home.dart';

// Cold-start loading screen: Guddi plus one Roman Urdu line (English below it) ending in three
// animated dots, in place of a spinner. After [slowAfter] the line switches to the "taking a
// while" one. With reduced motion (system "remove animations") the dots stay static. Lines live
// in data/guddi_content.dart (GuddiLoadingLines). Presentation only: reads and writes nothing.
// With [onRetry] set it shows the offline state instead (M1): no dots, a Retry button.
class GuddiLoading extends StatefulWidget {
  final bool returning; // signed in (saved session) vs first open / signed out
  final Duration slowAfter;
  final VoidCallback? onRetry; // non-null = the load failed; show the offline state
  const GuddiLoading({super.key, required this.returning, this.slowAfter = const Duration(seconds: 5), this.onRetry});
  @override
  State<GuddiLoading> createState() => _GuddiLoadingState();
}

class _GuddiLoadingState extends State<GuddiLoading> {
  Timer? _dotsTimer;
  Timer? _slowTimer;
  int _dots = 3;
  bool _slow = false;

  @override
  void initState() {
    super.initState();
    _slowTimer = Timer(widget.slowAfter, () {
      if (mounted) setState(() => _slow = true);
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Re-checked on every dependency change, so turning "remove animations" on or off takes effect.
    final reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (reduceMotion) {
      _dotsTimer?.cancel();
      _dotsTimer = null;
      _dots = 3;
    } else {
      _dotsTimer ??= Timer.periodic(const Duration(milliseconds: 450), (_) {
        if (mounted && widget.onRetry == null) setState(() => _dots = _dots % 3 + 1);
      });
    }
  }

  @override
  void dispose() {
    _dotsTimer?.cancel();
    _slowTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.onRetry != null) return _offline(widget.onRetry!);
    final line = _slow ? GuddiLoadingLines.slow : (widget.returning ? GuddiLoadingLines.returning : GuddiLoadingLines.firstOpen);
    final style = AppFonts.fraunces(size: 15, weight: FontWeight.w600, height: 1.35);
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Image.asset(GuddiPoses.smile, height: 150, fit: BoxFit.contain),
          const SizedBox(height: 18),
          Semantics(
            liveRegion: true,
            label: line.roman,
            child: ExcludeSemantics(
              child: Text.rich(
                TextSpan(children: [
                  TextSpan(text: line.roman),
                  // All three dots are always laid out; the hidden ones are transparent, so the
                  // line never shifts or re-wraps as they animate.
                  for (var i = 0; i < 3; i++)
                    TextSpan(text: '.', style: i < _dots ? null : const TextStyle(color: Colors.transparent)),
                ]),
                key: const ValueKey('guddi-loading-line'),
                textAlign: TextAlign.center,
                style: style,
              ),
            ),
          ),
          if (line.en != null) ...[
            const SizedBox(height: 6),
            Text(line.en!, textAlign: TextAlign.center, style: AppFonts.inter(size: 12.5, color: AppColors.textSoft, height: 1.4)),
          ],
        ]),
      ),
    );
  }

  Widget _offline(VoidCallback onRetry) {
    const line = GuddiLoadingLines.offline;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          // The worried pose is a bust crop cut flat at the bottom edge, which reads as a box on
          // the dark wallpaper; fading its lower part out blends it in like the other poses.
          ShaderMask(
            blendMode: BlendMode.dstIn,
            shaderCallback: (rect) => const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.white, Colors.white, Colors.transparent],
              stops: [0, 0.6, 1],
            ).createShader(rect),
            child: Image.asset(GuddiPoses.worried, height: 150, fit: BoxFit.contain),
          ),
          const SizedBox(height: 18),
          Semantics(
            liveRegion: true,
            child: Text(line.roman, key: const ValueKey('guddi-offline-line'), textAlign: TextAlign.center, style: AppFonts.fraunces(size: 15, weight: FontWeight.w600, height: 1.35)),
          ),
          const SizedBox(height: 18),
          GestureDetector(
            key: const ValueKey('guddi-offline-retry'),
            onTap: onRetry,
            child: Semantics(
              button: true,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
                decoration: BoxDecoration(color: AppColors.gold, borderRadius: BorderRadius.circular(14)),
                child: Text(GuddiLoadingLines.retry, style: AppFonts.inter(size: 14, weight: FontWeight.w700, color: AppColors.inkOnGold)),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}
