import 'package:flutter/material.dart';
import '../state/app_state.dart' show wallpaperSwatches;
import '../theme/app_theme.dart';
import '../widgets/animated_wallpaper.dart';
import '../widgets/guddi_loading.dart';

// DEV-ONLY preview of the cold-start Guddi loader: its own entry point, never imported by the app.
//   flutter run -d chrome -t lib/dev_prototypes/guddi_loading_preview.dart
// 360-dp panels: each line at 1.0, and the two longest at the app's A+ (1.15) and 1.3. No Supabase, no data.

void main() => runApp(MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      home: const Scaffold(
        backgroundColor: AppColors.bg1,
        body: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          _Phone(label: 'returning 1.0', child: GuddiLoading(returning: true, slowAfter: Duration(days: 1))),
          _Phone(label: 'first open 1.0', child: GuddiLoading(returning: false, slowAfter: Duration(days: 1))),
          _Phone(label: 'slow 1.0', child: GuddiLoading(returning: true, slowAfter: Duration.zero)),
          _Phone(label: 'first open 1.15', scale: 1.15, child: GuddiLoading(returning: false, slowAfter: Duration(days: 1))),
          _Phone(label: 'slow 1.15 (A+)', scale: 1.15, child: GuddiLoading(returning: true, slowAfter: Duration.zero)),
          _Phone(label: 'slow 1.3', scale: 1.3, child: GuddiLoading(returning: true, slowAfter: Duration.zero)),
        ]),
      ),
    ));

class _Phone extends StatelessWidget {
  final Widget child;
  final String label;
  final double scale;
  const _Phone({required this.child, required this.label, this.scale = 1.0});
  @override
  Widget build(BuildContext context) => Container(
        width: 360,
        height: 640,
        margin: const EdgeInsets.all(6),
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(18)),
        child: Stack(fit: StackFit.expand, children: [
          AnimatedWallpaper(gradientColors: wallpaperSwatches[0]),
          MediaQuery(data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)), child: SafeArea(child: child)),
          Positioned(left: 8, top: 6, child: Text(label, style: const TextStyle(color: Colors.white54, fontSize: 11))),
        ]),
      );
}
