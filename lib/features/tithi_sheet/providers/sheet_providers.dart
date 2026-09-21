import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/calendar/calendar_guards.dart';
import '../../../core/locale/app_locale.dart';
import '../../../l10n/app_localizations.dart';
import '../../../models/hindu_month_system.dart';
import '../../../providers/calendar_provider.dart';
import '../../../providers/locale_provider.dart';
import '../../../services/bengali_calendar/bengali_calendar_data.dart';
import '../../../services/bengali_calendar_service.dart';
import '../../../services/hindu_calendar_service.dart';
import '../../../utils/tithi_localization.dart';

// Phase 5a: tithi-sheet providers extracted from
// widgets/tithi_detail_sheet.dart. Names unchanged; the widget re-exports.

/// Bengali date for the sheet header. Only resolves when Bengali is the
/// primary calendar; null otherwise (and on failure) — same guarded pattern
/// as the schedule view and the home hero.
final bengaliDateForSheetProvider = FutureProvider.autoDispose
    .family<({int day, String month, int year})?, DateTime>((ref, date) async {
      if (!isPrimarySystem(ref, AppCalendarSystem.bengali)) return null;
      return guarded(
        () => ref.read(bengaliCalendarServiceProvider).calculateDate(date),
      );
    });

/// Hindu date label for a timing instant: Purnimant-correct masa + the exact
/// tithi that instant belongs to (passed in — the service is only queried
/// for the masa, so month boundaries stay correct). Resolves only when Hindu
/// is the primary calendar; null otherwise (and on failure), in which case
/// callers fall back to the Gregorian date.
final hinduInstantLabelProvider = FutureProvider.autoDispose
    .family<String?, ({DateTime instant, int tithiIndex})>((ref, arg) async {
      if (!isPrimarySystem(ref, AppCalendarSystem.hindu)) return null;
      try {
        final service = ref.read(hinduCalendarServiceProvider);
        final monthSystem = ref.watch(hinduMonthSystemProvider);
        final locale = resolveAppLocale(ref.watch(localeProvider));
        final l10n = await AppLocalizations.delegate.load(locale);
        final hDate = await service.calculateDate(arg.instant);
        final paksha = arg.tithiIndex <= 15 ? 'Shukla' : 'Krishna';
        final num = arg.tithiIndex <= 15 ? arg.tithiIndex : arg.tithiIndex - 15;
        final masa = localizedHinduMonthName(
          displayMasaName(hDate.masa, paksha, monthSystem).replaceAll('_', ' '),
          l10n,
        );
        return '$masa ${localizedTithiName(num, paksha, l10n)}';
      } catch (_) {
        return null;
      }
    });

/// Bengali date label for a timing instant, honoring the app-language script
/// rule. Resolves only when Bengali is the primary calendar; null otherwise
/// (and on failure).
final bengaliInstantLabelProvider = FutureProvider.autoDispose
    .family<String?, DateTime>((ref, instant) async {
      if (!isPrimarySystem(ref, AppCalendarSystem.bengali)) return null;
      try {
        final b = await ref
            .read(bengaliCalendarServiceProvider)
            .calculateDate(instant);
        final useBn = resolveAppLocale(ref.watch(localeProvider)).languageCode == 'bn';
        if (useBn) {
          final idx = bengaliMonthIndexOf(b.month);
          final monthBn = idx >= 0 ? kBengaliMonthsBn[idx] : b.month;
          return '${toBengaliDigits(b.day)} $monthBn ${toBengaliDigits(b.year)}';
        }
        return '${b.day} ${b.month} ${b.year}';
      } catch (_) {
        return null;
      }
    });

/// Primary-calendar date label for a timing instant (Hindu else Bengali),
/// null while resolving or when Gregorian is primary. Single subscription
/// node: replaces the per-call double watch (Hindu + Bengali) previously
/// done by the sheet's `_instantValue` helper, and Riverpod memoizes repeat
/// instants (transition sublines reuse the same times as the cards).
/// Exactly one branch can be non-null (only one system is primary), so the
/// sequential resolve matches the old concurrent read.
final instantPrimaryLabelProvider = FutureProvider.autoDispose
    .family<String?, ({DateTime instant, int tithiIndex})>((ref, arg) async {
      final hindu = await ref.watch(
        hinduInstantLabelProvider((
          instant: arg.instant,
          tithiIndex: arg.tithiIndex,
        )).future,
      );
      if (hindu != null) return hindu;
      return ref.watch(bengaliInstantLabelProvider(arg.instant).future);
    });

/// Hindu era year for the sheet's primary-calendar date line. Only resolves
/// when Hindu is the primary calendar; null otherwise (and on failure), in
/// which case the date line omits the year.
final hinduYearForSheetProvider = FutureProvider.autoDispose
    .family<({int year, String eraLabel})?, DateTime>((ref, date) async {
      if (!isPrimarySystem(ref, AppCalendarSystem.hindu)) return null;
      try {
        final service = ref.read(hinduCalendarServiceProvider);
        final yearEra = ref.watch(hinduYearEraProvider);
        final hDate = await service.calculateDate(date);
        return (
          year: yearEra == HinduYearEra.vikramSamvat
              ? hDate.vsYear
              : hDate.shakaYear,
          eraLabel: yearEra.shortLabel,
        );
      } catch (_) {
        return null;
      }
    });
