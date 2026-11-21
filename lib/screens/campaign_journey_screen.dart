import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../data/deed_catalog.dart';
import 'package:flutter/foundation.dart';
import '../data/journey_models.dart';
import '../data/journey_repository.dart';
import '../data/remote_config.dart';
import '../data/supabase_journey_repository.dart';
import '../journey/guddi_clips.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/submit_deed_flow.dart';
import 'campaign_detail_screen.dart';
import 'hall_of_fame_screen.dart';
import 'journey_side_screen.dart';
import 'skins_screen.dart';

// The campaign's road, in the real app: Home's campaign tile opens this instead of the old
// CampaignDetailScreen -> RoadmapScreen path (both still exist, unreferenced from Home). Data comes
// from the same tables and Edge Function the old roadmap used, through SupabaseJourneyRepository;
// nothing here adds a table, column or RPC.
class CampaignJourneyScreen extends StatefulWidget {
  final Campaign campaign;
  // Preview/tests only: swaps the Supabase repository for a seeded one. Always null in the app.
  @visibleForTesting
  final JourneyRepository? debugRepository;
  const CampaignJourneyScreen({super.key, required this.campaign, this.debugRepository});
  @override
  State<CampaignJourneyScreen> createState() => _CampaignJourneyScreenState();
}

class _CampaignJourneyScreenState extends State<CampaignJourneyScreen> {
  late final AppState _state;
  late final JourneyRepository _repo;
  late int _lastDeeds;
  bool _finished = false; // last stop claimed and won -> Hall of Fame button

  int _approvedDeeds() => _state.deedsLog.where((d) => d.status == 'approved' && d.campaignId == widget.campaign.id).length;

  @override
  void initState() {
    super.initState();
    _state = context.read<AppState>();
    _repo = widget.debugRepository ?? SupabaseJourneyRepository(
      campaign: widget.campaign,
      approvedDeedCount: _approvedDeeds,
      reloadProfile: () async {
        await _state.tryLoadExistingProfile();
      },
    );
    _lastDeeds = _approvedDeeds();
    _state.addListener(_onState);
  }

  // A deed got approved (or the log reloaded): re-read progress so Guddi walks to the new count.
  void _onState() {
    final n = _approvedDeeds();
    if (n != _lastDeeds) {
      _lastDeeds = n;
      final r = _repo;
      if (r is SupabaseJourneyRepository) r.refresh();
    }
  }

  @override
  void dispose() {
    _state.removeListener(_onState);
    super.dispose();
  }

  void _onLoaded(JourneyConfig c, JourneyProgress p) {
    if (c.stops.isEmpty) return;
    final last = c.stops.reduce((a, b) => a.threshold >= b.threshold ? a : b);
    final done = p.claims[last.id]?.won == true;
    if (done != _finished && mounted) setState(() => _finished = done);
  }

  void _openHallOfFame() => Navigator.of(context).push(MaterialPageRoute(builder: (_) => HallOfFameScreen(campaign: widget.campaign)));

  // Same openSubmitDeedFlow as everywhere else (GPS, moderation, cooldowns, offline queue); the
  // campaign id tags the deed so it counts toward this road.
  void _showTaskList() {
    final state = context.read<AppState>();
    final easiest = easiestDeedsPerCategory();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.bg2,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (sheetContext) => DraggableScrollableSheet(
        initialChildSize: 0.75,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) => ListView(
          controller: scrollController,
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 30),
          children: [
            Text('Acha kaam karein', style: AppFonts.fraunces(size: 16, weight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text('Each acha kaam from here moves you along the road.', style: AppFonts.inter(size: 11.5, color: AppColors.textSoft)),
            const SizedBox(height: 16),
            for (final cat in categoryDefs)
              if ((easiest[cat.key] ?? []).isNotEmpty) ...[
                Text('${cat.icon} ${cat.name}', style: AppFonts.inter(size: 12.5, weight: FontWeight.w700, color: AppColors.textSoft)),
                const SizedBox(height: 8),
                for (final type in easiest[cat.key]!)
                  Builder(builder: (_) {
                    final meta = deedCatalog[type]!;
                    final onCooldown = state.cooldownRemaining(type) > Duration.zero;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: GestureDetector(
                        onTap: onCooldown
                            ? () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Still on cooldown — try again shortly.')))
                            : () {
                                Navigator.of(sheetContext).pop();
                                openSubmitDeedFlow(this.context, type, campaignId: widget.campaign.id);
                              },
                        child: Opacity(
                          opacity: onCooldown ? 0.45 : 1.0,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            decoration: BoxDecoration(color: AppColors.oliveCard, borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0x29F6F5EC))),
                            child: Row(children: [
                              Text(meta.icon, style: const TextStyle(fontSize: 18)),
                              const SizedBox(width: 10),
                              Expanded(child: Text(meta.name, style: AppFonts.inter(size: 12.5, weight: FontWeight.w600))),
                              Text(onCooldown ? 'On cooldown' : '+${meta.points} pts', style: AppFonts.plexMono(size: 10.5, color: AppColors.textSoft)),
                            ]),
                          ),
                        ),
                      ),
                    );
                  }),
                const SizedBox(height: 8),
              ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF081209),
      appBar: AppBar(
        backgroundColor: const Color(0xFF081209),
        elevation: 0,
        leading: IconButton(icon: const Icon(Icons.arrow_back, color: AppColors.text), onPressed: () => Navigator.of(context).pop()),
        title: Text(widget.campaign.title, style: AppFonts.fraunces(size: 16, weight: FontWeight.w600), overflow: TextOverflow.ellipsis),
        actions: [
          if (_finished) IconButton(tooltip: 'Hall of Fame', icon: const Icon(Icons.emoji_events_rounded, color: AppColors.gold), onPressed: _openHallOfFame),
          IconButton(
            tooltip: 'About this campaign',
            icon: const Icon(Icons.info_outline_rounded, color: AppColors.text),
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => CampaignDetailScreen(campaign: widget.campaign))),
          ),
        ],
      ),
      body: JourneySideScreen(
        repository: _repo,
        campaignId: widget.campaign.id,
        clips: defaultGuddiClips,
        onAchaKaam: _showTaskList,
        onSkin: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SkinsScreen())),
        onLoaded: _onLoaded,
        onFinalWin: _openHallOfFame,
      ),
    );
  }
}
