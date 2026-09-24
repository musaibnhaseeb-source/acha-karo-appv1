import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:acha_karo/widgets/guddi_tour.dart';
import 'package:acha_karo/widgets/first_deed.dart';

// Widget tests for the first-deed Guddi tour — flow logic (Next/Skip/Later/CTA results), the
// returning-user 2-step variant, and no layout overflow on a small and a large phone, including
// the app's biggest text-size setting. No network, no Supabase: the tour is presentation-only.

final _deedKey = GlobalKey();
final _boardKey = GlobalKey();

List<GuddiTourStep> _fullSteps() => [
      const GuddiTourStep(image: 'assets/images/guddi/guddi_wink.png', en: "Hi! I'm Guddi. Every good deed you do matters to me.", ur: 'سلام! میں گڈی ہوں۔ آپ کا ہر اچھا کام میرے لیے اہم ہے۔'),
      GuddiTourStep(target: _deedKey, image: 'assets/images/guddi/guddi_point_phone.png', en: 'Did something kind today? Tap a circle to start.', ur: 'آج کوئی اچھا کام کریں، یہاں سے شروع کریں۔'),
      GuddiTourStep(target: _boardKey, image: 'assets/images/guddi/guddi_proud.png', en: 'Deeds earn points. Climb the leaderboard!', ur: 'ہر اچھے کام پر پوائنٹس۔ لیڈر بورڈ پر آگے بڑھیں!'),
      const GuddiTourStep(image: 'assets/images/guddi/guddi_show_phone.png', en: 'Do your first good deed now. It takes 30 seconds!', ur: 'اپنا پہلا اچھا کام ابھی کریں، صرف 30 سیکنڈ میں!'),
    ];

List<GuddiTourStep> _returningSteps() => [
      GuddiTourStep(
        target: _deedKey,
        image: 'assets/images/guddi/guddi_point_phone.png',
        leadEn: 'Welcome back! Your Guddi is still waiting for her first deed.',
        en: 'Did something kind today? Tap a circle to start.',
        ur: 'آج کوئی اچھا کام کریں، یہاں سے شروع کریں۔',
      ),
      const GuddiTourStep(image: 'assets/images/guddi/guddi_show_phone.png', en: 'Do your first good deed now. It takes 30 seconds!', ur: 'اپنا پہلا اچھا کام ابھی کریں، صرف 30 سیکنڈ میں!'),
    ];

// A stand-in Home: the deed section near the top and the leaderboard tile far enough down that
// the tour has to scroll to reach it, like the real screen.
class _FakeHome extends StatelessWidget {
  final void Function(GuddiTourResult) onResult;
  final List<GuddiTourStep> Function() steps;
  const _FakeHome({required this.onResult, required this.steps});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        child: Column(children: [
          const SizedBox(height: 120),
          Container(key: _deedKey, height: 110, color: Colors.green, child: const Text('Log a good deed')),
          const SizedBox(height: 900),
          Container(key: _boardKey, height: 80, color: Colors.amber, child: const Text('Leaderboard')),
          const SizedBox(height: 200),
          Builder(
            builder: (ctx) => TextButton(
              onPressed: () async => onResult(await showGuddiTour(ctx, steps())),
              child: const Text('start'),
            ),
          ),
        ]),
      ),
    );
  }
}

Future<void> _pumpHome(WidgetTester tester, {required Size size, double textScale = 1.0, required List<GuddiTourStep> Function() steps, required void Function(GuddiTourResult) onResult}) async {
  tester.view.physicalSize = size * 2;
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(
    builder: (context, child) => MediaQuery(data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(textScale)), child: child!),
    home: _FakeHome(onResult: onResult, steps: steps),
  ));
  // The start button sits at the bottom of the fake Home; bring it on screen and tap it.
  await tester.ensureVisible(find.text('start'));
  await tester.tap(find.text('start'));
}

Future<void> _settle(WidgetTester tester) async {
  // The bob animation loops forever, so pumpAndSettle would never settle — pump a fixed time.
  for (var i = 0; i < 20; i++) {
    await tester.pump(const Duration(milliseconds: 60));
  }
}

void main() {
  setUpAll(() {
    // No network in tests: fonts fall back to the default, which is fine for layout checks.
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  // google_fonts reports a missing-font error when runtime fetching is off; that's expected
  // here and unrelated to what's being tested, so only that specific error is ignored.
  void ignoreFontErrors() {
    final original = FlutterError.onError;
    FlutterError.onError = (details) {
      if (details.exceptionAsString().contains('GoogleFonts') || details.exceptionAsString().contains('google_fonts')) return;
      original?.call(details);
    };
    addTearDown(() => FlutterError.onError = original);
  }

  for (final size in const [Size(360, 640), Size(412, 915)]) {
    for (final scale in const [1.0, 1.15]) {
      testWidgets('full tour: 4 steps → CTA, no overflow (${size.width.toInt()}x${size.height.toInt()} @${scale}x)', (tester) async {
        ignoreFontErrors();
        GuddiTourResult? result;
        await _pumpHome(tester, size: size, textScale: scale, steps: _fullSteps, onResult: (r) => result = r);
        await _settle(tester);

        expect(find.textContaining("I'm Guddi"), findsOneWidget);
        expect(find.text('Skip'), findsOneWidget);
        for (var i = 0; i < 3; i++) {
          await tester.tap(find.text('Next'));
          await _settle(tester);
        }
        expect(find.textContaining('first good deed'), findsOneWidget);
        expect(find.text('Do my first deed'), findsOneWidget);
        expect(find.text('Later'), findsOneWidget);
        await tester.tap(find.text('Do my first deed'));
        await _settle(tester);
        expect(result, GuddiTourResult.cta);
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('Skip on step 1 returns skipped', (tester) async {
    ignoreFontErrors();
    GuddiTourResult? result;
    await _pumpHome(tester, size: const Size(360, 640), steps: _fullSteps, onResult: (r) => result = r);
    await _settle(tester);
    await tester.tap(find.text('Skip'));
    await _settle(tester);
    expect(result, GuddiTourResult.skipped);
  });

  testWidgets('returning version: 2 steps with welcome-back line → Later', (tester) async {
    ignoreFontErrors();
    GuddiTourResult? result;
    await _pumpHome(tester, size: const Size(360, 640), steps: _returningSteps, onResult: (r) => result = r);
    await _settle(tester);
    expect(find.textContaining('Welcome back!'), findsOneWidget);
    await tester.tap(find.text('Next'));
    await _settle(tester);
    await tester.tap(find.text('Later'));
    await _settle(tester);
    expect(result, GuddiTourResult.later);
    expect(tester.takeException(), isNull);
  });

  for (final flagged in const [false, true]) {
    testWidgets('first-deed celebration renders (${flagged ? 'pending' : 'approved'})', (tester) async {
      ignoreFontErrors();
      tester.view.physicalSize = const Size(360, 640) * 2;
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      var done = false;
      await tester.pumpWidget(MaterialApp(home: Scaffold(body: FirstDeedCelebration(wasFlagged: flagged, onDone: () => done = true))));
      await tester.pump(const Duration(milliseconds: 800));
      expect(find.text(flagged ? 'Your first deed is in!' : "You're on the board!"), findsOneWidget);
      await tester.pump(const Duration(seconds: 3));
      expect(done, isTrue); // auto-closes
      expect(tester.takeException(), isNull);
    });
  }
}
