import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

// Extracted out of home_screen.dart so Profile can use the exact same tile dimensions and
// styling — per direction, Skins/Limited Edition/Badges should match Home's tile sizing rather
// than a smaller, differently-styled container. Home's own usage is unaffected.
class BigTile extends StatelessWidget {
  final String? icon;
  final Widget? customIcon; // new — for campaigns, which can have image/GIF icons via
  // CampaignIcon, not just a simple text emoji. Exactly one of icon/customIcon should be set.
  final String name;
  final String description;
  final VoidCallback? onTap;
  const BigTile({super.key, this.icon, this.customIcon, required this.name, required this.description, this.onTap});

  static const double height = 92;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        height: height,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [AppColors.gold.withOpacity(0.12), AppColors.oliveCard]),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.gold.withOpacity(0.28)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            customIcon ?? Text(icon ?? '', style: const TextStyle(fontSize: 42)),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: AppFonts.fraunces(size: 16, weight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 3),
                  Text(description, style: AppFonts.inter(size: 11, color: AppColors.textSoft), maxLines: 2, overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
