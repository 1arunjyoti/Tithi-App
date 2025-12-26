// ignore_for_file: avoid_print

import 'package:flutter_test/flutter_test.dart';
import 'package:tithi/services/panchang_service.dart';

void main() {
  testWidgets('PanchangService Verification', (WidgetTester tester) async {
    // Ensure binding is initialized for path_provider (mocking might be needed if it fails)
    TestWidgetsFlutterBinding.ensureInitialized();

    final service = PanchangService();

    // We need to properly initialize.
    // Since init() copies files from assets, we need to mock rootBundle or ensure assets are available.
    // In a widget test, assets usually work if declared in pubspec.

    print("Initializing service...");
    await service.init();

    final now = DateTime.now();
    print("Calculating Tithi for $now...");

    try {
      final tithi = await service.calculateTithi(now);
      print("Calculated Tithi: $tithi");

      final tithiIndex = tithi.floor();
      final paksha = tithiIndex <= 15 ? "Shukla" : "Krishna";
      final displayName = tithiIndex <= 15
          ? 'Tithi $tithiIndex'
          : 'Tithi ${tithiIndex - 15}';

      print("Result: $paksha Paksha, $displayName");

      expect(tithi, greaterThan(0));
      expect(tithi, lessThanOrEqualTo(31)); // Small buffer
    } catch (e) {
      print("Error: $e");
      rethrow;
    }
  });
}
