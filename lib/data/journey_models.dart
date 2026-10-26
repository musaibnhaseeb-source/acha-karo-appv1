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
  final Color bgColor1;
  final Color bgColor2;
  final Color roadColor;
  final Color accentColor;
  final String stopIconLocked;
  final String stopIconReached;
  final String stopIconClaimed;
  final String accessory; // emoji for now; the design spec may swap this for an asset path
  final String? backgroundAsset;
  const JourneyTheme({
    required this.id,
    required this.name,
    required this.bgColor1,
    required this.bgColor2,
    required this.roadColor,
    required this.accentColor,
    this.stopIconLocked = '🔒',
    this.stopIconReached = '🎁',
    this.stopIconClaimed = '✅',
    this.accessory = '🌳',
    this.backgroundAsset,
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
  );
}

class JourneyConfig {
  final Campaign campaign;
  final List<RoadmapStop> stops; // ascending by threshold
  final JourneyTheme theme;
  const JourneyConfig({required this.campaign, required this.stops, this.theme = JourneyTheme.fallback});
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
