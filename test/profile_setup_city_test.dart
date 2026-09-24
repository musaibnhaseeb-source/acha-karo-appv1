import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:acha_karo/screens/profile_setup_screen.dart';

// Profile Setup must never submit without a real city: no pre-selected default, an inline
// message when Continue is tapped without one, and onComplete only fires once a city is picked.

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  testWidgets('city is required: blocked with inline message, then submits the picked city', (tester) async {
    final original = FlutterError.onError;
    FlutterError.onError = (d) {
      if (d.exceptionAsString().toLowerCase().contains('google')) return; // no font downloads in tests
      original?.call(d);
    };
    addTearDown(() => FlutterError.onError = original);
    // Wide surface: the test font draws every glyph as a full square (much wider than the app's
    // real Inter), which would overflow the side-by-side Gender/DOB labels — a test-font artifact,
    // not what this test is about.
    tester.view.physicalSize = const Size(700, 1400) * 2;
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);

    String? submittedCity;
    var submitCount = 0;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ProfileSetupScreen(
          onComplete: ({required name, required gender, required dob, required city, phone, avatarFile}) {
            submitCount++;
            submittedCity = city;
          },
        ),
      ),
    ));
    await tester.pumpAndSettle();

    // No city pre-selected.
    expect(find.text('Select your city'), findsOneWidget);

    // Fill everything except the city.
    await tester.enterText(find.byType(TextField).first, 'Test Person');
    await tester.tap(find.text('Select').first); // gender dropdown
    await tester.pumpAndSettle();
    await tester.tap(find.text('Female').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Select date'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK')); // initial date is already a valid 14+ date
    await tester.pumpAndSettle();

    // Continue without a city: blocked, message shown.
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(submitCount, 0);
    expect(find.text('Please pick your city to continue.'), findsOneWidget);

    // Pick a city: message clears, Continue submits that exact city.
    await tester.tap(find.text('Select your city'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Lahore').last);
    await tester.pumpAndSettle();
    expect(find.text('Please pick your city to continue.'), findsNothing);
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(submitCount, 1);
    expect(submittedCity, 'Lahore');
  });
}
