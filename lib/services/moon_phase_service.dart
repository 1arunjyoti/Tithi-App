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

    // Estimate days until target tithi peak
    // Lunar month is ~29.5 days, so each tithi is ~0.98 days
    // Purnima peak is exactly tithi 16.0. Amavasya peak is exactly tithi 31.0 (wraps to 1.0).
    int estimatedDays;
    if (targetTithi == 15) {
      // Looking for Purnima (peak 16.0)
      if (currentTithi < 16.0) {
        estimatedDays = ((16.0 - currentTithi) * 0.98).ceil();
      } else {
        // Already past this Purnima, find next one (~29.5 days later)
        estimatedDays = ((31.0 - currentTithi + 15.0) * 0.98).ceil();
      }
    } else {
      // Looking for Amavasya (peak 31.0)
      estimatedDays = ((31.0 - currentTithi) * 0.98).ceil();
      if (estimatedDays < 0) estimatedDays = 0;
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
        // Amavasya peak is when tithi reaches 31.0 (wraps to 1.0)
        if (tithiIndex == 30 || tithiIndex == 1) {
          foundDate = checkDate;
          break;
        }
      } else if (targetTithi == 15) {
        // Purnima peak is exactly tithi 16.0
        if (tithiIndex == 15 || tithiIndex == 16) {
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
    // Search within 96 hours window to ensure we encompass the exact peak
    var startTime = approximateDate.subtract(const Duration(hours: 48));
    var endTime = approximateDate.add(const Duration(hours: 48));

    // Binary search for exact transition (15 iterations for minute-level precision)
    for (int i = 0; i < 15; i++) {
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

      if (targetTithi == 30) {
        // Amavasya peak is exactly 31.0/1.0.
        // If tithi < 15.0, we've wrapped past 31.0 to 1.x, so we passed the peak.
        if (tithi < 15.0) {
          endTime = midTime;
        } else {
          startTime = midTime;
        }
      } else if (targetTithi == 15) {
        // Purnima peak is exactly 16.0.
        if (tithi >= 16.0) {
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
    int count = 15, // 15 phases guarantees > 12 months coverage
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
    int count = 15, // 15 phases guarantees > 12 months coverage
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
  double getMoonIllumination(double tithi) => illuminationForTithi(tithi);

  /// Static illumination curve shared by [getMoonIllumination].
  /// Tithi is from 1.0 to 31.0.
  /// Peak Amavasya (0%) is at 1.0 (and 31.0).
  /// Peak Purnima (100%) is at 16.0.
  static double illuminationForTithi(double tithi) {
    if (tithi <= 16.0) {
      // Waxing: 1.0 is 0%, 16.0 is 100%
      return ((tithi - 1.0) / 15.0) * 100.0;
    } else {
      // Waning: 16.0 is 100%, 31.0 is 0%
      return ((31.0 - tithi) / 15.0) * 100.0;
    }
  }

  /// Lit fraction 0.0-1.0 for [MoonPhasePainter] from a day's panchang data.
  ///
  /// Prefers the fractional sunrise [rawTithi] (astronomically exact for that
  /// moment, monotonic across the new-moon boundary). Falls back to a
  /// mid-tithi estimate when it is missing or garbage.
  ///
  /// The painter reads `phase` as a lit fraction (0 = new, 1 = full) and
  /// handles waxing/waning purely via its side flag — so a linear
  /// day-count mapping like `(tithi - 1) / 30` is wrong here (it renders
  /// Amavasya as nearly full and Purnima as half). Sampling at tithi *start*
  /// is also wrong: Amavasya day (30 → 6.7%) would read brighter than the
  /// following Pratipada (1 → 0%), straddling the true minimum (31.0).
  static double illuminationFractionForDay({
    required int tithiNumber,
    required bool isShukla,
    double? rawTithi,
  }) {
    final normalized = _normalizeRawTithi(rawTithi);
    if (normalized != null) {
      return (illuminationForTithi(normalized) / 100.0).clamp(0.0, 1.0);
    }
    // Mid-tithi estimate: symmetric across the 31.0 minimum
    // (Krishna 15 and Shukla 1 both read 3.3%).
    final continuous =
        (isShukla ? tithiNumber : 15 + tithiNumber).toDouble() + 0.5;
    return (illuminationForTithi(continuous) / 100.0).clamp(0.0, 1.0);
  }

  /// Normalizes a fractional sunrise tithi into [1, 31]. The web fallback
  /// wraps (30, 31] into (0, 1] (late Amavasya), which is shifted back.
  /// Returns null for missing or out-of-range input.
  static double? _normalizeRawTithi(double? raw) {
    if (raw == null || raw.isNaN || raw.isInfinite || raw <= 0) return null;
    final t = raw < 1 ? raw + 30 : raw;
    if (t < 1 || t > 31) return null;
    return t;
  }
}
