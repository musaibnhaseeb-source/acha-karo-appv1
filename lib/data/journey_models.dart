import 'package:flutter/material.dart';
import 'remote_config.dart';
import 'roadmap_data.dart';

// Data shapes for the journey-map screen. Deliberately free of any Supabase import — the screen
// only ever sees these, and a JourneyRepository (real or UAT) fills them in.

// Client-side theme pack: pure data, no server columns. Defaults match today's app colours until
// the design spec lands; adapt the fields here when it does.
class JourneyTheme {
  final String id;
  final String name;
  final String title; // header title of the side screen
  final Color bgColor1;
  final Color bgColor2;
  final Color roadColor;
  final Color accentColor;
  final String stopIconLocked;
  final String stopIconReached;
  final String stopIconClaimed;
  final String accessory; // emoji for now; the design spec may swap this for an asset path
  final String? backgroundAsset;
  // Side-scroller scene pack (design: journey_side_v2). Pure client-side data; all optional.
  final Color skyTop;
  final Color skyHorizon;
  final Color glow;
  final Color skyDots;
  final String farStyle; // 'hills' | 'skyline'
  final Color farA, farB;
  final String midStyle; // 'trees' | 'lamps'
  final Color midColor;
  final Color groundRoad, groundKerb, groundDash;
  final List<String> landmarks; // landmark kind per stop index, cycled if fewer than stops
  final List<String> stopIcons; // emoji for the next stop on the strip/card, cycled
  final String? artFolder; // assets/images/journey/<artFolder>/ real scenery; null = code-drawn placeholders
  const JourneyTheme({
    required this.id,
    required this.name,
    required this.bgColor1,
    required this.bgColor2,
    required this.roadColor,
    required this.accentColor,
    this.title = 'Acha Kaam Journey',
    this.stopIconLocked = '🔒',
    this.stopIconReached = '🎁',
    this.stopIconClaimed = '✅',
    this.accessory = '🌳',
    this.backgroundAsset,
    this.skyTop = const Color(0xFF0B1710),
    this.skyHorizon = const Color(0xFF173727),
    this.glow = const Color(0x4DD9A62E),
    this.skyDots = const Color(0xFFD9A62E),
    this.farStyle = 'hills',
    this.farA = const Color(0xFF17331F),
    this.farB = const Color(0xFF1B3B25),
    this.midStyle = 'trees',
    this.midColor = const Color(0xFF1F4529),
    this.groundRoad = const Color(0xFF0B1710),
    this.groundKerb = const Color(0xFF27472F),
    this.groundDash = const Color(0x4DF6F5EC),
    this.landmarks = const ['sprout', 'tree', 'stall', 'lamp', 'flagpost', 'arch'],
    this.stopIcons = const ['🌱', '🤝', '🌳', '💛', '🏃', '🏆'],
    this.artFolder,
  });

  // Same values AppColors uses today (bg1/bg2/oliveDeep/gold), written as literals so this data
  // file does not pull in the font/theme layer.
  static const fallback = JourneyTheme(
    id: 'default',
    name: 'Default',
    bgColor1: Color(0xFF081209),
    bgColor2: Color(0xFF0F2016),
    roadColor: Color(0xFF3C4A2C),
    accentColor: Color(0xFFD9A62E),
    artFolder: 'general',
  );
}

// Optional per-stop wording (UAT sample copy for now): a one-line message for the expanded card and an
// "arrive" line shown when she reaches the stop. Real campaigns can leave this empty.
class StopCopy {
  final String message;
  final String arrive;
  const StopCopy(this.message, this.arrive);
}

class JourneyConfig {
  final Campaign campaign;
  final List<RoadmapStop> stops; // ascending by threshold
  final JourneyTheme theme;
  final Map<String, StopCopy> copy; // stopId -> wording
  const JourneyConfig({required this.campaign, required this.stops, this.theme = JourneyTheme.fallback, this.copy = const {}});
}

// roadmap_claims stores only `won` per (user, stop), so that is all a record carries.
class ClaimRecord {
  final bool won;
  const ClaimRecord({required this.won});
}

class JourneyProgress {
  final int deedsDone;
  final Map<String, ClaimRecord> claims; // stopId -> record
  final bool hallOfFameClaimed;
  const JourneyProgress({required this.deedsDone, this.claims = const {}, this.hallOfFameClaimed = false});
  Set<String> get claimedStopIds => claims.keys.toSet();
}

// What a claim returns. outcome: 'prize' | 'free_skin' | 'discount' | 'none'.
class ClaimOutcome {
  final bool won;
  final String outcome;
  final int? prizePoints;
  final int? discountPercent;
  final String? skinId;
  const ClaimOutcome({required this.won, required this.outcome, this.prizePoints, this.discountPercent, this.skinId});
}

// Carries the user-facing message (the same strings claim-roadmap-stop returns in `error`).
class JourneyException implements Exception {
  final String message;
  const JourneyException(this.message);
  @override
  String toString() => message;
}
