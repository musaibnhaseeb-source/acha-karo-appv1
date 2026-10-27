import 'package:flutter/material.dart';
import '../journey/guddi_clips.dart';
import '../screens/journey_screen.dart';
import '../screens/journey_side_screen.dart';
import 'uat_journey_repository.dart';
import 'uat_rules.dart';

// UAT-only wrapper around JourneyScreen: persistent UAT banner, campaign chips, and an end
// drawer with the test controls. None of this exists in the real screen.
class UatApp extends StatelessWidget {
  const UatApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Acha Karo UAT',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: const Color(0xFF3C4A2C), brightness: Brightness.dark),
      builder: (context, child) => Banner(
        message: 'UAT',
        location: BannerLocation.topStart,
        color: const Color(0xFFC1573D),
        child: child!,
      ),
      home: const UatShell(),
    );
  }
}

class UatShell extends StatefulWidget {
  final UatJourneyRepository? repository;
  final bool startInSideView; // side-scroller first (default); tests of the list view pass false
  const UatShell({super.key, this.repository, this.startInSideView = true});
  @override
  State<UatShell> createState() => _UatShellState();
}

class _UatShellState extends State<UatShell> {
  late final UatJourneyRepository repo = widget.repository ?? UatJourneyRepository();
  late String campaignId = repo.campaigns.first.campaign.id;

  @override
  void initState() {
    super.initState();
    // Demo shortcuts on web: ?campaign=short|classic|long and ?user=a|b|c|d|e preselect what you look at.
    final q = Uri.base.queryParameters;
    final c = q['campaign'];
    if (c != null) {
      final hit = repo.campaigns.where((x) => x.campaign.id == 'uat-$c').toList();
      if (hit.isNotEmpty) campaignId = hit.first.campaign.id;
    }
    final u = q['user'];
    if (u != null && u.length == 1) {
      final i = u.toLowerCase().codeUnitAt(0) - 'a'.codeUnitAt(0);
      if (i >= 0 && i < repo.users.length) repo.switchUser(repo.users[i].id);
    }
  }
  late bool sideView = widget.startInSideView; // side-scroller or the plain list view

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: repo,
      builder: (context, _) => Scaffold(
        appBar: AppBar(
          title: const Text('UAT · seeded data · no network', style: TextStyle(fontSize: 14)),
          backgroundColor: const Color(0xFF5A2A1E),
          actions: [
            IconButton(key: const ValueKey('toggle-view'), tooltip: sideView ? 'Show list view' : 'Show side-scroller', icon: Icon(sideView ? Icons.view_list : Icons.directions_walk), onPressed: () => setState(() => sideView = !sideView)),
            Builder(builder: (ctx) => IconButton(key: const ValueKey('open-controls'), icon: const Icon(Icons.tune), onPressed: () => Scaffold.of(ctx).openEndDrawer())),
          ],
        ),
        endDrawer: Drawer(child: _controls()),
        body: Column(children: [
          SizedBox(
            height: 52,
            child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.all(8), children: [
              for (final c in repo.campaigns)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(c.campaign.title),
                    selected: c.campaign.id == campaignId,
                    onSelected: (_) => setState(() => campaignId = c.campaign.id),
                  ),
                ),
            ]),
          ),
          Expanded(
            child: sideView
                ? JourneySideScreen(
                    repository: repo,
                    campaignId: campaignId,
                    clips: defaultGuddiClips,
                    snapKey: '${repo.user.id}|$campaignId',
                    onAchaKaam: () => repo.completeAchaKaam(campaignId),
                    onSkin: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Skin selector: Default only (UAT)'))),
                  )
                : JourneyScreen(repository: repo, campaignId: campaignId),
          ),
        ]),
      ),
    );
  }

  Widget _controls() {
    final seed = repo.seedFor(campaignId);
    final deeds = repo.user.deeds[campaignId] ?? 0;
    return SafeArea(
      child: ListView(padding: const EdgeInsets.all(16), children: [
        const Text('UAT controls', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
        const SizedBox(height: 12),
        const Text('Fake user'),
        RadioGroup<String>(
          groupValue: repo.user.id,
          onChanged: (v) => repo.switchUser(v!),
          child: Column(children: [
            for (final u in repo.users) RadioListTile<String>(dense: true, title: Text(u.label), value: u.id),
          ]),
        ),
        const Divider(),
        Text('${seed.campaign.title}: $deeds acha kaam · ${repo.user.points} pts'),
        const SizedBox(height: 8),
        FilledButton(key: const ValueKey('add-deed'), onPressed: () => repo.completeAchaKaam(campaignId), child: const Text('+1 acha kaam (no photo / GPS)')),
        const SizedBox(height: 8),
        Wrap(spacing: 8, children: [
          ActionChip(label: const Text('Set 0'), onPressed: () => repo.setDeeds(campaignId, 0)),
          for (final s in seed.stops) ActionChip(label: Text('Set ${s.threshold}'), onPressed: () => repo.setDeeds(campaignId, s.threshold)),
        ]),
        const SizedBox(height: 8),
        OutlinedButton(onPressed: () => repo.resetUserCampaign(campaignId), child: const Text('Reset this user + campaign')),
        OutlinedButton(onPressed: repo.resetAll, child: const Text('Reset everything to seed')),
        const Divider(),
        const Text('Claim result'),
        SegmentedButton<UatClaimMode>(
          segments: const [
            ButtonSegment(value: UatClaimMode.random, label: Text('Random')),
            ButtonSegment(value: UatClaimMode.forceWin, label: Text('Win')),
            ButtonSegment(value: UatClaimMode.forceLose, label: Text('Lose')),
          ],
          selected: {repo.claimMode},
          onSelectionChanged: (s) => repo.setClaimMode(s.first),
        ),
        const SizedBox(height: 12),
        Text('Skins: ${repo.user.skins.isEmpty ? '-' : repo.user.skins.join(', ')}'),
        Text('Discounts: ${repo.user.discounts.isEmpty ? '-' : repo.user.discounts.entries.map((e) => '${e.key} ${e.value}%').join(', ')}'),
      ]),
    );
  }
}
