import 'dart:math';
import '../data/journey_models.dart';
import '../data/roadmap_data.dart';

// UAT re-implementation of the claim rules. Every function names the step of
// supabase/functions/claim-roadmap-stop/index.ts it mirrors — when that function changes, this
// file and lib/uat/README.md must be re-checked (see the drift table there).

enum UatClaimMode { random, forceWin, forceLose }

// MIRRORS: claim-roadmap-stop step 2 (`count < stop.threshold` -> 403).
bool hasReachedStop(int deedsDone, RoadmapStop stop) => deedsDone >= stop.threshold;

// MIRRORS: claim-roadmap-stop step 4 — shuffle all indices, winners are the first winning_boxes.
// forceWin / forceLose (UAT only) then adjust the set so the picked box gets the wanted result.
Set<int> drawWinningIndices(RoadmapStop stop, int pickedIndex, Random rng, UatClaimMode mode) {
  final all = List<int>.generate(stop.totalBoxes, (i) => i)..shuffle(rng);
  final winners = all.take(stop.winningBoxes).toSet();
  if (mode == UatClaimMode.forceWin && !winners.contains(pickedIndex) && winners.isNotEmpty) {
    winners.remove(winners.first);
    winners.add(pickedIndex);
  } else if (mode == UatClaimMode.forceLose && winners.contains(pickedIndex)) {
    final spare = all.where((i) => !winners.contains(i)).toList();
    if (spare.isNotEmpty) {
      winners.remove(pickedIndex);
      winners.add(spare.first);
    }
  }
  return winners;
}

// MIRRORS: claim-roadmap-stop steps 1-6, in the server's check order and with its error strings.
// prizePoints stands in for roadmap_stops.prize_points, which RoadmapStop does not expose.
ClaimOutcome resolveClaim({
  required RoadmapStop stop,
  required int pickedIndex,
  required int deedsDone,
  required bool alreadyClaimed,
  required Random rng,
  UatClaimMode mode = UatClaimMode.random,
  int? prizePoints,
}) {
  // step 1: invalid box -> 400
  if (pickedIndex < 0 || pickedIndex >= stop.totalBoxes) throw const JourneyException('Invalid box.');
  // step 2: not reached -> 403
  if (!hasReachedStop(deedsDone, stop)) throw const JourneyException('You have not reached this stop yet.');
  // step 3: already claimed -> 409
  if (alreadyClaimed) throw const JourneyException('You have already claimed this stop.');
  // step 4: decide
  final won = drawWinningIndices(stop, pickedIndex, rng, mode).contains(pickedIndex);
  // step 6: reward mode. guaranteed_with_discount only applies when a skin is attached; with no
  // skin_id the server falls through to the standard branch, so this does too.
  if (stop.rewardMode == 'guaranteed_with_discount' && stop.skinId != null) {
    return won
        ? ClaimOutcome(won: true, outcome: 'free_skin', skinId: stop.skinId)
        : ClaimOutcome(won: false, outcome: 'discount', skinId: stop.skinId, discountPercent: stop.discountPercent);
  }
  // The server credits points only when prize_points is truthy (non-null, non-zero).
  final points = (won && prizePoints != null && prizePoints > 0) ? prizePoints : null;
  return ClaimOutcome(won: won, outcome: won ? 'prize' : 'none', prizePoints: points);
}
