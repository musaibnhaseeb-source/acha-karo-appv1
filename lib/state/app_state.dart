import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show Color;
import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:geolocator/geolocator.dart';
import '../data/deed_catalog.dart';
import '../utils/public_name.dart';
import '../data/badges.dart';
import '../data/tiers.dart';
import '../utils/notifications.dart';
import '../data/remote_config.dart';
import '../utils/app_version.dart';
import '../utils/image_metadata.dart';

const Duration cooldownDuration = Duration(hours: 1); // same 1hr cooldown as the original

class RealLeaderboardEntry {
  final String id;
  final String name;
  final String city;
  final int points;
  final int badgeCount;
  const RealLeaderboardEntry({required this.id, required this.name, required this.city, required this.points, required this.badgeCount});
}

class CityDeedCount {
  final String city;
  final int count;
  const CityDeedCount({required this.city, required this.count});
}

class DeedLogEntry {
  final String? id; // Supabase row id once synced — null if the write hasn't completed/failed
  final String type;
  final int points;
  final int day; // still used for simDay-based testing (Simulator's Next Day/Week), NOT for
  // real calendar filtering anymore — see createdAt below for that.
  final DateTime createdAt; // Real bug fixed here: Achievements' "Today"/"This Week" filtering
  // was comparing d.day == simDay, but simDay is a purely local, fictional testing counter with
  // no relationship to real dates — and loaded historical deeds were deliberately tagged day: 0
  // (to fix an earlier milestone-miscounting bug), meaning they could NEVER match simDay again.
  // Net effect: any deed from a previous session silently vanished from "Today"/"This Week" the
  // moment the app was reopened, even though it genuinely happened today. This field is the
  // real fix — actual calendar-date filtering, independent of the simDay hack entirely.
  final String status; // 'approved' | 'pending' | 'rejected'
  final String? campaignId; // new — which campaign this deed was submitted through, if any.
  // Needed so roadmap progress can be counted correctly per-campaign, especially with multiple
  // campaigns potentially running simultaneously — real gap identified and fixed here, not
  // present when progress was only ever filtered by date.
  DeedLogEntry({this.id, required this.type, required this.points, required this.day, required this.createdAt, required this.status, this.campaignId});
}

class ModerationQueueItem {
  final String id;
  final String type;
  final int points;
  final int day;
  final String reason;
  final String? photoUrl; // reserved for a real Supabase-hosted URL once that exists
  final Uint8List? photoFile; // the actual local photo, for now — was never being passed through
  // at all before this fix (SubmitDeedModal required a photo to enable Submit, but never actually
  // sent the picked photo anywhere), so a moderator had nothing to review. Compressed the same
  // way as everywhere else (longest side capped at 800px, JPEG 70%) before it ever gets here.
  // Bytes, not dart:io File — this needs to display on web too (simulator preview).
  final String? evidence;
  final String? gps;
  ModerationQueueItem({required this.id, required this.type, required this.points, required this.day, required this.reason, this.photoUrl, this.photoFile, this.evidence, this.gps});
}

// Result of a submission — lets the UI layer sequence the right animations/messaging without
// needing to separately re-derive "was this flagged" from a bare TierDef?/null return.
class SubmitResult {
  final bool flagged;
  final TierDef? leveledUpTier;
  final List<int> newMilestones;
  final bool blockedByCooldown; // new — see submitPhotoDeed for why this needed a real, data-layer check
  const SubmitResult({required this.flagged, required this.leveledUpTier, required this.newMilestones, this.blockedByCooldown = false});
}

// In-app notifications, loaded from the real notifications table (e.g. deed approved/rejected by
// a moderator in the admin dashboard, feedback responses).
class AppNotification {
  final String id;
  final String type; // 'feedback' | 'taskActioned' — matches the original's two types
  final String title;
  final String body;
  final int day;
  bool read;
  AppNotification({required this.id, required this.type, required this.title, required this.body, required this.day, this.read = false});
}

class UserProfile {
  String name;
  int points;
  int streak;
  int lastLogDay;
  String city;
  List<String> badges;
  File? avatarFile; // local-device-only, per the explicit privacy requirement — never uploaded
  int joinDay;
  String? gender; // private — never shown to other users
  String? dob; // private — never shown to other users
  String? phone;
  String? email; // only collected in Edit Profile, not at signup — matches the original exactly
  // Empty defaults — the real values always come from the profiles row (or Profile Setup).
  UserProfile({
    this.name = '',
    this.points = 0,
    this.streak = 0,
    this.lastLogDay = 0,
    this.city = '',
    List<String>? badges,
    this.avatarFile,
    this.joinDay = 1,
    this.gender,
    this.dob,
    this.phone,
    this.email,
  }) : badges = badges ?? [];
}

// Ported from state.feedback in the original — upgraded from a bare string list to a real model
// with stars/response, since the Contact screen needs those fields (the badge check in
// badges.dart only ever used .length, so this doesn't affect that).
// Friends system models (friends / pending requests / assigned deeds) — loaded from the real
// friendships and assigned_deeds tables. The Friends UI itself is parked (no entry point).
class FriendEntry {
  final String id; // was missing entirely — made it impossible to properly assign a deed to a
  // specific friend, since there was no way to reference WHICH friend beyond their display name
  final String friendshipId; // the friendships row id — needed to persist favorite/remove
  final bool isRequester; // which side of that row the current user is on — favoriting writes to
  // favorited_by_requester or favorited_by_addressee depending on this
  final String name;
  bool favorited;
  FriendEntry({required this.id, required this.friendshipId, required this.isRequester, required this.name, this.favorited = false});
}

class PendingFriendRequest {
  final String id; // the friendships row id — needed to act on it (accept/decline)
  final String requesterId;
  final String name;
  const PendingFriendRequest({required this.id, required this.requesterId, required this.name});
}

class AssignedDeed {
  final String? id; // Supabase row id, needed to mark it complete
  final String friendName; // for assignedByMe: who you assigned it to. For assignedToMe: who assigned it to you.
  final String friendId; // the OTHER person's real id — assigner for assignedToMe, assignee for assignedByMe
  final String deedType;
  final int day;
  bool completed;
  AssignedDeed({this.id, required this.friendName, required this.friendId, required this.deedType, required this.day, this.completed = false});
}

class FeedbackEntry {
  final String? id;
  final int stars;
  final String text;
  final int day;
  bool responded;
  String? response;
  FeedbackEntry({this.id, required this.stars, required this.text, required this.day, this.responded = false, this.response});
}

// Ported from the original's 4 .wp-swatch presets exactly (same hex values). The original's
// 5th option ("📷 Add your own wallpaper") isn't included — a custom photo background is a
// bigger feature (would need to actually render a photo behind everything, not just swap a
// gradient) than the 4 preset colors, and isn't part of this pass.
const List<List<Color>> wallpaperSwatches = [
  [Color(0xFF0F2016), Color(0xFF081209)], // original default green
  [Color(0xFF3E1C10), Color(0xFF210D07)],
  [Color(0xFF141B33), Color(0xFF080B16)],
  [Color(0xFF1C1C1C), Color(0xFF050505)],
];

// AppState — ChangeNotifier is Flutter/Provider's equivalent of the useState-based hook in the
// Next.js port. Field-for-field the same shape as the original `state` object; see
// ACHA_KARO_FINALIZED.html's architecture comment block for the full Supabase table mapping,
// which applies identically here regardless of frontend framework.
class AppState extends ChangeNotifier {
  int simDay = 1;
  UserProfile user = UserProfile();
  // New — real, private membership number (AK-100001 style). Loaded from the separate
  // membership_numbers table, not a column on profiles — see membership_numbers.sql for why:
  // that table's own security rule means only you can ever fetch your own row, so this is
  // genuinely private, not just something the app chooses not to display elsewhere.
  String? membershipNumber;
  List<DeedLogEntry> deedsLog = [];
  // First-deed onboarding — true only once this account's real deed history has actually loaded
  // (or a brand-new profile was just created, so zero deeds is certain). Until then the app
  // genuinely doesn't know whether someone has logged a deed, so the Guddi tour/bubble stay
  // hidden rather than guessing from an empty, not-yet-loaded list (same trap as the rank badges).
  bool deedHistoryLoaded = false;
  // Set right after Profile Setup succeeds, so Home shows the full 4-step tour instead of the
  // shorter "welcome back" version. Session-only.
  bool justCompletedSetup = false;
  // Any deed at all (approved, pending or rejected) counts — trying is the goal.
  bool get needsFirstDeed => deedHistoryLoaded && deedsLog.isEmpty;
  // For the daily reminder: skip today's nudge once any deed has been logged today.
  bool get loggedDeedToday {
    final now = DateTime.now();
    return deedsLog.any((d) {
      final c = d.createdAt.toLocal();
      return c.year == now.year && c.month == now.month && c.day == now.day;
    });
  }
  List<ModerationQueueItem> moderationQueue = [];
  Map<String, DateTime> lastLoggedAt = {};
  bool everRankedFirst = false;
  // Badge ids an admin has frozen (badge_definitions.frozen). Loaded at sign-in and on every
  // loadRemoteConfig(); _applyBadgeUpdate() never newly grants these.
  Set<String> _frozenBadgeIds = {};
  String lastSeenTier = 'chick';

  // A failed read keeps the last known set (empty on first load, i.e. nothing frozen) and never
  // blocks sign-in — the RLS insert policy still refuses frozen badges server-side regardless.
  Future<void> _loadFrozenBadgeIds() async {
    try {
      final rows = await Supabase.instance.client.from('badge_definitions').select('id').eq('frozen', true);
      _frozenBadgeIds = rows.map<String>((r) => r['id'] as String).toSet();
    } catch (_) {}
  }
  List<FeedbackEntry> feedback = [];

  // Real write now — was purely local before, meaning feedback vanished the moment the app
  // closed. Local state still updates immediately either way (optimistic), same "don't block on
  // network" pattern as everything else; the id comes back from Supabase once the write lands.
  Future<void> submitFeedback({required int stars, required String text}) async {
    final entry = FeedbackEntry(stars: stars, text: text, day: simDay);
    // Inserted at the front now, not appended — feedback loads newest-first (see the real
    // ordering fix below), so a brand new submission needs to go at index 0 to actually show up
    // first, matching that same order, rather than the end.
    feedback.insert(0, entry);
    notifyListeners();

    final uid = Supabase.instance.client.auth.currentUser?.id;
    if (uid == null) return;
    try {
      final inserted = await Supabase.instance.client.from('feedback').insert({
        'user_id': uid,
        'stars': stars,
        'text': text,
      }).select().single();
      final id = inserted['id'] as String?;
      if (id != null) {
        final idx = feedback.indexOf(entry);
        if (idx != -1) feedback[idx] = FeedbackEntry(id: id, stars: stars, text: text, day: simDay);
        notifyListeners();
      }
    } catch (_) {
      // Best-effort — feedback still shows locally even if the remote write fails.
    }
  }
  int townVoiceWins = 0; // never actually incremented anywhere — same honest placeholder as the original
  // dailyMilestoneDateKey/dailyMilestonesHit removed — that whole persisted "already celebrated
  // today" tracking was the actual regression (see _checkDailyMilestones below for the fix that
  // replaced it, needing no persisted state at all).
  List<AppNotification> notifications = [];

  // Settings — text size (saved on this device) and wallpaper swatch (saved to the profile).
  String textScale = 'default'; // 'down' | 'default' | 'up'
  int wallpaperSwatchIndex = 0; // matches wallpaperSwatches below
  // Real, final direction — global equip, confirmed after a genuine policy discussion: since
  // campaigns are time-limited, a skin permanently locked to one specific, possibly-expired
  // campaign would make ownership pointless long-term. One skin, equipped globally, shown on
  // whichever roadmap is currently open — reuses profiles.active_skin_id, which already existed
  // in the schema. Automatically reset to null by a real database trigger the moment any new
  // campaign goes active (see reset_equipped_skin_on_campaign_launch.sql) — not app logic, so
  // it can never be missed regardless of how a campaign gets activated.
  String? equippedSkinId;
  String? equippedSkinIcon;
  Set<String> completedCampaignIds = {}; // new — which campaigns this user has fully claimed the Hall of Fame for, drives the tick mark on Home

  // Single source every screen reads campaign / Town Voice content from. Starts as the neutral
  // fallback (nothing shown) and is replaced by the real campaigns/app_config rows via
  // loadRemoteConfig() at startup, on resume and on pull-to-refresh.
  RemoteConfig remoteConfig = defaultRemoteConfig();

  // Real load now — campaigns/app_config are both publicly readable (see the schema's RLS:
  // "using (true)"), so this works regardless of auth state. Falls back to the local defaults
  // already sitting in remoteConfig if this fails, rather than showing nothing.
  // New — real app-update notification state. Null means nothing to show.
  Map<String, dynamic>? pendingUpdate;

  Future<void> checkForUpdate() async {
    try {
      final uid = Supabase.instance.client.auth.currentUser?.id;
      if (uid == null) return;

      final updateRow = await Supabase.instance.client.from('app_updates').select().eq('active', true).order('created_at', ascending: false).limit(1).maybeSingle();
      if (updateRow == null) return;

      // Already running the build this row announces (e.g. installed it straight from the
      // website) — nothing to update to, so never prompt for it.
      final rowLabel = (updateRow['version_label'] as String? ?? '').trim().toLowerCase();
      if (rowLabel == kAppVersionLabel.toLowerCase()) return;

      final profileRow = await Supabase.instance.client.from('profiles').select('joined_at, last_acked_update_id').eq('id', uid).maybeSingle();
      if (profileRow == null) return;

      // A genuinely new joiner, downloading after this update already existed, is already on
      // the latest build — never shown to them at all.
      final joinedAt = profileRow['joined_at'] != null ? DateTime.parse(profileRow['joined_at'] as String) : null;
      final createdAt = DateTime.parse(updateRow['created_at'] as String);
      if (joinedAt != null && joinedAt.isAfter(createdAt)) return;

      // Already acknowledged this specific update — never shown again for it.
      if (profileRow['last_acked_update_id'] == updateRow['id']) return;

      pendingUpdate = updateRow;
      notifyListeners();
    } catch (_) {
      // Never blocks the rest of the app over this.
    }
  }

  Future<void> acknowledgeUpdate() async {
    final uid = Supabase.instance.client.auth.currentUser?.id;
    final updateId = pendingUpdate?['id'];
    if (uid == null || updateId == null) return;
    pendingUpdate = null;
    notifyListeners();
    try {
      await Supabase.instance.client.from('profiles').update({'last_acked_update_id': updateId}).eq('id', uid);
    } catch (_) {
      // The popup is already dismissed either way — a failed write here just means it might
      // show again next launch, not a broken experience right now.
    }
  }

  Future<void> loadRemoteConfig() async {
    await _loadFrozenBadgeIds();
    try {
      final campaignRows = await Supabase.instance.client.from('campaigns').select();
      final campaigns = campaignRows.map<Campaign>((c) => Campaign(
            id: c['id'] as String,
            title: c['title'] as String,
            description: c['description'] as String,
            icon: c['icon'] as String,
            ctaLabel: c['cta_label'] as String?,
            ctaLink: c['cta_link'] as String?,
            active: c['active'] as bool? ?? false,
            youtubeVideoId: c['youtube_video_id'] as String?,
            startDate: c['start_date'] != null ? DateTime.tryParse(c['start_date'] as String) : null,
            endDate: c['end_date'] != null ? DateTime.tryParse(c['end_date'] as String) : null,
            cooldownMinutesOverride: c['cooldown_minutes_override'] as int?,
            hofBadgeName: c['hof_badge_name'] as String?,
            hofBadgeIcon: c['hof_badge_icon'] as String?,
            hofStickerName: c['hof_sticker_name'] as String?,
            hofStickerIcon: c['hof_sticker_icon'] as String?,
            hofYoutubeVideoId: c['hof_youtube_video_id'] as String?,
            defaultVehicleIcon: c['default_vehicle_icon'] as String? ?? '🚚',
            roadmapBgColor1: c['roadmap_bg_color_1'] as String?,
            roadmapBgColor2: c['roadmap_bg_color_2'] as String?,
            roadmapRoadColor: c['roadmap_road_color'] as String?,
            termsAndConditions: c['terms_and_conditions'] as String?,
            teaserActive: c['teaser_active'] as bool? ?? false,
            teaserDescription: c['teaser_description'] as String?,
          )).toList();

      var townVoice = remoteConfig.townVoice;
      var weeklyLeaderboardActive = remoteConfig.weeklyLeaderboardActive;
      final configRows = await Supabase.instance.client.from('app_config').select().limit(1);
      if (configRows.isNotEmpty) {
        final row = configRows.first;
        townVoice = TownVoiceConfig(
          streamUrl: row['town_voice_stream_url'] as String? ?? townVoice.streamUrl,
          dayLabel: row['town_voice_day_label'] as String? ?? townVoice.dayLabel,
          timeLabel: row['town_voice_time_label'] as String? ?? townVoice.timeLabel,
          durationLabel: row['town_voice_duration_label'] as String? ?? townVoice.durationLabel,
          active: row['town_voice_active'] as bool? ?? false,
        );
        weeklyLeaderboardActive = row['weekly_leaderboard_active'] as bool? ?? false;
      }

      remoteConfig = RemoteConfig(townVoice: townVoice, campaigns: campaigns, weeklyLeaderboardActive: weeklyLeaderboardActive);
      notifyListeners();
    } catch (_) {
      // Stays on the local defaults already set — better than showing nothing.
    }
  }

  // DEV-ONLY — used solely by lib/dev_prototypes/simulator_screen.dart. No shipped screen calls
  // it, so it's tree-shaken out of release builds. Do not call from app code: it's a client-side
  // write to campaigns.active (RLS restricts it to moderator/owner, but campaigns are managed
  // from the admin dashboard).
  Future<void> toggleDemoCampaignActive(String campaignId) async {
    Campaign? target;
    for (final c in remoteConfig.campaigns) {
      if (c.id == campaignId) target = c;
    }
    if (target == null) return;
    final newActive = !target.active;
    final updated = remoteConfig.campaigns.map((c) {
      if (c.id != campaignId) return c;
      // Real bug fixed here while already touching this line: this was dropping every field
      // beyond the first six — youtubeVideoId, dates, cooldown override, and now the new Hall of
      // Fame content too would have been silently wiped by any toggle. Only reachable via the
      // unreachable Simulator screen currently, so not an active bug, but worth fixing properly
      // rather than leaving a latent one for whenever Simulator might return.
      return Campaign(
        id: c.id, title: c.title, description: c.description, icon: c.icon, ctaLabel: c.ctaLabel, ctaLink: c.ctaLink, active: newActive,
        youtubeVideoId: c.youtubeVideoId, startDate: c.startDate, endDate: c.endDate, cooldownMinutesOverride: c.cooldownMinutesOverride,
        hofBadgeName: c.hofBadgeName, hofBadgeIcon: c.hofBadgeIcon, hofStickerName: c.hofStickerName, hofStickerIcon: c.hofStickerIcon, hofYoutubeVideoId: c.hofYoutubeVideoId,
        defaultVehicleIcon: c.defaultVehicleIcon,
        roadmapBgColor1: c.roadmapBgColor1, roadmapBgColor2: c.roadmapBgColor2, roadmapRoadColor: c.roadmapRoadColor,
        termsAndConditions: c.termsAndConditions,
        teaserActive: c.teaserActive, teaserDescription: c.teaserDescription,
      );
    }).toList();
    remoteConfig = RemoteConfig(townVoice: remoteConfig.townVoice, campaigns: updated, weeklyLeaderboardActive: remoteConfig.weeklyLeaderboardActive);
    notifyListeners();

    try {
      await Supabase.instance.client.from('campaigns').update({'active': newActive}).eq('id', campaignId);
    } catch (_) {
      // Best-effort — this requires moderator/owner role, same RLS pattern as everything else.
    }
  }

  double get textScaleFactor => switch (textScale) {
        'down' => 0.9,
        'up' => 1.15,
        _ => 1.0,
      };

  static const _textScaleKey = 'ak_text_scale';

  // Saved on this device only (shared_preferences), so the A−/A/A+ choice survives a restart.
  void setTextScale(String v) {
    textScale = v;
    notifyListeners();
    SharedPreferences.getInstance().then((p) => p.setString(_textScaleKey, v), onError: (_) => false);
  }

  Future<void> loadTextScale() async {
    try {
      final saved = (await SharedPreferences.getInstance()).getString(_textScaleKey);
      if (saved != null && saved != textScale && const ['down', 'default', 'up'].contains(saved)) {
        textScale = saved;
        notifyListeners();
      }
    } catch (_) {
      // Keeps the default size if local storage isn't available.
    }
  }

  // Saved to the real profiles.wallpaper_swatch_index column (and read back on load), so the
  // choice survives restarts and follows the account.
  Future<void> setWallpaperSwatch(int index) async {
    wallpaperSwatchIndex = index;
    notifyListeners();
    try {
      final uid = Supabase.instance.client.auth.currentUser?.id;
      if (uid != null) {
        await Supabase.instance.client.from('profiles').update({'wallpaper_swatch_index': index}).eq('id', uid);
      }
    } catch (_) {
      // Local state already updated either way — a save failure here just means it won't
      // survive a restart this one time, not that the current session is affected.
    }
  }

  // New — equips a real, owned skin, shown on the roadmap. Verifies ownership before saving,
  // rather than trusting whatever the UI happens to show — a defensive check, not just relying
  // on the Skins screen to only ever offer owned skins as an option.
  // Real, confirmed final version — genuinely global equip now, replacing the per-campaign
  // system entirely. Removes the diagnostic banner/debug fields too, since the real cause
  // (equipping being scoped per-campaign at all) is now understood and fixed at the design
  // level, not just patched around.
  Future<String?> equipSkin(String skinId, String skinIcon) async {
    try {
      final uid = Supabase.instance.client.auth.currentUser?.id;
      if (uid == null) return 'Not signed in.';
      final owned = await Supabase.instance.client.from('user_vehicle_skins').select('skin_id').eq('user_id', uid).eq('skin_id', skinId).maybeSingle();
      if (owned == null) return "You don't own this skin.";
      await Supabase.instance.client.from('profiles').update({'active_skin_id': skinId}).eq('id', uid);
      equippedSkinId = skinId;
      equippedSkinIcon = skinIcon;
      notifyListeners();
      return null;
    } catch (e) {
      return 'Could not equip this skin: ${e.toString()}';
    }
  }

  Future<String?> unequipSkin() async {
    try {
      final uid = Supabase.instance.client.auth.currentUser?.id;
      if (uid == null) return 'Not signed in.';
      await Supabase.instance.client.from('profiles').update({'active_skin_id': null}).eq('id', uid);
      equippedSkinId = null;
      equippedSkinIcon = null;
      notifyListeners();
      return null;
    } catch (e) {
      return 'Could not unequip: ${e.toString()}';
    }
  }

  Future<void> loadEquippedSkin() async {
    try {
      final uid = Supabase.instance.client.auth.currentUser?.id;
      if (uid == null) return;
      final row = await Supabase.instance.client
          .from('profiles')
          .select('active_skin_id, vehicle_skins(icon)')
          .eq('id', uid)
          .maybeSingle();
      // Handled defensively for both possible relationship shapes — confirmed elsewhere in this
      // project that PostgREST can return a nested to-one relationship as either a direct object
      // or a single-item list depending on context.
      final rawSkin = row?['vehicle_skins'];
      final skin = rawSkin is List ? (rawSkin.isNotEmpty ? rawSkin.first as Map<String, dynamic> : null) : rawSkin as Map<String, dynamic>?;
      equippedSkinId = row?['active_skin_id'] as String?;
      equippedSkinIcon = skin?['icon'] as String?;
      notifyListeners();
    } catch (_) {
      // Falls back to nothing equipped shown — never blocks the rest of the app over this.
    }
  }

  // Friends — starts empty, populated from the real `friendships` table once there's a session
  // (see tryLoadExistingProfile below). No pre-load mock seed: Friends has no reachable nav entry
  // in this pilot build, so there's never a user-visible moment before the real load completes.
  List<FriendEntry> friends = [];
  // Now real (see loadPendingFriendRequests below) — starts empty rather than seeded, same
  // reasoning as assignedByMe/assignedToMe: connects to the real `friendships` table now instead
  // of staying mock.
  List<PendingFriendRequest> pendingFriendRequests = [];
  // assignedByMe/assignedToMe — now real (see loadAssignedDeeds below), start empty rather than
  // seeded, since these connect to the real assigned_deeds table now instead of staying mock.
  List<AssignedDeed> assignedByMe = [];
  List<AssignedDeed> assignedToMe = [];

  Future<void> loadPendingFriendRequests() async {
    final uid = Supabase.instance.client.auth.currentUser?.id;
    if (uid == null) return;
    try {
      final rows = await Supabase.instance.client.from('friendships').select().eq('addressee_id', uid).eq('status', 'pending');
      final requesterIds = rows.map<String>((r) => r['requester_id'] as String).toSet().toList();
      if (requesterIds.isEmpty) {
        pendingFriendRequests = [];
        notifyListeners();
        return;
      }
      final profiles = await Supabase.instance.client.rpc('get_public_profiles', params: {'ids': requesterIds}) as List<dynamic>;
      final namesById = {for (final p in profiles) p['id'] as String: publicDisplayName(p['name'] as String?, fallback: 'Friend')};
      pendingFriendRequests = rows
          .map<PendingFriendRequest>((r) => PendingFriendRequest(
                id: r['id'] as String,
                requesterId: r['requester_id'] as String,
                name: namesById[r['requester_id']] ?? 'Friend',
              ))
          .toList();
      notifyListeners();
    } catch (_) {
      // Stays as whatever it already was — doesn't block sign-in.
    }
  }

  // Calls the request_friend RPC directly — see friends_screen.dart for the two-step UI this
  // supports (a plain match creates the request immediately; a cross-boundary adult/minor match
  // returns needs_relationship_answer first, so the caller re-invokes this with an answer).
  Future<Map<String, dynamic>> requestFriend(String membershipNumber, String name, {String? relationshipAnswer}) async {
    try {
      final result = await Supabase.instance.client.rpc('request_friend', params: {
        'membership_number_input': membershipNumber,
        'name_input': name,
        'relationship_answer_input': relationshipAnswer,
      });
      return Map<String, dynamic>.from(result as Map);
    } catch (e) {
      return {'status': 'error', 'message': 'Could not send that request: ${e.toString()}'};
    }
  }

  // Calls the accept_friend_request RPC — always routed through here regardless of whether a
  // relationship check applies, since only the server can determine that from both users' dob.
  Future<Map<String, dynamic>> acceptFriendRequest(String friendshipId, {String? relationshipAnswer}) async {
    try {
      final result = await Supabase.instance.client.rpc('accept_friend_request', params: {
        'friendship_id_input': friendshipId,
        'relationship_answer_input': relationshipAnswer,
      });
      final map = Map<String, dynamic>.from(result as Map);
      final status = map['status'] as String?;
      if (status == 'success' || status == 'flagged') {
        final req = pendingFriendRequests.where((r) => r.id == friendshipId).toList();
        pendingFriendRequests.removeWhere((r) => r.id == friendshipId);
        if (status == 'success' && req.isNotEmpty) {
          friends.add(FriendEntry(id: req.first.requesterId, friendshipId: friendshipId, isRequester: false, name: req.first.name));
        }
        notifyListeners();
      }
      return map;
    } catch (e) {
      return {'status': 'error', 'message': 'Could not accept that request: ${e.toString()}'};
    }
  }

  // Plain decline — no relationship check applies to declining, and the existing friendships RLS
  // (auth.uid() = requester_id OR addressee_id) already permits the addressee to update status
  // directly, so this doesn't need an RPC.
  Future<void> declineFriendRequest(String friendshipId) async {
    pendingFriendRequests.removeWhere((r) => r.id == friendshipId);
    notifyListeners();
    try {
      await Supabase.instance.client.from('friendships').update({'status': 'declined'}).eq('id', friendshipId);
    } catch (_) {
      // Optimistic-locally-first, same pattern as everywhere else in this file.
    }
  }

  static const int maxFavoriteFriends = 5; // matches the original's "star up to 5" rule

  // Matches by friend id (the other user's real profile id), not display name — two friends can
  // share a name, and name never uniquely identified a row anyway. Now persists too: was
  // local-only before, so a favorite/unfavorite never survived an app restart or showed up on
  // another device signed into the same account.
  Future<void> toggleFavoriteFriend(String id) async {
    final matches = friends.where((f) => f.id == id).toList();
    if (matches.isEmpty) return;
    final f = matches.first;
    final favoritedCount = friends.where((x) => x.favorited).length;
    if (!f.favorited && favoritedCount >= maxFavoriteFriends) return; // silently no-op at the cap, same as the original
    f.favorited = !f.favorited;
    notifyListeners();
    final column = f.isRequester ? 'favorited_by_requester' : 'favorited_by_addressee';
    try {
      await Supabase.instance.client.from('friendships').update({column: f.favorited}).eq('id', f.friendshipId);
    } catch (_) {
      // Optimistic-locally-first, same pattern as everywhere else in this file.
    }
  }

  // Same id-not-name fix as above, plus now actually persisted: unfriending only ever removed the
  // row from local state before, so the other person would still see you as a friend and the pair
  // would reappear on next real load. Marks the friendships row 'removed' rather than deleting it
  // outright, same non-destructive approach declineFriendRequest already uses for 'declined'.
  Future<void> removeFriend(String id) async {
    final matches = friends.where((f) => f.id == id).toList();
    if (matches.isEmpty) return;
    final friendshipId = matches.first.friendshipId;
    friends.removeWhere((f) => f.id == id);
    notifyListeners();
    try {
      await Supabase.instance.client.from('friendships').update({'status': 'removed'}).eq('id', friendshipId);
    } catch (_) {
      // Optimistic-locally-first, same pattern as everywhere else in this file.
    }
  }

  // The only source of rank data in the app: real public profiles (via the get_public_profiles
  // RPC — safe columns only) plus real badge counts, loaded at sign-in and whenever the
  // leaderboard is opened. myRank, the "ranked #N" labels and the Top 10/3/1 badges all use it.
  List<RealLeaderboardEntry> realLeaderboard = [];
  List<RealLeaderboardEntry> weeklyLeaderboard = [];
  // Real bug fixed here: rank-based badges (Top 10/Top 3/Ranked First) were being granted on
  // every cold start — _applyBadgeUpdate() runs before loadLeaderboard() has finished, and with
  // realLeaderboard still empty, myRank always comes out as #1. Only set once a load has
  // genuinely succeeded; badges.dart and _applyBadgeUpdate() check rankDataReady before trusting
  // any rank at all, so a failed (offline) load or an empty result can never grant these.
  bool leaderboardLoaded = false;
  bool get rankDataReady {
    final uid = Supabase.instance.client.auth.currentUser?.id;
    return leaderboardLoaded && realLeaderboard.any((e) => e.id != uid);
  }

  Future<void> loadLeaderboard() async {
    try {
      final profileRows = await Supabase.instance.client.rpc('get_public_profiles') as List<dynamic>;
      final badgeRows = await Supabase.instance.client.from('user_badges').select('user_id');
      final badgeCounts = <String, int>{};
      for (final b in badgeRows) {
        final uid = b['user_id'] as String;
        badgeCounts[uid] = (badgeCounts[uid] ?? 0) + 1;
      }
      realLeaderboard = profileRows.map<RealLeaderboardEntry>((r) => RealLeaderboardEntry(
            id: r['id'] as String,
            name: publicDisplayName(r['name'] as String?),
            city: r['city'] as String? ?? '',
            points: r['points'] as int? ?? 0,
            badgeCount: badgeCounts[r['id']] ?? 0,
          )).toList();
      leaderboardLoaded = true;

      // Real weekly data now — was the mock-duplicate-of-All-Time placeholder before. Reuses
      // the same RealLeaderboardEntry model; badgeCount doesn't have a clean per-week meaning,
      // left at 0 for these entries (only affects which tier icon shows next to weekly rows).
      final weeklyRows = await Supabase.instance.client.rpc('get_weekly_leaderboard') as List<dynamic>;
      weeklyLeaderboard = weeklyRows.map<RealLeaderboardEntry>((r) => RealLeaderboardEntry(
            id: r['user_id'] as String,
            // Your own weekly row keeps your name as you typed it; everyone else is "First L."
            name: r['user_id'] == Supabase.instance.client.auth.currentUser?.id ? user.name : publicDisplayName(r['name'] as String?),
            city: r['city'] as String? ?? '',
            points: r['weekly_points'] as int? ?? 0,
            badgeCount: 0,
          )).toList();
      notifyListeners();
    } catch (_) {
      // Leaderboard just won't reflect real data until the next successful load — doesn't block
      // anything else.
    }
  }

  // Shared by badges.dart's Top 10/Top 3 checks and every screen that shows "you're ranked #X" —
  // one real source of truth now instead of three separate local copies each computing it their
  // own way.
  int get myRank {
    final uid = Supabase.instance.client.auth.currentUser?.id;
    final otherPoints = realLeaderboard.where((e) => e.id != uid).map((e) => e.points).toList();
    final all = [...otherPoints, user.points]..sort((a, b) => b.compareTo(a));
    return all.indexOf(user.points) + 1;
  }

  // assigned_deeds — was entirely local mock data, never connected. Two foreign keys to
  // profiles here too (assigner_id, assignee_id), same ambiguity risk as friendships/feedback —
  // fetched separately per direction and joined in Dart rather than an embedded select, for the
  // same reason those were fixed that way.
  Future<void> _loadAssignedDeeds(String uid) async {
    try {
      final byMeRows = await Supabase.instance.client.from('assigned_deeds').select().eq('assigner_id', uid);
      final toMeRows = await Supabase.instance.client.from('assigned_deeds').select().eq('assignee_id', uid);

      final otherIds = {
        ...byMeRows.map((r) => r['assignee_id'] as String),
        ...toMeRows.map((r) => r['assigner_id'] as String),
      }.toList();

      var namesById = <String, String>{};
      if (otherIds.isNotEmpty) {
        final profiles = await Supabase.instance.client.rpc('get_public_profiles', params: {'ids': otherIds}) as List<dynamic>;
        namesById = {for (final p in profiles) p['id'] as String: publicDisplayName(p['name'] as String?, fallback: 'Friend')};
      }

      assignedByMe = byMeRows.map<AssignedDeed>((r) => AssignedDeed(
            id: r['id'] as String?,
            friendId: r['assignee_id'] as String,
            friendName: namesById[r['assignee_id']] ?? 'Friend',
            deedType: r['type'] as String,
            day: simDay,
            completed: r['completed'] as bool? ?? false,
          )).toList();

      assignedToMe = toMeRows.map<AssignedDeed>((r) => AssignedDeed(
            id: r['id'] as String?,
            friendId: r['assigner_id'] as String,
            friendName: namesById[r['assigner_id']] ?? 'Friend',
            deedType: r['type'] as String,
            day: simDay,
            completed: r['completed'] as bool? ?? false,
          )).toList();
    } catch (_) {
      // Doesn't block sign-in — assigned lists just won't reflect real data until the next
      // successful load, same pattern as everywhere else.
    }
  }

  Future<String?> assignDeedToFriend(String friendId, String friendName, String deedType) async {
    final uid = Supabase.instance.client.auth.currentUser?.id;
    if (uid == null) return 'You need to be signed in to do this.';
    try {
      final inserted = await Supabase.instance.client.from('assigned_deeds').insert({
        'assigner_id': uid,
        'assignee_id': friendId,
        'type': deedType,
      }).select().single();
      assignedByMe.add(AssignedDeed(id: inserted['id'] as String?, friendId: friendId, friendName: friendName, deedType: deedType, day: simDay));
      notifyListeners();
      return null;
    } catch (e) {
      return 'Could not assign that deed: ${e.toString()}';
    }
  }

  Future<String?> markAssignedDeedComplete(String id) async {
    try {
      await Supabase.instance.client.from('assigned_deeds').update({'completed': true}).eq('id', id);
      final idx = assignedToMe.indexWhere((a) => a.id == id);
      if (idx != -1) assignedToMe[idx].completed = true;
      notifyListeners();
      return null;
    } catch (e) {
      return 'Could not mark that complete: ${e.toString()}';
    }
  }

  // generateInviteLink/redeemInviteCode removed — the invite_codes table they depended on was
  // never actually created in the live database (confirmed directly against Supabase), so this
  // path always threw in production regardless. Superseded entirely by the membership-number +
  // name friend-request flow (request_friend RPC), not repaired.

  bool get hasUnreadNotifications => notifications.any((n) => !n.read);

  // "Something needs your attention" dot on the burger menu. Only unread notifications for now —
  // friend requests / assigned deeds live in the parked Friends UI, which has no entry point, so
  // counting them would light a dot the person has no way to clear.
  bool get hasSideSheetActivity => hasUnreadNotifications;

  // Now writes back to Supabase — was purely local before, meaning "read" status reset every
  // time the app reopened. Optimistic locally first, same pattern as everywhere else.
  void markNotificationRead(String id) {
    for (final n in notifications) {
      if (n.id == id) {
        n.read = true;
        break;
      }
    }
    notifyListeners();
    Supabase.instance.client.from('notifications').update({'read': true}).eq('id', id).then((_) {}, onError: (_) {});
  }

  void markAllNotificationsRead() {
    final ids = notifications.where((n) => !n.read).map((n) => n.id).toList();
    for (final n in notifications) {
      n.read = true;
    }
    notifyListeners();
    if (ids.isNotEmpty) {
      Supabase.instance.client.from('notifications').update({'read': true}).inFilter('id', ids).then((_) {}, onError: (_) {});
    }
  }

  // Effective cooldown right now — the normal 1-hour duration, UNLESS an active campaign
  // specifies a shorter one, in which case the shortest such override wins. Fully database-
  // driven: a campaign's cooldown_minutes_override column controls this, no code change needed
  // to run a "faster cooldowns this week" promotion.
  Duration get effectiveCooldownDuration {
    final overrideMinutes = remoteConfig.activeCooldownOverrideMinutes;
    if (overrideMinutes != null) return Duration(minutes: overrideMinutes);
    return cooldownDuration;
  }

  // New — the global side of the dual cooldown system: 15 minutes across ALL deed types after
  // ANY submission, layered on top of the existing per-type 1-hour cooldown. A type is locked if
  // EITHER condition says so. Same campaign-override mechanism as the per-type cooldown, per the
  // explicit direction that campaigns should affect both the same way — worth knowing this means
  // a campaign override longer than 15 minutes would technically make the global cooldown
  // LONGER than normal, not shorter; a reasonable edge case to just document rather than guard
  // against, since campaigns are expected to only ever set short override values in practice.
  Duration get effectiveGlobalCooldownDuration {
    final overrideMinutes = remoteConfig.activeCooldownOverrideMinutes;
    if (overrideMinutes != null) return Duration(minutes: overrideMinutes);
    return const Duration(minutes: 15);
  }

  // Most recent submission across ALL deed types — derived from lastLoggedAt rather than a
  // separately-tracked field, so there's nothing extra to keep in sync or reset on sign-out.
  DateTime? get _lastAnyDeedSubmission {
    if (lastLoggedAt.isEmpty) return null;
    return lastLoggedAt.values.reduce((a, b) => a.isAfter(b) ? a : b);
  }

  // New — public, so Home can distinguish "everything is locked because of the shared global
  // cooldown" from the normal per-type progress state, and show a clearer, deliberately greyed
  // treatment instead of relying on the same progress-ring visual used for ordinary cooldowns —
  // avoids the confusion of every category ring suddenly looking "full" for a reason that isn't
  // obvious from the ring alone.
  bool get isGlobalCooldownActive {
    final lastAny = _lastAnyDeedSubmission;
    if (lastAny == null) return false;
    return _clampToZero(effectiveGlobalCooldownDuration - DateTime.now().difference(lastAny)) > Duration.zero;
  }

  Duration cooldownRemaining(String type) {
    final last = lastLoggedAt[type];
    final perTypeRemaining = last == null
        ? Duration.zero
        : _clampToZero(effectiveCooldownDuration - DateTime.now().difference(last));

    final lastAny = _lastAnyDeedSubmission;
    final globalRemaining = lastAny == null
        ? Duration.zero
        : _clampToZero(effectiveGlobalCooldownDuration - DateTime.now().difference(lastAny));

    // A type is locked by whichever cooldown is stricter right now — its own per-type window,
    // or the shared global window from any recent submission at all.
    return perTypeRemaining > globalRemaining ? perTypeRemaining : globalRemaining;
  }

  Duration _clampToZero(Duration d) => d.isNegative ? Duration.zero : d;

  // DEV-ONLY (dev_prototypes/simulator_screen.dart; no shipped callers, tree-shaken from release).
  // Testing helper — simulates simDay advancing (used by the Simulator's "Next Day" /
  // "Next Week" buttons). Cooldowns are real-wall-clock-based (cooldownRemaining above), which
  // has no relationship to simDay at all on its own — advancing the simulated day wouldn't make
  // any cooldown wear off without this explicitly clearing lastLoggedAt too.
  void advanceDay(int days) {
    simDay += days;
    lastLoggedAt.clear();
    notifyListeners();
  }

  // Real bug fixed here too — same root cause as Achievements' Today/This Week filtering.
  // d.day == simDay silently excluded any deed loaded from a previous session, which meant the
  // "3+ same type today" repeat-flag check would undercount after an app restart, making
  // moderation less strict than intended. Real calendar-date comparison now, independent of the
  // simDay testing counter entirely.
  int countTodayByType(String type) {
    final now = DateTime.now();
    return deedsLog.where((d) => d.type == type && d.createdAt.year == now.year && d.createdAt.month == now.month && d.createdAt.day == now.day).length;
  }

  // Uses the same real data source (realLeaderboard) as Leaderboard/myRank.
  //
  // Still a real, honest limitation worth knowing: this is lifetime points, not a genuine
  // Mon–Sun weekly window (the actual agreed design). deedsLog does have real timestamps now
  // (from the milestone-fix batch), so building a true weekly window is realistic to do later —
  // just not built in this pass, flagged clearly rather than silently pretending this is final.
  (String name, int points) get townVoiceLeader {
    var leaderName = user.name;
    var leaderPoints = user.points;
    for (final e in realLeaderboard) {
      if (e.points > leaderPoints) {
        leaderPoints = e.points;
        leaderName = e.name;
      }
    }
    return (leaderName, leaderPoints);
  }

  String get townVoiceHolderName => townVoiceLeader.$1;

  // Best-effort GPS capture — returns null on any failure (permission denied, service disabled,
  // timeout, or any other error), never throws. Mirrors the same "weak signal, not proof" caution
  // already documented for this feature in the original app.
  Future<Position?> _attemptGpsCapture() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return null;
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return null;
      }
      if (permission == LocationPermission.deniedForever) return null;
      // geolocator 12.0.0 (the version pinned in pubspec.yaml) predates the `locationSettings`
      // parameter — that's a newer API. This version uses the direct desiredAccuracy/timeLimit
      // parameters instead. Confirmed against the actual build error, not just docs.
      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
        timeLimit: const Duration(seconds: 8),
      );
    } catch (_) {
      return null; // any geolocation error — treated as a capture failure, same as the original
    }
  }

  // DATA — checks whether today's crossed into a new 3/5/7-deed milestone since it was last
  // acknowledged. Only approved (not pending/flagged) deeds count, matching the original exactly.
  // Real regression fixed here: the previous version tracked "already celebrated today" in
  // dailyMilestonesHit — purely in-memory state that reset on every app restart. So reopening
  // the app after hitting 3 forgot that 3 was already celebrated, and both 3 and 5 fired
  // together on the next submission that crossed 5. This version needs no persisted flag at
  // all: it just checks whether THIS SPECIFIC submission crossed a threshold, by comparing the
  // real count immediately before vs. after. Nothing to desync, because there's nothing being
  // remembered between sessions in the first place.
  List<int> _checkDailyMilestones() {
    final now = DateTime.now();
    final countAfter = deedsLog.where((d) {
      final c = d.createdAt;
      return c.year == now.year && c.month == now.month && c.day == now.day && (d.status == 'approved' || d.status == 'pending');
    }).length;
    final countBefore = countAfter - 1; // this submission is what just brought the count to countAfter
    final newlyHit = <int>[];
    for (final t in [3, 5, 7]) {
      if (countBefore < t && countAfter >= t) {
        // The animation itself is gendered (شہزادہ/شہزادی), so it's skipped for anyone who
        // hasn't specified male or female, rather than defaulting one way — same rule as before.
        if (t == 7 && user.gender != 'male' && user.gender != 'female') continue;
        newlyHit.add(t);
      }
    }
    return newlyHit;
  }

  // DATA — Photo mode is now the ONLY submission path (Honor mode removed entirely). No location
  // choice from the user anymore — GPS is captured automatically instead, so there's no more
  // public/shared point multiplier either; every approved submission awards full points.
  // Flags to moderation (never instant-rejects) when: repeated 3+ times today, GPS couldn't be
  // captured, or the deed is a donation type (always reviewed regardless of the other two).
  // Real moderation is active — flags to moderation (never instant-rejects) when: repeated 3+
  // times today, GPS couldn't be captured, or the deed is a donation type (always reviewed
  // regardless of the other two).
  // Uploads the already-compressed photo (longest side capped at 800px, JPEG 70% — done at
  // pick-time by AvatarPicker/SubmitDeedModal's ImagePicker call, not re-compressed here) to the
  // private deed-photos bucket. Returns the storage path (not a public URL — the bucket is
  // private, only the submitter and moderators/owners can actually view it) or null if there's
  // no photo or the upload fails, in which case the deed record still gets created either way.
  // Bytes, not dart:io File — File is unusable on Flutter web (no real filesystem), so
  // uploadBinary over raw bytes is what actually works on every platform, not just a web
  // special-case.
  // Metadata (EXIF GPS, XMP...) is stripped first — see image_metadata.dart. If the photo can't
  // be cleaned, nothing is uploaded rather than the original. The extension (and so the stored
  // content type) comes from the cleaned bytes, not the picked file name.
  Future<String?> _uploadDeedPhoto(String uid, Uint8List photoBytes) async {
    try {
      final clean = await stripImageMetadata(photoBytes);
      if (clean == null) return null;
      final path = '$uid/${DateTime.now().millisecondsSinceEpoch}.${clean.extension}';
      await Supabase.instance.client.storage.from('deed-photos').uploadBinary(path, clean.bytes);
      return path;
    } catch (_) {
      return null; // best-effort, same "don't block the person" reasoning as the other writes
    }
  }

  Future<SubmitResult> submitPhotoDeed(String type, Map<String, String> details, {Uint8List? photoBytes, String? photoFileName, String? campaignId, bool shareLocation = true}) async {
    final meta = deedCatalog[type];
    if (meta == null) return SubmitResult(flagged: false, leveledUpTier: null, newMilestones: []);

    // Real fix here: a genuine, confirmed case where briefly toggling a campaign active (even
    // for a moment) could leave its shortened cooldown override lingering for anyone whose app
    // was already open at that exact moment — since remoteConfig only otherwise refreshes on
    // cold start or app resume, not right before this actually matters. Re-fetched here, right
    // before the real cooldown check, so this always uses genuinely current campaign state
    // rather than whatever was cached from an earlier point in the session.
    await loadRemoteConfig();

    // Real bug fixed here: this never actually checked cooldown at all — every bit of
    // enforcement lived purely in the UI (greyed-out, disabled tiles). That's exactly the kind
    // of gap that lets submission through if ANY path reaches this function without the UI's
    // own check having caught it first — confirmed happening via the submit modal specifically.
    // Real safeguard now lives here too, at the data layer, checked before any actual work
    // (GPS, photo upload) happens — not just relying on the UI to have gotten it right.
    if (cooldownRemaining(type) > Duration.zero) {
      return SubmitResult(flagged: false, leveledUpTier: null, newMilestones: [], blockedByCooldown: true);
    }

    // shareLocation is the person's answer to the location disclosure (location_disclosure.dart).
    // Saying no skips GPS entirely (no OS prompt) and takes the same moderated path as a GPS failure.
    final position = shareLocation ? await _attemptGpsCapture() : null;
    final gpsFailed = position == null;
    final repeatFlag = countTodayByType(type) >= 2;
    final isDonation = donationDeedTypes.contains(type);
    final willFlag = repeatFlag || gpsFailed || isDonation;
    final awardedPoints = meta.points;
    final uid = Supabase.instance.client.auth.currentUser?.id;
    final photoPath = (uid != null && photoBytes != null) ? await _uploadDeedPhoto(uid, photoBytes) : null;

    if (willFlag) {
      lastLoggedAt[type] = DateTime.now(); // cooldown must start here too — a flagged/pending
      // submission still "used up" this deed type for the hour, same as an approved one.
      final reasons = <String>[];
      if (repeatFlag) reasons.add('Same deed type logged 3+ times today — repetition guard triggered.');
      if (!shareLocation) {
        reasons.add('Submitter chose not to share location.');
      } else if (gpsFailed) {
        reasons.add('GPS location could not be captured at submission.');
      }
      if (isDonation) reasons.add('Donation-category submission — always reviewed by a moderator.');
      final evidence = details.entries.where((e) => e.value.isNotEmpty).map((e) => '${e.key}: ${e.value}').join(' · ');
      final reasonText = reasons.join(' ');

      // Real writes — a deeds row (status pending, photo_url = the uploaded Storage path above)
      // and a linked moderation_queue row. Wrapped in try/catch so a network hiccup doesn't
      // block the person from completing what they were doing — local state still updates
      // either way; this is a known gap (no retry/offline queue yet) worth improving later.
      String? deedId;
      if (uid != null) {
        try {
          final inserted = await Supabase.instance.client.from('deeds').insert({
            'user_id': uid,
            'type': type,
            'points': awardedPoints,
            'status': 'pending',
            'photo_url': photoPath,
            'gps_lat': position?.latitude,
            'gps_lng': position?.longitude,
            'campaign_id': campaignId,
          }).select().single();
          deedId = inserted['id'] as String?;
          if (deedId != null) {
            await Supabase.instance.client.from('moderation_queue').insert({
              'deed_id': deedId,
              'reason': reasonText,
            });
          }
        } catch (_) {
          // Deliberately swallowed — see comment above. Local queue below still reflects this
          // submission regardless of whether the remote write succeeded.
        }
      }

      moderationQueue.add(ModerationQueueItem(
        id: deedId ?? 'local_${DateTime.now().millisecondsSinceEpoch}',
        type: type,
        points: awardedPoints,
        day: simDay,
        reason: reasonText,
        photoFile: photoBytes,
        evidence: evidence.isEmpty ? null : evidence,
        gps: position != null ? '${position.latitude.toStringAsFixed(4)}, ${position.longitude.toStringAsFixed(4)}' : null,
      ));
      deedsLog.add(DeedLogEntry(id: deedId, type: type, points: awardedPoints, day: simDay, createdAt: DateTime.now(), status: 'pending', campaignId: campaignId));
      // Milestones now count pending submissions too, matching "give a thank you regardless" —
      // previously this only ran in the approved branch below, so a flagged submission never
      // moved the daily-milestone counter at all, even though the deed genuinely happened.
      final newMilestones = _checkDailyMilestones();
      notifyListeners();
      return SubmitResult(flagged: true, leveledUpTier: null, newMilestones: newMilestones);
    }

    String? deedId;
    if (uid != null) {
      try {
        final inserted = await Supabase.instance.client.from('deeds').insert({
          'user_id': uid,
          'type': type,
          'points': awardedPoints,
          'status': 'approved',
          'photo_url': photoPath,
          'gps_lat': position.latitude, // non-null here: a GPS failure always takes the flagged path above
          'gps_lng': position.longitude,
          'campaign_id': campaignId,
        }).select().single();
        deedId = inserted['id'] as String?;
        // Real points update — was purely local before. Same "don't block on network" reasoning
        // as above: local state updates regardless, this is best-effort until real offline sync
        // is built.
        await Supabase.instance.client.from('profiles').update({
          'points': user.points + awardedPoints,
          'last_points_activity': DateTime.now().toIso8601String(),
        }).eq('id', uid);
      } catch (_) {
        // Swallowed for the same reason as above.
      }
    }

    deedsLog.add(DeedLogEntry(id: deedId, type: type, points: awardedPoints, day: simDay, createdAt: DateTime.now(), status: 'approved', campaignId: campaignId));
    user.points += awardedPoints;
    if (user.lastLogDay != simDay) {
      user.streak += 1;
      user.lastLogDay = simDay;
    }
    lastLoggedAt[type] = DateTime.now();

    final leveledUpTier = _applyBadgeUpdate();
    final newMilestones = _checkDailyMilestones();
    notifyListeners();
    return SubmitResult(flagged: false, leveledUpTier: leveledUpTier, newMilestones: newMilestones);
  }

  // DATA — pure logic, ported 1:1 from applyBadgeUpdate() in the Next.js port (itself ported
  // from updateBadges()/checkTierLevelUp() in the original). Only reports a level-up on genuine
  // growth — never on a downgrade.
  TierDef? _applyBadgeUpdate() {
    if (rankDataReady && computeRank(this) == 1) everRankedFirst = true;
    final oldBadges = user.badges.toSet();
    // Freeze is enforced by the database (user_badges' RLS insert policy refuses any badge whose
    // badge_definitions.frozen = true), but the write below is fire-and-forget — a refused
    // insert never reached the UI, so a frozen badge still showed locally. Frozen badges are now
    // never newly unlocked here; ones the person already holds (loaded from user_badges) stay.
    user.badges = grantableBadgeIds(badgeDefs.where((b) => b.check(this)).map((b) => b.id), oldBadges, _frozenBadgeIds);
    final newlyUnlocked = user.badges.where((id) => !oldBadges.contains(id)).toList();
    if (newlyUnlocked.isNotEmpty) _writeNewBadges(newlyUnlocked);

    final newTier = getUserTier(user.badges.length);
    if (newTier.key == lastSeenTier) return null;
    final oldIdx = tierDefs.indexWhere((t) => t.key == lastSeenTier);
    final newIdx = tierDefs.indexWhere((t) => t.key == newTier.key);
    lastSeenTier = newTier.key;
    return newIdx > oldIdx ? newTier : null;
  }

  // New — badges computed correctly locally this whole time, but never actually reached
  // Supabase's user_badges table, which just sat empty. Real, practical consequence: nobody else
  // (a friend, the admin site) could ever see anyone's badges, since there was nothing in the
  // database to read. upsert (not insert) specifically, so this is safe to call even if a badge
  // somehow gets recomputed as "new" again — no duplicate-key error, it just does nothing extra.
  void _writeNewBadges(List<String> badgeIds) {
    final uid = Supabase.instance.client.auth.currentUser?.id;
    if (uid == null) return;
    final rows = badgeIds.map((id) => {'user_id': uid, 'badge_id': id}).toList();
    Supabase.instance.client.from('user_badges').upsert(rows).then((_) {}, onError: (_) {});
  }

  // DEV-ONLY from here through rejectQueueItem (except the city breakdown): used only by
  // dev_prototypes/simulator_screen.dart, no shipped callers, tree-shaken from release builds.
  // Real moderation happens in the admin dashboard.
  // Simulator-only methods — for the test Simulator screen, since real moderation is paused
  // right now. Lets that specific flow (approve/reject a flagged item) be tested independently
  // of the main submission path. Simplification worth knowing: approving adds a fresh approved
  // deedsLog entry rather than mutating the original pending one (DeedLogEntry has no id to
  // match against) — harmless for testing, not how the real moderator screen should work later.
  // Real cross-session moderator review — was missing entirely before. The Simulator could only
  // ever show items added within the SAME app session; a photo submitted from one device/
  // session couldn't be reviewed from another. This actually loads the real pending queue.
  // Only succeeds for accounts with role moderator/owner — RLS enforces that server-side, same
  // as approve/reject already does; this just fails quietly (queue stays whatever it was) for
  // anyone else, rather than throwing an error over a permission check that's supposed to exist.
  // City breakdown (replaces the earlier interactive-map heatmap — a plain bar chart is lower
  // risk to test with, no map SDK, no external tiles, uses the city already captured at
  // sign-up). Loads from the public_deed_cities VIEW, same reasoning as before: a regular user
  // can't see other users' rows in deeds directly under existing RLS (correctly), so this view
  // exposes only deed type + submitter's city for approved deeds — nothing identifying.
  List<CityDeedCount> cityBreakdown = [];
  bool cityBreakdownLoading = false;

  Future<void> loadCityBreakdown() async {
    cityBreakdownLoading = true;
    notifyListeners();
    try {
      final rows = await Supabase.instance.client.from('public_deed_cities').select();
      final counts = <String, int>{};
      for (final r in rows) {
        final city = r['city'] as String?;
        if (city == null) continue;
        counts[city] = (counts[city] ?? 0) + 1;
      }
      final entries = counts.entries.map((e) => CityDeedCount(city: e.key, count: e.value)).toList();
      entries.sort((a, b) => b.count.compareTo(a.count));
      cityBreakdown = entries;
    } catch (_) {
      // Stays empty — matches "keep it blank until there's real activity" exactly, whether
      // that's because there's genuinely no data yet or because the view isn't reachable.
    }
    cityBreakdownLoading = false;
    notifyListeners();
  }

  Future<void> loadModerationQueue() async {
    try {
      final rows = await Supabase.instance.client
          .from('moderation_queue')
          .select('*, deeds(*)')
          .isFilter('outcome', null)
          .order('created_at');
      moderationQueue = rows.map<ModerationQueueItem>((r) {
        final deed = r['deeds'] as Map<String, dynamic>?;
        final lat = deed?['gps_lat'];
        final lng = deed?['gps_lng'];
        return ModerationQueueItem(
          id: r['deed_id'] as String,
          type: deed?['type'] as String? ?? 'unknown',
          points: deed?['points'] as int? ?? 0,
          day: simDay,
          reason: r['reason'] as String? ?? '',
          photoUrl: deed?['photo_url'] as String?, // a Storage PATH, not yet a viewable URL —
          // the bucket is private, so displaying it needs a signed URL generated on demand
          // (see getSignedPhotoUrl below), not stored/cached here since signed URLs expire.
          gps: (lat != null && lng != null) ? '$lat, $lng' : null,
        );
      }).toList();
      notifyListeners();
    } catch (_) {
      // Not a moderator/owner, or offline — queue just stays as whatever it already was locally.
    }
  }

  // Generates a short-lived signed URL for a private deed photo — called on-demand when actually
  // displaying one, not stored, since signed URLs expire (60 seconds here; long enough to load
  // the image, short enough not to leak a durable public link to something meant to stay private).
  Future<String?> getSignedPhotoUrl(String path) async {
    try {
      return await Supabase.instance.client.storage.from('deed-photos').createSignedUrl(path, 60);
    } catch (_) {
      return null;
    }
  }

  void simulateAddTestFlaggedDeed(String type) {
    final meta = deedCatalog[type];
    if (meta == null) return;
    final id = 'sim${DateTime.now().millisecondsSinceEpoch}';
    moderationQueue.add(ModerationQueueItem(id: id, type: type, points: meta.points, day: simDay, reason: 'Simulated test item — not a real flagged submission.'));
    // Real bug fixed here: this never gave the DeedLogEntry a matching id at all, so
    // approve/reject could never find the right entry to update — explaining why an "approved"
    // test item kept showing as pending regardless.
    deedsLog.add(DeedLogEntry(id: id, type: type, points: meta.points, day: simDay, createdAt: DateTime.now(), status: 'pending'));
    notifyListeners();
  }

  // Real bug fixed in both methods below: approving used to ADD a new deedsLog entry rather
  // than updating the existing pending one, which never went away — so the original entry kept
  // showing "pending" forever regardless of what the queue said. Neither method wrote to
  // Supabase at all before this, so even checking the database directly would still show
  // pending. Both fixed now: the existing local entry is replaced in place, and (for real,
  // Supabase-backed items — test items created by the Simulator have no real row, so this is
  // expected to fail for those specifically) the real deeds and moderation_queue rows update too.
  // Returns an error message on failure instead of silently swallowing it — a real RLS
  // permission error (e.g. account not set to moderator/owner yet) looked identical to "nothing
  // happened" before this, which made a real, findable problem look like a mystery.
  Future<String?> approveQueueItem(String id) async {
    ModerationQueueItem? item;
    for (final q in moderationQueue) {
      if (q.id == id) item = q;
    }
    if (item == null) return null;
    moderationQueue.removeWhere((q) => q.id == id);

    final idx = deedsLog.indexWhere((d) => d.id == id);
    // Preserve the original createdAt when replacing an existing pending entry — the deed itself
    // happened at submission time, only its status is changing now. Same reasoning just applied
    // to rejectQueueItem below.
    final originalCreatedAt = idx != -1 ? deedsLog[idx].createdAt : DateTime.now();
    final originalCampaignId = idx != -1 ? deedsLog[idx].campaignId : null; // preserved through
    // approval too — a campaign-tagged deed shouldn't lose that tag just because a moderator
    // acted on it
    final approved = DeedLogEntry(id: id, type: item.type, points: item.points, day: simDay, createdAt: originalCreatedAt, status: 'approved', campaignId: originalCampaignId);
    if (idx != -1) {
      deedsLog[idx] = approved;
    } else {
      deedsLog.add(approved); // shouldn't normally happen, but don't lose the record if it does
    }

    user.points += item.points;
    if (user.lastLogDay != simDay) {
      user.streak += 1;
      user.lastLogDay = simDay;
    }

    String? errorMessage;
    if (!id.startsWith('sim') && !id.startsWith('local_')) {
      try {
        await Supabase.instance.client.from('deeds').update({'status': 'approved'}).eq('id', id);
        await Supabase.instance.client.from('moderation_queue').update({
          'outcome': 'approved',
          'resolved_at': DateTime.now().toIso8601String(),
          'resolved_by': Supabase.instance.client.auth.currentUser?.id,
        }).eq('deed_id', id);
        final uid = Supabase.instance.client.auth.currentUser?.id;
        if (uid != null) {
          await Supabase.instance.client.from('profiles').update({
            'points': user.points,
            'last_points_activity': DateTime.now().toIso8601String(),
          }).eq('id', uid);
          // New — same fix as the admin site's moderation tab. Simulator always approves your
          // own test items (you can only submit your own deeds), so the notification target is
          // always the currently signed-in user here.
          await Supabase.instance.client.from('notifications').insert({
            'user_id': uid,
            'type': 'taskActioned',
            'title': 'Deed approved',
            'body': 'Your ${item.type} submission was approved — +${item.points} points.',
          });
        }
      } catch (e) {
        errorMessage = e.toString();
      }
    }

    _applyBadgeUpdate();
    _checkDailyMilestones();
    notifyListeners();
    return errorMessage;
  }

  Future<String?> rejectQueueItem(String id) async {
    moderationQueue.removeWhere((q) => q.id == id);

    final idx = deedsLog.indexWhere((d) => d.id == id);
    if (idx != -1) {
      final old = deedsLog[idx];
      deedsLog[idx] = DeedLogEntry(id: old.id, type: old.type, points: old.points, day: old.day, createdAt: old.createdAt, status: 'rejected', campaignId: old.campaignId);
    }

    String? errorMessage;
    if (!id.startsWith('sim') && !id.startsWith('local_')) {
      try {
        await Supabase.instance.client.from('deeds').update({'status': 'rejected'}).eq('id', id);
        await Supabase.instance.client.from('moderation_queue').update({
          'outcome': 'rejected',
          'resolved_at': DateTime.now().toIso8601String(),
          'resolved_by': Supabase.instance.client.auth.currentUser?.id,
        }).eq('deed_id', id);
        final uid = Supabase.instance.client.auth.currentUser?.id;
        if (uid != null && idx != -1) {
          await Supabase.instance.client.from('notifications').insert({
            'user_id': uid,
            'type': 'taskActioned',
            'title': 'Deed rejected',
            'body': 'Your ${deedsLog[idx].type} submission was rejected.',
          });
        }
      } catch (e) {
        errorMessage = e.toString();
      }
    }

    notifyListeners();
    return errorMessage;
  }

  void completeSetup({required String name, required String gender, required String dob, required String city, String? phone, File? avatarFile}) {
    user.name = name;
    user.gender = gender;
    user.dob = dob;
    user.city = city;
    user.phone = phone;
    user.avatarFile = avatarFile;
    // Real bug fixed here: email was never captured at signup at all — there's no email field
    // on Profile Setup (correctly, since it's already known from the OTP-authenticated session),
    // but nothing ever auto-filled it into the profile either. Auto-populated from the real
    // session now, so it's captured from day one instead of staying blank until manually typed.
    user.email = Supabase.instance.client.auth.currentUser?.email;
    notifyListeners();
  }

  // Profile / session loading. tryLoadExistingProfile() returns true if an existing profile was
  // found and loaded (returning user — skip Setup), false if not (new user — go to Setup). The
  // avatar photo is local-only by design and never round-tripped.

  // Needed since sign-out became real. Without this, switching accounts would
  // briefly show the previous account's points/deeds/friends/etc. before fresh data loads,
  // since none of this was ever being cleared on its own.
  void resetLocalState() {
    user = UserProfile();
    membershipNumber = null;
    deedsLog = [];
    deedHistoryLoaded = false;
    justCompletedSetup = false;
    moderationQueue = [];
    lastLoggedAt = {};
    feedback = [];
    notifications = [];
    friends = [];
    pendingFriendRequests = [];
    assignedByMe = [];
    assignedToMe = [];
    notifyListeners();
  }

  Future<bool> tryLoadExistingProfile() async {
    final uid = Supabase.instance.client.auth.currentUser?.id;
    if (uid == null) return false;
    final rows = await Supabase.instance.client.from('profiles').select().eq('id', uid).limit(1);
    if (rows.isEmpty) return false;
    final row = rows.first;
    user.name = row['name'] as String? ?? user.name;
    user.email = row['email'] as String?;
    user.phone = row['phone'] as String?;
    user.city = row['city'] as String? ?? user.city;
    user.points = row['points'] as int? ?? 0;
    // Real fix here — loads the real, saved wallpaper selection now, matching the new save
    // logic in setWallpaperSwatch(). Without this, even a successful save would still look
    // broken, since nothing would ever read it back on the next session.
    wallpaperSwatchIndex = row['wallpaper_swatch_index'] as int? ?? wallpaperSwatchIndex;

    // Global equip is loaded separately via loadEquippedSkin(), called at profile level.

    // New — which campaigns this user has fully completed, for the Home tick mark. Loaded here
    // (once, with everything else) rather than per-campaign-card, since Home shows all active
    // campaigns at once and needs this for each of them.
    try {
      final completedRows = await Supabase.instance.client.from('hall_of_fame_claims').select('campaign_id').eq('user_id', uid);
      completedCampaignIds = completedRows.map<String>((r) => r['campaign_id'] as String).toSet();
    } catch (_) {
      // Tick mark just won't show yet if this fails — doesn't block anything else.
    }

    // Load real deed history too — was missing before, which meant a returning user's badges,
    // cooldowns, and daily-milestone progress would all silently reset to nothing every time
    // they reopened the app, even though their points correctly persisted. Badges/tiers don't
    // need their own separate sync — they're computed locally from this same deed history via
    // _applyBadgeUpdate(), same as they always were.
    try {
      final deedRows = await Supabase.instance.client.from('deeds').select().eq('user_id', uid).order('created_at');
      deedsLog = deedRows.map<DeedLogEntry>((d) {
        // day stays 0 deliberately — this is the correct, intentional fix from before (loaded
        // history never counts toward THIS session's fresh milestone/cooldown progress, since
        // simDay is a purely local testing counter with no real relationship to calendar dates).
        // createdAt is the NEW, separate fix: real bug found — Achievements' "Today"/"This Week"
        // filtering was ALSO using this same simDay-based day field, so once a deed's day got set
        // to 0 for the milestone fix, it silently vanished from Achievements too, even though it
        // genuinely happened today. Real calendar-date filtering (via createdAt below) is
        // independent of the simDay hack entirely, so both concerns are now correctly separated
        // instead of one field trying to serve two different, incompatible purposes.
        final createdAt = DateTime.tryParse(d['created_at'] as String? ?? '') ?? DateTime.now();
        return DeedLogEntry(
          id: d['id'] as String?,
          type: d['type'] as String,
          points: d['points'] as int,
          day: 0,
          createdAt: createdAt,
          status: d['status'] as String,
          campaignId: d['campaign_id'] as String?,
        );
      }).toList();
      deedHistoryLoaded = true;

      // Reconstruct cooldowns from the most recent deed per type, so a real hour-long cooldown
      // persists across app restarts instead of resetting the moment the app reopens.
      lastLoggedAt = {};
      for (final d in deedRows) {
        final type = d['type'] as String;
        final createdAt = DateTime.tryParse(d['created_at'] as String? ?? '');
        if (createdAt == null) continue;
        final existing = lastLoggedAt[type];
        if (existing == null || createdAt.isAfter(existing)) lastLoggedAt[type] = createdAt;
      }

      // Load already-known badges first, so _applyBadgeUpdate() below has the correct baseline
      // to diff against — without this, every badge would look "newly unlocked" on every single
      // app restart (since local state always starts empty), triggering pointless repeat writes
      // to user_badges every time, not just genuinely new unlocks.
      try {
        final badgeRows = await Supabase.instance.client.from('user_badges').select('badge_id').eq('user_id', uid);
        user.badges = badgeRows.map<String>((b) => b['badge_id'] as String).toList();
      } catch (_) {
        // Falls through to full local recomputation below regardless.
      }

      await _loadFrozenBadgeIds();
      _applyBadgeUpdate(); // recompute badges/tier from the real history just loaded
    } catch (_) {
      // Deed history failing to load shouldn't block sign-in entirely — the person still gets
      // into the app with at least their profile basics; deeds/badges just won't reflect history
      // until the next successful load. Known gap, same reasoning as the submission-side writes.
    }

    // Real load now — was mock data this whole time, never connected.
    await _loadAssignedDeeds(uid);
    // Real leaderboard data — needed before Home renders "you're ranked #X", since that now
    // depends on this being loaded rather than a hardcoded mock list.
    await loadLeaderboard();

    // Real membership number fetch — table's RLS already guarantees this only ever returns
    // your own row, regardless of what's queried.
    try {
      final rows = await Supabase.instance.client.from('membership_numbers').select('membership_number').eq('user_id', uid).limit(1);
      membershipNumber = rows.isNotEmpty ? rows.first['membership_number'] as String? : null;
    } catch (_) {
      // Doesn't block sign-in — just won't show until the next successful load.
    }

    // Feedback history too — was previously lost entirely on every app reopen, including any
    // moderator response that had already been given.
    try {
      final feedbackRows = await Supabase.instance.client.from('feedback').select().eq('user_id', uid).order('created_at', ascending: false);
      feedback = feedbackRows.map<FeedbackEntry>((f) => FeedbackEntry(
            id: f['id'] as String?,
            stars: f['stars'] as int,
            text: f['text'] as String? ?? '',
            day: simDay,
            responded: f['responded'] as bool? ?? false,
            response: f['response'] as String?,
          )).toList();
    } catch (_) {
      // Same reasoning — doesn't block sign-in.
    }

    // Real bug fixed here: friendships were never loaded from Supabase at all — a friend
    // connection created via redeeming an invite code was only ever visible in whichever
    // session it happened in. Neither the redeemer nor the issuer would see it again after
    // reopening the app, on either side. Fixed by actually fetching it now.
    try {
      final rows = await Supabase.instance.client
          .from('friendships')
          .select('id, requester_id, addressee_id, favorited_by_requester, favorited_by_addressee')
          .or('requester_id.eq.$uid,addressee_id.eq.$uid')
          .eq('status', 'approved');
      final otherIds = rows.map<String>((r) => r['requester_id'] == uid ? r['addressee_id'] as String : r['requester_id'] as String).toList();
      if (otherIds.isNotEmpty) {
        final otherProfiles = await Supabase.instance.client.rpc('get_public_profiles', params: {'ids': otherIds}) as List<dynamic>;
        final namesById = {for (final p in otherProfiles) p['id'] as String: publicDisplayName(p['name'] as String?, fallback: 'Friend')};
        friends = rows.map<FriendEntry>((r) {
          final isRequester = r['requester_id'] == uid;
          final otherId = isRequester ? r['addressee_id'] as String : r['requester_id'] as String;
          final favorited = (isRequester ? r['favorited_by_requester'] : r['favorited_by_addressee']) as bool? ?? false;
          return FriendEntry(id: otherId, friendshipId: r['id'] as String, isRequester: isRequester, name: namesById[otherId] ?? 'Friend', favorited: favorited);
        }).toList();
      } else {
        friends = [];
      }
    } catch (_) {
      // Doesn't block sign-in — friends list just won't reflect real connections until the
      // next successful load.
    }
    await loadPendingFriendRequests();

    // Real notifications too — was always an empty list before, since nothing ever loaded them
    // and (separately) nothing could even write one, given the missing INSERT policy.
    try {
      final notifRows = await Supabase.instance.client.from('notifications').select().eq('user_id', uid).order('created_at', ascending: false);
      final previousIds = notifications.map((n) => n.id).toSet();
      final loaded = notifRows.map<AppNotification>((n) => AppNotification(
            id: n['id'] as String,
            type: n['type'] as String,
            title: n['title'] as String,
            body: n['body'] as String,
            day: simDay,
            read: n['read'] as bool? ?? false,
          )).toList();
      // New — real system notification (with sound) for anything that's genuinely new since the
      // last load, not just the in-app list updating silently. Guarded by previousIds being
      // non-empty so this doesn't fire once for every notification the very first time someone
      // ever loads their profile (which would just be existing history, not something new).
      if (previousIds.isNotEmpty) {
        for (final n in loaded) {
          if (!previousIds.contains(n.id)) {
            showLocalNotification(title: n.title, body: n.body);
          }
        }
      }
      notifications = loaded;
    } catch (_) {
      // Doesn't block sign-in — same reasoning as above.
    }

    notifyListeners();
    return true;
  }

  // Called once, right after Profile Setup completes for a brand-new user — creates their row
  // in Supabase to match what completeSetup() just did locally.
  // Real bug fixed here: this had no error handling at all. If this insert failed for any
  // reason — a leftover row from an account that was only ever "requested" for deletion, not
  // actually removed (Delete Account never auto-deletes, by design), a network issue, anything —
  // the failure was completely silent. No error shown anywhere the person could see, the
  // Continue button would just look enabled and do nothing when tapped. Real error surfaced now.
  Future<String?> createProfileInSupabase() async {
    final uid = Supabase.instance.client.auth.currentUser?.id;
    final email = Supabase.instance.client.auth.currentUser?.email;
    if (uid == null) return 'You need to be signed in to do this.';
    if (user.city.trim().isEmpty) return 'Please pick your city to continue.'; // never write an empty city
    try {
      await Supabase.instance.client.from('profiles').insert({
        'id': uid,
        'name': user.name,
        'email': email,
        'phone': user.phone,
        'city': user.city,
        'gender': user.gender,
        'dob': user.dob,
      });
      // Brand-new profile — zero deeds is certain, not a guess from an unloaded list.
      deedHistoryLoaded = true;
      return null;
    } catch (e) {
      return 'Could not create your profile: ${e.toString()}';
    }
  }

  // Ported from saveEditProfile() in the original — Photo/Name/Phone/Email only. Gender, DOB,
  // and City are intentionally NOT editable here, matching the original's setup-screen
  // disclaimer ("cannot be changed later") — this isn't an oversight, it's the same rule
  // enforced by simply not exposing those fields on this screen.
  // Real bug fixed here: this only ever updated local state — despite createProfileInSupabase()
  // existing for the initial signup, there was never an equivalent for updating an EXISTING
  // profile afterward. A name change would look like it worked (local state updates
  // immediately) but silently never reached the database, so it wouldn't survive a restart or
  // be visible anywhere else (the admin site, another device).
  Future<String?> updateProfile({required String name, String? phone, String? email, File? avatarFile, bool removeAvatar = false}) async {
    user.name = name;
    user.phone = phone;
    user.email = email;
    if (removeAvatar) {
      user.avatarFile = null;
    } else if (avatarFile != null) {
      user.avatarFile = avatarFile;
    }
    notifyListeners();

    final uid = Supabase.instance.client.auth.currentUser?.id;
    if (uid == null) return 'You need to be signed in to do this.';
    try {
      await Supabase.instance.client.from('profiles').update({
        'name': name,
        'phone': phone,
        'email': email,
      }).eq('id', uid);
      return null;
    } catch (e) {
      return 'Could not save your changes: ${e.toString()}';
    }
  }

  // New — pilot-scoped delete account: submits a request with a reason for a moderator to
  // review, rather than the app deleting the auth account itself. Real deletion needs a
  // service_role key or Edge Function, neither of which should live in client-side app code —
  // that's a real security risk, not just extra engineering effort. Reasonable to build for
  // real post-pilot once this simpler flow shows what people actually cite as reasons.
  Future<String?> submitAccountDeletionRequest(String? reason) async {
    final uid = Supabase.instance.client.auth.currentUser?.id;
    if (uid == null) return 'You need to be signed in to do this.';
    try {
      await Supabase.instance.client.from('account_deletion_requests').insert({
        'user_id': uid,
        'reason': reason,
      });
      return null;
    } catch (e) {
      return 'Could not submit your request: ${e.toString()}';
    }
  }
}
