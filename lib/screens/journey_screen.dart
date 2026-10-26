import 'package:flutter/material.dart';
import '../data/journey_models.dart';
import '../data/journey_repository.dart';
import '../data/roadmap_data.dart';

// Journey-map screen, data side. Everything comes through a JourneyRepository, so the same screen
// runs on live data or on the seeded UAT repository. The visuals here are a plain functional
// placeholder (stop list + box picker) until the design spec lands; the data wiring is the part
// that is final. Not linked from any live screen yet.
class JourneyScreen extends StatefulWidget {
  final JourneyRepository repository;
  final String campaignId;
  const JourneyScreen({super.key, required this.repository, required this.campaignId});
  @override
  State<JourneyScreen> createState() => _JourneyScreenState();
}

class _JourneyScreenState extends State<JourneyScreen> {
  JourneyConfig? config;
  JourneyProgress? progress;
  String? error;

  @override
  void initState() {
    super.initState();
    widget.repository.changes.addListener(_load);
    _load();
  }

  @override
  void didUpdateWidget(JourneyScreen old) {
    super.didUpdateWidget(old);
    if (old.campaignId != widget.campaignId) _load();
  }

  @override
  void dispose() {
    widget.repository.changes.removeListener(_load);
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final c = await widget.repository.loadCampaign(widget.campaignId);
      final p = await widget.repository.loadProgress(widget.campaignId);
      if (!mounted) return;
      setState(() { config = c; progress = p; error = null; });
    } on JourneyException catch (e) {
      if (mounted) setState(() => error = e.message);
    }
  }

  Future<void> _openStop(RoadmapStop stop) async {
    final p = progress!;
    if (p.deedsDone < stop.threshold) return;
    final record = p.claims[stop.id];
    if (record != null) {
      await _info(stop.label, record.won ? '${stop.prize.icon}  You won: ${stop.prize.name}' : "📭  You didn't win here");
      return;
    }
    final index = await showModalBottomSheet<int>(
      context: context,
      isDismissible: false,
      builder: (ctx) => _BoxPicker(stop: stop),
    );
    if (index == null) return;
    try {
      final outcome = await widget.repository.claimStop(stop.id, index);
      await widget.repository.refreshAfterClaim();
      if (mounted) await _info(_titleFor(outcome), _bodyFor(stop, outcome));
    } on JourneyException catch (e) {
      if (mounted) await _info('Could not claim', e.message);
    }
  }

  String _titleFor(ClaimOutcome o) {
    switch (o.outcome) {
      case 'free_skin': return 'You won it — free!';
      case 'discount': return 'You earned a discount!';
      case 'prize': return 'You won!';
      default: return 'Not this time';
    }
  }

  String _bodyFor(RoadmapStop stop, ClaimOutcome o) {
    switch (o.outcome) {
      case 'free_skin': return '${stop.prize.name} is now yours, no points needed.';
      case 'discount': return '${o.discountPercent}% off ${stop.prize.name} — it is waiting in Skins.';
      case 'prize': return o.prizePoints != null ? '+${o.prizePoints} points added to your total!' : stop.prize.name;
      default: return 'Better luck at the next stop!';
    }
  }

  Future<void> _info(String title, String body) => showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(title),
          content: Text(body),
          actions: [TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('OK'))],
        ),
      );

  @override
  Widget build(BuildContext context) {
    if (error != null) return Center(child: Text(error!));
    final c = config, p = progress;
    if (c == null || p == null) return const Center(child: CircularProgressIndicator());
    final t = c.theme;
    final next = c.stops.where((s) => p.deedsDone < s.threshold).toList();
    final header = next.isEmpty ? 'Road complete!' : 'Bas ${next.first.threshold - p.deedsDone} aur!';
    return Container(
      decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [t.bgColor2, t.bgColor1])),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('${t.accessory}  ${c.campaign.title}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: Colors.white)),
          const SizedBox(height: 4),
          Text('${p.deedsDone} / ${c.stops.last.threshold} acha kaam  ·  $header', style: const TextStyle(color: Colors.white70)),
          if (p.hallOfFameClaimed) const Padding(padding: EdgeInsets.only(top: 4), child: Text('Hall of Fame claimed', style: TextStyle(color: Colors.white70))),
          const SizedBox(height: 12),
          for (final stop in c.stops) _stopTile(stop, p, t),
        ],
      ),
    );
  }

  Widget _stopTile(RoadmapStop stop, JourneyProgress p, JourneyTheme t) {
    final reached = p.deedsDone >= stop.threshold;
    final claimed = p.claims.containsKey(stop.id);
    final icon = claimed ? t.stopIconClaimed : (reached ? t.stopIconReached : t.stopIconLocked);
    final status = claimed ? (p.claims[stop.id]!.won ? 'claimed · won' : 'claimed') : (reached ? 'tap to claim' : 'locked');
    return Card(
      color: t.roadColor.withValues(alpha: reached ? 0.6 : 0.25),
      child: ListTile(
        key: ValueKey('stop-${stop.id}'),
        leading: Text(icon, style: const TextStyle(fontSize: 26)),
        title: Text('${stop.label} · ${stop.threshold} deeds', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
        subtitle: Text('${stop.prize.name} · ${stop.rewardMode} · ${stop.winningBoxes}/${stop.totalBoxes} boxes · $status', style: const TextStyle(color: Colors.white70)),
        onTap: () => _openStop(stop),
      ),
    );
  }
}

class _BoxPicker extends StatelessWidget {
  final RoadmapStop stop;
  const _BoxPicker({required this.stop});
  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('${stop.label} — pick a box', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          GridView.count(
            shrinkWrap: true,
            crossAxisCount: 3,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            children: [
              for (var i = 0; i < stop.totalBoxes; i++)
                ElevatedButton(key: ValueKey('box-$i'), onPressed: () => Navigator.of(context).pop(i), child: const Text('🎁', style: TextStyle(fontSize: 26))),
            ],
          ),
        ]),
      ),
    );
  }
}
