// Ported from TIER_DEFS in the original. Badge-count thresholds for the tier system, with the
// Urdu names rendered via Noto Nastaliq Urdu (see AppFonts.nastaliq in theme/app_theme.dart).

class TierDef {
  final String key;
  final String name; // Urdu
  final String icon;
  final int min;
  const TierDef({required this.key, required this.name, required this.icon, required this.min});
}

const List<TierDef> tierDefs = [
  TierDef(key: 'chick', name: 'چوزہ', icon: '🐣', min: 0),
  TierDef(key: 'cat', name: 'بلو', icon: '🐱', min: 3),
  TierDef(key: 'parrot', name: 'طوطو', icon: '🦜', min: 8),
  TierDef(key: 'bear', name: 'بھالو', icon: '🐻', min: 14),
  TierDef(key: 'cheetah', name: 'چیتا', icon: '🐆', min: 21),
  TierDef(key: 'lion', name: 'ببر شیر', icon: '🦁', min: 29),
  TierDef(key: 'eagle', name: 'شاہین', icon: '🦅', min: 36),
];

TierDef getUserTier(int badgeCount) {
  var tier = tierDefs[0];
  for (final t in tierDefs) {
    if (badgeCount >= t.min) tier = t;
  }
  return tier;
}
