import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../state/app_state.dart';
import '../data/deed_catalog.dart';

// New — real data (deedsLog already loads correctly with real timestamps), just needed a
// screen. Simple table: date + count, tap a date to expand and see that day's deeds. No date
// range slider for now, per the current pilot scope — straightforward to add later if needed.
class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});
  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  String? expandedDateKey;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();

    // Group by real calendar date, most recent first.
    final byDate = <String, List<DeedLogEntry>>{};
    for (final d in state.deedsLog) {
      final key = '${d.createdAt.year}-${d.createdAt.month.toString().padLeft(2, '0')}-${d.createdAt.day.toString().padLeft(2, '0')}';
      byDate.putIfAbsent(key, () => []).add(d);
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
      body: Container(
        decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: wallpaperSwatches[context.watch<AppState>().wallpaperSwatchIndex])),
        child: SafeArea(
          child: sortedKeys.isEmpty
              ? Center(child: Text('No deeds logged yet.', style: AppFonts.inter(size: 13, color: AppColors.textSoft)))
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(18, 10, 18, 30),
                  itemCount: sortedKeys.length,
                  itemBuilder: (context, i) {
                    final key = sortedKeys[i];
                    final deeds = byDate[key]!;
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
                                Expanded(child: Text(_formatDate(deeds.first.createdAt), style: AppFonts.inter(size: 13.5, weight: FontWeight.w600))),
                                Text('${deeds.length} deed${deeds.length == 1 ? '' : 's'}', style: AppFonts.plexMono(size: 11, color: AppColors.textSoft)),
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
                                children: deeds.map((d) {
                                  final meta = deedCatalog[d.type];
                                  return Padding(
                                    padding: const EdgeInsets.only(top: 8),
                                    child: Row(children: [
                                      Text(meta?.icon ?? '❓', style: const TextStyle(fontSize: 15)),
                                      const SizedBox(width: 8),
                                      Expanded(child: Text(meta?.name ?? d.type, style: AppFonts.inter(size: 12, color: AppColors.textSoft))),
                                      _StatusPill(status: d.status),
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
    final colors = {'approved': AppColors.olive, 'pending': AppColors.textSoft, 'rejected': AppColors.rust};
    final color = colors[status] ?? AppColors.textSoft;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: color.withOpacity(0.18), borderRadius: BorderRadius.circular(100)),
      child: Text(status.toUpperCase(), style: AppFonts.plexMono(size: 8.5, weight: FontWeight.w700, color: color)),
    );
  }
}
