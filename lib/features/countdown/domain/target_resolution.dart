import 'package:flutter/foundation.dart';

import '../../../models/festival.dart';
import '../../../models/hindu_month_system.dart';
import '../../../services/panchang_service.dart';
import '../../panchang/domain/occurrence_cache.dart';

// Shared "N festivals -> dated targets" resolution used by the countdown
// providers, the all-festivals screen, search, and export. Previously each
// implemented its own forward-scan loop; all now funnel through the
// occurrence-result cache ([findNextFestivalOccurrenceCached]) plus the
// helpers below, so a scan computed anywhere serves everywhere.

/// One festival with its next occurrence date (null when no occurrence
/// resolves inside the forward window — those sort last, undated).
typedef DatedFestival = ({Festival festival, DateTime? date});

/// Chronological order for dated festival lists: ascending next-occurrence
/// date (name breaks ties), undatable entries last by name.
List<DatedFestival> sortDatedFestivals(List<DatedFestival> items) {
  final sorted = items.toList();
  sorted.sort((a, b) {
    if (a.date == null && b.date == null) {
      return a.festival.name.compareTo(b.festival.name);
    }
    if (a.date == null) return 1;
    if (b.date == null) return -1;
    final byDate = a.date!.compareTo(b.date!);
    if (byDate != 0) return byDate;
    return a.festival.name.compareTo(b.festival.name);
  });
  return sorted;
}

/// One festival's next occurrence on/after [baseDate] (date-only), or null
/// on failure. One bad rule never fails the caller — it resolves dateless.
///
/// Resolution is ALWAYS Amanta-based: festival rules are stored in Amanta
/// and both scanners match with [HinduMonthSystem.amanta] hardcoded, so the
/// display system must not enter the cache key (it did before occ7, causing
/// a full re-scan of every festival on each Amanta↔Purnimant toggle for zero
/// new information). Callers needing the user's system for *labels* (e.g.
/// export's masaDisplay) keep it separately — it never affects dates.
Future<DateTime?> resolveOccurrenceDate({
  required PanchangService service,
  required Festival festival,
  required DateTime baseDate,
  required double latitude,
  required double longitude,
}) async {
  try {
    return await findNextFestivalOccurrenceCached(
      service: service,
      festival: festival,
      startDate: baseDate,
      latitude: latitude,
      longitude: longitude,
      monthSystem: HinduMonthSystem.amanta,
    );
  } catch (e) {
    // One bad rule must not fail the whole list; log and sort last.
    debugPrint('Occurrence resolve failed for ${festival.id}: $e');
    return null;
  }
}

/// Every festival's next occurrence, sorted ([sortDatedFestivals]).
/// Resolved in small parallel batches: enough parallelism for throughput,
/// small enough to avoid FFI stampedes that jank the UI thread (matches
/// the month batch size). Resolution is Amanta-fixed (see above), so a
/// month-system toggle never re-scans.
Future<List<DatedFestival>> resolveDatedFestivals({
  required PanchangService service,
  required List<Festival> festivals,
  required DateTime baseDate,
  required double latitude,
  required double longitude,
  int batchSize = 8,
}) async {
  Future<DatedFestival> resolve(Festival festival) async {
    final date = await resolveOccurrenceDate(
      service: service,
      festival: festival,
      baseDate: baseDate,
      latitude: latitude,
      longitude: longitude,
    );
    return (festival: festival, date: date);
  }

  final out = <DatedFestival>[];
  for (var i = 0; i < festivals.length; i += batchSize) {
    final end = (i + batchSize).clamp(0, festivals.length);
    final batch = festivals.sublist(i, end);
    out.addAll(await Future.wait(batch.map(resolve)));
  }
  return sortDatedFestivals(out);
}
