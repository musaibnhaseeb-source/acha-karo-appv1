import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'journey_models.dart';
import 'journey_repository.dart';
import 'remote_config.dart';
import 'roadmap_data.dart';

// Real implementation. The queries and the Edge Function call are the same ones
// lib/screens/roadmap_screen.dart makes today (roadmap_stops, roadmap_claims,
// hall_of_fame_claims, claim-roadmap-stop) — no new tables, columns or functions.
//
// The campaign object and the approved-deed count come from the app's existing state, passed in,
// exactly as roadmap_screen.dart takes them from the widget and AppState.deedsLog.
class SupabaseJourneyRepository implements JourneyRepository {
  final Campaign campaign;
  final int Function() approvedDeedCount; // approved deeds with campaign_id == campaign.id
  final Future<void> Function()? reloadProfile; // e.g. AppState.tryLoadExistingProfile
  final JourneyTheme theme;
  final _Notifier _changes = _Notifier();

  SupabaseJourneyRepository({
    required this.campaign,
    required this.approvedDeedCount,
    this.reloadProfile,
    this.theme = JourneyTheme.fallback,
  });

  @override
  Listenable get changes => _changes;

  // The screen reloads when this fires; the host calls it when the approved-deed count changes.
  void refresh() => _changes.ping();

  SupabaseClient get _db => Supabase.instance.client;

  @override
  Future<JourneyConfig> loadCampaign(String campaignId) async {
    try {
      final rows = await _db.from('roadmap_stops').select().eq('campaign_id', campaignId).order('threshold', ascending: true);
      return JourneyConfig(campaign: campaign, stops: rows.map<RoadmapStop>((r) => RoadmapStop.fromRow(r)).toList(), theme: theme);
    } catch (_) {
      throw const JourneyException("Couldn't load this campaign's roadmap. Check your connection and try again.");
    }
  }

  @override
  Future<JourneyProgress> loadProgress(String campaignId) async {
    try {
      final uid = _db.auth.currentUser?.id;
      final deeds = approvedDeedCount();
      if (uid == null) return JourneyProgress(deedsDone: deeds);
      final stopRows = await _db.from('roadmap_stops').select('id').eq('campaign_id', campaignId);
      final stopIds = stopRows.map<String>((r) => r['id'] as String).toList();
      if (stopIds.isEmpty) return JourneyProgress(deedsDone: deeds);
      final claimRows = await _db.from('roadmap_claims').select('stop_id, won').eq('user_id', uid).inFilter('stop_id', stopIds);
      final hofRow = await _db.from('hall_of_fame_claims').select('campaign_id').eq('user_id', uid).eq('campaign_id', campaignId).maybeSingle();
      return JourneyProgress(
        deedsDone: deeds,
        claims: {for (final r in claimRows) r['stop_id'] as String: ClaimRecord(won: r['won'] as bool)},
        hallOfFameClaimed: hofRow != null,
      );
    } catch (_) {
      throw const JourneyException("Couldn't load your progress. Check your connection and try again.");
    }
  }

  @override
  Future<ClaimOutcome> claimStop(String stopId, int pickedIndex) async {
    try {
      final response = await _db.functions.invoke('claim-roadmap-stop', body: {'stop_id': stopId, 'picked_index': pickedIndex});
      final data = response.data as Map<String, dynamic>?;
      if (data == null || data['error'] != null) {
        throw JourneyException((data?['error'] as String?) ?? 'Could not complete this — try again.');
      }
      final won = data['won'] as bool;
      _changes.ping();
      return ClaimOutcome(
        won: won,
        outcome: data['outcome'] as String? ?? (won ? 'prize' : 'none'),
        discountPercent: data['discount_percent'] as int?,
        prizePoints: data['prize_points'] as int?,
        skinId: data['skin_id'] as String?,
      );
    } on JourneyException {
      rethrow;
    } catch (_) {
      throw const JourneyException('Could not complete this — check your connection and try again.');
    }
  }

  @override
  Future<void> refreshAfterClaim() async {
    await reloadProfile?.call();
  }
}

class _Notifier extends ChangeNotifier {
  void ping() => notifyListeners();
}
