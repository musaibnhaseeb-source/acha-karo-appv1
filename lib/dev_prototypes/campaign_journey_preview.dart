import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../data/remote_config.dart';
import '../screens/campaign_detail_screen.dart';
import '../screens/campaign_journey_screen.dart';
import '../state/app_state.dart';
import '../uat/uat_journey_repository.dart';

// DEV-ONLY preview of the production CampaignJourneyScreen (its real AppBar, task list, skin button)
// on the UAT seeded repository. Its own entry point, never imported by the app:
//   flutter run -d chrome -t lib/dev_prototypes/campaign_journey_preview.dart
// Supabase points at a dead localhost address, so nothing here can touch the live database.
// ?user=uat-user-at-stop picks the seeded user; ?campaign=<index> picks the campaign.

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(url: 'http://127.0.0.1:9', publishableKey: 'offline-preview');
  final repo = UatJourneyRepository();
  final user = Uri.base.queryParameters['user'];
  if (user != null) repo.switchUser(user);
  var campaign = repo.campaigns[int.tryParse(Uri.base.queryParameters['campaign'] ?? '') ?? 0].campaign;
  // ?icon=directions_bike previews a stored value that is not an emoji (it must still draw as an icon).
  final icon = Uri.base.queryParameters['icon'];
  if (icon != null) campaign = Campaign(id: campaign.id, title: campaign.title, description: campaign.description, icon: icon, active: true);
  runApp(ChangeNotifierProvider<AppState>(
    create: (_) => AppState(),
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(useMaterial3: true, brightness: Brightness.dark),
      // ?screen=detail shows the campaign's info page, where the campaign icon is drawn large.
      home: Uri.base.queryParameters['screen'] == 'detail'
          ? CampaignDetailScreen(campaign: campaign)
          : CampaignJourneyScreen(campaign: campaign, debugRepository: repo),
    ),
  ));
}
