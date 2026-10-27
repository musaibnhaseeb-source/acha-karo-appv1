import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import '../data/journey_models.dart';
import '../data/journey_repository.dart';
import '../data/roadmap_data.dart';
import '../journey/guddi_clip_player.dart';
import '../journey/guddi_clips.dart';
import '../journey/scene_painters.dart';
import '../journey/side_scroller_logic.dart';

// Side-scrolling journey (design: journey_side_v2). Guddi walks in place on the left, the world scrolls
// past, and at a stop she jumps; a compact card at the top right shows the approaching stop (progress
// lives on the card, no fuel bar) and offers the prize at a reached stop. All data comes through a
// JourneyRepository (real or UAT). Scenery is placeholder art painted in code until the final tiles land.

const _gold = Color(0xFFD9A62E);
const _olive = Color(0xFF9FAE6E);
const _text = Color(0xFFF6F5EC);
const _textSoft = Color(0xFFC9CDBC);
const _bg1 = Color(0xFF081209);
const _bg2 = Color(0xFF0F2016);
const _cardBg = Color(0xF00F2016);

class JourneySideScreen extends StatefulWidget {
  final JourneyRepository repository;
  final String campaignId;
  final GuddiClipSet clips;
  // Changes when the user or campaign is switched in UAT: Guddi snaps to the new position, no walking.
  final Object? snapKey;
  final VoidCallback? onAchaKaam; // the bottom button (in UAT: +1 acha kaam)
  final VoidCallback? onSkin; // the skin button
  const JourneySideScreen({
    super.key,
    required this.repository,
    required this.campaignId,
    required this.clips,
    this.snapKey,
    this.onAchaKaam,
    this.onSkin,
  });
  @override
  State<JourneySideScreen> createState() => _JourneySideScreenState();
}

class _JourneySideScreenState extends State<JourneySideScreen> with SingleTickerProviderStateMixin {
  static const step = 520.0;
  JourneyConfig? config;
  JourneyProgress? progress;
  SideScrollerLogic? logic;
  String? error;
  bool clipsReady = false;
  bool _snapNext = true;
  final camera = ValueNotifier<double>(0);
  final shadowScale = ValueNotifier<double>(1);
  final giftPhase = ValueNotifier<double>(0); // 0..1, drives the floating gift above a reached stop
  SceneArt? art; // real scenery for the current theme (null = code-drawn placeholders)
  String? _artFolder;
  late final Ticker _ticker;
  Duration _last = Duration.zero;
  int? preview; // stop previewed from the strip
  bool cardOpen = false;
  bool _mounted = true;

  @override
  void initState() {
    super.initState();
    widget.repository.changes.addListener(_load);
    _ticker = createTicker(_tick)..start();
    _load();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!clipsReady) {
      precacheGuddiClips(context, widget.clips).then((_) {
        if (_mounted && mounted) setState(() => clipsReady = true);
      });
    }
  }

  @override
  void didUpdateWidget(JourneySideScreen old) {
    super.didUpdateWidget(old);
    if (old.campaignId != widget.campaignId || old.snapKey != widget.snapKey) {
      _snapNext = true;
      logic = null;
      preview = null;
      _load();
    }
  }

  @override
  void dispose() {
    _mounted = false;
    widget.repository.changes.removeListener(_load);
    _ticker.dispose();
    camera.dispose();
    shadowScale.dispose();
    giftPhase.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final c = await widget.repository.loadCampaign(widget.campaignId);
      final p = await widget.repository.loadProgress(widget.campaignId);
      if (!mounted) return;
      setState(() {
        config = c;
        progress = p;
        error = null;
        final l = logic ??= SideScrollerLogic(thresholds: [for (final s in c.stops) s.threshold], step: step);
        l.setProgress(p.deedsDone, snap: _snapNext);
        if (_snapNext) camera.value = l.worldX;
        _snapNext = false;
      });
      final folder = c.theme.artFolder;
      if (folder != _artFolder) {
        _artFolder = folder;
        final loaded = await SceneArt.load(folder);
        if (mounted && _artFolder == folder) setState(() => art = loaded);
      }
    } on JourneyException catch (e) {
      if (mounted) setState(() => error = e.message);
    }
  }

  void _tick(Duration elapsed) {
    final l = logic;
    if (l == null || !clipsReady) {
      _last = elapsed;
      return;
    }
    final dt = ((elapsed - _last).inMicroseconds / 1e6).clamp(0.0, 0.05);
    _last = elapsed;
    final before = l.state;
    if (l.update(dt)) camera.value = l.worldX;
    giftPhase.value = (elapsed.inMilliseconds % 2800) / 2800;
    // shadow shrinks at the top of the jump (clip is 2.7 s; the jump sits in roughly 15%..70%)
    if (l.state == GuddiState.celebrate) {
      final u = ((l.stateTime / 2.7 - 0.15) / 0.55).clamp(0.0, 1.0);
      shadowScale.value = 1 - 0.45 * (1 - (2 * u - 1).abs());
    } else if (shadowScale.value != 1) {
      shadowScale.value = 1;
    }
    if (l.state != before) setState(() {});
  }

  // ---- derived state ----
  int get _nextIdx {
    final c = config!, p = progress!;
    return c.stops.indexWhere((s) => p.deedsDone < s.threshold);
  }

  LandmarkState _stState(int i) {
    final c = config!, p = progress!;
    final s = c.stops[i];
    if (p.claims.containsKey(s.id)) return LandmarkState.claimed;
    if (p.deedsDone >= s.threshold) return LandmarkState.ready;
    if (i == _nextIdx) return LandmarkState.next;
    return LandmarkState.locked;
  }

  // Which stop the card shows: a strip preview, else the stop she stands on while holding, else the next stop.
  int? get _cardStop {
    final l = logic!;
    if (preview != null) return preview;
    if (l.state == GuddiState.celebrate) return null;
    if (l.state == GuddiState.hold || (l.state == GuddiState.idle && l.arrivedStop != null)) return l.arrivedStop;
    final n = _nextIdx;
    return n < 0 ? null : n;
  }

  Future<void> _claim(RoadmapStop stop) async {
    final index = await showModalBottomSheet<int>(
      context: context,
      isDismissible: false,
      isScrollControlled: true,
      backgroundColor: _bg2,
      builder: (ctx) => _BoxPicker(stop: stop),
    );
    if (index == null) return;
    try {
      final o = await widget.repository.claimStop(stop.id, index);
      await widget.repository.refreshAfterClaim();
      if (mounted) await _info(_title(o), _body(stop, o));
    } on JourneyException catch (e) {
      if (mounted) await _info('Could not claim', e.message);
    }
  }

  String _title(ClaimOutcome o) {
    switch (o.outcome) {
      case 'free_skin': return 'You won it — free!';
      case 'discount': return 'You earned a discount!';
      case 'prize': return 'You won!';
      default: return 'Not this time';
    }
  }

  String _body(RoadmapStop s, ClaimOutcome o) {
    switch (o.outcome) {
      case 'free_skin': return '${s.prize.name} is now yours, no points needed.';
      case 'discount': return '${o.discountPercent}% off ${s.prize.name} — it is waiting in Skins.';
      case 'prize': return o.prizePoints != null ? '+${o.prizePoints} points added to your total!' : s.prize.name;
      default: return 'Better luck at the next stop!';
    }
  }

  Future<void> _info(String t, String b) => showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: _bg2,
          title: Text(t, style: const TextStyle(color: _text)),
          content: Text(b, style: const TextStyle(color: _text)),
          actions: [TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('OK', style: TextStyle(color: _gold)))],
        ),
      );

  GuddiClip _clipFor(GuddiState s) {
    final c = widget.clips;
    switch (s) {
      case GuddiState.idle: return c.idle;
      case GuddiState.walkStart: return c.walkStart;
      case GuddiState.walking: return c.walkLoop;
      case GuddiState.walkStop: return c.walkStop;
      case GuddiState.celebrate:
      case GuddiState.hold: return c.celebrate;
      case GuddiState.returning: return c.returning;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (error != null) return Center(child: Text(error!, style: const TextStyle(color: _text)));
    final c = config, p = progress, l = logic;
    if (c == null || p == null || l == null || !clipsReady) {
      return const ColoredBox(color: _bg1, child: Center(child: CircularProgressIndicator()));
    }
    final t = c.theme;
    final total = c.stops.last.threshold;
    return LayoutBuilder(builder: (context, outer) {
      return ColoredBox(
        color: _bg1,
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 8, 18, 0),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text('${t.title} · ${p.deedsDone} / $total acha kaam', style: const TextStyle(color: _textSoft, fontSize: 11, fontFamily: 'monospace', fontWeight: FontWeight.w500)),
            ),
          ),
          _Strip(
            key: const ValueKey('strip'),
            config: c,
            progress: p,
            nextIdx: _nextIdx,
            preview: preview,
            stateOf: _stState,
            guddiFace: widget.clips.framePath(widget.clips.idle, 0),
            onTapStop: (i) => setState(() {
              preview = preview == i ? null : i;
              cardOpen = false;
            }),
          ),
          Expanded(child: _scene(c, p, l, outer.maxHeight)),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 10, 18, 14),
            child: Row(children: [
              Expanded(
                child: FilledButton(
                  key: const ValueKey('cta'),
                  style: FilledButton.styleFrom(backgroundColor: _gold, foregroundColor: const Color(0xFF1B1706), padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13))),
                  onPressed: widget.onAchaKaam,
                  child: const Text('📋 Acha kaam karein', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
                ),
              ),
              const SizedBox(width: 10),
              InkWell(
                key: const ValueKey('skin-btn'),
                onTap: widget.onSkin,
                borderRadius: BorderRadius.circular(13),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
                  decoration: BoxDecoration(color: const Color(0x428C9A5C), borderRadius: BorderRadius.circular(13), border: Border.all(color: _gold.withValues(alpha: 0.4))),
                  child: const Text('🎨', style: TextStyle(fontSize: 18)),
                ),
              ),
            ]),
          ),
        ]),
      );
    });
  }

  Widget _scene(JourneyConfig c, JourneyProgress p, SideScrollerLogic l, double screenH) {
    final t = c.theme;
    return LayoutBuilder(builder: (context, box) {
      final w = box.maxWidth, h = box.maxHeight;
      final gh = (screenH * 0.42).clamp(120.0, h - 70);
      final gw = gh * 0.28;
      final gx = (w * 0.18).clamp(gw / 2 + 24, double.infinity);
      final feet = h - (kGroundH - kFeetBelowGroundTop);
      final lmx = gx + (w - gx) * 0.58;
      final cardW = (w - (gx + gw / 2 + 26) - 12).clamp(170.0, 260.0);
      // clip stage scale: Guddi (head to feet) is ~532 stage px tall and fills ~91% of the slot height
      final k = gh * 0.91 / 532.5;
      final stageLeft = gx - GuddiClips.centreX * GuddiClips.scale * k;
      final stageTop = feet - GuddiClips.groundY * GuddiClips.scale * k;
      final states = [for (var i = 0; i < c.stops.length; i++) _stState(i)];
      final nextIdx = _nextIdx;
      final complete = nextIdx < 0;
      final arrived = (l.state == GuddiState.hold && l.arrivedStop != null) ? c.copy[c.stops[l.arrivedStop!].id]?.arrive : null;
      final bubble = arrived ??
          ((l.state == GuddiState.idle && preview == null)
              ? (complete && states.last == LandmarkState.claimed ? 'Journey complete! 💪' : 'Bas ${complete ? 0 : c.stops[nextIdx].threshold - p.deedsDone} aur!')
              : null);
      final cs = _cardStop;
      return ClipRect(
        child: Stack(children: [
          Positioned.fill(child: CustomPaint(painter: SceneLayersPainter(cameraX: camera, theme: t, art: art))),
          Positioned.fill(
            child: CustomPaint(
              painter: LandmarksPainter(
                cameraX: camera,
                theme: t,
                thresholds: [for (final s in c.stops) s.threshold],
                states: states,
                step: step,
                landmarkX: lmx,
                feetY: feet,
                art: art,
                bob: giftPhase,
              ),
            ),
          ),
          // soft ellipse shadow under the feet, drawn here (the clips carry none); shrinks at the top of the jump
          Positioned(
            left: gx - gw * 0.75,
            top: feet - 6,
            width: gw * 1.5,
            height: 12,
            child: IgnorePointer(
              child: ValueListenableBuilder<double>(
                valueListenable: shadowScale,
                builder: (context, s, _) => Transform.scale(
                  scale: s,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(100),
                      gradient: RadialGradient(colors: [Colors.black.withValues(alpha: 0.5 * s), Colors.black.withValues(alpha: 0)]),
                    ),
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            left: stageLeft,
            top: stageTop,
            child: IgnorePointer(
              child: Transform.scale(
                scale: k,
                alignment: Alignment.topLeft,
                child: GuddiStage(
                  key: ValueKey(l.state),
                  set: widget.clips,
                  clip: _clipFor(l.state),
                  holdLast: l.state == GuddiState.hold,
                  onFinished: () {
                    l.clipFinished();
                    setState(() {});
                  },
                ),
              ),
            ),
          ),
          if (bubble != null)
            Positioned(
              left: (gx - gw / 2).clamp(8.0, double.infinity),
              top: feet - gh - 30,
              child: IgnorePointer(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                  decoration: BoxDecoration(color: const Color(0xEB0F2016), borderRadius: BorderRadius.circular(10), border: Border.all(color: _gold.withValues(alpha: 0.5))),
                  child: Text(bubble, style: const TextStyle(color: _text, fontSize: 11, fontWeight: FontWeight.w700)),
                ),
              ),
            ),
          Positioned(
            top: 8,
            right: 10,
            width: cardW.toDouble(),
            child: AnimatedSlide(
              offset: cs == null ? const Offset(0.12, 0) : Offset.zero,
              duration: const Duration(milliseconds: 300),
              child: AnimatedOpacity(
                opacity: cs == null ? 0 : 1,
                duration: const Duration(milliseconds: 250),
                child: cs == null ? const SizedBox(height: 1) : _card(c, p, cs, states[cs]),
              ),
            ),
          ),
        ]),
      );
    });
  }

  Widget _card(JourneyConfig c, JourneyProgress p, int i, LandmarkState st) {
    final s = c.stops[i];
    final t = c.theme;
    final Widget icon = st == LandmarkState.locked ? const Icon(Icons.lock, size: 15, color: _textSoft) : Text(t.stopIcons[i % t.stopIcons.length], style: const TextStyle(fontSize: 16));
    final label = const {LandmarkState.locked: 'Locked', LandmarkState.next: 'Next stop', LandmarkState.ready: 'Reached', LandmarkState.claimed: 'Claimed'}[st]!;
    final pillColor = st == LandmarkState.ready ? _gold : (st == LandmarkState.claimed ? _olive : (st == LandmarkState.next ? _gold : _textSoft));
    final Widget pz = st == LandmarkState.locked ? const Icon(Icons.lock_outline, size: 16, color: _textSoft) : Text(s.prize.icon, style: const TextStyle(fontSize: 17));
    final pct = (p.deedsDone / s.threshold).clamp(0.0, 1.0);
    Widget r2;
    if (st == LandmarkState.ready) {
      r2 = Row(children: [
        Expanded(
          child: FilledButton(
            key: const ValueKey('claim-btn'),
            style: FilledButton.styleFrom(backgroundColor: _gold, foregroundColor: const Color(0xFF1B1706), padding: const EdgeInsets.symmetric(vertical: 7), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            onPressed: () => _claim(s),
            child: const Text('Open prize 🎁', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
          ),
        ),
        const SizedBox(width: 8),
        pz,
      ]);
    } else if (st == LandmarkState.claimed) {
      final won = p.claims[s.id]?.won ?? false;
      r2 = Row(children: [
        Expanded(child: Text(won ? '✓ ${s.prize.name}' : '✓ Opened', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _olive, fontSize: 10.5, fontWeight: FontWeight.w600, fontFamily: 'monospace'))),
        pz,
      ]);
    } else {
      r2 = Row(children: [
        Container(
          width: 44,
          height: 6,
          decoration: BoxDecoration(color: const Color(0x99081209), borderRadius: BorderRadius.circular(100)),
          alignment: Alignment.centerLeft,
          child: FractionallySizedBox(widthFactor: st == LandmarkState.locked ? 0 : pct, child: Container(decoration: BoxDecoration(color: _gold, borderRadius: BorderRadius.circular(100)))),
        ),
        const SizedBox(width: 8),
        Expanded(child: Text('${p.deedsDone.clamp(0, s.threshold)} of ${s.threshold} acha kaam', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _textSoft, fontSize: 10.5, fontWeight: FontWeight.w600, fontFamily: 'monospace'))),
        pz,
      ]);
    }
    final left = s.threshold - p.deedsDone;
    return Container(
      key: const ValueKey('stop-card'),
      padding: const EdgeInsets.fromLTRB(11, 9, 11, 10),
      decoration: BoxDecoration(color: _cardBg, borderRadius: BorderRadius.circular(14), border: Border.all(color: _gold.withValues(alpha: 0.4)), boxShadow: const [BoxShadow(color: Color(0x59000000), blurRadius: 16, offset: Offset(0, 6))]),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => setState(() => cardOpen = !cardOpen),
          child: Row(children: [
            icon,
            const SizedBox(width: 7),
            Expanded(child: Text(s.label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _text, fontSize: 14, fontWeight: FontWeight.w600))),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(100), border: Border.all(color: pillColor.withValues(alpha: 0.6)), color: st == LandmarkState.ready ? _gold : null),
              child: Text(label.toUpperCase(), style: TextStyle(color: st == LandmarkState.ready ? const Color(0xFF1B1706) : pillColor, fontSize: 8.5, fontWeight: FontWeight.w600, fontFamily: 'monospace', letterSpacing: 0.5)),
            ),
            Text(cardOpen ? ' ▴' : ' ▾', style: const TextStyle(color: _textSoft, fontSize: 11)),
          ]),
        ),
        const SizedBox(height: 7),
        r2,
        if (cardOpen) ...[
          const SizedBox(height: 8),
          const Divider(height: 1, color: Color(0x29F6F5EC)),
          const SizedBox(height: 8),
          if (c.copy[s.id] != null) ...[
            Text(c.copy[s.id]!.message, style: const TextStyle(color: _textSoft, fontSize: 11.5, height: 1.35)),
            const SizedBox(height: 6),
          ],
          Text(
            'Prize: ${st == LandmarkState.locked ? 'hidden until you reach this stop' : s.prize.name}${st == LandmarkState.locked || st == LandmarkState.next ? ' · $left more acha kaam' : ''}',
            style: const TextStyle(color: _textSoft, fontSize: 10, fontWeight: FontWeight.w600, fontFamily: 'monospace'),
          ),
          Text('${s.winningBoxes} of ${s.totalBoxes} boxes win · ${s.rewardMode == 'guaranteed_with_discount' ? 'always a reward' : 'standard'}', style: const TextStyle(color: _textSoft, fontSize: 10, fontFamily: 'monospace')),
        ],
      ]),
    );
  }
}

// Journey strip: a node per stop with connectors that fill as deeds are done, plus Guddi's marker.
class _Strip extends StatelessWidget {
  final JourneyConfig config;
  final JourneyProgress progress;
  final int nextIdx;
  final int? preview;
  final LandmarkState Function(int) stateOf;
  final String guddiFace;
  final void Function(int) onTapStop;
  const _Strip({super.key, required this.config, required this.progress, required this.nextIdx, required this.preview, required this.stateOf, required this.guddiFace, required this.onTapStop});

  @override
  Widget build(BuildContext context) {
    final stops = config.stops;
    final done = progress.deedsDone;
    final n = stops.length;
    // marker position as a share of the strip, like the design
    var k = 0.0;
    for (var i = 0; i < n; i++) {
      final a = i == 0 ? 0 : stops[i - 1].threshold;
      if (done > a) k = i + ((done - a) / (stops[i].threshold - a)).clamp(0.0, 1.0);
    }
    final children = <Widget>[
      _node(context, label: '0', start: true),
    ];
    var prev = 0;
    for (var i = 0; i < n; i++) {
      final a = prev, b = stops[i].threshold;
      final f = ((done - a) / (b - a)).clamp(0.0, 1.0);
      children.add(Expanded(
        child: Container(
          height: 3,
          margin: const EdgeInsets.only(top: 12),
          decoration: BoxDecoration(color: const Color(0x38C9CDBC), borderRadius: BorderRadius.circular(3)),
          alignment: Alignment.centerLeft,
          child: FractionallySizedBox(widthFactor: f, child: Container(decoration: BoxDecoration(color: _gold, borderRadius: BorderRadius.circular(3)))),
        ),
      ));
      children.add(_node(context, label: '${stops[i].threshold}', index: i));
      prev = b;
    }
    return SizedBox(
      height: 56,
      child: LayoutBuilder(builder: (context, box) {
        final inner = box.maxWidth - 28 - 34;
        return Stack(children: [
          Padding(padding: const EdgeInsets.fromLTRB(14, 10, 14, 0), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: children)),
          AnimatedPositioned(
            duration: const Duration(milliseconds: 500),
            left: 14 + 17 - 11 + inner * (k / n),
            top: 2,
            child: IgnorePointer(
              child: Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: _gold, width: 1.5), color: _bg2),
                clipBehavior: Clip.antiAlias,
                child: FittedBox(fit: BoxFit.cover, alignment: const Alignment(0, -0.85), child: SizedBox(width: 174, height: 550, child: Image.asset(guddiFace, fit: BoxFit.fill))),
              ),
            ),
          ),
        ]);
      }),
    );
  }

  Widget _node(BuildContext context, {required String label, bool start = false, int? index}) {
    if (start) {
      return SizedBox(
        width: 34,
        child: Column(children: [
          Container(width: 14, height: 14, margin: const EdgeInsets.symmetric(vertical: 6), decoration: BoxDecoration(shape: BoxShape.circle, color: _olive, border: Border.all(color: _olive, width: 2))),
          const SizedBox(height: 3),
          Text(label, style: const TextStyle(color: _textSoft, fontSize: 9.5, fontWeight: FontWeight.w600, fontFamily: 'monospace')),
        ]),
      );
    }
    final st = stateOf(index!);
    final theme = config.theme;
    final ic = st == LandmarkState.claimed ? '✓' : st == LandmarkState.ready ? '🎁' : st == LandmarkState.next ? theme.stopIcons[index % theme.stopIcons.length] : '🔒';
    final fill = (st == LandmarkState.ready) ? _gold : (st == LandmarkState.claimed ? _olive : _bg2);
    final border = (st == LandmarkState.next || st == LandmarkState.ready || st == LandmarkState.claimed) ? _gold : const Color(0x66C9CDBC);
    return GestureDetector(
      key: ValueKey('node-$index'),
      onTap: () => onTapStop(index),
      child: SizedBox(
        width: 34,
        child: Column(children: [
          Container(
            width: 26,
            height: 26,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: fill,
              border: Border.all(color: border, width: 2),
              boxShadow: [
                if (st == LandmarkState.ready) const BoxShadow(color: Color(0x8CD9A62E), blurRadius: 12),
                if (preview == index) const BoxShadow(color: Color(0x73D9A62E), spreadRadius: 3),
              ],
            ),
            child: st == LandmarkState.locked
                ? const Icon(Icons.lock, size: 12, color: _textSoft)
                : Text(ic, style: TextStyle(fontSize: 12, color: (st == LandmarkState.claimed || st == LandmarkState.ready) ? const Color(0xFF1B1706) : _text, fontWeight: FontWeight.w700)),
          ),
          const SizedBox(height: 3),
          Text(label, style: TextStyle(color: st == LandmarkState.next ? _gold : _textSoft, fontSize: 9.5, fontWeight: FontWeight.w600, fontFamily: 'monospace')),
        ]),
      ),
    );
  }
}

class _BoxPicker extends StatelessWidget {
  final RoadmapStop stop;
  const _BoxPicker({required this.stop});
  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('${stop.label} — pick a box', style: const TextStyle(color: _text, fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          Text('${stop.winningBoxes} of ${stop.totalBoxes} win — pick one, no take-backs.', style: const TextStyle(color: _textSoft, fontSize: 11.5)),
          const SizedBox(height: 14),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 3,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1 / 1.39,
            children: [
              for (var i = 0; i < stop.totalBoxes; i++)
                InkWell(
                  key: ValueKey('box-$i'),
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => Navigator.of(context).pop(i),
                  child: Container(
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0x599FAE6E), _bg1]),
                      border: Border.all(color: _gold.withValues(alpha: 0.25), width: 1.5),
                    ),
                    child: Text('?', style: TextStyle(color: _gold.withValues(alpha: 0.85), fontSize: 30, fontWeight: FontWeight.w700)),
                  ),
                ),
            ],
          ),
        ]),
      ),
    );
  }
}
