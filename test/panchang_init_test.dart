import 'dart:io';

import 'package:crypto/crypto.dart' show sha256;
import 'package:flutter/foundation.dart' show FlutterError, TargetPlatform;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jyotish/jyotish.dart';
import 'package:path/path.dart' as p;

import 'package:tithi/services/panchang_init/panchang_init.dart';

// Phase 6: the ephemeris copy used to trust "the file exists" and hand Swiss
// Ephemeris whatever was on disk. These tests pin the replacement contract:
// verify size + magic + checksum, re-copy anything that fails, write atomically,
// and fail with an actionable message when the bundled asset itself is broken.

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('plugins.flutter.io/path_provider');
  late Directory tempDir;
  late Map<String, String> manifest;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('tithi_panchang_init');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async => tempDir.path);
    // The synthetic bundle below is not the shipped data, so the manifest has to
    // describe it instead of the real assets/ephe files.
    manifest = {for (final name in kEphemerisAssets) name: _sha256(_se1())};
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

  Future<String> copy(AssetBundle bundle) =>
      copyEphemerisFiles(bundle, sha256ByFile: manifest);

  _FakeAssetBundle validBundle() => _FakeAssetBundle({
    for (final name in kEphemerisAssets) 'assets/ephe/$name': _se1(),
  });

  group('copyEphemerisFiles', () {
    test('copies every declared asset on first launch', () async {
      // Arrange
      final bundle = validBundle();

      // Act
      final path = await copy(bundle);

      // Assert
      expect(path, p.join(tempDir.path, 'ephe'));
      for (final name in kEphemerisAssets) {
        expect(installed(name).existsSync(), isTrue, reason: name);
      }
      expect(bundle.requested, hasLength(kEphemerisAssets.length));
    });

    test('does not reload assets that already verify', () async {
      // Arrange
      await copy(validBundle());
      final bundle = _FakeAssetBundle({});

      // Act
      await copy(bundle);

      // Assert: the second launch reads nothing from the bundle.
      expect(bundle.requested, isEmpty);
    });

    test(
      'replaces a truncated file instead of trusting its existence',
      () async {
        // Arrange: a previous launch was killed mid-write.
        final target = installed('seas_18.se1');
        await target.parent.create(recursive: true);
        await target.writeAsBytes(_se1().sublist(0, 200));

        // Act
        await copy(validBundle());

        // Assert
        expect(await target.length(), _se1().length);
      },
    );

    test('replaces a zero-byte file', () async {
      // Arrange
      final target = installed('semo_18.se1');
      await target.parent.create(recursive: true);
      await target.writeAsBytes(const <int>[]);

      // Act
      await copy(validBundle());

      // Assert
      expect(await target.length(), _se1().length);
    });

    test('replaces a file with the wrong header', () async {
      // Arrange: right size, wrong format.
      final target = installed('sepl_18.se1');
      await target.parent.create(recursive: true);
      await target.writeAsBytes(Uint8List(_se1().length));

      // Act
      await copy(validBundle());

      // Assert
      final bytes = await target.readAsBytes();
      expect(String.fromCharCodes(bytes.sublist(0, 8)), 'SWISSEPH');
    });

    test(
      'replaces a file with a valid size and header but wrong contents',
      () async {
        // Arrange: this is the case size + magic cannot see - a copy that kept
        // its first kilobyte and lost or gained bytes further in.
        final target = installed('seas_18.se1');
        await target.parent.create(recursive: true);
        await target.writeAsBytes(_corrupt(_se1()));

        // Act
        await copy(validBundle());

        // Assert
        expect(_sha256(await target.readAsBytes()), _sha256(_se1()));
      },
    );

    test('leaves no staging file behind after a copy', () async {
      // Act
      await copy(validBundle());

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
      final error = await _captureEphemerisError(() => copy(bundle));
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
      final error = await _captureEphemerisError(() => copy(bundle));
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
      final error = await _captureEphemerisError(() => copy(bundle));
      expect(error.file, 'seas_18.se1');
      expect(error.message, contains('64 bytes'));
    });

    test('throws when the bundled asset fails the checksum', () async {
      // Arrange: valid size, valid header, one byte different - a wrong build
      // or a corrupted copy inside the APK.
      final bundle = _FakeAssetBundle({
        for (final name in kEphemerisAssets) 'assets/ephe/$name': _se1(),
        'assets/ephe/semo_18.se1': _corrupt(_se1()),
      });

      // Act / Assert
      final error = await _captureEphemerisError(() => copy(bundle));
      expect(error.file, 'semo_18.se1');
      expect(error.message, contains('checksum'));
      expect(error.message, contains('Reinstall'));
      // Nothing is installed when the source itself is untrustworthy.
      expect(installed('semo_18.se1').existsSync(), isFalse);
    });

    test(
      'throws when the manifest has no entry for a declared asset',
      () async {
        // Arrange: a developer added a file to kEphemerisAssets only.
        manifest = {'seas_18.se1': _sha256(_se1())};

        // Act / Assert
        final error = await _captureEphemerisError(() => copy(validBundle()));
        expect(error.file, 'semo_18.se1');
        expect(error.message, contains('checksum'));
        expect(error.message, contains('kEphemerisAssetSha256'));
      },
    );

    test(
      'keeps a valid install untouched even if the bundle is broken',
      () async {
        // Arrange: a valid install, then a bad bundle (e.g. a corrupted build).
        await copy(validBundle());
        final target = installed('sepl_18.se1');
        final before = await target.readAsBytes();
        final bundle = _FakeAssetBundle({
          for (final name in kEphemerisAssets) 'assets/ephe/$name': _se1(),
          'assets/ephe/sepl_18.se1': Uint8List(4096),
        });

        // Act: a valid install short-circuits before the bundle is read.
        await copy(bundle);

        // Assert
        expect(bundle.requested, isEmpty);
        expect(await target.readAsBytes(), before);
      },
    );
  });

  group('shipped ephemeris manifest', () {
    test('covers exactly the declared assets', () {
      expect(kEphemerisAssetSha256.keys.toSet(), kEphemerisAssets.toSet());
    });

    test('matches the bytes in assets/ephe', () async {
      // Guards the build: replacing a .se1 without updating the manifest would
      // make every device reinstall the old expected hash forever, or reject a
      // good bundle. Runs against the real files, not the fake bundle.
      for (final name in kEphemerisAssets) {
        final file = File(p.join('assets', 'ephe', name));
        expect(file.existsSync(), isTrue, reason: name);
        expect(
          _sha256(await file.readAsBytes()),
          kEphemerisAssetSha256[name],
          reason: '$name changed without updating kEphemerisAssetSha256',
        );
      }
    });
  });

  group('ensureNativeEngineInstalled', () {
    test('throws on Android when the solar engine fell back', () {
      // Act / Assert: a NOAA fallback moves sunrise, which far more rules read
      // than the lunar one, so it must not pass as a normal startup.
      expect(
        () => ensureNativeEngineInstalled(
          platform: TargetPlatform.android,
          solarSetupError: StateError('swe_set_ephe_path failed'),
          moonSetupError: null,
        ),
        throwsA(isA<EphemerisEngineException>()),
      );
    });

    test('throws on Android when only the lunar engine fell back', () {
      // Arrange: the approximation is 1-3 minutes out, which is enough to move
      // a `moonrise` observance's matching instant.
      final failure = StateError('libswisseph.so not found');

      // Act / Assert
      expect(
        () => ensureNativeEngineInstalled(
          platform: TargetPlatform.android,
          solarSetupError: null,
          moonSetupError: failure,
        ),
        throwsA(
          isA<EphemerisEngineException>().having(
            (error) => error.cause,
            'cause',
            same(failure),
          ),
        ),
      );
    });

    test('does nothing on Android when both engines installed', () {
      // Act / Assert
      expect(
        () => ensureNativeEngineInstalled(
          platform: TargetPlatform.android,
          solarSetupError: null,
          moonSetupError: null,
        ),
        returnsNormally,
      );
    });

    test('does not throw on platforms that do not ship the native engine', () {
      // Arrange: desktop/web scaffolding builds no Swiss Ephemeris, so the
      // labelled approximation is the documented behaviour there.
      final failure = StateError('library not built for this platform');

      // Act / Assert
      for (final platform in TargetPlatform.values) {
        if (kNativeEnginePlatforms.contains(platform)) continue;
        expect(
          () => ensureNativeEngineInstalled(
            platform: platform,
            solarSetupError: failure,
            moonSetupError: failure,
          ),
          returnsNormally,
          reason: '$platform',
        );
      }
    });

    test('names the failure and the recovery step', () {
      // Act
      final error = _captureEngineError(
        () => ensureNativeEngineInstalled(
          platform: TargetPlatform.android,
          solarSetupError: StateError('opaque FFI failure'),
          moonSetupError: null,
        ),
      );

      // Assert: the banner shows this verbatim, so it must be actionable and
      // must not leak the raw FFI text.
      expect(error.message, contains('Swiss Ephemeris'));
      expect(error.message, contains('Reinstall'));
      expect(error.message, contains('approximate'));
      expect(error.message, isNot(contains('opaque FFI failure')));
    });
  });

  group('ensureEphemerisRangeInstalled', () {
    EphemerisFileRange file(int ifno, int startYear, int endYear) {
      return EphemerisFileRange(
        ifno: ifno,
        path: '/tmp/file.se1',
        startUtc: DateTime.utc(startYear),
        endUtc: DateTime.utc(endYear, 12, 31),
        denum: 0,
      );
    }

    test('accepts the bundled 1800-2399 range', () {
      final range = EphemerisDataRange(
        planets: file(
          0,
          kEphemerisExpectedStartYear,
          kEphemerisExpectedEndYear,
        ),
        moon: file(1, kEphemerisExpectedStartYear, kEphemerisExpectedEndYear),
      );

      expect(() => ensureEphemerisRangeInstalled(range), returnsNormally);
    });

    test('rejects a missing lunar file', () {
      final range = EphemerisDataRange(
        planets: file(
          0,
          kEphemerisExpectedStartYear,
          kEphemerisExpectedEndYear,
        ),
      );

      expect(
        () => ensureEphemerisRangeInstalled(range),
        throwsA(isA<EphemerisAssetException>()),
      );
    });

    test('rejects a range that stops short', () {
      final range = EphemerisDataRange(
        planets: file(0, kEphemerisExpectedStartYear, 2398),
        moon: file(1, kEphemerisExpectedStartYear, kEphemerisExpectedEndYear),
      );

      expect(
        () => ensureEphemerisRangeInstalled(range),
        throwsA(isA<EphemerisAssetException>()),
      );
    });
  });
}

EphemerisEngineException _captureEngineError(void Function() body) {
  try {
    body();
  } on EphemerisEngineException catch (error) {
    return error;
  }
  fail('Expected an EphemerisEngineException');
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

/// Flips one byte deep in the body, keeping the size and the header intact.
Uint8List _corrupt(Uint8List bytes) {
  final copy = Uint8List.fromList(bytes);
  final index = copy.length ~/ 2;
  copy[index] = copy[index] ^ 0xFF;
  return copy;
}

String _sha256(Uint8List bytes) => sha256.convert(bytes).toString();

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
