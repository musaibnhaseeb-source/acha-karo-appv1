import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:acha_karo/uat/uat_journey_repository.dart';
import 'package:acha_karo/uat/uat_rules.dart';
import 'package:acha_karo/uat/uat_shell.dart';

void main() {
  testWidgets('UAT shell: +1 acha kaam unlocks a stop, claim works end to end', (tester) async {
    final repo = UatJourneyRepository(rng: Random(1));
    repo.switchUser('uat-user-started'); // 1 deed on every campaign
    repo.setClaimMode(UatClaimMode.forceWin);
    await tester.binding.setSurfaceSize(const Size(500, 1000));
    await tester.pumpWidget(MaterialApp(home: UatShell(repository: repo, startInSideView: false)));
    await tester.pumpAndSettle();

    expect(find.textContaining('locked'), findsWidgets);
    repo.completeAchaKaam('uat-short'); // 2 deeds -> Stop 1 reachable
    await tester.pumpAndSettle();
    expect(find.textContaining('tap to claim'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('stop-uat-short-s1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('box-0')));
    await tester.pumpAndSettle();
    expect(find.text('You won!'), findsOneWidget);
    expect(find.textContaining('+20 points'), findsOneWidget);
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(find.textContaining('claimed · won'), findsOneWidget);
    await tester.binding.setSurfaceSize(null);
  });

  testWidgets('UAT app shows the UAT banner', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: UatShell(startInSideView: false)));
    await tester.pumpAndSettle();
    expect(find.byType(Banner), findsWidgets);
    expect(find.textContaining('seeded data'), findsOneWidget);
  });
}
