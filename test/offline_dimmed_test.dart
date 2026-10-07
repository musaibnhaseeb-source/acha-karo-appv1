import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:acha_karo/widgets/offline_ui.dart';

// Offline "Internet chahiye" cards are greyed like the cooldown rings; online they're untouched,
// and a tap still reaches the card (which shows the needs-internet note).

void main() {
  Widget host(bool offline, VoidCallback onTap) => MaterialApp(
        home: Scaffold(
          body: OfflineDimmed(
            offline: offline,
            child: GestureDetector(key: const ValueKey('card'), onTap: onTap, child: const SizedBox(width: 200, height: 80, child: Text('Leaderboard'))),
          ),
        ),
      );

  testWidgets('online: the card is returned untouched', (tester) async {
    await tester.pumpWidget(host(false, () {}));
    expect(find.byKey(const ValueKey('offline-dimmed')), findsNothing);
    expect(find.byType(Opacity), findsNothing);
  });

  testWidgets('offline: greyed (~0.4 opacity) and taps still go through', (tester) async {
    var taps = 0;
    await tester.pumpWidget(host(true, () => taps++));
    expect(find.byKey(const ValueKey('offline-dimmed')), findsOneWidget);
    expect(tester.widget<Opacity>(find.byType(Opacity)).opacity, 0.4);
    await tester.tap(find.byKey(const ValueKey('card')));
    expect(taps, 1);
  });
}
