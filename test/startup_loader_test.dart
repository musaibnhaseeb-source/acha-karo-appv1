import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:acha_karo/utils/startup_loader.dart';

// M1 (offline cold start hang): StartupLoader outcomes, driven by fake timers via testWidgets.

void main() {
  late List<StartupOutcome> outcomes;
  late List<Completer<bool>> loads;
  StartupLoader make() {
    outcomes = [];
    loads = [];
    return StartupLoader(
      load: () {
        final c = Completer<bool>();
        loads.add(c);
        return c.future;
      },
      onOutcome: outcomes.add,
    );
  }

  testWidgets('success reports found, once', (tester) async {
    make().start();
    loads[0].complete(true);
    await tester.pump(const Duration(seconds: 20));
    expect(outcomes, [StartupOutcome.found]);
  });

  testWidgets('no profile row reports missing', (tester) async {
    make().start();
    loads[0].complete(false);
    await tester.pump();
    expect(outcomes, [StartupOutcome.missing]);
  });

  testWidgets('an error (offline) reports failed straight away', (tester) async {
    make().start();
    loads[0].completeError(Exception('SocketException: no network'));
    await tester.pump();
    expect(outcomes, [StartupOutcome.failed]);
    await tester.pump(const Duration(seconds: 20)); // the timeout doesn't fire a second time
    expect(outcomes, [StartupOutcome.failed]);
  });

  testWidgets('a slow but successful load (14 s) never reports failed', (tester) async {
    make().start();
    await tester.pump(const Duration(seconds: 14));
    loads[0].complete(true);
    await tester.pump(const Duration(seconds: 5));
    expect(outcomes, [StartupOutcome.found]);
  });

  testWidgets('a hang reports failed at 15 s; a late success still wins', (tester) async {
    make().start();
    await tester.pump(const Duration(seconds: 15));
    expect(outcomes, [StartupOutcome.failed]);
    loads[0].complete(true);
    await tester.pump();
    expect(outcomes, [StartupOutcome.failed, StartupOutcome.found]);
  });

  testWidgets('retry: a stale failure from the old attempt is ignored', (tester) async {
    final l = make()..start();
    await tester.pump(const Duration(seconds: 15)); // attempt 1 times out
    l.start(); // user taps Retry
    loads[0].completeError(Exception('old attempt finally errors'));
    await tester.pump();
    expect(outcomes, [StartupOutcome.failed]);
    loads[1].complete(true);
    await tester.pump();
    expect(outcomes, [StartupOutcome.failed, StartupOutcome.found]);
  });

  testWidgets('after dispose (e.g. signed out) nothing is reported', (tester) async {
    final l = make()..start();
    l.dispose();
    loads[0].complete(true);
    await tester.pump(const Duration(seconds: 20));
    expect(outcomes, isEmpty);
  });

  testWidgets('a load that throws synchronously reports failed', (tester) async {
    final got = <StartupOutcome>[];
    StartupLoader(load: () => throw StateError('boom'), onOutcome: got.add).start();
    await tester.pump();
    expect(got, [StartupOutcome.failed]);
  });
}
