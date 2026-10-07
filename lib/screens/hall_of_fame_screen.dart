import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../theme/app_theme.dart';
import '../state/app_state.dart';
import '../data/remote_config.dart';
import '../widgets/flip_card.dart';
import '../widgets/youtube_icon.dart';
import '../widgets/campaign_icon.dart';
import '../utils/youtube.dart';
import 'contact_screen.dart';

// New — the real reveal triggered after winning a campaign's final stop, per the exact sequence
// specified: three cards (sticker, badge, video) flip to reveal in a staggered sequence, then
// Claim All appears, which safely records the claim server-side (verified against a real,
// already-recorded final-stop win — not just trusted from the app) and shows a feedback CTA.
class HallOfFameScreen extends StatefulWidget {
  final Campaign campaign;
  const HallOfFameScreen({super.key, required this.campaign});
  @override
  State<HallOfFameScreen> createState() => _HallOfFameScreenState();
}

class _HallOfFameScreenState extends State<HallOfFameScreen> {
  final List<GlobalKey<FlipCardState>> _cardKeys = List.generate(3, (_) => GlobalKey<FlipCardState>());
  bool _revealed = false;
  bool _claiming = false;
  bool _claimed = false;

  @override
  void initState() {
    super.initState();
    // Staggered auto-flip on load — each card reveals a beat after the last, matching the
    // specified "3 cards flipping to reveal" sequence rather than all three snapping at once.
    Future.delayed(const Duration(milliseconds: 400), () {
      if (mounted) _cardKeys[0].currentState?.flip();
    });
    Future.delayed(const Duration(milliseconds: 900), () {
      if (mounted) _cardKeys[1].currentState?.flip();
    });
    Future.delayed(const Duration(milliseconds: 1400), () {
      if (mounted) _cardKeys[2].currentState?.flip();
    });
    Future.delayed(const Duration(milliseconds: 2000), () {
      if (mounted) setState(() => _revealed = true);
    });
  }

  Future<void> _claimAll() async {
    setState(() => _claiming = true);
    try {
      final result = await Supabase.instance.client.rpc('claim_hall_of_fame', params: {'campaign_id_input': widget.campaign.id});
      if (!mounted) return;
      if (result == 'success') {
        setState(() { _claiming = false; _claimed = true; });
        _showFeedbackCta();
      } else {
        setState(() => _claiming = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result as String? ?? 'Could not complete this.')));
      }
    } catch (e) {
      if (mounted) setState(() => _claiming = false);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Couldn't complete this. Please try again.")));
    }
  }

  void _showFeedbackCta() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.bg2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text('🎉 All claimed!', style: AppFonts.fraunces(size: 16, weight: FontWeight.w600)),
        content: Text("You've completed this campaign's whole journey. We'd love to hear how it went.", textAlign: TextAlign.center, style: AppFonts.inter(size: 13, color: AppColors.textSoft)),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: Text('Later', style: AppFonts.inter(size: 13, color: AppColors.textSoft))),
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ContactScreen()));
            },
            child: Text('Share feedback', style: AppFonts.inter(size: 13, weight: FontWeight.w700, color: AppColors.gold)),
          ),
        ],
      ),
    );
  }

  Future<void> _watchVideo() async {
    final raw = widget.campaign.hofYoutubeVideoId;
    if (raw == null || raw.isEmpty) return;
    final videoId = extractYoutubeVideoId(raw);
    if (videoId == null) return;
    await launchUrl(Uri.parse('https://www.youtube.com/watch?v=$videoId'), mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    context.watch<AppState>();
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: Text('Hall of Fame', style: AppFonts.inter(size: 14, weight: FontWeight.w600)),
        centerTitle: true,
      ),
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
            child: Container(decoration: const BoxDecoration(gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [AppColors.bg2, AppColors.bg1]))),
          ),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 30),
              child: Column(
                children: [
                  const Text('🏆', style: TextStyle(fontSize: 40)),
                  const SizedBox(height: 10),
                  Text('You completed the whole road!', style: AppFonts.fraunces(size: 19, weight: FontWeight.w600), textAlign: TextAlign.center),
                  const SizedBox(height: 6),
                  Text(widget.campaign.title, style: AppFonts.inter(size: 12, color: AppColors.textSoft)),
                  const SizedBox(height: 28),
                  Row(
                    children: [
                      Expanded(child: _HofCard(cardKey: _cardKeys[0], icon: widget.campaign.hofStickerIcon ?? '✨', label: widget.campaign.hofStickerName ?? 'Sticker')),
                      const SizedBox(width: 12),
                      Expanded(child: _HofCard(cardKey: _cardKeys[1], icon: widget.campaign.hofBadgeIcon ?? '🏅', label: widget.campaign.hofBadgeName ?? 'Badge')),
                      const SizedBox(width: 12),
                      Expanded(child: _HofCard(cardKey: _cardKeys[2], icon: '▶️', label: 'Video', onTap: _revealed ? _watchVideo : null)),
                    ],
                  ),
                  const SizedBox(height: 32),
                  AnimatedOpacity(
                    opacity: _revealed ? 1 : 0,
                    duration: const Duration(milliseconds: 400),
                    child: IgnorePointer(
                      ignoring: !_revealed,
                      child: GestureDetector(
                        onTap: _claimed || _claiming ? null : _claimAll,
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 15),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(colors: [AppColors.gold, Color(0xFFF3D688)]),
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: [BoxShadow(color: AppColors.gold.withOpacity(0.5), blurRadius: 20, spreadRadius: 1)],
                          ),
                          alignment: Alignment.center,
                          child: _claiming
                              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.inkOnGold))
                              : Text(_claimed ? '✓ Claimed' : 'Claim All', style: AppFonts.inter(size: 14, weight: FontWeight.w700, color: AppColors.inkOnGold)),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: () => Navigator.of(context).popUntil((r) => r.isFirst),
                    child: Text('Back to Home', style: AppFonts.inter(size: 12, color: AppColors.textSoft)),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Real, distinctive card styling per the spec — golden, textured (layered gradient stops since
// no image asset exists for a literal texture), bright glow shadow, using the same shared
// FlipCard mechanic already proven for the mystery boxes.
class _HofCard extends StatelessWidget {
  final GlobalKey<FlipCardState> cardKey;
  final String icon;
  final String label;
  final VoidCallback? onTap;
  const _HofCard({required this.cardKey, required this.icon, required this.label, this.onTap});

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 0.72,
      child: FlipCard(
        key: cardKey,
        onTap: onTap ?? () {},
        front: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [AppColors.olive.withOpacity(0.4), AppColors.bg1]),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.gold.withOpacity(0.3), width: 1.5),
          ),
          alignment: Alignment.center,
          child: Text('?', style: AppFonts.fraunces(size: 34, weight: FontWeight.w700).copyWith(color: AppColors.gold.withOpacity(0.7))),
        ),
        back: Container(
          decoration: BoxDecoration(
            // Layered gold gradient stops standing in for a real texture — no image asset for
            // this exists, this is the closest a pure-Flutter decoration gets to it.
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFFF3D688), Color(0xFFD9A62E), Color(0xFFB8860B), Color(0xFFF3D688)],
              stops: [0.0, 0.4, 0.7, 1.0],
            ),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFF6E7B8), width: 2),
            boxShadow: [BoxShadow(color: AppColors.gold.withOpacity(0.6), blurRadius: 18, spreadRadius: 1)],
          ),
          alignment: Alignment.center,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            // Real fix here: only the video card should get the branded YouTube treatment —
            // sticker and badge cards still show their own real emoji/icon as before.
            // Real fix here: this rendered the icon as plain text, never routed through
            // CampaignIcon at all — meaning a sticker or badge with a real image URL (not an
            // emoji) would show the raw URL text instead of the actual image. Same underlying
            // bug class already fixed elsewhere in the app, just missed here until now.
            icon == '▶️' ? const YoutubeIcon(size: 34) : CampaignIcon(icon: icon, size: 32),
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(label, textAlign: TextAlign.center, style: AppFonts.inter(size: 9.5, weight: FontWeight.w700, color: AppColors.inkOnGold), maxLines: 2, overflow: TextOverflow.ellipsis),
            ),
          ]),
        ),
      ),
    );
  }
}
