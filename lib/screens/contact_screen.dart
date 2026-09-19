import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../state/app_state.dart';
import '../widgets/animated_wallpaper.dart';

// Ported from #moreTabContact / renderContact() in the original. Feedback submitted here feeds
// state.feedback, which is also what the "Advisor" badge (3+ feedbacks) already checks in
// badges.dart — this is the first screen in the Flutter port that actually writes to that list.
class ContactScreen extends StatefulWidget {
  const ContactScreen({super.key});
  @override
  State<ContactScreen> createState() => _ContactScreenState();
}

class _ContactScreenState extends State<ContactScreen> {
  int rating = 0;
  final textController = TextEditingController();

  void _submit(BuildContext context) {
    final text = textController.text.trim();
    if (rating == 0 && text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Pick a star rating or add a note first.")));
      return;
    }
    if (text.isNotEmpty && rating == 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please pick a star rating before submitting written feedback.')));
      return;
    }
    context.read<AppState>().submitFeedback(stars: rating, text: text);
    setState(() {
      rating = 0;
      textController.clear();
    });
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Thanks — feedback submitted.')));
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
        title: Text('Contact', style: AppFonts.inter(size: 14, weight: FontWeight.w600)),
        centerTitle: true,
      ),
      // Same real bug fixed here as Leaderboard — Container-wrapping-content only fills as much
      // height as its content needs, showing black underneath on a short screen. Stack with the
      // gradient as a Positioned.fill layer decouples background from content height entirely.
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
                Text("Tell us what's working, what isn't.", style: AppFonts.inter(size: 12, color: AppColors.textSoft)),
                const SizedBox(height: 14),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: AppColors.oliveCard, borderRadius: BorderRadius.circular(16)),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text("How's the app treating you?", style: AppFonts.inter(size: 12, color: AppColors.textSoft)),
                    const SizedBox(height: 8),
                    Row(children: List.generate(5, (i) {
                      final filled = i < rating;
                      return GestureDetector(
                        onTap: () => setState(() => rating = i + 1),
                        child: Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: Text(filled ? '★' : '☆', style: TextStyle(fontSize: 26, color: filled ? AppColors.gold : AppColors.textSoft)),
                        ),
                      );
                    })),
                    const SizedBox(height: 16),
                    Text('Feedback', style: AppFonts.inter(size: 12, color: AppColors.textSoft)),
                    const SizedBox(height: 8),
                    Container(
                      decoration: BoxDecoration(color: AppColors.bg1.withOpacity(0.3), borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0x33F6F5EC))),
                      child: TextField(
                        controller: textController,
                        maxLines: 4,
                        style: AppFonts.inter(size: 13),
                        decoration: InputDecoration(
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.all(10),
                          hintText: "Anything you'd like us to know...",
                          hintStyle: AppFonts.inter(size: 13, color: AppColors.textSoft.withOpacity(0.5)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    GestureDetector(
                      onTap: () => _submit(context),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        decoration: BoxDecoration(color: AppColors.gold, borderRadius: BorderRadius.circular(13)),
                        alignment: Alignment.center,
                        child: Text('Submit feedback', style: AppFonts.inter(size: 14, weight: FontWeight.w700, color: AppColors.inkOnGold)),
                      ),
                    ),
                  ]),
                ),
                if (state.feedback.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  Text('Previously submitted', style: AppFonts.fraunces(size: 15, weight: FontWeight.w600)),
                  const SizedBox(height: 10),
                  // Real bug fixed here, same root cause as notifications — this .reversed
                  // undid the correct order once the load query itself was made newest-first.
                  // feedback is already correctly ordered now, both from loading and from new
                  // submissions being inserted at the front instead of appended.
                  ...state.feedback.map((f) => Container(
                        width: double.infinity, // Same real bug as notifications — the parent
                        // Column's CrossAxisAlignment.start sized these to their own content
                        // width instead of a consistent full width.
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(color: AppColors.oliveCard, borderRadius: BorderRadius.circular(14)),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text('★' * f.stars + '☆' * (5 - f.stars), style: const TextStyle(color: AppColors.gold, fontSize: 13)),
                          if (f.text.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(f.text, style: AppFonts.inter(size: 12, color: AppColors.textSoft)),
                          ],
                          if (f.responded) ...[
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(color: AppColors.olive.withOpacity(0.1), borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.olive.withOpacity(0.3))),
                              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Text('MODERATOR RESPONSE', style: AppFonts.plexMono(size: 9, color: AppColors.olive)),
                                const SizedBox(height: 4),
                                Text(f.response ?? '', style: AppFonts.inter(size: 12, color: AppColors.textSoft)),
                              ]),
                            ),
                          ],
                        ]),
                      )),
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
