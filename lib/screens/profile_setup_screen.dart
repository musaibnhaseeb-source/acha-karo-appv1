import 'dart:io';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../theme/app_theme.dart';
import '../widgets/avatar_picker.dart';
import '../widgets/labeled_text_field.dart';

typedef SetupCompleteCallback = void Function({
  required String name,
  required String gender,
  required String dob,
  required String city,
  String? phone,
  File? avatarFile,
});

int? _calcAge(DateTime? dob) {
  if (dob == null) return null;
  final today = DateTime.now();
  int age = today.year - dob.year;
  if (today.month < dob.month || (today.month == dob.month && today.day < dob.day)) age--;
  return age;
}

// Ported from ProfileSetupScreen.jsx (Next.js port) / #profileSetupScreen in the original.
// Same required fields, same 14+ validation, same exact privacy disclaimer copy.
class ProfileSetupScreen extends StatefulWidget {
  final SetupCompleteCallback onComplete;
  const ProfileSetupScreen({super.key, required this.onComplete});
  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  final nameController = TextEditingController();
  final phoneController = TextEditingController();
  String? gender;
  DateTime? dob;
  String city = 'Islamabad';
  bool showDobInfo = false;
  // Local-device-only, same explicit privacy requirement as the original — never uploaded,
  // never sent to any backend, never stored server-side once Supabase is connected either.
  File? photoFile;

  static const cities = ['Islamabad', 'Lahore', 'Karachi', 'Faisalabad', 'Peshawar', 'Quetta'];
  static const genders = [
    ('female', 'Female'),
    ('male', 'Male'),
    ('other', 'Other'),
    ('prefer_not', 'Prefer not to say'),
  ];

  @override
  void dispose() {
    // Wasn't here before — a pre-existing gap across all 3 controllers, not just the new one.
    // Fixed while already touching this class.
    nameController.dispose();
    phoneController.dispose();
    super.dispose();
  }

  bool get valid {
    final age = _calcAge(dob);
    return nameController.text.trim().isNotEmpty && gender != null && dob != null && age != null && age >= 14;
  }

  void _confirmAbandonSetup(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.bg2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text('Abandon setup?', style: AppFonts.fraunces(size: 16, weight: FontWeight.w600)),
        content: Text("You'll be signed out, and will need to sign in again to try setup once more.", style: AppFonts.inter(size: 12.5, color: AppColors.textSoft)),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: Text('Stay', style: AppFonts.inter(size: 13, color: AppColors.textSoft))),
          TextButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              // RootScreen's auth-state listener (in main.dart) handles clearing local state and
              // navigating back to Login once this fires — same proven mechanism as Settings'
              // sign-out, nothing else needed here.
              await Supabase.instance.client.auth.signOut();
            },
            child: Text('Abandon', style: AppFonts.inter(size: 13, weight: FontWeight.w700, color: const Color(0xFFE39B84))),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 40, 24, 30),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // New — real bug fixed here: there was no way to abandon this screen at all. Someone
          // signed up with the wrong email, or who just wanted to back out, had no path except
          // force-closing the app. This reuses the same sign-out mechanism already proven in
          // Settings — the person is already authenticated at this point (OTP already verified),
          // so "back" here genuinely means abandoning the signup, not stepping to a prior screen.
          GestureDetector(
            onTap: () => _confirmAbandonSetup(context),
            child: const Icon(Icons.arrow_back, color: AppColors.text, size: 22),
          ),
          const SizedBox(height: 16),
          Text('ONE LAST STEP', style: AppFonts.plexMono(size: 10)),
          const SizedBox(height: 6),
          Text('Tell us who you are', style: AppFonts.fraunces(size: 22, weight: FontWeight.w600)),
          const SizedBox(height: 8),
          Text('Name, gender, date of birth, and city are required — phone and photo are optional.',
              style: AppFonts.inter(size: 12, color: AppColors.textSoft)),
          const SizedBox(height: 20),

          Center(
            child: AvatarPicker(
              photoFile: photoFile,
              onPhotoPicked: (file) => setState(() => photoFile = file),
              onPhotoRemoved: () => setState(() => photoFile = null),
            ),
          ),
          Center(child: Padding(padding: const EdgeInsets.only(top: 6), child: Text('Photo (optional)', style: AppFonts.inter(size: 11, color: AppColors.textSoft)))),
          const SizedBox(height: 18),

          LabeledTextField(
            label: 'Your name',
            required: true,
            hint: 'e.g. Amina Rashid',
            controller: nameController,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 14),

          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                _label('Gender', required: true),
                _dropdown(
                  value: gender,
                  hint: 'Select',
                  items: genders,
                  onChanged: (v) => setState(() => gender = v),
                ),
              ]),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  _label('Date of birth', required: true),
                  const SizedBox(width: 6),
                  GestureDetector(
                    onTap: () => setState(() => showDobInfo = !showDobInfo),
                    child: Container(
                      width: 16, height: 16,
                      decoration: BoxDecoration(shape: BoxShape.circle, color: AppColors.oliveCardStrong, border: Border.all(color: AppColors.textSoft.withOpacity(0.25))),
                      alignment: Alignment.center,
                      child: Text('i', style: AppFonts.plexMono(size: 9.5)),
                    ),
                  ),
                ]),
                // Real bug fixed here: _label() already has its own 8px bottom padding built
                // in (used correctly, alone, by Gender's column). This extra SizedBox added a
                // SECOND 8px gap on top of that same padding, only on this side — giving DOB
                // double the spacing Gender had before its control, which is exactly why the
                // date box sat lower than the dropdown instead of lining up with it.
                GestureDetector(
                  onTap: () async {
                    final now = DateTime.now();
                    // Exact calendar-based 14-years-ago date, not an approximation — 365*14
                    // doesn't account for leap years, which let the picker allow dates a couple
                    // of days short of a true 14th birthday, disagreeing with _calcAge() below.
                    final maxDate = DateTime(now.year - 14, now.month, now.day);
                    final picked = await showDatePicker(
                      context: context,
                      firstDate: DateTime(1930),
                      lastDate: maxDate,
                      initialDate: maxDate,
                    );
                    if (picked != null) setState(() => dob = picked);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(color: AppColors.oliveCard, borderRadius: BorderRadius.circular(12)),
                    child: Text(
                      dob == null ? 'Select date' : '${dob!.year}-${dob!.month.toString().padLeft(2, '0')}-${dob!.day.toString().padLeft(2, '0')}',
                      style: AppFonts.inter(size: 13, color: dob == null ? AppColors.textSoft.withOpacity(0.6) : AppColors.text),
                    ),
                  ),
                ),
                if (showDobInfo)
                  Container(
                    margin: const EdgeInsets.only(top: 6),
                    padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
                    decoration: BoxDecoration(color: AppColors.oliveDeep, borderRadius: BorderRadius.circular(10)),
                    child: Text(
                      'We use your date of birth to verify eligibility, personalize your experience, generate anonymous demographic insights, and support future community initiatives such as birthday recognition. Your date of birth is kept confidential.',
                      style: AppFonts.inter(size: 9.5, color: AppColors.textSoft, height: 1.5),
                    ),
                  ),
              ]),
            ),
          ]),
          const SizedBox(height: 10),
          Text(
            'Gender and age are private and are not visible to others.\nNeither can be changed later, user must be 14+.',
            style: AppFonts.inter(size: 9.5, color: AppColors.textSoft, height: 1.4),
          ),
          const SizedBox(height: 14),

          _label('City', required: true),
          _dropdown(
            value: city,
            hint: 'Select',
            items: cities.map((c) => (c, c)).toList(),
            onChanged: (v) => setState(() => city = v ?? city),
          ),
          const SizedBox(height: 14),

          LabeledTextField(
            label: 'Phone number',
            suffix: '(optional)',
            hint: '+92 300 1234567',
            controller: phoneController,
            keyboardType: TextInputType.phone,
            inputFormatters: phoneInputFormatters,
          ),
          const SizedBox(height: 14),

          GestureDetector(
            onTap: valid
                ? () => widget.onComplete(
                      name: nameController.text.trim(),
                      gender: gender!,
                      dob: dob!.toIso8601String(),
                      city: city,
                      phone: phoneController.text.trim().isEmpty ? null : phoneController.text.trim(),
                      avatarFile: photoFile,
                    )
                : null,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: valid ? AppColors.gold : AppColors.oliveCard,
                borderRadius: BorderRadius.circular(14),
              ),
              alignment: Alignment.center,
              child: Text('Continue', style: AppFonts.inter(size: 15, weight: FontWeight.w700, color: valid ? AppColors.inkOnGold : AppColors.textSoft)),
            ),
          ),
          const SizedBox(height: 10),
          Center(child: Text('You can change these later from your Profile.', style: AppFonts.inter(size: 11, color: AppColors.textSoft))),
        ],
      ),
    );
  }

  Widget _label(String text, {bool required = false, String? suffix}) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(children: [
          Text(text, style: AppFonts.inter(size: 12, color: AppColors.textSoft)),
          if (required) Text(' *', style: AppFonts.inter(size: 12, color: AppColors.rust)),
          if (suffix != null) Text(' $suffix', style: AppFonts.inter(size: 11, color: AppColors.textSoft)),
        ]),
      );

  Widget _dropdown({required String? value, required String hint, required List<(String, String)> items, required ValueChanged<String?> onChanged}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(color: AppColors.oliveCard, borderRadius: BorderRadius.circular(12)),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          hint: Text(hint, style: AppFonts.inter(size: 13, color: AppColors.textSoft.withOpacity(0.6))),
          isExpanded: true,
          dropdownColor: AppColors.bg2,
          style: AppFonts.inter(size: 13),
          items: items.map((i) => DropdownMenuItem(value: i.$1, child: Text(i.$2))).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }
}
