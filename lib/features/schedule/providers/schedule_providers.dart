import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/calendar/calendar_guards.dart';
import '../../../models/hindu_month_system.dart';
import '../../../models/panchang_data.dart';
import '../../../providers/calendar_provider.dart' as cp;
import '../../../providers/panchang_provider.dart';
import '../../../services/bengali_calendar_service.dart';
import '../../../services/hindu_calendar_service.dart';

// Phase 5a: schedule-view providers extracted from
// widgets/schedule_view_widget.dart. Names unchanged; the widget re-exports.

/// Data class for Hindu date with proper settings applied
class HinduDateData {
  final int day; // tithi number
  final String month; // masa name (with month system applied)
  final String paksha;
  final int year; // year in selected era
  final String eraLabel; // "Vikram" or "Shaka"

  HinduDateData({
    required this.day,
    required this.month,
    required this.paksha,
    required this.year,
    required this.eraLabel,
  });
}

class ScheduleDateData {
  final PanchangData panchang;
  final ({int day, String month, int year})? bengaliDate;
  final HinduDateData? hinduDate;

  const ScheduleDateData({
    required this.panchang,
    required this.bengaliDate,
    required this.hinduDate,
  });
}

/// Provider for Hindu date with settings applied
final hinduDateForScheduleProvider = FutureProvider.autoDispose
    .family<HinduDateData?, DateTime>((ref, date) async {
      // Only calculate if Hindu is primary or secondary
      if (!showsCalendarSystem(ref, cp.AppCalendarSystem.hindu)) return null;

      try {
        final service = ref.read(hinduCalendarServiceProvider);
        final monthSystem = ref.watch(cp.hinduMonthSystemProvider);
        final yearEra = ref.watch(cp.hinduYearEraProvider);

        final hDate = await service.calculateDate(date);

        // Apply display mode (paksha-based 1-15 or continuous 1-30)
        final displayMode = ref.watch(cp.tithiDisplayModeProvider);
        final displayTithi = displayMode == cp.TithiDisplayMode.continuous30
            ? hDate.fullTithi
            : hDate.tithi;

        // Apply month system conversion if needed
        String masa = displayMasaName(hDate.masa, hDate.paksha, monthSystem);
        // Replace underscores with spaces for display (e.g. 'Adhika_Jyeshtha' -> 'Adhika Jyeshtha')
        masa = masa.replaceAll('_', ' ');

        // Get year based on era selection
        final year = yearEra == HinduYearEra.vikramSamvat
            ? hDate.vsYear
            : hDate.shakaYear;
        final eraLabel = yearEra.shortLabel;

        return HinduDateData(
          day: displayTithi,
          month: masa,
          paksha: hDate.paksha,
          year: year,
          eraLabel: eraLabel,
        );
      } catch (_) {
        return null;
      }
    });

/// Provider for Bengali date for a specific date
final bengaliDateForScheduleProvider = FutureProvider.autoDispose
    .family<({int day, String month, int year})?, DateTime>((ref, date) async {
      // Only calculate if Bengali is primary or secondary
      if (!showsCalendarSystem(ref, cp.AppCalendarSystem.bengali)) return null;
      return guarded(
        () => ref.read(bengaliCalendarServiceProvider).calculateDate(date),
      );
    });

final scheduleDateDataProvider = FutureProvider.autoDispose
    .family<ScheduleDateData, DateTime>((ref, date) async {
      final panchang = await ref.watch(panchangForDateProvider(date).future);

      final results = await Future.wait<Object?>([
        ref.watch(bengaliDateForScheduleProvider(date).future),
        ref.watch(hinduDateForScheduleProvider(date).future),
      ]);

      return ScheduleDateData(
        panchang: panchang,
        bengaliDate: results[0] as ({int day, String month, int year})?,
        hinduDate: results[1] as HinduDateData?,
      );
    });
