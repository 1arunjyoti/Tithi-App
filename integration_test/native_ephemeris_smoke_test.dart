import 'dart:io';

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

    // Assert: every declared asset landed in the documents directory and
    // passes the same size + header check the installer uses.
    final documents = await getApplicationDocumentsDirectory();
    final epheDir = Directory(p.join(documents.path, 'ephe'));
    for (final name in kEphemerisAssets) {
      final file = File(p.join(epheDir.path, name));
      expect(file.existsSync(), isTrue, reason: name);
      expect(await file.length(), greaterThan(1024), reason: name);
      final header = await _readHeader(file);
      expect(String.fromCharCodes(header), 'SWISSEPH', reason: name);
    }

    // Assert: a real calculation returns a valid tithi, so the library is not
    // merely loaded but callable.
    final tithi = await service.calculateTithi(DateTime.now());
    expect(tithi, inInclusiveRange(1, 30));
  });
}

Future<List<int>> _readHeader(File file) async {
  final handle = await file.open();
  try {
    return await handle.read(8);
  } finally {
    await handle.close();
  }
}
