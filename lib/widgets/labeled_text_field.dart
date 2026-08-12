import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';

// Shared phone formatter — digits, a leading '+' (for country code), and spaces only. Used by
// both Profile and Profile Setup so the rule is identical everywhere a phone number is entered,
// not reimplemented per-screen.
final List<TextInputFormatter> phoneInputFormatters = [
  FilteringTextInputFormatter.allow(RegExp(r'[0-9+ ]')),
];

// Reusable labeled input — same visual pattern used for Name/Email/Phone throughout the
// original (the .email-field CSS class, despite the name, is the general-purpose text input
// style used for all of these, not just literal email fields). Used today by LoginScreen (email)
// and ProfileSetupScreen (name, phone); intended for the Profile tab / Edit Profile modal too.
class LabeledTextField extends StatelessWidget {
  final String label;
  final bool required;
  final String? suffix;
  final String? hint;
  final TextEditingController? controller;
  final TextInputType? keyboardType;
  final ValueChanged<String>? onChanged;
  final List<TextInputFormatter>? inputFormatters;
  final bool enabled;
  final String? errorText;
  final FocusNode? focusNode;

  const LabeledTextField({
    super.key,
    required this.label,
    this.required = false,
    this.suffix,
    this.hint,
    this.controller,
    this.keyboardType,
    this.onChanged,
    this.inputFormatters,
    this.enabled = true,
    this.errorText,
    this.focusNode,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Text(label, style: AppFonts.inter(size: 12, color: AppColors.textSoft)),
          if (required) Text(' *', style: AppFonts.inter(size: 12, color: AppColors.rust)),
          if (suffix != null) Text(' $suffix', style: AppFonts.inter(size: 11, color: AppColors.textSoft)),
        ]),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 4),
          decoration: BoxDecoration(
            color: enabled ? AppColors.oliveCard : AppColors.oliveCard.withOpacity(0.5),
            borderRadius: BorderRadius.circular(13),
            border: Border.all(color: errorText != null ? AppColors.rust.withOpacity(0.6) : const Color(0x33F6F5EC)),
          ),
          child: TextField(
            controller: controller,
            focusNode: focusNode,
            keyboardType: keyboardType,
            onChanged: onChanged,
            inputFormatters: inputFormatters,
            enabled: enabled,
            style: AppFonts.inter(size: 14, color: enabled ? AppColors.text : AppColors.textSoft),
            decoration: InputDecoration(
              border: InputBorder.none,
              isDense: true,
              hintText: hint,
              hintStyle: AppFonts.inter(size: 14, color: AppColors.textSoft.withOpacity(0.5)),
            ),
          ),
        ),
        if (errorText != null)
          Padding(
            padding: const EdgeInsets.only(top: 5, left: 2),
            child: Text(errorText!, style: AppFonts.inter(size: 10.5, color: AppColors.rust)),
          ),
      ],
    );
  }
}
