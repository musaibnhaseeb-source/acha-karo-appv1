// This is the actual architecture answer to "can campaigns/YouTube links be changed from the
// database instead of the code" — yes, but only because of this file existing. Every screen
// that shows editable-looking content (Town Voice's stream info, campaign banners) reads from
// a RemoteConfig object on AppState, never from a literal hardcoded string. Right now that
// object is populated with sensible defaults locally (defaultRemoteConfig() below) — once
import 'package:flutter/material.dart';
// Supabase exists, the ONLY change needed is swapping where this object comes from (a Supabase
// fetch at app startup instead of a local default), NOT rewriting any screen that displays it.
// This is the pattern to follow for anything else that should be database-editable later too.

class TownVoiceConfig {
  final String streamUrl;
  final String dayLabel;
  final String timeLabel;
  final String durationLabel;
  final bool active; // new — the real on/off switch; false shows the "launching soon" placeholder
  const TownVoiceConfig({required this.streamUrl, required this.dayLabel, required this.timeLabel, required this.durationLabel, required this.active});
}

// A campaign the team wants to run — e.g. a seasonal push, a partner promotion. "active" is the
// literal on/off switch: once this comes from Supabase, toggling a row's active column live-
// activates or deactivates a campaign with zero app update, matching exactly what was asked.
// Extended with a YouTube video, a running date range, and an optional reduced cooldown while
// the campaign is active — all still fully database-editable, none of it hardcoded.
class Campaign {
  final String id;
  final String title;
  final String description;
  final String icon;
  final String? ctaLabel;
  final String? ctaLink;
  final bool active;
  final String? youtubeVideoId;
  final DateTime? startDate;
  final DateTime? endDate;
  final int? cooldownMinutesOverride; // shortened cooldown while this campaign is active — null means "no change"
  // New — Hall of Fame content, one per campaign. Null until a real campaign has real content set.
  final String? hofBadgeName;
  final String? hofBadgeIcon;
  final String? hofStickerName;
  final String? hofStickerIcon;
  final String? hofYoutubeVideoId;
  final String defaultVehicleIcon; // new — the campaign's baseline vehicle, shown until something's equipped for it specifically
  // New — real, per-campaign roadmap colors. Null falls back to the app's current defaults —
  // nothing breaks for a campaign that hasn't set these.
  final String? roadmapBgColor1;
  final String? roadmapBgColor2;
  final String? roadmapRoadColor;
  final String? termsAndConditions; // new — real, per-campaign T&Cs, falls back to a generic placeholder if not set
  final bool teaserActive; // new — shows a non-tappable "coming soon" preview on Home, independent of active
  final String? teaserDescription;
  const Campaign({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    this.ctaLabel,
    this.ctaLink,
    required this.active,
    this.youtubeVideoId,
    this.startDate,
    this.endDate,
    this.cooldownMinutesOverride,
    this.hofBadgeName,
    this.hofBadgeIcon,
    this.hofStickerName,
    this.hofStickerIcon,
    this.hofYoutubeVideoId,
    this.defaultVehicleIcon = '🚚',
    this.roadmapBgColor1,
    this.roadmapBgColor2,
    this.roadmapRoadColor,
    this.termsAndConditions,
    this.teaserActive = false,
    this.teaserDescription,
  });

  // New — parses a real hex string ('#081209') into a Color, or returns the given fallback if
  // null/invalid. Kept on the model itself so any screen using campaign colors can call this the
  // same way, rather than duplicating hex-parsing logic in multiple places.
  static Color? _parseHex(String? hex) {
    if (hex == null || hex.isEmpty) return null;
    final cleaned = hex.replaceAll('#', '');
    final value = int.tryParse(cleaned.length == 6 ? 'FF$cleaned' : cleaned, radix: 16);
    return value == null ? null : Color(value);
  }

  Color bgColor1(Color fallback) => _parseHex(roadmapBgColor1) ?? fallback;
  Color bgColor2(Color fallback) => _parseHex(roadmapBgColor2) ?? fallback;
  Color roadColor(Color fallback) => _parseHex(roadmapRoadColor) ?? fallback;
}

class RemoteConfig {
  final TownVoiceConfig townVoice;
  final List<Campaign> campaigns;
  final bool weeklyLeaderboardActive; // new — same toggle pattern as townVoice.active
  const RemoteConfig({required this.townVoice, required this.campaigns, required this.weeklyLeaderboardActive});

  List<Campaign> get activeCampaigns => campaigns.where((c) => c.active).toList();
  // New — only shows a teaser if the campaign isn't already fully active, since the real card
  // should take over at that point, not show both at once.
  List<Campaign> get teaserCampaigns => campaigns.where((c) => c.teaserActive && !c.active).toList();

  // The shortest cooldown override among all currently-active campaigns, if any — used by
  // AppState.cooldownDuration so a running campaign actually shortens cooldowns everywhere,
  // driven entirely by the database, not a code change.
  int? get activeCooldownOverrideMinutes {
    final overrides = activeCampaigns.map((c) => c.cooldownMinutesOverride).whereType<int>().toList();
    if (overrides.isEmpty) return null;
    return overrides.reduce((a, b) => a < b ? a : b);
  }
}

// Current hardcoded values, moved here as the DEFAULT rather than deleted — same numbers as
// before, just now living in one config object instead of scattered across widget code.
// campaigns starts empty (there's no real campaign running) — this list is exactly what a
// Supabase `campaigns` table would populate later, sample row included as a demo.
RemoteConfig defaultRemoteConfig() {
  return RemoteConfig(
    weeklyLeaderboardActive: false, // matches the database default
    townVoice: const TownVoiceConfig(
      streamUrl: 'https://youtube.com/live/placeholder',
      dayLabel: 'Fri, Aug 8',
      timeLabel: '6:00 PM',
      durationLabel: '15 min',
      active: false, // matches the database default — placeholder shown until explicitly activated
    ),
    campaigns: [
      // Example only, inactive by default — this is what flipping `active: true` (a database
      // row change, not a code change) would look like once a real campaign is running.
      Campaign(
        id: 'ramadan_2026',
        title: 'Ramadan Giving Drive',
        description: 'Double points on donation deeds all month.',
        icon: '🌙',
        ctaLabel: 'Learn more',
        ctaLink: 'https://achakaro.pk/campaigns/ramadan',
        active: false,
        youtubeVideoId: 'dQw4w9WgXcQ', // placeholder — replace via the database, not this file
        startDate: DateTime(2026, 3, 1),
        endDate: DateTime(2026, 3, 30),
        cooldownMinutesOverride: 30, // half the normal 60-minute cooldown, while this runs
      ),
    ],
  );
}
