import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:acha_karo/widgets/animated_wallpaper.dart';

// The wallpaper pre-renders its blurred blobs once; it must build, animate and dispose cleanly.

void main() {
  testWidgets('builds, animates and disposes without errors', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: SizedBox(width: 360, height: 640, child: AnimatedWallpaper(gradientColors: [Color(0xFF0F2016), Color(0xFF081209)])),
    ));
    expect(find.byType(RawImage), findsNWidgets(3));
    expect(find.byType(RepaintBoundary), findsWidgets);
    await tester.pump(const Duration(seconds: 7));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    expect(tester.takeException(), isNull);
  });
}
