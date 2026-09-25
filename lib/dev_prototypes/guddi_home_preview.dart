import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../data/tiers.dart';
import '../screens/home_screen.dart';
import '../screens/profile_screen.dart';
import '../data/badges.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/daily_milestone_animation.dart';
import '../widgets/guddi_home.dart';
import '../widgets/thank_you_animation.dart';
import '../widgets/tier_up_animation.dart';

// DEV-ONLY preview of Guddi on Home — its own entry point, never imported by the app:
//   flutter run -d chrome -t lib/dev_prototypes/guddi_home_preview.dart
// Renders the real HomeScreen with SAMPLE deeds and a chosen time of day, plus buttons for the
// celebration animations. Supabase points at a dead localhost address, so nothing here can
// touch the live database.

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(url: 'http://127.0.0.1:9', publishableKey: 'offline-preview');
  runApp(const _PreviewApp());
}

class _PreviewAppState extends AppState {
  _PreviewAppState({required DateTime now, required bool deedToday, required int priorDays, int gapDays = 1}) {
    user.name = 'Ayesha Preview';
    user.points = 40 + 10 * priorDays;
    final n = int.tryParse(Uri.base.queryParameters['badges'] ?? '') ?? 5;
    user.badges = [for (var i = 0; i < n && i < badgeDefs.length; i++) badgeDefs[(i * 7) % badgeDefs.length].id];
    deedHistoryLoaded = true;
    final day = DateTime(now.year, now.month, now.day, 12);
    deedsLog = [
      for (var i = gapDays; i < gapDays + priorDays; i++)
        DeedLogEntry(id: 'p$i', type: 'water', points: 10, day: 0, createdAt: day.subtract(Duration(days: i)), status: 'approved'),
      if (deedToday) DeedLogEntry(id: 'today', type: 'litter', points: 15, day: 0, createdAt: now.subtract(const Duration(minutes: 90)), status: 'approved'),
    ];
  }
}

class _PreviewApp extends StatefulWidget {
  const _PreviewApp();
  @override
  State<_PreviewApp> createState() => _PreviewAppAppState();
}

class _PreviewAppAppState extends State<_PreviewApp> {
  // Starting scenario can come from the URL (?h=22&deed=1&prior=4&away=0&anim=tier) so
  // screenshots can be taken headlessly.
  static final _q = Uri.base.queryParameters;
  int hour = int.tryParse(_q['h'] ?? '') ?? 9;
  bool deedToday = _q['deed'] == '1';
  int priorDays = int.tryParse(_q['prior'] ?? '') ?? 2; // streak days before today
  bool away = _q['away'] == '1'; // last deed 5 days ago
  final _homeNav = GlobalKey<NavigatorState>();

  @override
  void initState() {
    super.initState();
    final anim = _q['anim'];
    if (anim != null) {
      Future.delayed(const Duration(milliseconds: 1500), () {
        final w = switch (anim) {
          'thanks' => ThankYouAnimation(wasFlagged: false, onDone: () {}),
          'm3' => DailyMilestoneAnimation(threshold: 3, gender: 'female', onDone: () {}),
          'm5' => DailyMilestoneAnimation(threshold: 5, gender: 'female', onDone: () {}),
          'top' => TierUpAnimation(tier: tierDefs.last, onDone: () {}),
          _ => TierUpAnimation(tier: tierDefs[2], onDone: () {}),
        };
        _homeNav.currentState?.overlay?.insert(OverlayEntry(builder: (_) => Positioned.fill(child: w)));
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final base = DateTime.now();
    final now = DateTime(base.year, base.month, base.day, hour, 5);
    guddiClock = () => now;
    final state = _PreviewAppState(now: now, deedToday: deedToday, priorDays: away ? 1 : priorDays, gapDays: away ? 5 : 1);
    Widget chip(String label, bool on, VoidCallback tap) => Padding(
          padding: const EdgeInsets.all(3),
          child: ChoiceChip(label: Text(label), selected: on, onSelected: (_) => setState(tap)),
        );
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      home: Scaffold(
        backgroundColor: const Color(0xFF222222),
        body: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(
            width: 260,
            child: ListView(padding: const EdgeInsets.all(12), children: [
              const Text('SAMPLE DATA — dev preview', style: TextStyle(color: Colors.white70, fontSize: 11)),
              const SizedBox(height: 8),
              Wrap(children: [
                for (final (l, h) in const [('Morning 9', 9), ('Day 14', 14), ('Evening 19', 19), ('Night 22', 22), ('Late 2am', 2)])
                  chip(l, hour == h, () => hour = h),
              ]),
              Wrap(children: [chip('No deed today', !deedToday, () => deedToday = false), chip('Deed today', deedToday, () => deedToday = true)]),
              Wrap(children: [
                for (final d in const [0, 2, 4]) chip('$d prior days', !away && priorDays == d, () { away = false; priorDays = d; }),
                chip('Away 5 days', away, () => away = true),
              ]),
              const Divider(),
              Builder(builder: (c) => Wrap(children: [
                    for (final (l, w) in [
                      ('Thank-you', (VoidCallback d) => ThankYouAnimation(wasFlagged: false, onDone: d)),
                      ('Milestone 3', (VoidCallback d) => DailyMilestoneAnimation(threshold: 3, gender: 'female', onDone: d)),
                      ('Milestone 5', (VoidCallback d) => DailyMilestoneAnimation(threshold: 5, gender: 'female', onDone: d)),
                      ('Tier up', (VoidCallback d) => TierUpAnimation(tier: tierDefs[2], onDone: d)),
                      ('Top tier', (VoidCallback d) => TierUpAnimation(tier: tierDefs.last, onDone: d)),
                    ])
                      Padding(
                        padding: const EdgeInsets.all(3),
                        child: OutlinedButton(
                          onPressed: () {
                            final overlay = _homeNav.currentState!.overlay!;
                            late OverlayEntry e;
                            e = OverlayEntry(builder: (_) => Positioned.fill(child: w(() => e.remove())));
                            overlay.insert(e);
                          },
                          child: Text(l),
                        ),
                      ),
                  ])),
            ]),
          ),
          // Phone-sized frame with the real HomeScreen.
          Container(
            width: 390, height: 844,
            margin: const EdgeInsets.all(12),
            color: AppColors.bg1,
            child: ChangeNotifierProvider<AppState>.value(
              key: ValueKey('$hour$deedToday$priorDays$away'),
              value: state,
              child: Navigator(key: _homeNav, onGenerateRoute: (_) => MaterialPageRoute(builder: (_) => Uri.base.queryParameters['screen'] == 'profile' ? const ProfileScreen() : const HomeScreen())),
            ),
          ),
        ]),
      ),
    );
  }
}
