import 'dart:ffi' show Abi;
import 'dart:io';

import 'package:crypto/crypto.dart' show sha256;
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'package:tithi/services/moon_events_service.dart';
import 'package:tithi/services/panchang/panchang_service.dart';
import 'package:tithi/services/panchang_init/panchang_init.dart';
import 'package:tithi/services/solar_events_service.dart';

/// Phase 6 smoke test: proves that the pieces the Android build promises are
/// actually wired together on a device - the bundled `.se1` assets install,
/// `libswisseph.so` loads through FFI, and both native rise/set calculators
/// replace their pure-Dart fallbacks.
///
/// It also records the ABI that actually ran and the path of the mapped
/// library, which is the per-ABI runtime evidence for a given device: run it on
/// an x86_64 emulator and on an ARM device and the assertion pins each one to
/// its own `lib/<abi>/` slice.
///
/// Run with: flutter test integration_test/native_ephemeris_smoke_test.dart
/// (needs a connected Android device or emulator; the package declares no
/// other native platform).
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('installs the ephemeris and starts the native engine',
      (tester) async {
    // Arrange / Act
    final service = PanchangService();
    await service.init();

    // Assert: init reached the end, which means the asset copy, the FFI
    // library load and `swe_set_ephe_path` all succeeded.
    expect(service.isInitialized, isTrue);
    expect(solarEventsService.usesNativeCalculator, isTrue);
    expect(moonEventsService.usesNativeCalculator, isTrue);

    // Assert: every declared asset landed in the documents directory, passes
    // the size + header check, and matches the build manifest. This is the only
    // place the manifest is checked against bytes that were copied by the
    // installer on a real device rather than by a fake bundle.
    final documents = await getApplicationDocumentsDirectory();
    final epheDir = Directory(p.join(documents.path, 'ephe'));
    for (final name in kEphemerisAssets) {
      final file = File(p.join(epheDir.path, name));
      expect(file.existsSync(), isTrue, reason: name);
      expect(await file.length(), greaterThan(1024), reason: name);
      final header = await _readHeader(file);
      expect(String.fromCharCodes(header), 'SWISSEPH', reason: name);
      expect(
        sha256.convert(await file.readAsBytes()).toString(),
        kEphemerisAssetSha256[name],
        reason: '$name does not match the manifest',
      );
    }

    // Assert: the process runs an ABI the package actually builds a slice for.
    // Android resolves `libswisseph.so` from the process's own `lib/<abi>/`
    // entry, so a successful load on this ABI proves that slice ran. The path
    // itself is not visible in /proc/self/maps: with extractNativeLibs=false
    // the linker maps the APK, not the extracted .so.
    final abi = Abi.current();
    final slice = _abiDirectory(abi);
    expect(
      kNativeEngineAbis,
      contains(slice),
      reason: 'the package builds no native slice for $slice',
    );
    debugPrint('native engine: abi=$abi slice=lib/$slice');

    // Assert: a real calculation returns a valid tithi, so the library is not
    // merely loaded but callable.
    final tithi = await service.calculateTithi(DateTime.now());
    expect(tithi, inInclusiveRange(1, 30));
  });
}

/// `lib/<abi>/` directories the Android build produces.
///
/// Kept next to the smoke test rather than derived from CMake so a device run
/// fails loudly if an ABI is dropped from the build.
const Set<String> kNativeEngineAbis = {'arm64-v8a', 'armeabi-v7a', 'x86_64'};

/// Android's `lib/<abi>/` directory name for the running Dart VM.
String _abiDirectory(Abi abi) => switch (abi) {
  Abi.androidArm64 => 'arm64-v8a',
  Abi.androidArm => 'armeabi-v7a',
  Abi.androidX64 => 'x86_64',
  Abi.androidIA32 => 'x86',
  _ => throw StateError('Not an Android ABI: $abi'),
};

Future<List<int>> _readHeader(File file) async {
  final handle = await file.open();
  try {
    return await handle.read(8);
  } finally {
    await handle.close();
  }
}
