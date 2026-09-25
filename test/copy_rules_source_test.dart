import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

// Musa's standing copy rule, checked across ALL app source (not just guddi_content): never a bare
// "karein" / "کریں" — always "acha kaam karein" / "اچھا کام کریں", or a different verb
// ("kijiye", "کیجیے"). Comment lines and dev prototypes are skipped.
void main() {
  test('no bare karein / کریں anywhere in lib/', () {
    final bare = RegExp(r'(?<!acha kaam )karein|(?<!اچھا کام )کریں', caseSensitive: false);
    final hits = <String>[];
    for (final f in Directory('lib').listSync(recursive: true).whereType<File>()) {
      final path = f.path.replaceAll(r'\', '/');
      if (!path.endsWith('.dart') || path.contains('/dev_prototypes/')) continue;
      final lines = f.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        if (lines[i].trimLeft().startsWith('//')) continue;
        if (bare.hasMatch(lines[i])) hits.add('$path:${i + 1}: ${lines[i].trim()}');
      }
    }
    expect(hits, isEmpty, reason: hits.join('\n'));
  });

  // Deeds are done, not logged: the only allowed "Log …" copy is the existing "Log a good deed".
  test('no "Log …" copy in string literals except "Log a good deed"', () {
    final logCopy = RegExp(r"""['"][^'"]*\bLog (?!a good deed)[^'"]*['"]""");
    final hits = <String>[];
    for (final f in Directory('lib').listSync(recursive: true).whereType<File>()) {
      final path = f.path.replaceAll(r'\', '/');
      if (!path.endsWith('.dart') || path.contains('/dev_prototypes/')) continue;
      final lines = f.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        if (lines[i].trimLeft().startsWith('//')) continue;
        if (logCopy.hasMatch(lines[i])) hits.add('$path:${i + 1}: ${lines[i].trim()}');
      }
    }
    expect(hits, isEmpty, reason: hits.join('\n'));
  });
}
