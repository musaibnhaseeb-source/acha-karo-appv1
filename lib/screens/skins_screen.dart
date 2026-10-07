import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../theme/app_theme.dart';
import '../state/app_state.dart';
import '../widgets/campaign_icon.dart';
import '../widgets/skin_reveal_dialog.dart';

// Real redesign, per direction: this is now the actual store — both purchase AND equip happen
// here, not split with the Roadmap screen. A campaign skin is locked until the specific stop
// it's tied to (roadmap_stops.skin_id) is genuinely reached — traced directly from the skin's
// own id, not a separate flag. A skin with no gating stop at all (skin_id never referenced by
// any roadmap_stops row) is simply always available, no campaign progress required.
class SkinsScreen extends StatefulWidget {
  const SkinsScreen({super.key});
  @override
  State<SkinsScreen> createState() => _SkinsScreenState();
}

class _VehicleSkin {
  final String id;
  final String? campaignId; // nullable now — a skin can genuinely stand alone, tied to no campaign at all
  final String name;
  final String icon;
  final int pointsCost;
  final bool visible;
  const _VehicleSkin({required this.id, required this.campaignId, required this.name, required this.icon, required this.pointsCost, required this.visible});
}

class _SkinsScreenState extends State<SkinsScreen> {
  List<_VehicleSkin> skins = [];
  Set<String> ownedIds = {};
  Map<String, int> gatingThreshold = {}; // skinId -> the deed threshold that unlocks it, if any
  Map<String, int> deedsDonePerCampaign = {}; // campaignId -> real approved deed count
  Map<String, int> discounts = {};
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
      final skinRows = await Supabase.instance.client.from('vehicle_skins').select();
      final ownedRows = uid == null ? [] : await Supabase.instance.client.from('user_vehicle_skins').select('skin_id').eq('user_id', uid);
      final discountRows = uid == null ? [] : await Supabase.instance.client.from('user_skin_discounts').select('skin_id, discount_percent').eq('user_id', uid);
      // Real gating source — which stop, if any, this skin is tied to.
      final stopRows = await Supabase.instance.client.from('roadmap_stops').select('skin_id, threshold, campaign_id').not('skin_id', 'is', null);

      final parsedSkins = skinRows.map<_VehicleSkin>((r) => _VehicleSkin(
            id: r['id'] as String,
            campaignId: r['campaign_id'] as String?,
            name: r['name'] as String,
            icon: r['icon'] as String,
            pointsCost: r['points_cost'] as int,
            visible: r['visible'] as bool? ?? true,
          )).toList();

      final gating = <String, int>{};
      for (final r in stopRows) {
        gating[r['skin_id'] as String] = r['threshold'] as int;
      }

      // Real, per-campaign approved deed counts — only fetched for campaigns that actually have
      // a gated skin, not every campaign in the system. A gated skin always genuinely has a real
      // campaign (it can only be gated via a roadmap stop, which itself always belongs to one),
      // but whereType<String>() narrows the now-nullable type safely regardless.
      final relevantCampaignIds = parsedSkins.where((s) => gating.containsKey(s.id)).map((s) => s.campaignId).whereType<String>().toSet();
      final deedCounts = <String, int>{};
      if (uid != null) {
        for (final campaignId in relevantCampaignIds) {
          final rows = await Supabase.instance.client.from('deeds').select('id').eq('user_id', uid).eq('status', 'approved').eq('campaign_id', campaignId);
          deedCounts[campaignId] = rows.length;
        }
      }

      setState(() {
        skins = parsedSkins;
        ownedIds = ownedRows.map<String>((r) => r['skin_id'] as String).toSet();
        discounts = {for (final r in discountRows) r['skin_id'] as String: r['discount_percent'] as int};
        gatingThreshold = gating;
        deedsDonePerCampaign = deedCounts;
        loading = false;
      });
    } catch (e) {
      setState(() { error = "Couldn't load skins. Check your connection and try again."; loading = false; });
    }
  }

  bool _isUnlocked(_VehicleSkin skin) {
    final threshold = gatingThreshold[skin.id];
    if (threshold == null) return true; // no gating stop — always available
    return (deedsDonePerCampaign[skin.campaignId] ?? 0) >= threshold;
  }

  Future<void> _purchase(_VehicleSkin skin) async {
    try {
      final result = await Supabase.instance.client.rpc('purchase_vehicle_skin', params: {'skin_id_input': skin.id});
      if (!mounted) return;
      if (result == 'success') {
        // New — real confetti + skin reveal, per direction, replacing a plain snackbar for
        // what's meant to be a genuine, celebratory moment.
        if (mounted) await showSkinRevealDialog(context, icon: skin.icon, name: skin.name);
        await context.read<AppState>().tryLoadExistingProfile();
        _load();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result as String? ?? 'Could not complete purchase.')));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Couldn't complete the purchase. Please try again.")));
    }
  }

  Future<void> _equip(_VehicleSkin skin) async {
    final error = await context.read<AppState>().equipSkin(skin.id, skin.icon);
    if (!mounted) return;
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${skin.name} equipped!')));
    }
  }

  // Real, confirmed final version — genuinely global unequip now.
  Future<void> _unequip(_VehicleSkin skin) async {
    final error = await context.read<AppState>().unequipSkin();
    if (!mounted) return;
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Unequipped — back to the default vehicle.')));
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
        title: Text('Skins', style: AppFonts.inter(size: 14, weight: FontWeight.w600)),
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
            child: Container(
              decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: wallpaperSwatches[state.wallpaperSwatchIndex])),
            ),
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
                            Text('🎨 Skins', style: AppFonts.fraunces(size: 22, weight: FontWeight.w600)),
                            const SizedBox(height: 4),
                            Text('${ownedIds.length} of ${skins.length} unlocked · You have ${state.user.points} pts', style: AppFonts.inter(size: 12, color: AppColors.textSoft)),
                            const SizedBox(height: 18),
                            if (skins.isEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 40),
                                child: Center(
                                  child: Column(children: [
                                    Opacity(opacity: 0.4, child: const Text('🎨', style: TextStyle(fontSize: 44))),
                                    const SizedBox(height: 14),
                                    Text('Nothing here yet', style: AppFonts.fraunces(size: 15, weight: FontWeight.w600)),
                                    const SizedBox(height: 6),
                                    Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 24),
                                      child: Text('Skins appear here once a campaign adds them to the catalog.', textAlign: TextAlign.center, style: AppFonts.inter(size: 12, color: AppColors.textSoft, height: 1.6)),
                                    ),
                                  ]),
                                ),
                              )
                            else
                              // Real fix here: the pause toggle on the admin side existed as a
                              // column, but nothing in the app actually checked it — a paused
                              // skin was still fully visible and purchasable to everyone. Now
                              // genuinely hidden from anyone who doesn't already own it, while
                              // staying fully visible and usable for anyone who does — matching
                              // how nothing else in this app strips access already granted.
                              ...skins.where((skin) => skin.visible || ownedIds.contains(skin.id)).map((skin) {
                                final owned = ownedIds.contains(skin.id);
                                final equipped = state.equippedSkinId == skin.id;
                                final unlocked = _isUnlocked(skin);
                                final threshold = gatingThreshold[skin.id];
                                final done = deedsDonePerCampaign[skin.campaignId] ?? 0;
                                final discountPct = discounts[skin.id];
                                final finalCost = discountPct != null ? (skin.pointsCost - (skin.pointsCost * discountPct / 100)).round() : skin.pointsCost;
                                final canAfford = state.user.points >= finalCost;

                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 10),
                                  child: Container(
                                    padding: const EdgeInsets.all(14),
                                    decoration: BoxDecoration(
                                      color: AppColors.oliveCard,
                                      borderRadius: BorderRadius.circular(14),
                                      border: Border.all(color: equipped ? AppColors.gold : (owned ? AppColors.gold.withOpacity(0.35) : Colors.transparent), width: equipped ? 2 : 1),
                                    ),
                                    child: Row(children: [
                                      Opacity(opacity: unlocked ? 1 : 0.4, child: CampaignIcon(icon: skin.icon, size: 32)),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                          Text(skin.name, style: AppFonts.inter(size: 13, weight: FontWeight.w700, color: unlocked ? AppColors.text : AppColors.textSoft)),
                                          const SizedBox(height: 2),
                                          if (!unlocked)
                                            Text('Reach $threshold deeds in this campaign to unlock ($done/$threshold)', style: AppFonts.inter(size: 10, color: AppColors.textSoft))
                                          else if (discountPct != null && !owned)
                                            Row(children: [
                                              Text('${skin.pointsCost} pts', style: AppFonts.inter(size: 10, color: AppColors.textSoft).copyWith(decoration: TextDecoration.lineThrough)),
                                              const SizedBox(width: 5),
                                              Text('$finalCost pts', style: AppFonts.inter(size: 10.5, weight: FontWeight.w700, color: AppColors.gold)),
                                            ])
                                          else
                                            Text(owned ? (equipped ? 'Equipped' : 'Owned') : '$finalCost pts', style: AppFonts.inter(size: 10.5, color: AppColors.textSoft)),
                                        ]),
                                      ),
                                      if (!unlocked)
                                        const Icon(Icons.lock_outline, size: 18, color: AppColors.textSoft)
                                      else if (owned)
                                        GestureDetector(
                                          // Real fix here: the previously-missing unequip action —
                                          // tapping an already-equipped skin now genuinely reverts
                                          // to the default vehicle, instead of the button just
                                          // becoming permanently disabled with no way back.
                                          onTap: equipped ? () => _unequip(skin) : () => _equip(skin),
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                                            decoration: BoxDecoration(color: equipped ? AppColors.gold.withOpacity(0.18) : AppColors.gold, borderRadius: BorderRadius.circular(100)),
                                            child: Text(equipped ? '✓ Unequip' : 'EQUIP', style: AppFonts.plexMono(size: 9.5, weight: FontWeight.w700, color: equipped ? AppColors.gold : AppColors.inkOnGold)),
                                          ),
                                        )
                                      else
                                        GestureDetector(
                                          onTap: canAfford ? () => _purchase(skin) : null,
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                            decoration: BoxDecoration(color: canAfford ? AppColors.gold : AppColors.bg1.withOpacity(0.4), borderRadius: BorderRadius.circular(100)),
                                            child: Text('Buy', style: AppFonts.inter(size: 11.5, weight: FontWeight.w700, color: canAfford ? AppColors.inkOnGold : AppColors.textSoft)),
                                          ),
                                        ),
                                    ]),
                                  ),
                                );
                              }),
                          ],
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}
