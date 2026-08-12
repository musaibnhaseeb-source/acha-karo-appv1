import 'dart:math';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme/app_theme.dart';
import '../data/remote_config.dart';
import '../data/deed_catalog.dart';
import '../widgets/campaign_icon.dart';
import '../widgets/submit_deed_flow.dart';

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
      body: Container(
        decoration: const BoxDecoration(gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [AppColors.bg2, AppColors.bg1])),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(18, 10, 18, 30),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Tap the card to flip it', style: AppFonts.inter(size: 11.5, color: AppColors.textSoft)),
                const SizedBox(height: 12),
                _FlipCard(
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
      height: 320,
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
    final videoId = campaign.youtubeVideoId;
    if (videoId == null || videoId.isEmpty) return;
    final uri = Uri.parse('https://www.youtube.com/watch?v=$videoId');
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not open the video.')));
    }
  }

  // The CTA's actual behavior — one quick, low-friction deed per category (whichever is worth
  // the fewest points, i.e. fastest/easiest), so someone reading about a campaign can act on it
  // immediately without hunting through all 32 deed types on Home. Tapping any of these opens
  // openSubmitDeedFlow — the exact same real flow as a normal submission (GPS, moderation,
  // cooldowns, age-related rules already enforced app-wide at sign-up), nothing bypassed or
  // specially relaxed just because it started from a campaign.
  void _showQuickActions(BuildContext context) {
    final lowest = lowestPointDeedPerCategory();
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.bg2,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (sheetContext) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Quick actions', style: AppFonts.fraunces(size: 16, weight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text('The fastest deed in each category — one tap to get started.', style: AppFonts.inter(size: 11.5, color: AppColors.textSoft)),
            const SizedBox(height: 16),
            ...categoryDefs.map((cat) {
              final type = lowest[cat.key];
              if (type == null) return const SizedBox.shrink();
              final meta = deedCatalog[type]!;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: GestureDetector(
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    openSubmitDeedFlow(context, type);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(color: AppColors.oliveCard, borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0x29F6F5EC))),
                    child: Row(children: [
                      Text(meta.icon, style: const TextStyle(fontSize: 18)),
                      const SizedBox(width: 10),
                      Expanded(child: Text(meta.name, style: AppFonts.inter(size: 12.5, weight: FontWeight.w600))),
                      Text('+${meta.points} pts', style: AppFonts.plexMono(size: 10.5, color: AppColors.textSoft)),
                    ]),
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 320),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.oliveCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.gold.withOpacity(0.35)),
      ),
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
              // quick-action sheet regardless of ctaLink; that field is no longer used for this
              // button (kept in the schema for now in case it's wanted for something else later).
              onTap: () => _showQuickActions(context),
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
        ],
      ),
    );
  }
}

// Real 3D flip using core Flutter Transform/Matrix4 — no extra package needed for this part.
class _FlipCard extends StatefulWidget {
  final Widget front;
  final Widget back;
  const _FlipCard({required this.front, required this.back});
  @override
  State<_FlipCard> createState() => _FlipCardState();
}

class _FlipCardState extends State<_FlipCard> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  bool _showFront = true;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 500));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _flip() {
    if (_controller.isAnimating) return;
    if (_showFront) {
      _controller.forward();
    } else {
      _controller.reverse();
    }
    _showFront = !_showFront;
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _flip,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          final angle = _controller.value * pi;
          final isBack = angle > pi / 2;
          final displayAngle = isBack ? angle - pi : angle;
          return Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.0015)
              ..rotateY(displayAngle),
            child: isBack ? widget.back : widget.front,
          );
        },
      ),
    );
  }
}
