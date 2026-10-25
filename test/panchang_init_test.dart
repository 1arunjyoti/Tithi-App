import 'dart:io';

import 'package:flutter/foundation.dart' show FlutterError;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'package:tithi/services/panchang_init/panchang_init.dart';

// Phase 6: the ephemeris copy used to trust "the file exists" and hand Swiss
// Ephemeris whatever was on disk. These tests pin the replacement contract:
// verify size + magic, re-copy anything that fails, write atomically, and
// fail with an actionable message when the bundled asset itself is broken.

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('plugins.flutter.io/path_provider');
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('tithi_panchang_init');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async => tempDir.path);
  });

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
    try {
      await tempDir.delete(recursive: true);
    } on FileSystemException {
      // Leave it to the OS if a handle is still open.
    }
  });

  File installed(String name) => File(p.join(tempDir.path, 'ephe', name));

  _FakeAssetBundle validBundle() => _FakeAssetBundle({
    for (final name in kEphemerisAssets) 'assets/ephe/$name': _se1(),
  });

  group('copyEphemerisFiles', () {
    test('copies every declared asset on first launch', () async {
      // Arrange
      final bundle = validBundle();

      // Act
      final path = await copyEphemerisFiles(bundle);

      // Assert
      expect(path, p.join(tempDir.path, 'ephe'));
      for (final name in kEphemerisAssets) {
        expect(installed(name).existsSync(), isTrue, reason: name);
      }
      expect(bundle.requested, hasLength(kEphemerisAssets.length));
    });

    test('does not reload assets that already verify', () async {
      // Arrange
      await copyEphemerisFiles(validBundle());
      final bundle = _FakeAssetBundle({});

      // Act
      await copyEphemerisFiles(bundle);

      // Assert: the second launch reads nothing from the bundle.
      expect(bundle.requested, isEmpty);
    });

    test('replaces a truncated file instead of trusting its existence',
        () async {
      // Arrange: a previous launch was killed mid-write.
      final target = installed('seas_18.se1');
      await target.parent.create(recursive: true);
      await target.writeAsBytes(_se1().sublist(0, 200));

      // Act
      await copyEphemerisFiles(validBundle());

      // Assert
      expect(await target.length(), _se1().length);
    });

    test('replaces a zero-byte file', () async {
      // Arrange
      final target = installed('semo_18.se1');
      await target.parent.create(recursive: true);
      await target.writeAsBytes(const <int>[]);

      // Act
      await copyEphemerisFiles(validBundle());

      // Assert
      expect(await target.length(), _se1().length);
    });

    test('replaces a file with the wrong header', () async {
      // Arrange: right size, wrong format.
      final target = installed('sepl_18.se1');
      await target.parent.create(recursive: true);
      await target.writeAsBytes(Uint8List(_se1().length));

      // Act
      await copyEphemerisFiles(validBundle());

      // Assert
      final bytes = await target.readAsBytes();
      expect(String.fromCharCodes(bytes.sublist(0, 8)), 'SWISSEPH');
    });

    test('leaves no staging file behind after a copy', () async {
      // Act
      await copyEphemerisFiles(validBundle());

      // Assert
      final leftovers = tempDir
          .listSync(recursive: true)
          .whereType<File>()
          .where((file) => file.path.endsWith('.part'))
          .toList();
      expect(leftovers, isEmpty);
    });

    test('throws when a bundled asset is missing', () async {
      // Arrange: only two of the three files ship.
      final bundle = _FakeAssetBundle({
        'assets/ephe/seas_18.se1': _se1(),
        'assets/ephe/semo_18.se1': _se1(),
      });

      // Act / Assert
      final error = await _captureEphemerisError(
        () => copyEphemerisFiles(bundle),
      );
      expect(error.file, 'sepl_18.se1');
      expect(error.message, contains('sepl_18.se1'));
      expect(error.message, contains('assets/ephe/sepl_18.se1'));
      expect(error.message, contains('Reinstall'));
      expect(error.message, contains('pubspec.yaml'));
      // The error must be actionable, not a raw FlutterError string.
      expect(error.cause, isA<FlutterError>());
    });

    test('throws when the bundled asset is not a .se1 file', () async {
      // Arrange
      final bundle = _FakeAssetBundle({
        for (final name in kEphemerisAssets) 'assets/ephe/$name': _se1(),
        'assets/ephe/semo_18.se1': Uint8List.fromList(
          List<int>.filled(4096, 0x41),
        ),
      });

      // Act / Assert
      final error = await _captureEphemerisError(
        () => copyEphemerisFiles(bundle),
      );
      expect(error.file, 'semo_18.se1');
      expect(error.message, contains('not usable'));
      expect(error.message, contains('Reinstall'));
    });

    test('throws when the bundled asset is too small', () async {
      // Arrange
      final bundle = _FakeAssetBundle({
        for (final name in kEphemerisAssets) 'assets/ephe/$name': _se1(),
        'assets/ephe/seas_18.se1': _se1(length: 64),
      });

      // Act / Assert
      final error = await _captureEphemerisError(
        () => copyEphemerisFiles(bundle),
      );
      expect(error.file, 'seas_18.se1');
      expect(error.message, contains('64 bytes'));
    });

    test('keeps a valid install untouched even if the bundle is broken',
        () async {
      // Arrange: a valid install, then a bad bundle (e.g. a corrupted build).
      await copyEphemerisFiles(validBundle());
      final target = installed('sepl_18.se1');
      final before = await target.readAsBytes();
      final bundle = _FakeAssetBundle({
        for (final name in kEphemerisAssets) 'assets/ephe/$name': _se1(),
        'assets/ephe/sepl_18.se1': Uint8List(4096),
      });

      // Act: a valid install short-circuits before the bundle is read.
      await copyEphemerisFiles(bundle);

      // Assert
      expect(bundle.requested, isEmpty);
      expect(await target.readAsBytes(), before);
    });
  });
}

Future<EphemerisAssetException> _captureEphemerisError(
  Future<void> Function() body,
) async {
  try {
    await body();
  } on EphemerisAssetException catch (error) {
    return error;
  }
  fail('Expected an EphemerisAssetException');
}

/// A `.se1` file with a valid header and a non-repeating body.
Uint8List _se1({int length = 2048}) {
  final bytes = Uint8List(length);
  final header = 'SWISSEPH  1\r\n'.codeUnits;
  final copied = header.length <= length ? header.length : length;
  bytes.setRange(0, copied, header);
  for (var i = copied; i < length; i++) {
    bytes[i] = i % 251;
  }
  return bytes;
}

class _FakeAssetBundle extends AssetBundle {
  _FakeAssetBundle(this.assets);

  final Map<String, Uint8List> assets;
  final List<String> requested = <String>[];

  @override
  Future<ByteData> load(String key) async {
    requested.add(key);
    final bytes = assets[key];
    if (bytes == null) {
      throw FlutterError('Unable to load asset: "$key".');
    }
    return ByteData.sublistView(bytes);
  }
}
