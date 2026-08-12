import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../state/app_state.dart';
import '../data/deed_catalog.dart';

enum BoardView { achievements, heatmap }
enum AchPeriod { today, week, all }

// Ported from #tabBoard in the original. Leaderboard was moved out to its own screen
// (screens/leaderboard_screen.dart) — reached from a Home tile now instead of living inside the
// Board tab, so this segmented control is 2-way (Our Achievements / Pakistan), not 3-way.
// Pakistan is a real, plain bar chart of deeds-per-city now (using the city captured at
// sign-up) — swapped in place of an earlier interactive-map version specifically to avoid the
// risk of untested map-SDK packages while the product is still being tested. No external APIs,
// no new packages, uses only core Flutter widgets. Built from actual approved-deed data via the
// public_deed_cities view — no synthetic data anywhere. Stays visibly blank until real activity
// with a known city exists.
class BoardScreen extends StatefulWidget {
  const BoardScreen({super.key});
  @override
  State<BoardScreen> createState() => _BoardScreenState();
}

class _BoardScreenState extends State<BoardScreen> {
  BoardView view = BoardView.achievements;
  AchPeriod achPeriod = AchPeriod.week;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(18, 10, 18, 90),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('🏆 Achievements', style: AppFonts.fraunces(size: 22, weight: FontWeight.w600)),
          const SizedBox(height: 14),
          _Segmented(
            options: const [('Our Achievements', BoardView.achievements), ('Pakistan', BoardView.heatmap)],
            value: view,
            onChanged: (v) => setState(() => view = v),
          ),
          const SizedBox(height: 14),
          if (view == BoardView.achievements) _AchievementsView(state: state, period: achPeriod, onPeriodChanged: (p) => setState(() => achPeriod = p)),
          if (view == BoardView.heatmap) _HeatmapPlaceholder(),
        ],
      ),
    );
  }
}

class _Segmented<T> extends StatelessWidget {
  final List<(String, T)> options;
  final T value;
  final ValueChanged<T> onChanged;
  const _Segmented({required this.options, required this.value, required this.onChanged});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: AppColors.bg1.withOpacity(0.35), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0x1FF6F5EC))),
      child: Row(
        children: options.map((opt) {
          final active = opt.$2 == value;
          return Expanded(
            child: GestureDetector(
              onTap: () => onChanged(opt.$2),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(color: active ? AppColors.gold : Colors.transparent, borderRadius: BorderRadius.circular(9)),
                alignment: Alignment.center,
                child: Text(opt.$1, textAlign: TextAlign.center, style: AppFonts.plexMono(size: 11.5, weight: FontWeight.w600, color: active ? AppColors.inkOnGold : AppColors.textSoft)),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// NOTE: "Today"/"This Week"/"All Time" — since deedsLog only tracks a `day` counter (not real
// calendar dates), this is an honest simplification: Today = current simDay, This Week = same as
// Today for now (no real multi-day history to distinguish them yet), All Time = everything.
// Flagged the same way the Town Voice weekly-window limitation was flagged.
class _AchievementsView extends StatelessWidget {
  final AppState state;
  final AchPeriod period;
  final ValueChanged<AchPeriod> onPeriodChanged;
  const _AchievementsView({required this.state, required this.period, required this.onPeriodChanged});

  List<DeedLogEntry> get _filtered {
    final now = DateTime.now();
    switch (period) {
      case AchPeriod.today:
        // Real calendar-date comparison now — was d.day == state.simDay, which silently excluded
        // every loaded deed from a previous session (see DeedLogEntry's createdAt field for the
        // full explanation). This is the actual fix for "today's deeds aren't showing up".
        return state.deedsLog.where((d) {
          final c = d.createdAt;
          return d.status == 'approved' && c.year == now.year && c.month == now.month && c.day == now.day;
        }).toList();
      case AchPeriod.week:
        // Monday–Sunday, same weekly-window definition already used for Leaderboard/Town Voice
        // elsewhere in this app — "This Week" and "Today" were previously using the exact same
        // (broken) filter and were indistinguishable; now they're genuinely different ranges.
        final weekday = now.weekday; // 1 = Monday .. 7 = Sunday
        final startOfWeek = DateTime(now.year, now.month, now.day).subtract(Duration(days: weekday - 1));
        return state.deedsLog.where((d) => d.status == 'approved' && !d.createdAt.isBefore(startOfWeek)).toList();
      case AchPeriod.all:
        return state.deedsLog.where((d) => d.status == 'approved').toList();
    }
  }

  @override
  Widget build(BuildContext context) {
    final current = _filtered;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Expanded(child: _Chip(label: 'Today', active: period == AchPeriod.today, onTap: () => onPeriodChanged(AchPeriod.today))),
          const SizedBox(width: 6),
          Expanded(child: _Chip(label: 'This Week', active: period == AchPeriod.week, onTap: () => onPeriodChanged(AchPeriod.week))),
          const SizedBox(width: 6),
          Expanded(child: _Chip(label: 'All Time', active: period == AchPeriod.all, onTap: () => onPeriodChanged(AchPeriod.all))),
        ]),
        const SizedBox(height: 14),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: AppColors.oliveCard, borderRadius: BorderRadius.circular(14)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('TOTAL DEEDS ACTIONED', style: AppFonts.plexMono(size: 10.5, color: AppColors.textSoft)),
            const SizedBox(height: 4),
            Text('${current.length}', style: AppFonts.fraunces(size: 28, weight: FontWeight.w600)),
          ]),
        ),
        const SizedBox(height: 14),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          // Taller than before (was 1.6) — icon and name are now stacked on separate lines
          // instead of inline, which needs more vertical room. Sized generously against the
          // actual content this time, after the tile-overflow lesson from earlier.
          childAspectRatio: 1.05,
          children: categoryDefs.map((cat) {
            final count = current.where((d) => deedCatalog[d.type]?.category == cat.key).length;
            return GestureDetector(
              onTap: () => _showCategoryBreakdown(context, cat, current),
              child: Container(
                padding: const EdgeInsets.all(13),
                decoration: BoxDecoration(color: AppColors.oliveCard, borderRadius: BorderRadius.circular(14)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(cat.icon, style: const TextStyle(fontSize: 30)),
                    const SizedBox(height: 8),
                    Text(cat.name, style: AppFonts.inter(size: 12.5, weight: FontWeight.w600), maxLines: 2, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 6),
                    Text('$count', style: AppFonts.fraunces(size: 22, weight: FontWeight.w600)), // unchanged, as asked
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  // Ported from openCategoryBreakdown() in the original — tapping a category card shows the
  // per-deed counts within it for the currently selected period. Only deeds actually actioned
  // this period are listed, matching the original exactly.
  void _showCategoryBreakdown(BuildContext context, CategoryDef cat, List<DeedLogEntry> current) {
    final keysInCat = deedCatalog.keys.where((k) => deedCatalog[k]!.category == cat.key).toList();
    final rows = <(String, String, int)>[];
    for (final key in keysInCat) {
      final count = current.where((d) => d.type == key).length;
      if (count == 0) continue; // only deeds actually actioned this period, same as the original
      rows.add((deedCatalog[key]!.icon, deedCatalog[key]!.name, count));
    }
    final periodLabel = switch (period) {
      AchPeriod.today => 'Today',
      AchPeriod.week => 'This Week',
      AchPeriod.all => 'All Time',
    };

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.5,
        maxChildSize: 0.85,
        minChildSize: 0.3,
        expand: false,
        builder: (context, scrollController) {
          return Container(
            decoration: const BoxDecoration(color: AppColors.bg2, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
                  child: Row(children: [
                    Text('${cat.icon} ${cat.name}', style: AppFonts.fraunces(size: 15, weight: FontWeight.w600)),
                    const Spacer(),
                    Text(periodLabel, style: AppFonts.plexMono(size: 9.5, color: AppColors.textSoft)),
                  ]),
                ),
                Expanded(
                  child: rows.isEmpty
                      ? Center(child: Text('No deeds actioned in this category yet.', style: AppFonts.inter(size: 12, color: AppColors.textSoft)))
                      : ListView.builder(
                          controller: scrollController,
                          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                          itemCount: rows.length,
                          itemBuilder: (context, i) {
                            final (icon, name, count) = rows[i];
                            return Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              decoration: BoxDecoration(color: AppColors.oliveCard, borderRadius: BorderRadius.circular(12)),
                              child: Row(children: [
                                Container(
                                  width: 30, height: 30,
                                  decoration: BoxDecoration(shape: BoxShape.circle, color: AppColors.bg2.withOpacity(0.4)),
                                  alignment: Alignment.center,
                                  child: Text(icon, style: const TextStyle(fontSize: 15)),
                                ),
                                const SizedBox(width: 10),
                                Expanded(child: Text(name, style: AppFonts.inter(size: 12.5, weight: FontWeight.w600))),
                                Text('×$count', style: AppFonts.plexMono(size: 12, weight: FontWeight.w600, color: AppColors.textSoft)),
                              ]),
                            );
                          },
                        ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _Chip({required this.label, required this.active, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 7),
        decoration: BoxDecoration(
          color: active ? AppColors.oliveCardStrong : Colors.transparent,
          borderRadius: BorderRadius.circular(9),
          border: Border.all(color: active ? AppColors.olive : const Color(0x29F6F5EC)),
        ),
        alignment: Alignment.center,
        child: Text(label, style: AppFonts.plexMono(size: 11, weight: FontWeight.w600, color: active ? AppColors.text : AppColors.textSoft)),
      ),
    );
  }
}

class _HeatmapPlaceholder extends StatefulWidget {
  @override
  State<_HeatmapPlaceholder> createState() => _HeatmapPlaceholderState();
}

class _HeatmapPlaceholderState extends State<_HeatmapPlaceholder> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AppState>().loadCityBreakdown();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();

    if (state.cityBreakdownLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 60),
        child: Center(child: CircularProgressIndicator(color: AppColors.gold)),
      );
    }

    final cities = state.cityBreakdown;

    if (cities.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 40),
        child: Center(
          child: Text(
            'No approved deeds with a city on record yet — this fills in automatically as real activity comes in.',
            textAlign: TextAlign.center,
            style: AppFonts.inter(size: 12, color: AppColors.textSoft, height: 1.5),
          ),
        ),
      );
    }

    final maxCount = cities.first.count; // already sorted descending in AppState

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Deeds by City', style: AppFonts.fraunces(size: 15, weight: FontWeight.w600)),
        const SizedBox(height: 4),
        Text('Based on the city entered at sign-up, for approved deeds.', style: AppFonts.inter(size: 11, color: AppColors.textSoft)),
        const SizedBox(height: 16),
        ...cities.map((c) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              children: [
                SizedBox(
                  width: 90,
                  child: Text(c.city, style: AppFonts.inter(size: 12.5, weight: FontWeight.w600), overflow: TextOverflow.ellipsis),
                ),
                Expanded(
                  child: Container(
                    height: 20,
                    decoration: BoxDecoration(color: AppColors.bg2.withOpacity(0.4), borderRadius: BorderRadius.circular(7)),
                    child: FractionallySizedBox(
                      alignment: Alignment.centerLeft,
                      widthFactor: c.count / maxCount,
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(colors: [AppColors.olive, AppColors.gold]),
                          borderRadius: BorderRadius.circular(7),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  width: 36,
                  child: Text('${c.count}', textAlign: TextAlign.right, style: AppFonts.plexMono(size: 11, color: AppColors.textSoft)),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }
}
