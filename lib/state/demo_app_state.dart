import '../data/deed_catalog.dart';
import 'app_state.dart';

// Debug-only preview data for FriendsScreen — lets Musa/the team click through the Approve/
// Manage/Assigned tabs and the adult/minor relationship-answer dialog with realistic-looking
// data, without a single Supabase call (the real request_friend/accept_friend_request RPCs
// don't even exist server-side yet). Only ever instantiated from behind the kDebugMode gate in
// home_side_sheet.dart, which Dart strips entirely from release builds — this class is never
// reachable by a real user or in a release build.
//
// Overrides just the 7 friend-related action methods to mutate the in-memory lists seeded
// below; everything else (points, badges, leaderboard, etc.) falls through to the real AppState
// implementation, which is never invoked here since FriendsScreen only touches friends-state.
class DemoAppState extends AppState {
  DemoAppState() {
    friends = [
      FriendEntry(id: 'demo-friend-1', friendshipId: 'demo-friendship-1', isRequester: true, name: 'Ayesha K.', favorited: true),
      FriendEntry(id: 'demo-friend-2', friendshipId: 'demo-friendship-2', isRequester: false, name: 'Bilal S.'),
      FriendEntry(id: 'demo-friend-3', friendshipId: 'demo-friendship-3', isRequester: true, name: 'Zainab R.', favorited: true),
    ];
    pendingFriendRequests = [
      const PendingFriendRequest(id: 'demo-request-1', requesterId: 'demo-requester-1', name: 'Hamza T.'),
      // This one is wired below to trigger the relationship-answer branch on approve, so that
      // flow is actually reachable in the demo rather than just the request-side dialog.
      const PendingFriendRequest(id: 'demo-request-2', requesterId: 'demo-requester-2', name: 'Sara N.'),
    ];
    final sampleDeedType = deedCatalog.keys.first;
    assignedByMe = [
      AssignedDeed(id: 'demo-assigned-1', friendId: 'demo-friend-1', friendName: 'Ayesha K.', deedType: sampleDeedType, day: simDay),
    ];
    assignedToMe = [
      AssignedDeed(id: 'demo-assigned-2', friendId: 'demo-friend-2', friendName: 'Bilal S.', deedType: sampleDeedType, day: simDay),
    ];
  }

  int _demoIdCounter = 0;
  String _nextDemoId() => 'demo-new-${_demoIdCounter++}';

  @override
  Future<Map<String, dynamic>> requestFriend(String membershipNumber, String name, {String? relationshipAnswer}) async {
    if (relationshipAnswer == null) {
      // Fakes an adult/minor cross-boundary match so the requester-side relationship picker is
      // exercised too, not just the approve-side one.
      return {
        'status': 'needs_relationship_answer',
        'requester_is_adult': true,
        'options': const ['Parent', 'Grandparent', 'Aunt/Uncle', 'Teacher/Mentor', 'Sibling', 'Family Friend', 'Neighbor', 'Other'],
      };
    }
    return {'status': 'success'};
  }

  @override
  Future<Map<String, dynamic>> acceptFriendRequest(String friendshipId, {String? relationshipAnswer}) async {
    final match = pendingFriendRequests.where((r) => r.id == friendshipId).toList();
    if (match.isEmpty) return {'status': 'error', 'message': 'Request not found.'};

    if (friendshipId == 'demo-request-2' && relationshipAnswer == null) {
      return {
        'status': 'needs_relationship_answer',
        'requester_is_adult': false,
        'options': const ['Child', 'Grandchild', 'Niece/Nephew', 'Student', 'Sibling', 'Family Friend', 'Neighbor', 'Other'],
      };
    }

    pendingFriendRequests.removeWhere((r) => r.id == friendshipId);
    friends.add(FriendEntry(id: match.first.requesterId, friendshipId: friendshipId, isRequester: false, name: match.first.name));
    notifyListeners();
    return {'status': 'success'};
  }

  @override
  Future<void> declineFriendRequest(String friendshipId) async {
    pendingFriendRequests.removeWhere((r) => r.id == friendshipId);
    notifyListeners();
  }

  @override
  Future<void> toggleFavoriteFriend(String id) async {
    final matches = friends.where((f) => f.id == id).toList();
    if (matches.isEmpty) return;
    final f = matches.first;
    final favoritedCount = friends.where((x) => x.favorited).length;
    if (!f.favorited && favoritedCount >= AppState.maxFavoriteFriends) return;
    f.favorited = !f.favorited;
    notifyListeners();
  }

  @override
  Future<void> removeFriend(String id) async {
    friends.removeWhere((f) => f.id == id);
    notifyListeners();
  }

  @override
  Future<String?> assignDeedToFriend(String friendId, String friendName, String deedType) async {
    assignedByMe.add(AssignedDeed(id: _nextDemoId(), friendId: friendId, friendName: friendName, deedType: deedType, day: simDay));
    notifyListeners();
    return null;
  }

  @override
  Future<String?> markAssignedDeedComplete(String id) async {
    final idx = assignedToMe.indexWhere((a) => a.id == id);
    if (idx != -1) {
      assignedToMe[idx].completed = true;
      notifyListeners();
    }
    return null;
  }
}
