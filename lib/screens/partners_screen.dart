import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../state/app_state.dart';

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
      body: Container(
        decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: wallpaperSwatches[context.watch<AppState>().wallpaperSwatchIndex])),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              '🎁\n\nRedemption partners — coming soon.',
              textAlign: TextAlign.center,
              style: AppFonts.inter(size: 13, color: AppColors.textSoft),
            ),
          ),
        ),
      ),
    );
  }
}
