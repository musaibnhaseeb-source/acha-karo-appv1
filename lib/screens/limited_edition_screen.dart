import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:gal/gal.dart';
import 'dart:io';
import 'dart:typed_data';
import '../theme/app_theme.dart';
import '../state/app_state.dart';
import '../widgets/animated_wallpaper.dart';
import '../widgets/campaign_icon.dart';
import '../widgets/youtube_icon.dart';
import '../utils/youtube.dart';

// Real fix here: this only ever showed the empty state, even for someone who'd genuinely
// completed a Hall of Fame claim — the claiming half was built and working, but nothing here
// was ever updated to actually display it. hall_of_fame_claims only records THAT something was
// claimed for a campaign; the actual badge/sticker content lives on that campaign's own row, so
// this fetches both and joins them together.
//
// Restyled to match Skins' real row layout, per direction — same card shape, same icon+name+
// action structure, rather than the earlier grid-card style.
class LimitedEditionScreen extends StatefulWidget {
  const LimitedEditionScreen({super.key});
  @override
  State<LimitedEditionScreen> createState() => _LimitedEditionScreenState();
}

class _LimitedEditionItem {
  final String icon;
  final String name;
  final String type; // 'Badge', 'Sticker', or 'Video'
  final String? videoRef; // only set for type 'Video' — the raw youtube_video_id/link to open
  const _LimitedEditionItem({required this.icon, required this.name, required this.type, this.videoRef});

  // Real download only ever makes sense against the sticker column specifically, and only when
  // it's genuinely a real image (not an emoji) — nothing to "download" from a plain character.
  bool get isDownloadableSticker => type == 'Sticker' && (icon.startsWith('http://') || icon.startsWith('https://'));
}

class _LimitedEditionScreenState extends State<LimitedEditionScreen> {
  List<_LimitedEditionItem> items = [];
  bool loading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { loading = true; error = null; });
    try {
      final uid = Supabase.instance.client.auth.currentUser?.id;
      if (uid == null) return;
      final rows = await Supabase.instance.client
          .from('hall_of_fame_claims')
          .select('campaigns(title, hof_badge_name, hof_badge_icon, hof_sticker_name, hof_sticker_icon, hof_youtube_video_id)')
          .eq('user_id', uid);
      final result = <_LimitedEditionItem>[];
      for (final r in rows) {
        final campaign = r['campaigns'] as Map<String, dynamic>?;
        if (campaign == null) continue;
        if (campaign['hof_badge_name'] != null) {
          result.add(_LimitedEditionItem(icon: campaign['hof_badge_icon'] as String? ?? '🏅', name: campaign['hof_badge_name'] as String, type: 'Badge'));
        }
        if (campaign['hof_sticker_name'] != null) {
          result.add(_LimitedEditionItem(icon: campaign['hof_sticker_icon'] as String? ?? '✨', name: campaign['hof_sticker_name'] as String, type: 'Sticker'));
        }
        final videoRef = campaign['hof_youtube_video_id'] as String?;
        if (videoRef != null && videoRef.isNotEmpty) {
          result.add(_LimitedEditionItem(icon: '▶️', name: '${campaign['title'] as String? ?? 'Campaign'} video', type: 'Video', videoRef: videoRef));
        }
      }
      setState(() { items = result; loading = false; });
    } catch (e) {
      setState(() { error = 'Could not load your items: ${e.toString()}'; loading = false; });
    }
  }

  Future<void> _openVideo(String raw) async {
    final videoId = extractYoutubeVideoId(raw);
    if (videoId == null) return;
    await launchUrl(Uri.parse('https://www.youtube.com/watch?v=$videoId'), mode: LaunchMode.externalApplication);
  }

  // Real download now, per direction — genuinely saves to the device's gallery, not just
  // opening the image externally for someone to save manually themselves. Bytes fetched via
  // Dart's own built-in HttpClient (no new dependency needed just for that part); gal handles
  // the actual, genuinely platform-specific save.
  bool _downloading = false;
  Future<void> _downloadSticker(BuildContext context, String url, String name) async {
    setState(() => _downloading = true);
    try {
      final client = HttpClient();
      final request = await client.getUrl(Uri.parse(url));
      final response = await request.close();
      if (response.statusCode != 200) {
        throw Exception('Could not fetch the image (status ${response.statusCode}).');
      }
      // Real, deliberate choice here: writing this small helper directly rather than relying on
      // a remembered built-in API name I can't actually verify in this sandbox (no live docs
      // access, and package installation is blocked here too) — a few lines of guaranteed-
      // correct code beats a name I'm not fully certain of.
      final bytes = <int>[];
      await for (final chunk in response) {
        bytes.addAll(chunk);
      }
      // Real fix here: gal's API expects a genuine Uint8List (the standard type for binary
      // image data), not a plain List<int> — converted explicitly rather than assumed compatible.
      await Gal.putImageBytes(Uint8List.fromList(bytes), name: name.replaceAll(' ', '_'));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$name saved to your gallery!')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not save this sticker: ${e.toString()}')));
      }
    } finally {
      if (mounted) setState(() => _downloading = false);
    }
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
        title: Text('Limited Edition Items', style: AppFonts.inter(size: 14, weight: FontWeight.w600)),
        centerTitle: true,
      ),
      body: Stack(
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
            child: loading
                ? const Center(child: CircularProgressIndicator(color: AppColors.gold))
                : error != null
                    ? Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(error!, textAlign: TextAlign.center, style: AppFonts.inter(size: 12, color: AppColors.textSoft))))
                    : SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(18, 10, 18, 30),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('🏆 Limited Edition Items', style: AppFonts.fraunces(size: 22, weight: FontWeight.w600)),
                            const SizedBox(height: 4),
                            Text('Medals and stickers earned by completing a campaign\'s full roadmap.', style: AppFonts.inter(size: 12, color: AppColors.textSoft)),
                            const SizedBox(height: 18),
                            if (items.isEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 30),
                                child: Center(
                                  child: Column(children: [
                                    Opacity(opacity: 0.4, child: const Text('🏆', style: TextStyle(fontSize: 44))),
                                    const SizedBox(height: 14),
                                    Text('Nothing here yet', style: AppFonts.fraunces(size: 15, weight: FontWeight.w600)),
                                    const SizedBox(height: 6),
                                    Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 24),
                                      child: Text(
                                        'Complete all 12 deeds in a campaign\'s roadmap to unlock a limited-edition medal and collectible sticker here.',
                                        textAlign: TextAlign.center,
                                        style: AppFonts.inter(size: 12, color: AppColors.textSoft, height: 1.6),
                                      ),
                                    ),
                                  ]),
                                ),
                              )
                            else
                              ...items.map((item) => Padding(
                                    padding: const EdgeInsets.only(bottom: 10),
                                    child: GestureDetector(
                                      onTap: item.type == 'Video' ? () => _openVideo(item.videoRef!) : null,
                                      child: Container(
                                        padding: const EdgeInsets.all(14),
                                        decoration: BoxDecoration(color: AppColors.oliveCard, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.gold.withOpacity(0.35))),
                                        child: Row(children: [
                                          item.type == 'Video' ? const YoutubeIcon(size: 32) : CampaignIcon(icon: item.icon, size: 32),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                              Text(item.name, style: AppFonts.inter(size: 13, weight: FontWeight.w700)),
                                              const SizedBox(height: 2),
                                              Text(item.type, style: AppFonts.inter(size: 10.5, color: AppColors.textSoft)),
                                            ]),
                                          ),
                                          if (item.isDownloadableSticker)
                                            GestureDetector(
                                              onTap: _downloading ? null : () => _downloadSticker(context, item.icon, item.name),
                                              child: Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                                                decoration: BoxDecoration(color: AppColors.gold, borderRadius: BorderRadius.circular(100)),
                                                child: _downloading
                                                    ? const SizedBox(width: 13, height: 13, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.inkOnGold))
                                                    : Row(mainAxisSize: MainAxisSize.min, children: [
                                                        const Icon(Icons.download_rounded, size: 13, color: AppColors.inkOnGold),
                                                        const SizedBox(width: 4),
                                                        Text('Download', style: AppFonts.plexMono(size: 9.5, weight: FontWeight.w700, color: AppColors.inkOnGold)),
                                                      ]),
                                              ),
                                            )
                                          else
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                              decoration: BoxDecoration(color: AppColors.gold.withOpacity(0.18), borderRadius: BorderRadius.circular(100)),
                                              child: Text(item.type.toUpperCase(), style: AppFonts.plexMono(size: 8.5, weight: FontWeight.w700, color: AppColors.gold)),
                                            ),
                                        ]),
                                      ),
                                    ),
                                  )),
                          ],
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}
