import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme/app_theme.dart';
import '../state/app_state.dart';

// New — real update-available popup. Shown at app start once checkForUpdate() confirms this
// specific user should genuinely see it (an active update exists, they joined before it was
// created, and they haven't already acknowledged it).
class UpdateAvailableDialog extends StatelessWidget {
  final Map<String, dynamic> update;
  const UpdateAvailableDialog({super.key, required this.update});

  @override
  Widget build(BuildContext context) {
    final versionLabel = update['version_label'] as String? ?? 'New update';
    final message = update['message'] as String?;
    final downloadUrl = update['download_url'] as String?;

    return Dialog(
      backgroundColor: AppColors.bg2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: AppColors.gold.withOpacity(0.4))),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('🚀', style: TextStyle(fontSize: 32)),
          const SizedBox(height: 14),
          Text(versionLabel, style: AppFonts.fraunces(size: 18, weight: FontWeight.w600)),
          const SizedBox(height: 8),
          Text(
            message ?? 'A new version of Acha Karo is available.',
            style: AppFonts.inter(size: 13, color: AppColors.textSoft, height: 1.5),
          ),
          const SizedBox(height: 24),
          Row(children: [
            Expanded(
              child: GestureDetector(
                onTap: () => context.read<AppState>().acknowledgeUpdate(),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  alignment: Alignment.center,
                  child: Text('Later', style: AppFonts.inter(size: 13, weight: FontWeight.w600, color: AppColors.textSoft)),
                ),
              ),
            ),
            Expanded(
              child: GestureDetector(
                onTap: () async {
                  if (downloadUrl != null) {
                    await launchUrl(Uri.parse(downloadUrl), mode: LaunchMode.externalApplication);
                  }
                  if (context.mounted) context.read<AppState>().acknowledgeUpdate();
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(color: AppColors.gold, borderRadius: BorderRadius.circular(100)),
                  alignment: Alignment.center,
                  child: Text('Update Now', style: AppFonts.inter(size: 13, weight: FontWeight.w700, color: AppColors.inkOnGold)),
                ),
              ),
            ),
          ]),
        ]),
      ),
    );
  }
}
