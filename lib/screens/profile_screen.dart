import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../state/app_state.dart';
import '../data/tiers.dart';
import '../widgets/edit_profile_sheet.dart';

// Simplified for the pilot — editing moved entirely to EditProfileSheet (reachable from here AND
// the Side Sheet, one shared popup instead of duplicating fields/validation in two places).
// Favorite Friends/Group sections removed for now — Friends/Groups are hidden pilot-wide as
// MVP2 scope, so a "no friends yet, add one" section referencing a hidden feature would be
// confusing rather than helpful. Nothing deleted, just not shown — trivial to bring back.
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  void _openEditSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const EditProfileSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final user = state.user;
    final tier = getUserTier(user.badges.length);
    final rank = _computeRank(state);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(18, 10, 18, 90),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
              const SizedBox(height: 4),
              Text('#$rank this week · ${user.points} pts', style: AppFonts.plexMono(size: 11, color: AppColors.textSoft)),
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
          if (user.phone != null || user.email != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: AppColors.oliveCard, borderRadius: BorderRadius.circular(14)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                if (user.phone != null) ...[
                  Text('Phone', style: AppFonts.plexMono(size: 10, color: AppColors.textSoft)),
                  Text(user.phone!, style: AppFonts.inter(size: 13)),
                ],
                if (user.phone != null && user.email != null) const SizedBox(height: 10),
                if (user.email != null) ...[
                  Text('Email', style: AppFonts.plexMono(size: 10, color: AppColors.textSoft)),
                  Text(user.email!, style: AppFonts.inter(size: 13)),
                ],
              ]),
            ),
        ],
      ),
    );
  }

  int _computeRank(AppState state) {
    final all = [...otherUsers.map((u) => u.points), state.user.points]..sort((a, b) => b.compareTo(a));
    return all.indexOf(state.user.points) + 1;
  }
}
