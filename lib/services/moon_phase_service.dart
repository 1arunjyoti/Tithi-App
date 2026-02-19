import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'panchang_service.dart';
import '../providers/panchang_provider.dart';

/// Provider for MoonPhaseService
final moonPhaseServiceProvider = Provider<MoonPhaseService>((ref) {
  return MoonPhaseService(ref.watch(panchangServiceProvider));
});

/// Data class representing moon phase information
class MoonPhaseData {
  const MoonPhaseData({
    required this.nextAmavasya,
    required this.nextPurnima,
    required this.currentTithi,
    required this.isShukla,
  });

  final DateTime nextAmavasya;
  final DateTime nextPurnima;
  final double currentTithi;
  final bool isShukla;

  /// Returns countdown to Amavasya
  Duration get amavasyaCountdown => nextAmavasya.difference(DateTime.now());

  /// Returns countdown to Purnima
  Duration get purnimaCountdown => nextPurnima.difference(DateTime.now());

  /// Returns the nearest moon event (Amavasya or Purnima)
  bool get isAmavasyaNearer =>
      amavasyaCountdown.inSeconds.abs() < purnimaCountdown.inSeconds.abs();
}

/// Service for calculating moon phase information
/// Uses existing PanchangService for tithi calculations
class MoonPhaseService {
  MoonPhaseService(this._panchangService);

  final PanchangService _panchangService;

  /// Gets current moon phase data including next Amavasya and Purnima dates
  Future<MoonPhaseData> getMoonPhaseData({
    double latitude = 28.6139,
    double longitude = 77.2090,
  }) async {
    // Ensure PanchangService is initialized before use
    await _panchangService.init();

    final now = DateTime.now();

    // Get current tithi
    final currentTithi = await _panchangService.calculateTithi(
      now,
      latitude: latitude,
      longitude: longitude,
    );

    final isShukla = currentTithi <= 15;

    // Find next Amavasya and Purnima
    final nextAmavasya = await _findNextMoonPhase(
      targetTithi: 30, // Amavasya is tithi 30
      startDate: now,
      latitude: latitude,
      longitude: longitude,
    );

    final nextPurnima = await _findNextMoonPhase(
      targetTithi: 15, // Purnima is tithi 15
      startDate: now,
      latitude: latitude,
      longitude: longitude,
    );

    return MoonPhaseData(
      nextAmavasya: nextAmavasya,
      nextPurnima: nextPurnima,
      currentTithi: currentTithi,
      isShukla: isShukla,
    );
  }

  /// Finds the next occurrence of a specific tithi (15 for Purnima, 30 for Amavasya)
  Future<DateTime> _findNextMoonPhase({
    required int targetTithi,
    required DateTime startDate,
    double latitude = 28.6139,
    double longitude = 77.2090,
  }) async {
    // Get current tithi to estimate days until target
    final currentTithi = await _panchangService.calculateTithi(
      startDate,
      latitude: latitude,
      longitude: longitude,
    );

    // Estimate days until target tithi
    // Lunar month is ~29.5 days, so each tithi is ~0.98 days
    int estimatedDays;
    if (targetTithi == 15) {
      // Looking for Purnima
      if (currentTithi < 15) {
        estimatedDays = ((15 - currentTithi) * 0.98).ceil();
      } else {
        // Already past this Purnima, find next one (~29.5 days later)
        estimatedDays = ((30 - currentTithi + 15) * 0.98).ceil();
      }
    } else {
      // Looking for Amavasya (tithi 30/1)
      if (currentTithi < 30) {
        estimatedDays = ((30 - currentTithi) * 0.98).ceil();
      } else {
        // Very rare case where we're exactly at 30
        estimatedDays = 0;
      }
    }

    // Search from estimated date with a window
    var searchDate = startDate.add(Duration(days: estimatedDays - 2));
    if (searchDate.isBefore(startDate)) {
      searchDate = startDate;
    }

    // Binary search refinement: first find the day
    DateTime? foundDate;
    for (int i = 0; i < 35; i++) {
      final checkDate = searchDate.add(Duration(days: i));
      final tithi = await _panchangService.calculateTithi(
        DateTime(checkDate.year, checkDate.month, checkDate.day, 6),
        latitude: latitude,
        longitude: longitude,
      );

      final tithiIndex = tithi.floor();

      // Check if we've hit the target
      if (targetTithi == 30) {
        // Amavasya is when tithi transitions from 30 to 1
        if (tithiIndex >= 29 || tithiIndex == 30) {
          foundDate = checkDate;
          break;
        }
      } else if (targetTithi == 15) {
        // Purnima is tithi 15
        if (tithiIndex == 15) {
          foundDate = checkDate;
          break;
        }
      }
    }

    // Refine to find exact time (within the day)
    if (foundDate != null) {
      return await _refineExactTime(
        targetTithi: targetTithi,
        approximateDate: foundDate,
        latitude: latitude,
        longitude: longitude,
      );
    }

    // Fallback: return estimate
    return startDate.add(Duration(days: estimatedDays));
  }

  /// Refines the exact time of moon phase using binary search
  Future<DateTime> _refineExactTime({
    required int targetTithi,
    required DateTime approximateDate,
    double latitude = 28.6139,
    double longitude = 77.2090,
  }) async {
    // Search within 48 hours window
    var startTime = approximateDate.subtract(const Duration(hours: 24));
    var endTime = approximateDate.add(const Duration(hours: 24));

    // Binary search for exact transition
    for (int i = 0; i < 8; i++) {
      final midTime = startTime.add(
        Duration(
          milliseconds: endTime.difference(startTime).inMilliseconds ~/ 2,
        ),
      );

      final tithi = await _panchangService.calculateTithi(
        midTime,
        latitude: latitude,
        longitude: longitude,
      );

      final tithiIndex = tithi.floor();

      if (targetTithi == 30) {
        // Before Amavasya, tithi < 30; at Amavasya, tithi >= 30 (or wraps to 1)
        if (tithiIndex >= 29) {
          endTime = midTime;
        } else {
          startTime = midTime;
        }
      } else if (targetTithi == 15) {
        // Before Purnima, tithi < 15; at Purnima, tithi = 15
        if (tithiIndex >= 15) {
          endTime = midTime;
        } else {
          startTime = midTime;
        }
      }
    }

    return startTime;
  }

  /// Gets a list of upcoming Amavasya dates
  Future<List<DateTime>> getUpcomingAmavasyas({
    int count = 6,
    double latitude = 28.6139,
    double longitude = 77.2090,
  }) async {
    final dates = <DateTime>[];
    var searchFrom = DateTime.now();

    for (int i = 0; i < count; i++) {
      final date = await _findNextMoonPhase(
        targetTithi: 30,
        startDate: searchFrom,
        latitude: latitude,
        longitude: longitude,
      );
      dates.add(date);
      searchFrom = date.add(const Duration(days: 2));
    }

    return dates;
  }

  /// Gets a list of upcoming Purnima dates
  Future<List<DateTime>> getUpcomingPurnimas({
    int count = 6,
    double latitude = 28.6139,
    double longitude = 77.2090,
  }) async {
    final dates = <DateTime>[];
    var searchFrom = DateTime.now();

    for (int i = 0; i < count; i++) {
      final date = await _findNextMoonPhase(
        targetTithi: 15,
        startDate: searchFrom,
        latitude: latitude,
        longitude: longitude,
      );
      dates.add(date);
      searchFrom = date.add(const Duration(days: 2));
    }

    return dates;
  }

  /// Calculates moon illumination percentage (0-100)
  /// Based on current tithi
  double getMoonIllumination(double tithi) {
    // Tithi 1-15: waxing (0 to 100%)
    // Tithi 16-30: waning (100 to 0%)
    if (tithi <= 15) {
      return (tithi / 15) * 100;
    } else {
      return ((30 - tithi) / 15) * 100;
    }
  }
}
