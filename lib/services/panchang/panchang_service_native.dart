import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:jyotish/jyotish.dart';
import '../../models/festival.dart';
import '../panchang_init/panchang_init.dart';

/// Native (mobile/desktop) implementation of PanchangService
/// Uses FFI-based Swiss Ephemeris for accurate calculations
class PanchangService {
  PanchangService();

  bool _isInitialized = false;
  String? _ephePath;

  /// Cache for tithi calculations (key: date_lat_lon)
  final Map<String, double> _tithiCache = {};

  bool get isInitialized => _isInitialized;

  bool get hasFullSupport => _isInitialized;

  Future<void> init() async {
    if (_isInitialized) return;

    try {
      // Copy ephemeris files and initialize
      _ephePath = await copyEphemerisFiles(rootBundle);

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

  Future<double> calculateTithi(
    DateTime date, {
    double latitude = 28.6139,
    double longitude = 77.2090,
  }) async {
    if (!_isInitialized) {
      throw Exception("PanchangService not initialized.");
    }

    // Generate cache key
    final cacheKey =
        '${date.millisecondsSinceEpoch}_${latitude.toStringAsFixed(4)}_${longitude.toStringAsFixed(4)}';

    // Check cache first
    if (_tithiCache.containsKey(cacheKey)) {
      return _tithiCache[cacheKey]!;
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

    // Store in cache
    _tithiCache[cacheKey] = tithi;

    return tithi;
  }

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
    double lng = sun.longitude;

    // Normalize
    while (lng < 0) {
      lng += 360;
    }
    while (lng >= 360) {
      lng -= 360;
    }

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

  Future<DateTime?> findNextFestivalOccurrence(
    Festival festival, {
    DateTime? startDate,
    double latitude = 28.6139,
    double longitude = 77.2090,
  }) async {
    final baseDate = startDate ?? DateTime.now();
    var date = _estimateFestivalSearchStart(baseDate, festival);

    if (date.isBefore(baseDate)) {
      date = baseDate;
    }

    // Limit search to ~380 days
    for (int i = 0; i < 380; i++) {
      final checkDate = DateTime(date.year, date.month, date.day, 6);

      final rawTithi = await calculateTithi(
        checkDate,
        latitude: latitude,
        longitude: longitude,
      );

      final tithiIndex = rawTithi.floor();
      String paksha;
      int tithiNumber;
      if (tithiIndex <= 15) {
        paksha = 'Shukla';
        tithiNumber = tithiIndex;
      } else {
        paksha = 'Krishna';
        tithiNumber = tithiIndex - 15;
      }

      final masa = await calculateMasa(
        checkDate,
        rawTithi,
        latitude: latitude,
        longitude: longitude,
      );

      if (festival.matchesTithi(paksha, tithiNumber, masa)) {
        return date;
      }

      date = date.add(const Duration(days: 1));
    }

    // Fallback: full brute-force from base date if heuristic window missed
    date = baseDate;
    for (int i = 0; i < 380; i++) {
      final checkDate = DateTime(date.year, date.month, date.day, 6);

      final rawTithi = await calculateTithi(
        checkDate,
        latitude: latitude,
        longitude: longitude,
      );

      final tithiIndex = rawTithi.floor();
      String paksha;
      int tithiNumber;
      if (tithiIndex <= 15) {
        paksha = 'Shukla';
        tithiNumber = tithiIndex;
      } else {
        paksha = 'Krishna';
        tithiNumber = tithiIndex - 15;
      }

      final masa = await calculateMasa(
        checkDate,
        rawTithi,
        latitude: latitude,
        longitude: longitude,
      );

      if (festival.matchesTithi(paksha, tithiNumber, masa)) {
        return date;
      }

      date = date.add(const Duration(days: 1));
    }

    return null;
  }

  DateTime _estimateFestivalSearchStart(DateTime from, Festival festival) {
    final masa = festival.panchangRules.masa;
    if (masa.isEmpty || masa == '*') {
      return from;
    }

    const approxMonth = {
      'Chaitra': 3,
      'Vaishakha': 4,
      'Jyeshtha': 5,
      'Ashadha': 6,
      'Shravana': 7,
      'Bhadrapada': 8,
      'Ashwin': 9,
      'Kartika': 10,
      'Margashirsha': 11,
      'Pausha': 12,
      'Magha': 1,
      'Phalguna': 2,
    };

    final targetMonth = approxMonth[masa];
    if (targetMonth == null) return from;

    var year = from.year;
    if (targetMonth < from.month - 1) {
      year += 1;
    }

    return DateTime(year, targetMonth);
  }
}
