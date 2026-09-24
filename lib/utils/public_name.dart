// How ANOTHER user's name is shown anywhere in the app (leaderboards, Town Voice, friends):
// first name + last initial, e.g. "Ayesha Khan" → "Ayesha K.". A single-word name is shown as
// is. Your own name on your own profile is never passed through this.
//
// Display-side only: get_public_profiles / get_weekly_leaderboard still return the full name
// to any caller until the server-side change in docs/proposed_rpc_name_protection.sql lands.
// Once the server returns "Ayesha K." itself, this is a harmless no-op on that input.

String publicDisplayName(String? raw, {String fallback = 'User'}) {
  final parts = (raw ?? '').trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
  if (parts.isEmpty) return fallback;
  if (parts.length == 1) return parts.first;
  // First rune, not code unit, so non-Latin (e.g. Urdu) and surrogate-pair letters stay whole.
  final initial = String.fromCharCode(parts.last.runes.first).toUpperCase();
  return '${parts.first} $initial.';
}
