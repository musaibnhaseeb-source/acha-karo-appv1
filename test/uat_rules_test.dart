import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:acha_karo/data/journey_models.dart';
import 'package:acha_karo/data/roadmap_data.dart';
import 'package:acha_karo/uat/uat_journey_repository.dart';
import 'package:acha_karo/uat/uat_rules.dart';
import 'package:acha_karo/uat/uat_seed.dart';

// Expectations copied from supabase/functions/claim-roadmap-stop/index.ts. If that function
// changes, update these together with lib/uat/uat_rules.dart and lib/uat/README.md.
void main() {
  const prize = RoadmapPrize(name: 'P', icon: 'x');
  const standard = RoadmapStop(id: 's', threshold: 3, label: 'S', totalBoxes: 9, winningBoxes: 3, prize: prize);
  const guaranteed = RoadmapStop(
    id: 'g', threshold: 3, label: 'G', totalBoxes: 9, winningBoxes: 3, prize: prize,
    rewardMode: 'guaranteed_with_discount', skinId: 'skin', discountPercent: 40,
  );
  const guaranteedNoSkin = RoadmapStop(id: 'n', threshold: 3, label: 'N', totalBoxes: 9, winningBoxes: 3, prize: prize, rewardMode: 'guaranteed_with_discount');

  ClaimOutcome claim(RoadmapStop s, {int pick = 0, int deeds = 3, bool claimed = false, UatClaimMode mode = UatClaimMode.random, int? points}) =>
      resolveClaim(stop: s, pickedIndex: pick, deedsDone: deeds, alreadyClaimed: claimed, rng: Random(1), mode: mode, prizePoints: points);

  group('refusals (server error strings, server check order)', () {
    test('invalid box', () {
      expect(() => claim(standard, pick: 9), throwsA(isA<JourneyException>().having((e) => e.message, 'message', 'Invalid box.')));
      expect(() => claim(standard, pick: -1), throwsA(isA<JourneyException>()));
    });
    test('not reached: boundary is >= threshold', () {
      expect(() => claim(standard, deeds: 2), throwsA(isA<JourneyException>().having((e) => e.message, 'message', 'You have not reached this stop yet.')));
      expect(claim(standard, deeds: 3, mode: UatClaimMode.forceWin).won, isTrue);
    });
    test('already claimed', () {
      expect(() => claim(standard, claimed: true), throwsA(isA<JourneyException>().having((e) => e.message, 'message', 'You have already claimed this stop.')));
    });
    test('invalid box is reported before not-reached; not-reached before already-claimed', () {
      expect(() => claim(standard, pick: 99, deeds: 0), throwsA(isA<JourneyException>().having((e) => e.message, 'message', 'Invalid box.')));
      expect(() => claim(standard, deeds: 0, claimed: true), throwsA(isA<JourneyException>().having((e) => e.message, 'message', 'You have not reached this stop yet.')));
    });
  });

  group('winning set', () {
    test('exactly winning_boxes winners out of total_boxes', () {
      for (var seed = 0; seed < 50; seed++) {
        final w = drawWinningIndices(standard, 4, Random(seed), UatClaimMode.random);
        expect(w.length, 3);
        expect(w.every((i) => i >= 0 && i < 9), isTrue);
      }
    });
    test('force modes decide the picked box and keep the winner count', () {
      for (var seed = 0; seed < 50; seed++) {
        final win = drawWinningIndices(standard, 4, Random(seed), UatClaimMode.forceWin);
        final lose = drawWinningIndices(standard, 4, Random(seed), UatClaimMode.forceLose);
        expect(win.contains(4), isTrue);
        expect(win.length, 3);
        expect(lose.contains(4), isFalse);
        expect(lose.length, 3);
      }
    });
    test('random mode hits roughly winning/total over many picks', () {
      final rng = Random(7);
      var wins = 0;
      const n = 3000;
      for (var i = 0; i < n; i++) {
        if (drawWinningIndices(standard, 0, rng, UatClaimMode.random).contains(0)) wins++;
      }
      expect(wins / n, closeTo(3 / 9, 0.04));
    });
  });

  group('reward modes', () {
    test('standard win -> prize, credits points only when set and non-zero', () {
      final o = claim(standard, mode: UatClaimMode.forceWin, points: 25);
      expect((o.won, o.outcome, o.prizePoints), (true, 'prize', 25));
      expect(claim(standard, mode: UatClaimMode.forceWin).prizePoints, isNull);
      expect(claim(standard, mode: UatClaimMode.forceWin, points: 0).prizePoints, isNull);
    });
    test('standard lose -> none, no points', () {
      final o = claim(standard, mode: UatClaimMode.forceLose, points: 25);
      expect((o.won, o.outcome, o.prizePoints), (false, 'none', null));
    });
    test('guaranteed_with_discount: win -> free_skin, lose -> discount (never nothing)', () {
      final w = claim(guaranteed, mode: UatClaimMode.forceWin);
      expect((w.won, w.outcome, w.skinId), (true, 'free_skin', 'skin'));
      final l = claim(guaranteed, mode: UatClaimMode.forceLose);
      expect((l.won, l.outcome, l.discountPercent, l.skinId), (false, 'discount', 40, 'skin'));
    });
    test('guaranteed mode without skin_id falls through to standard', () {
      expect(claim(guaranteedNoSkin, mode: UatClaimMode.forceWin, points: 5).outcome, 'prize');
      expect(claim(guaranteedNoSkin, mode: UatClaimMode.forceLose).outcome, 'none');
    });
  });

  group('UatJourneyRepository', () {
    late UatJourneyRepository repo;
    setUp(() => repo = UatJourneyRepository(rng: Random(3)));

    test('seed: 3 campaigns, 5 users, differing stop counts', () {
      expect(repo.campaigns.map((c) => c.stops.length), [3, 3, 6]);
      expect(repo.users.length, 5);
      expect(repo.users.any((u) => u.label.contains('@')), isFalse);
    });

    test('seeded users sit at different progress levels', () async {
      final deeds = <int>[];
      for (final u in repo.users) {
        repo.switchUser(u.id);
        deeds.add((await repo.loadProgress(UatSeed.classicId)).deedsDone);
      }
      expect(deeds, [0, 1, 4, 7, 12]);
    });

    test('+1 acha kaam advances one campaign only, and unlocks the next stop at its threshold', () async {
      repo.switchUser('uat-user-started'); // 1 deed
      repo.completeAchaKaam(UatSeed.shortId); // 2 -> Stop 1 (threshold 2)
      expect((await repo.loadProgress(UatSeed.shortId)).deedsDone, 2);
      expect((await repo.loadProgress(UatSeed.classicId)).deedsDone, 1);
      final stop = repo.seedFor(UatSeed.shortId).stops.first;
      repo.setClaimMode(UatClaimMode.forceWin);
      final o = await repo.claimStop(stop.id, 0);
      expect(o.outcome, 'prize');
      expect(repo.user.points, 20);
    });

    test('claim before threshold and second claim are refused; claim is recorded', () async {
      repo.switchUser('uat-user-fresh');
      final stop = repo.seedFor(UatSeed.shortId).stops.first;
      await expectLater(repo.claimStop(stop.id, 0), throwsA(isA<JourneyException>()));
      repo.setDeeds(UatSeed.shortId, 2);
      repo.setClaimMode(UatClaimMode.forceLose);
      await repo.claimStop(stop.id, 0);
      expect((await repo.loadProgress(UatSeed.shortId)).claims[stop.id]?.won, isFalse);
      await expectLater(repo.claimStop(stop.id, 0), throwsA(isA<JourneyException>()));
    });

    test('guaranteed stop grants skin on win, discount on loss', () async {
      repo.switchUser('uat-user-fresh');
      repo.setDeeds(UatSeed.classicId, 7);
      final stops = repo.seedFor(UatSeed.classicId).stops;
      // Stop 1 (threshold 3) is reachable too; claim the guaranteed middle stop only.
      repo.setClaimMode(UatClaimMode.forceLose);
      await repo.claimStop(stops[1].id, 2);
      expect(repo.user.discounts['uat-skin-classic'], 50);
      repo.resetUserCampaign(UatSeed.classicId);
      repo.setDeeds(UatSeed.classicId, 7);
      repo.setClaimMode(UatClaimMode.forceWin);
      await repo.claimStop(stops[1].id, 2);
      expect(repo.user.skins, contains('uat-skin-classic'));
    });

    test('resetAll restores the seed', () async {
      repo.switchUser('uat-user-finished');
      repo.resetUserCampaign(UatSeed.longId);
      repo.resetAll();
      expect((await repo.loadProgress(UatSeed.longId)).deedsDone, 27);
      expect(repo.user.id, 'uat-user-finished');
    });
  });
}
