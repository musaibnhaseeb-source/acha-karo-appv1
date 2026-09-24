import 'package:shared_preferences/shared_preferences.dart';

// Device-local memory for the first-deed Guddi tour — nothing here ever touches Supabase.
// Keyed per account (by the auth user id, which never leaves the device here) so a second
// person signing in on the same phone still gets their own tour. Any storage failure is
// treated as "not seen", which at worst shows the tour once more, never blocks the app.
class OnboardingStore {
  static String _tourKey(String uid) => 'ak_first_deed_tour_done_$uid';

  static Future<bool> isTourDone(String uid) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_tourKey(uid)) ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<void> markTourDone(String uid) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_tourKey(uid), true);
    } catch (_) {
      // Best-effort — worst case the tour is offered once more on a later open.
    }
  }
}
