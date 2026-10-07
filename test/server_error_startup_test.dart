import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show PostgrestException;
import 'package:acha_karo/state/home_data.dart';
import 'package:acha_karo/utils/network_errors.dart';
import 'package:acha_karo/utils/startup_loader.dart';
import 'package:acha_karo/data/guddi_content.dart';
import 'package:acha_karo/widgets/guddi_loading.dart';

// v1.3.3 regression: a bare vehicle_skins(icon) embed from profiles is ambiguous (several FK
// paths), PostgREST answered HTTP 300, and the app showed "internet off" on every cold start.

void main() {
  test('profile select names the FK for the equipped-skin embed', () {
    expect(HomeData.profileColumns, contains('vehicle_skins!profiles_active_skin_id_fkey(icon)'));
    expect(HomeData.profileColumns, isNot(contains(', vehicle_skins(')));
  });

  test('no bare vehicle_skins( embed selected from profiles anywhere in lib/', () {
    final offenders = <String>[];
    for (final f in Directory('lib').listSync(recursive: true).whereType<File>().where((f) => f.path.endsWith('.dart'))) {
      final src = f.readAsStringSync();
      for (final m in RegExp(r"active_skin_id[^'\n]*vehicle_skins\(").allMatches(src)) {
        offenders.add('${f.path}: ${m.group(0)}');
      }
    }
    expect(offenders, isEmpty);
  });

  test('a server answer (PostgREST 300 / 4xx) is not a network error', () {
    expect(isNetworkError(const PostgrestException(message: 'Could not embed because more than one relationship was found', code: 'PGRST201', details: '300')), isFalse);
    expect(isNetworkError(const SocketException('Failed host lookup')), isTrue);
  });

  testWidgets('StartupLoader keeps the error, null on timeout', (tester) async {
    final outcomes = <StartupOutcome>[];
    final loader = StartupLoader(load: () => Future.error(const PostgrestException(message: 'ambiguous', code: 'PGRST201')), onOutcome: outcomes.add);
    loader.start();
    await tester.pump();
    expect(outcomes, [StartupOutcome.failed]);
    expect(loader.lastError, isA<PostgrestException>());

    final slow = StartupLoader(load: () => Future<bool>.delayed(const Duration(minutes: 1), () => true), onOutcome: outcomes.add);
    slow.start();
    await tester.pump(const Duration(seconds: 16));
    expect(slow.lastError, isNull);
    slow.dispose();
    await tester.pump(const Duration(minutes: 1));
  });

  testWidgets('server error shows the neutral line, not "internet off"', (tester) async {
    GoogleFonts.config.allowRuntimeFetching = false;
    final original = FlutterError.onError;
    FlutterError.onError = (d) {
      if (d.exceptionAsString().contains('GoogleFonts') || d.exceptionAsString().contains('google_fonts')) return;
      original?.call(d);
    };
    addTearDown(() => FlutterError.onError = original);
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: GuddiLoading(returning: true, onRetry: () {}, serverError: true))));
    expect(find.text(GuddiLoadingLines.serverError.roman), findsOneWidget);
    expect(find.text(GuddiLoadingLines.offline.roman), findsNothing);
    expect(find.byKey(const ValueKey('guddi-offline-retry')), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
}
