import 'package:flutter/material.dart';
import '../data/guddi_content.dart';
import '../theme/app_theme.dart';
import '../widgets/guddi_home.dart';

// DEV-ONLY: every pose of each pool in its real slot, for review screenshots. No data, no network.
//   flutter build web -t lib/dev_prototypes/pose_pools_preview.dart   ?pool=happy|night|cheer|idea
void main() => runApp(const _App());

class _App extends StatelessWidget {
  const _App();
  @override
  Widget build(BuildContext context) {
    final which = Uri.base.queryParameters['pool'] ?? 'happy';
    const idea = AchaKaamIdea('Apni gali se kachra uthayein', 'Pick up litter on your street', 'litter');
    Widget label(String t) => Padding(
          padding: const EdgeInsets.only(top: 10, bottom: 4),
          child: Text(t, style: AppFonts.plexMono(size: 9, color: AppColors.gold)),
        );
    String name(String p) => p.split('/').last.replaceAll('.webp', '');

    Widget tile(String p, Widget child) => Column(mainAxisSize: MainAxisSize.min, children: [
          child,
          Text(name(p).replaceAll('guddi_', ''), style: AppFonts.plexMono(size: 8)),
        ]);
    final List<Widget> items = switch (which) {
      // Everything on one sheet: each pool, every pose, in its real slot widget.
      'all' => [
          label('HOME HEADER · DAY (happy pool)'),
          Wrap(spacing: 4, runSpacing: 6, children: [for (final p in GuddiPoses.happyPool) tile(p, GuddiFigure(pose: p, night: false, width: 84, height: 122))]),
          label('HOME HEADER · NIGHT (rest + happy pool)'),
          Wrap(spacing: 4, runSpacing: 6, children: [for (final p in GuddiPoses.nightPool) tile(p, GuddiFigure(pose: p, night: true, width: 84, height: 122))]),
          label('CELEBRATION POP-IN (cheer pool)'),
          Wrap(spacing: 4, runSpacing: 6, children: [for (final p in GuddiPoses.cheerPool) tile(p, SizedBox(width: 84, child: GuddiPopIn(pose: p, screenFraction: 0.1, maxHeight: 120)))]),
          label('IDEA CARD AVATAR (idea pool)'),
          for (final p in GuddiPoses.ideaPool) ...[
            AchaKaamIdeaCard(idea: idea, onDo: () {}, avatarPose: p),
            const SizedBox(height: 6),
          ],
        ],
      'cheer' => [
          for (final p in GuddiPoses.cheerPool) ...[
            label('CELEBRATION POP-IN · ${name(p)}'),
            Center(child: GuddiPopIn(pose: p, screenFraction: 0.2, maxHeight: 170)),
          ],
        ],
      'idea' => [
          for (final p in GuddiPoses.ideaPool) ...[
            label('IDEA CARD AVATAR · ${name(p)}'),
            AchaKaamIdeaCard(idea: idea, onDo: () {}, avatarPose: p),
          ],
        ],
      _ => [
          for (final p in (which == 'night' ? GuddiPoses.nightPool : GuddiPoses.happyPool)) ...[
            label('HOME HEADER${which == 'night' ? ' · NIGHT' : ''} · ${name(p)}'),
            GuddiHomeHeader(
              mood: GuddiHomeMood([p], which == 'night' ? GuddiLines.evening : GuddiLines.morning, night: which == 'night'),
              nameBlock: Text('Ayesha', style: AppFonts.fraunces(size: 22, weight: FontWeight.w600)),
            ),
          ],
        ],
    };

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      home: Scaffold(
        backgroundColor: const Color(0xFF222222),
        body: Align(
          alignment: Alignment.topLeft,
          child: Container(
            width: 390, height: 1560, margin: const EdgeInsets.all(12), color: AppColors.bg1,
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(18, 8, 18, 18),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: items),
            ),
          ),
        ),
      ),
    );
  }
}
