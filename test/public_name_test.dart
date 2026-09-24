import 'package:flutter_test/flutter_test.dart';
import 'package:acha_karo/utils/public_name.dart';

// Other users' names are shown as first name + last initial.

void main() {
  test('first name + last initial', () {
    expect(publicDisplayName('Ayesha Khan'), 'Ayesha K.');
    expect(publicDisplayName('Muhammad Ali Raza'), 'Muhammad R.'); // middle names dropped
    expect(publicDisplayName('ayesha khan'), 'ayesha K.'); // first name kept as typed
  });

  test('extra and odd whitespace', () {
    expect(publicDisplayName('   Ayesha    Khan  '), 'Ayesha K.');
    expect(publicDisplayName('Ayesha\tKhan\n'), 'Ayesha K.');
  });

  test('single word is shown as is', () {
    expect(publicDisplayName('Ayesha'), 'Ayesha');
    expect(publicDisplayName('  Ayesha  '), 'Ayesha');
  });

  test('Urdu script', () {
    expect(publicDisplayName('عائشہ خان'), 'عائشہ خ.');
    expect(publicDisplayName('عائشہ'), 'عائشہ');
  });

  test('empty / null falls back', () {
    expect(publicDisplayName(null), 'User');
    expect(publicDisplayName(''), 'User');
    expect(publicDisplayName('   '), 'User');
    expect(publicDisplayName(null, fallback: 'Friend'), 'Friend');
  });

  test('already-shortened server value is left alone', () {
    expect(publicDisplayName('Ayesha K.'), 'Ayesha K.');
  });
}
