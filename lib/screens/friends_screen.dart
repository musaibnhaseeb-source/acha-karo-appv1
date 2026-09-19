import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../state/app_state.dart';
import '../widgets/animated_wallpaper.dart';
import '../data/deed_catalog.dart';

enum FriendsSubTab { approve, manage, assigned }

// Ported from #moreTabFriends in the original — three sub-tabs (Approve/Manage/Assigned), same
// order and labels. "Add friend" generates a one-time text invite code instead of a QR code —
// QR generation/scanning needs new packages not yet added or verified in this project, so this
// is the real underlying "one-time invite" mechanic without that added risk. Can be upgraded to
// QR later without changing anything else about how friends/requests work.
class FriendsScreen extends StatefulWidget {
  final FriendsSubTab initialTab;
  const FriendsScreen({super.key, this.initialTab = FriendsSubTab.manage});
  @override
  State<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends State<FriendsScreen> {
  late FriendsSubTab tab;

  @override
  void initState() {
    super.initState();
    tab = widget.initialTab;
  }

  // Invite-link generate/redeem removed entirely — superseded by the membership-number + name
  // request flow below (a real friend request via `friendships`, not a link).

  // Shows the two-field add-friend form, sends the request, and — only for an adult/minor
  // cross-boundary match — walks the requester through the relationship question before the
  // request actually goes out. Every branch (plain success, needs a relationship answer, or an
  // error) is handled here so callers just fire-and-forget this.
  Future<void> _showAddFriendDialog(BuildContext context) async {
    final membershipController = TextEditingController();
    final nameController = TextEditingController();
    final submitted = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.bg2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text('Add a friend', style: AppFonts.fraunces(size: 16, weight: FontWeight.w600)),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Enter their membership number and the name on their profile — both have to match.', style: AppFonts.inter(size: 11.5, color: AppColors.textSoft)),
          const SizedBox(height: 14),
          TextField(
            controller: membershipController,
            style: AppFonts.plexMono(size: 13, color: AppColors.text),
            decoration: InputDecoration(hintText: 'Membership number', hintStyle: AppFonts.plexMono(size: 12, color: AppColors.textSoft.withOpacity(0.5))),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: nameController,
            style: AppFonts.inter(size: 13, color: AppColors.text),
            decoration: InputDecoration(hintText: 'Their name', hintStyle: AppFonts.inter(size: 12, color: AppColors.textSoft.withOpacity(0.5))),
          ),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: Text('Cancel', style: AppFonts.inter(size: 13, color: AppColors.textSoft))),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text('Send request', style: AppFonts.inter(size: 13, weight: FontWeight.w700, color: AppColors.gold)),
          ),
        ],
      ),
    );
    if (submitted != true || !context.mounted) return;

    final membershipNumber = membershipController.text.trim();
    final name = nameController.text.trim();
    if (membershipNumber.isEmpty || name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Both fields are required.')));
      return;
    }

    final appState = context.read<AppState>();
    var result = await appState.requestFriend(membershipNumber, name);
    if (!context.mounted) return;

    if (result['status'] == 'needs_relationship_answer') {
      final isAdult = result['requester_is_adult'] as bool? ?? true;
      final options = (result['options'] as List<dynamic>? ?? []).cast<String>();
      final answer = await _showRelationshipPicker(context, isAdult: isAdult, forRequester: true);
      if (answer == null || !context.mounted) return; // cancelled — nothing was sent
      if (!options.contains(answer)) return; // shouldn't happen, options come straight from the server
      result = await appState.requestFriend(membershipNumber, name, relationshipAnswer: answer);
      if (!context.mounted) return;
    }

    final status = result['status'] as String?;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(status == 'success' ? 'Friend request sent.' : (result['message'] as String? ?? 'Something went wrong.')),
    ));
  }

  // Mirrors _showAddFriendDialog's two-step handling, on the accept side — accept can also come
  // back needing a relationship answer (only the server knows both users' dob), and the broken
  // wiring this replaced (a call to a nonexistent `approveFriendRequest`, passing the display name
  // instead of the friendship id) meant that branch was never reachable to begin with.
  Future<void> _handleApprove(BuildContext context, PendingFriendRequest request) async {
    final appState = context.read<AppState>();
    var result = await appState.acceptFriendRequest(request.id);
    if (!context.mounted) return;

    if (result['status'] == 'needs_relationship_answer') {
      final isAdult = result['requester_is_adult'] as bool? ?? true;
      final answer = await _showRelationshipPicker(context, isAdult: isAdult, forRequester: false);
      if (answer == null || !context.mounted) return; // cancelled — request stays pending
      result = await appState.acceptFriendRequest(request.id, relationshipAnswer: answer);
      if (!context.mounted) return;
    }

    final status = result['status'] as String?;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text((status == 'success' || status == 'flagged') ? 'Friend request accepted.' : (result['message'] as String? ?? 'Something went wrong.')),
    ));
  }

  // Shared by both the requester (send-time) and the addressee (accept-time) — the server tells
  // the caller which set of options applies and whether this is the "adult" or "minor" side of
  // the question, per Musa's exact framing ("How is this minor/adult related to you?").
  Future<String?> _showRelationshipPicker(BuildContext context, {required bool isAdult, required bool forRequester}) {
    return showDialog<String>(
      context: context,
      builder: (ctx) {
        final options = forRequester
            ? (isAdult
                ? const ['Parent', 'Grandparent', 'Aunt/Uncle', 'Teacher/Mentor', 'Sibling', 'Family Friend', 'Neighbor', 'Other']
                : const ['Child', 'Grandchild', 'Niece/Nephew', 'Student', 'Sibling', 'Family Friend', 'Neighbor', 'Other'])
            : (isAdult
                ? const ['Parent', 'Grandparent', 'Aunt/Uncle', 'Teacher/Mentor', 'Sibling', 'Family Friend', 'Neighbor', 'Other']
                : const ['Child', 'Grandchild', 'Niece/Nephew', 'Student', 'Sibling', 'Family Friend', 'Neighbor', 'Other']);
        return AlertDialog(
          backgroundColor: AppColors.bg2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: Text(
            isAdult ? 'How is this minor related to you?' : 'How is this adult related to you?',
            style: AppFonts.fraunces(size: 15, weight: FontWeight.w600),
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: options
                  .map((o) => Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: GestureDetector(
                          onTap: () => Navigator.of(ctx).pop(o),
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                            decoration: BoxDecoration(color: AppColors.oliveCard, borderRadius: BorderRadius.circular(10)),
                            child: Text(o, style: AppFonts.inter(size: 12.5, weight: FontWeight.w600)),
                          ),
                        ),
                      ))
                  .toList(),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(), child: Text('Cancel', style: AppFonts.inter(size: 13, color: AppColors.textSoft))),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(icon: const Icon(Icons.arrow_back, color: AppColors.text), onPressed: () => Navigator.of(context).pop()),
        title: Text('Friends', style: AppFonts.inter(size: 14, weight: FontWeight.w600)),
        centerTitle: true,
        actions: [
          IconButton(icon: const Icon(Icons.person_add_alt_1, color: AppColors.gold, size: 20), onPressed: () => _showAddFriendDialog(context)),
        ],
      ),
      // Same real bug fixed here as the other screens in this batch.
      body: Stack(
        // Real, genuine root-cause fix: Stack defaults to StackFit.loose, meaning it sizes
        // itself to its non-Positioned child (SafeArea), which in turn sizes to its OWN content
        // rather than filling available space. Every previous attempt only ever changed the
        // background widget itself, never addressed this — the Positioned background was
        // always being clipped down to match the Stack's own, content-sized bounds, regardless
        // of what explicit size it was given. This forces the Stack itself to fill available
        // space unconditionally, which is the actual fix.
        fit: StackFit.expand,
        children: [
          Positioned(
            top: 0,
            left: 0,
            width: MediaQuery.of(context).size.width,
            height: MediaQuery.of(context).size.height,
            child: AnimatedWallpaper(gradientColors: wallpaperSwatches[context.watch<AppState>().wallpaperSwatchIndex]),
          ),
        SafeArea(
          child: Column(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 10, 18, 0),
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(color: AppColors.bg1.withOpacity(0.35), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0x1FF6F5EC))),
                child: Row(children: [
                  Expanded(child: _SegBtn(label: 'Approve', active: tab == FriendsSubTab.approve, onTap: () => setState(() => tab = FriendsSubTab.approve))),
                  Expanded(child: _SegBtn(label: 'Manage', active: tab == FriendsSubTab.manage, onTap: () => setState(() => tab = FriendsSubTab.manage))),
                  Expanded(child: _SegBtn(label: 'Assigned', active: tab == FriendsSubTab.assigned, onTap: () => setState(() => tab = FriendsSubTab.assigned))),
                ]),
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(18, 14, 18, 30),
                child: switch (tab) {
                  FriendsSubTab.approve => _ApproveTab(
                      state: state,
                      onApprove: (r) => _handleApprove(context, r),
                      onDecline: (r) => state.declineFriendRequest(r.id),
                    ),
                  FriendsSubTab.manage => _ManageTab(state: state),
                  FriendsSubTab.assigned => _AssignedTab(state: state),
                },
              ),
            ),
          ]),
        ),
        ],
      ),
    );
  }
}

class _SegBtn extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _SegBtn({required this.label, required this.active, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(color: active ? AppColors.gold : Colors.transparent, borderRadius: BorderRadius.circular(9)),
        alignment: Alignment.center,
        child: Text(label, textAlign: TextAlign.center, style: AppFonts.plexMono(size: 11, weight: FontWeight.w600, color: active ? AppColors.inkOnGold : AppColors.textSoft)),
      ),
    );
  }
}

class _ApproveTab extends StatelessWidget {
  final AppState state;
  final void Function(PendingFriendRequest) onApprove;
  final void Function(PendingFriendRequest) onDecline;
  const _ApproveTab({required this.state, required this.onApprove, required this.onDecline});
  @override
  Widget build(BuildContext context) {
    if (state.pendingFriendRequests.isEmpty) {
      return Padding(
        padding: const EdgeInsets.only(top: 30),
        child: Center(child: Text('No pending requests.', style: AppFonts.inter(size: 12, color: AppColors.textSoft))),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Friend requests waiting for your approval.', style: AppFonts.inter(size: 12, color: AppColors.textSoft)),
        const SizedBox(height: 12),
        ...state.pendingFriendRequests.map((r) => Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(color: AppColors.oliveCard, borderRadius: BorderRadius.circular(14)),
              child: Row(children: [
                Expanded(child: Text(r.name, style: AppFonts.inter(size: 13, weight: FontWeight.w600))),
                GestureDetector(
                  onTap: () => onApprove(r),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                    decoration: BoxDecoration(color: AppColors.olive, borderRadius: BorderRadius.circular(100)),
                    child: Text('✓ Approve', style: AppFonts.inter(size: 11, weight: FontWeight.w700, color: AppColors.inkOnGold)),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () => onDecline(r),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                    decoration: BoxDecoration(color: AppColors.bg2.withOpacity(0.4), borderRadius: BorderRadius.circular(100), border: Border.all(color: const Color(0x29F6F5EC))),
                    child: Text('✕', style: AppFonts.inter(size: 12, weight: FontWeight.w700, color: AppColors.textSoft)),
                  ),
                ),
              ]),
            )),
      ],
    );
  }
}

class _ManageTab extends StatelessWidget {
  final AppState state;
  const _ManageTab({required this.state});

  void _showAssignSheet(BuildContext context, FriendEntry friend) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.bg2,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (sheetContext) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) => ListView(
          controller: scrollController,
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 30),
          children: [
            Text('Assign a deed to ${friend.name}', style: AppFonts.fraunces(size: 16, weight: FontWeight.w600)),
            const SizedBox(height: 14),
            ...deedCatalog.entries.map((entry) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: GestureDetector(
                    onTap: () async {
                      Navigator.of(sheetContext).pop();
                      final error = await context.read<AppState>().assignDeedToFriend(friend.id, friend.name, entry.key);
                      if (error != null && context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
                      } else if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Assigned "${entry.value.name}" to ${friend.name}.')));
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                      decoration: BoxDecoration(color: AppColors.oliveCard, borderRadius: BorderRadius.circular(12)),
                      child: Row(children: [
                        Text(entry.value.icon, style: const TextStyle(fontSize: 16)),
                        const SizedBox(width: 10),
                        Expanded(child: Text(entry.value.name, style: AppFonts.inter(size: 12.5, weight: FontWeight.w600))),
                        Text('+${entry.value.points}', style: AppFonts.plexMono(size: 10.5, color: AppColors.textSoft)),
                      ]),
                    ),
                  ),
                )),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Star up to 5 friends to pin on your Profile, assign a deed, or remove a friend.', style: AppFonts.inter(size: 12, color: AppColors.textSoft)),
        const SizedBox(height: 12),
        if (state.friends.isEmpty)
          Text('No friends yet.', style: AppFonts.inter(size: 12, color: AppColors.textSoft))
        else
          ...state.friends.map((f) => Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(color: AppColors.oliveCard, borderRadius: BorderRadius.circular(14)),
                child: Row(children: [
                  Expanded(child: Text(f.name, style: AppFonts.inter(size: 13, weight: FontWeight.w600))),
                  GestureDetector(
                    onTap: () => _showAssignSheet(context, f),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: Text('📋', style: AppFonts.inter(size: 16)),
                    ),
                  ),
                  GestureDetector(
                    onTap: () => context.read<AppState>().toggleFavoriteFriend(f.id),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: Text(f.favorited ? '★' : '☆', style: TextStyle(fontSize: 20, color: f.favorited ? AppColors.gold : AppColors.textSoft)),
                    ),
                  ),
                  GestureDetector(
                    onTap: () => context.read<AppState>().removeFriend(f.id),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: Text('🗑️', style: AppFonts.inter(size: 15)),
                    ),
                  ),
                ]),
              )),
      ],
    );
  }
}

class _AssignedTab extends StatelessWidget {
  final AppState state;
  const _AssignedTab({required this.state});

  Widget _row(BuildContext context, AssignedDeed a, {required bool showFriendAsAssigner}) {
    final meta = deedCatalog[a.deedType];
    // Only the assignee (assignedToMe side) can mark something complete — matches the RLS policy
    // (assigned_deeds update requires auth.uid() = assignee_id), so this UI mirrors what the
    // database would actually allow anyway.
    final canMarkComplete = showFriendAsAssigner && !a.completed && a.id != null;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(color: AppColors.oliveCard, borderRadius: BorderRadius.circular(14)),
      child: Row(children: [
        Text(meta?.icon ?? '❓', style: const TextStyle(fontSize: 18)),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(meta?.name ?? a.deedType, style: AppFonts.inter(size: 12.5, weight: FontWeight.w600)),
            Text(showFriendAsAssigner ? 'Assigned by ${a.friendName}' : 'Assigned to ${a.friendName}', style: AppFonts.plexMono(size: 9.5, color: AppColors.textSoft)),
          ]),
        ),
        GestureDetector(
          onTap: canMarkComplete
              ? () async {
                  final error = await context.read<AppState>().markAssignedDeedComplete(a.id!);
                  if (error != null && context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
                  }
                }
              : null,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
            decoration: BoxDecoration(color: a.completed ? AppColors.olive.withOpacity(0.2) : AppColors.bg2.withOpacity(0.4), borderRadius: BorderRadius.circular(100)),
            child: Text(
              a.completed ? '✓ Done' : (canMarkComplete ? 'Tap to complete' : 'Pending'),
              style: AppFonts.plexMono(size: 9.5, weight: FontWeight.w700, color: a.completed ? AppColors.olive : AppColors.textSoft),
            ),
          ),
        ),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Assigned to me', style: AppFonts.fraunces(size: 14, weight: FontWeight.w600)),
        const SizedBox(height: 4),
        Text('Deeds friends have assigned to you.', style: AppFonts.inter(size: 11.5, color: AppColors.textSoft)),
        const SizedBox(height: 10),
        if (state.assignedToMe.isEmpty)
          Padding(padding: const EdgeInsets.only(bottom: 20), child: Text('Nothing assigned to you yet.', style: AppFonts.inter(size: 12, color: AppColors.textSoft)))
        else
          ...state.assignedToMe.map((a) => _row(context, a, showFriendAsAssigner: true)),

        const SizedBox(height: 18),
        Text('Assigned by me', style: AppFonts.fraunces(size: 14, weight: FontWeight.w600)),
        const SizedBox(height: 4),
        Text('Deeds you\'ve assigned to friends, and whether they\'ve completed them.', style: AppFonts.inter(size: 11.5, color: AppColors.textSoft)),
        const SizedBox(height: 10),
        if (state.assignedByMe.isEmpty)
          Text('You haven\'t assigned any deeds yet.', style: AppFonts.inter(size: 12, color: AppColors.textSoft))
        else
          ...state.assignedByMe.map((a) => _row(context, a, showFriendAsAssigner: false)),
      ],
    );
  }
}
