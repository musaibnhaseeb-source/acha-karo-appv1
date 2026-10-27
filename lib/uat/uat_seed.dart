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

  JourneyConfig toConfig() => JourneyConfig(campaign: campaign, stops: stops, theme: theme, copy: {for (final s in stops) if (UatSeed.copy.containsKey(s.id)) s.id: UatSeed.copy[s.id]!});
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
  // Sample wording from the Supervisor's copy file (UAT only): title is the stop label above.
  static const Map<String, StopCopy> copy = {
    'uat-short-s1': StopCopy('Two acha kaam and you\'re here.', 'You made it. Pick a box.'),
    'uat-short-s2': StopCopy('Keep walking, one acha kaam at a time.', 'Nice walking. Pick a box.'),
    'uat-short-s3': StopCopy('Last stop on this road.', 'You finished the road!'),
    'uat-classic-s1': StopCopy('Do 3 acha kaam to get here.', 'First milestone done.'),
    'uat-classic-s2': StopCopy('A new look is waiting at this stop.', 'Your look is ready.'),
    'uat-classic-s3': StopCopy('Do 12 acha kaam to finish the road.', 'Road complete. Well done.'),
    'uat-long-s1': StopCopy('Get ready and head out safe.', 'Bag packed. Off you go.'),
    'uat-long-s2': StopCopy('Cross where it is safe.', 'Crossed safely.'),
    'uat-long-s3': StopCopy('Wait for the light.', 'You waited. Good.'),
    'uat-long-s4': StopCopy('Pause before you cross.', 'Paused and safe.'),
    'uat-long-s5': StopCopy('Left, right, then go.', 'Both ways clear.'),
    'uat-long-s6': StopCopy('You reached school safely.', 'Safe at school!'),
  };

  static const _prize = RoadmapPrize(name: 'Sample prize', icon: '🎁');
  static const _skinPrize = RoadmapPrize(name: 'Sample vehicle skin', icon: '🚙');

  static const shortId = 'uat-short';
  static const classicId = 'uat-classic';
  static const longId = 'uat-long';

  static List<UatCampaignSeed> campaigns() => const [
        UatCampaignSeed(
          campaign: Campaign(id: shortId, title: 'UAT Short Road', description: 'Three quick stops.', icon: '🚲', active: true, defaultVehicleIcon: '🚲'),
          theme: JourneyTheme(
            id: 'uat-meadow', name: 'Meadow', title: 'Meadow Walk',
            bgColor1: Color(0xFF0B1F12), bgColor2: Color(0xFF1B3A22), roadColor: Color(0xFF6B8F4E), accentColor: Color(0xFFE6C94C),
            accessory: '🌼',
            artFolder: 'general',
          ),
          stops: [
            RoadmapStop(id: 'uat-short-s1', threshold: 2, label: 'Good start', totalBoxes: 6, winningBoxes: 2, prize: _prize),
            RoadmapStop(id: 'uat-short-s2', threshold: 4, label: 'Halfway happy', totalBoxes: 6, winningBoxes: 2, prize: _prize),
            RoadmapStop(id: 'uat-short-s3', threshold: 6, label: 'Meadow\'s end', totalBoxes: 6, winningBoxes: 2, prize: _prize),
          ],
          prizePoints: {'uat-short-s1': 20, 'uat-short-s3': 50},
        ),
        UatCampaignSeed(
          campaign: Campaign(id: classicId, title: 'UAT Classic Road', description: 'Mirrors the live 3-stop shape.', icon: '🚚', active: true),
          theme: JourneyTheme.fallback,
          stops: [
            RoadmapStop(id: 'uat-classic-s1', threshold: 3, label: 'First milestone', totalBoxes: 9, winningBoxes: 3, prize: _prize),
            RoadmapStop(
              id: 'uat-classic-s2', threshold: 7, label: 'Skin stop', totalBoxes: 9, winningBoxes: 3, prize: _skinPrize,
              rewardMode: 'guaranteed_with_discount', skinId: 'uat-skin-classic', discountPercent: 50,
            ),
            RoadmapStop(id: 'uat-classic-s3', threshold: 12, label: 'Road complete', totalBoxes: 9, winningBoxes: 3, prize: _prize),
          ],
          prizePoints: {'uat-classic-s1': 25, 'uat-classic-s3': 100},
        ),
        UatCampaignSeed(
          campaign: Campaign(id: longId, title: 'UAT Long Road', description: 'Six stops, mixed reward modes.', icon: '🚌', active: true, defaultVehicleIcon: '🚌'),
          theme: JourneyTheme(
            id: 'uat-road', name: 'Road safety', title: 'Safe Road to School',
            bgColor1: Color(0xFF0A1C26), bgColor2: Color(0xFF1C4352), roadColor: Color(0xFF3A4750), accentColor: Color(0xFFD9A62E),
            skyTop: Color(0xFF0A1C26), skyHorizon: Color(0xFF1C4352), glow: Color(0x2ED9A62E), skyDots: Color(0xFFF6F5EC),
            farStyle: 'skyline', farA: Color(0xFF16313C), farB: Color(0xFFF2D58A),
            midStyle: 'lamps', midColor: Color(0xFF2A4F5C),
            groundRoad: Color(0xFF171E23), groundKerb: Color(0xFF3A4750), groundDash: Color(0x8CF6F5EC),
            landmarks: ['house', 'zebra', 'light', 'stop', 'lookboth', 'gate'],
            stopIcons: ['🎒', '🚸', '🚦', '🛑', '👀', '🏫'],
            artFolder: 'road',
          ),
          stops: [
            RoadmapStop(id: 'uat-long-s1', threshold: 2, label: 'Pack up', totalBoxes: 12, winningBoxes: 4, prize: _prize),
            RoadmapStop(id: 'uat-long-s2', threshold: 5, label: 'Zebra crossing', totalBoxes: 12, winningBoxes: 4, prize: _prize),
            RoadmapStop(
              id: 'uat-long-s3', threshold: 9, label: 'Green means go', totalBoxes: 9, winningBoxes: 3, prize: _skinPrize,
              rewardMode: 'guaranteed_with_discount', skinId: 'uat-skin-long', discountPercent: 30,
            ),
            RoadmapStop(id: 'uat-long-s4', threshold: 14, label: 'Stop and look', totalBoxes: 12, winningBoxes: 4, prize: _prize),
            // guaranteed mode but no skin attached: the server falls through to standard.
            RoadmapStop(id: 'uat-long-s5', threshold: 20, label: 'Look both ways', totalBoxes: 6, winningBoxes: 2, prize: _prize, rewardMode: 'guaranteed_with_discount'),
            RoadmapStop(id: 'uat-long-s6', threshold: 27, label: 'School gate', totalBoxes: 12, winningBoxes: 6, prize: _prize),
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
