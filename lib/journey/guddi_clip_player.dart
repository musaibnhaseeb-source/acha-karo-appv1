import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'guddi_clips.dart';

// Plays one transparent clip (numbered WebP frames) at the clip's fps.
// loop: repeats forever. one-shot: plays once, calls onFinished, then keeps showing the last frame.
// holdLast: shows only the last frame (used for the held pose after the celebration).
class GuddiClipPlayer extends StatefulWidget {
  final GuddiClipSet set;
  final GuddiClip clip;
  final bool holdLast;
  final VoidCallback? onFinished;
  const GuddiClipPlayer({super.key, required this.set, required this.clip, this.holdLast = false, this.onFinished});
  @override
  State<GuddiClipPlayer> createState() => _GuddiClipPlayerState();
}

class _GuddiClipPlayerState extends State<GuddiClipPlayer> with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  int _frame = 0;
  bool _done = false;

  @override
  void initState() {
    super.initState();
    final c = widget.clip;
    if (widget.holdLast) {
      _frame = c.frames - 1;
      _ticker = createTicker((_) {});
      return;
    }
    _ticker = createTicker((elapsed) {
      final f = (elapsed.inMicroseconds / 1e6 * c.fps).floor();
      if (c.loop) {
        var i = f % c.frames;
        if (c.pingPong && c.frames > 1) {
          final period = 2 * (c.frames - 1);
          final k = f % period;
          i = k < c.frames ? k : period - k;
        }
        if (i != _frame) setState(() => _frame = i);
      } else if (f >= c.frames) {
        if (!_done) {
          _done = true;
          if (_frame != c.frames - 1) setState(() => _frame = c.frames - 1);
          widget.onFinished?.call();
        }
      } else if (f != _frame) {
        setState(() => _frame = f);
      }
    })..start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.clip;
    return Image.asset(
      widget.set.framePath(c, _frame),
      width: c.imgW.toDouble(),
      height: c.imgH.toDouble(),
      fit: BoxFit.fill,
      gaplessPlayback: true,
      filterQuality: FilterQuality.medium,
    );
  }
}

// Puts a clip on the shared stage (the 478x850 master frame scaled by GuddiClips.scale), so every
// clip lines up on one anchor: feet at stage y = groundY, body centre at stage x = centreX.
class GuddiStage extends StatelessWidget {
  final GuddiClipSet set;
  final GuddiClip clip;
  final bool holdLast;
  final VoidCallback? onFinished;
  const GuddiStage({super.key, required this.set, required this.clip, this.holdLast = false, this.onFinished});

  @override
  Widget build(BuildContext context) {
    const s = GuddiClips.scale;
    return SizedBox(
      width: GuddiClips.stageW * s,
      height: GuddiClips.stageH * s,
      child: Stack(clipBehavior: Clip.none, children: [
        Positioned(
          left: clip.cropX * s,
          top: clip.cropY * s,
          child: GuddiClipPlayer(set: set, clip: clip, holdLast: holdLast, onFinished: onFinished),
        ),
      ]),
    );
  }
}

// Decodes every frame of every clip into the image cache so playback never stalls on first use.
Future<void> precacheGuddiClips(BuildContext context, GuddiClipSet set) async {
  final futures = <Future<void>>[];
  for (final c in set.all) {
    for (var i = 0; i < c.frames; i++) {
      futures.add(precacheImage(AssetImage(set.framePath(c, i)), context));
    }
  }
  await Future.wait(futures);
}
