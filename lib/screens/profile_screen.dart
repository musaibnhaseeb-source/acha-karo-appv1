import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../state/app_state.dart';
import '../data/tiers.dart';
import '../data/badges.dart';
import '../widgets/edit_profile_sheet.dart';
import '../widgets/home_side_sheet.dart';
import '../widgets/animated_wallpaper.dart';
import '../widgets/big_tile.dart';
import 'limited_edition_screen.dart';
import 'skins_screen.dart';
import 'invites_screen.dart';
import 'badges_screen.dart';

// Real functionality now — brought back per direction, using the same header treatment (real
// time-based greeting, burger menu opening the same Side Sheet) and background wrapping as
// Home, for consistency between the two. Was previously a bare SingleChildScrollView with none
// of that, since it predates the Home header pattern being established.
//
// Simplified for the pilot — editing moved entirely to EditProfileSheet (reachable from here AND
// the Side Sheet, one shared popup instead of duplicating fields/validation in two places).
// Favorite Friends/Group sections removed for now — Friends/Groups are hidden pilot-wide as
// MVP2 scope, so a "no friends yet, add one" section referencing a hidden feature would be
// confusing rather than helpful. Nothing deleted, just not shown — trivial to bring back.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();

  void _openEditSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const EditProfileSheet(),
    );
  }

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 5) return 'Good night';
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    if (hour < 21) return 'Good evening';
    return 'Good night';
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final user = state.user;
    final tier = getUserTier(user.badges.length);
    final rank = state.myRank;

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: Colors.transparent,
      endDrawer: const HomeSideSheet(),
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
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(18, 10, 18, 90),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(_greeting(), style: AppFonts.plexMono(size: 10.5)),
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
                  const SizedBox(height: 20),
                  Center(
                    child: Column(children: [
                      Container(
                        width: 84, height: 84,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.oliveCardStrong,
                          border: Border.all(color: AppColors.gold.withOpacity(0.4), width: 2),
                          image: user.avatarFile != null ? DecorationImage(image: FileImage(user.avatarFile!), fit: BoxFit.cover) : null,
                        ),
                        alignment: Alignment.center,
                        child: user.avatarFile == null ? const Text('🙂', style: TextStyle(fontSize: 34)) : null,
                      ),
                      const SizedBox(height: 10),
                      Text(user.name, style: AppFonts.fraunces(size: 20, weight: FontWeight.w600)),
                      if (state.membershipNumber != null) ...[
                        const SizedBox(height: 2),
                        Text(state.membershipNumber!, style: AppFonts.plexMono(size: 9, color: AppColors.textSoft)),
                      ],
                      const SizedBox(height: 4),
                      // Real bug fixed here: this said "this week" but the rank behind it
                      // (myRank) is genuinely all-time, not a weekly figure — a real, separate
                      // inconsistency found while bringing this screen back, not something new
                      // introduced. Matches Leaderboard's own "overall" labeling now.
                      Text('#$rank overall · ${user.points} pts', style: AppFonts.plexMono(size: 11, color: AppColors.textSoft)),
                      const SizedBox(height: 6),
                      Row(mainAxisSize: MainAxisSize.min, children: [
                        Text(tier.icon, style: const TextStyle(fontSize: 16)),
                        const SizedBox(width: 4),
                        Text(tier.name, style: AppFonts.nastaliq(size: 16, color: AppColors.gold)),
                      ]),
                      const SizedBox(height: 14),
                      GestureDetector(
                        onTap: () => _openEditSheet(context),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
                          decoration: BoxDecoration(color: AppColors.oliveCard, borderRadius: BorderRadius.circular(100), border: Border.all(color: const Color(0x29F6F5EC))),
                          child: Text('✏️ Edit profile', style: AppFonts.inter(size: 12, weight: FontWeight.w600)),
                        ),
                      ),
                    ]),
                  ),
                  const SizedBox(height: 24),
                  // Resized to match Home's tile dimensions, per direction — Badges, Limited
                  // Edition, and Skins now grouped together here as a real trio, all using the
                  // same shared BigTile widget Home uses, for genuine visual consistency rather
                  // than a differently-sized custom container.
                  BigTile(
                    icon: '🏅',
                    name: 'Badges',
                    description: '${user.badges.length} of ${badgeDefs.length} badges earned',
                    onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const BadgesScreen())),
                  ),
                  const SizedBox(height: 10),
                  BigTile(
                    icon: '🏆',
                    name: 'Limited Edition Items',
                    description: 'Medals and stickers from completed roadmaps',
                    onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const LimitedEditionScreen())),
                  ),
                  const SizedBox(height: 10),
                  BigTile(
                    icon: '🎨',
                    name: 'Skins',
                    description: 'Vehicle skins earned from campaigns',
                    onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SkinsScreen())),
                  ),
                  const SizedBox(height: 10),
                  // New — real entry point to Invites, per direction.
                  BigTile(
                    icon: '✉️',
                    name: 'Invites',
                    description: 'KaroCast and co-create opportunities',
                    onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const InvitesScreen())),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
