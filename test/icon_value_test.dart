import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:acha_karo/utils/icon_value.dart';
import 'package:acha_karo/widgets/campaign_icon.dart';

void main() {
  group('displayIcon', () {
    test('an emoji is kept as is', () {
      expect(displayIcon('🚲'), '🚲');
      expect(displayIcon(' 🎁 '), '🎁');
      expect(displayIcon('🚙'), '🚙');
      expect(displayIcon('🏷️'), '🏷️');
    });

    test('names and shortcodes map to an emoji', () {
      expect(displayIcon('directions_bike'), '🚲');
      expect(displayIcon(':bike:'), '🚲');
      expect(displayIcon('Local Shipping'), '🚚');
      expect(displayIcon('delivery-truck'), '🚚');
      expect(displayIcon('icons.emoji_events'), '🏆');
      expect(displayIcon('TROPHY'), '🏆');
    });

    test('codepoints map to an emoji', () {
      expect(displayIcon('U+1F6B2'), '🚲');
      expect(displayIcon('1f6b2'), '🚲');
      expect(displayIcon('0x1F6B2'), '🚲');
      expect(displayIcon(r'\u{1F6B2}'), '🚲');
      expect(displayIcon('&#x1F6B2;'), '🚲');
      expect(displayIcon('&#128690;'), '🚲');
      expect(displayIcon('U+1F468 U+200D U+1F4BB'), '👨‍💻');
    });

    test('an emoji with stray text around it keeps only the emoji', () {
      expect(displayIcon('🚲 bike'), '🚲');
    });

    test('unknown, empty or word-like values fall back, never raw text', () {
      expect(displayIcon('something_new'), kFallbackIcon);
      expect(displayIcon(''), kFallbackIcon);
      expect(displayIcon(null), kFallbackIcon);
      expect(displayIcon('face'), kFallbackIcon); // hex letters only, not a codepoint
      expect(displayIcon('1234'), kFallbackIcon); // not in an emoji range
      expect(displayIcon('U+0041'), kFallbackIcon);
    });
  });

  group('CampaignIcon', () {
    Future<String?> drawn(WidgetTester tester, String value) async {
      await tester.pumpWidget(MaterialApp(home: CampaignIcon(icon: value)));
      return tester.widget<Text>(find.byType(Text)).data;
    }

    testWidgets('draws the resolved emoji, not the stored text', (tester) async {
      expect(await drawn(tester, 'directions_bike'), '🚲');
      expect(await drawn(tester, 'U+1F69A'), '🚚');
      expect(await drawn(tester, 'not_an_icon'), kFallbackIcon);
      expect(await drawn(tester, '🚌'), '🚌');
    });
  });
}
