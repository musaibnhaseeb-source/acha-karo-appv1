import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

// Keeps the UAT mode unable to reach the live backend or ship to users. Reads source files only.
void main() {
  final importLine = RegExp(r'''^\s*(import|export)\s+['"]([^'"]+)['"]''', multiLine: true);

  List<String> importsOf(File f) => importLine.allMatches(f.readAsStringSync()).map((m) => m.group(2)!).toList();

  Iterable<File> dartFiles(String dir) =>
      Directory(dir).listSync(recursive: true).whereType<File>().where((f) => f.path.endsWith('.dart'));

  bool inDir(File f, String dir) => f.path.replaceAll('\\', '/').contains('/$dir/');

  test('lib/uat imports nothing that can reach the live backend', () {
    for (final f in dartFiles('lib/uat')) {
      for (final i in importsOf(f)) {
        expect(i.contains('supabase'), isFalse, reason: '${f.path} imports $i');
        expect(i.endsWith('main.dart') && !i.endsWith('uat_main.dart'), isFalse, reason: '${f.path} imports $i');
        // Only the data/UI the screen itself uses is allowed; no AppState, no remote config reads.
        expect(i.contains('state/app_state'), isFalse, reason: '${f.path} imports $i');
      }
      expect(f.readAsStringSync().contains('Supabase.'), isFalse, reason: '${f.path} references Supabase');
    }
  });

  test('nothing outside lib/uat and lib/dev_prototypes imports lib/uat', () {
    for (final f in dartFiles('lib')) {
      if (inDir(f, 'uat') || inDir(f, 'dev_prototypes')) continue;
      for (final i in importsOf(f)) {
        expect(RegExp(r'(^|/)uat/').hasMatch(i), isFalse, reason: '${f.path} imports $i');
      }
    }
  });

  test('the journey screen and its data interface stay free of Supabase', () {
    const files = [
      'lib/screens/journey_screen.dart',
      'lib/data/journey_models.dart',
      'lib/data/journey_repository.dart',
    ];
    for (final p in files) {
      for (final i in importsOf(File(p))) {
        expect(i.contains('supabase'), isFalse, reason: '$p imports $i');
      }
    }
  });

  test('only the Supabase repository file imports the live backend among the journey files', () {
    final live = importsOf(File('lib/data/supabase_journey_repository.dart'));
    expect(live.any((i) => i.contains('supabase_flutter')), isTrue);
    expect(File('lib/uat/uat_main.dart').readAsStringSync(), contains('kReleaseMode'));
  });

  test('the live roadmap screen was not edited to depend on the journey layer', () {
    expect(File('lib/screens/roadmap_screen.dart').readAsStringSync().contains('journey_'), isFalse);
  });
}
