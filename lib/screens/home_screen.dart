import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../theme/app_theme.dart';
import '../state/app_state.dart';
import '../data/deed_catalog.dart';
import '../data/tiers.dart';
import '../widgets/submit_deed_flow.dart';
import '../widgets/cooldowns_sheet.dart';
import '../widgets/home_side_sheet.dart';
import 'town_voice_screen.dart';
import 'leaderboard_screen.dart';
import 'campaign_detail_screen.dart';
import '../widgets/campaign_icon.dart';
import '../widgets/big_tile.dart';
import '../utils/youtube.dart';
import '../utils/onboarding_store.dart';
import '../utils/daily_reminder.dart';
import '../widgets/guddi_tour.dart';
import '../widgets/first_deed.dart';

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

  // First-deed Guddi onboarding. Spotlight targets for the tour, plus session-only guards —
  // whether the tour has been considered yet this session, and whether it's on screen now.
  final _deedSectionKey = GlobalKey();
  final _leaderboardKey = GlobalKey();
  bool _tourConsidered = false;
  bool _tourRunning = false;

  // Deeds are something you DO — new copy never says log / write / tell.
  static const _stepLogDeedEn = 'Did something kind today? Tap a circle to start.';
  static const _stepLogDeedUr = 'آج کوئی اچھا کام کریں، یہاں سے شروع کریں۔';
  static const _stepFirstDeedEn = 'Do your first good deed now. It takes 30 seconds!';
  static const _stepFirstDeedUr = 'اپنا پہلا اچھا کام ابھی کریں، صرف 30 سیکنڈ میں!';

  List<GuddiTourStep> _fullTour() => [
        const GuddiTourStep(
          image: 'assets/images/guddi/guddi_wink.png',
          en: "Hi! I'm Guddi. Every good deed you do matters to me.",
          ur: 'سلام! میں گڈی ہوں۔ آپ کا ہر اچھا کام میرے لیے اہم ہے۔',
        ),
        GuddiTourStep(target: _deedSectionKey, image: 'assets/images/guddi/guddi_point_phone.png', en: _stepLogDeedEn, ur: _stepLogDeedUr),
        GuddiTourStep(
          target: _leaderboardKey,
          image: 'assets/images/guddi/guddi_proud.png',
          en: 'Deeds earn points. Climb the leaderboard!',
          ur: 'ہر اچھے کام پر پوائنٹس۔ لیڈر بورڈ پر آگے بڑھیں!',
        ),
        const GuddiTourStep(image: 'assets/images/guddi/guddi_show_phone.png', en: _stepFirstDeedEn, ur: _stepFirstDeedUr),
      ];

  // Returning users who have never logged a deed — just the two steps that get them there.
  List<GuddiTourStep> _returningTour() => [
        GuddiTourStep(
          target: _deedSectionKey,
          image: 'assets/images/guddi/guddi_point_phone.png',
          leadEn: 'Welcome back! Your Guddi is still waiting for her first deed.',
          leadUr: 'خوش آمدید! آپ کی گڈی اب بھی آپ کے پہلے اچھے کام کا انتظار کر رہی ہے۔',
          en: _stepLogDeedEn,
          ur: _stepLogDeedUr,
        ),
        const GuddiTourStep(image: 'assets/images/guddi/guddi_show_phone.png', en: _stepFirstDeedEn, ur: _stepFirstDeedUr),
      ];

  // Decides once per session. Waits (by simply returning, to be called again on the next build)
  // until deed history has really loaded and any update popup is out of the way. Never shown
  // once the person has any deed; never again once they've skipped/finished it on this device.
  void _maybeStartTour() {
    if (_tourConsidered || !mounted) return;
    final state = context.read<AppState>();
    if (!state.deedHistoryLoaded || state.pendingUpdate != null) return;
    final uid = Supabase.instance.client.auth.currentUser?.id;
    if (uid == null) return;
    _tourConsidered = true;
    if (!state.needsFirstDeed) return;
    final full = state.justCompletedSetup;
    // Held as "running" while the local flag is read, so the bubble can't flash up first.
    setState(() => _tourRunning = true);
    OnboardingStore.isTourDone(uid).then((done) async {
      if (!mounted) return;
      if (done) {
        setState(() => _tourRunning = false);
        return;
      }
      await Future.delayed(const Duration(milliseconds: 600)); // let Home settle first
      if (!mounted) return;
      // Deed already logged meanwhile, or another screen is on top of Home — don't overlay it.
      // (Not marked done in the second case, so it's simply offered again next session.)
      if (!context.read<AppState>().needsFirstDeed || !(ModalRoute.of(context)?.isCurrent ?? true)) {
        setState(() => _tourRunning = false);
        return;
      }
      final result = await showGuddiTour(context, full ? _fullTour() : _returningTour());
      await OnboardingStore.markTourDone(uid);
      if (!mounted) return;
      setState(() => _tourRunning = false);
      if (result == GuddiTourResult.cta) {
        // Straight to their first deed; the reminder question comes after that deed instead.
        showFirstDeedPicker(context);
      } else {
        // End of the tour (Later/Skip) — the in-context moment to offer the daily reminder.
        await DailyReminder.maybeAsk(context, loggedToday: context.read<AppState>().loggedDeedToday);
      }
    });
  }

  // New — real, direct video open for a teaser's YouTube button, same extraction logic already
  // proven elsewhere (accepts either a full link or just the raw video id).
  Future<void> _openTeaserVideo(String raw) async {
    final videoId = extractYoutubeVideoId(raw);
    if (videoId == null) return;
    await launchUrl(Uri.parse('https://www.youtube.com/watch?v=$videoId'), mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final tier = getUserTier(state.user.badges.length);
    final lockedKeys = deedCatalog.keys.where((k) => state.cooldownRemaining(k) > Duration.zero).toList();
    final rank = _computeRank(state);
    if (!_tourConsidered) WidgetsBinding.instance.addPostFrameCallback((_) => _maybeStartTour());
    final showFirstDeedBubble = state.needsFirstDeed && _tourConsidered && !_tourRunning;

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
        child: RefreshIndicator(
          color: AppColors.gold,
          backgroundColor: AppColors.bg2,
          // Real gap addressed here — pull-to-refresh gives explicit, on-demand control over
          // seeing updates (an approved deed, a new notification), pairing with the
          // refresh-on-resume added in main.dart for the more automatic case.
          // Real gap fixed here: this only re-ran tryLoadExistingProfile(), which never touches
          // campaigns at all — loadRemoteConfig() (campaigns + Town Voice/app_config) was only
          // ever called once, at cold app start. So a campaign disabled by an admin would keep
          // showing indefinitely, surviving both pull-to-refresh and resume-from-background,
          // until a full app restart happened to re-trigger that one-time load. Both real data
          // sources refreshed together now, so "refresh" actually means what it says.
          onRefresh: () => Future.wait([
            context.read<AppState>().tryLoadExistingProfile(),
            context.read<AppState>().loadRemoteConfig(),
          ]),
          child: SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(), // required for RefreshIndicator's pull
      // gesture to work even when content is shorter than the screen and wouldn't otherwise scroll
      padding: const EdgeInsets.fromLTRB(18, 6, 18, 90),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Real gap fixed here — this was hardcoded "Good afternoon" verbatim from the
              // original HTML design, which never actually made it time-based either. Now
              // genuinely computed from the real clock. Also dropped "Day X" — that was always
              // the simDay testing counter, meaningless to a real user and now stuck showing
              // "Day 1" indefinitely since Simulator (the only thing that ever advanced it) is
              // hidden for the pilot.
              Text(_greeting(), style: AppFonts.plexMono(size: 10.5)),
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
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(state.user.name.split(' ').first, style: AppFonts.fraunces(size: 22, weight: FontWeight.w600)),
                if (state.membershipNumber != null) ...[
                  const SizedBox(height: 2),
                  Text(state.membershipNumber!, style: AppFonts.plexMono(size: 9)),
                ],
              ]),
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
          // Heading + rings wrapped together as one spotlight target for the Guddi tour.
          KeyedSubtree(
            key: _deedSectionKey,
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          // Wrap, not Row — on a narrow phone or the A+ text size the bubble drops under the
          // heading instead of overflowing.
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 6,
            children: [
              Text('Log a good deed', style: AppFonts.fraunces(size: 15, weight: FontWeight.w600)),
              if (showFirstDeedBubble) FirstDeedBubble(onTap: () => showFirstDeedPicker(context)),
            ],
          ),
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
                    _CategoryRing(icon: cat.icon, progress: pct, active: isActive, size: ringSize, greyedOut: state.isGlobalCooldownActive),
                    const SizedBox(height: 4),
                    Text(cat.short, style: AppFonts.plexMono(size: 9.5, weight: FontWeight.w600, color: AppColors.text)),
                  ]),
                );
              }).toList(),
            );
          }),
            ]),
          ),

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
          // Real fix here: resized to genuinely match Leaderboard's exact dimensions, using the
          // same shared BigTile widget instead of a differently-sized custom container —
          // customIcon used here since campaigns can have image/GIF icons via CampaignIcon, not
          // just a simple text emoji.
          ...state.remoteConfig.activeCampaigns.map((c) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Stack(children: [
                  BigTile(
                    customIcon: Container(
                      width: 60, height: 60,
                      decoration: BoxDecoration(shape: BoxShape.circle, color: AppColors.gold.withOpacity(0.18)),
                      alignment: Alignment.center,
                      child: CampaignIcon(icon: c.icon, size: 42),
                    ),
                    name: c.title,
                    description: c.description,
                    onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => CampaignDetailScreen(campaign: c))),
                  ),
                  // New — real tick mark once this campaign's Hall of Fame is genuinely
                  // claimed, per direction: an at-a-glance "you've finished this one" signal
                  // without needing to open it.
                  if (state.completedCampaignIds.contains(c.id))
                    Positioned(
                      top: 8, right: 8,
                      child: Container(
                        width: 22, height: 22,
                        decoration: BoxDecoration(shape: BoxShape.circle, color: AppColors.gold, boxShadow: [BoxShadow(color: AppColors.gold.withOpacity(0.5), blurRadius: 6)]),
                        alignment: Alignment.center,
                        child: const Icon(Icons.check, size: 14, color: AppColors.inkOnGold),
                      ),
                    ),
                ]),
              )),
          // New — real, per-campaign teaser cards, per direction: same exact BigTile design as
          // the real campaign card, just non-tappable, for building excitement before a
          // campaign is actually playable. Only shows for a campaign that hasn't gone active
          // yet — the real card takes over automatically once it does.
          ...state.remoteConfig.teaserCampaigns.map((c) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Stack(children: [
                  BigTile(
                    customIcon: Container(
                      width: 60, height: 60,
                      decoration: BoxDecoration(shape: BoxShape.circle, color: AppColors.gold.withOpacity(0.18)),
                      alignment: Alignment.center,
                      child: CampaignIcon(icon: c.icon, size: 42),
                    ),
                    name: c.title,
                    description: c.teaserDescription ?? 'Something is coming.',
                    onTap: null,
                  ),
                  Positioned(
                    top: 8, right: 8,
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      // New — real YouTube button next to "Coming Soon", per direction: only
                      // shown once a real video link actually exists in the database, opens it
                      // directly on tap. Same exact padding and border radius as the pill next
                      // to it, so both share identical height and a consistent size, rather
                      // than the icon-only button ending up a mismatched shape.
                      if (c.youtubeVideoId != null && c.youtubeVideoId!.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: GestureDetector(
                            onTap: () => _openTeaserVideo(c.youtubeVideoId!),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(color: const Color(0xFFFF0000), borderRadius: BorderRadius.circular(100)),
                              child: const Icon(Icons.play_arrow_rounded, size: 12, color: Colors.white),
                            ),
                          ),
                        ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(color: AppColors.bg1.withOpacity(0.6), borderRadius: BorderRadius.circular(100)),
                        child: Text('COMING SOON', style: AppFonts.plexMono(size: 8, weight: FontWeight.w700, color: AppColors.gold)),
                      ),
                    ]),
                  ),
                ]),
              )),
          // "Ranked #N" comes from AppState.myRank — real leaderboard data only (no mock rivals).
          KeyedSubtree(
            key: _leaderboardKey, // Guddi tour spotlight target
            child: BigTile(
              icon: '👑',
              name: 'Leaderboard',
              // Neutral until real leaderboard data has loaded — never a made-up "#1".
              description: state.rankDataReady ? 'You\'re ranked #$rank overall' : 'See where you rank',
              onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const LeaderboardScreen())),
            ),
          ),
          const SizedBox(height: 10),
          // Profile tile removed — it's a real bottom-nav tab now, not reached via a Home tile
          // anymore. A tile here would just be a redundant, confusing second path to the same
          // place. ProfileScreen itself untouched, still the real destination, just reached
          // differently now (see main_tab_screen.dart).
          //
          // Badges tile also moved to Profile now, alongside Limited Edition Items and Skins —
          // grouping achievement/collection content together in one place, per direction.
          // BadgesScreen itself untouched.
          BigTile(
            icon: '🎙️',
            name: 'Town Voice',
            // Now dynamic, matching whatever the page itself actually shows — real leader name
            // when active, "Launching soon" when not, driven by the same app_config flag either
            // way rather than a hardcoded string that could drift out of sync with the page again.
            description: state.remoteConfig.townVoice.active ? '${state.townVoiceLeader.$1} is leading this week' : 'Launching soon',
            onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const TownVoiceScreen())),
          ),
          // Redeem tile removed for the pilot, per the current direction — no redemption system
          // exists yet, and a hardcoded "0 pts" tile that always leads to a toast wasn't adding
          // anything. Easy to bring back once real redemption exists.
        ],
      ),
      ),
      ),
      ),
    );
  }

  int _computeRank(AppState state) => state.myRank; // real leaderboard data only, see AppState.myRank

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 5) return 'Good night';
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    if (hour < 21) return 'Good evening';
    return 'Good night';
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
//
// BigTile itself extracted to widgets/big_tile.dart so Profile can use the identical styling —
// this comment block stays here since it documents Home's own tile usage/decisions above.

class _CategoryRing extends StatelessWidget {
  final String icon;
  final double progress; // 0..1
  final bool active;
  final double size;
  final bool greyedOut; // new — true while the global 15-min cooldown is active
  const _CategoryRing({required this.icon, required this.progress, required this.active, required this.size, this.greyedOut = false});
  @override
  Widget build(BuildContext context) {
    final innerSize = size * 0.84;
    return SizedBox(
      width: size, height: size,
      child: Stack(alignment: Alignment.center, children: [
        CustomPaint(size: Size(size, size), painter: _RingPainter(progress: progress, greyedOut: greyedOut)),
        Container(
          width: innerSize, height: innerSize,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            // Deliberately desaturated while the global cooldown is active — a distinct,
            // unambiguous "everything is locked right now" state, rather than looking like the
            // normal gold-tinted ring just happened to fill up.
            gradient: greyedOut
                ? LinearGradient(colors: [AppColors.textSoft.withOpacity(0.08), AppColors.bg2.withOpacity(0.4)])
                : LinearGradient(colors: [AppColors.gold.withOpacity(0.12), AppColors.oliveCard]),
            border: Border.all(color: greyedOut ? AppColors.textSoft.withOpacity(0.3) : (active ? AppColors.gold : AppColors.bg2), width: 2),
          ),
          alignment: Alignment.center,
          child: Opacity(
            opacity: greyedOut ? 0.4 : 1.0,
            child: Text(icon, style: TextStyle(fontSize: size * 0.37)),
          ),
        ),
      ]),
    );
  }
}

class _RingPainter extends CustomPainter {
  final double progress;
  final bool greyedOut;
  _RingPainter({required this.progress, this.greyedOut = false});
  @override
  void paint(Canvas canvas, Size size) {
    // Real fix here: during global cooldown, every category's progress becomes 1.0
    // simultaneously (everything is locked at once), so a full ring was being drawn around every
    // icon on top of the already-desaturated inner circle — two overlapping "locked" treatments
    // at once, which is exactly the uneven look. The inner circle alone communicates this
    // clearly; the ring is redundant noise specifically in this state.
    if (progress <= 0 || greyedOut) return;
    final paint = Paint()
      ..color = greyedOut ? AppColors.textSoft.withOpacity(0.35) : AppColors.gold
      ..strokeWidth = 4
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.butt;
    final rect = Rect.fromLTWH(2, 2, size.width - 4, size.height - 4);
    canvas.drawArc(rect, -3.14159 / 2, 2 * 3.14159 * progress, false, paint);
  }

  @override
  bool shouldRepaint(covariant _RingPainter oldDelegate) => oldDelegate.progress != progress || oldDelegate.greyedOut != greyedOut;
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
