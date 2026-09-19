// Real data model now, matching roadmap_stops.sql exactly — replacing the local placeholder
// list from Phase 1's UI-only testing. Same reusable structure agreed on from the start: one
// engine, fed real data from the database, ready to serve the eventual Pakistan map with zero
// changes to the shape itself.

class RoadmapPrize {
  final String name;
  final String icon;
  const RoadmapPrize({required this.name, required this.icon});
}

class RoadmapStop {
  final String id; // real UUID from roadmap_stops now, needed to call the claim Edge Function
  final int threshold;
  final String label;
  final int totalBoxes;
  final int winningBoxes;
  final RoadmapPrize prize;
  // New — 'standard' (Stop 1, Stop 3: win shows the prize, lose shows nothing) or
  // 'guaranteed_with_discount' (Stop 2: win grants a skin free, any other tap grants a discount
  // instead — never "you got nothing"). skinId/discountPercent only meaningful for the latter.
  final String rewardMode;
  final String? skinId;
  final int discountPercent;
  const RoadmapStop({
    required this.id,
    required this.threshold,
    required this.label,
    required this.totalBoxes,
    required this.winningBoxes,
    required this.prize,
    this.rewardMode = 'standard',
    this.skinId,
    this.discountPercent = 50,
  });

  factory RoadmapStop.fromRow(Map<String, dynamic> row) {
    return RoadmapStop(
      id: row['id'] as String,
      threshold: row['threshold'] as int,
      label: row['label'] as String,
      totalBoxes: row['total_boxes'] as int,
      winningBoxes: row['winning_boxes'] as int,
      prize: RoadmapPrize(name: row['prize_name'] as String, icon: row['prize_icon'] as String),
      rewardMode: row['reward_mode'] as String? ?? 'standard',
      skinId: row['skin_id'] as String?,
      discountPercent: row['discount_percent'] as int? ?? 50,
    );
  }
}
