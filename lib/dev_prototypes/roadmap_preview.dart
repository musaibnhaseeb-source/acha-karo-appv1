import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../data/remote_config.dart';
import '../data/roadmap_data.dart';
import '../screens/roadmap_screen.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';

// DEV-ONLY preview of the roadmap road with Guddi — SAMPLE stops, no live data:
//   flutter build web -t lib/dev_prototypes/roadmap_preview.dart   ?done=5&claimed=1
// Supabase points at a dead localhost address, so nothing here can reach the live database.
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(url: 'http://127.0.0.1:9', publishableKey: 'offline-preview');
  runApp(const _App());
}

class _App extends StatelessWidget {
  const _App();
  @override
  Widget build(BuildContext context) {
    final q = Uri.base.queryParameters;
    final done = int.tryParse(q['done'] ?? '') ?? 5;
    final claimedCount = int.tryParse(q['claimed'] ?? '') ?? 1;
    const prize = RoadmapPrize(name: 'Sample prize', icon: '🎁');
    const stops = [
      RoadmapStop(id: 's1', threshold: 3, label: 'Stop 1', totalBoxes: 9, winningBoxes: 3, prize: prize),
      RoadmapStop(id: 's2', threshold: 7, label: 'Stop 2', totalBoxes: 9, winningBoxes: 3, prize: prize),
      RoadmapStop(id: 's3', threshold: 12, label: 'Stop 3', totalBoxes: 9, winningBoxes: 3, prize: prize),
    ];
    const campaign = Campaign(id: 'preview', title: 'Sample campaign', description: '', icon: '🚚', active: true);
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      home: Scaffold(
        backgroundColor: const Color(0xFF222222),
        body: Align(
          alignment: Alignment.topLeft,
          child: Container(
            width: 390, height: 844, margin: const EdgeInsets.all(12),
            decoration: const BoxDecoration(gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [AppColors.bg2, AppColors.bg1])),
            child: ChangeNotifierProvider<AppState>(
              create: (_) => AppState(),
              child: Column(children: [
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text('SAMPLE · $done / 12 deeds', style: AppFonts.plexMono(size: 11)),
                ),
                Expanded(
                  child: RoadmapRoadView(
                    campaign: campaign,
                    stops: stops,
                    deedsDone: done,
                    claimedStopIds: {for (var i = 0; i < claimedCount; i++) stops[i].id},
                    onStopTap: (_) {},
                  ),
                ),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}
