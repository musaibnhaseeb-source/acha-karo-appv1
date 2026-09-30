import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter_test/flutter_test.dart';
import 'package:acha_karo/utils/image_metadata.dart';

// Fixtures (test/fixtures/) are 16x8 synthetic images made with sharp, carrying EXIF GPS tags
// (31°31'13.44"N 74°21'31.32"E), Make/Model and, for gps_exif.jpg/.png, XMP and Orientation 6.

Uint8List _fixture(String name) => File('test/fixtures/$name').readAsBytesSync();

// JPEG segment markers up to start-of-scan, with each segment's payload.
List<(int, Uint8List)> _jpegSegments(Uint8List b) {
  final out = <(int, Uint8List)>[];
  var i = 2;
  while (i + 4 <= b.length) {
    final marker = b[i + 1];
    final len = (b[i + 2] << 8) | b[i + 3];
    out.add((marker, Uint8List.sublistView(b, i + 4, i + 2 + len)));
    if (marker == 0xDA) break;
    i += 2 + len;
  }
  return out;
}

List<String> _pngChunkTypes(Uint8List b) {
  final out = <String>[];
  var i = 8;
  while (i + 12 <= b.length) {
    final len = (b[i] << 24) | (b[i + 1] << 16) | (b[i + 2] << 8) | b[i + 3];
    out.add(String.fromCharCodes(b.sublist(i + 4, i + 8)));
    i += 12 + len;
  }
  return out;
}

bool _contains(Uint8List hay, List<int> needle) {
  outer:
  for (var i = 0; i + needle.length <= hay.length; i++) {
    for (var k = 0; k < needle.length; k++) {
      if (hay[i + k] != needle[k]) continue outer;
    }
    return true;
  }
  return false;
}

// Markers of what must be gone: the GPS IFD pointer tag (0x8825, either byte order), the XMP
// namespace, and the camera make.
void _expectNoLeaks(Uint8List out) {
  expect(_contains(out, [0x88, 0x25]) || _contains(out, [0x25, 0x88]), isFalse, reason: 'GPS IFD pointer');
  expect(_contains(out, 'ns.adobe.com'.codeUnits), isFalse, reason: 'XMP');
  expect(_contains(out, 'TestCam'.codeUnits), isFalse, reason: 'camera make');
}

// The only EXIF allowed through: "Exif\0\0" + a one-entry big-endian IFD0 holding Orientation.
List<int> _orientationOnlyExif(int o) => [
      ...'Exif'.codeUnits, 0, 0,
      0x4D, 0x4D, 0x00, 0x2A, 0x00, 0x00, 0x00, 0x08, 0x00, 0x01,
      0x01, 0x12, 0x00, 0x03, 0x00, 0x00, 0x00, 0x01, 0x00, o, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    ];

Future<(int, int)> _decodeSize(WidgetTester tester, Uint8List bytes) async {
  return (await tester.runAsync(() async {
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    return (frame.image.width, frame.image.height);
  }))!;
}

void main() {
  test('fixtures really carry GPS, XMP and camera EXIF', () {
    final jpg = _fixture('gps_exif.jpg');
    expect(_jpegSegments(jpg).any((s) => s.$1 == 0xE1), isTrue);
    expect(_contains(jpg, [0x88, 0x25]) || _contains(jpg, [0x25, 0x88]), isTrue);
    expect(_contains(jpg, 'ns.adobe.com'.codeUnits), isTrue);
    expect(_pngChunkTypes(_fixture('gps_exif.png')), contains('eXIf'));
  });

  testWidgets('upright JPEG with GPS: no APP1 at all, still decodes', (tester) async {
    final clean = (await stripImageMetadata(_fixture('gps_exif_upright.jpg')))!;
    expect(clean.extension, 'jpg');
    expect(_jpegSegments(clean.bytes).where((s) => s.$1 == 0xE1), isEmpty);
    _expectNoLeaks(clean.bytes);
    expect(await _decodeSize(tester, clean.bytes), (16, 8));
  });

  testWidgets('rotated JPEG with GPS + XMP: only an Orientation-only APP1 remains, still decodes', (tester) async {
    final clean = (await stripImageMetadata(_fixture('gps_exif.jpg')))!;
    expect(clean.extension, 'jpg');
    final app1 = _jpegSegments(clean.bytes).where((s) => s.$1 == 0xE1).toList();
    expect(app1, hasLength(1));
    expect(app1.single.$2, _orientationOnlyExif(6));
    expect(_jpegSegments(clean.bytes).where((s) => s.$1 == 0xFE), isEmpty); // no comments
    _expectNoLeaks(clean.bytes);
    // Orientation 6 = rotate 90°, so the decoder shows the 16x8 image as 8x16.
    expect(await _decodeSize(tester, clean.bytes), (8, 16));
  });

  testWidgets('PNG with eXIf + XMP text: only an Orientation-only eXIf remains, still decodes', (tester) async {
    final clean = (await stripImageMetadata(_fixture('gps_exif.png')))!;
    expect(clean.extension, 'png');
    final types = _pngChunkTypes(clean.bytes);
    expect(types.where((t) => t == 'eXIf'), hasLength(1));
    expect(types.any((t) => t == 'tEXt' || t == 'zTXt' || t == 'iTXt'), isFalse);
    _expectNoLeaks(clean.bytes);
    // Whether a decoder applies PNG eXIf orientation varies, so either way round is fine here.
    expect([(16, 8), (8, 16)], contains(await _decodeSize(tester, clean.bytes)));
  });

  testWidgets('WebP with GPS EXIF is re-encoded to PNG with no metadata', (tester) async {
    final clean = (await tester.runAsync(() => stripImageMetadata(_fixture('gps_exif.webp'))))!;
    expect(clean.extension, 'png');
    expect(_pngChunkTypes(clean.bytes).any((t) => t == 'eXIf' || t == 'tEXt' || t == 'iTXt' || t == 'zTXt'), isFalse);
    _expectNoLeaks(clean.bytes);
  });

  testWidgets('a truncated JPEG is never returned with its metadata', (tester) async {
    final jpg = _fixture('gps_exif.jpg');
    final truncated = Uint8List.sublistView(jpg, 0, jpg.length - 40);
    expect(stripJpegMetadata(truncated), isNull);
    final clean = await tester.runAsync(() => stripImageMetadata(truncated));
    if (clean != null) _expectNoLeaks(clean.bytes); // re-encoded, or null (nothing uploaded)
  });
}
