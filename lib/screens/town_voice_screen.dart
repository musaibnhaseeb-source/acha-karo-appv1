import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../state/app_state.dart';

// Simplified for the pilot per the current direction — the full leader card / date-time /
// notify-calendar-YouTube UI still exists in the project's history and can come back once
// there's a real audience worth streaming to. Showing an honest "give us time to grow" message
// is more useful right now than a fully-built feature with no one watching it yet.
class TownVoiceScreen extends StatelessWidget {
  const TownVoiceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(icon: const Icon(Icons.arrow_back, color: AppColors.text), onPressed: () => Navigator.of(context).pop()),
        title: Text('Town Voice', style: AppFonts.inter(size: 14, weight: FontWeight.w600)),
        centerTitle: true,
      ),
      body: Container(
        decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: wallpaperSwatches[state.wallpaperSwatchIndex])),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('🎙️', style: TextStyle(fontSize: 48)),
                  const SizedBox(height: 20),
                  Text('Launching soon', style: AppFonts.fraunces(size: 20, weight: FontWeight.w600), textAlign: TextAlign.center),
                  const SizedBox(height: 12),
                  Text(
                    "We're giving ourselves time to accumulate real users first — so when Town Voice launches, you'll actually have a meaningful audience, and your time will be worth it.",
                    textAlign: TextAlign.center,
                    style: AppFonts.inter(size: 13, color: AppColors.textSoft, height: 1.6),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
