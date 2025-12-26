import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:jyotish/jyotish.dart';
import 'package:path/path.dart' as p;

// Provider for PanchangService
final panchangServiceProvider = Provider<PanchangService>((ref) {
  return PanchangService();
});

class PanchangService {
  PanchangService();

  bool _isInitialized = false;
  String? _ephePath;

  Future<void> init() async {
    if (_isInitialized) return;

    try {
      final appDir = await getApplicationDocumentsDirectory();
      final epheDir = Directory(p.join(appDir.path, 'ephe'));

      if (!await epheDir.exists()) {
        await epheDir.create(recursive: true);
      }

      _ephePath = epheDir.path;

      // List of ephemeris files to copy
      final files = ['seas_18.se1', 'semo_18.se1', 'sepl_18.se1'];

      for (final file in files) {
        final targetFile = File(p.join(epheDir.path, file));
        // Check if file exists to avoid copying every time (optional optimization)
        // For now, we can overwrite or check size. Let's just copy if not exists.
        if (!await targetFile.exists()) {
          final data = await rootBundle.load('assets/ephe/$file');
          final bytes = data.buffer.asUint8List(
            data.offsetInBytes,
            data.lengthInBytes,
          );
          await targetFile.writeAsBytes(bytes);
        }
      }

      // Initialize Jyotish/SwissEph with the path
      await Jyotish().initialize(ephemerisPath: _ephePath);

      if (kDebugMode) {
        print("Swiss Ephemeris files copied to $_ephePath");
      }

      _isInitialized = true;
    } catch (e) {
      if (kDebugMode) {
        print("Error initializing PanchangService: $e");
      }
      rethrow;
    }
  }

  /// Calculates the Tithi for a given date.
  /// Returns a value between 1 and 30.
  /// 1-15: Shukla Paksha (Waxing)
  /// 16-30: Krishna Paksha (Waning)
  ///
  /// Location defaults to Delhi, India (28.6139°N, 77.2090°E)
  Future<double> calculateTithi(
    DateTime date, {
    double latitude = 28.6139,
    double longitude = 77.2090,
  }) async {
    if (!_isInitialized) {
      throw Exception("PanchangService not initialized.");
    }

    final location = GeographicLocation(
      latitude: latitude,
      longitude: longitude,
    );

    final sun = await Jyotish().getPlanetPosition(
      planet: Planet.sun,
      dateTime: date,
      location: location,
    );
    final moon = await Jyotish().getPlanetPosition(
      planet: Planet.moon,
      dateTime: date,
      location: location,
    );

    double diff = moon.longitude - sun.longitude;
    if (diff < 0) {
      diff += 360;
    }

    // Tithi = diff / 12
    // We add 1 because Tithi starts from 1, not 0.
    final tithi = (diff / 12) + 1;
    return tithi;
  }

  /// Calculates the Hindu Month (Masa) based on Sun's sidereal longitude
  /// at the time of the previous New Moon (Amanta system).
  Future<String> calculateMasa(
    DateTime date,
    double rawTithi, {
    double latitude = 28.6139,
    double longitude = 77.2090,
  }) async {
    if (!_isInitialized) {
      throw Exception("PanchangService not initialized.");
    }

    // Calculate days since last New Moon (Amavasya)
    // Relative speed of Moon vs Sun is ~12.19074 degrees/day
    // diff = (rawTithi - 1) * 12
    final diffDegrees = (rawTithi - 1) * 12;
    final daysSinceNewMoon = diffDegrees / 12.19074;

    // Estimate date of previous New Moon
    final newMoonDate = date.subtract(
      Duration(minutes: (daysSinceNewMoon * 1440).round()),
    );

    final location = GeographicLocation(
      latitude: latitude,
      longitude: longitude,
    );

    // Get Sun's position at New Moon
    final sun = await Jyotish().getPlanetPosition(
      planet: Planet.sun,
      dateTime: newMoonDate,
      location: location,
    );

    // Map Sun's sidereal longitude to Hindu Month (Amanta)
    // 330-360: Pisces (Meena) -> Chaitra
    // 0-30:   Aries (Mesha) -> Vaishakha
    // ...
    double lng = sun.longitude;

    // Normalize
    while (lng < 0) {
      lng += 360;
    }
    while (lng >= 360) {
      lng -= 360;
    }

    // Index 0 = Vaishakha (Aries starts), but Chaitra is Pisces (Index 11)
    // Aries (0-30) is Index 0
    final index = (lng / 30).floor();

    const masas = [
      'Vaishakha', // 0-30 Aries
      'Jyeshtha', // 30-60 Taurus
      'Ashadha', // 60-90 Gemini
      'Shravana', // 90-120 Cancer
      'Bhadrapada', // 120-150 Leo
      'Ashwin', // 150-180 Virgo
      'Kartika', // 180-210 Libra
      'Margashirsha', // 210-240 Scorpio
      'Pausha', // 240-270 Sagittarius
      'Magha', // 270-300 Capricorn
      'Phalguna', // 300-330 Aquarius
      'Chaitra', // 330-360 Pisces
    ];

    if (index >= 0 && index < masas.length) {
      return masas[index];
    }
    return 'Unknown';
  }
}
