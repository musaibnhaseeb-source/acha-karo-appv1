import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../state/app_state.dart';
import '../data/deed_catalog.dart';
import '../data/deed_form_fields.dart';
import '../data/guddi_content.dart';
import 'guddi_home.dart';
import 'location_disclosure.dart';

// Rebuilt per the simplified submission design: Photo mode is now the ONLY way to submit — no
// Honor mode (location is asked for via location_disclosure.dart at submit), no free-text or plain
// numeric questions. Only a predefined dropdown remains where one exists (6 of 32 deeds); the
// other 26 are photo-only. Donation-type deeds get specific guidance ("photo of food or a
// receipt") and are always sent to a moderator, same rule enforced in AppState.
class SubmitDeedModal extends StatefulWidget {
  final String type;
  final String? campaignId; // new — tags the resulting deed so campaign-specific roadmap
  // progress can be counted correctly, especially when multiple campaigns run simultaneously
  // Optional Guddi tip shown under the photo picker — e.g. "photograph the deed, not the person"
  // for deeds that involve helping someone (passed in from Home's idea card).
  final GuddiLine? photoHint;
  const SubmitDeedModal({super.key, required this.type, this.campaignId, this.photoHint});
  @override
  State<SubmitDeedModal> createState() => _SubmitDeedModalState();
}

class _SubmitDeedModalState extends State<SubmitDeedModal> {
  // Bytes, not dart:io File — File has no working implementation on Flutter web, so a photo
  // picked there would silently fail to preview or upload. XFile.readAsBytes() is the one
  // picker API that's actually cross-platform.
  Uint8List? photoBytes;
  String? photoFileName;
  final Map<String, String> details = {};
  bool submitting = false;
  bool sharingLocation = false; // drives the "Capturing location…" line

  Future<void> _pickPhoto() async {
    final picker = ImagePicker();
    final choice = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppColors.bg2,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(leading: const Text('📷', style: TextStyle(fontSize: 20)), title: Text('Take a photo', style: AppFonts.inter(size: 14)), onTap: () => Navigator.pop(ctx, 'camera')),
          ListTile(leading: const Text('🖼️', style: TextStyle(fontSize: 20)), title: Text('Choose from gallery', style: AppFonts.inter(size: 14)), onTap: () => Navigator.pop(ctx, 'gallery')),
          const SizedBox(height: 8),
        ]),
      ),
    );
    if (choice == null) return;
    final picked = await picker.pickImage(
      source: choice == 'camera' ? ImageSource.camera : ImageSource.gallery,
      // maxWidth alone only constrains width — for a portrait photo (the common case) that
      // doesn't cap the longer dimension the way the original's "cap the longest side at 800"
      // rule does. maxHeight added too so this is a true bounding-box fit, matching the original
      // regardless of the photo's orientation.
      maxWidth: 800,
      maxHeight: 800,
      imageQuality: 70,
    );
    if (picked != null) {
      final bytes = await picked.readAsBytes();
      if (mounted) setState(() { photoBytes = bytes; photoFileName = picked.name; });
    }
  }

  Future<void> _handleSubmit() async {
    // Location disclosure comes first, before any OS permission prompt. Dismissing it goes back
    // to the form without sending anything.
    final share = await confirmLocationSharing(context, isDonation: donationDeedTypes.contains(widget.type));
    if (share == null || !mounted) return;
    setState(() { submitting = true; sharingLocation = share; });
    final appState = context.read<AppState>();
    final result = await appState.submitPhotoDeed(widget.type, details, photoBytes: photoBytes, photoFileName: photoFileName, campaignId: widget.campaignId, shareLocation: share);
    if (mounted) Navigator.of(context).pop(result);
  }

  @override
  Widget build(BuildContext context) {
    final meta = deedCatalog[widget.type];
    if (meta == null) return const SizedBox.shrink();
    final fields = deedFormFields[widget.type] ?? [];
    final isDonation = donationDeedTypes.contains(widget.type);
    final fieldsFilled = fields.every((f) => (details[f.id] ?? '').isNotEmpty);
    final valid = photoBytes != null && fieldsFilled && !submitting;

    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      maxChildSize: 0.9,
      minChildSize: 0.45,
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
                Row(children: [
                  Container(
                    width: 44, height: 44,
                    decoration: BoxDecoration(shape: BoxShape.circle, color: AppColors.oliveCard),
                    alignment: Alignment.center,
                    child: Text(meta.icon, style: const TextStyle(fontSize: 22)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(meta.name, style: AppFonts.inter(size: 13, weight: FontWeight.w600)),
                      Text('+${meta.points} pts on approval', style: AppFonts.plexMono(size: 10.5)),
                    ]),
                  ),
                ]),
                const SizedBox(height: 16),

                // Compact photo picker/preview — deliberately small, not full-width, per the
                // "resize the picture to small" direction.
                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  GestureDetector(
                    onTap: _pickPhoto,
                    child: Container(
                      width: 84, height: 84,
                      decoration: BoxDecoration(
                        color: AppColors.oliveCard,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0x33F6F5EC)),
                        image: photoBytes != null ? DecorationImage(image: MemoryImage(photoBytes!), fit: BoxFit.cover) : null,
                      ),
                      alignment: Alignment.center,
                      child: photoBytes == null ? Text('📷', style: AppFonts.inter(size: 26)) : null,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(photoBytes == null ? 'Add a photo' : 'Tap to change photo', style: AppFonts.inter(size: 12.5, weight: FontWeight.w600)),
                      const SizedBox(height: 4),
                      Text(
                        isDonation
                            ? 'Please show a photo of the food or a receipt — donations are always reviewed by a moderator.'
                            : 'Just the photo — nothing else to fill in.',
                        style: AppFonts.inter(size: 10.5, color: AppColors.textSoft, height: 1.4),
                      ),
                    ]),
                  ),
                ]),
                if (widget.photoHint != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.fromLTRB(6, 6, 12, 6),
                    decoration: BoxDecoration(color: AppColors.oliveCard, borderRadius: BorderRadius.circular(12)),
                    child: Row(children: [
                      // Guddi "explaining" (chalk) — her tips pose.
                      Image.asset(GuddiPoses.explain, height: 48, fit: BoxFit.contain),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(widget.photoHint!.roman, style: AppFonts.inter(size: 12, weight: FontWeight.w600)),
                          if (widget.photoHint!.en != null)
                            Text(widget.photoHint!.en!, style: AppFonts.inter(size: 10.5, color: AppColors.textSoft)),
                        ]),
                      ),
                    ]),
                  ),
                ],
                const SizedBox(height: 10),
                Text(
                  'Any image deemed inappropriate or harassing may result in your account being flagged for moderator review.',
                  style: AppFonts.inter(size: 9.5, color: const Color(0xFFE39B84), height: 1.4),
                ),

                if (fields.isNotEmpty) ...[
                  const SizedBox(height: 18),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(color: AppColors.oliveCard, borderRadius: BorderRadius.circular(14)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: fields.map((f) => Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text(f.label, style: AppFonts.inter(size: 12, color: AppColors.textSoft)),
                              const SizedBox(height: 6),
                              _SelectField(
                                value: details[f.id],
                                options: f.options,
                                onChanged: (v) => setState(() => details[f.id] = v ?? ''),
                              ),
                            ]),
                          )).toList(),
                    ),
                  ),
                ],

                const SizedBox(height: 18),
                GestureDetector(
                  onTap: valid ? _handleSubmit : null,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(color: valid ? AppColors.gold : AppColors.oliveCard, borderRadius: BorderRadius.circular(14)),
                    alignment: Alignment.center,
                    child: submitting
                        ? SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.inkOnGold))
                        : Text('Submit deed', style: AppFonts.inter(size: 15, weight: FontWeight.w700, color: valid ? AppColors.inkOnGold : AppColors.textSoft)),
                  ),
                ),
                if (submitting && sharingLocation)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text('Capturing location…', textAlign: TextAlign.center, style: AppFonts.inter(size: 10.5, color: AppColors.textSoft)),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _SelectField extends StatelessWidget {
  final String? value;
  final List<String> options;
  final ValueChanged<String?> onChanged;
  const _SelectField({required this.value, required this.options, required this.onChanged});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(color: AppColors.bg2.withOpacity(0.4), borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0x33F6F5EC))),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          hint: Text('Select...', style: AppFonts.inter(size: 12.5, color: AppColors.textSoft.withOpacity(0.6))),
          isExpanded: true,
          dropdownColor: AppColors.bg2,
          style: AppFonts.inter(size: 12.5),
          items: options.map((o) => DropdownMenuItem(value: o, child: Text(o))).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }
}
