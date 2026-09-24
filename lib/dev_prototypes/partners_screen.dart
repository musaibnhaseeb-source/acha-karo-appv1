import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../state/app_state.dart';
import '../widgets/animated_wallpaper.dart';

// Blank placeholder — exists as a real screen/route so it's ready to build out, but the Redeem
// Points tile on Home is deliberately NOT wired to navigate here yet. It still shows its
// "coming soon" toast, per the current direction. Wire HomeScreen's Redeem tile onTap to push
// this screen once the actual redemption/partners design is ready.
class PartnersScreen extends StatelessWidget {
  const PartnersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(icon: const Icon(Icons.arrow_back, color: AppColors.text), onPressed: () => Navigator.of(context).pop()),
        title: Text('Redeem Points', style: AppFonts.inter(size: 14, weight: FontWeight.w600)),
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
            child: AnimatedWallpaper(gradientColors: wallpaperSwatches[context.watch<AppState>().wallpaperSwatchIndex]),
          ),
          Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                '🎁\n\nRedemption partners — coming soon.',
                textAlign: TextAlign.center,
                style: AppFonts.inter(size: 13, color: AppColors.textSoft),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
