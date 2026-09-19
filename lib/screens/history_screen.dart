import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../theme/app_theme.dart';
import '../state/app_state.dart';
import '../widgets/animated_wallpaper.dart';
import '../data/deed_catalog.dart';
import '../widgets/campaign_icon.dart';

// Real data (deedsLog already loads correctly with real timestamps). Simple table: date + count,
// tap a date to expand and see that day's activity. No date range slider for now, per the
// current pilot scope — straightforward to add later if needed.
//
// Real gap fixed here: this only ever showed deed activity — skin redemptions (a real, separate
// activity type recorded in user_vehicle_skins) never appeared here at all, even though the
// purchase itself worked correctly. Both now merge into the same timeline, since they're both
// genuinely "things that happened," not two separate concepts a person needs to check in two
// different places.
class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});
  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

// Generic wrapper so a deed and a redemption can sit in the same sorted, grouped timeline
// without forcing one shape onto the other.
class _HistoryItem {
  final DateTime when;
  final String icon;
  final String label;
  final String? statusText; // deed status (approved/pending/rejected) — null for redemptions
  const _HistoryItem({required this.when, required this.icon, required this.label, this.statusText});
}

class _HistoryScreenState extends State<HistoryScreen> {
  String? expandedDateKey;
  List<_HistoryItem> redemptions = [];
  List<_HistoryItem> pointsEarned = [];
  bool loadingRedemptions = true;

  @override
  void initState() {
    super.initState();
    _loadRedemptions();
    _loadPointsEarned();
  }

  // New — real points earned from a roadmap win, alongside the existing points-spent
  // (redemption) entries. Only wins where the stop actually had a real points prize show up
  // here — a skin or co-create win has nothing to show in this specific list.
  Future<void> _loadPointsEarned() async {
    try {
      final uid = Supabase.instance.client.auth.currentUser?.id;
      if (uid == null) return;
      final rows = await Supabase.instance.client
          .from('roadmap_claims')
          .select('claimed_at, roadmap_stops(prize_name, prize_icon, prize_points)')
          .eq('user_id', uid)
          .eq('won', true);
      final earned = <_HistoryItem>[];
      for (final r in rows) {
        final stop = r['roadmap_stops'] as Map<String, dynamic>?;
        final points = stop?['prize_points'] as int?;
        // Real fix here: this only skipped a genuinely null value, not zero — a stop with
        // prize_points explicitly set to 0 (a skin/discount-type stop, or one where this field
        // was accidentally left as 0 instead of blank) was still showing a meaningless "+0 PTS"
        // entry. Nothing worth showing below a real, positive amount.
        if (points == null || points <= 0) continue;
        earned.add(_HistoryItem(
          when: DateTime.parse(r['claimed_at'] as String),
          icon: stop?['prize_icon'] as String? ?? '⭐',
          label: stop?['prize_name'] as String? ?? 'Roadmap prize',
          statusText: 'earned:$points',
        ));
      }
      if (mounted) setState(() => pointsEarned = earned);
    } catch (_) {
      // Doesn't block the rest of History either way.
    }
  }

  Future<void> _loadRedemptions() async {
    try {
      final uid = Supabase.instance.client.auth.currentUser?.id;
      if (uid == null) return;
      final rows = await Supabase.instance.client
          .from('user_vehicle_skins')
          .select('acquired_at, points_spent, vehicle_skins(name, icon)')
          .eq('user_id', uid);
      setState(() {
        redemptions = rows.map<_HistoryItem>((r) {
          final skin = r['vehicle_skins'] as Map<String, dynamic>?;
          return _HistoryItem(
            when: DateTime.parse(r['acquired_at'] as String),
            icon: skin?['icon'] as String? ?? '🎨',
            // Real fix here: "X pts used" was embedded directly in the label as plain text,
            // inconsistent with how deed status is shown. Now uses the same real pill mechanism
            // as approved/pending/rejected, just with its own real content and color.
            label: skin?['name'] as String? ?? 'a skin',
            statusText: 'used:${r['points_spent'] as int? ?? 0}',
          );
        }).toList();
        loadingRedemptions = false;
      });
    } catch (_) {
      // Doesn't block the rest of History from showing real deed activity either way.
      if (mounted) setState(() => loadingRedemptions = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();

    // Merge both real activity types into one timeline, grouped by real calendar date, most
    // recent first.
    final byDate = <String, List<_HistoryItem>>{};
    for (final d in state.deedsLog) {
      final meta = deedCatalog[d.type];
      final key = '${d.createdAt.year}-${d.createdAt.month.toString().padLeft(2, '0')}-${d.createdAt.day.toString().padLeft(2, '0')}';
      byDate.putIfAbsent(key, () => []).add(_HistoryItem(
            when: d.createdAt,
            icon: meta?.icon ?? '❓',
            label: meta?.name ?? d.type,
            // Real fix here: an approved deed already genuinely earned real points — showing
            // just the word "approved" hid that real number. Pending/rejected stay exactly as
            // they were, since there's no real point value to show for either of those.
            statusText: d.status == 'approved' ? 'earned:${meta?.points ?? 0}' : d.status,
          ));
    }
    for (final r in redemptions) {
      final key = '${r.when.year}-${r.when.month.toString().padLeft(2, '0')}-${r.when.day.toString().padLeft(2, '0')}';
      byDate.putIfAbsent(key, () => []).add(r);
    }
    for (final e in pointsEarned) {
      final key = '${e.when.year}-${e.when.month.toString().padLeft(2, '0')}-${e.when.day.toString().padLeft(2, '0')}';
      byDate.putIfAbsent(key, () => []).add(e);
    }
    final sortedKeys = byDate.keys.toList()..sort((a, b) => b.compareTo(a));

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(icon: const Icon(Icons.arrow_back, color: AppColors.text), onPressed: () => Navigator.of(context).pop()),
        title: Text('History', style: AppFonts.inter(size: 14, weight: FontWeight.w600)),
        centerTitle: true,
      ),
      body: Stack(
        // Real, genuine root-cause fix: Stack defaults to StackFit.loose, meaning it sizes
        // itself to its non-Positioned child (SafeArea), which in turn sizes to its OWN content
        // rather than filling available space. Every previous attempt only ever changed the
        // background widget itself, never addressed this — the Positioned background was
        // always being clipped down to match the Stack's own, content-sized bounds, regardless
        // of what explicit size it was given. This forces the Stack itself to fill available
        // space unconditionally, which is the actual fix.
        fit: StackFit.expand,
        children: [
          Positioned(
            top: 0,
            left: 0,
            width: MediaQuery.of(context).size.width,
            height: MediaQuery.of(context).size.height,
            child: AnimatedWallpaper(gradientColors: wallpaperSwatches[state.wallpaperSwatchIndex]),
          ),
          SafeArea(
            child: (sortedKeys.isEmpty && loadingRedemptions)
                ? const Center(child: CircularProgressIndicator(color: AppColors.gold))
                : sortedKeys.isEmpty
                    ? Center(child: Text('No activity logged yet.', style: AppFonts.inter(size: 13, color: AppColors.textSoft)))
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(18, 10, 18, 30),
                        itemCount: sortedKeys.length,
                        itemBuilder: (context, i) {
                          final key = sortedKeys[i];
                          final items = byDate[key]!..sort((a, b) => b.when.compareTo(a.when));
                          final expanded = expandedDateKey == key;
                          return Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            decoration: BoxDecoration(color: AppColors.oliveCard, borderRadius: BorderRadius.circular(14)),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                InkWell(
                                  borderRadius: BorderRadius.circular(14),
                                  onTap: () => setState(() => expandedDateKey = expanded ? null : key),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                    child: Row(children: [
                                      Expanded(child: Text(_formatDate(items.first.when), style: AppFonts.inter(size: 13.5, weight: FontWeight.w600))),
                                      Text('${items.length} item${items.length == 1 ? '' : 's'}', style: AppFonts.plexMono(size: 11, color: AppColors.textSoft)),
                                      const SizedBox(width: 8),
                                      Icon(expanded ? Icons.expand_less : Icons.expand_more, size: 18, color: AppColors.textSoft),
                                    ]),
                                  ),
                                ),
                                if (expanded)
                                  Padding(
                                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: items.map((item) {
                                        return Padding(
                                          padding: const EdgeInsets.only(top: 8),
                                          child: Row(children: [
                                            CampaignIcon(icon: item.icon, size: 15),
                                            const SizedBox(width: 8),
                                            Expanded(child: Text(item.label, style: AppFonts.inter(size: 12, color: AppColors.textSoft))),
                                            if (item.statusText != null) _StatusPill(status: item.statusText!),
                                          ]),
                                        );
                                      }).toList(),
                                    ),
                                  ),
                              ],
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime d) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final now = DateTime.now();
    if (d.year == now.year && d.month == now.month && d.day == now.day) return 'Today';
    final yesterday = now.subtract(const Duration(days: 1));
    if (d.year == yesterday.year && d.month == yesterday.month && d.day == yesterday.day) return 'Yesterday';
    return '${months[d.month - 1]} ${d.day}, ${d.year}';
  }
}

class _StatusPill extends StatelessWidget {
  final String status;
  const _StatusPill({required this.status});
  @override
  Widget build(BuildContext context) {
    final String text;
    final Color color;

    if (status.startsWith('used:')) {
      final pts = status.split(':')[1];
      text = 'USED $pts PTS';
      color = AppColors.gold;
    } else if (status.startsWith('earned:')) {
      // Real fix here: matches the exact same green "approved" already used, per direction —
      // every real points-earned pill (whether from an approved deed or a roadmap win) uses one
      // consistent color, not gold for one and green for the other.
      final pts = status.split(':')[1];
      text = '+$pts PTS';
      color = AppColors.olive;
    } else {
      const colors = {'pending': AppColors.textSoft, 'rejected': AppColors.rust};
      text = status.toUpperCase();
      color = colors[status] ?? AppColors.textSoft;
    }

    // Real fix here: pills previously sized to their own text length, so "APPROVED" and
    // "+100 PTS" and "USED 50 PTS" all ended up visibly different widths — genuinely
    // inconsistent, not just a minor visual detail. A fixed minimum width keeps every pill the
    // same real size regardless of what it says.
    return Container(
      constraints: const BoxConstraints(minWidth: 78),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: color.withOpacity(0.18), borderRadius: BorderRadius.circular(100)),
      alignment: Alignment.center,
      child: Text(text, textAlign: TextAlign.center, style: AppFonts.plexMono(size: 8.5, weight: FontWeight.w700, color: color)),
    );
  }
}
