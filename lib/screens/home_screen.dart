import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../state/app_state.dart';
import '../data/deed_catalog.dart';
import '../data/tiers.dart';
import '../widgets/submit_deed_flow.dart';
import '../widgets/cooldowns_sheet.dart';
import '../widgets/home_side_sheet.dart';
import 'town_voice_screen.dart';
import 'leaderboard_screen.dart';
import 'badges_screen.dart';
import 'campaign_detail_screen.dart';
import '../widgets/campaign_icon.dart';
import '../data/badges.dart';

String _formatRemaining(Duration d) {
  final mins = (d.inSeconds / 60).ceil();
  if (mins >= 60) return '${mins ~/ 60}h ${mins % 60}m';
  return '${mins}m';
}

// Ported from HomeScreen.jsx (Next.js port) — same category accordion, same cooldown button
// reposition-on-open behavior (done here via conditional widget ordering, same idea as the
// React version's conditional JSX — no DOM/imperative reordering needed in either framework).
// Assigned-to-you section, daily-milestone/tier-up animations, and confetti/sound are NOT yet
// ported — see PORTING_STATUS.md.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String? openCategoryKey;
  final _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final tier = getUserTier(state.user.badges.length);
    final lockedKeys = deedCatalog.keys.where((k) => state.cooldownRemaining(k) > Duration.zero).toList();
    final rank = _computeRank(state);

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: Colors.transparent,
      endDrawer: const HomeSideSheet(),
      body: GestureDetector(
        // Tapping anywhere outside the open category panel closes it now — previously you had
        // to tap the same ring icon again specifically. Nested GestureDetectors (the rings, deed
        // rows, buttons) win the gesture arena for their own taps by default, so this only fires
        // for taps that land outside all of those, which is exactly "click outside to close".
        behavior: HitTestBehavior.opaque,
        onTap: () {
          if (openCategoryKey != null) setState(() => openCategoryKey = null);
        },
        child: SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(18, 6, 18, 90),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Day ${state.simDay} · Good afternoon', style: AppFonts.plexMono(size: 10.5)),
              // Bell icon removed — redundant with Notifications already living in the Side
              // Sheet. The menu button (which opens that sheet) is the only entry point needed.
              GestureDetector(
                onTap: () => _scaffoldKey.currentState?.openEndDrawer(),
                child: Container(
                  width: 32, height: 32,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: AppColors.oliveCardStrong, border: Border.all(color: const Color(0x29F6F5EC))),
                  alignment: Alignment.center,
                  child: Stack(clipBehavior: Clip.none, children: [
                    const Icon(Icons.menu, size: 16, color: AppColors.text),
                    if (state.hasSideSheetActivity)
                      Positioned(
                        top: -3, right: -3,
                        child: Container(width: 9, height: 9, decoration: BoxDecoration(shape: BoxShape.circle, color: AppColors.rust, border: Border.all(color: AppColors.bg2, width: 2))),
                      ),
                  ]),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(state.user.name.split(' ').first, style: AppFonts.fraunces(size: 22, weight: FontWeight.w600)),
              Row(children: [
                Text(tier.icon, style: const TextStyle(fontSize: 22)),
                const SizedBox(width: 4),
                Text(tier.name, style: AppFonts.nastaliq(size: 22, color: AppColors.gold)),
              ]),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('TOTAL POINTS', style: AppFonts.plexMono(size: 9)),
                Text('${state.user.points}', style: AppFonts.fraunces(size: 28, weight: FontWeight.w700, color: AppColors.gold)),
              ]),
              Text('🔥 ${state.user.streak} day streak', style: AppFonts.plexMono(size: 11)),
            ],
          ),
          const SizedBox(height: 22),
          Text('Log a good deed', style: AppFonts.fraunces(size: 15, weight: FontWeight.w600)),
          const SizedBox(height: 10),

          LayoutBuilder(builder: (context, constraints) {
            // Responsive instead of a fixed pixel size — a hardcoded "bigger" size risked
            // overflowing on narrower phones (5 rings at a fixed 76px alone is already 380px,
            // before any gaps, which exceeds many real device widths). This sizes each ring off
            // the actual available width instead, so it's as big as safely possible on any screen.
            final ringSize = ((constraints.maxWidth - 24) / 5).clamp(52.0, 76.0);
            return Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: categoryDefs.map((cat) {
                final keysInCat = deedCatalog.keys.where((k) => deedCatalog[k]!.category == cat.key).toList();
                final doneCount = keysInCat.where((k) => state.cooldownRemaining(k) > Duration.zero).length;
                final pct = keysInCat.isEmpty ? 0.0 : doneCount / keysInCat.length;
                final isActive = openCategoryKey == cat.key;
                return GestureDetector(
                  onTap: () => setState(() => openCategoryKey = isActive ? null : cat.key),
                  child: Column(children: [
                    _CategoryRing(icon: cat.icon, progress: pct, active: isActive, size: ringSize),
                    const SizedBox(height: 4),
                    Text(cat.short, style: AppFonts.plexMono(size: 9.5, weight: FontWeight.w600, color: AppColors.text)),
                  ]),
                );
              }).toList(),
            );
          }),

          if (openCategoryKey == null && lockedKeys.isNotEmpty) ...[
            const SizedBox(height: 8),
            _CooldownButton(count: lockedKeys.length, onTap: () => _openCooldownsSheet(context)),
          ],

          if (openCategoryKey != null) ...[
            const SizedBox(height: 10),
            _CategoryPanel(
              categoryKey: openCategoryKey!,
              state: state,
              onSelectDeed: (type) => _openSubmitModal(context, type),
            ),
          ],

          if (openCategoryKey != null && lockedKeys.isNotEmpty) ...[
            const SizedBox(height: 8),
            _CooldownButton(count: lockedKeys.length, onTap: () => _openCooldownsSheet(context)),
          ],

          const SizedBox(height: 22),
          // Only renders when a campaign's `active` field is true — proves the actual point of
          // this whole architecture: flipping that field (a database change) shows/hides this
          // with zero app update. Positioned right above Leaderboard, per the current design.
          ...state.remoteConfig.activeCampaigns.map((c) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: GestureDetector(
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => CampaignDetailScreen(campaign: c))),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: [AppColors.gold.withOpacity(0.16), AppColors.oliveCard]),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.gold.withOpacity(0.3)),
                    ),
                    child: Row(children: [
                      Container(
                        width: 44, height: 44,
                        decoration: BoxDecoration(shape: BoxShape.circle, color: AppColors.gold.withOpacity(0.18)),
                        alignment: Alignment.center,
                        child: CampaignIcon(icon: c.icon, size: 22),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(c.title, style: AppFonts.fraunces(size: 14.5, weight: FontWeight.w600)),
                          Text(c.description, style: AppFonts.inter(size: 11, color: AppColors.textSoft)),
                        ]),
                      ),
                      const Icon(Icons.chevron_right, color: AppColors.gold, size: 20),
                    ]),
                  ),
                ),
              )),
          _BigTile(
            icon: '👑',
            name: 'Leaderboard',
            description: 'You\'re ranked #$rank overall',
            onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const LeaderboardScreen())),
          ),
          const SizedBox(height: 10),
          _BigTile(
            icon: '🏅',
            name: 'Badges',
            description: '${state.user.badges.length} of ${badgeDefs.length} badges earned',
            onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const BadgesScreen())),
          ),
          const SizedBox(height: 10),
          _BigTile(
            icon: '🎙️',
            name: 'Town Voice',
            // Was showing "X is leading this week" — contradicted the page it opens, which now
            // says launching soon. Kept consistent with what's actually behind the tile.
            description: 'Launching soon',
            onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const TownVoiceScreen())),
          ),
          // Redeem tile removed for the pilot, per the current direction — no redemption system
          // exists yet, and a hardcoded "0 pts" tile that always leads to a toast wasn't adding
          // anything. Easy to bring back once real redemption exists.
        ],
      ),
      ),
      ),
    );
  }

  int _computeRank(AppState state) {
    final all = [...otherUsers.map((u) => u.points), state.user.points]..sort((a, b) => b.compareTo(a));
    return all.indexOf(state.user.points) + 1;
  }

  void _openCooldownsSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const CooldownsSheet(),
    );
  }

  void _openSubmitModal(BuildContext context, String type) => openSubmitDeedFlow(context, type);
}

// Shared big tile — icon on the left (sized to the tile), name + smaller description stacked to
// its right. Rebuilt after the previous vertical icon-on-top layout overflowed (stacking 4 text
// elements in a fixed height was too tight for real content) — a horizontal row is both what was
// asked for and inherently safer here, since it doesn't compound vertical space the way stacking
// icon+label+title+subtitle did.
// NOTE: Town Voice's holder name here is based on lifetime points — an honest interim
// placeholder until real Mon–Sun weekly-window tracking is built (needs real timestamps on
// deedsLog, not just the current `day` counter). Flagged clearly rather than presented as final.
class _BigTile extends StatelessWidget {
  final String icon;
  final String name;
  final String description;
  final VoidCallback? onTap;
  const _BigTile({required this.icon, required this.name, required this.description, this.onTap});

  static const double _height = 92;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        height: _height,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [AppColors.gold.withOpacity(0.12), AppColors.oliveCard]),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.gold.withOpacity(0.28)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(icon, style: const TextStyle(fontSize: 42)),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: AppFonts.fraunces(size: 16, weight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 3),
                  Text(description, style: AppFonts.inter(size: 11, color: AppColors.textSoft), maxLines: 2, overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CategoryRing extends StatelessWidget {
  final String icon;
  final double progress; // 0..1
  final bool active;
  final double size;
  const _CategoryRing({required this.icon, required this.progress, required this.active, required this.size});
  @override
  Widget build(BuildContext context) {
    final innerSize = size * 0.84;
    return SizedBox(
      width: size, height: size,
      child: Stack(alignment: Alignment.center, children: [
        CustomPaint(size: Size(size, size), painter: _RingPainter(progress: progress)),
        Container(
          width: innerSize, height: innerSize,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            // Same vibrant gold-tinted gradient as the Town Voice/Redeem/Leaderboard tiles now,
            // instead of the plain flat oliveCard fill — ring/progress logic (the CustomPaint
            // arc above) is completely unchanged, only this inner circle's fill matches.
            gradient: LinearGradient(colors: [AppColors.gold.withOpacity(0.12), AppColors.oliveCard]),
            border: Border.all(color: active ? AppColors.gold : AppColors.bg2, width: 2),
          ),
          alignment: Alignment.center,
          child: Text(icon, style: TextStyle(fontSize: size * 0.37)),
        ),
      ]),
    );
  }
}

class _RingPainter extends CustomPainter {
  final double progress;
  _RingPainter({required this.progress});
  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0) return;
    final paint = Paint()
      ..color = AppColors.gold
      ..strokeWidth = 4
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.butt;
    final rect = Rect.fromLTWH(2, 2, size.width - 4, size.height - 4);
    canvas.drawArc(rect, -3.14159 / 2, 2 * 3.14159 * progress, false, paint);
  }

  @override
  bool shouldRepaint(covariant _RingPainter oldDelegate) => oldDelegate.progress != progress;
}

class _CooldownButton extends StatelessWidget {
  final int count;
  final VoidCallback onTap;
  const _CooldownButton({required this.count, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(color: AppColors.oliveCard, borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0x29F6F5EC))),
        child: Row(children: [
          const Text('🔒', style: TextStyle(fontSize: 15)),
          const SizedBox(width: 8),
          Expanded(child: Text('Tasks cooling down', style: AppFonts.inter(size: 12, weight: FontWeight.w600))),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 2),
            decoration: BoxDecoration(color: AppColors.oliveCardStrong, borderRadius: BorderRadius.circular(100), border: Border.all(color: AppColors.gold.withOpacity(0.3))),
            child: Text('$count', style: AppFonts.plexMono(size: 11, weight: FontWeight.w700, color: AppColors.gold)),
          ),
        ]),
      ),
    );
  }
}

class _CategoryPanel extends StatelessWidget {
  final String categoryKey;
  final AppState state;
  final ValueChanged<String> onSelectDeed;
  const _CategoryPanel({required this.categoryKey, required this.state, required this.onSelectDeed});

  @override
  Widget build(BuildContext context) {
    final cat = categoryDefs.firstWhere((c) => c.key == categoryKey);
    final keysInCat = deedCatalog.keys.where((k) => deedCatalog[k]!.category == categoryKey).toList();
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: AppColors.oliveCard, borderRadius: BorderRadius.circular(14)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text(cat.icon, style: const TextStyle(fontSize: 16)),
          const SizedBox(width: 8),
          Expanded(child: Text(cat.name, style: AppFonts.fraunces(size: 13.5, weight: FontWeight.w600))),
          Text('${keysInCat.length}', style: AppFonts.plexMono(size: 9.5)),
        ]),
        const SizedBox(height: 8),
        ...keysInCat.map((key) {
          final meta = deedCatalog[key]!;
          final remaining = state.cooldownRemaining(key);
          final onCooldown = remaining > Duration.zero;
          return Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: GestureDetector(
              onTap: onCooldown ? null : () => onSelectDeed(key),
              child: Opacity(
                opacity: onCooldown ? 0.55 : 1,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                  decoration: BoxDecoration(color: AppColors.bg2.withOpacity(0.4), borderRadius: BorderRadius.circular(12)),
                  child: Row(children: [
                    Container(
                      width: 30, height: 30,
                      decoration: const BoxDecoration(shape: BoxShape.circle, color: AppColors.oliveCard),
                      alignment: Alignment.center,
                      child: Text(meta.icon, style: const TextStyle(fontSize: 16)),
                    ),
                    const SizedBox(width: 10),
                    Expanded(child: Text(meta.name, style: AppFonts.inter(size: 12, weight: FontWeight.w600))),
                    Text(
                      onCooldown ? '⏱ ${_formatRemaining(remaining)}' : '+${meta.points} pts',
                      style: AppFonts.plexMono(size: 10.5, color: onCooldown ? AppColors.textSoft : AppColors.olive),
                    ),
                  ]),
                ),
              ),
            ),
          );
        }),
      ]),
    );
  }
}
