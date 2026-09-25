import 'dart:math' as math;
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
  // The original onboarding set, back in day-to-day rotation through the pools below.
  static const wink = '$_dir/guddi_wink.webp'; // close-up wink + thumbs up
  static const proud = '$_dir/guddi_proud.webp'; // sunglasses, arms crossed (slim full body)
  static const pointPhone = '$_dir/guddi_point_phone.webp'; // pointing at the Acha Karo app
  static const showPhone = '$_dir/guddi_show_phone.webp'; // holding the app up (slim full body)
  // guddi_small (walking / shrug) stays in the first-deed picker, bubble and reminder ask only.

  // POSE POOLS — each moment rotates through a few poses that fit it (Musa: "different images can
  // appear randomly"). Moments where the emotion matters (worried, rest, frown, strong, power)
  // stay fixed.
  static const happyPool = [smile, chatty, wink, proud, showPhone]; // Home header, everyday
  static const cheerPool = [cheer, wink, proud]; // done today, thank-you, 3-deed milestone
  static const ideaPool = [curious, explain, pointPhone]; // idea-card avatar

  // Slim full-body poses read tiny at header size — shown larger, cropped above the knees.
  static const tallPoses = {rest, proud, showPhone};

  static const homePoses = [smile, chatty, wink, proud, showPhone, curious, explain, pointPhone, cheer, worried, frown, rest];
  static const celebrationPoses = [cheer, wink, proud, strong, power];
}

// Picked once per app open, so Guddi's pose is random between opens but never flickers on
// rebuilds. Tapping her steps through the pool from there.
final int guddiSessionSeed = math.Random().nextInt(1 << 20);

String pickFromPool(List<String> pool, {int offset = 0}) => pool[(guddiSessionSeed + offset) % pool.length];

/// A fresh random pick — for one-off moments like a celebration overlay (chosen once when it opens).
String randomFromPool(List<String> pool) => pool[math.Random().nextInt(pool.length)];

class GuddiHomeMood {
  final List<String> pool; // poses that fit this moment (one = fixed)
  final GuddiLine? line;
  final bool night;
  final int streak; // substituted into "{n}"
  const GuddiHomeMood(this.pool, this.line, {required this.night, this.streak = 0});

  /// Stable for this app open; [offset] = how many times the user has tapped Guddi.
  String poseAt(int offset) => pickFromPool(pool, offset: offset);
  String get pose => poseAt(0);

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
  GuddiHomeMood m(List<String> pool, GuddiLine? line) => GuddiHomeMood(pool, line, night: night, streak: streak);

  // History unknown yet — a friendly default, no claims about their day.
  if (!historyLoaded) return m(GuddiPoses.happyPool, null);

  if (doneToday) {
    if (night) return m(const [GuddiPoses.rest], GuddiLines.doneNight);
    if (streak >= 2) return m(GuddiPoses.cheerPool, GuddiLines.doneStreak);
    return m(GuddiPoses.cheerPool, GuddiLines.done);
  }
  if (needsFirstDeed) return m(GuddiPoses.happyPool, GuddiLines.firstDeed);
  if (rejectedTodayOnly) return m(const [GuddiPoses.frown], GuddiLines.rejectedToday);
  if (h < 5) return m(const [GuddiPoses.rest], GuddiLines.lateNight); // after midnight: no nudging
  if (daysSinceLast != null && daysSinceLast >= 3) return m(const [GuddiPoses.worried], GuddiLines.comeback);
  if (streak >= 2 && h < 21) return m(GuddiPoses.happyPool, GuddiLines.streakAlive);
  if (h < 12) return m(GuddiPoses.happyPool, GuddiLines.morning);
  if (h < 17) return m(GuddiPoses.happyPool, GuddiLines.day);
  return m(GuddiPoses.happyPool, GuddiLines.evening); // evening, and 9 pm–midnight (night treatment)
}

// ---------------------------------------------------------------------------------------------

/// Speech bubble (left) + Guddi (right). The bubble's tail points at her. Tap or swipe Guddi to
/// see the next pose in the current pool (no auto-rotation).
class GuddiHomeHeader extends StatelessWidget {
  final GuddiHomeMood mood;
  final Widget nameBlock; // name + membership number, above the bubble
  final int poseOffset;
  final VoidCallback? onCyclePose;
  const GuddiHomeHeader({super.key, required this.mood, required this.nameBlock, this.poseOffset = 0, this.onCyclePose});

  @override
  Widget build(BuildContext context) {
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          nameBlock,
          if (mood.roman != null) ...[
            const SizedBox(height: 10),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: _SpeechBubble(key: ValueKey(mood.roman), roman: mood.roman!, en: mood.en),
            ),
          ],
        ]),
      ),
      const SizedBox(width: 6),
      if (mood.pool.length > 1 && onCyclePose != null)
        Semantics(
          button: true,
          label: 'Guddi. Tap to see another pose.',
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onCyclePose,
            onHorizontalDragEnd: (_) => onCyclePose!(),
            child: GuddiFigure(pose: mood.poseAt(poseOffset), night: mood.night),
          ),
        )
      else
        GuddiFigure(pose: mood.poseAt(poseOffset), night: mood.night),
    ]);
  }
}

class _SpeechBubble extends StatelessWidget {
  final String roman;
  final String? en;
  const _SpeechBubble({super.key, required this.roman, this.en});

  @override
  Widget build(BuildContext context) {
    const border = Color(0x73D9A62E); // gold @ 45%
    return Stack(clipBehavior: Clip.none, children: [
      Container(
        margin: const EdgeInsets.only(right: 6),
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
        decoration: BoxDecoration(color: AppColors.bg2, borderRadius: BorderRadius.circular(14), border: Border.all(color: border)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(roman, style: AppFonts.inter(size: 13, weight: FontWeight.w500, height: 1.35)),
          if (en != null) ...[
            const SizedBox(height: 3),
            Text(en!, style: AppFonts.inter(size: 10.5, color: AppColors.textSoft, height: 1.3)),
          ],
        ]),
      ),
      // Tail, pointing right at Guddi.
      Positioned(
        right: 0,
        top: 16,
        child: Transform.rotate(
          angle: 0.785398, // 45°
          child: Container(
            width: 12,
            height: 12,
            decoration: const BoxDecoration(
              color: AppColors.bg2,
              border: Border(top: BorderSide(color: border), right: BorderSide(color: border)),
            ),
          ),
        ),
      ),
    ]);
  }
}

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
    // Slim full-body poses (rest, proud, show-phone) read tiny at this size — show them larger,
    // cropped just above the knees with a soft fade, like the waist-up poses.
    final isTall = GuddiPoses.tallPoses.contains(widget.pose);
    final Widget image = isTall
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

/// "THIS WEEK" card: Mon–Sun circles from the user's own deed days, plus the real streak.
class WeekRowCard extends StatelessWidget {
  final List<DateTime> weekDays; // Mon..Sun
  final Set<DateTime> activeDays;
  final DateTime today; // date-only
  final int streak;
  const WeekRowCard({super.key, required this.weekDays, required this.activeDays, required this.today, required this.streak});

  static const _letters = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
      decoration: BoxDecoration(color: AppColors.bg2, borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0x14F6F5EC))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text('THIS WEEK', style: AppFonts.plexMono(size: 9)),
          // Hidden at 0 — never a "0 day streak".
          if (streak > 0) Text('🔥 $streak day streak', style: AppFonts.plexMono(size: 10.5, color: AppColors.gold)),
        ]),
        const SizedBox(height: 8),
        LayoutBuilder(builder: (context, c) {
          final size = ((c.maxWidth - 6 * 6) / 7).clamp(26.0, 36.0);
          return Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            for (var i = 0; i < 7; i++) _dayCircle(i, size),
          ]);
        }),
      ]),
    );
  }

  Widget _dayCircle(int i, double size) {
    final day = weekDays[i];
    final done = activeDays.contains(day);
    final isToday = day == today;
    final future = day.isAfter(today);
    return Semantics(
      label: '${_letters[i]}${isToday ? ', today' : ''}${done ? ', acha kaam done' : ''}',
      child: Opacity(
        opacity: future ? 0.5 : 1,
        child: Container(
          width: size, height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: done ? AppColors.gold : AppColors.text.withOpacity(0.06),
            border: Border.all(color: isToday ? AppColors.gold : Colors.transparent, width: 2),
          ),
          alignment: Alignment.center,
          child: done
              ? const Icon(Icons.check_rounded, size: 16, color: AppColors.inkOnGold)
              : Text(_letters[i], style: AppFonts.inter(size: 11, weight: FontWeight.w600, color: AppColors.textSoft)),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------------------------

/// "TODAY'S ACHA KAAM IDEA" card, with curious Guddi. "Do it" opens that deed's submit sheet.
class AchaKaamIdeaCard extends StatelessWidget {
  final AchaKaamIdea idea;
  final VoidCallback? onDo; // null while the global cooldown is on
  final String avatarPose; // from GuddiPoses.ideaPool
  final VoidCallback? onAvatarTap; // steps to the next pose in the pool
  const AchaKaamIdeaCard({super.key, required this.idea, required this.onDo, this.avatarPose = GuddiPoses.curious, this.onAvatarTap});

  // Where each pose's face sits (and how far to zoom in), so the round avatar shows her face.
  static const _faceAlign = {
    GuddiPoses.curious: Alignment(0, -0.85),
    GuddiPoses.explain: Alignment(0.3, -0.9),
    GuddiPoses.pointPhone: Alignment(-0.35, -0.55),
  };
  static const _faceZoom = {GuddiPoses.explain: 1.7, GuddiPoses.pointPhone: 1.6};

  @override
  Widget build(BuildContext context) {
    final meta = deedCatalog[idea.deedType];
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      decoration: BoxDecoration(
        color: AppColors.gold.withOpacity(0.14),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.gold.withOpacity(0.5)),
      ),
      child: Row(children: [
        // Guddi (curious / explain / point-phone), head-and-shoulders crop; tap for another.
        GestureDetector(
          onTap: onAvatarTap,
          child: Container(
            width: 48, height: 48,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(shape: BoxShape.circle, color: AppColors.gold.withOpacity(0.22)),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: Transform.scale(
                key: ValueKey(avatarPose),
                scale: _faceZoom[avatarPose] ?? 1.0,
                alignment: _faceAlign[avatarPose] ?? const Alignment(0, -0.85),
                child: Image.asset(
                  avatarPose,
                  width: 48, height: 48,
                  fit: BoxFit.cover,
                  alignment: _faceAlign[avatarPose] ?? const Alignment(0, -0.85),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text("TODAY'S ACHA KAAM IDEA", style: AppFonts.plexMono(size: 9, color: AppColors.gold)),
            const SizedBox(height: 3),
            Text('${meta != null ? '${meta.icon} ' : ''}${idea.roman}', style: AppFonts.fraunces(size: 15, weight: FontWeight.w600, height: 1.25)),
            const SizedBox(height: 2),
            Text(idea.en, style: AppFonts.inter(size: 11, color: AppColors.textSoft)),
            if (idea.involvesPerson) ...[
              const SizedBox(height: 4),
              Text('📷 ${kPhotoTheDeedHint.roman}', style: AppFonts.inter(size: 10.5, weight: FontWeight.w600, color: AppColors.olive)),
            ],
          ]),
        ),
        const SizedBox(width: 8),
        SizedBox(
          height: 44,
          child: ElevatedButton(
            onPressed: onDo,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.gold,
              foregroundColor: AppColors.inkOnGold,
              disabledBackgroundColor: AppColors.text.withOpacity(0.08),
              disabledForegroundColor: AppColors.textSoft,
              padding: const EdgeInsets.symmetric(horizontal: 18),
              shape: const StadiumBorder(),
              elevation: 0,
            ),
            child: Text('Do it', style: AppFonts.inter(size: 14, weight: FontWeight.w700, color: onDo != null ? AppColors.inkOnGold : AppColors.textSoft)),
          ),
        ),
      ]),
    );
  }
}

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
    // Slim full-body poses (e.g. proud) would read tiny next to the waist-up ones — show them
    // larger and cropped above the knees, same as in the Home header.
    final tall = GuddiPoses.tallPoses.contains(pose);
    final Widget img = tall
        ? ClipRect(
            child: SizedBox(
              height: h,
              child: OverflowBox(
                alignment: Alignment.topCenter,
                maxHeight: h * 1.45,
                child: Image.asset(pose, height: h * 1.45, fit: BoxFit.contain),
              ),
            ),
          )
        : Image.asset(pose, height: h, fit: BoxFit.contain);
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
        child: img,
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
