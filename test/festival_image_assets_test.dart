import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

/// Budget enforced by `scripts/compress_festival_images.py` (agreed 2026-09).
/// These tests are the automatic enforcement: adding an oversized or
/// non-WebP image fails `flutter test` until the script is run.
const int kMaxFestivalImageBytes = 200 * 1024;
const int kMaxFestivalImageSidePx = 800;

/// Path prefix all bundled festival artwork must live under. `pubspec.yaml`
/// bundles this whole directory, so strays bloat the APK/IPA silently.
const String kFestivalImageDir = 'assets/images/festival/';

/// All non-empty `visuals.image` references as {assetPath: festivalId}.
Map<String, String> _referencedImages() {
  final file = File('assets/festivals.json');
  final decoded = jsonDecode(file.readAsStringSync()) as List;
  final refs = <String, String>{};
  for (final entry in decoded.cast<Map<String, dynamic>>()) {
    final visuals = (entry['visuals'] as Map?)?.cast<String, dynamic>() ?? {};
    final image = (visuals['image'] ?? '').toString().trim();
    if (image.isNotEmpty) refs[image] = entry['id'].toString();
  }
  return refs;
}

int _u16be(Uint8List b, int o) => (b[o] << 8) | b[o + 1];
int _u16le(Uint8List b, int o) => b[o] | (b[o + 1] << 8);
int _u24le(Uint8List b, int o) => b[o] | (b[o + 1] << 8) | (b[o + 2] << 16);
String _fourCC(Uint8List b, int o) =>
    String.fromCharCodes(b.sublist(o, o + 4));

/// Pixel dimensions parsed from raw bytes (no new dependencies).
/// Supports WebP (VP8/VP8L/VP8X), PNG and JPEG (for clear failure messages
/// when a non-WebP file slips in).
({int width, int height}) _imageDimensions(Uint8List b, String path) {
  // PNG: 8-byte signature, then IHDR width/height as big-endian u32.
  if (b.length > 24 &&
      b[0] == 0x89 &&
      b[1] == 0x50 &&
      _fourCC(b, 12) == 'IHDR') {
    final w = (b[16] << 24) | (b[17] << 16) | (b[18] << 8) | b[19];
    final h = (b[20] << 24) | (b[21] << 16) | (b[22] << 8) | b[23];
    return (width: w, height: h);
  }
  // JPEG: scan segments for a Start-Of-Frame marker (C0-CF excl. C4/C8/CC).
  if (b.length > 4 && b[0] == 0xFF && b[1] == 0xD8) {
    var o = 2;
    while (o + 9 < b.length) {
      if (b[o] != 0xFF) {
        o++;
        continue;
      }
      final marker = b[o + 1];
      if (marker == 0xD8 || marker == 0xD9 || (marker >= 0xD0 && marker <= 0xD7)) {
        o += 2;
        continue;
      }
      final segLen = _u16be(b, o + 2);
      if (marker >= 0xC0 &&
          marker <= 0xCF &&
          marker != 0xC4 &&
          marker != 0xC8 &&
          marker != 0xCC) {
        return (width: _u16be(b, o + 7), height: _u16be(b, o + 5));
      }
      o += 2 + segLen;
    }
    throw StateError('No SOF marker found in $path');
  }
  // WebP: RIFF....WEBP + VP8 /VP8L/VP8X chunk.
  if (b.length > 16 &&
      _fourCC(b, 0) == 'RIFF' &&
      _fourCC(b, 8) == 'WEBP') {
    final chunk = _fourCC(b, 12);
    if (chunk == 'VP8 ') {
      // Lossy: 4-byte size, 3-byte frame tag, 0x9D012A, then full 14-bit
      // w/h (the minus-one packing applies only to VP8L/VP8X).
      final w = _u16le(b, 26) & 0x3FFF;
      final h = _u16le(b, 28) & 0x3FFF;
      return (width: w, height: h);
    }
    if (chunk == 'VP8L') {
      // Lossless: 0x2F then 14-bit w/h packed little-endian.
      final w = b[21] | ((b[22] & 0x3F) << 8);
      final h = ((b[22] >> 6) | (b[23] << 2) | ((b[24] & 0x0F) << 10));
      return (width: w + 1, height: h + 1);
    }
    if (chunk == 'VP8X') {
      // Extended: 24-bit canvas size minus one, little-endian.
      return (width: _u24le(b, 24) + 1, height: _u24le(b, 27) + 1);
    }
  }
  throw StateError('Unsupported image format: $path');
}

void main() {
  group('Festival image asset budget (WebP / <=800px / <=200 KB)', () {
    test('referenced images exist under assets/images/festival/', () {
      // Arrange
      final refs = _referencedImages();

      // Act
      final missing = {
        for (final e in refs.entries)
          if (!File(e.key).existsSync()) e.key: e.value,
      };

      // Assert
      expect(
        missing,
        isEmpty,
        reason: 'Missing artwork (path -> festival id): $missing',
      );
    });

    test('festival images use the .webp format', () {
      // Arrange
      final refs = _referencedImages();

      // Act
      final nonWebP = refs.keys
          .where((p) => !p.toLowerCase().endsWith('.webp'))
          .toList();

      // Assert
      expect(
        nonWebP,
        isEmpty,
        reason:
            'Run python scripts/compress_festival_images.py to convert: $nonWebP',
      );
    });

    test('festival images are <= 200 KB each', () {
      // Arrange
      final refs = _referencedImages();

      // Act
      final oversized = <String>[];
      for (final path in refs.keys) {
        final file = File(path);
        if (!file.existsSync()) continue;
        final kb = file.lengthSync() ~/ 1024;
        if (file.lengthSync() > kMaxFestivalImageBytes) {
          oversized.add('$path ($kb KB)');
        }
      }

      // Assert
      expect(
        oversized,
        isEmpty,
        reason:
            'Run python scripts/compress_festival_images.py to shrink: $oversized',
      );
    });

    test('festival images fit within 800px on the longest side', () {
      // Arrange
      final refs = _referencedImages();

      // Act
      final tooBig = <String>[];
      for (final path in refs.keys) {
        final file = File(path);
        if (!file.existsSync()) continue;
        final dims = _imageDimensions(file.readAsBytesSync(), path);
        final longest = dims.width > dims.height ? dims.width : dims.height;
        if (longest > kMaxFestivalImageSidePx) {
          tooBig.add('$path (${dims.width}x${dims.height})');
        }
      }

      // Assert
      expect(
        tooBig,
        isEmpty,
        reason:
            'Run python scripts/compress_festival_images.py to downscale: $tooBig',
      );
    });

    test('no orphan images ship unreferenced in the bundle', () {
      // Arrange: pubspec bundles the whole dir, so every file ships.
      final refs = _referencedImages();
      final dir = Directory(kFestivalImageDir);

      // Act
      final orphans = dir
          .listSync()
          .whereType<File>()
          .map((f) => f.path.replaceAll('\\', '/'))
          .where((p) => !refs.containsKey(p))
          .toList();

      // Assert
      expect(
        orphans,
        isEmpty,
        reason: 'Unreferenced files bloat the app bundle: $orphans',
      );
    });

    test('dimension parser reads the shipped artwork correctly', () {
      // Arrange: ground truth for the one bundled image (600x800 WebP).
      final bytes = File('${kFestivalImageDir}shri_ganesh.webp')
          .readAsBytesSync();

      // Act
      final dims = _imageDimensions(bytes, 'shri_ganesh.webp');

      // Assert
      expect(dims.width, equals(600));
      expect(dims.height, equals(800));
    });
  });
}
