// Turns whatever is stored in an icon column (campaigns.icon, prize_icon, hof_*_icon, skin icons)
// into something safe to draw. The columns are meant to hold an emoji or an image URL, but they are
// free text: an admin can type an icon name ("directions_bike"), a shortcode (":bike:") or a
// codepoint ("U+1F6B2"). Drawn as-is those show up as raw text, so they are mapped to an emoji here,
// and anything that can't be resolved becomes [kFallbackIcon] instead of text.
const String kFallbackIcon = '🎉';

bool isIconUrl(String v) => v.startsWith('http://') || v.startsWith('https://');

// The emoji to draw for a stored (non-URL) icon value; never raw text.
String displayIcon(String? raw) => emojiForIconValue(raw) ?? kFallbackIcon;

// null when the value is empty, or a name/code that isn't known.
String? emojiForIconValue(String? raw) {
  final t = (raw ?? '').trim();
  if (t.isEmpty) return null;

  // Already an emoji (possibly with stray ASCII around it): keep the emoji part only.
  if (t.runes.any(_isEmojiRune)) {
    final kept = String.fromCharCodes(t.runes.where((r) => r > 0x7F || r == 0xA9 || r == 0xAE).toList()).trim();
    return kept.runes.any(_isEmojiRune) ? kept : null;
  }

  final fromCode = _fromCodepoints(t);
  if (fromCode != null) return fromCode;

  final key = t.toLowerCase().replaceAll(':', '').replaceAll(RegExp(r'^(icons\.|material[-_ ])'), '').replaceAll(RegExp(r'[\s\-]+'), '_').replaceAll(RegExp(r'_+'), '_').trim();
  return _byName[key];
}

bool _isEmojiRune(int r) =>
    (r >= 0x1F000 && r <= 0x1FAFF) ||
    (r >= 0x2190 && r <= 0x21FF) ||
    (r >= 0x2300 && r <= 0x23FF) ||
    (r >= 0x2600 && r <= 0x27BF) ||
    (r >= 0x2B00 && r <= 0x2BFF) ||
    r == 0x2122 || r == 0x2139 || r == 0x3030 || r == 0x303D || r == 0x3297 || r == 0x3299;

// "U+1F6B2", "1f6b2", "0x1F6B2", "\u{1F6B2}", "&#x1F6B2;", "&#128690;", and space/dash separated sequences
// of those ("U+1F468 U+200D U+1F4BB"). Only emoji ranges are accepted so ordinary words and numbers are not turned into symbols.
String? _fromCodepoints(String t) {
  final dec = RegExp(r'^&#(\d{4,7});$').firstMatch(t);
  if (dec != null) return _emojiOf([int.parse(dec.group(1)!)]);
  final points = <int>[];
  for (final tok in t.split(RegExp(r'[\s,\-]+'))) {
    final m = RegExp(r'^(U\+|u\+|\\u\{|\\u|0x|&#x|#x)?([0-9A-Fa-f]{2,6})[};]?$').firstMatch(tok);
    if (m == null) return null;
    // a bare hex run without a digit is a word ("face", "cafe"), not a codepoint
    if (m.group(1) == null && !RegExp(r'\d').hasMatch(m.group(2)!)) return null;
    points.add(int.parse(m.group(2)!, radix: 16));
  }
  return _emojiOf(points);
}

String? _emojiOf(List<int> points) {
  if (points.isEmpty) return null;
  for (final p in points) {
    if (p > 0x10FFFF) return null;
    if (!(_isEmojiRune(p) || p == 0x200D || p == 0xFE0F || p == 0x20E3)) return null;
  }
  return points.any(_isEmojiRune) ? String.fromCharCodes(points) : null;
}

// Material icon names and common shortcodes an admin might type, mapped to the emoji the app draws.
const Map<String, String> _byName = {
  'bike': '🚲', 'bicycle': '🚲', 'cycle': '🚲', 'cycling': '🚲', 'directions_bike': '🚲', 'pedal_bike': '🚲', 'two_wheeler': '🛵', 'motorcycle': '🏍️', 'scooter': '🛵',
  'truck': '🚚', 'delivery_truck': '🚚', 'local_shipping': '🚚', 'lorry': '🚚',
  'bus': '🚌', 'directions_bus': '🚌',
  'car': '🚗', 'directions_car': '🚗', 'taxi': '🚕', 'local_taxi': '🚕', 'rickshaw': '🛺', 'auto_rickshaw': '🛺', 'tuk_tuk': '🛺',
  'train': '🚆', 'subway': '🚇', 'plane': '✈️', 'flight': '✈️', 'airplane': '✈️', 'boat': '⛵', 'sailing': '⛵', 'rocket': '🚀',
  'walk': '🚶', 'walking': '🚶', 'directions_walk': '🚶', 'run': '🏃', 'running': '🏃', 'directions_run': '🏃',
  'tree': '🌳', 'park': '🌳', 'forest': '🌲', 'nature': '🌿', 'eco': '🌱', 'seedling': '🌱', 'sprout': '🌱', 'plant': '🌱', 'leaf': '🍃', 'flower': '🌸', 'local_florist': '🌸',
  'recycle': '♻️', 'recycling': '♻️', 'delete_sweep': '🧹', 'cleaning': '🧹', 'broom': '🧹',
  'water': '💧', 'water_drop': '💧', 'droplet': '💧', 'sun': '☀️', 'wb_sunny': '☀️', 'moon': '🌙', 'star': '⭐', 'stars': '🌟', 'sparkles': '✨', 'auto_awesome': '✨',
  'heart': '❤️', 'favorite': '❤️', 'love': '❤️', 'handshake': '🤝', 'volunteer_activism': '🤲', 'helping_hands': '🤲', 'hands': '🤲', 'people': '👥', 'group': '👥', 'groups': '👥',
  'trophy': '🏆', 'emoji_events': '🏆', 'award': '🏆', 'medal': '🏅', 'military_tech': '🎖️', 'badge': '🏅', 'crown': '👑', 'sticker': '🏷️', 'tag': '🏷️', 'sell': '🏷️', 'label': '🏷️',
  'gift': '🎁', 'present': '🎁', 'card_giftcard': '🎁', 'party': '🎉', 'celebration': '🎉', 'confetti': '🎉', 'party_popper': '🎉', 'tada': '🎉',
  'flag': '🚩', 'outlined_flag': '🚩', 'fire': '🔥', 'local_fire_department': '🔥', 'flame': '🔥',
  'home': '🏠', 'house': '🏠', 'school': '🏫', 'hospital': '🏥', 'local_hospital': '🏥', 'health': '🏥', 'mosque': '🕌', 'ramadan': '🌙',
  'paw': '🐾', 'pets': '🐾', 'animal': '🐾', 'dog': '🐕', 'cat': '🐈', 'bird': '🐦',
  'earth': '🌍', 'globe': '🌍', 'world': '🌍', 'public': '🌍', 'map': '🗺️', 'road': '🛣️', 'route': '🛣️', 'pin': '📍', 'location_on': '📍',
  'money': '💰', 'payments': '💰', 'coin': '🪙', 'discount': '🏷️',
  'video': '▶️', 'play': '▶️', 'play_arrow': '▶️', 'youtube': '▶️', 'camera': '📷', 'photo_camera': '📷',
  'shield': '🛡️', 'security': '🛡️', 'check': '✅', 'check_circle': '✅', 'done': '✅', 'bolt': '⚡', 'flash': '⚡', 'lightning': '⚡',
  'book': '📖', 'menu_book': '📖', 'food': '🍲', 'restaurant': '🍽️', 'meal': '🍲', 'bread': '🍞',
};
