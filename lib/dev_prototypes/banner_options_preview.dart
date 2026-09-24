import 'package:flutter/material.dart';
import '../data/badges.dart';
import '../data/guddi_content.dart';
import '../data/tiers.dart';
import '../theme/app_theme.dart';
import '../utils/deed_streak.dart';
import '../widgets/guddi_home.dart';
import 'banner_options.dart';

// DEV-ONLY preview of the banner options, SAMPLE data, no network/DB:
//   flutter build web -t lib/dev_prototypes/banner_options_preview.dart
//   ?opt=homeA|homeB|profA|profB  &h=9  &badges=5
void main() => runApp(const _App());

class _App extends StatelessWidget {
  const _App();
  @override
  Widget build(BuildContext context) {
    final q = Uri.base.queryParameters;
    final opt = q['opt'] ?? 'homeA';
    final hour = int.tryParse(q['h'] ?? '') ?? 9;
    final badges = int.tryParse(q['badges'] ?? '') ?? 5;
    final earned = [for (var i = 0; i < badges && i < badgeDefs.length; i++) badgeDefs[(i * 7) % badgeDefs.length].id];
    final base = DateTime.now();
    final now = DateTime(base.year, base.month, base.day, hour, 5);
    final today = dateOnly(now);
    final active = {today.subtract(const Duration(days: 1)), today.subtract(const Duration(days: 2))};
    final mood = pickGuddiHomeMood(now: now, historyLoaded: true, needsFirstDeed: false, doneToday: false, rejectedTodayOnly: false, streak: 2, daysSinceLast: 1);
    final tier = getUserTier(badges);

    Widget topBar(String greeting) => Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(greeting, style: AppFonts.plexMono(size: 10.5)),
          Container(
            width: 32, height: 32,
            decoration: BoxDecoration(shape: BoxShape.circle, color: AppColors.oliveCardStrong, border: Border.all(color: const Color(0x29F6F5EC))),
            child: const Icon(Icons.menu, size: 16, color: AppColors.text),
          ),
        ]);
    Widget points() => Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, crossAxisAlignment: CrossAxisAlignment.end, children: [
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('TOTAL POINTS', style: AppFonts.plexMono(size: 9)),
            Text('120', style: AppFonts.fraunces(size: 28, weight: FontWeight.w700, color: AppColors.gold)),
          ]),
          Row(children: [Text(tier.icon, style: const TextStyle(fontSize: 22)), const SizedBox(width: 4), Text(tier.name, style: AppFonts.nastaliq(size: 22, color: AppColors.gold))]),
        ]);
    final idea = achaKaamIdeas[3];
    final week = WeekRowCard(weekDays: currentWeekDays(now), activeDays: active, today: today, streak: 2);
    final name = Text('Ayesha', style: AppFonts.fraunces(size: 22, weight: FontWeight.w600));

    final List<Widget> body = switch (opt) {
      'homeB' => [
          topBar('Good morning'), const SizedBox(height: 12),
          GuddiHomeHeader(mood: mood, nameBlock: name), const SizedBox(height: 8),
          points(), const SizedBox(height: 12),
          HomeProgressRailB(weekRow: week, badgeCount: badges), const SizedBox(height: 10),
          StoryIdeaCardB(idea: idea, onDo: () {}),
        ],
      'profA' || 'profB' => [
          topBar('Good morning'), const SizedBox(height: 16),
          Center(
            child: Column(children: [
              Container(
                width: 72, height: 72,
                decoration: BoxDecoration(shape: BoxShape.circle, color: AppColors.oliveCardStrong, border: Border.all(color: AppColors.gold.withOpacity(0.4), width: 2)),
                alignment: Alignment.center,
                child: const Text('🙂', style: TextStyle(fontSize: 30)),
              ),
              const SizedBox(height: 8),
              Text('Ayesha Khan', style: AppFonts.fraunces(size: 20, weight: FontWeight.w600)),
              Text('#12 overall · 120 pts', style: AppFonts.plexMono(size: 11)),
            ]),
          ),
          const SizedBox(height: 16),
          opt == 'profA' ? ProfileTierCardA(badgeCount: badges, earnedIds: earned) : ProfileTierBannerB(badgeCount: badges, earnedIds: earned),
        ],
      _ => [
          topBar('Good morning'), const SizedBox(height: 10),
          name, const SizedBox(height: 4),
          HomeBannerA(mood: mood, hour: hour, onAct: () {}), const SizedBox(height: 12),
          points(), const SizedBox(height: 10),
          HomeProgressStripA(streak: 2, doneToday: false, badgeCount: badges), const SizedBox(height: 10),
          StoryIdeaCardB(idea: idea, onDo: () {}),
        ],
    };

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      home: Scaffold(
        backgroundColor: const Color(0xFF222222),
        body: Align(
          alignment: Alignment.topLeft,
          child: Container(
            width: 390, height: 844, margin: const EdgeInsets.all(12), color: AppColors.bg1,
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 24),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: body),
            ),
          ),
        ),
      ),
    );
  }
}
