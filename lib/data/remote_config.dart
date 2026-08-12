// This is the actual architecture answer to "can campaigns/YouTube links be changed from the
// database instead of the code" — yes, but only because of this file existing. Every screen
// that shows editable-looking content (Town Voice's stream info, campaign banners) reads from
// a RemoteConfig object on AppState, never from a literal hardcoded string. Right now that
// object is populated with sensible defaults locally (defaultRemoteConfig() below) — once
// Supabase exists, the ONLY change needed is swapping where this object comes from (a Supabase
// fetch at app startup instead of a local default), NOT rewriting any screen that displays it.
// This is the pattern to follow for anything else that should be database-editable later too.

class TownVoiceConfig {
  final String streamUrl;
  final String dayLabel;
  final String timeLabel;
  final String durationLabel;
  const TownVoiceConfig({required this.streamUrl, required this.dayLabel, required this.timeLabel, required this.durationLabel});
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
  });
}

class RemoteConfig {
  final TownVoiceConfig townVoice;
  final List<Campaign> campaigns;
  const RemoteConfig({required this.townVoice, required this.campaigns});

  List<Campaign> get activeCampaigns => campaigns.where((c) => c.active).toList();

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
    townVoice: const TownVoiceConfig(
      streamUrl: 'https://youtube.com/live/placeholder',
      dayLabel: 'Fri, Aug 8',
      timeLabel: '6:00 PM',
      durationLabel: '15 min',
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
