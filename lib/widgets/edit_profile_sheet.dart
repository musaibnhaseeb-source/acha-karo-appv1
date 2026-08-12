import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../state/app_state.dart';
import 'avatar_picker.dart';
import 'labeled_text_field.dart';

// New — Edit Profile relocated here from being inline on Profile tab, per the pilot scope: one
// popup, reachable from both the Side Sheet (top of the menu) and Profile's own edit button,
// rather than duplicating the same fields/validation in two places. Real database write now too
// — a genuine bug was found and fixed alongside this move: saving never actually reached
// Supabase before, only local state, so a name change would look successful but silently vanish
// on the next app open.
class EditProfileSheet extends StatefulWidget {
  const EditProfileSheet({super.key});
  @override
  State<EditProfileSheet> createState() => _EditProfileSheetState();
}

class _EditProfileSheetState extends State<EditProfileSheet> {
  late TextEditingController nameController;
  late TextEditingController phoneController;
  late TextEditingController emailController;
  final nameFocus = FocusNode();
  final emailFocus = FocusNode();
  String? nameError;
  String? emailError;
  File? photoFile;
  bool saving = false;

  @override
  void initState() {
    super.initState();
    final user = context.read<AppState>().user;
    nameController = TextEditingController(text: user.name);
    phoneController = TextEditingController(text: user.phone ?? '');
    emailController = TextEditingController(text: user.email ?? '');
    photoFile = user.avatarFile;

    nameFocus.addListener(() {
      if (!nameFocus.hasFocus) _validateName();
    });
    emailFocus.addListener(() {
      if (!emailFocus.hasFocus) _validateEmail();
    });
  }

  @override
  void dispose() {
    nameController.dispose();
    phoneController.dispose();
    emailController.dispose();
    nameFocus.dispose();
    emailFocus.dispose();
    super.dispose();
  }

  bool _validateName() {
    final valid = nameController.text.trim().isNotEmpty;
    setState(() => nameError = valid ? null : 'Name can\'t be empty');
    return valid;
  }

  bool _validateEmail() {
    final text = emailController.text.trim();
    final valid = text.isEmpty || text.contains('@');
    setState(() => emailError = valid ? null : 'Enter a valid email address');
    return valid;
  }

  Future<void> _save() async {
    final nameOk = _validateName();
    final emailOk = _validateEmail();
    if (!nameOk || !emailOk) return;
    setState(() => saving = true);
    final error = await context.read<AppState>().updateProfile(
          name: nameController.text.trim(),
          phone: phoneController.text.trim().isEmpty ? null : phoneController.text.trim(),
          email: emailController.text.trim().isEmpty ? null : emailController.text.trim(),
          avatarFile: photoFile,
          removeAvatar: photoFile == null,
        );
    if (!mounted) return;
    setState(() => saving = false);
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
    } else {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profile updated.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      maxChildSize: 0.9,
      minChildSize: 0.5,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(color: AppColors.bg2, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
          child: SingleChildScrollView(
            controller: scrollController,
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 30),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Edit profile', style: AppFonts.fraunces(size: 17, weight: FontWeight.w600)),
                const SizedBox(height: 8),
                Text(
                  'Your photo stays on this device and is never uploaded. Only your name is ever shown to others.',
                  style: AppFonts.inter(size: 11.5, color: AppColors.textSoft, height: 1.5),
                ),
                const SizedBox(height: 20),
                Center(
                  child: AvatarPicker(
                    photoFile: photoFile,
                    size: 84,
                    onPhotoPicked: (file) => setState(() => photoFile = file),
                    onPhotoRemoved: () => setState(() => photoFile = null),
                  ),
                ),
                const SizedBox(height: 24),
                LabeledTextField(label: 'Name', required: true, controller: nameController, focusNode: nameFocus, errorText: nameError),
                const SizedBox(height: 14),
                LabeledTextField(label: 'Phone', hint: '+92 300 1234567', controller: phoneController, keyboardType: TextInputType.phone, inputFormatters: phoneInputFormatters),
                const SizedBox(height: 14),
                LabeledTextField(label: 'Email', controller: emailController, keyboardType: TextInputType.emailAddress, focusNode: emailFocus, errorText: emailError),
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
                      onTap: saving ? null : _save,
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        decoration: BoxDecoration(color: saving ? AppColors.oliveCardStrong : AppColors.gold, borderRadius: BorderRadius.circular(13)),
                        alignment: Alignment.center,
                        child: Text(saving ? 'Saving…' : 'Save', style: AppFonts.inter(size: 13.5, weight: FontWeight.w700, color: saving ? AppColors.textSoft : AppColors.inkOnGold)),
                      ),
                    ),
                  ),
                ]),
              ],
            ),
          ),
        );
      },
    );
  }
}
