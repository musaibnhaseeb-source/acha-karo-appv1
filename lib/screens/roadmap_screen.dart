import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../theme/app_theme.dart';
import '../state/app_state.dart';
import '../data/roadmap_data.dart';
import '../data/remote_config.dart';
import '../data/deed_catalog.dart';
import '../widgets/submit_deed_flow.dart';
import '../widgets/guddi_home.dart';
import '../widgets/flip_card.dart';
import '../widgets/campaign_icon.dart';
import 'hall_of_fame_screen.dart';
import 'skins_screen.dart';

// Real functionality now — genuine progress tracking, not a testing mock. Takes the campaign
// it's reached from, and counts real approved deeds submitted since that campaign's start date.
// Confirmed rule: campaign progress is separate from the eventual Pakistan map's progress — it
// does NOT carry over — so this deliberately counts from campaign.startDate specifically, not
// lifetime activity.
class RoadmapScreen extends StatefulWidget {
  final Campaign campaign;
  const RoadmapScreen({super.key, required this.campaign});
  @override
  State<RoadmapScreen> createState() => _RoadmapScreenState();
}

class _RoadmapScreenState extends State<RoadmapScreen> {
  List<RoadmapStop> stops = [];
  Set<String> claimedStopIds = {}; // real persistence now — survives navigation, matches the
  // exact bug diagnosed: local-only state forgot everything the moment this screen was rebuilt
  bool loadingStops = true;
  String? loadError;
  bool hallOfFameClaimed = false; // new — hides "Acha kaam karein" once this campaign is fully done
  Map<String, bool> claimResults = {}; // stopId -> won, so tapping a claimed stop can show the real result

  @override
  void initState() {
    super.initState();
    _loadStopsAndClaims();
    // New — loads whichever skin (if any) is equipped specifically for this campaign, so the
    // vehicle shown is real from the moment the road actually renders.
    // Reverted back to per-campaign loading, per direction.
    // Real, global equip now — loaded once at profile level (main.dart). Also safe to call
    // again here, in case this screen opens before that initial load has finished.
    context.read<AppState>().loadEquippedSkin();
  }

  // Real database connection now, replacing the local placeholder list from Phase 1's UI-only
  // testing. Fetches this specific campaign's real stops, and this user's real claim history —
  // both genuinely persist now, closing the exact gap that made a claimed stop look unclaimed
  // again after leaving and returning to the screen.
  Future<void> _loadStopsAndClaims() async {
    setState(() { loadingStops = true; loadError = null; });
    try {
      final uid = Supabase.instance.client.auth.currentUser?.id;
      final stopRows = await Supabase.instance.client.from('roadmap_stops').select().eq('campaign_id', widget.campaign.id).order('threshold', ascending: true);
      final loadedStops = stopRows.map<RoadmapStop>((r) => RoadmapStop.fromRow(r)).toList();

      Set<String> claimed = {};
      bool hofClaimed = false;
      if (uid != null && loadedStops.isNotEmpty) {
        final stopIds = loadedStops.map((s) => s.id).toList();
        final claimRows = await Supabase.instance.client.from('roadmap_claims').select('stop_id, won').eq('user_id', uid).inFilter('stop_id', stopIds);
        claimed = claimRows.map<String>((r) => r['stop_id'] as String).toSet();
        // New — real claim results kept, not just which stops were claimed, so tapping an
        // already-claimed stop can show what was genuinely won there, not just "already claimed."
        claimResults = {for (final r in claimRows) r['stop_id'] as String: r['won'] as bool};
        // New — checked here alongside everything else, so "Acha kaam karein" can correctly disappear
        // once this campaign's full Hall of Fame has genuinely been claimed, not just deed 12
        // reached (those are two different moments — someone could hit the threshold but not
        // yet have completed the actual Hall of Fame claim).
        final hofRow = await Supabase.instance.client.from('hall_of_fame_claims').select('campaign_id').eq('user_id', uid).eq('campaign_id', widget.campaign.id).maybeSingle();
        hofClaimed = hofRow != null;
      }

      setState(() { stops = loadedStops; claimedStopIds = claimed; hallOfFameClaimed = hofClaimed; loadingStops = false; });
    } catch (e) {
      setState(() { loadError = "Couldn't load this campaign's roadmap. Check your connection and try again."; loadingStops = false; });
    }
  }

  // Real count now — approved deeds submitted since this campaign started, not the old +1/-1
  // test buttons. If a campaign has no start date set, counts from account creation instead of
  // showing zero forever — an honest fallback rather than a silently broken feature.
  int get deedsDone {
    final state = context.read<AppState>();
    // Real fix here — the identified multi-campaign gap: this used to count "approved deeds
    // since this campaign's start date" with no concept of WHICH campaign a deed actually came
    // from. If two campaigns ran at once, the same deeds would count toward both roadmaps
    // simultaneously. Now filters by the actual campaign_id tag set at submission time —
    // requires deeds submitted through THIS specific campaign's task list, not just "any deed
    // done after this date."
    return state.deedsLog.where((d) => d.status == 'approved' && d.campaignId == widget.campaign.id).length;
  }

  void _openStop(RoadmapStop stop) {
    if (deedsDone < stop.threshold) return; // not reached yet
    if (claimedStopIds.contains(stop.id)) {
      _showAlreadyClaimed(stop);
      return;
    }
    _showMysteryBoxes(stop);
  }

  void _showAlreadyClaimed(RoadmapStop stop) {
    // Real fix here: this used to just say "already claimed" with no way to see what was
    // actually won — the real result already exists in roadmap_claims, this was purely a
    // missing display, same shape as the earlier Limited Edition Items gap.
    final won = claimResults[stop.id] ?? false;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.bg2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text('${stop.label}', style: AppFonts.fraunces(size: 16, weight: FontWeight.w600)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(won ? stop.prize.icon : '📭', style: const TextStyle(fontSize: 40)),
          const SizedBox(height: 10),
          Text(won ? 'You won: ${stop.prize.name}' : "You didn't win here", textAlign: TextAlign.center, style: AppFonts.inter(size: 13.5, weight: FontWeight.w700)),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: Text('OK', style: AppFonts.inter(size: 13, weight: FontWeight.w700, color: AppColors.gold))),
        ],
      ),
    );
  }

  void _showMysteryBoxes(RoadmapStop stop) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.bg2,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      isDismissible: false, // must pick a box, matches the "hidden behind boxes" mechanic
      isScrollControlled: true,
      builder: (sheetContext) => _MysteryBoxSheet(
        stop: stop,
        // Real design change here, worth understanding: the old version pre-shuffled ALL box
        // outcomes locally, so "reveal for all" could show where every prize was, since that
        // full set already existed on the device. Genuine server-side fairness can't allow
        // that — if the full set existed on-device before tapping, a technically inclined
        // person could inspect it. Now only the TAPPED box's real outcome comes back from the
        // Edge Function, decided at the moment of the tap. The other boxes genuinely have no
        // answer to reveal, since nothing was decided for them.
        //
        // New — the result now carries an outcome type, not just a plain win/lose bool. Stop
        // 2's guaranteed_with_discount mode means every tap results in something real: the
        // winning card grants a skin free, any other card grants a discount instead. Never
        // "you got nothing," which is the actual point of this mechanic.
        onFinished: (result) {
          setState(() => claimedStopIds.add(stop.id));
          // Real fix here: the server updates the actual points total directly, but the app's
          // own local copy has no way to know that happened unless something tells it to
          // re-check. Without this, a real points credit would be genuinely invisible until
          // some unrelated screen happened to trigger a refresh.
          if (result.won && result.prizePoints != null) {
            context.read<AppState>().tryLoadExistingProfile();
          }
          Future.delayed(const Duration(milliseconds: 900), () {
            if (mounted) Navigator.of(sheetContext).pop();
            if (mounted) _showResultDialog(stop, result);
          });
        },
      ),
    );
  }

  void _showResultDialog(RoadmapStop stop, _ClaimResult result) {
    // Real branch here for Stop 2's new mechanic — a genuinely different message and visual
    // for "you got a discount" versus the standard win/lose outcomes, since it's neither a
    // full win nor a loss.
    final String emoji;
    final String title;
    final String body;
    switch (result.outcome) {
      case 'free_skin':
        emoji = stop.prize.icon;
        title = 'You won it — free!';
        body = '${stop.prize.name} is now yours, no points needed.';
        break;
      case 'discount':
        emoji = '🏷️';
        title = 'You earned a discount!';
        body = '${result.discountPercent}% off ${stop.prize.name} — it\'s waiting in Skins.';
        break;
      case 'prize':
        emoji = stop.prize.icon;
        title = 'You won!';
        // Real fix here: this used to always show just the prize name, even for a points prize
        // that (before this batch) never actually credited anything. Now shows the real amount
        // that was genuinely added to your points total, when one exists.
        body = result.prizePoints != null ? '+${result.prizePoints} points added to your total!' : stop.prize.name;
        break;
      default:
        emoji = '📭';
        title = 'Not this time';
        body = 'Better luck at the next stop!';
    }
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.bg2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text(title, style: AppFonts.fraunces(size: 16, weight: FontWeight.w600)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(emoji, style: const TextStyle(fontSize: 48)),
          const SizedBox(height: 10),
          Text(body, textAlign: TextAlign.center, style: AppFonts.inter(size: 14, weight: FontWeight.w700)),
        ]),
        actions: [
          // New — real navigation now, per direction, not just text telling someone where to
          // go manually. Only shown for outcomes where Skins is actually relevant.
          if (result.outcome == 'free_skin' || result.outcome == 'discount')
            TextButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SkinsScreen()));
              },
              child: Text('Go to Skins', style: AppFonts.inter(size: 13, weight: FontWeight.w700, color: AppColors.gold)),
            ),
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              // New — real trigger for the Hall of Fame reveal: only for the campaign's actual
              // final (highest threshold) stop, and only on a genuine win there — matches
              // exactly what the Edge Function's own verification checks for, so this can never
              // navigate somewhere the server would then refuse to honor.
              final isFinalStop = stop.threshold == stops.map((s) => s.threshold).reduce((a, b) => a > b ? a : b);
              if (isFinalStop && result.won) {
                Navigator.of(context).push(MaterialPageRoute(builder: (_) => HallOfFameScreen(campaign: widget.campaign)));
              }
            },
            child: Text('OK', style: AppFonts.inter(size: 13, weight: FontWeight.w700, color: AppColors.gold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Real fix here: deedsDone is computed via context.read (correct for the one-off lookups in
    // event handlers like _openStop), but read alone never triggers a rebuild on its own. This
    // watch call is what actually subscribes the screen to AppState changes — so the moment a
    // deed gets submitted from the task list below and deedsLog updates, this rebuilds and
    // deedsDone re-evaluates fresh, moving the truck without needing a manual refresh.
    context.watch<AppState>();
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(icon: const Icon(Icons.arrow_back, color: AppColors.text), onPressed: () => Navigator.of(context).pop()),
        title: Text(widget.campaign.title, style: AppFonts.inter(size: 14, weight: FontWeight.w600)),
        centerTitle: true,
      ),
      body: Stack(
        // Real, genuine root-cause fix: Stack defaults to StackFit.loose, meaning it sizes
        // itself to its non-Positioned child (SafeArea), which in turn sizes to its OWN content
        // rather than filling available space. Every previous attempt only ever changed the
        // background widget itself, never addressed this — the Positioned background was
        // always being clipped down to match the Stack's own, content-sized bounds, regardless
        // of what explicit size it was given. This forces the Stack itself to fill available
        // space unconditionally, which is the actual fix.
        fit: StackFit.expand,
        children: [
          // Real, different theory here, not yet tried: explicitly sized to the device's actual
          // known screen dimensions via MediaQuery, rather than trusting Positioned.fill to
          // correctly receive sizing information through the Stack's own constraint
          // propagation. Positioned.fill SHOULD already do this — if the coverage bug persists
          // even with an explicit, known size, that's real, useful evidence the actual cause
          // lies somewhere else entirely (worth reporting back either way).
          Positioned(
            top: 0,
            left: 0,
            width: MediaQuery.of(context).size.width,
            height: MediaQuery.of(context).size.height,
            // Real, per-campaign colors now — falls back to the app's current defaults if this
            // campaign hasn't set its own, so nothing looks broken for existing campaigns.
            child: Container(decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [widget.campaign.bgColor1(AppColors.bg2), widget.campaign.bgColor2(AppColors.bg1)]))),
          ),
          SafeArea(
            child: loadingStops
                ? const Center(child: CircularProgressIndicator(color: AppColors.gold))
                : loadError != null
                    ? Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(loadError!, textAlign: TextAlign.center, style: AppFonts.inter(size: 12, color: AppColors.textSoft))))
                    : stops.isEmpty
                        ? Center(child: Padding(padding: const EdgeInsets.all(24), child: Text('No roadmap set up for this campaign yet.', textAlign: TextAlign.center, style: AppFonts.inter(size: 12, color: AppColors.textSoft))))
                        : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 10, 18, 0),
                  child: Text('${widget.campaign.title} · $deedsDone / ${stops.last.threshold} deeds', style: AppFonts.plexMono(size: 11, color: AppColors.textSoft)),
                ),
                Expanded(
                  child: RoadmapRoadView(
                    campaign: widget.campaign,
                    stops: stops,
                    deedsDone: deedsDone,
                    claimedStopIds: claimedStopIds,
                    onStopTap: _openStop,
                  ),
                ),
                // New — fuel bar mechanic, replacing continuous per-deed vehicle movement per
                // direction: the vehicle now snaps to its last reached stop (see RoadmapRoadView),
                // and this shows real progress toward the next one instead. Segments aren't
                // equal length (3, then +4, then +5 deeds) — this correctly fills based on each
                // segment's real length, not a naive overall fraction.
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 4, 18, 12),
                  child: _FuelBar(stops: stops, deedsDone: deedsDone),
                ),
                // Real, temporary diagnostic banner removed — its job is done. The real cause
                // was the per-campaign equip design itself, not a bug within it; the whole
                // system moved to genuine global equip instead of patching around the design.
                // New — "the actual placeholder" that opens the task list, per the current
                // direction: the CTA's old quick-actions behavior relocated here, expanded from
                // one lowest-point pick per category to 3 real choices, donation types excluded.
                // "Acha kaam karein" hidden entirely once this campaign's Hall of Fame is genuinely
                // claimed — nothing left to log toward, per direction. Equip stays available
                // regardless, since browsing/equipping owned skins still makes sense afterward.
                // New — real fix here: purchase and equip both moved entirely to the Skins
                // store screen now, per direction. This button no longer needs a companion
                // equip control at all — genuinely simpler, not a workaround.
                // New — real fix here: purchase and equip both moved entirely to the Skins
                // store screen now, but the roadmap still needs a real, visible way to get
                // there — per direction, restored as a "Switch Skin" CTA alongside "Acha kaam karein",
                // rather than leaving equipping only reachable by navigating there some other way.
                if (!hallOfFameClaimed) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(18, 0, 18, 10),
                    child: Row(children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () => _showTaskList(context),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            decoration: BoxDecoration(color: AppColors.gold, borderRadius: BorderRadius.circular(13)),
                            alignment: Alignment.center,
                            child: Text('📋 Acha kaam karein', style: AppFonts.inter(size: 13.5, weight: FontWeight.w700, color: AppColors.inkOnGold)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      GestureDetector(
                        onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SkinsScreen())),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                          decoration: BoxDecoration(color: AppColors.oliveCardStrong, borderRadius: BorderRadius.circular(13), border: Border.all(color: AppColors.gold.withOpacity(0.4))),
                          alignment: Alignment.center,
                          child: const Text('🎨', style: TextStyle(fontSize: 18)),
                        ),
                      ),
                    ]),
                  ),
                  const SizedBox(height: 6),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Real submission flow — same openSubmitDeedFlow used everywhere else in the app (GPS,
  // moderation, cooldowns, all real), not a mock. Only the SELECTION here is testing-scoped
  // (donation types excluded, 3 choices per category); once picked, everything downstream is
  // the genuine, already-proven submission path.
  // Real bug fixed here: this had zero cooldown-awareness at all — every task always looked
  // tappable regardless of actual state. The backend correctly blocked a submission during
  // cooldown (openSubmitDeedFlow → submitPhotoDeed's own real check), but nothing here reflected
  // that visually beforehand — confirmed the exact gap you found through real testing. Now reuses
  // the same cooldownRemaining check Home already uses, greying out and disabling anything
  // actually on cooldown instead of only finding out after tapping.
  // Real fix here: the equip flow that used to live here is gone entirely — purchase and equip
  // both moved to the Skins store screen, per direction, rather than being split across two
  // places.

  void _showTaskList(BuildContext context) {
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
            Text('The easiest tasks in each category — one tap to get started.', style: AppFonts.inter(size: 11.5, color: AppColors.textSoft)),
            const SizedBox(height: 16),
            for (final cat in categoryDefs) ...[
              if ((easiest[cat.key] ?? []).isNotEmpty) ...[
                Text('${cat.icon} ${cat.name}', style: AppFonts.inter(size: 12.5, weight: FontWeight.w700, color: AppColors.textSoft)),
                const SizedBox(height: 8),
                ...easiest[cat.key]!.map((type) {
                  final meta = deedCatalog[type]!;
                  final onCooldown = state.cooldownRemaining(type) > Duration.zero;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: GestureDetector(
                      onTap: onCooldown
                          ? () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Still on cooldown — try again shortly.')))
                          : () {
                              Navigator.of(sheetContext).pop();
                              openSubmitDeedFlow(context, type, campaignId: widget.campaign.id);
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
                const SizedBox(height: 12),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

// The actual road — top-to-bottom progress (journey starts near the top, moves downward), stops
// alternating left/right/center to create the "wiggly" feel. Curved with a cubic S-bend between
// points, and the canvas is taller than the viewport with
// auto-scroll keeping the truck roughly centered — the "screen moves with the avatar's journey"
// feel, achieved with Flutter's own ScrollController rather than a real 3D engine.
class _FuelBar extends StatelessWidget {
  final List<RoadmapStop> stops;
  final int deedsDone;
  const _FuelBar({required this.stops, required this.deedsDone});

  @override
  Widget build(BuildContext context) {
    final allThresholds = [0, ...stops.map((s) => s.threshold)];
    // Find which segment current progress falls within, and how full it is — segments aren't
    // equal length (3, then +4, then +5), so this fills based on the REAL length of whichever
    // segment we're actually in, not a naive deedsDone/maxThreshold fraction.
    //
    // Real off-by-one bug fixed here, confirmed through actual testing: at exactly a threshold
    // (deedsDone == 3, say), the old <= upper bound matched the segment that had JUST ended
    // ([0,3], remaining = 3-3 = 0) instead of the one actually ahead ([3,7], remaining = 4) —
    // which is exactly "0 deeds to next stop" showing at a stop that was just reached, not
    // completed. Now uses a strict < upper bound for every segment except the very last one,
    // where <= is still correct and needed to catch the genuine "road complete" state.
    var segStart = allThresholds[0];
    var segEnd = allThresholds[1];
    for (var i = 0; i < allThresholds.length - 1; i++) {
      final isLastSegment = i == allThresholds.length - 2;
      final upperMatches = isLastSegment ? deedsDone <= allThresholds[i + 1] : deedsDone < allThresholds[i + 1];
      if (deedsDone >= allThresholds[i] && upperMatches) {
        segStart = allThresholds[i];
        segEnd = allThresholds[i + 1];
        break;
      }
    }
    final fraction = segEnd == segStart ? 1.0 : ((deedsDone - segStart) / (segEnd - segStart)).clamp(0.0, 1.0);
    final remaining = segEnd - deedsDone;
    final isMaxed = deedsDone >= allThresholds.last;

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        // Real fix here: sized up, per direction — was easy to miss at the old small size.
        Text('⛽ Fuel', style: AppFonts.plexMono(size: 12, weight: FontWeight.w700, color: AppColors.textSoft)),
        Text(
          isMaxed ? 'Road complete!' : '$remaining deed${remaining == 1 ? '' : 's'} to next stop',
          style: AppFonts.plexMono(size: 12, weight: FontWeight.w700, color: AppColors.textSoft),
        ),
      ]),
      const SizedBox(height: 8),
      ClipRRect(
        borderRadius: BorderRadius.circular(100),
        child: LinearProgressIndicator(
          value: fraction,
          minHeight: 16,
          backgroundColor: AppColors.bg1.withOpacity(0.4),
          valueColor: AlwaysStoppedAnimation(AppColors.gold),
        ),
      ),
    ]);
  }
}

class RoadmapRoadView extends StatefulWidget {
  final Campaign campaign; // new — needed for the default vehicle icon and campaign-scoped equip lookup
  final List<RoadmapStop> stops;
  final int deedsDone;
  final Set<String> claimedStopIds; // real fix here: this field was never updated when the
  // parent switched from local threshold-based tracking to real, id-based claim persistence —
  // a genuine mismatch (the parent was passing claimedStopIds to a parameter that didn't exist)
  // that would have failed to compile.
  final void Function(RoadmapStop) onStopTap;
  const RoadmapRoadView({required this.campaign, required this.stops, required this.deedsDone, required this.claimedStopIds, required this.onStopTap});

  @override
  State<RoadmapRoadView> createState() => _RoadmapRoadViewState();
}

class _RoadmapRoadViewState extends State<RoadmapRoadView> with SingleTickerProviderStateMixin {
  // Real change here, not a tuning tweak: plain scrolling can only pan, not zoom — "pan in"
  // (zoom in while following) genuinely needs InteractiveViewer's transform matrix instead of a
  // simple scroll offset. TransformationController has no built-in animateTo, so this drives its
  // own tween manually, matching the truck's 900ms pace exactly.
  final _transformController = TransformationController();
  late final AnimationController _animController;
  Matrix4? _fromMatrix;
  Matrix4? _toMatrix;

  @override
  void initState() {
    super.initState();
    // Real fix here: 900ms still read as too fast, per direction — slowed further to genuinely
    // feel like travel, not a quick snap.
    _animController = AnimationController(vsync: this, duration: const Duration(milliseconds: 1600))
      ..addListener(() {
        if (_fromMatrix != null && _toMatrix != null) {
          _transformController.value = Matrix4Tween(begin: _fromMatrix, end: _toMatrix).transform(Curves.easeInOut.transform(_animController.value));
        }
      });
  }

  @override
  void dispose() {
    _animController.dispose();
    _transformController.dispose();
    super.dispose();
  }

  // Real fix here — two compounding bugs found through actual testing, not a tuning issue:
  // (1) the old fraction (deedsDone/maxThreshold) didn't match the truck's real pixel position,
  // since stops are spaced evenly by INDEX visually but unevenly by threshold value (3, +4, +5)
  // — the two never lined up. (2) reverse:true had the scroll direction genuinely backwards,
  // meaning the camera was mathematically centering on the wrong part of the canvas — exactly
  // "focuses on the background more." This centering logic itself is orientation-agnostic — it
  // just centers on whatever pixel the truck actually reports, regardless of which way the
  // canvas is laid out. The canvas orientation itself (start at bottom, final stop at top —
  // matching "truck drives away from you," not toward you) lives in the y-position formula
  // below, not here.
  //
  // New — zoomed in now, per direction ("pan in on the screen"), not just centered at 1:1 scale.
  static const double _zoomScale = 1.35;
  void _focusOnTruck(Offset truckPos, double viewportW, double viewportH) {
    final targetX = viewportW / 2 - truckPos.dx * _zoomScale;
    final targetY = viewportH / 2 - truckPos.dy * _zoomScale;
    final targetMatrix = Matrix4.identity()
      ..translate(targetX, targetY)
      ..scale(_zoomScale);
    _fromMatrix = _transformController.value.clone();
    _toMatrix = targetMatrix;
    _animController.forward(from: 0);
  }

  // Same x the stop marker uses (markers sit beside the road, not on it).
  double _markerLeft(List<Offset> points, List<double> xFractions, int i) =>
      points[i + 1].dx + (xFractions[(i + 1) % xFractions.length] < 0.5 ? 60 : -116);

  // Guddi on the journey. The camera follows the truck, so her guide spot is right beside it
  // (on the side away from the stop marker) — "Bas N aur!" to the next stop, or strong
  // "Road complete! 💪" once the last stop is reached. A strong Guddi also waits at the final stop
  // as the goal, visible when panning ahead.
  List<Widget> _roadGuddi(List<Offset> points, List<double> xFractions, Offset truckPos, double canvasW) {
    final stops = widget.stops;
    if (stops.isEmpty) return const [];
    final last = stops.length - 1;
    final nextIdx = stops.indexWhere((s) => widget.deedsDone < s.threshold); // -1 = road complete
    final complete = nextIdx == -1;
    final out = <Widget>[];

    if (!complete) {
      // The goal: strong Guddi beside the final stop's marker, on the side away from the road.
      final markerLeft = _markerLeft(points, xFractions, last);
      final markerRightOfRoad = xFractions[(last + 1) % xFractions.length] < 0.5;
      const goalH = 84.0, goalW = 60.0;
      out.add(Positioned(
        left: markerRightOfRoad ? markerLeft + 56 + 4 : markerLeft - 4 - goalW,
        top: points[last + 1].dy + 28 - goalH,
        child: IgnorePointer(child: SizedBox(width: goalW, child: _RoadGuddi(pose: GuddiPoses.strong, height: goalH))),
      ));
    }

    // The guide, beside the truck. Positioned by her real width (poses are ~0.65 wide:tall), and
    // her bubble extends from her toward the road so it never runs off the screen edge.
    const guideH = 88.0, guideW = 58.0;
    final reachedIdx = stops.lastIndexWhere((s) => widget.deedsDone >= s.threshold); // -1 = at START
    final markerRightOfRoad = reachedIdx == -1 || xFractions[(reachedIdx + 1) % xFractions.length] < 0.5;
    // Marker to the right → Guddi on the left of the truck, and vice versa; kept inside the canvas.
    final guddiLeft = (markerRightOfRoad ? truckPos.dx - 24 - 4 - guideW : truckPos.dx + 24 + 4).clamp(0.0, canvasW - guideW);
    final guddiTop = truckPos.dy + 30 - guideH; // feet level with the truck's base
    out.add(Positioned(
      left: guddiLeft,
      top: guddiTop,
      child: IgnorePointer(child: SizedBox(width: guideW, child: _RoadGuddi(pose: complete ? GuddiPoses.strong : GuddiPoses.chatty, height: guideH))),
    ));
    final bubble = IgnorePointer(child: _RoadBubble(complete ? 'Road complete! 💪' : 'Bas ${stops[nextIdx].threshold - widget.deedsDone} aur!'));
    out.add(markerRightOfRoad
        ? Positioned(left: guddiLeft, top: guddiTop - 30, child: bubble)
        : Positioned(right: canvasW - guddiLeft - guideW, top: guddiTop - 30, child: bubble));
    return out;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final w = constraints.maxWidth;
      final viewportH = constraints.maxHeight;
      // Canvas taller than the viewport — this is what actually creates the scrolling-journey
      // feel, real room to travel through rather than everything visible flat at once.
      final canvasH = viewportH * 1.8;

      final xFractions = [0.5, 0.22, 0.78, 0.5];
      final points = <Offset>[];
      final allThresholds = [0, ...widget.stops.map((s) => s.threshold)];
      for (var i = 0; i < allThresholds.length; i++) {
        final x = w * xFractions[i % xFractions.length];
        // Real bug fixed here, confirmed through actual testing: the previous flip (start at
        // top, progress toward bottom) made the vehicle look like it was driving TOWARD the
        // viewer instead of away — bottom-of-screen reads as "closer" in normal visual
        // convention. Reversed back: start near the BOTTOM (large y), final stop near the TOP
        // (small y) — the centering/scroll logic itself doesn't need to change, since it
        // already works directly off the vehicle's real computed position either way.
        final y = canvasH * (0.94 - (i / (allThresholds.length - 1)) * 0.88);
        points.add(Offset(x, y));
      }

      // Real mechanic change here: the vehicle now snaps to its last REACHED stop instead of
      // continuously interpolating between stops per-deed. Progress toward the next stop is
      // shown separately by the fuel bar above — AnimatedPositioned still gives a smooth slide
      // when the vehicle actually does move to a newly-reached stop, just not a step-by-step
      // creep for every single deed anymore.
      Offset truckPos = points.first;
      for (var i = 0; i < allThresholds.length - 1; i++) {
        if (widget.deedsDone >= allThresholds[i + 1]) truckPos = points[i + 1];
      }

      // Centers and zooms on the truck's real, already-computed position — no separate fraction
      // calculation that could drift out of sync with where the truck actually is.
      WidgetsBinding.instance.addPostFrameCallback((_) => _focusOnTruck(truckPos, w, viewportH));

      return InteractiveViewer(
        transformationController: _transformController,
        // Real fix here — genuine regression from the zoom-in change: disabling pan entirely
        // also removed the ability to manually look back at earlier stops, which was never the
        // intent. Auto-focus still runs whenever the truck moves, but the person can now pan
        // away from that focused view to look around on their own. Scale (pinch-zoom) stays
        // programmatic-only, since the zoom level itself is a deliberate camera choice, not
        // something meant to be user-adjustable.
        panEnabled: true,
        scaleEnabled: false,
        constrained: false,
        boundaryMargin: const EdgeInsets.all(double.infinity),
        child: SizedBox(
          width: w,
          height: canvasH,
          child: Stack(
            // Not clipped: Guddi near the final stop can reach above the canvas's top edge.
            clipBehavior: Clip.none,
            children: [
              Positioned.fill(child: CustomPaint(painter: _RoadPainter(points: points, roadColor: widget.campaign.roadColor(AppColors.oliveCardStrong)))),
              // Truck rendered BEFORE the stop markers now, not after — real bug fixed here.
              // It used to render on top of them, which meant right at the exact moment a stop
              // became reachable, the truck's own hit-test area was physically blocking taps
              // meant for the stop marker underneath it. Stops now correctly render above it.
              AnimatedPositioned(
                // Real fix here: slowed further, per direction — 900ms still read as too fast.
                duration: const Duration(milliseconds: 1600),
                curve: Curves.easeInOut,
                // Real fix here: offset updated to match the new, bigger size below (half of
                // 48 now, was half of the old 32) — keeps the icon properly centered on its
                // actual road position instead of shifting it off-center.
                left: truckPos.dx - 24,
                top: truckPos.dy - 24,
                child: IgnorePointer(
                  // Belt-and-suspenders alongside the reordering above — the truck should never
                  // be interactive at all, so this guarantees it can't block taps even if
                  // something about the ordering changes again later.
                  child: Builder(builder: (context) {
                    // Reverted back to per-campaign, per direction: this campaign's own default
                    // vehicle shows unless a skin is equipped specifically for it — never a
                    // mismatched skin from somewhere else.
                    // Real, confirmed final direction: genuinely global equip — whatever's
                    // equipped shows on every roadmap, regardless of which campaign it came
                    // from. A new campaign going active automatically clears this for everyone
                    // (see auto_unequip_on_new_campaign.sql), so a fresh campaign always starts
                    // on the default vehicle unless the person deliberately re-equips something.
                    final vehicleIcon = context.watch<AppState>().equippedSkinIcon ?? widget.campaign.defaultVehicleIcon;
                    final isRealArt = vehicleIcon.startsWith('http://') || vehicleIcon.startsWith('https://');
                    // Real fix here: the solid gold badge behind this made sense for a plain
                    // emoji, which needs something to give it presence on the road. Real,
                    // detailed art (like the tank) already has its own visual weight — the gold
                    // square just fights it, showing up as an unwanted frame around actual
                    // artwork instead of the icon standing on its own. Now only shown for emoji;
                    // real images get just a soft shadow for grounding, no solid fill.
                    return Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: isRealArt ? null : AppColors.gold,
                        borderRadius: BorderRadius.circular(9),
                        boxShadow: [BoxShadow(color: AppColors.gold.withOpacity(isRealArt ? 0.35 : 0.5), blurRadius: isRealArt ? 10 : 14)],
                      ),
                      alignment: Alignment.center,
                      // Real fix here: this was reading the old single global activeSkinIcon,
                      // which no longer exists. Now correctly scoped to THIS campaign's own
                      // equipped skin, falling back to the campaign's real default vehicle (not
                      // a hardcoded truck) if nothing's been equipped for it yet.
                      child: CampaignIcon(icon: vehicleIcon, size: isRealArt ? 48 : 24),
                    );
                  }),
                ),
              ),
              for (var i = 0; i < widget.stops.length; i++)
                Positioned(
                  // Real redesign here, not just a bug patch: stops used to sit directly on the
                  // road at the exact same coordinates the truck travels through, so the moment
                  // the truck arrived at a stop, its own gift-icon marker completely covered the
                  // truck underneath it — you could no longer see where the truck actually was.
                  // Stops now sit offset to the side of the road instead, genuinely separate
                  // positions rather than sharing one spot — the truck stays exactly on the
                  // path, the stop markers (with their point values) sit beside it.
                  left: points[i + 1].dx + (xFractions[(i + 1) % xFractions.length] < 0.5 ? 60 : -116),
                  top: points[i + 1].dy - 28,
                  child: _StopMarker(
                    stop: widget.stops[i],
                    reached: widget.deedsDone >= widget.stops[i].threshold,
                    claimed: widget.claimedStopIds.contains(widget.stops[i].id),
                    onTap: () => widget.onStopTap(widget.stops[i]),
                  ),
                ),
              Positioned(
                left: points.first.dx - 20,
                top: points.first.dy - 10,
                child: Text('START', style: AppFonts.plexMono(size: 9, color: AppColors.textSoft)),
              ),
              // Guddi on the journey (presentation only, never blocks taps):
              //  - a small cheer-Guddi badge on every claimed stop
              //  - Guddi as the guide above the next stop still to reach ("Bas N aur!")
              //  - strong Guddi at the final stop ("Road complete! 💪" once reached)
              for (var i = 0; i < widget.stops.length; i++)
                if (widget.claimedStopIds.contains(widget.stops[i].id) && i != widget.stops.length - 1)
                  Positioned(
                    left: _markerLeft(points, xFractions, i) + 38,
                    top: points[i + 1].dy - 38,
                    child: IgnorePointer(child: _GuddiBadge(pose: GuddiPoses.cheer)),
                  ),
              ..._roadGuddi(points, xFractions, truckPos, w),
            ],
          ),
        ),
      );
    });
  }
}

// Guddi standing on the road, bobbing gently; fades out at the bottom (waist-cropped poses).
class _RoadGuddi extends StatefulWidget {
  final String pose;
  final double height;
  const _RoadGuddi({required this.pose, required this.height});
  @override
  State<_RoadGuddi> createState() => _RoadGuddiState();
}

class _RoadGuddiState extends State<_RoadGuddi> with SingleTickerProviderStateMixin {
  late final AnimationController _bob = AnimationController(vsync: this, duration: const Duration(milliseconds: 1800))..repeat(reverse: true);
  @override
  void dispose() {
    _bob.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _bob,
      builder: (_, child) => Transform.translate(offset: Offset(0, -3 * Curves.easeInOut.transform(_bob.value)), child: child),
      child: ShaderMask(
        blendMode: BlendMode.dstIn,
        shaderCallback: (r) => const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.white, Colors.white, Colors.transparent],
          stops: [0, 0.78, 1],
        ).createShader(r),
        child: Image.asset(widget.pose, height: widget.height, fit: BoxFit.contain),
      ),
    );
  }
}

class _RoadBubble extends StatelessWidget {
  final String text;
  const _RoadBubble(this.text);
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 2),
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.bg2.withOpacity(0.92),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.gold.withOpacity(0.5)),
      ),
      child: Text(text, style: AppFonts.inter(size: 11, weight: FontWeight.w700, color: AppColors.text)),
    );
  }
}

// Small round cheer-Guddi badge pinned to a claimed stop.
class _GuddiBadge extends StatelessWidget {
  final String pose;
  const _GuddiBadge({required this.pose});
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 30, height: 30,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(shape: BoxShape.circle, color: AppColors.bg2, border: Border.all(color: AppColors.gold, width: 1.5)),
      child: Image.asset(pose, fit: BoxFit.cover, alignment: const Alignment(0, -0.85)),
    );
  }
}

class _RoadPainter extends CustomPainter {
  final List<Offset> points;
  final Color roadColor; // new — real, per-campaign color, passed in rather than hardcoded
  const _RoadPainter({required this.points, required this.roadColor});
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = roadColor
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    // More pronounced bend now, per the direction — cubic bezier with two control points
    // instead of one quadratic point, giving a real S-curve between each pair rather than a
    // subtle lean.
    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (var i = 0; i < points.length - 1; i++) {
      final p1 = points[i];
      final p2 = points[i + 1];
      final control1 = Offset(p1.dx, p1.dy + (p2.dy - p1.dy) * 0.4);
      final control2 = Offset(p2.dx, p1.dy + (p2.dy - p1.dy) * 0.6);
      path.cubicTo(control1.dx, control1.dy, control2.dx, control2.dy, p2.dx, p2.dy);
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _RoadPainter oldDelegate) => oldDelegate.points != points || oldDelegate.roadColor != roadColor;
}

class _StopMarker extends StatelessWidget {
  final RoadmapStop stop;
  final bool reached;
  final bool claimed;
  final VoidCallback onTap;
  const _StopMarker({required this.stop, required this.reached, required this.claimed, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final color = claimed ? AppColors.olive : (reached ? AppColors.gold : AppColors.bg2);
    return GestureDetector(
      onTap: reached ? onTap : null,
      child: Column(children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color,
            border: Border.all(color: reached ? AppColors.gold : AppColors.textSoft.withOpacity(0.4), width: 2),
          ),
          alignment: Alignment.center,
          child: Text(
            claimed ? '✓' : (reached ? '🎁' : '🔒'),
            style: TextStyle(fontSize: 20, color: reached ? AppColors.inkOnGold : AppColors.textSoft),
          ),
        ),
        const SizedBox(height: 4),
        Text('${stop.threshold}', style: AppFonts.plexMono(size: 10, weight: FontWeight.w700, color: reached ? AppColors.gold : AppColors.textSoft)),
      ]),
    );
  }
}

// New — carries the full outcome, not just win/lose. Needed since Stop 2's mechanic has real
// outcomes beyond a simple boolean: a free skin grant, or a discount grant, neither of which
// "won" alone can express.
class _ClaimResult {
  final bool won;
  final String outcome; // 'free_skin', 'discount', 'prize', or 'none'
  final int? discountPercent;
  final int? prizePoints; // new — real points actually credited, for a standard-mode win
  const _ClaimResult({required this.won, required this.outcome, this.discountPercent, this.prizePoints});
}

class _MysteryBoxSheet extends StatefulWidget {
  final RoadmapStop stop;
  final void Function(_ClaimResult result) onFinished;
  const _MysteryBoxSheet({required this.stop, required this.onFinished});
  @override
  State<_MysteryBoxSheet> createState() => _MysteryBoxSheetState();
}

class _MysteryBoxSheetState extends State<_MysteryBoxSheet> {
  late List<GlobalKey<FlipCardState>> cardKeys;
  int? pickedIndex; // locked in once chosen — "tap is final answer"
  bool? pickedWon; // the real, server-decided result — only known after the tap comes back
  bool loading = false;
  String? error;

  @override
  void initState() {
    super.initState();
    cardKeys = List.generate(widget.stop.totalBoxes, (_) => GlobalKey<FlipCardState>());
  }

  // Real connection to the claim-roadmap-stop Edge Function now — replacing the old client-side
  // shuffle. The server decides win/lose, verifying real progress and preventing a double-claim
  // itself, not just trusting whatever the app's local state believes. Only this one box's real
  // result comes back; the other 8 genuinely have no answer, since nothing was decided for them.
  Future<void> _pick(int index) async {
    if (pickedIndex != null || loading) return;
    setState(() { loading = true; error = null; });
    try {
      final response = await Supabase.instance.client.functions.invoke(
        'claim-roadmap-stop',
        body: {'stop_id': widget.stop.id, 'picked_index': index},
      );
      final data = response.data as Map<String, dynamic>?;
      if (data == null || data['error'] != null) {
        setState(() { loading = false; error = (data?['error'] as String?) ?? 'Could not complete this — try again.'; });
        return;
      }
      final won = data['won'] as bool;
      setState(() {
        pickedIndex = index;
        pickedWon = won;
        loading = false;
      });
      cardKeys[index].currentState?.flip();
      widget.onFinished(_ClaimResult(
        won: won,
        outcome: data['outcome'] as String? ?? (won ? 'prize' : 'none'),
        discountPercent: data['discount_percent'] as int?,
        prizePoints: data['prize_points'] as int?,
      ));
    } catch (e) {
      if (mounted) setState(() { loading = false; error = 'Could not complete this — check your connection and try again.'; });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Safety net alongside isScrollControlled: true on the sheet itself — this makes the
    // content genuinely scrollable if it's still too tall even at full screen height (a very
    // small device, larger text-size setting, etc.), rather than assuming full-screen alone
    // always guarantees enough room.
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 30),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('${widget.stop.label} — pick a box', style: AppFonts.fraunces(size: 16, weight: FontWeight.w600)),
          const SizedBox(height: 6),
          // Real fix here: "X of Y win" would be misleading for Stop 2's guaranteed mechanic,
          // where every card results in something real — no card is actually a "loser" here.
          Text(
            widget.stop.rewardMode == 'guaranteed_with_discount'
                ? 'Every card wins something — pick one, no take-backs.'
                : '${widget.stop.winningBoxes} of ${widget.stop.totalBoxes} win — pick one, no take-backs.',
            style: AppFonts.inter(size: 11.5, color: AppColors.textSoft),
          ),
          if (loading) ...[
            const SizedBox(height: 10),
            Row(children: [
              const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.gold)),
              const SizedBox(width: 8),
              Text('Checking with the server…', style: AppFonts.inter(size: 11, color: AppColors.textSoft)),
            ]),
          ],
          if (error != null) ...[
            const SizedBox(height: 10),
            Text(error!, style: AppFonts.inter(size: 11.5, color: AppColors.rust)),
          ],
          const SizedBox(height: 18),
          // Real fix here: this was a Wrap, which reflows by however many boxes fit the
          // available width (came out 4 across on a typical phone) rather than an actual fixed
          // grid. GridView with an explicit crossAxisCount guarantees exactly 3 columns
          // regardless of screen width.
          GridView.count(
            crossAxisCount: 3,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 0.72, // taller than wide — real playing-card proportions now
            children: List.generate(widget.stop.totalBoxes, (i) {
              final isPicked = pickedIndex == i;
              // Real result now — only the picked box knows its outcome, from the server. The
              // other boxes never flip at all (see _pick), so their "back" content here is
              // never actually seen, but kept sensible regardless.
              final thisWon = isPicked ? (pickedWon ?? false) : false;
              return FlipCard(
                key: cardKeys[i],
                onTap: () => _pick(i),
                // Real card design now, not a box emoji in a square — a question mark on a
                // gradient card face, per the "more of a gamish feel" direction.
                front: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [AppColors.olive.withOpacity(0.35), AppColors.bg1]),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: isPicked ? AppColors.gold : AppColors.gold.withOpacity(0.25), width: isPicked ? 2.5 : 1.5),
                    boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 6, offset: Offset(0, 3))],
                  ),
                  alignment: Alignment.center,
                  child: Text('?', style: AppFonts.fraunces(size: 30, weight: FontWeight.w700).copyWith(color: AppColors.gold.withOpacity(0.85))),
                ),
                back: Container(
                  decoration: BoxDecoration(
                    gradient: thisWon
                        ? LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [AppColors.gold.withOpacity(0.35), AppColors.gold.withOpacity(0.1)])
                        : LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [AppColors.bg1, AppColors.bg2]),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: isPicked ? AppColors.gold : const Color(0x1FF6F5EC), width: isPicked ? 2.5 : 1.5),
                  ),
                  alignment: Alignment.center,
                  // Real fix here: a non-winning tap on Stop 2's guaranteed mechanic is a
                  // discount, not "nothing" — shows a tag icon instead of an empty mailbox,
                  // matching what actually happened rather than implying a loss that didn't occur.
                  child: Text(
                    thisWon ? widget.stop.prize.icon : (widget.stop.rewardMode == 'guaranteed_with_discount' ? '🏷️' : '📭'),
                    style: const TextStyle(fontSize: 26),
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}
