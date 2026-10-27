import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:acha_karo/journey/guddi_clips.dart';
import 'package:acha_karo/screens/journey_side_screen.dart';
import 'package:acha_karo/uat/uat_journey_repository.dart';
import 'package:acha_karo/uat/uat_rules.dart';

void main() {
  test('every clip frame in the registry exists as an asset file', () {
    // pubspec lists one folder per clip; the registry must match the files on disk
    // (checked through the filesystem since tests run from the project root)
    const set = defaultGuddiClips;
    for (final c in set.all) {
      for (var i = 0; i < c.frames; i++) {
        expect(File(set.framePath(c, i)).existsSync(), isTrue, reason: set.framePath(c, i));
      }
    }
  });

  testWidgets('side screen: loads, shows the stop card, claims a reached stop', (tester) async {
    final repo = UatJourneyRepository(rng: Random(1));
    repo.switchUser('uat-user-at-stop'); // at the stop with deeds == threshold, unclaimed
    repo.setClaimMode(UatClaimMode.forceWin);
    await tester.binding.setSurfaceSize(const Size(420, 860));
    await tester.runAsync(() async {
      await tester.pumpWidget(MaterialApp(home: Scaffold(body: JourneySideScreen(repository: repo, campaignId: 'uat-classic', clips: defaultGuddiClips, snapKey: 'a'))));
      for (var i = 0; i < 40; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 50));
        await tester.pump(const Duration(milliseconds: 50));
        if (find.byKey(const ValueKey('stop-card')).evaluate().isNotEmpty) break;
      }
    });
    expect(find.byKey(const ValueKey('stop-card')), findsOneWidget);
    expect(find.byKey(const ValueKey('claim-btn')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('claim-btn')));
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    await tester.tap(find.byKey(const ValueKey('box-0')));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('You won it — free!'), findsOneWidget);
    await tester.binding.setSurfaceSize(null);
  });
}
