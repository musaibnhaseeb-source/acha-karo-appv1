import 'dart:math';
import 'package:flutter/foundation.dart';
import '../data/journey_models.dart';
import '../data/journey_repository.dart';
import 'uat_rules.dart';
import 'uat_seed.dart';

// In-memory JourneyRepository for UAT. No network, no persistence: restarting the app restores
// the seed. Also a ChangeNotifier so the UAT drawer can rebuild on user/campaign changes.
class UatJourneyRepository extends ChangeNotifier implements JourneyRepository {
  final List<UatCampaignSeed> campaigns;
  late List<UatUserState> users;
  late String _currentUserId;
  UatClaimMode claimMode = UatClaimMode.random;
  final Random _rng;

  UatJourneyRepository({Random? rng})
      : campaigns = UatSeed.campaigns(),
        _rng = rng ?? Random() {
    users = UatSeed.users(campaigns);
    _currentUserId = users.first.id;
  }

  UatUserState get user => users.firstWhere((u) => u.id == _currentUserId);

  @override
  Listenable get changes => this;

  UatCampaignSeed seedFor(String campaignId) => campaigns.firstWhere((c) => c.campaign.id == campaignId);

  // --- JourneyRepository ---

  @override
  Future<JourneyConfig> loadCampaign(String campaignId) async => seedFor(campaignId).toConfig();

  @override
  Future<JourneyProgress> loadProgress(String campaignId) async => JourneyProgress(
        deedsDone: user.deeds[campaignId] ?? 0,
        claims: Map.of(user.claims[campaignId] ?? {}),
        hallOfFameClaimed: user.hallOfFame.contains(campaignId),
      );

  @override
  Future<ClaimOutcome> claimStop(String stopId, int pickedIndex) async {
    final seed = campaigns.where((c) => c.stops.any((s) => s.id == stopId)).toList();
    if (seed.isEmpty) throw const JourneyException('Stop not found.');
    final cid = seed.first.campaign.id;
    final stop = seed.first.stops.firstWhere((s) => s.id == stopId);
    final claims = user.claims.putIfAbsent(cid, () => {});
    final outcome = resolveClaim(
      stop: stop,
      pickedIndex: pickedIndex,
      deedsDone: user.deeds[cid] ?? 0,
      alreadyClaimed: claims.containsKey(stopId),
      rng: _rng,
      mode: claimMode,
      prizePoints: seed.first.prizePoints[stopId],
    );
    // step 5 (record the claim) and step 6 side effects, against the UAT user only.
    claims[stopId] = ClaimRecord(won: outcome.won);
    if (outcome.outcome == 'free_skin' && outcome.skinId != null) user.skins.add(outcome.skinId!);
    if (outcome.outcome == 'discount' && outcome.skinId != null) user.discounts[outcome.skinId!] = outcome.discountPercent ?? 0;
    if (outcome.prizePoints != null) user.points += outcome.prizePoints!;
    notifyListeners();
    return outcome;
  }

  @override
  Future<void> refreshAfterClaim() async {}

  // --- UAT-only controls (drawer) ---

  void switchUser(String id) {
    _currentUserId = id;
    notifyListeners();
  }

  // "Complete an acha kaam": one more approved deed for this campaign, no photo or GPS.
  void completeAchaKaam(String campaignId) {
    user.deeds[campaignId] = (user.deeds[campaignId] ?? 0) + 1;
    notifyListeners();
  }

  void setDeeds(String campaignId, int n) {
    user.deeds[campaignId] = max(0, n);
    notifyListeners();
  }

  // Clears this user's progress and claims for one campaign.
  void resetUserCampaign(String campaignId) {
    user.deeds[campaignId] = 0;
    user.claims[campaignId] = {};
    user.hallOfFame.remove(campaignId);
    notifyListeners();
  }

  // Back to the seed for everyone.
  void resetAll() {
    final keep = _currentUserId;
    users = UatSeed.users(campaigns);
    _currentUserId = keep;
    claimMode = UatClaimMode.random;
    notifyListeners();
  }

  void setClaimMode(UatClaimMode m) {
    claimMode = m;
    notifyListeners();
  }
}
