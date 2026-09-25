// Guddi-on-Home content — the ONE place to swap Guddi's Home lines and the daily idea cards.
//
// Starter content: Marketing's audience-cravings.md Part B (assumptions, not user data yet) with
// the Supervisor's edits applied. Replace freely once real audience answers come in; nothing
// else in the app needs to change.
//
// Copy rules: Roman Urdu first, English subtitle optional. No religious framing ("acha kaam",
// never neki/sawab). Deeds are done — "acha kaam karein", never likhein / log karein. Never a
// bare "karein" / "کریں" (double-meaning slang): always "acha kaam karein", or a different verb
// ("kijiye", "soyein"…). And never a "small" acha kaam
// (no chhota sa / small / چھوٹا) — there's only "acha kaam". Both enforced in test/deed_streak_test.dart.

class GuddiLine {
  final String roman; // primary, Roman Urdu. "{n}" is replaced with the streak count.
  final String? en; // optional English subtitle
  const GuddiLine(this.roman, [this.en]);
}

class GuddiLines {
  static const firstDeed = GuddiLine('Chaliye, apna pehla acha kaam karein! 💛', "Let's do your first acha kaam!");
  static const morning = GuddiLine('Subah bakhair! Aaj ek acha kaam karein? ☀️', 'Good morning! One acha kaam today?');
  static const day = GuddiLine('Guddi ka aaj ka idea neeche hai 💡', "Guddi's idea for today is just below.");
  static const evening = GuddiLine('Abhi bhi waqt hai, aaj ek acha kaam karein 🌙', 'Still time for one acha kaam today.');
  static const lateNight = GuddiLine('Ab aaram se soyein. Kal naya din hai 🌙', "Rest now. Tomorrow's a new day.");
  static const streakAlive = GuddiLine('Lagatar {n} din! Aaj bhi acha kaam karein? 🔥', '{n} days in a row! Keep it going today?');
  static const comeback = GuddiLine('Guddi aap ko miss kar rahi thi 💛 Aaj ek acha kaam karein?', 'Guddi missed you! One acha kaam today?');
  // Only when every deed today was rejected. Gentle on purpose — never a guilt-trip.
  static const rejectedToday = GuddiLine('Yeh wala approve nahi hua. Koi aur acha kaam karein? 💛', "That one didn't go through. Try another one?");
  static const done = GuddiLine('Wah! Aaj ka acha kaam ho gaya 🎉', "Today's acha kaam is done!");
  static const doneStreak = GuddiLine('Lagatar {n} din! Guddi proud hai 💛', '{n} days in a row! Guddi is proud of you.');
  static const doneNight = GuddiLine('Aaj ka acha kaam ho gaya. Aaram se soyein 🌙', "Today's acha kaam is done. Rest well.");
}

// Celebration captions (Guddi in the tier-up / big-milestone animations).
class GuddiCelebrationLines {
  static const strong = GuddiLine('Aap aur mazboot ho rahe hain 💪', "You're getting stronger.");
  static const topTier = GuddiLine('Guddi kuch bhi ban sakti hai. Aur aap bhi! 💪', 'Guddi can be anything. So can you!');
}

// Shown on people-facing ideas and in their submit sheet: proof photos must never show the person.
const GuddiLine kPhotoTheDeedHint = GuddiLine('Kaam ki tasveer lein, insaan ki nahi', 'Photograph the deed, not the person.');

class AchaKaamIdea {
  final String roman; // the idea, Roman Urdu
  final String en; // English subtitle
  final String deedType; // deedCatalog key — "Do it" opens this deed's normal submit sheet
  final bool involvesPerson; // shows kPhotoTheDeedHint on the card and in the submit sheet
  const AchaKaamIdea(this.roman, this.en, this.deedType, {this.involvesPerson = false});
}

// One idea per day, rotating through this list (see HomeScreen). Every entry must map to a real
// deedCatalog type so points, cooldowns and moderation all work exactly as normal.
const List<AchaKaamIdea> achaKaamIdeas = [
  AchaKaamIdea('Kisi buzurg ki madad kijiye', 'Help an elder with something', 'helpCrossRoad', involvesPerson: true),
  AchaKaamIdea('Parindon ke liye paani rakhein', 'Put out water for the birds', 'waterAnimals'),
  AchaKaamIdea('Kisi ke liye darwaza kholein ya samaan uthane mein madad kijiye', "Hold a door or help carry someone's bags", 'carryBags', involvesPerson: true),
  AchaKaamIdea('Apni gali se kachra uthayein', 'Pick up litter on your street', 'litter'),
  AchaKaamIdea('Kisi ko kuch naya sikhayein', 'Teach someone something new', 'teachSkill', involvesPerson: true),
  AchaKaamIdea('Kisi paudey ko paani dein', 'Water a plant', 'water'),
  AchaKaamIdea('Parindon ko daana dalein', 'Feed the birds', 'feedBirds'),
  AchaKaamIdea('Kisi awara janwar ko khana khilayein', 'Feed a stray animal', 'stray'),
  // Held back — no matching deed type in deedCatalog yet (would need a new type first):
  // AchaKaamIdea('Ghar walon ke liye chai banayein', 'Make chai for your family', ???),
  // AchaKaamIdea('Purane kapre donate kijiye', 'Donate old clothes', ???),
];
