import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../data/journey_models.dart';

// Placeholder scenery painted in code, ported from the design mockup (journey_side_v2.html): sky with a
// dot tile, far / mid / ground layers that tile sideways at their own scroll rates, and a landmark per
// stop. The final art arrives as tiles later; the layer structure and rates stay:
// sky 0.04x, far 0.12x, mid 0.35x, ground and landmarks 1.0x.

const double kGroundH = 52; // ground tile height (dp)
const double kFeetBelowGroundTop = 14; // feet stand 14 dp below the ground tile's top edge

void _tile(Canvas canvas, double tileW, double offset, double width, double top, void Function(Canvas) draw) {
  final start = -(offset % tileW);
  for (var x = start; x < width; x += tileW) {
    canvas.save();
    canvas.translate(x, top);
    draw(canvas);
    canvas.restore();
  }
}

Paint _p(Color c) => Paint()..color = c;

// Real scenery art (journey_side_v2 export): one folder per theme under assets/images/journey/.
// Sizes are px at 2x (1 dp = 2 px). Missing art falls back to the code-drawn placeholders below.
class SceneArt {
  final ui.Image sky, stars, far, mid, ground;
  final List<List<ui.Image>> landmarks; // [stop 0..5][locked, normal, prize]
  final ui.Image gift;
  const SceneArt({required this.sky, required this.stars, required this.far, required this.mid, required this.ground, required this.landmarks, required this.gift});

  static const _lm = {
    'general': ['01_sprout', '02_tree', '03_stall', '04_lamp', '05_flagpost', '06_arch'],
    'road': ['01_house', '02_zebra', '03_light', '04_stop', '05_lookboth', '06_gate'],
  };

  static Future<ui.Image> _img(String path) async {
    final data = await rootBundle.load(path);
    final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
    return (await codec.getNextFrame()).image;
  }

  static Future<SceneArt?> load(String? folder, {String root = 'assets/images/journey'}) async {
    if (folder == null || !_lm.containsKey(folder)) return null;
    try {
      final b = '$root/$folder';
      final lms = <List<ui.Image>>[];
      for (final n in _lm[folder]!) {
        lms.add([await _img('$b/lm_${n}_locked.webp'), await _img('$b/lm_${n}_normal.webp'), await _img('$b/lm_${n}_prize.webp')]);
      }
      return SceneArt(
        sky: await _img('$b/sky_gradient.webp'),
        stars: await _img('$b/sky_stars.webp'),
        far: await _img('$b/far.webp'),
        mid: await _img('$b/mid.webp'),
        ground: await _img('$b/ground.webp'),
        landmarks: lms,
        gift: await _img('$root/fx_gift.webp'),
      );
    } catch (_) {
      return null; // fall back to the code-drawn placeholders
    }
  }
}

void _img2(Canvas c, ui.Image im, Rect dst) =>
    c.drawImageRect(im, Rect.fromLTWH(0, 0, im.width.toDouble(), im.height.toDouble()), dst, Paint()..filterQuality = FilterQuality.medium);

class SceneLayersPainter extends CustomPainter {
  final ValueNotifier<double> cameraX;
  final JourneyTheme theme;
  final SceneArt? art;
  SceneLayersPainter({required this.cameraX, required this.theme, this.art}) : super(repaint: cameraX);

  @override
  void paint(Canvas canvas, Size size) {
    final cam = cameraX.value;
    final w = size.width, h = size.height;
    final a = art;
    if (a != null) {
      // sky gradient: fit to width, align bottom, crop the top; static
      final sh = w * a.sky.height / a.sky.width;
      canvas.drawRect(Offset.zero & size, _p(theme.skyTop));
      _img2(canvas, a.sky, Rect.fromLTWH(0, h - sh, w, sh));
      _tile(canvas, 400, cam * 0.04, w, 0, (c) => _img2(c, a.stars, const Rect.fromLTWH(0, 0, 400, 200)));
      _tile(canvas, 400, cam * 0.12, w, h - kGroundH - 8 - 170, (c) => _img2(c, a.far, const Rect.fromLTWH(0, 0, 400, 170)));
      _tile(canvas, 360, cam * 0.35, w, h - kGroundH + 4 - 130, (c) => _img2(c, a.mid, const Rect.fromLTWH(0, 0, 360, 130)));
      _tile(canvas, 120, cam, w, h - kGroundH, (c) => _img2(c, a.ground, const Rect.fromLTWH(0, 0, 120, 52)));
      return;
    }
    // sky: vertical gradient + soft glow near the right horizon + dots tile at 0.04x
    canvas.drawRect(
      Offset.zero & size,
      Paint()..shader = ui.Gradient.linear(Offset.zero, Offset(0, h), [theme.skyTop, theme.skyHorizon]),
    );
    final glowCenter = Offset(w * 0.72, h);
    canvas.drawRect(
      Offset.zero & size,
      Paint()..shader = ui.Gradient.radial(glowCenter, w * 0.8, [theme.glow, theme.glow.withValues(alpha: 0)], [0, 0.7]),
    );
    _tile(canvas, 400, cam * 0.04, w, 0, (c) {
      for (var i = 0; i < 22; i++) {
        final x = (i * 61 + 13) % 400, y = (i * 37 + 29) % 200;
        c.drawCircle(Offset(x.toDouble(), y.toDouble()), i % 4 == 0 ? 1.8 : 1, _p(theme.skyDots.withValues(alpha: i % 3 == 0 ? 0.9 : 0.5)));
      }
    });
    // far (0.12x), bottom edge 8 above the ground tile
    _tile(canvas, 400, cam * 0.12, w, h - kGroundH - 8 - 170, (c) {
      if (theme.farStyle == 'skyline') {
        _skyline(c, 400, 170, theme.farA, theme.farB);
      } else {
        _hills(c, 400, 170, theme.farA, 70, 22, 10, 0.6);
        _hills(c, 400, 170, theme.farB, 34, 14, 8, 2.1);
      }
    });
    // mid (0.35x), stands on the ground
    _tile(canvas, 360, cam * 0.35, w, h - kGroundH + 4 - 130, (c) {
      if (theme.midStyle == 'lamps') {
        _lamps(c, 360, 130, theme.midColor);
      } else {
        _trees(c, 360, 130, theme.midColor);
      }
    });
    // ground / road (1.0x)
    _tile(canvas, 120, cam, w, h - kGroundH, (c) {
      c.drawRect(const Rect.fromLTWH(0, 0, 120, kGroundH), _p(theme.groundRoad));
      c.drawRect(const Rect.fromLTWH(0, 0, 120, 8), _p(theme.groundKerb));
      c.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(14, kGroundH - 14, 40, 4), const Radius.circular(2)), _p(theme.groundDash));
      c.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(74, kGroundH - 14, 28, 4), const Radius.circular(2)), _p(theme.groundDash));
    });
  }

  void _hills(Canvas c, double w, double h, Color color, double base, double a1, double a2, double ph) {
    final p = Path()..moveTo(0, h);
    for (var x = 0.0; x <= w; x += 8) {
      final y = h - base - a1 * math.sin(2 * math.pi * x / w + ph) - a2 * math.sin(4 * math.pi * x / w + ph * 2);
      p.lineTo(x, y);
    }
    p..lineTo(w, h)..close();
    c.drawPath(p, _p(color));
  }

  void _skyline(Canvas c, double w, double h, Color color, Color lit) {
    const ws = [46, 30, 52, 38, 44, 30, 56, 40, 34, 30];
    const hs = [100, 70, 140, 90, 120, 80, 150, 95, 110, 75];
    var x = 0.0;
    for (var i = 0; i < ws.length; i++) {
      final bw = ws[i].toDouble(), bh = hs[i].toDouble();
      c.drawRect(Rect.fromLTWH(x, h - bh, bw, bh), _p(color));
      for (var yy = h - bh + 10; yy < h - 12; yy += 16) {
        for (var xx = x + 7; xx < x + bw - 9; xx += 12) {
          if (((xx + yy + i).round()) % 3 == 0) c.drawRect(Rect.fromLTWH(xx, yy, 5, 7), _p(lit.withValues(alpha: 0.55)));
        }
      }
      x += bw;
    }
  }

  void _trees(Canvas c, double w, double h, Color color) {
    for (final t in const [[36.0, 24.0, 52.0], [110.0, 30.0, 64.0], [176.0, 22.0, 46.0], [244.0, 28.0, 58.0], [318.0, 24.0, 50.0]]) {
      final x = t[0], r = t[1], th = t[2];
      c.drawRect(Rect.fromLTWH(x - 3, h - th / 2, 6, th / 2), _p(color));
      c.drawCircle(Offset(x, h - th / 2 - r * .55), r, _p(color));
      c.drawCircle(Offset(x - r * .6, h - th / 2), r * .62, _p(color));
      c.drawCircle(Offset(x + r * .6, h - th / 2), r * .62, _p(color));
    }
  }

  void _lamps(Canvas c, double w, double h, Color post) {
    const glow = Color(0xFFF2D58A);
    c.drawRect(Rect.fromLTWH(0, h - 26, w, 26), _p(const Color(0xFF1F3F4B)));
    for (final x in const [70.0, 250.0]) {
      c.drawCircle(Offset(x, h - 96), 26, _p(glow.withValues(alpha: 0.18)));
      c.drawRect(Rect.fromLTWH(x - 2, h - 92, 4, 70), _p(post));
      c.drawCircle(Offset(x, h - 96), 6, _p(glow));
    }
    for (final b in const [[150.0, 16.0], [330.0, 12.0]]) {
      c.drawCircle(Offset(b[0], h - 30), b[1], _p(post.withValues(alpha: 0.85)));
    }
  }

  @override
  bool shouldRepaint(SceneLayersPainter old) => old.theme != theme || old.art != art;
}

enum LandmarkState { locked, next, ready, claimed }

// Landmarks, one per stop, at their world positions. World x of stop i is (i+1)*step; the landmark's
// screen x is landmarkX + (stopWorldX - camera).
class LandmarksPainter extends CustomPainter {
  final ValueNotifier<double> cameraX;
  final JourneyTheme theme;
  final List<int> thresholds;
  final List<LandmarkState> states;
  final double step;
  final double landmarkX; // screen x where a stop sits when Guddi stands on it
  final double feetY;
  final SceneArt? art;
  final ValueNotifier<double>? bob; // 0..1 phase for the floating gift
  LandmarksPainter({
    required this.cameraX,
    required this.theme,
    required this.thresholds,
    required this.states,
    required this.step,
    required this.landmarkX,
    required this.feetY,
    this.art,
    this.bob,
  }) : super(repaint: bob == null ? cameraX : Listenable.merge([cameraX, bob]));

  @override
  void paint(Canvas canvas, Size size) {
    const scale = 1.25; // 120x160 art -> 150x200 dp
    for (var i = 0; i < thresholds.length; i++) {
      final x = landmarkX + ((i + 1) * step - cameraX.value);
      if (x < -110 || x > size.width + 110) continue;
      final st = states[i];
      final a = art;
      if (a != null && i < a.landmarks.length) {
        final imgs = a.landmarks[i];
        final im = st == LandmarkState.locked ? imgs[0] : (st == LandmarkState.ready ? imgs[2] : imgs[1]);
        // 200 x 250 dp canvas, image top at feet - 216, centred on x
        _img2(canvas, im, Rect.fromLTWH(x - 100, feetY - 216, 200, 250));
        final tagBg2 = st == LandmarkState.ready ? theme.accentColor : (st == LandmarkState.claimed ? const Color(0xFF9FAE6E) : const Color(0xEB0F2016));
        final tagFg2 = (st == LandmarkState.ready || st == LandmarkState.claimed) ? const Color(0xFF1B1706) : (st == LandmarkState.next ? theme.accentColor : const Color(0xFFC9CDBC));
        canvas.save();
        canvas.translate(x - 75, feetY - 196);
        _tag(canvas, st == LandmarkState.claimed ? '✓ ${thresholds[i]}' : '${thresholds[i]}', const Offset(75, -6), tagBg2, tagFg2, st == LandmarkState.next ? theme.accentColor : const Color(0x66C9CDBC));
        canvas.restore();
        if (st == LandmarkState.ready) {
          final b = bob == null ? 0.0 : (bob!.value < 0.5 ? bob!.value * 2 : 2 - bob!.value * 2);
          _img2(canvas, a.gift, Rect.fromLTWH(x - 24, feetY - 236 - 8 * b, 48, 48));
        }
        continue;
      }
      final kind = theme.landmarks[i % theme.landmarks.length];
      canvas.save();
      canvas.translate(x - 75, feetY - 196);
      if (st == LandmarkState.locked) {
        // grayscale + dimmed, like the design's .locked
        const g = 0.55;
        canvas.saveLayer(
          const Rect.fromLTWH(-20, -60, 200, 280),
          Paint()
            ..colorFilter = const ColorFilter.matrix(<double>[
              0.33 * g, 0.33 * g, 0.33 * g, 0, 0,
              0.33 * g, 0.33 * g, 0.33 * g, 0, 0,
              0.33 * g, 0.33 * g, 0.33 * g, 0, 0,
              0, 0, 0, 1, 0,
            ]),
        );
      } else if (st == LandmarkState.ready) {
        canvas.saveLayer(const Rect.fromLTWH(-20, -60, 200, 280), Paint());
        canvas.drawCircle(const Offset(75, 110), 78, _p(theme.accentColor.withValues(alpha: 0.12)));
      }
      canvas.save();
      canvas.scale(scale);
      canvas.drawOval(const Rect.fromLTWH(18, 152, 84, 10), _p(Colors.black.withValues(alpha: 0.35)));
      _landmark(canvas, kind);
      canvas.restore();
      if (st == LandmarkState.locked || st == LandmarkState.ready) canvas.restore();
      // tag
      final tagBg = st == LandmarkState.ready ? theme.accentColor : (st == LandmarkState.claimed ? const Color(0xFF9FAE6E) : const Color(0xEB0F2016));
      final tagFg = (st == LandmarkState.ready || st == LandmarkState.claimed) ? const Color(0xFF1B1706) : (st == LandmarkState.next ? theme.accentColor : const Color(0xFFC9CDBC));
      _tag(canvas, '${thresholds[i]}', const Offset(75, -6), tagBg, tagFg, st == LandmarkState.next ? theme.accentColor : const Color(0x66C9CDBC));
      if (st == LandmarkState.ready) _emoji(canvas, '🎁', const Offset(75, -40), 26);
      canvas.restore();
    }
  }

  void _tag(Canvas canvas, String text, Offset center, Color bg, Color fg, Color border) {
    final tp = TextPainter(text: TextSpan(text: text, style: TextStyle(color: fg, fontSize: 10, fontWeight: FontWeight.w600, fontFamily: 'monospace')), textDirection: TextDirection.ltr)..layout();
    final r = RRect.fromRectAndRadius(Rect.fromCenter(center: center, width: tp.width + 18, height: tp.height + 4), const Radius.circular(100));
    canvas.drawRRect(r, _p(bg));
    canvas.drawRRect(r, Paint()..style = PaintingStyle.stroke..strokeWidth = 1..color = border);
    tp.paint(canvas, Offset(center.dx - tp.width / 2, center.dy - tp.height / 2));
  }

  void _emoji(Canvas canvas, String e, Offset center, double size) {
    final tp = TextPainter(text: TextSpan(text: e, style: TextStyle(fontSize: size)), textDirection: TextDirection.ltr)..layout();
    tp.paint(canvas, Offset(center.dx - tp.width / 2, center.dy - tp.height / 2));
  }

  // Landmarks in the design's 120 x 160 box, base on the bottom edge.
  void _landmark(Canvas c, String kind) {
    Paint f(int rgb, [double a = 1]) => _p(Color(0xFF000000 | rgb).withValues(alpha: a));
    void r(double x, double y, double w, double h, int rgb, [double rad = 0]) =>
        c.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(x, y, w, h), Radius.circular(rad)), f(rgb));
    void o(double cx, double cy, double rad, int rgb, [double a = 1]) => c.drawCircle(Offset(cx, cy), rad, f(rgb, a));
    Path poly(List<double> pts) {
      final p = Path()..moveTo(pts[0], pts[1]);
      for (var i = 2; i < pts.length; i += 2) {
        p.lineTo(pts[i], pts[i + 1]);
      }
      return p..close();
    }

    switch (kind) {
      case 'sprout':
        c.drawLine(const Offset(60, 158), const Offset(60, 100), Paint()..color = const Color(0xFF6B8F3A)..strokeWidth = 7..strokeCap = StrokeCap.round);
        c.drawPath(poly([60, 112, 30, 112, 26, 82, 30, 70, 56, 70, 60, 90]), f(0x9FAE6E));
        c.drawPath(poly([60, 100, 90, 100, 96, 66, 90, 54, 62, 56, 60, 78]), f(0x7D9A4A));
        break;
      case 'tree':
        r(54, 90, 12, 68, 0x5A3D24, 3);
        o(60, 66, 34, 0x2F6B3F);
        o(36, 86, 22, 0x3B7D4C);
        o(84, 86, 22, 0x2A5E38);
        break;
      case 'stall':
        r(14, 112, 92, 46, 0x5A3D24);
        r(12, 62, 4, 96, 0xCFD3C4);
        r(104, 62, 4, 96, 0xCFD3C4);
        for (var k = 0; k < 6; k++) {
          r(8.0 + k * 17, 60, 17, 32, k.isOdd ? 0xF6F5EC : 0xC1573D);
        }
        r(26, 98, 68, 14, 0xD9A62E, 3);
        break;
      case 'lamp':
        o(60, 34, 30, 0xD9A62E, 0.22);
        r(56, 40, 8, 118, 0x2A2F2A, 3);
        c.drawPath(Path()..moveTo(42, 40)..quadraticBezierTo(60, 14, 78, 40)..close(), f(0x2A2F2A));
        o(60, 40, 9, 0xF2D58A);
        break;
      case 'flagpost':
        r(40, 20, 6, 138, 0xCFD3C4, 3);
        c.drawPath(poly([46, 24, 102, 24, 90, 41, 102, 58, 46, 58]), f(0xD9A62E));
        break;
      case 'arch':
        r(12, 52, 16, 106, 0x3C4A2C);
        r(92, 52, 16, 106, 0x3C4A2C);
        r(6, 36, 108, 22, 0xD9A62E, 8);
        c.drawPath(poly([60, 36, 60, 12, 82, 20, 60, 28]), f(0xC1573D));
        break;
      case 'house':
        r(20, 84, 80, 74, 0xE8A78A);
        c.drawPath(poly([10, 88, 60, 46, 110, 88]), f(0xC1573D));
        r(52, 114, 18, 44, 0x5A3D24, 2);
        r(28, 100, 16, 16, 0xF2D58A);
        r(78, 100, 16, 16, 0xF2D58A);
        break;
      case 'zebra':
        for (var k = 0; k < 6; k++) {
          final x = 6.0 + k * 19;
          c.drawPath(poly([x, 158, x + 13, 158, x + 9, 134, x - 4, 134]), f(0xF6F5EC, 0.88));
        }
        for (final x in const [18.0, 102.0]) {
          r(x - 3, 76, 6, 82, 0xF6F5EC);
          r(x - 3, 92, 6, 10, 0x1B1F1C);
          r(x - 3, 112, 6, 10, 0x1B1F1C);
          r(x - 3, 132, 6, 10, 0x1B1F1C);
          o(x, 70, 8, 0xF29A2E);
        }
        break;
      case 'light':
        r(56, 70, 8, 88, 0x2A2F2A);
        r(40, 0, 40, 86, 0x1A1F1C, 9);
        o(60, 20, 10, 0x5A2A22);
        o(60, 43, 10, 0x5A4A22);
        o(60, 66, 14, 0x9FD36E, 0.3);
        o(60, 66, 10, 0x9FD36E);
        break;
      case 'stop':
        r(56, 70, 8, 88, 0xCFD3C4);
        c.drawPath(poly([45, 6, 75, 6, 96, 27, 96, 57, 75, 78, 45, 78, 24, 57, 24, 27]), f(0xC1573D));
        r(38, 36, 44, 9, 0xF6F5EC, 4);
        break;
      case 'lookboth':
        r(56, 70, 8, 88, 0xCFD3C4);
        c.drawPath(poly([60, 4, 100, 42, 60, 80, 20, 42]), f(0xD9A62E));
        c.drawLine(const Offset(34, 42), const Offset(86, 42), Paint()..color = const Color(0xFF1B1706)..strokeWidth = 4..strokeCap = StrokeCap.round);
        break;
      case 'gate':
        r(8, 58, 18, 100, 0xD7C79A);
        r(94, 58, 18, 100, 0xD7C79A);
        c.drawPath(Path()..moveTo(8, 64)..quadraticBezierTo(60, -44, 112, 64), Paint()..style = PaintingStyle.stroke..strokeWidth = 10..color = const Color(0xFF3C4A2C));
        o(60, 30, 12, 0xD9A62E);
        for (final x in const [38.0, 52.0, 68.0, 82.0]) {
          c.drawLine(Offset(x, 90), Offset(x, 158), Paint()..color = const Color(0xFF3C4A2C)..strokeWidth = 4);
        }
        break;
      default:
        r(56, 70, 8, 88, 0xCFD3C4);
        o(60, 50, 24, 0xD9A62E);
    }
  }

  @override
  bool shouldRepaint(LandmarksPainter old) => old.states != states || old.theme != theme || old.landmarkX != landmarkX || old.feetY != feetY || old.art != art;
}
