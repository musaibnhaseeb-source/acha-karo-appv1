import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../theme/app_theme.dart';
import '../state/app_state.dart';
import '../widgets/animated_wallpaper.dart';
import '../widgets/offline_ui.dart';
import '../utils/invite_response.dart';

// New — real, reachable screen backed by invites.sql. Same admin-managed pattern as campaigns:
// moderators create rows directly in Supabase (who qualifies is their judgment call against
// real roadmap_claims data, not something this screen or the app computes), the app just
// displays whatever's real. Honest empty state until a real invite exists, same "blank until
// real" principle used everywhere else in this project.
class InvitesScreen extends StatefulWidget {
  const InvitesScreen({super.key});
  @override
  State<InvitesScreen> createState() => _InvitesScreenState();
}

class _Invite {
  final String id;
  final String inviteType;
  final String message;
  final String? formUrl;
  final bool seen;
  final DateTime createdAt;
  final String? response; // null | 'accepted' | 'declined' (set only by the respond_to_invite RPC)
  const _Invite({required this.id, required this.inviteType, required this.message, this.formUrl, required this.seen, required this.createdAt, this.response});
}

class _InvitesScreenState extends State<InvitesScreen> {
  List<_Invite> invites = [];
  bool loading = true;
  String? error;
  final Set<String> _answering = {}; // invite ids with an answer in flight (no double taps)

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { loading = true; error = null; });
    try {
      final uid = Supabase.instance.client.auth.currentUser?.id;
      if (uid == null) return;
      final rows = await Supabase.instance.client.from('invites').select().eq('user_id', uid).order('created_at', ascending: false);
      setState(() {
        invites = rows.map<_Invite>((r) => _Invite(
              id: r['id'] as String,
              inviteType: r['invite_type'] as String,
              message: r['message'] as String,
              formUrl: r['form_url'] as String?,
              seen: r['seen'] as bool? ?? false,
              createdAt: DateTime.parse(r['created_at'] as String),
              response: r['response'] as String?,
            )).toList();
        loading = false;
      });
    } catch (e) {
      // Never the raw error (it can carry ids): a friendly line + Try again.
      if (mounted) setState(() { error = InviteCopy.loadFailed; loading = false; });
    }
  }

  Future<void> _markSeen(_Invite invite) async {
    if (invite.seen) return;
    try {
      await Supabase.instance.client.from('invites').update({'seen': true}).eq('id', invite.id);
      _load();
    } catch (_) {
      // Not critical if this fails — the invite itself is still fully visible either way.
    }
  }

  // Accept / Decline through the respond_to_invite RPC only (never a direct column write).
  // Offline: nothing is queued — just the needs-internet note. Decline asks first.
  Future<void> _answer(_Invite invite, {required bool accept}) async {
    if (context.read<AppState>().isOffline) {
      showNeedsInternet(context);
      return;
    }
    if (_answering.contains(invite.id)) return;
    if (!accept && !await _confirmDecline()) return;
    if (!mounted) return;
    setState(() => _answering.add(invite.id));
    final messenger = ScaffoldMessenger.of(context);
    try {
      await Supabase.instance.client.rpc(respondToInviteRpc, params: respondToInviteParams(invite.id, accept: accept));
    } catch (_) {
      messenger.showSnackBar(const SnackBar(content: Text(InviteCopy.sendFailed)));
    }
    if (!mounted) return;
    setState(() => _answering.remove(invite.id));
    await _load(); // shows the saved answer (or the real state after a failure)
  }

  Future<bool> _confirmDecline() async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.bg2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text(InviteCopy.declineTitle, style: AppFonts.fraunces(size: 16, weight: FontWeight.w600)),
        content: Text(InviteCopy.declineBody, style: AppFonts.inter(size: 12.5, color: AppColors.textSoft)),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: Text(InviteCopy.declineCancel, style: AppFonts.inter(size: 13, color: AppColors.textSoft))),
          TextButton(
            key: const ValueKey('invite-decline-confirm'),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(InviteCopy.declineConfirm, style: AppFonts.inter(size: 13, weight: FontWeight.w700, color: const Color(0xFFE39B84))),
          ),
        ],
      ),
    );
    return yes ?? false;
  }

  Widget _answerArea(_Invite invite) {
    if (invite.response != null) {
      final accepted = invite.response == 'accepted';
      return Container(
        key: ValueKey('invite-status-${invite.id}'),
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: accepted ? AppColors.gold.withOpacity(0.15) : AppColors.bg2.withOpacity(0.4),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: accepted ? AppColors.gold.withOpacity(0.45) : const Color(0x29F6F5EC)),
        ),
        child: Text(accepted ? InviteCopy.accepted : InviteCopy.declined,
            style: AppFonts.inter(size: 12, weight: FontWeight.w600, color: accepted ? AppColors.gold : AppColors.textSoft)),
      );
    }
    final busy = _answering.contains(invite.id);
    return Row(children: [
      Expanded(
        child: GestureDetector(
          key: ValueKey('invite-accept-${invite.id}'),
          onTap: busy ? null : () => _answer(invite, accept: true),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 11),
            decoration: BoxDecoration(color: AppColors.gold, borderRadius: BorderRadius.circular(10)),
            alignment: Alignment.center,
            child: busy
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.inkOnGold))
                : Text(InviteCopy.accept, style: AppFonts.inter(size: 12.5, weight: FontWeight.w700, color: AppColors.inkOnGold)),
          ),
        ),
      ),
      const SizedBox(width: 8),
      Expanded(
        child: GestureDetector(
          key: ValueKey('invite-decline-${invite.id}'),
          onTap: busy ? null : () => _answer(invite, accept: false),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 11),
            decoration: BoxDecoration(color: Colors.transparent, borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0x52F6F5EC))),
            alignment: Alignment.center,
            child: Text(InviteCopy.decline, style: AppFonts.inter(size: 12.5, weight: FontWeight.w700, color: AppColors.text)),
          ),
        ),
      ),
    ]);
  }

  Future<void> _openForm(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  // Real fix here: this only ever recognized two types, silently mislabeling anything else
  // (including the newer service_call type) as a Co-Create Invite. Now handles all three real
  // types explicitly, with an honest fallback for anything genuinely unrecognized.
  String _label(String type) {
    switch (type) {
      case 'karocast':
        return '🎙️ KaroCast Invite';
      case 'town_voice':
        return '🎙️ Town Voice Invite';
      case 'co_create':
        return '🤝 Co-Create Invite';
      case 'service_call':
        return '📞 Service Call Invite';
      default:
        return '✉️ Invite';
    }
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
        title: Text('Invites', style: AppFonts.inter(size: 14, weight: FontWeight.w600)),
        centerTitle: true,
      ),
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
            child: AnimatedWallpaper(gradientColors: wallpaperSwatches[state.wallpaperSwatchIndex]),
          ),
          SafeArea(
            child: loading
                ? const Center(child: CircularProgressIndicator(color: AppColors.gold))
                : error != null
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(mainAxisSize: MainAxisSize.min, children: [
                            Text(error!, textAlign: TextAlign.center, style: AppFonts.inter(size: 12, color: AppColors.textSoft)),
                            const SizedBox(height: 10),
                            TextButton(onPressed: _load, child: Text(InviteCopy.retry, style: AppFonts.inter(size: 13, weight: FontWeight.w700, color: AppColors.gold))),
                          ]),
                        ),
                      )
                    : SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(18, 10, 18, 30),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('✉️ Invites', style: AppFonts.fraunces(size: 22, weight: FontWeight.w600)),
                            const SizedBox(height: 4),
                            Text('KaroCast and co-create opportunities sent your way.', style: AppFonts.inter(size: 12, color: AppColors.textSoft)),
                            const SizedBox(height: 18),
                            if (invites.isEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 40),
                                child: Center(
                                  child: Column(children: [
                                    Opacity(opacity: 0.4, child: const Text('✉️', style: TextStyle(fontSize: 44))),
                                    const SizedBox(height: 14),
                                    Text('Nothing here yet', style: AppFonts.fraunces(size: 15, weight: FontWeight.w600)),
                                    const SizedBox(height: 6),
                                    Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 24),
                                      child: Text('Real opportunities appear here when the team reaches out directly.', textAlign: TextAlign.center, style: AppFonts.inter(size: 12, color: AppColors.textSoft, height: 1.6)),
                                    ),
                                  ]),
                                ),
                              )
                            else
                              ...invites.map((invite) => Padding(
                                    padding: const EdgeInsets.only(bottom: 10),
                                    child: GestureDetector(
                                      onTap: () => _markSeen(invite),
                                      child: Container(
                                        padding: const EdgeInsets.all(16),
                                        decoration: BoxDecoration(
                                          color: AppColors.oliveCard,
                                          borderRadius: BorderRadius.circular(14),
                                          border: Border.all(color: invite.seen ? const Color(0x29F6F5EC) : AppColors.gold.withOpacity(0.5)),
                                        ),
                                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                          Row(children: [
                                            Expanded(child: Text(_label(invite.inviteType), style: AppFonts.inter(size: 13, weight: FontWeight.w700))),
                                            if (!invite.seen)
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                                decoration: BoxDecoration(color: AppColors.gold.withOpacity(0.18), borderRadius: BorderRadius.circular(100)),
                                                child: Text('NEW', style: AppFonts.plexMono(size: 8.5, weight: FontWeight.w700, color: AppColors.gold)),
                                              ),
                                          ]),
                                          const SizedBox(height: 8),
                                          Text(invite.message, style: AppFonts.inter(size: 12.5, color: AppColors.textSoft, height: 1.5)),
                                          if (invite.inviteType == 'town_voice') ...[
                                            const SizedBox(height: 8),
                                            Text(InviteCopy.guardianNote, key: ValueKey('invite-guardian-${invite.id}'), style: AppFonts.inter(size: 11, weight: FontWeight.w600, color: AppColors.text, height: 1.45)),
                                          ],
                                          if (invite.formUrl != null) ...[
                                            const SizedBox(height: 12),
                                            GestureDetector(
                                              onTap: () => _openForm(invite.formUrl!),
                                              child: Container(
                                                padding: const EdgeInsets.symmetric(vertical: 11),
                                                width: double.infinity,
                                                decoration: BoxDecoration(color: AppColors.gold, borderRadius: BorderRadius.circular(10)),
                                                alignment: Alignment.center,
                                                child: Text('Open Form', style: AppFonts.inter(size: 12.5, weight: FontWeight.w700, color: AppColors.inkOnGold)),
                                              ),
                                            ),
                                          ],
                                          // Accept / Decline (karocast, town_voice, service_call), or the saved answer.
                                          if (inviteNeedsAnswer(invite.inviteType, invite.response) || invite.response != null) ...[
                                            const SizedBox(height: 12),
                                            _answerArea(invite),
                                          ],
                                        ]),
                                      ),
                                    ),
                                  )),
                          ],
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}
