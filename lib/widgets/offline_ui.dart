import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../data/guddi_content.dart';
import 'guddi_home.dart';

// Offline mode UI pieces (layer 2): the "Offline" pill, the "internet chahiye" note for screens
// that need the server, the waiting-deeds card on Home and Guddi's dialogs. Presentation only.

class OfflinePill extends StatelessWidget {
  const OfflinePill({super.key});
  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: OfflineLines.needsInternet.en,
      child: Container(
        key: const ValueKey('offline-pill'),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: AppColors.rust.withOpacity(0.22),
          borderRadius: BorderRadius.circular(100),
          border: Border.all(color: AppColors.rust.withOpacity(0.6)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.cloud_off_rounded, size: 12, color: AppColors.text),
          const SizedBox(width: 5),
          Text(OfflineLines.pill, style: AppFonts.plexMono(size: 9.5, weight: FontWeight.w700, color: AppColors.text)),
        ]),
      ),
    );
  }
}

// Greys out a card that needs the server while offline — the same "locked" look as Home's
// category rings during the global cooldown (_CategoryRing): textSoft-tinted background, soft
// border, content desaturated at ~0.4 opacity. Taps still reach the child (which shows the
// needs-internet note). Online: returns the child untouched, so nothing about it changes.
class OfflineDimmed extends StatelessWidget {
  final bool offline;
  final double radius; // match the card's own corner radius
  final Widget child;
  const OfflineDimmed({super.key, required this.offline, required this.child, this.radius = 16});

  static const _greyscale = ColorFilter.matrix(<double>[
    0.2126, 0.7152, 0.0722, 0, 0,
    0.2126, 0.7152, 0.0722, 0, 0,
    0.2126, 0.7152, 0.0722, 0, 0,
    0, 0, 0, 1, 0,
  ]);

  @override
  Widget build(BuildContext context) {
    if (!offline) return child;
    return Container(
      key: const ValueKey('offline-dimmed'),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [AppColors.textSoft.withOpacity(0.08), AppColors.bg2.withOpacity(0.4)]),
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: AppColors.textSoft.withOpacity(0.3)),
      ),
      child: Opacity(opacity: 0.4, child: ColorFiltered(colorFilter: _greyscale, child: child)),
    );
  }
}

// Tapping something that needs the server while offline.
void showNeedsInternet(BuildContext context) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text('${OfflineLines.needsInternet.roman} · ${OfflineLines.needsInternet.en}')));
}

// Home, while deeds wait on the phone.
class WaitingDeedsCard extends StatelessWidget {
  final int count;
  const WaitingDeedsCard({super.key, required this.count});
  @override
  Widget build(BuildContext context) {
    final line = count == 1 ? OfflineLines.waitingOne : OfflineLines.waiting;
    return Container(
      key: const ValueKey('waiting-deeds-card'),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(color: AppColors.oliveCard, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.gold.withOpacity(0.3))),
      child: Row(children: [
        const Text('⏳', style: TextStyle(fontSize: 18)),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(line.roman.replaceAll('{n}', '$count'), style: AppFonts.inter(size: 12, weight: FontWeight.w600)),
            if (line.en != null) Text(line.en!, style: AppFonts.inter(size: 10.5, color: AppColors.textSoft, height: 1.35)),
          ]),
        ),
      ]),
    );
  }
}

class WaitingPointsChip extends StatelessWidget {
  final int points;
  const WaitingPointsChip({super.key, required this.points});
  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('waiting-points-chip'),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: AppColors.oliveCardStrong, borderRadius: BorderRadius.circular(100), border: Border.all(color: AppColors.gold.withOpacity(0.35))),
      child: Text(OfflineLines.waitingPoints.replaceAll('{x}', '$points'), style: AppFonts.plexMono(size: 9.5, weight: FontWeight.w700, color: AppColors.gold)),
    );
  }
}

// Guddi with one message and an OK button: "saved on your phone", "queue full", etc.
Future<void> showGuddiNotice(BuildContext context, GuddiLine line, {String pose = GuddiPoses.showPhone}) {
  return showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: AppColors.bg2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      content: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Image.asset(pose, height: 110, fit: BoxFit.contain),
          const SizedBox(height: 12),
          Text(line.roman, key: const ValueKey('guddi-notice-line'), textAlign: TextAlign.center, style: AppFonts.inter(size: 13.5, weight: FontWeight.w600, height: 1.4)),
          if (line.en != null) ...[
            const SizedBox(height: 6),
            Text(line.en!, textAlign: TextAlign.center, style: AppFonts.inter(size: 11.5, color: AppColors.textSoft, height: 1.4)),
          ],
        ]),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: Text(OfflineLines.savedOk, style: AppFonts.inter(size: 13, weight: FontWeight.w700, color: AppColors.gold)),
        ),
      ],
    ),
  );
}
