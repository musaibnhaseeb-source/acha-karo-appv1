import 'dart:typed_data';
import 'dart:ui' as ui;

// Strips metadata (EXIF incl. GPS, XMP, IPTC, comments) from a deed photo before it's uploaded.
// Needed because image_picker_android copies the original photo's EXIF, GPS tags included, onto
// its resized output. Pure Dart, so the same code runs on Android and on the web/PWA.
//
// The one piece of EXIF that's kept is Orientation. The Android resizer doesn't rotate the
// pixels, it relies on that tag, so dropping it would show portrait photos sideways. It's
// written back as a fresh, one-entry EXIF block, so nothing else from the original survives.
//
// JPEG and PNG are cleaned by dropping segments/chunks without re-encoding. Anything else
// (WebP, HEIC, GIF) or a file that doesn't parse is decoded and re-encoded as PNG through
// dart:ui. A re-encode never carries metadata. If even that fails, the result is null and the
// caller uploads nothing, rather than uploading the original with its metadata.

class CleanImage {
  final Uint8List bytes;
  final String extension; // from the actual bytes, not the picked file name
  const CleanImage(this.bytes, this.extension);
}

Future<CleanImage?> stripImageMetadata(Uint8List bytes) async {
  if (isJpeg(bytes)) {
    final out = stripJpegMetadata(bytes);
    if (out != null) return CleanImage(out, 'jpg');
  } else if (isPng(bytes)) {
    final out = stripPngMetadata(bytes);
    if (out != null) return CleanImage(out, 'png');
  }
  final reencoded = await _reencodeAsPng(bytes);
  return reencoded == null ? null : CleanImage(reencoded, 'png');
}

bool isJpeg(Uint8List b) => b.length > 3 && b[0] == 0xFF && b[1] == 0xD8 && b[2] == 0xFF;

const _pngSignature = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A];
bool isPng(Uint8List b) {
  if (b.length < 8) return false;
  for (var i = 0; i < 8; i++) {
    if (b[i] != _pngSignature[i]) return false;
  }
  return true;
}

Future<Uint8List?> _reencodeAsPng(Uint8List bytes) async {
  try {
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    final data = await frame.image.toByteData(format: ui.ImageByteFormat.png);
    frame.image.dispose();
    codec.dispose();
    return data?.buffer.asUint8List();
  } catch (_) {
    return null;
  }
}

// ---- JPEG ----------------------------------------------------------------------------------

bool _startsWith(Uint8List b, int offset, List<int> prefix) {
  if (offset + prefix.length > b.length) return false;
  for (var i = 0; i < prefix.length; i++) {
    if (b[offset + i] != prefix[i]) return false;
  }
  return true;
}

const _exifHeader = [0x45, 0x78, 0x69, 0x66, 0x00, 0x00]; // "Exif\0\0"
const _iccHeader = [0x49, 0x43, 0x43, 0x5F, 0x50, 0x52, 0x4F, 0x46, 0x49, 0x4C, 0x45, 0x00]; // "ICC_PROFILE\0"

// Keeps only what's needed to show the picture: APP0 (JFIF), APP2 ICC colour profile, APP14
// (Adobe colour transform) and the non-APP image segments. Drops every other APPn (APP1 EXIF
// and XMP, APP13 IPTC, MPF...), comments, and anything after the end-of-image marker (some
// phones append extra images or data there). Returns null if the file doesn't parse cleanly.
Uint8List? stripJpegMetadata(Uint8List b) {
  if (!isJpeg(b)) return null;
  final n = b.length;
  final segments = <Uint8List>[];
  int? orientation;
  var i = 2;
  var sawEoi = false;
  var sawSos = false;
  while (i < n) {
    if (b[i] != 0xFF) return null;
    while (i + 1 < n && b[i + 1] == 0xFF) {
      i++; // fill bytes
    }
    if (i + 1 >= n) return null;
    final marker = b[i + 1];
    if (marker == 0xD9) {
      sawEoi = true;
      break;
    }
    if ((marker >= 0xD0 && marker <= 0xD7) || marker == 0x01) {
      segments.add(Uint8List.sublistView(b, i, i + 2));
      i += 2;
      continue;
    }
    if (i + 3 >= n) return null;
    final len = (b[i + 2] << 8) | b[i + 3];
    final end = i + 2 + len;
    if (len < 2 || end > n) return null;
    final payload = i + 4;

    var keep = true;
    if (marker == 0xE1) {
      if (_startsWith(b, payload, _exifHeader)) {
        orientation ??= _readTiffOrientation(Uint8List.sublistView(b, payload + 6, end));
      }
      keep = false;
    } else if (marker == 0xE2) {
      keep = _startsWith(b, payload, _iccHeader);
    } else if (marker >= 0xE1 && marker <= 0xEF) {
      keep = marker == 0xEE; // APP14 Adobe
    } else if (marker == 0xFE) {
      keep = false; // comment
    }

    if (marker == 0xDA) {
      // Start of scan: the header is followed by entropy-coded data that runs until the next
      // real marker (0xFF followed by anything other than 0x00, a restart marker or more 0xFF).
      sawSos = true;
      var j = end;
      while (j < n) {
        if (b[j] == 0xFF && j + 1 < n) {
          final next = b[j + 1];
          if (next == 0x00 || (next >= 0xD0 && next <= 0xD7)) {
            j += 2;
            continue;
          }
          if (next == 0xFF) {
            j++;
            continue;
          }
          break;
        }
        j++;
      }
      if (j >= n) return null; // ran off the end without reaching a marker
      segments.add(Uint8List.sublistView(b, i, j));
      i = j;
      continue;
    }
    if (keep) segments.add(Uint8List.sublistView(b, i, end));
    i = end;
  }
  if (!sawEoi || !sawSos) return null;

  final out = BytesBuilder(copy: false)..add(const [0xFF, 0xD8]);
  var rest = segments;
  // JFIF wants APP0 first, so the rebuilt EXIF goes after it when there is one.
  if (rest.isNotEmpty && rest.first.length > 1 && rest.first[1] == 0xE0) {
    out.add(rest.first);
    rest = rest.sublist(1);
  }
  if (orientation != null && orientation >= 2 && orientation <= 8) {
    final tiff = _orientationOnlyTiff(orientation);
    final len = 2 + _exifHeader.length + tiff.length;
    out
      ..add([0xFF, 0xE1, len >> 8, len & 0xFF])
      ..add(_exifHeader)
      ..add(tiff);
  }
  for (final s in rest) {
    out.add(s);
  }
  out.add(const [0xFF, 0xD9]);
  return out.takeBytes();
}

// Reads IFD0's Orientation tag (0x0112) from a TIFF block. Returns null if it's absent or the
// block is malformed.
int? _readTiffOrientation(Uint8List t) {
  if (t.length < 8) return null;
  final bool le;
  if (t[0] == 0x49 && t[1] == 0x49) {
    le = true;
  } else if (t[0] == 0x4D && t[1] == 0x4D) {
    le = false;
  } else {
    return null;
  }
  int u16(int o) => le ? t[o] | (t[o + 1] << 8) : (t[o] << 8) | t[o + 1];
  int u32(int o) => le
      ? t[o] | (t[o + 1] << 8) | (t[o + 2] << 16) | (t[o + 3] << 24)
      : (t[o] << 24) | (t[o + 1] << 16) | (t[o + 2] << 8) | t[o + 3];
  final ifd = u32(4);
  if (ifd + 2 > t.length) return null;
  final count = u16(ifd);
  for (var k = 0; k < count; k++) {
    final e = ifd + 2 + k * 12;
    if (e + 12 > t.length) return null;
    if (u16(e) == 0x0112 && u16(e + 2) == 3) return u16(e + 8);
  }
  return null;
}

// Big-endian TIFF with a single IFD0 entry: Orientation (SHORT, count 1).
Uint8List _orientationOnlyTiff(int orientation) => Uint8List.fromList([
      0x4D, 0x4D, 0x00, 0x2A, 0x00, 0x00, 0x00, 0x08, // "MM", 42, IFD0 at offset 8
      0x00, 0x01, // 1 entry
      0x01, 0x12, 0x00, 0x03, 0x00, 0x00, 0x00, 0x01, 0x00, orientation, 0x00, 0x00,
      0x00, 0x00, 0x00, 0x00, // no next IFD
    ]);

// ---- PNG -----------------------------------------------------------------------------------

// Chunks needed to show the picture correctly. Everything else (eXIf, tEXt/zTXt/iTXt which
// carry XMP and comments, tIME, private chunks) is dropped.
const _pngKeep = {
  'IHDR', 'PLTE', 'IDAT', 'IEND', 'tRNS', 'cHRM', 'gAMA', 'iCCP', 'sBIT', 'sRGB', 'cICP',
  'bKGD', 'pHYs', 'acTL', 'fcTL', 'fdAT',
};

Uint8List? stripPngMetadata(Uint8List b) {
  if (!isPng(b)) return null;
  final n = b.length;
  final out = BytesBuilder(copy: false)..add(Uint8List.sublistView(b, 0, 8));
  int? orientation;
  var wroteOrientation = false;
  var i = 8;
  var sawEnd = false;
  while (i + 12 <= n) {
    final len = (b[i] << 24) | (b[i + 1] << 16) | (b[i + 2] << 8) | b[i + 3];
    final end = i + 12 + len;
    if (len < 0 || end > n) return null;
    final type = String.fromCharCodes(b.sublist(i + 4, i + 8));
    if (type == 'eXIf') {
      orientation ??= _readTiffOrientation(Uint8List.sublistView(b, i + 8, i + 8 + len));
    }
    // eXIf must come before the first IDAT, so the rebuilt one goes in just ahead of it.
    if (type == 'IDAT' && !wroteOrientation) {
      wroteOrientation = true;
      if (orientation != null && orientation >= 2 && orientation <= 8) {
        out.add(_pngChunk('eXIf', _orientationOnlyTiff(orientation)));
      }
    }
    if (_pngKeep.contains(type)) out.add(Uint8List.sublistView(b, i, end));
    i = end;
    if (type == 'IEND') {
      sawEnd = true;
      break;
    }
  }
  return sawEnd ? out.takeBytes() : null;
}

Uint8List _pngChunk(String type, Uint8List data) {
  final typeBytes = type.codeUnits;
  final crc = _crc32([...typeBytes, ...data]);
  final len = data.length;
  return Uint8List.fromList([
    len >> 24 & 0xFF, len >> 16 & 0xFF, len >> 8 & 0xFF, len & 0xFF,
    ...typeBytes,
    ...data,
    crc >> 24 & 0xFF, crc >> 16 & 0xFF, crc >> 8 & 0xFF, crc & 0xFF,
  ]);
}

final List<int> _crcTable = List<int>.generate(256, (n) {
  var c = n;
  for (var k = 0; k < 8; k++) {
    c = (c & 1) != 0 ? 0xEDB88320 ^ (c >> 1) : c >> 1;
  }
  return c;
});

int _crc32(List<int> data) {
  var c = 0xFFFFFFFF;
  for (final x in data) {
    c = _crcTable[(c ^ x) & 0xFF] ^ (c >> 8);
  }
  return c ^ 0xFFFFFFFF;
}
