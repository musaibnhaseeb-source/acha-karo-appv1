@TestOn('browser')
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:acha_karo/state/app_state.dart';
import 'package:acha_karo/utils/points_notifier.dart';
import 'package:acha_karo/utils/town_voice_reminder.dart';
import 'package:acha_karo/utils/daily_reminder.dart';
import 'package:acha_karo/widgets/avatar_picker.dart';

// PWA (web) build only — run with: flutter test --platform chrome test/web_only_test.dart
// The browser gets no offline queue / Home cache (nothing written to browser storage), no local
// notifications or their markers, and no device-only profile photo.

void main() {
  test('offline queue + Home cache are off on web', () {
    expect(AppState.offlineStorageSupported, isFalse);
  });

  test('reminders and Notify me are hidden on web', () {
    expect(DailyReminder.supported, isFalse);
    expect(TownVoiceReminder.supported, isFalse);
  });

  test('points notifications: nothing fires and no marker is stored on web', () async {
    SharedPreferences.setMockInitialValues({});
    final shown = await PointsNotifier.process('u1', [
      {'id': '1', 'type': 'taskActioned', 'title': 'Deed approved', 'body': 'Your litter submission was approved — +15 points.', 'created_at': '2026-10-07T11:00:00Z', 'read': false},
    ]);
    expect(shown, isEmpty);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getKeys().where((k) => k.startsWith('ak_notif_marker_')), isEmpty);
  });

  testWidgets('profile photo picker is just a placeholder on web (nothing to tap)', (tester) async {
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: AvatarPicker(photoFile: null, onPhotoPicked: (_) {}))));
    expect(find.text('🙂'), findsOneWidget);
    expect(find.byType(GestureDetector), findsNothing);
  });
}
