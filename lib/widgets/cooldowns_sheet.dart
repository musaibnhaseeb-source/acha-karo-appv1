import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../state/app_state.dart';
import '../data/deed_catalog.dart';

String _formatRemaining(Duration d) {
  final mins = (d.inSeconds / 60).ceil();
  if (mins >= 60) return '${mins ~/ 60}h ${mins % 60}m';
  return '${mins}m';
}

// The "Tasks cooling down" button never actually opened anything before this — no onTap was
// wired at all. This is that missing screen, shown as a popup (bottom sheet) rather than a full
// page push, per the direction to keep it lightweight.
class CooldownsSheet extends StatefulWidget {
  const CooldownsSheet({super.key});
  @override
  State<CooldownsSheet> createState() => _CooldownsSheetState();
}

class _CooldownsSheetState extends State<CooldownsSheet> {
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    // Cooldown times are live/decreasing — a periodic rebuild keeps the remaining-time labels
    // accurate while the sheet is open, instead of freezing at whatever it showed on open.
    _ticker = Timer.periodic(const Duration(seconds: 15), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final locked = deedCatalog.keys.where((k) => state.cooldownRemaining(k) > Duration.zero).toList()
      ..sort((a, b) => state.cooldownRemaining(a).compareTo(state.cooldownRemaining(b)));

    return DraggableScrollableSheet(
      initialChildSize: 0.55,
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
                  Text('🔒', style: AppFonts.inter(size: 18)),
                  const SizedBox(width: 8),
                  Expanded(child: Text('Tasks cooling down', style: AppFonts.fraunces(size: 16, weight: FontWeight.w600))),
                  Text('${locked.length}', style: AppFonts.plexMono(size: 12, weight: FontWeight.w700, color: AppColors.gold)),
                ]),
              ),
              Expanded(
                child: locked.isEmpty
                    ? Center(child: Text('Nothing on cooldown right now.', style: AppFonts.inter(size: 12, color: AppColors.textSoft)))
                    : ListView.builder(
                        controller: scrollController,
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                        itemCount: locked.length,
                        itemBuilder: (context, i) {
                          final key = locked[i];
                          final meta = deedCatalog[key]!;
                          final remaining = state.cooldownRemaining(key);
                          return Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            decoration: BoxDecoration(color: AppColors.oliveCard, borderRadius: BorderRadius.circular(12)),
                            child: Row(children: [
                              Container(
                                width: 32, height: 32,
                                decoration: BoxDecoration(shape: BoxShape.circle, color: AppColors.bg2.withOpacity(0.4)),
                                alignment: Alignment.center,
                                child: Text(meta.icon, style: const TextStyle(fontSize: 16)),
                              ),
                              const SizedBox(width: 10),
                              Expanded(child: Text(meta.name, style: AppFonts.inter(size: 12.5, weight: FontWeight.w600))),
                              Text('⏱ ${_formatRemaining(remaining)}', style: AppFonts.plexMono(size: 10.5, color: AppColors.textSoft)),
                            ]),
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}
