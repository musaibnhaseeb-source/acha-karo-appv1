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

// Cold-start loading screen (widgets/guddi_loading.dart), shown while the app loads the session
// and profile.
// Approved copy (Musa, 2026-09-30). No trailing "..." or full stop: the widget adds the
// animated dots itself. Each line mixes Roman Urdu and English, so there's no separate subtitle.
class GuddiLoadingLines {
  // Signed in (a saved session exists).
  static const returning = GuddiLine('Welcome back! Guddi aa rahi hai');
  // No saved session (first open, or signed out).
  static const firstOpen = GuddiLine('Hi! Main Guddi, sab ready kar rahi hoon');
  // Swapped in if loading takes longer than about 5 seconds.
  static const slow = GuddiLine('Thora aur wait, Guddi bas aa hi rahi hai');

  // Offline state (load failed or timed out) and its button. Approved copy (Musa, 2026-09-30).
  // One line, no English subtitle and no dots, matching the other loading states.
  static const offline = GuddiLine('Lagta hai internet off hai');
  static const retry = 'Dobara try karo';
  // The server answered with an error (not a connection problem): never shown as "internet off".
  static const serverError = GuddiLine('Kuch masla ho gaya. Dobara try karo.', 'Something went wrong. Try again.');
}

// Offline mode (layer 2). `saved` is Musa's wording (2026-10-07); the rest are proposals for review.
class OfflineLines {
  // Right after a deed is saved on the phone instead of sent.
  static const saved = GuddiLine(
    'Yeh acha kaam phone mein save ho gaya hai. Internet on karke app kholo, tabhi yeh register hoga.',
    "Saved on your phone. It only counts once you're online with the app open.",
  );
  static const savedOk = 'Theek hai';
  static const pill = 'Offline';
  // Screens that need the server (leaderboard, Town Voice, limited edition, skins, invites, edit profile).
  static const needsInternet = GuddiLine('Iske liye internet chahiye', 'This needs internet.');
  static const needsInternetShort = 'Internet chahiye';
  // Home, while deeds are waiting. {n} = how many.
  static const waiting = GuddiLine('{n} acha kaam phone mein save hain', "They count once you're online with the app open.");
  static const waitingOne = GuddiLine('1 acha kaam phone mein save hai', "It counts once you're online with the app open.");
  static const waitingPoints = '+{x} waiting';
  static const waitingBadge = 'WAITING';
  static const queueFull = GuddiLine(
    'Phone mein pehle se 20 acha kaam save hain. Internet on karke app kholo taake yeh register ho jayein, phir naye save ho sakte hain.',
    '20 deeds are already saved on your phone. Go online with the app open to send them, then you can save more.',
  );
  static const saveFailed = GuddiLine('Phone mein save nahi ho saka. Dobara try karo.', "Couldn't save it on your phone. Please try again.");
  // A waiting deed the server refused when it was sent (its photo was already used on a deed).
  static const rejectedOnSend = GuddiLine(
    'Ek save kiya hua acha kaam register nahi ho saka: yeh photo pehle bhi use ho chuki thi.',
    "One saved deed couldn't be sent: that photo was already used.",
  );
  // Settings > Sign out, while deeds are still waiting. {n} = how many.
  static const signOutWarning = "{n} saved acha kaam haven't been sent yet. Signing out deletes them from this phone.";
}

// Duplicate photo (v1.3.2, submit form): the photo was already used on one of this user's deeds.
// Approved copy (Musa, 2026-09-30).
class GuddiDuplicatePhotoLines {
  static const rejected = GuddiLine('Oho! Yeh photo pehle bhi upload ho chuki hai. Koi baat nahi, nayi photo lo.');
  static const newPhotoButton = 'New photo';
  // Shown before resubmitting with a new photo: it will go to a moderator.
  static const willBeReviewed = GuddiLine('Yeh acha kaam ab hamari team check karegi');
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
