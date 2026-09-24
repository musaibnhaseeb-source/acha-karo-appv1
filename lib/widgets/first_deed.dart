import 'dart:async';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../data/deed_catalog.dart';
import 'confetti_overlay.dart';
import 'submit_deed_flow.dart';

// First-deed onboarding pieces used by Home and the submit flow. Both are presentation only —
// the picker hands off to the normal submit flow (same GPS/moderation/cooldown path as every
// other deed), and the celebration is cosmetic: it grants nothing and writes nothing.

// Easy, everyday starters — deliberately no donation types, which always go to a moderator
// and would make someone's very first deed sit as "pending".
const List<String> firstDeedStarterTypes = ['water', 'litter', 'carryBags'];

Future<void> showFirstDeedPicker(BuildContext context) {
  return showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) => Container(
      decoration: const BoxDecoration(color: AppColors.bg2, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
      child: SafeArea(
        top: false,
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            Image.asset('assets/images/guddi/guddi_small.png', height: 56, fit: BoxFit.contain),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Pick an easy first deed', style: AppFonts.fraunces(size: 17, weight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text('Snap a photo and you\'re done.', style: AppFonts.inter(size: 12, color: AppColors.textSoft)),
              ]),
            ),
          ]),
          const SizedBox(height: 14),
          for (final type in firstDeedStarterTypes)
            if (deedCatalog[type] != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: GestureDetector(
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    openSubmitDeedFlow(context, type);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(color: AppColors.oliveCard, borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0x29F6F5EC))),
                    child: Row(children: [
                      Text(deedCatalog[type]!.icon, style: const TextStyle(fontSize: 22)),
                      const SizedBox(width: 12),
                      Expanded(child: Text(deedCatalog[type]!.name, style: AppFonts.inter(size: 14, weight: FontWeight.w600))),
                      Text('+${deedCatalog[type]!.points} pts', style: AppFonts.plexMono(size: 10.5, color: AppColors.gold)),
                    ]),
                  ),
                ),
              ),
        ]),
      ),
    ),
  );
}

// Small nudge beside "Log a good deed" on Home for anyone who hasn't logged a deed yet (after
// the tour was skipped/finished). No overlay — tapping it opens the easy-first-deed picker.
class FirstDeedBubble extends StatefulWidget {
  final VoidCallback onTap;
  const FirstDeedBubble({super.key, required this.onTap});
  @override
  State<FirstDeedBubble> createState() => _FirstDeedBubbleState();
}

class _FirstDeedBubbleState extends State<FirstDeedBubble> with SingleTickerProviderStateMixin {
  late final AnimationController _bob = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))..repeat(reverse: true);

  @override
  void dispose() {
    _bob.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: AppColors.gold.withOpacity(0.16),
            borderRadius: BorderRadius.circular(100),
            border: Border.all(color: AppColors.gold.withOpacity(0.5)),
          ),
          child: Text('Your first deed is waiting 💛', style: AppFonts.inter(size: 11, weight: FontWeight.w600, color: AppColors.gold)),
        ),
        const SizedBox(width: 4),
        AnimatedBuilder(
          animation: _bob,
          builder: (_, child) => Transform.translate(offset: Offset(0, -3 * Curves.easeInOut.transform(_bob.value)), child: child),
          child: Image.asset('assets/images/guddi/guddi_small.png', height: 34, fit: BoxFit.contain),
        ),
      ]),
    );
  }
}

// Shown instead of the regular thank-you animation for someone's very first deed.
class FirstDeedCelebration extends StatefulWidget {
  final bool wasFlagged;
  final VoidCallback onDone;
  const FirstDeedCelebration({super.key, required this.wasFlagged, required this.onDone});
  @override
  State<FirstDeedCelebration> createState() => _FirstDeedCelebrationState();
}

class _FirstDeedCelebrationState extends State<FirstDeedCelebration> with TickerProviderStateMixin {
  late final AnimationController _confetti;
  late final AnimationController _pop;
  late final List<ConfettiPiece> _pieces;
  Timer? _autoClose;
  bool _done = false;

  @override
  void initState() {
    super.initState();
    _pieces = generateConfettiPieces(40);
    _confetti = AnimationController(vsync: this, duration: const Duration(milliseconds: 2200))..forward();
    _pop = AnimationController(vsync: this, duration: const Duration(milliseconds: 650))..forward();
    _autoClose = Timer(const Duration(milliseconds: 3400), _close);
  }

  void _close() {
    if (_done || !mounted) return;
    _done = true;
    widget.onDone();
  }

  @override
  void dispose() {
    _autoClose?.cancel();
    _confetti.dispose();
    _pop.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final approved = !widget.wasFlagged;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _close, // tap anywhere to continue early
      child: Container(
        color: AppColors.bg1.withOpacity(0.82),
        child: Stack(children: [
          ConfettiLayer(controller: _confetti, pieces: _pieces),
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                ScaleTransition(
                  scale: CurvedAnimation(parent: _pop, curve: Curves.elasticOut),
                  // Scales with the screen (never cropped) so short phones keep her whole head in view.
                  child: Image.asset(
                    'assets/images/guddi/guddi_show_phone.png',
                    height: (MediaQuery.of(context).size.height * 0.34).clamp(150.0, 260.0),
                    fit: BoxFit.contain,
                  ),
                ),
                const SizedBox(height: 16),
                PopInText(
                  delay: const Duration(milliseconds: 200),
                  child: Text(
                    approved ? "You're on the board!" : 'Your first deed is in!',
                    textAlign: TextAlign.center,
                    style: AppFonts.fraunces(size: 24, weight: FontWeight.w700, color: AppColors.gold).copyWith(decoration: TextDecoration.none),
                  ),
                ),
                const SizedBox(height: 8),
                PopInText(
                  delay: const Duration(milliseconds: 420),
                  child: Text(
                    approved ? 'Your first good deed is done. Guddi is proud of you!' : 'A moderator will check it soon.',
                    textAlign: TextAlign.center,
                    style: AppFonts.inter(size: 13, color: AppColors.text, height: 1.4).copyWith(decoration: TextDecoration.none),
                  ),
                ),
              ]),
            ),
          ),
        ]),
      ),
    );
  }
}
