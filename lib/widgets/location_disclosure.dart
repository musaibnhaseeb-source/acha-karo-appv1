import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_theme.dart';
import 'guddi_home.dart';

// In-context location disclosure, shown before the app ever asks the OS for location (Play's
// "prominent disclosure" rule). It says what's collected, why, and who can see it. The person
// can submit without location: the deed then goes to a moderator instead of being approved
// straight away. That's the same path a GPS failure already took, so approval logic is unchanged.
//
// Once someone taps "Share location" it's remembered on this device and not asked again (the
// OS permission prompt still applies). "Submit without location" isn't remembered, so the choice
// is offered again on the next deed, which also leaves a way to change your mind. Returns true to
// share, false to submit without location, or null if the dialog was dismissed (the caller goes
// back to the form and sends nothing).
const _acceptedKey = 'ak_location_disclosure_accepted';

Future<bool?> confirmLocationSharing(BuildContext context, {required bool isDonation}) async {
  SharedPreferences? prefs;
  try {
    prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_acceptedKey) ?? false) return true;
  } catch (_) {
    // Storage unavailable: just show the disclosure again.
  }
  if (!context.mounted) return null;
  final choice = await showDialog<bool>(
    context: context,
    builder: (_) => _LocationDisclosureDialog(isDonation: isDonation),
  );
  if (choice == true) {
    try {
      await prefs?.setBool(_acceptedKey, true);
    } catch (_) {
      // Best-effort. Worst case, the disclosure is shown once more.
    }
  }
  return choice;
}

class _LocationDisclosureDialog extends StatelessWidget {
  final bool isDonation;
  const _LocationDisclosureDialog({required this.isDonation});

  Widget _point(String label, String text) => Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: AppFonts.inter(size: 12, weight: FontWeight.w700)),
          const SizedBox(height: 2),
          Text(text, style: AppFonts.inter(size: 12, color: AppColors.textSoft, height: 1.4)),
        ]),
      );

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.bg2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      content: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Center(child: Image.asset(GuddiPoses.explain, height: 80, fit: BoxFit.contain)),
          const SizedBox(height: 10),
          Text('Share your location with this acha kaam?', style: AppFonts.fraunces(size: 16, weight: FontWeight.w600)),
          _point('What we collect',
              "Your phone's approximate location (about 100 m) at the moment you submit, saved with this acha kaam. Only when you submit, never in the background."),
          _point('Why', 'It helps a moderator check that the acha kaam really happened.'),
          _point('Who can see it',
              // UNCONFIRMED: depends on the live deeds RLS (only the owner and moderators can select
              // gps_lat/gps_lng). Pending confirmation via the Supervisor/Musa.
              "Only you and Acha Karo moderators. It isn't shown on your profile, on leaderboards or to friends."),
          _point(
            'If you say no',
            isDonation
                ? 'You can still submit. Donations are always checked by a moderator, so nothing changes.'
                : "You can still submit. A moderator checks it first, so your points arrive once it's approved.",
          ),
        ]),
      ),
      actionsAlignment: MainAxisAlignment.spaceBetween,
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text('Submit without location', style: AppFonts.inter(size: 13, color: AppColors.textSoft)),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: Text('Share location', style: AppFonts.inter(size: 13, weight: FontWeight.w700, color: AppColors.gold)),
        ),
      ],
    );
  }
}
