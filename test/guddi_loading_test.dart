import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:acha_karo/data/guddi_content.dart';
import 'package:acha_karo/widgets/guddi_loading.dart';

// Cold-start Guddi loader: right line per variant, the "slow" line after 5 s, dots animate, and
// they stay static with reduced motion. Presentation only, no network or Supabase.

Widget _host(Widget child, {bool reduceMotion = false, Size size = const Size(360, 640), double scale = 1.0}) => MediaQuery(
      data: MediaQueryData(size: size, disableAnimations: reduceMotion, textScaler: TextScaler.linear(scale)),
      child: MaterialApp(home: Scaffold(body: child)),
    );

String _lineText(WidgetTester tester) => tester.widget<Text>(find.byKey(const ValueKey('guddi-loading-line'))).textSpan!.toPlainText();

// Dots that are actually visible (hidden ones are drawn transparent to keep the layout still).
int _visibleDots(WidgetTester tester) {
  final spans = (tester.widget<Text>(find.byKey(const ValueKey('guddi-loading-line'))).textSpan! as TextSpan).children!.skip(1);
  return spans.where((s) => (s as TextSpan).style?.color != Colors.transparent).length;
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  void ignoreFontErrors() {
    final original = FlutterError.onError;
    FlutterError.onError = (details) {
      if (details.exceptionAsString().contains('GoogleFonts') || details.exceptionAsString().contains('google_fonts')) return;
      original?.call(details);
    };
    addTearDown(() => FlutterError.onError = original);
  }

  testWidgets('returning: welcome-back line, then the slow line after 5 s', (tester) async {
    ignoreFontErrors();
    await tester.pumpWidget(_host(const GuddiLoading(returning: true)));
    expect(_lineText(tester), '${GuddiLoadingLines.returning.roman}...');
    expect(find.byType(CircularProgressIndicator), findsNothing);
    await tester.pump(const Duration(seconds: 5));
    expect(_lineText(tester), '${GuddiLoadingLines.slow.roman}...');
    await tester.pumpWidget(const SizedBox()); // dispose, cancelling timers
  });

  testWidgets('first open / signed out: getting-ready line', (tester) async {
    ignoreFontErrors();
    await tester.pumpWidget(_host(const GuddiLoading(returning: false)));
    expect(_lineText(tester), '${GuddiLoadingLines.firstOpen.roman}...');
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('dots animate', (tester) async {
    ignoreFontErrors();
    await tester.pumpWidget(_host(const GuddiLoading(returning: true)));
    final seen = <int>{};
    for (var i = 0; i < 4; i++) {
      seen.add(_visibleDots(tester));
      await tester.pump(const Duration(milliseconds: 450));
    }
    expect(seen, {1, 2, 3});
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('reduced motion: dots stay static', (tester) async {
    ignoreFontErrors();
    await tester.pumpWidget(_host(const GuddiLoading(returning: true), reduceMotion: true));
    for (var i = 0; i < 4; i++) {
      expect(_visibleDots(tester), 3);
      await tester.pump(const Duration(milliseconds: 450));
    }
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('offline state: offline line, no dots, Retry calls back', (tester) async {
    ignoreFontErrors();
    var retries = 0;
    await tester.pumpWidget(_host(GuddiLoading(returning: true, onRetry: () => retries++)));
    expect(find.byKey(const ValueKey('guddi-loading-line')), findsNothing);
    expect(find.text(GuddiLoadingLines.offline.roman), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('guddi-offline-retry')));
    expect(retries, 1);
    await tester.pump(const Duration(seconds: 5)); // no "slow" swap in the offline state
    expect(find.text(GuddiLoadingLines.offline.roman), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  for (final size in const [Size(320, 568), Size(412, 915)]) {
    testWidgets('no overflow at ${size.width.toInt()}x${size.height.toInt()} @1.15x', (tester) async {
      ignoreFontErrors();
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(_host(const GuddiLoading(returning: true), size: size, scale: 1.15));
      await tester.pump(const Duration(seconds: 5)); // longest line variant
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }
}
