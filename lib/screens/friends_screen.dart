import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../state/app_state.dart';
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

  Future<void> _showInviteCode(BuildContext context) async {
    final appState = context.read<AppState>();
    final (link, error) = await appState.generateInviteLink();
    if (!context.mounted) return;
    if (link == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error ?? 'Could not generate an invite link.')));
      return;
    }
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.bg2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text('Your invite link', style: AppFonts.fraunces(size: 16, weight: FontWeight.w600)),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Share this with a friend, along with the app download link — one-time use only.', style: AppFonts.inter(size: 12, color: AppColors.textSoft)),
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
            decoration: BoxDecoration(color: AppColors.oliveCard, borderRadius: BorderRadius.circular(12)),
            alignment: Alignment.center,
            child: Text(link, textAlign: TextAlign.center, style: AppFonts.plexMono(size: 13.5, weight: FontWeight.w700, color: AppColors.gold)),
          ),
        ]),
        actions: [
          TextButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: link));
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Copied to clipboard.')));
            },
            child: Text('Copy', style: AppFonts.inter(size: 13, weight: FontWeight.w600, color: AppColors.gold)),
          ),
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: Text('Done', style: AppFonts.inter(size: 13, color: AppColors.textSoft))),
        ],
      ),
    );
  }

  void _redeemCode(BuildContext context) {
    final codeController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.bg2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text('Redeem a link', style: AppFonts.fraunces(size: 16, weight: FontWeight.w600)),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(
            'This is now real — checks the code against Supabase and connects you with whoever sent it. Their name is looked up automatically.',
            style: AppFonts.inter(size: 10.5, color: AppColors.textSoft, height: 1.4),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: codeController,
            style: AppFonts.plexMono(size: 13, color: AppColors.text),
            decoration: InputDecoration(hintText: 'Paste the invite link', hintStyle: AppFonts.plexMono(size: 13, color: AppColors.textSoft.withOpacity(0.5))),
          ),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: Text('Cancel', style: AppFonts.inter(size: 13, color: AppColors.textSoft))),
          TextButton(
            onPressed: () async {
              final appState = context.read<AppState>();
              final error = await appState.redeemInviteCode(codeController.text);
              if (!ctx.mounted) return;
              Navigator.of(ctx).pop();
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error ?? 'Friend added!')));
            },
            child: Text('Redeem', style: AppFonts.inter(size: 13, weight: FontWeight.w700, color: AppColors.gold)),
          ),
        ],
      ),
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
          IconButton(icon: const Icon(Icons.link, color: AppColors.textSoft, size: 20), onPressed: () => _redeemCode(context), tooltip: 'Redeem a link'),
          IconButton(icon: const Icon(Icons.person_add_alt_1, color: AppColors.gold, size: 20), onPressed: () => _showInviteCode(context)),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: wallpaperSwatches[context.watch<AppState>().wallpaperSwatchIndex])),
        child: SafeArea(
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
                  FriendsSubTab.approve => _ApproveTab(state: state),
                  FriendsSubTab.manage => _ManageTab(state: state),
                  FriendsSubTab.assigned => _AssignedTab(state: state),
                },
              ),
            ),
          ]),
        ),
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
  const _ApproveTab({required this.state});
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
        Text('People who signed up using one of your invite links.', style: AppFonts.inter(size: 12, color: AppColors.textSoft)),
        const SizedBox(height: 12),
        ...state.pendingFriendRequests.map((r) => Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(color: AppColors.oliveCard, borderRadius: BorderRadius.circular(14)),
              child: Row(children: [
                Expanded(child: Text(r.name, style: AppFonts.inter(size: 13, weight: FontWeight.w600))),
                GestureDetector(
                  onTap: () => context.read<AppState>().approveFriendRequest(r.name),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                    decoration: BoxDecoration(color: AppColors.olive, borderRadius: BorderRadius.circular(100)),
                    child: Text('✓ Approve', style: AppFonts.inter(size: 11, weight: FontWeight.w700, color: AppColors.inkOnGold)),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () => context.read<AppState>().declineFriendRequest(r.name),
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
                    onTap: () => context.read<AppState>().toggleFavoriteFriend(f.name),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: Text(f.favorited ? '★' : '☆', style: TextStyle(fontSize: 20, color: f.favorited ? AppColors.gold : AppColors.textSoft)),
                    ),
                  ),
                  GestureDetector(
                    onTap: () => context.read<AppState>().removeFriend(f.name),
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
