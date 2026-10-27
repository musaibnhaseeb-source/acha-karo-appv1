// Registry of the Guddi clips (transparent WebP frame sequences, 10-15 fps, quality ~65).
//
// All clips were cut from one fixed-camera master (478x850 source px), keyed, padded 16 px, cropped to
// their own bounding box and scaled by [GuddiClips.scale]. crop* is the crop box in SOURCE px, so a
// frame is drawn at (cropX*scale, cropY*scale) on a shared stage of stageW x stageH source px; that
// keeps the feet on one ground line (stage y = groundY) and the body centre on one x (centreX)
// across every clip when they are chained.
class GuddiClip {
  final String name; // folder + file prefix under the clip set root
  final int frames;
  final double fps;
  final bool loop;
  final int cropX, cropY; // source px
  final int imgW, imgH; // pixel size of the frame files
  final bool pingPong; // loop forward then backward (no seam, no crossfade ghosting); only with loop
  const GuddiClip(this.name, this.frames, this.fps, this.loop, this.cropX, this.cropY, this.imgW, this.imgH, {this.pingPong = false});
}

class GuddiClips {
  static const double scale = 0.75;
  static const double stageW = 478, stageH = 850; // source px of the master frame
  static const double groundY = 806; // feet line, source px
  static const double centreX = 255; // body centre, source px
}

class GuddiClipSet {
  final String root; // e.g. assets/images/guddi/journey (one folder per clip below it)
  const GuddiClipSet(this.root);

  // idle: hands clasped; master f0-33 played forward then backward. The idle drifts (slow head turn), so a plain
  // loop pops and a crossfade double-exposes the face; ping-pong has neither.
  GuddiClip get idle => const GuddiClip('idle', 14, 10, true, 160, 86, 168, 548, pingPong: true);
  // walk_start: idle -> first steps; the last frame leads into walk_loop's first frame
  GuddiClip get walkStart => const GuddiClip('walk_start', 26, 15, false, 90, 78, 216, 562);
  // walk_loop: one stride, loops (crossfaded end; slight ghosting in the blended third)
  GuddiClip get walkLoop => const GuddiClip('walk_loop', 11, 15, true, 90, 78, 216, 558);
  // walk_stop: continuation of the walk that turns to face the camera; starts with a 4-frame
  // crossfade from the loop's own next frames
  GuddiClip get walkStop => const GuddiClip('walk_stop', 14, 15, false, 106, 78, 198, 558);
  // celebrate: ready pose -> jump -> land -> arms crossed (the last frame is the held pose)
  GuddiClip get celebrate => const GuddiClip('celebrate', 27, 10, false, 62, 16, 302, 604);
  // return: arms crossed -> uncross -> settle to hands clasped
  GuddiClip get returning => const GuddiClip('return', 20, 10, false, 112, 80, 206, 558);

  List<GuddiClip> get all => [idle, walkStart, walkLoop, walkStop, celebrate, returning];

  String framePath(GuddiClip c, int index) =>
      '$root/${c.name}/${c.name}_${(index + 1).toString().padLeft(3, '0')}.webp';
}

const defaultGuddiClips = GuddiClipSet('assets/images/guddi/journey');
