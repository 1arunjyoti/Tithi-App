import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart' show Locale;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/format/festival_labels.dart';
import '../core/locale/app_locale.dart';
import '../features/hero/domain/hero_content.dart';
import '../features/hero/providers/hero_providers.dart';
import '../features/home_widget/domain/panchang_widget_payload.dart';
import '../features/sheets/domain/sheet_labels.dart';
import '../l10n/app_localizations.dart';
import '../l10n/app_localizations_bn.dart';
import '../l10n/app_localizations_en.dart';
import '../l10n/app_localizations_hi.dart';
import '../l10n/app_localizations_sa.dart';
import '../models/festival_region.dart';
import '../services/home_widget.dart';
import '../utils/tithi_localization.dart';
import 'calendar_provider.dart';
import 'festival_countdown_provider.dart';
import 'locale_provider.dart';
import 'location_provider.dart';
import 'panchang_provider.dart';

/// Exposes the [HomeWidgetService] as a shared const instance.
/// Const constructor — no per-read allocation, no state to leak.
final homeWidgetServiceProvider = Provider<HomeWidgetService>((ref) {
  return const HomeWidgetService();
});

/// Whether the device supports pinning widgets (Android 8+ with launcher support).
/// keepAlive caches the platform-channel result across navigation so rebuilds
/// don't re-hit the MethodChannel on every card mount.
final homeWidgetPinSupportProvider = FutureProvider<bool>((ref) async {
  ref.keepAlive();
  final service = ref.watch(homeWidgetServiceProvider);
  return service.isRequestPinSupported();
});

/// Whether widgets are supported on this platform at all.
/// Purely synchronous platform check, but kept async for API symmetry.
/// keepAlive avoids re-evaluation on every rebuild.
final homeWidgetSupportedProvider = FutureProvider<bool>((ref) async {
  ref.keepAlive();
  final service = ref.watch(homeWidgetServiceProvider);
  return service.isWidgetSupported();
});

/// Side-effect provider: keeps the home screen widget in sync with ALL
/// festivals on the countdown page.
///
/// Note: this intentionally watches [allFestivalCountdownTargetsProvider],
/// not [homeFestivalCountdownTargetsProvider]. The home-pin (house icon)
/// only controls the in-app home section; the Android widget always shows
/// every countdown.
///
/// The widget theme is NOT synced here — it belongs to the widget itself
/// (configure screen on add, long-press → Reconfigure on API 31+).
///
/// Single-fire design: exactly ONE watch path (no parallel listen+watch),
/// so each data change triggers at most one sync. The service itself
/// dedups identical payloads, making rebuild-driven re-evaluation free
/// (early return before any platform-channel IPC).
///
/// Memory: no Stream/Timer/Controller held; Riverpod disposes the
/// subscription automatically when the last listener unsubscribes. No leak.
final homeWidgetSyncProvider = Provider<void>((ref) {
  final asyncTargets = ref.watch(allFestivalCountdownTargetsProvider);
  // Widget labels follow the app language (see HomeWidgetService): a pure
  // language switch changes no dates, so without this the widget would keep
  // yesterday's language until the next countdown change.
  ref.watch(localeProvider);

  final targets = asyncTargets.valueOrNull;
  if (targets != null) {
    // Fire-and-forget: never block the build phase on IPC. unawaited
    // documents the intentional no-await and satisfies the lint.
    unawaited(
      ref
          .read(homeWidgetServiceProvider)
          .updateFestivalCountdownWidget(targets),
    );
  }
});

/// Side-effect provider: keeps the hero and timing widgets fed with today's
/// panchang and windows.
///
/// Mounted at the app root (not inside the promo card) so the widgets stay
/// fresh even after the user dismisses the home-screen-widget card. The
/// payload includes tomorrow's timings too, letting the native midnight
/// refresh roll over without waiting for the app to run.
///
/// Every string is localized here, at sync time: the native widgets never
/// resolve `AppLocalizations`.
final panchangWidgetSyncProvider = Provider<void>((ref) {
  final locale = resolveAppLocale(ref.watch(localeProvider));
  final l10n = _localizationsFor(locale);
  final today = ref.watch(todayDateProvider);
  final coordinates = ref.watch(resolvedCoordinatesProvider);
  final city = ref.watch(currentLocationProvider).valueOrNull?.cityName ?? '';
  final region = ref.watch(festivalRegionProvider);
  final primarySystem = ref.watch(primaryCalendarSystemProvider);
  final secondarySystem = ref.watch(secondaryCalendarSystemProvider);
  final monthSystem = ref.watch(hinduMonthSystemProvider);

  final panchang = ref.watch(livePanchangProvider(today)).valueOrNull;
  if (panchang == null) return;

  final tomorrow = DateTime(today.year, today.month, today.day + 1);
  // Already warm on the home screen (the month batch and event list need
  // it); a missing tomorrow just means no rollover payload today.
  final tomorrowPanchang = ref
      .watch(panchangForDateProvider(tomorrow))
      .valueOrNull;

  // Payload construction is pure but not infallible (astronomy edge cases,
  // malformed festival data). A widget failure must never throw into the
  // app-root build, so degrade to "no sync this time" and retry on the next
  // data change.
  try {
    final content = heroContentData(
      panchang: panchang,
      l10n: l10n,
      primarySystem: primarySystem,
      secondarySystem: secondarySystem,
      monthSystem: monthSystem,
      bengali: ref
          .watch(bengaliDateForHeroProvider(panchang.date))
          .valueOrNull,
      useBengaliScript: locale.languageCode == 'bn',
      isToday: true,
      region: region,
    );
    final names = masaTithiNames(
      masa: panchang.masa,
      paksha: panchang.paksha,
      monthSystem: monthSystem,
      tithiNumber: panchang.tithiNumber,
      l10n: l10n,
    );
    final detail = [
      names.localizedMasa,
      ?panchang.nakshatra,
    ].where((part) => part.trim().isNotEmpty).join(' · ');

    // Widget text follows the app language, including festival names.
    final festivals = sortedFestivalsForRegion(
      panchang.festivals,
      region,
    )
        .map(
          (festival) => festivalDisplayName(
            festival: festival,
            locale: locale.languageCode,
          ),
        )
        .toList(growable: false);

    final hero = buildHeroWidgetPayload(
      panchang: panchang,
      content: content,
      l10n: l10n,
      detail: detail,
      festivals: festivals,
      lang: locale.languageCode,
      refreshLabel: l10n.widgetOpenToRefresh,
      formatTime: (time) => formatLocalizedDate(time, 'jm', l10n.localeName),
      location: city,
    );

    final timings = buildTimingsWidgetPayload(
      days: [panchang, ?tomorrowPanchang],
      coordinates: coordinates,
      l10n: l10n,
      lang: locale.languageCode,
      refreshLabel: l10n.widgetOpenToRefresh,
    );

    unawaited(
      ref
          .read(homeWidgetServiceProvider)
          .updatePanchangWidgets(hero: hero, timings: timings),
    );
  } catch (e, stack) {
    debugPrint('panchangWidgetSyncProvider failed: $e\n$stack');
  }
});

/// Context-free localizations for background sync work.
AppLocalizations _localizationsFor(Locale locale) =>
    switch (locale.languageCode) {
      'hi' => AppLocalizationsHi(),
      'bn' => AppLocalizationsBn(),
      'sa' => AppLocalizationsSa(),
      _ => AppLocalizationsEn(),
    };
