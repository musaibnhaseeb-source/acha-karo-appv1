// Ported from lib/data.js (Next.js port) / DEED_CATALOG + CATEGORY_DEFS in the original
// ACHA_KARO_FINALIZED.html. Same keys, same values — only the container syntax changed
// (JS object literals -> Dart classes) since Dart doesn't have untyped object literals the
// same way.

class CategoryDef {
  final String key;
  final String name;
  final String short;
  final String icon;
  const CategoryDef({required this.key, required this.name, required this.short, required this.icon});
}

const List<CategoryDef> categoryDefs = [
  CategoryDef(key: 'env', name: 'Environmental Action', short: 'Enviro', icon: '🌍'),
  CategoryDef(key: 'animal', name: 'Animal Welfare', short: 'Animal', icon: '🐾'),
  CategoryDef(key: 'civic', name: 'Civic & Community', short: 'Civic', icon: '🏙️'),
  CategoryDef(key: 'social', name: 'Social & Human Welfare', short: 'Social', icon: '👥'),
  CategoryDef(key: 'health', name: 'Health & Hygiene', short: 'Health', icon: '🏥'),
];

class DeedMeta {
  final String name;
  final String icon;
  final int points;
  final String category;
  const DeedMeta({required this.name, required this.icon, required this.points, required this.category});
}

const Map<String, DeedMeta> deedCatalog = {
  // Environmental Action
  'litter': DeedMeta(name: 'Clear litter', icon: '🗑️', points: 15, category: 'env'),
  'sweep': DeedMeta(name: 'Sweep a walkway', icon: '🧹', points: 12, category: 'env'),
  'water': DeedMeta(name: 'Water a plant', icon: '💧', points: 10, category: 'env'),
  'plantSapling': DeedMeta(name: 'Plant a sapling', icon: '🌱', points: 25, category: 'env'),
  'cleanDrain': DeedMeta(name: 'Clean a drain', icon: '🪣', points: 18, category: 'env'),
  'recycle': DeedMeta(name: 'Recycle waste responsibly', icon: '♻️', points: 8, category: 'env'),
  'greenSpace': DeedMeta(name: 'Create a green space', icon: '🌻', points: 30, category: 'env'),
  'waterCooler': DeedMeta(name: 'Install a water cooler', icon: '🚰', points: 30, category: 'env'),
  // Animal Welfare
  'stray': DeedMeta(name: 'Feed a stray', icon: '🐕', points: 20, category: 'animal'),
  'reportInjuredAnimal': DeedMeta(name: 'Report injured animal', icon: '🩺', points: 15, category: 'animal'),
  'waterAnimals': DeedMeta(name: 'Provide water for animals', icon: '💧', points: 10, category: 'animal'),
  'buildShelter': DeedMeta(name: 'Build a shelter', icon: '🏠', points: 30, category: 'animal'),
  'feedBirds': DeedMeta(name: 'Feed birds', icon: '🐦', points: 10, category: 'animal'),
  'neuterStray': DeedMeta(name: 'Get a stray neutered', icon: '🐱', points: 40, category: 'animal'),
  'fosterAnimal': DeedMeta(name: 'Foster a rescue animal', icon: '🐾', points: 35, category: 'animal'),
  // Civic & Community
  'reportStreetlight': DeedMeta(name: 'Report broken streetlight', icon: '💡', points: 8, category: 'civic'),
  'reportPothole': DeedMeta(name: 'Report pothole', icon: '🕳️', points: 8, category: 'civic'),
  'paintBench': DeedMeta(name: 'Paint a public bench', icon: '🪑', points: 20, category: 'civic'),
  'helpCrossRoad': DeedMeta(name: 'Help someone cross the road', icon: '🚶', points: 12, category: 'civic'),
  'cleanSchool': DeedMeta(name: 'Clean a school area', icon: '🏫', points: 18, category: 'civic'),
  'cleanWorship': DeedMeta(name: 'Clean a mosque/church/temple', icon: '🕌', points: 20, category: 'civic'),
  'reportHazard': DeedMeta(name: 'Report a safety hazard', icon: '⚠️', points: 10, category: 'civic'),
  // Social & Human Welfare
  'donateSupplies': DeedMeta(name: 'Donate school supplies', icon: '🎒', points: 15, category: 'social'),
  'shareMeal': DeedMeta(name: 'Share a meal', icon: '🍲', points: 20, category: 'social'),
  'donateBooks': DeedMeta(name: 'Donate books', icon: '📚', points: 10, category: 'social'),
  'donateBlood': DeedMeta(name: 'Donate blood', icon: '🩸', points: 30, category: 'social'),
  'visitElderly': DeedMeta(name: 'Visit the elderly', icon: '👴', points: 15, category: 'social'),
  'teachSkill': DeedMeta(name: 'Teach a skill', icon: '🧑‍🏫', points: 15, category: 'social'),
  'carryBags': DeedMeta(name: 'Help carry heavy bags', icon: '🛒', points: 10, category: 'social'),
  'donateFirstAid': DeedMeta(name: 'Donate first aid supplies', icon: '🩹', points: 18, category: 'social'),
  // Health & Hygiene
  'donateMedicines': DeedMeta(name: 'Donate medicines', icon: '💊', points: 30, category: 'health'),
  'cleanClinic': DeedMeta(name: 'Clean a clinic/hospital area', icon: '🧹', points: 18, category: 'health'),
};

// Small helper used by allCategoriesTouched() in badges.dart — kept here rather than in badges.dart
// since it's really a DEED_CATALOG lookup, not badge logic.
String? deedCatalogCategoryOf(String deedType) => deedCatalog[deedType]?.category;

// New — powers the campaign quick-action CTA: the single lowest-point (easiest, fastest) deed
// type within each category, one per category. Computed from the catalog itself rather than
// hardcoded, so it always reflects real point values even if those change later. Where two deed
// types tie on points within a category, whichever appears first in the catalog above wins —
// deterministic, not arbitrary, since Dart's Map preserves insertion order.
Map<String, String> lowestPointDeedPerCategory() {
  final result = <String, String>{};
  final lowestPoints = <String, int>{};
  deedCatalog.forEach((type, meta) {
    final current = lowestPoints[meta.category];
    if (current == null || meta.points < current) {
      lowestPoints[meta.category] = meta.points;
      result[meta.category] = type;
    }
  });
  return result;
}

// Donation-category deeds always go to moderation, regardless of GPS/repeat status — a photo of
// food or a receipt needs a human to actually confirm, unlike e.g. litter clean-up where the
// photo is usually self-evident. Moved here from app_state.dart specifically so
// easiestDeedsPerCategory() below can reference it without creating a circular import
// (app_state.dart already imports FROM this file).
const Set<String> donationDeedTypes = {
  'donateSupplies', 'shareMeal', 'donateBooks', 'donateBlood', 'donateFirstAid', 'donateMedicines',
};

// New — 3 easiest (lowest-point) deed types per category, excluding donation types entirely.
// Powers the roadmap's task-selection sheet, which relocated from the campaign CTA's earlier
// single-lowest-per-category version (lowestPointDeedPerCategory above, kept as-is since nothing
// else was asked to change there) — same idea, expanded to give real choice within each
// category. Donation types excluded since they always require moderation review, at odds with
// "quick, easy roadmap progress."
Map<String, List<String>> easiestDeedsPerCategory({int perCategory = 3}) {
  final result = <String, List<String>>{};
  for (final cat in categoryDefs) {
    final types = deedCatalog.entries.where((e) => e.value.category == cat.key && !donationDeedTypes.contains(e.key)).toList()
      ..sort((a, b) => a.value.points.compareTo(b.value.points));
    result[cat.key] = types.take(perCategory).map((e) => e.key).toList();
  }
  return result;
}

