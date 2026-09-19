import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../theme/app_theme.dart';
import '../state/app_state.dart';
import '../widgets/animated_wallpaper.dart';

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
  const _Invite({required this.id, required this.inviteType, required this.message, this.formUrl, required this.seen, required this.createdAt});
}

class _InvitesScreenState extends State<InvitesScreen> {
  List<_Invite> invites = [];
  bool loading = true;
  String? error;

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
            )).toList();
        loading = false;
      });
    } catch (e) {
      setState(() { error = 'Could not load invites: ${e.toString()}'; loading = false; });
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
                    ? Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(error!, textAlign: TextAlign.center, style: AppFonts.inter(size: 12, color: AppColors.textSoft))))
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
