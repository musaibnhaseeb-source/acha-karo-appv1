import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../theme/app_theme.dart';
import '../state/app_state.dart';
import '../widgets/animated_wallpaper.dart';
import '../data/deed_catalog.dart';
import '../data/tiers.dart';
import '../widgets/thank_you_animation.dart';
import '../widgets/daily_milestone_animation.dart';
import '../widgets/tier_up_animation.dart';
import '../screens/town_voice_screen.dart';

// Testing-only screen — lets every celebration animation and the moderator approve/reject flow
// be triggered manually, without needing a real photo/GPS submission each time. Once the
// moderator screen is built for real and connected to Supabase, this can either go away or stay
// as a dev tool — that's a decision for later, not now.
class SimulatorScreen extends StatefulWidget {
  const SimulatorScreen({super.key});
  @override
  State<SimulatorScreen> createState() => _SimulatorScreenState();
}

class _SimulatorScreenState extends State<SimulatorScreen> {
  String? _connectionResult;
  bool _testingConnection = false;

  @override
  void initState() {
    super.initState();
    // Loads the real cross-session queue on open — was previously only ever showing whatever
    // had been added within the current app session.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AppState>().loadModerationQueue();
    });
  }

  Future<void> _testSupabaseConnection() async {
    setState(() {
      _testingConnection = true;
      _connectionResult = null;
    });
    try {
      // Querying a table that (almost certainly) doesn't exist yet on purpose — a Postgres
      // "relation does not exist" error actually PROVES the connection worked: it means we
      // reached your real database and got a real, structured answer back. Only a network-level
      // failure (timeout, DNS, wrong URL) means the connection itself is broken.
      await Supabase.instance.client.from('_connection_test').select().limit(1);
      setState(() => _connectionResult = '✅ Connected — reached your Supabase project.');
    } catch (e) {
      final msg = e.toString();
      if (msg.contains('relation') || msg.contains('does not exist') || msg.contains('PGRST')) {
        setState(() => _connectionResult = '✅ Connected — reached your Supabase project (no tables yet, which is expected).');
      } else {
        setState(() => _connectionResult = '❌ Could not connect. Double check the URL and Publishable key in lib/supabase_config.dart.\n\nDetails: $msg');
      }
    } finally {
      setState(() => _testingConnection = false);
    }
  }

  void _playOverlay(Widget Function(VoidCallback onDone) builder) {
    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (ctx) => Positioned.fill(child: builder(() => entry.remove())),
    );
    Overlay.of(context).insert(entry);
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(icon: const Icon(Icons.arrow_back, color: AppColors.text), onPressed: () => Navigator.of(context).pop()),
        title: Text('Simulator', style: AppFonts.inter(size: 14, weight: FontWeight.w600)),
        centerTitle: true,
      ),
      // Same background-fill fix as the other screens in this batch, for consistency — this
      // screen is unreachable in the current build (removed from the Side Sheet), but keeping
      // it correct in case it's ever re-enabled for testing later.
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
            child: AnimatedWallpaper(gradientColors: wallpaperSwatches[context.watch<AppState>().wallpaperSwatchIndex]),
          ),
        SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(18, 10, 18, 30),
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: AppColors.rust.withOpacity(0.12), borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.rust.withOpacity(0.3))),
                child: Text(
                  'Testing only — not part of the real app experience. Triggers animations and moderator actions directly, bypassing the real submission flow.',
                  style: AppFonts.inter(size: 11, color: AppColors.textSoft, height: 1.4),
                ),
              ),
              const SizedBox(height: 20),
              Text('Supabase Connection', style: AppFonts.fraunces(size: 16, weight: FontWeight.w600)),
              const SizedBox(height: 4),
              Text('Tests only whether the app can reach your project — not any real data yet.', style: AppFonts.inter(size: 11, color: AppColors.textSoft)),
              const SizedBox(height: 10),
              _SimButton(
                label: _testingConnection ? 'Testing…' : '🔌 Test connection',
                onTap: _testingConnection ? () {} : _testSupabaseConnection,
              ),
              if (_connectionResult != null)
                Container(
                  margin: const EdgeInsets.only(top: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: AppColors.oliveCard, borderRadius: BorderRadius.circular(12)),
                  child: Text(_connectionResult!, style: AppFonts.inter(size: 11.5, color: AppColors.text, height: 1.4)),
                ),

              const SizedBox(height: 20),
              Text('Animations', style: AppFonts.fraunces(size: 16, weight: FontWeight.w600)),
              const SizedBox(height: 10),
              _SimButton(label: '🎉 Thank-you (approved)', onTap: () => _playOverlay((onDone) => ThankYouAnimation(wasFlagged: false, onDone: onDone))),
              _SimButton(label: '🎉 Thank-you (sent for review)', onTap: () => _playOverlay((onDone) => ThankYouAnimation(wasFlagged: true, onDone: onDone))),
              _SimButton(label: '🎊 Daily milestone — 3 deeds (واہ جی واہ)', onTap: () => _playOverlay((onDone) => DailyMilestoneAnimation(threshold: 3, gender: state.user.gender, onDone: onDone))),
              _SimButton(label: '🎊 Daily milestone — 5 deeds (او خیر)', onTap: () => _playOverlay((onDone) => DailyMilestoneAnimation(threshold: 5, gender: state.user.gender, onDone: onDone))),
              _SimButton(label: '🎊 Daily milestone — 7 deeds (شہزادہ/شہزادی)', onTap: () => _playOverlay((onDone) => DailyMilestoneAnimation(threshold: 7, gender: state.user.gender, onDone: onDone))),
              ...tierDefs.map((t) => _SimButton(label: '👑 Tier up — ${t.icon} ${t.name}', onTap: () => _playOverlay((onDone) => TierUpAnimation(tier: t, onDone: onDone)))),

              const SizedBox(height: 24),
              Text('Time', style: AppFonts.fraunces(size: 16, weight: FontWeight.w600)),
              const SizedBox(height: 4),
              Text('Day ${state.simDay} right now. Advancing clears all cooldowns, same as a real day passing would.', style: AppFonts.inter(size: 11, color: AppColors.textSoft)),
              const SizedBox(height: 10),
              _SimButton(label: '⏭️ Simulate next day', onTap: () => context.read<AppState>().advanceDay(1)),
              _SimButton(label: '⏭️⏭️ Simulate next week', onTap: () => context.read<AppState>().advanceDay(7)),

              const SizedBox(height: 24),
              Text('Campaigns & Town Voice', style: AppFonts.fraunces(size: 16, weight: FontWeight.w600)),
              const SizedBox(height: 4),
              Text('Both load from the same app_config/campaigns tables in one call — this refreshes both together, no need for two separate buttons.', style: AppFonts.inter(size: 11, color: AppColors.textSoft)),
              const SizedBox(height: 10),
              _SimButton(
                label: '🔄 Refresh campaigns & Town Voice',
                onTap: () async {
                  await context.read<AppState>().loadRemoteConfig();
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Refreshed from Supabase.')));
                  }
                },
              ),
              const SizedBox(height: 14),
              // Live Town Voice values, so a database change is actually verifiable here the
              // same way campaign toggles already show their current state — previously there
              // was no way to visually confirm Town Voice's config had actually updated.
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: AppColors.oliveCard, borderRadius: BorderRadius.circular(12)),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('🎙️ Town Voice — current values', style: AppFonts.inter(size: 11.5, weight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  Text('Day: ${state.remoteConfig.townVoice.dayLabel}', style: AppFonts.plexMono(size: 10.5, color: AppColors.textSoft)),
                  Text('Time: ${state.remoteConfig.townVoice.timeLabel}', style: AppFonts.plexMono(size: 10.5, color: AppColors.textSoft)),
                  Text('Length: ${state.remoteConfig.townVoice.durationLabel}', style: AppFonts.plexMono(size: 10.5, color: AppColors.textSoft)),
                  Text('Stream: ${state.remoteConfig.townVoice.streamUrl}', style: AppFonts.plexMono(size: 10.5, color: AppColors.textSoft)),
                ]),
              ),
              const SizedBox(height: 14),
              _SimButton(
                label: '🎙️ Open Town Voice screen',
                onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const TownVoiceScreen())),
              ),
              const SizedBox(height: 14),
              ...state.remoteConfig.campaigns.map((c) => _SimButton(
                    // A button label is plain text — can't embed an image here, so a GIF/image
                    // URL icon is simply left out of the label rather than showing the raw URL.
                    label: '${c.active ? '✓' : '○'} ${c.icon.startsWith('http') ? '' : '${c.icon} '}${c.title} — tap to ${c.active ? 'deactivate' : 'activate'}',
                    onTap: () => context.read<AppState>().toggleDemoCampaignActive(c.id),
                  )),

              const SizedBox(height: 24),
              Text('Moderator simulation', style: AppFonts.fraunces(size: 16, weight: FontWeight.w600)),
              const SizedBox(height: 4),
              Text('Real moderation is active — this also lets you add a test item directly, without a real submission.', style: AppFonts.inter(size: 11, color: AppColors.textSoft)),
              const SizedBox(height: 10),
              _SimButton(
                label: '➕ Add a test flagged deed to the queue',
                onTap: () {
                  final key = deedCatalog.keys.first;
                  context.read<AppState>().simulateAddTestFlaggedDeed(key);
                },
              ),
              const SizedBox(height: 12),
              if (state.moderationQueue.isEmpty)
                Text('Queue is empty.', style: AppFonts.inter(size: 12, color: AppColors.textSoft))
              else
                ...state.moderationQueue.map((item) {
                  final meta = deedCatalog[item.type];
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: AppColors.oliveCard, borderRadius: BorderRadius.circular(12)),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        Text(meta?.icon ?? '❓', style: const TextStyle(fontSize: 18)),
                        const SizedBox(width: 8),
                        Expanded(child: Text(meta?.name ?? item.type, style: AppFonts.inter(size: 12.5, weight: FontWeight.w600))),
                        Text('+${item.points} pts', style: AppFonts.plexMono(size: 10.5, color: AppColors.textSoft)),
                      ]),
                      const SizedBox(height: 4),
                      Text(item.reason, style: AppFonts.inter(size: 10.5, color: AppColors.textSoft)),
                      if (item.photoFile != null) ...[
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Image.memory(item.photoFile!, height: 140, width: double.infinity, fit: BoxFit.cover),
                        ),
                      ] else if (item.photoUrl != null) ...[
                        // Real cross-session case — no local file (this device didn't submit
                        // it), but a photo exists in Storage. Generates a short-lived signed URL
                        // on demand since the bucket is private.
                        const SizedBox(height: 8),
                        FutureBuilder<String?>(
                          future: context.read<AppState>().getSignedPhotoUrl(item.photoUrl!),
                          builder: (context, snapshot) {
                            if (snapshot.connectionState != ConnectionState.done) {
                              return Container(
                                height: 140,
                                decoration: BoxDecoration(color: AppColors.bg2.withOpacity(0.4), borderRadius: BorderRadius.circular(10)),
                                alignment: Alignment.center,
                                child: const CircularProgressIndicator(color: AppColors.gold, strokeWidth: 2),
                              );
                            }
                            final url = snapshot.data;
                            if (url == null) {
                              return Container(
                                padding: const EdgeInsets.symmetric(vertical: 10),
                                decoration: BoxDecoration(color: AppColors.rust.withOpacity(0.12), borderRadius: BorderRadius.circular(10)),
                                alignment: Alignment.center,
                                child: Text('⚠️ Could not load photo', style: AppFonts.inter(size: 10.5, color: const Color(0xFFE39B84))),
                              );
                            }
                            return ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: Image.network(url, height: 140, width: double.infinity, fit: BoxFit.cover),
                            );
                          },
                        ),
                      ] else ...[
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(color: AppColors.rust.withOpacity(0.12), borderRadius: BorderRadius.circular(10)),
                          alignment: Alignment.center,
                          child: Text('⚠️ No photo attached to this item', style: AppFonts.inter(size: 10.5, color: const Color(0xFFE39B84))),
                        ),
                      ],
                      const SizedBox(height: 8),
                      Row(children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () async {
                              final error = await context.read<AppState>().approveQueueItem(item.id);
                              if (error != null && context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Approved locally, but the database update failed:\n$error')));
                              }
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              decoration: BoxDecoration(color: AppColors.olive, borderRadius: BorderRadius.circular(9)),
                              alignment: Alignment.center,
                              child: Text('✓ Approve', style: AppFonts.inter(size: 11.5, weight: FontWeight.w700, color: AppColors.inkOnGold)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: GestureDetector(
                            onTap: () async {
                              final error = await context.read<AppState>().rejectQueueItem(item.id);
                              if (error != null && context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Rejected locally, but the database update failed:\n$error')));
                              }
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              decoration: BoxDecoration(color: AppColors.rust.withOpacity(0.2), borderRadius: BorderRadius.circular(9), border: Border.all(color: AppColors.rust.withOpacity(0.4))),
                              alignment: Alignment.center,
                              child: Text('✕ Reject', style: AppFonts.inter(size: 11.5, weight: FontWeight.w700, color: const Color(0xFFE39B84))),
                            ),
                          ),
                        ),
                      ]),
                    ]),
                  );
                }),
            ],
          ),
        ),
        ],
      ),
    );
  }
}

class _SimButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _SimButton({required this.label, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(color: AppColors.oliveCard, borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0x29F6F5EC))),
          child: Text(label, style: AppFonts.inter(size: 12.5, weight: FontWeight.w600)),
        ),
      ),
    );
  }
}
