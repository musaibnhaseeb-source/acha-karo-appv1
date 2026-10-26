import 'package:flutter/material.dart';
import '../data/journey_models.dart';
import '../data/remote_config.dart';
import '../data/roadmap_data.dart';

// Seeded UAT data: three sample campaigns and five fake users. No real names, numbers or ids.

class UatCampaignSeed {
  final Campaign campaign;
  final List<RoadmapStop> stops;
  final JourneyTheme theme;
  final Map<String, int> prizePoints; // stopId -> points (roadmap_stops.prize_points stand-in)
  const UatCampaignSeed({required this.campaign, required this.stops, required this.theme, this.prizePoints = const {}});

  JourneyConfig toConfig() => JourneyConfig(campaign: campaign, stops: stops, theme: theme);
}

class UatUserState {
  final String id;
  final String label;
  final Map<String, int> deeds = {}; // campaignId -> approved deeds
  final Map<String, Map<String, ClaimRecord>> claims = {}; // campaignId -> stopId -> record
  final Set<String> hallOfFame = {}; // campaignIds
  int points = 0;
  final Set<String> skins = {};
  final Map<String, int> discounts = {}; // skinId -> percent
  UatUserState(this.id, this.label);
}

class UatSeed {
  static const _prize = RoadmapPrize(name: 'Sample prize', icon: '🎁');
  static const _skinPrize = RoadmapPrize(name: 'Sample vehicle skin', icon: '🚙');

  static const shortId = 'uat-short';
  static const classicId = 'uat-classic';
  static const longId = 'uat-long';

  static List<UatCampaignSeed> campaigns() => const [
        UatCampaignSeed(
          campaign: Campaign(id: shortId, title: 'UAT Short Road', description: 'Three quick stops.', icon: '🚲', active: true, defaultVehicleIcon: '🚲'),
          theme: JourneyTheme(
            id: 'uat-meadow', name: 'Meadow',
            bgColor1: Color(0xFF0B1F12), bgColor2: Color(0xFF1B3A22), roadColor: Color(0xFF6B8F4E), accentColor: Color(0xFFE6C94C),
            accessory: '🌼',
          ),
          stops: [
            RoadmapStop(id: 'uat-short-s1', threshold: 2, label: 'Stop 1', totalBoxes: 6, winningBoxes: 2, prize: _prize),
            RoadmapStop(id: 'uat-short-s2', threshold: 4, label: 'Stop 2', totalBoxes: 6, winningBoxes: 2, prize: _prize),
            RoadmapStop(id: 'uat-short-s3', threshold: 6, label: 'Stop 3', totalBoxes: 6, winningBoxes: 2, prize: _prize),
          ],
          prizePoints: {'uat-short-s1': 20, 'uat-short-s3': 50},
        ),
        UatCampaignSeed(
          campaign: Campaign(id: classicId, title: 'UAT Classic Road', description: 'Mirrors the live 3-stop shape.', icon: '🚚', active: true),
          theme: JourneyTheme.fallback,
          stops: [
            RoadmapStop(id: 'uat-classic-s1', threshold: 3, label: 'Stop 1', totalBoxes: 9, winningBoxes: 3, prize: _prize),
            RoadmapStop(
              id: 'uat-classic-s2', threshold: 7, label: 'Stop 2', totalBoxes: 9, winningBoxes: 3, prize: _skinPrize,
              rewardMode: 'guaranteed_with_discount', skinId: 'uat-skin-classic', discountPercent: 50,
            ),
            RoadmapStop(id: 'uat-classic-s3', threshold: 12, label: 'Stop 3', totalBoxes: 9, winningBoxes: 3, prize: _prize),
          ],
          prizePoints: {'uat-classic-s1': 25, 'uat-classic-s3': 100},
        ),
        UatCampaignSeed(
          campaign: Campaign(id: longId, title: 'UAT Long Road', description: 'Six stops, mixed reward modes.', icon: '🚌', active: true, defaultVehicleIcon: '🚌'),
          theme: JourneyTheme(
            id: 'uat-dusk', name: 'Dusk',
            bgColor1: Color(0xFF1A1030), bgColor2: Color(0xFF2E1F4F), roadColor: Color(0xFF7A62A8), accentColor: Color(0xFFFF9A62),
            stopIconLocked: '🌑', stopIconReached: '🌟', stopIconClaimed: '🌕', accessory: '🌙',
          ),
          stops: [
            RoadmapStop(id: 'uat-long-s1', threshold: 2, label: 'Stop 1', totalBoxes: 12, winningBoxes: 4, prize: _prize),
            RoadmapStop(id: 'uat-long-s2', threshold: 5, label: 'Stop 2', totalBoxes: 12, winningBoxes: 4, prize: _prize),
            RoadmapStop(
              id: 'uat-long-s3', threshold: 9, label: 'Stop 3', totalBoxes: 9, winningBoxes: 3, prize: _skinPrize,
              rewardMode: 'guaranteed_with_discount', skinId: 'uat-skin-long', discountPercent: 30,
            ),
            RoadmapStop(id: 'uat-long-s4', threshold: 14, label: 'Stop 4', totalBoxes: 12, winningBoxes: 4, prize: _prize),
            // guaranteed mode but no skin attached: the server falls through to standard.
            RoadmapStop(id: 'uat-long-s5', threshold: 20, label: 'Stop 5', totalBoxes: 6, winningBoxes: 2, prize: _prize, rewardMode: 'guaranteed_with_discount'),
            RoadmapStop(id: 'uat-long-s6', threshold: 27, label: 'Stop 6', totalBoxes: 12, winningBoxes: 6, prize: _prize),
          ],
          prizePoints: {'uat-long-s1': 10, 'uat-long-s2': 20, 'uat-long-s4': 40, 'uat-long-s6': 150},
        ),
      ];

  // Five fake users at different progress levels, computed from each campaign's stops so the
  // positions are meaningful whatever the thresholds are.
  static List<UatUserState> users(List<UatCampaignSeed> seeds) {
    final fresh = UatUserState('uat-user-fresh', 'UAT User A (fresh)');
    final started = UatUserState('uat-user-started', 'UAT User B (1 acha kaam)');
    final mid = UatUserState('uat-user-mid', 'UAT User C (mid-road)');
    final atStop = UatUserState('uat-user-at-stop', 'UAT User D (at a stop)');
    final done = UatUserState('uat-user-finished', 'UAT User E (finished)');
    for (final s in seeds) {
      final id = s.campaign.id;
      final stops = s.stops;
      for (final u in [fresh, started, mid, atStop, done]) {
        u.deeds[id] = 0;
        u.claims[id] = {};
      }
      started.deeds[id] = 1;
      mid.deeds[id] = stops.first.threshold + 1;
      mid.claims[id] = {stops.first.id: const ClaimRecord(won: true)};
      atStop.deeds[id] = stops[1].threshold;
      atStop.claims[id] = {stops.first.id: const ClaimRecord(won: false)};
      done.deeds[id] = stops.last.threshold;
      done.claims[id] = {for (var i = 0; i < stops.length; i++) stops[i].id: ClaimRecord(won: i.isEven)};
      done.hallOfFame.add(id);
    }
    return [fresh, started, mid, atStop, done];
  }
}
