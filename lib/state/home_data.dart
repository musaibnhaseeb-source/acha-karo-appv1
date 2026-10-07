import 'package:supabase_flutter/supabase_flutter.dart';

// Everything Home needs to render for a signed-in user, fetched in ONE parallel round trip
// (wave 1 of the cold start). Every query is keyed on the session uid only, so none of them
// waits for another. Holds the raw rows (plain JSON maps) so it can later be cached on the
// device as-is for offline mode; AppState.applyHomeData() turns it into app state.
//
// Wave 2 (leaderboard, feedback, notifications) is not here: Home renders without it and
// AppState loads it in the background afterwards.
class HomeData {
  final Map<String, dynamic> profile;
  // null = that read failed. Same rule as before the parallel load: only the profile is required,
  // every other read failing still lets the person into the app.
  final List<Map<String, dynamic>>? deeds;
  final List<Map<String, dynamic>>? badges;
  final List<Map<String, dynamic>>? frozenBadges;
  final List<Map<String, dynamic>>? hallOfFameClaims;
  final List<Map<String, dynamic>>? membership;

  const HomeData({
    required this.profile,
    required this.deeds,
    required this.badges,
    required this.frozenBadges,
    required this.hallOfFameClaims,
    required this.membership,
  });

  // Explicit columns: only what the app reads. vehicle_skins(icon) is the equipped skin, and
  // joined_at / last_acked_update_id are for the update check, so neither needs its own query.
  static const profileColumns =
      'id, name, email, phone, city, points, wallpaper_swatch_index, active_skin_id, joined_at, last_acked_update_id, vehicle_skins(icon)';
  // No photo_url or GPS: Home and badges never use them.
  static const deedColumns = 'id, type, points, created_at, status, campaign_id';

  // Offline mode (home_cache.dart) keeps the last good HomeData on the phone. Email and phone are
  // left out on purpose: nothing offline shows them (Edit profile is unavailable offline).
  static const _notCached = {'email', 'phone'};

  Map<String, dynamic> toCacheJson() => {
        'profile': {for (final e in profile.entries) if (!_notCached.contains(e.key)) e.key: e.value},
        'deeds': deeds,
        'badges': badges,
        'frozenBadges': frozenBadges,
        'hallOfFameClaims': hallOfFameClaims,
        'membership': membership,
      };

  static List<Map<String, dynamic>>? _rows(Object? v) => v == null ? null : [for (final r in v as List) Map<String, dynamic>.from(r as Map)];

  factory HomeData.fromCacheJson(Map<String, dynamic> j) => HomeData(
        profile: Map<String, dynamic>.from(j['profile'] as Map),
        deeds: _rows(j['deeds']),
        badges: _rows(j['badges']),
        frozenBadges: _rows(j['frozenBadges']),
        hallOfFameClaims: _rows(j['hallOfFameClaims']),
        membership: _rows(j['membership']),
      );

  // Returns null when the account has no profile row (new user, goes to Setup). Throws if the
  // profile read itself fails, so the cold-start loader can show the offline state.
  static Future<HomeData?> fetch(SupabaseClient client, String uid) async {
    Future<List<Map<String, dynamic>>?> soft(Future<List<Map<String, dynamic>>> q) => q.then<List<Map<String, dynamic>>?>((rows) => rows, onError: (_) => null);

    final profileQ = client.from('profiles').select(profileColumns).eq('id', uid).limit(1);
    final deedsQ = soft(client.from('deeds').select(deedColumns).eq('user_id', uid).order('created_at'));
    final badgesQ = soft(client.from('user_badges').select('badge_id').eq('user_id', uid));
    final frozenQ = soft(client.from('badge_definitions').select('id').eq('frozen', true));
    final hofQ = soft(client.from('hall_of_fame_claims').select('campaign_id').eq('user_id', uid));
    final membershipQ = soft(client.from('membership_numbers').select('membership_number').eq('user_id', uid).limit(1));

    // All six are in flight at once; only the profile read can throw.
    final profileRows = await profileQ;
    final (deeds, badges, frozen, hof, membership) = await (deedsQ, badgesQ, frozenQ, hofQ, membershipQ).wait;
    if (profileRows.isEmpty) return null;
    return HomeData(
      profile: profileRows.first,
      deeds: deeds,
      badges: badges,
      frozenBadges: frozen,
      hallOfFameClaims: hof,
      membership: membership,
    );
  }
}
