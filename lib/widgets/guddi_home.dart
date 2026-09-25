import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../data/guddi_content.dart';
import '../data/deed_catalog.dart';

// Guddi on Home: her pose + line follow the real time of day and the user's own deed history
// (done today? streak? away a while?). Presentation only — reads what AppState already has,
// writes nothing. Lines live in data/guddi_content.dart.

class GuddiPoses {
  static const _dir = 'assets/images/guddi';
  static const smile = '$_dir/guddi_smile.webp'; // big smile, open palms — Home default, welcome
  static const chatty = '$_dir/guddi_chatty.webp'; // excited, chatty — morning greeting
  static const curious = '$_dir/guddi_curious.webp'; // chin on fist — the idea card
  static const explain = '$_dir/guddi_explain.webp'; // holding chalk — tips
  static const cheer = '$_dir/guddi_cheer.webp'; // wink + thumbs up — thank-you, done today, milestones
  static const worried = '$_dir/guddi_worried.webp'; // gentle "haven't seen you" nudge
  static const frown = '$_dir/guddi_frown.webp'; // sparingly — only when today's deed was rejected
  static const rest = '$_dir/guddi_rest.webp'; // eyes closed — night / "rest well"
  static const strong = '$_dir/guddi_strong.webp'; // sword hilt — tier-up, big milestones
  static const power = '$_dir/guddi_power.webp'; // sword drawn, different art style — top tier ONLY

  static const homePoses = [smile, chatty, curious, cheer, worried, frown, rest];
  static const celebrationPoses = [cheer, strong, power];
}

class GuddiHomeMood {
  final String pose;
  final GuddiLine? line;
  final bool night;
  final int streak; // substituted into "{n}"
  const GuddiHomeMood(this.pose, this.line, {required this.night, this.streak = 0});

  String? get roman => line?.roman.replaceAll('{n}', '$streak');
  String? get en => line?.en?.replaceAll('{n}', '$streak');
}

// Home reads the time through this; always DateTime.now in the app. Only the dev preview in
// lib/dev_prototypes/ swaps it, to show morning / day / night without waiting for the clock.
DateTime Function() guddiClock = DateTime.now;

bool isNightHour(int hour) => hour >= 21 || hour < 5;

// Pure — unit-tested in test/guddi_home_mood_test.dart.
GuddiHomeMood pickGuddiHomeMood({
  required DateTime now,
  required bool historyLoaded,
  required bool needsFirstDeed,
  required bool doneToday, // an approved or pending deed today
  required bool rejectedTodayOnly, // deed(s) today, but every one was rejected
  required int streak,
  required int? daysSinceLast,
}) {
  final h = now.hour;
  final night = isNightHour(h);
  GuddiHomeMood m(String pose, GuddiLine? line) => GuddiHomeMood(pose, line, night: night, streak: streak);

  // History unknown yet — a friendly default, no claims about their day.
  if (!historyLoaded) return m(GuddiPoses.smile, null);

  if (doneToday) {
    if (night) return m(GuddiPoses.rest, GuddiLines.doneNight);
    if (streak >= 2) return m(GuddiPoses.cheer, GuddiLines.doneStreak);
    return m(GuddiPoses.cheer, GuddiLines.done);
  }
  if (needsFirstDeed) return m(GuddiPoses.smile, GuddiLines.firstDeed);
  if (rejectedTodayOnly) return m(GuddiPoses.frown, GuddiLines.rejectedToday);
  if (h < 5) return m(GuddiPoses.rest, GuddiLines.lateNight); // after midnight: no nudging
  if (daysSinceLast != null && daysSinceLast >= 3) return m(GuddiPoses.worried, GuddiLines.comeback);
  if (streak >= 2 && h < 21) return m(GuddiPoses.chatty, GuddiLines.streakAlive);
  if (h < 12) return m(GuddiPoses.chatty, GuddiLines.morning);
  if (h < 17) return m(GuddiPoses.smile, GuddiLines.day);
  return m(GuddiPoses.smile, GuddiLines.evening); // evening, and 9 pm–midnight (night treatment)
}

// ---------------------------------------------------------------------------------------------

/// Guddi with a soft backdrop: warm glow by day; at night a dim sky, moon and a few stars, with
/// Guddi herself dimmed a touch (same approved poses — no separate night art).
class GuddiFigure extends StatefulWidget {
  final String pose;
  final bool night;
  final double width;
  final double height;
  const GuddiFigure({super.key, required this.pose, required this.night, this.width = 104, this.height = 150});
  @override
  State<GuddiFigure> createState() => _GuddiFigureState();
}

class _GuddiFigureState extends State<GuddiFigure> with SingleTickerProviderStateMixin {
  late final AnimationController _bob = AnimationController(vsync: this, duration: const Duration(milliseconds: 1800))..repeat(reverse: true);

  @override
  void dispose() {
    _bob.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final w = widget.width, h = widget.height;
    // The rest pose is a slim full-body image and reads tiny at this size — show it larger,
    // cropped just above the knees with a soft fade, like the waist-up poses.
    final isRest = widget.pose == GuddiPoses.rest;
    final Widget image = isRest
        ? ClipRect(
            child: SizedBox(
              height: h - 8,
              child: OverflowBox(
                alignment: Alignment.topCenter,
                maxHeight: (h - 8) * 1.45,
                child: ShaderMask(
                  blendMode: BlendMode.dstIn,
                  shaderCallback: (r) => const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.white, Colors.white, Colors.transparent],
                    stops: [0, 0.55, 0.69],
                  ).createShader(r),
                  child: Image.asset(widget.pose, height: (h - 8) * 1.45, fit: BoxFit.contain, gaplessPlayback: true),
                ),
              ),
            ),
          )
        : Image.asset(widget.pose, height: h - 8, fit: BoxFit.contain, gaplessPlayback: true);
    return SizedBox(
      width: w,
      height: h,
      child: Stack(alignment: Alignment.bottomCenter, children: [
        // Backdrop
        Positioned(
          left: 4, right: 4, bottom: 0, top: h * 0.12,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 600),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(w),
              gradient: widget.night
                  ? const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFF141B33), Color(0xFF0A0F1E)])
                  : RadialGradient(colors: [AppColors.gold.withOpacity(0.28), AppColors.gold.withOpacity(0.0)]),
            ),
          ),
        ),
        if (widget.night) ...[
          const Positioned(top: 4, right: 6, child: Text('🌙', style: TextStyle(fontSize: 18))),
          for (final (l, t, s) in const [(14.0, 30.0, 3.0), (30.0, 12.0, 2.0), (80.0, 44.0, 2.0), (20.0, 62.0, 2.0)])
            Positioned(
              left: l, top: t,
              child: Container(width: s, height: s, decoration: BoxDecoration(shape: BoxShape.circle, color: AppColors.text.withOpacity(0.7))),
            ),
        ],
        // Guddi, gently floating; cross-fades when her pose changes.
        AnimatedBuilder(
          animation: _bob,
          builder: (_, child) => Transform.translate(offset: Offset(0, -3 * Curves.easeInOut.transform(_bob.value)), child: child),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 350),
            child: KeyedSubtree(
              key: ValueKey('${widget.pose}|${widget.night}'),
              child: widget.night
                  ? ColorFiltered(
                      // Slight dim + cool tint for night.
                      colorFilter: const ColorFilter.matrix([
                        0.78, 0, 0, 0, 0,
                        0, 0.80, 0, 0, 0,
                        0, 0, 0.92, 0, 6,
                        0, 0, 0, 1, 0,
                      ]),
                      child: image,
                    )
                  : image,
            ),
          ),
        ),
      ]),
    );
  }
}

// ---------------------------------------------------------------------------------------------

/// Today's idea: rotates daily through [achaKaamIdeas], skipping any whose deed is cooling down.
AchaKaamIdea pickTodaysIdea(DateTime today, bool Function(String deedType) onCooldown) {
  final ideas = achaKaamIdeas.where((i) => deedCatalog.containsKey(i.deedType)).toList();
  final dayIndex = DateTime.utc(today.year, today.month, today.day).difference(DateTime.utc(2026, 1, 1)).inDays;
  final start = dayIndex % ideas.length;
  for (var k = 0; k < ideas.length; k++) {
    final idea = ideas[(start + k) % ideas.length];
    if (!onCooldown(idea.deedType)) return idea;
  }
  return ideas[start];
}

// ---------------------------------------------------------------------------------------------

/// Guddi popping in (elastic scale) for the thank-you / milestone / tier-up celebrations. Sized
/// off the screen height so short phones still show her whole.
class GuddiPopIn extends StatelessWidget {
  final String pose;
  final double screenFraction;
  final double maxHeight;
  const GuddiPopIn({super.key, required this.pose, this.screenFraction = 0.26, this.maxHeight = 210});

  @override
  Widget build(BuildContext context) {
    final h = (MediaQuery.of(context).size.height * screenFraction).clamp(110.0, maxHeight);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.4, end: 1),
      duration: const Duration(milliseconds: 650),
      curve: Curves.elasticOut,
      builder: (_, v, child) => Transform.scale(scale: v, child: Opacity(opacity: ((v - 0.4) / 0.6).clamp(0.0, 1.0), child: child)),
      // Most poses are cropped flat at the waist — fade the bottom edge so they don't end in a
      // hard line over the dimmed screen.
      child: ShaderMask(
        blendMode: BlendMode.dstIn,
        shaderCallback: (r) => const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.white, Colors.white, Colors.transparent],
          stops: [0, 0.8, 1],
        ).createShader(r),
        child: Image.asset(pose, height: h, fit: BoxFit.contain),
      ),
    );
  }
}

/// Roman Urdu line + optional English subtitle, for the celebrations.
class GuddiCaption extends StatelessWidget {
  final GuddiLine line;
  const GuddiCaption(this.line, {super.key});
  @override
  Widget build(BuildContext context) {
    // Own dark pill — the celebration overlays are see-through, so bare text would sit on Home.
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 28),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(color: AppColors.bg1.withOpacity(0.9), borderRadius: BorderRadius.circular(14)),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text(line.roman, textAlign: TextAlign.center, style: AppFonts.inter(size: 14, weight: FontWeight.w600)),
        if (line.en != null) ...[
          const SizedBox(height: 2),
          Text(line.en!, textAlign: TextAlign.center, style: AppFonts.inter(size: 11, color: AppColors.textSoft)),
        ],
      ]),
    );
  }
}
