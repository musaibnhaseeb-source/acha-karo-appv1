import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../state/app_state.dart';
import '../widgets/avatar_picker.dart';
import '../widgets/labeled_text_field.dart';

// Ported from #editProfileModal / saveEditProfile() in the original — same fields (Photo, Name,
// Phone, Email), same privacy disclaimer copy. Gender/DOB/City are deliberately not here — the
// original's setup-screen rule ("cannot be changed later") is enforced simply by not exposing
// those fields on this screen at all, not by some separate lock mechanism.
class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});
  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  late TextEditingController nameController;
  late TextEditingController phoneController;
  late TextEditingController emailController;
  File? photoFile;

  @override
  void initState() {
    super.initState();
    final user = context.read<AppState>().user;
    nameController = TextEditingController(text: user.name);
    phoneController = TextEditingController(text: user.phone ?? '');
    emailController = TextEditingController(text: user.email ?? '');
    photoFile = user.avatarFile;
  }

  @override
  void dispose() {
    nameController.dispose();
    phoneController.dispose();
    emailController.dispose();
    super.dispose();
  }

  void _save(BuildContext context) {
    context.read<AppState>().updateProfile(
          name: nameController.text.trim(),
          phone: phoneController.text.trim().isEmpty ? null : phoneController.text.trim(),
          email: emailController.text.trim().isEmpty ? null : emailController.text.trim(),
          avatarFile: photoFile,
          removeAvatar: photoFile == null,
        );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(icon: const Icon(Icons.close, color: AppColors.text), onPressed: () => Navigator.of(context).pop()),
        title: Text('Edit your profile', style: AppFonts.inter(size: 14, weight: FontWeight.w600)),
        centerTitle: true,
      ),
      body: Container(
        decoration: const BoxDecoration(gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [AppColors.bg2, AppColors.bg1])),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 30),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Update your photo, name, phone, or email — only your name is ever shown to others. Your photo stays on this device and is never uploaded or visible to admins.',
                  style: AppFonts.inter(size: 11.5, color: AppColors.textSoft, height: 1.5),
                ),
                const SizedBox(height: 20),
                Center(
                  child: AvatarPicker(
                    photoFile: photoFile,
                    onPhotoPicked: (file) => setState(() => photoFile = file),
                    onPhotoRemoved: () => setState(() => photoFile = null),
                    size: 84,
                  ),
                ),
                const SizedBox(height: 24),
                LabeledTextField(label: 'Name', required: true, controller: nameController),
                const SizedBox(height: 14),
                LabeledTextField(label: 'Phone', hint: '+92 300 1234567', controller: phoneController, keyboardType: TextInputType.phone),
                const SizedBox(height: 14),
                LabeledTextField(label: 'Email', controller: emailController, keyboardType: TextInputType.emailAddress),
                const SizedBox(height: 24),
                Row(children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => Navigator.of(context).pop(),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        decoration: BoxDecoration(color: AppColors.oliveCard, borderRadius: BorderRadius.circular(13), border: Border.all(color: const Color(0x29F6F5EC))),
                        alignment: Alignment.center,
                        child: Text('Cancel', style: AppFonts.inter(size: 13.5, weight: FontWeight.w600)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => _save(context),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        decoration: BoxDecoration(color: AppColors.gold, borderRadius: BorderRadius.circular(13)),
                        alignment: Alignment.center,
                        child: Text('Save', style: AppFonts.inter(size: 13.5, weight: FontWeight.w700, color: AppColors.inkOnGold)),
                      ),
                    ),
                  ),
                ]),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
