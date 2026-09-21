import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/calendar/calendar_guards.dart';
import '../../../providers/calendar_provider.dart';
import '../../../services/bengali_calendar_service.dart';

// Phase 5a: hero provider extracted from widgets/paksha_hero_card.dart.
// Name unchanged; the widget re-exports.

/// Bengali date for the hero header. Only resolves when Bengali is the
/// primary or secondary calendar system; null otherwise (and on failure),
/// in which case the hero falls back to its Hindu/Gregorian rendering —
/// same guarded pattern as the schedule view.
final bengaliDateForHeroProvider = FutureProvider.autoDispose
    .family<({int day, String month, int year})?, DateTime>((ref, date) async {
      if (!showsCalendarSystem(ref, AppCalendarSystem.bengali)) return null;
      return guarded(
        () => ref.read(bengaliCalendarServiceProvider).calculateDate(date),
      );
    });
