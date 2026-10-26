import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'uat_shell.dart';

// UAT entry point for the journey-map screen. Run with:
//   flutter run -t lib/uat/uat_main.dart
// Seeded in-memory data only. This file never imports main.dart or supabase_config.dart and never
// initialises Supabase, so no live key or database is reachable from here; test/uat_isolation_test
// enforces that. It also refuses to start in a release build.
void main() {
  if (kReleaseMode) {
    throw StateError('UAT entry point must never run in a release build.');
  }
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const UatApp());
}
