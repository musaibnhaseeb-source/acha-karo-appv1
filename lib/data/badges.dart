// Ported from the AUTHORITATIVE BADGE_DEFS in ACHA_KARO_FINALIZED.html (not the Next.js port,
// which was found to be missing the 'Town Voice Winner' badge — 39 instead of 40).

import '../state/app_state.dart';
import 'deed_catalog.dart';

class BadgeDef {
  final String id;
  final String name;
  final String icon;
  final String req;
  final String tier;
  final String category;
  final bool Function(AppState state) check;
  const BadgeDef({required this.id, required this.name, required this.icon, required this.req, required this.tier, required this.category, required this.check});
}

int countType(AppState s, String type) =>
    s.deedsLog.where((d) => d.type == type && d.status == 'approved').length;

int countTypes(AppState s, List<String> types) =>
    s.deedsLog.where((d) => types.contains(d.type) && d.status == 'approved').length;

bool allCategoriesTouched(AppState s) {
  final touched = s.deedsLog
      .where((d) => d.status == 'approved')
      .map((d) => deedCatalogCategoryOf(d.type))
      .toSet();
  return categoryDefs.every((c) => touched.contains(c.key));
}

// Rank comes only from AppState.myRank — real leaderboard data from the database. Rank badges
// below also check AppState.rankDataReady first, so an unloaded/empty leaderboard never counts.
int computeRank(AppState s) => s.myRank;

// Which of the badges whose check() currently passes may show: a frozen badge is never newly
// granted, but one the person already holds stays. Used by AppState._applyBadgeUpdate().
List<String> grantableBadgeIds(Iterable<String> passing, Set<String> held, Set<String> frozen) =>
    passing.where((id) => held.contains(id) || !frozen.contains(id)).toList();

// Not `const` — this list holds closures (the `check` functions), and closures can never be
// compile-time constants in Dart, no matter how simple their body is. `final` still means this
// list is created exactly once and never reassigned, which is all we actually need here.
class BadgeCategoryDef {
  final String key;
  final String name;
  final String icon;
  const BadgeCategoryDef({required this.key, required this.name, required this.icon});
}

const List<BadgeCategoryDef> badgeCategoryDefs = [
  BadgeCategoryDef(key: 'streak', name: 'Consistency & Streak', icon: '🔥'),
  BadgeCategoryDef(key: 'env', name: 'Environmental', icon: '🌍'),
  BadgeCategoryDef(key: 'animal', name: 'Animal Welfare', icon: '🐾'),
  BadgeCategoryDef(key: 'civic', name: 'Civic & Community', icon: '🏙️'),
  BadgeCategoryDef(key: 'social', name: 'Social & Human Welfare', icon: '👥'),
  BadgeCategoryDef(key: 'health', name: 'Health & Hygiene', icon: '🏥'),
  BadgeCategoryDef(key: 'special', name: 'Special Achievement', icon: '🏆'),
];

// Not `const` — this list holds closures (the `check` functions), and closures can never be
// compile-time constants in Dart, no matter how simple their body is. `final` still means this
// list is created exactly once and never reassigned, which is all we actually need here.
final List<BadgeDef> badgeDefs = [
  BadgeDef(id: 'firstStep', name: 'First Step', icon: '🌱', req: 'Do your first acha kaam', tier: 'bronze', category: 'streak', check: (s) => s.deedsLog.where((d) => d.status == 'approved').length >= 1),
  BadgeDef(id: 'streak3', name: '3-Day Streak', icon: '🔥', req: '3 consecutive days', tier: 'bronze', category: 'streak', check: (s) => s.user.streak >= 3),
  BadgeDef(id: 'streak5', name: '5-Day Streak', icon: '🔥', req: '5 consecutive days', tier: 'silver', category: 'streak', check: (s) => s.user.streak >= 5),
  BadgeDef(id: 'streak7', name: '7-Day Streak', icon: '🔥🔥', req: '7 consecutive days', tier: 'gold', category: 'streak', check: (s) => s.user.streak >= 7),
  BadgeDef(id: 'streak14', name: '14-Day Streak', icon: '⚡', req: '14 consecutive days', tier: 'platinum', category: 'streak', check: (s) => s.user.streak >= 14),
  BadgeDef(id: 'streak30', name: '30-Day Streak', icon: '🌟', req: '30 consecutive days', tier: 'rainbow', category: 'streak', check: (s) => s.user.streak >= 30),
  BadgeDef(id: 'deeds100', name: '100 Deeds', icon: '💯', req: 'Complete 100 deeds', tier: 'gold', category: 'streak', check: (s) => s.deedsLog.where((d) => d.status == 'approved').length >= 100),
  BadgeDef(id: 'litterPicker', name: 'Litter Picker', icon: '🗑️', req: '10 litter deeds', tier: 'bronze', category: 'env', check: (s) => countType(s, 'litter') >= 10),
  BadgeDef(id: 'cleanStreet', name: 'Clean Street', icon: '🧹', req: '25 litter deeds', tier: 'silver', category: 'env', check: (s) => countType(s, 'litter') >= 25),
  BadgeDef(id: 'zeroWaste', name: 'Zero Waste Hero', icon: '♻️', req: '50 litter deeds', tier: 'gold', category: 'env', check: (s) => countType(s, 'litter') >= 50),
  BadgeDef(id: 'treePlanter', name: 'Tree Planter', icon: '🌳', req: '5 saplings planted', tier: 'silver', category: 'env', check: (s) => countType(s, 'plantSapling') >= 5),
  BadgeDef(id: 'urbanGardener', name: 'Urban Gardener', icon: '🌻', req: '3 green spaces created', tier: 'gold', category: 'env', check: (s) => countType(s, 'greenSpace') >= 3),
  BadgeDef(id: 'waterGuardian', name: 'Water Guardian', icon: '💧', req: '20 plants watered', tier: 'silver', category: 'env', check: (s) => countType(s, 'water') >= 20),
  BadgeDef(id: 'friendToStrays', name: 'Friend to Strays', icon: '🐕', req: '5 strays fed', tier: 'bronze', category: 'animal', check: (s) => countType(s, 'stray') >= 5),
  BadgeDef(id: 'animalProtector', name: 'Animal Protector', icon: '🛡️', req: '3 injured animals reported', tier: 'silver', category: 'animal', check: (s) => countType(s, 'reportInjuredAnimal') >= 3),
  BadgeDef(id: 'strayHero', name: 'Stray Hero', icon: '🐾', req: '20 strays fed', tier: 'gold', category: 'animal', check: (s) => countType(s, 'stray') >= 20),
  BadgeDef(id: 'birdLover', name: 'Bird Lover', icon: '🐦', req: '10 bird feeds', tier: 'silver', category: 'animal', check: (s) => countType(s, 'feedBirds') >= 10),
  BadgeDef(id: 'fosterParent', name: 'Foster Parent', icon: '🏠', req: '2 rescue animals fostered', tier: 'gold', category: 'animal', check: (s) => countType(s, 'fosterAnimal') >= 2),
  BadgeDef(id: 'neuterChampion', name: 'Neuter Champion', icon: '🐱', req: '3 strays neutered', tier: 'platinum', category: 'animal', check: (s) => countType(s, 'neuterStray') >= 3),
  BadgeDef(id: 'civicReporter', name: 'Civic Reporter', icon: '📝', req: '5 issues reported', tier: 'bronze', category: 'civic', check: (s) => countTypes(s, ['reportStreetlight', 'reportPothole', 'reportHazard']) >= 5),
  BadgeDef(id: 'communityPainter', name: 'Community Painter', icon: '🎨', req: '3 benches painted', tier: 'silver', category: 'civic', check: (s) => countType(s, 'paintBench') >= 3),
  BadgeDef(id: 'goodNeighbor', name: 'Good Neighbor', icon: '🤝', req: '10 crossings helped', tier: 'silver', category: 'civic', check: (s) => countType(s, 'helpCrossRoad') >= 10),
  BadgeDef(id: 'schoolChampion', name: 'School Champion', icon: '🏫', req: '5 school clean-ups', tier: 'gold', category: 'civic', check: (s) => countType(s, 'cleanSchool') >= 5),
  BadgeDef(id: 'faithfulServant', name: 'Community Caretaker', icon: '🧹', req: '3 places of worship cleaned', tier: 'gold', category: 'civic', check: (s) => countType(s, 'cleanWorship') >= 3),
  BadgeDef(id: 'generousGiver', name: 'Generous Giver', icon: '🎒', req: '5 school supply donations', tier: 'bronze', category: 'social', check: (s) => countType(s, 'donateSupplies') >= 5),
  BadgeDef(id: 'mealProvider', name: 'Meal Provider', icon: '🍲', req: '10 meals shared', tier: 'silver', category: 'social', check: (s) => countType(s, 'shareMeal') >= 10),
  BadgeDef(id: 'literacyChampion', name: 'Literacy Champion', icon: '📚', req: '10 book donations', tier: 'silver', category: 'social', check: (s) => countType(s, 'donateBooks') >= 10),
  BadgeDef(id: 'bloodDonor', name: 'Blood Donor', icon: '🩸', req: '3 blood donations', tier: 'gold', category: 'social', check: (s) => countType(s, 'donateBlood') >= 3),
  BadgeDef(id: 'elderFriend', name: 'Elder Friend', icon: '👴', req: '10 elderly visits', tier: 'gold', category: 'social', check: (s) => countType(s, 'visitElderly') >= 10),
  BadgeDef(id: 'teacher', name: 'Teacher', icon: '🧑‍🏫', req: '5 skills taught', tier: 'gold', category: 'social', check: (s) => countType(s, 'teachSkill') >= 5),
  BadgeDef(id: 'firstResponder', name: 'First Responder', icon: '🩹', req: '5 first aid donations', tier: 'silver', category: 'social', check: (s) => countType(s, 'donateFirstAid') >= 5),
  BadgeDef(id: 'medicineDonor', name: 'Medicine Donor', icon: '💊', req: '5 medicine donations', tier: 'silver', category: 'health', check: (s) => countType(s, 'donateMedicines') >= 5),
  BadgeDef(id: 'healthChampion', name: 'Health Champion', icon: '🏥', req: '5 clinic clean-ups', tier: 'gold', category: 'health', check: (s) => countType(s, 'cleanClinic') >= 5),
  // townVoiceWins is never actually incremented anywhere in the original or here — stays honestly locked.
  BadgeDef(id: 'townVoiceWinner', name: 'Town Voice Winner', icon: '🎙️', req: 'Win Town Voice', tier: 'platinum', category: 'special', check: (s) => (s.townVoiceWins) >= 1),
  BadgeDef(id: 'advisor', name: 'Advisor', icon: '📣', req: 'Submit 3 feedbacks', tier: 'gold', category: 'special', check: (s) => s.feedbackLoaded ? s.feedback.length >= 3 : s.user.badges.contains('advisor')),
  BadgeDef(id: 'mentor', name: 'Mentor', icon: '🌟', req: 'Teach 10 skills', tier: 'platinum', category: 'special', check: (s) => countType(s, 'teachSkill') >= 10),
  BadgeDef(id: 'allRounder', name: 'All-Rounder', icon: '🎯', req: 'Do deeds in all 5 categories', tier: 'rainbow', category: 'special', check: (s) => allCategoriesTouched(s)),
  // Advisor (above) works the same way: feedback loads in the background after Home, so until it
  // has, a held Advisor badge is kept instead of being dropped on every cold start.
  // Rank badges only trust a rank once real leaderboard data has loaded (see
  // AppState.rankDataReady). Until then they just keep whatever the user already holds —
  // never newly granted from an empty/failed load, and never dropped for lack of data either.
  // top1 is "at least once", so it's sticky: everRankedFirst is only ever set once rankDataReady
  // (AppState._applyBadgeUpdate), and a held top1 is never dropped when rank later falls.
  // Frozen badges are filtered out in _applyBadgeUpdate, not here.
  BadgeDef(id: 'top10', name: 'Top 10', icon: '🏅', req: 'Rank in top 10', tier: 'silver', category: 'special', check: (s) => s.rankDataReady ? computeRank(s) <= 10 : s.user.badges.contains('top10')),
  BadgeDef(id: 'top3', name: 'Top 3', icon: '🥉', req: 'Rank in top 3', tier: 'gold', category: 'special', check: (s) => s.rankDataReady ? computeRank(s) <= 3 : s.user.badges.contains('top3')),
  BadgeDef(id: 'top1', name: 'Ranked First', icon: '🏆', req: 'Reach rank #1 at least once', tier: 'platinum', category: 'special', check: (s) => s.everRankedFirst || s.user.badges.contains('top1')),
];