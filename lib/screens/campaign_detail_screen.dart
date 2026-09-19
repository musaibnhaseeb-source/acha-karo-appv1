import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme/app_theme.dart';
import '../state/app_state.dart';
import '../data/remote_config.dart';
import '../widgets/campaign_icon.dart';
import '../widgets/animated_wallpaper.dart';
import '../widgets/flip_card.dart';
import '../utils/youtube.dart';
import 'roadmap_screen.dart';

// New screen — tapping the campaign card on Home opens this. Hosts a real flip card (front:
// campaign intro; back: YouTube link + CTA + running dates), everything on it driven by the
// Campaign row from the database, nothing hardcoded here. Video opens externally (YouTube app or
// browser) rather than playing in-app — see pubspec.yaml for why.
class CampaignDetailScreen extends StatelessWidget {
  final Campaign campaign;
  const CampaignDetailScreen({super.key, required this.campaign});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(icon: const Icon(Icons.arrow_back, color: AppColors.text), onPressed: () => Navigator.of(context).pop()),
        title: Text(campaign.title, style: AppFonts.inter(size: 14, weight: FontWeight.w600)),
        centerTitle: true,
      ),
      // Two real bugs fixed here: same background-fill issue as the other screens in this
      // batch, plus this was using a hardcoded gradient instead of reacting to the wallpaper
      // setting like every other screen does — same category of oversight as the Side Sheet fix
      // from an earlier batch, just never caught on this specific screen until now.
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
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(18, 10, 18, 30),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Tap the card to flip it', style: AppFonts.inter(size: 11.5, color: AppColors.textSoft)),
                const SizedBox(height: 12),
                FlipCard(
                  front: _CardFront(campaign: campaign),
                  back: _CardBack(campaign: campaign),
                ),
                if (campaign.cooldownMinutesOverride != null) ...[
                  const SizedBox(height: 18),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(color: AppColors.olive.withOpacity(0.12), borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.olive.withOpacity(0.3))),
                    child: Row(children: [
                      const Text('⚡', style: TextStyle(fontSize: 18)),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Cooldowns are shortened to ${campaign.cooldownMinutesOverride} minutes while this campaign runs.',
                          style: AppFonts.inter(size: 12, color: AppColors.text),
                        ),
                      ),
                    ]),
                  ),
                ],
              ],
            ),
          ),
        ),
        ],
      ),
    );
  }
}

class _CardFront extends StatelessWidget {
  final Campaign campaign;
  const _CardFront({required this.campaign});
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      // Real fix here: front and back previously had different heights (front fixed at 320,
      // back allowed to grow taller for its extra content), causing a visible size jump during
      // the flip. Both sides now share one fixed height, genuinely closer to full-screen —
      // T&Cs added below to both sides so the front doesn't just look sparse with empty space.
      height: 480,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [AppColors.gold.withOpacity(0.22), AppColors.oliveCard]),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.gold.withOpacity(0.35)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CampaignIcon(icon: campaign.icon, size: 56),
          const SizedBox(height: 16),
          Text(campaign.title, textAlign: TextAlign.center, style: AppFonts.fraunces(size: 20, weight: FontWeight.w600)),
          const SizedBox(height: 8),
          Text(campaign.description, textAlign: TextAlign.center, style: AppFonts.inter(size: 12.5, color: AppColors.textSoft, height: 1.5)),
          const SizedBox(height: 20),
          Text('👆 Tap to flip', style: AppFonts.plexMono(size: 10, color: AppColors.gold)),
          const Spacer(),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: AppColors.bg1.withOpacity(0.3), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0x1FF6F5EC))),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('TERMS & CONDITIONS', style: AppFonts.plexMono(size: 9.5, color: AppColors.textSoft).copyWith(letterSpacing: 0.5)),
              const SizedBox(height: 6),
              Text(
                // Real fix here: this front-side teaser was left hardcoded when the back side
                // became database-driven — always said "placeholder" even for a campaign with
                // genuine, real terms set. Now reflects the same real/placeholder status as the
                // back, just condensed rather than showing the full text twice.
                campaign.termsAndConditions != null
                    ? 'Real terms apply to this campaign. Full terms on the back of this card.'
                    : 'Placeholder — real terms to be added. Full terms on the back of this card.',
                style: AppFonts.inter(size: 10.5, color: AppColors.textSoft, height: 1.5),
              ),
            ]),
          ),
        ],
      ),
    );
  }
}

class _CardBack extends StatelessWidget {
  final Campaign campaign;
  const _CardBack({required this.campaign});

  String _formatDateRange() {
    final start = campaign.startDate;
    final end = campaign.endDate;
    if (start == null && end == null) return 'Running now';
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    String fmt(DateTime d) => '${months[d.month - 1]} ${d.day}, ${d.year}';
    if (start != null && end != null) return 'Running ${fmt(start)} – ${fmt(end)}';
    if (start != null) return 'Started ${fmt(start)}';
    return 'Until ${fmt(end!)}';
  }

  Future<void> _openVideo(BuildContext context) async {
    final raw = campaign.youtubeVideoId;
    if (raw == null || raw.isEmpty) return;
    final videoId = extractYoutubeVideoId(raw);
    if (videoId == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Couldn't recognize this campaign's video link — check it in Supabase.")));
      }
      return;
    }
    final uri = Uri.parse('https://www.youtube.com/watch?v=$videoId');
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not open the video.')));
    }
  }

  // Relocated to roadmap_screen.dart — the CTA now opens the Roadmap directly, and this same
  // "quick, easy deed" concept lives there instead, now offering real choice (3 per category)
  // rather than a single pick. Removed from here rather than left as dead code.

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      // Real fix here: matches _CardFront's fixed height exactly now, instead of the old
      // minHeight (which let this side grow taller and caused the visible jump during the flip).
      // Content wrapped in its own scroll view, since fixing the height means genuinely long
      // content (a long T&Cs block) needs somewhere safe to go rather than overflowing.
      height: 480,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.oliveCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.gold.withOpacity(0.35)),
      ),
      child: SingleChildScrollView(
        child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (campaign.youtubeVideoId != null && campaign.youtubeVideoId!.isNotEmpty)
            GestureDetector(
              onTap: () => _openVideo(context),
              child: Container(
                width: double.infinity,
                height: 100,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [Color(0xFFFF3B30), Color(0xFFC1272D)]),
                  borderRadius: BorderRadius.circular(14),
                ),
                alignment: Alignment.center,
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.play_circle_fill, color: Colors.white, size: 34),
                  const SizedBox(height: 6),
                  Text('Watch on YouTube', style: AppFonts.inter(size: 13, weight: FontWeight.w700, color: Colors.white)),
                ]),
              ),
            )
          else
            Container(
              width: double.infinity,
              height: 100,
              decoration: BoxDecoration(color: AppColors.bg2.withOpacity(0.4), borderRadius: BorderRadius.circular(14)),
              alignment: Alignment.center,
              child: Text('No video linked to this campaign', style: AppFonts.inter(size: 12, color: AppColors.textSoft)),
            ),
          const SizedBox(height: 16),
          if (campaign.ctaLabel != null)
            GestureDetector(
              // Real behavior now — was just a "would open" placeholder before. Opens the same
              // Real behavior changed here — CTA now opens the Roadmap directly, per the current
              // testing phase. The quick-actions task-list concept isn't removed, just relocated
              // onto the Roadmap screen itself (see roadmap_screen.dart), where it now serves the
              // same purpose — a fast way to log a real deed — from a more natural point in the
              // flow. ctaLink still unused (kept in the schema in case it's wanted later).
              onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => RoadmapScreen(campaign: campaign))),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 13),
                decoration: BoxDecoration(color: AppColors.gold, borderRadius: BorderRadius.circular(13)),
                alignment: Alignment.center,
                child: Text(campaign.ctaLabel!, style: AppFonts.inter(size: 13.5, weight: FontWeight.w700, color: AppColors.inkOnGold)),
              ),
            ),
          const SizedBox(height: 12),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            const Icon(Icons.calendar_today, size: 13, color: AppColors.textSoft),
            const SizedBox(width: 6),
            Text(_formatDateRange(), style: AppFonts.plexMono(size: 11, color: AppColors.textSoft)),
          ]),
          const SizedBox(height: 18),
          // New — fills the remaining space at the bottom of shorter campaign cards, which
          // pragmatically addresses the black-gap issue for this specific screen regardless of
          // whatever the underlying system-level cause turns out to be. Placeholder legal text
          // for now — real copy to be provided.
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: AppColors.bg1.withOpacity(0.3), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0x1FF6F5EC))),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('TERMS & CONDITIONS', style: AppFonts.plexMono(size: 9.5, color: AppColors.textSoft).copyWith(letterSpacing: 0.5)),
              const SizedBox(height: 8),
              // Real fix here: now genuinely database-driven, per-campaign content — falls back
              // to the same honest placeholder if a campaign hasn't set real terms yet.
              Text(
                campaign.termsAndConditions ??
                    'Placeholder — real terms to be added. Participation in this campaign and any associated rewards are subject to Acha Karo\'s standard terms of use. Rewards, if any, are not guaranteed and are awarded at the sole discretion of the platform. Campaign dates and rewards may change without notice.',
                style: AppFonts.inter(size: 11, color: AppColors.textSoft, height: 1.6),
              ),
            ]),
          ),
        ],
        ),
      ),
    );
  }
}
