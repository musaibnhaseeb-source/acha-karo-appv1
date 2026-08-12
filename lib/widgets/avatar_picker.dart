import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../theme/app_theme.dart';

// Reusable circular photo picker — used by ProfileSetupScreen and ProfileScreen directly. Local-
// device-only photo, same explicit privacy requirement throughout this whole project — never
// uploaded, never sent to any backend. The remove (🗑️) badge only appears when a photo is
// actually set, matching the original's editProfileRemoveBtn (hidden until a photo exists).
class AvatarPicker extends StatelessWidget {
  final File? photoFile;
  final ValueChanged<File> onPhotoPicked;
  final VoidCallback? onPhotoRemoved;
  final double size;
  final String placeholderEmoji;

  const AvatarPicker({
    super.key,
    required this.photoFile,
    required this.onPhotoPicked,
    this.onPhotoRemoved,
    this.size = 72,
    this.placeholderEmoji = '🙂',
  });

  Future<void> _pick(BuildContext context) async {
    final picker = ImagePicker();
    final choice = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppColors.bg2,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(
            leading: const Text('📷', style: TextStyle(fontSize: 20)),
            title: Text('Take a photo', style: AppFonts.inter(size: 14)),
            onTap: () => Navigator.pop(ctx, 'camera'),
          ),
          ListTile(
            leading: const Text('🖼️', style: TextStyle(fontSize: 20)),
            title: Text('Choose from gallery', style: AppFonts.inter(size: 14)),
            onTap: () => Navigator.pop(ctx, 'gallery'),
          ),
          const SizedBox(height: 8),
        ]),
      ),
    );
    if (choice == null) return;
    final picked = await picker.pickImage(
      source: choice == 'camera' ? ImageSource.camera : ImageSource.gallery,
      // maxWidth alone only constrains width — added maxHeight too so this is a true
      // bounding-box fit (caps whichever side is longer), matching the original's "cap the
      // longest side at 800" rule regardless of the photo's orientation.
      maxWidth: 800,
      maxHeight: 800,
      imageQuality: 70,
    );
    if (picked != null) onPhotoPicked(File(picked.path));
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _pick(context),
      child: Stack(clipBehavior: Clip.none, children: [
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.oliveCardStrong,
            border: Border.all(color: AppColors.textSoft.withOpacity(0.35), width: 2),
            image: photoFile != null ? DecorationImage(image: FileImage(photoFile!), fit: BoxFit.cover) : null,
          ),
          alignment: Alignment.center,
          child: photoFile == null ? Text(placeholderEmoji, style: TextStyle(fontSize: size * 0.36)) : null,
        ),
        Positioned(
          bottom: -2, right: -2,
          child: Container(
            width: size * 0.33, height: size * 0.33,
            decoration: BoxDecoration(shape: BoxShape.circle, color: AppColors.gold, border: Border.all(color: AppColors.bg2, width: 2)),
            alignment: Alignment.center,
            child: Text('＋', style: AppFonts.inter(size: size * 0.15, weight: FontWeight.w700, color: AppColors.inkOnGold)),
          ),
        ),
        if (photoFile != null && onPhotoRemoved != null)
          Positioned(
            top: -2, right: -2,
            child: GestureDetector(
              onTap: onPhotoRemoved,
              child: Container(
                width: size * 0.33, height: size * 0.33,
                decoration: BoxDecoration(shape: BoxShape.circle, color: AppColors.rust, border: Border.all(color: AppColors.bg2, width: 2)),
                alignment: Alignment.center,
                child: Text('🗑️', style: TextStyle(fontSize: size * 0.14)),
              ),
            ),
          ),
      ]),
    );
  }
}
