import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/format/date_only.dart';
import '../../../models/panchang_data.dart';
import '../../../providers/calendar_provider.dart';
import '../../../providers/location_provider.dart';
import '../../../providers/panchang_provider.dart';
import '../../../theme/app_metrics.dart';
import '../../../theme/app_motion.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/skeleton.dart';
import 'hero_card_body.dart';

/// True-cold placeholder height: reserves most of the hero's space up front
/// (any remainder still glides via AnimatedSize) without leaving a cavernous
/// block while the month batch computes.
const double _trueColdSkeletonHeight = 220;

/// Hero card showing the selected day's paksha/tithi (redesign v3 faithful).
///
/// Gradient hero (orange / purple / flat dark per theme) placed above the
/// calendar on the home screen. Data comes from [panchangForDateProvider] —
/// the month-map entry plus the resolved daytime tithi transition, computed
/// with [resolvedCoordinatesProvider] (GPS with Delhi fallback) — with the
/// month batch and [cachedPanchangUiSync] as instant fallbacks so date taps
/// never flash. City chip comes from [cityNameProvider]. Tap opens
/// [showTithiDetailSheet] for the displayed day.
///
/// The header mirrors the calendar Settings: the day line follows
/// [primaryCalendarSystemProvider] (Bengali primary swaps in the Bengali
/// date, otherwise the Hindu-flavored line), the masa is converted with
/// [displayMasaName] so Purnimant Krishna days show the right month, and a
/// Bengali secondary system adds its own line (other secondaries are already
/// visible in the tag/day/moon rows). [bengaliDateForHeroProvider] resolves
/// lazily and the hero falls back while it loads.
///
/// When the day's primary festival ships artwork ([Visuals.image]), it
/// renders in a rounded slot on the right of the moon row; otherwise the
/// card keeps its current text-only layout.
class PakshaHeroCard extends ConsumerWidget {
  const PakshaHeroCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Normalized once so the provider-family key, month key and map lookups
    // all share one stable midnight value (no duplicate cache entries when
    // the selected date carries a time component).
    final selected = ref.watch(selectedDateProvider);
    final day = dateOnly(selected);
    final isToday = isSameDay(day, ref.watch(todayDateProvider));

    // Live record: on today the displayed label advances intraday when a
    // tithi boundary passes (see livePanchangProvider); browsed dates and
    // the month-batch fallback below stay sunrise-pinned.
    final panchangAsync = ref.watch(livePanchangProvider(day));
    final cityAsync = ref.watch(cityNameProvider);
    final primarySystem = ref.watch(primaryCalendarSystemProvider);
    final cachedDay = cachedPanchangUiSync(day);
    final adaptiveGridHasDay =
        (primarySystem == AppCalendarSystem.hindu ||
            primarySystem == AppCalendarSystem.bengali) &&
        cachedDay != null;
    // The adaptive calendar has already resolved this date and its nearby
    // event-list window. Do not launch a duplicate Gregorian-month batch
    // merely to provide a fallback the shared cache can provide instantly.
    final monthAsync = adaptiveGridHasDay
        ? const AsyncValue<Map<DateTime, PanchangData>>.loading()
        : ref.watch(monthlyPanchangProvider(DateTime(day.year, day.month)));

    // Month data first, then last-visited stale, then — only on a true cold
    // start (fresh restart: both caches empty) — the placeholder that
    // reserves the resolved card's height.
    final shown = heroRecordFor(
      live: panchangAsync,
      cached: monthAsync.valueOrNull?[day] ?? cachedDay,
    );

    // Resize behavior on date taps: the swapped day can add/drop the
    // artwork column and the chips row, so the card height changes. That
    // change glides from a pinned top edge (AnimatedSize, slow-start curve
    // so the bottom edge never kicks), while the incoming content fades in
    // (keyed switcher, no stacking so the size glide stays in charge).
    // Together this reads as one calm settle instead of a rapid expand
    // flash with sliced text at the bottom edge.
    return AnimatedSize(
      alignment: Alignment.topCenter,
      duration: AppMotion.of(context, AppMotion.emphasized),
      curve: AppMotion.emphasizedCurve,
      child: AnimatedSwitcher(
        duration: AppMotion.of(context, AppMotion.subtle),
        transitionBuilder: (child, animation) =>
            FadeTransition(opacity: animation, child: child),
        layoutBuilder: (currentChild, _) => currentChild!,
        // No key here: the shell (HeroBody, gradient + ripple) stays
        // mounted across date taps. Only the true-cold skeleton (a plain
        // Container) cross-fades by type. Day text animates in the content
        // switcher inside HeroBody, so the background never flashes.
        child: shown == null
            ? const _TrueColdHeroPlaceholder()
            : HeroBody(
                panchang: shown.record,
                cityName: cityAsync.valueOrNull,
                isToday: isToday,
                resolved: shown.resolved,
              ),
      ),
    );
  }
}

/// The record the hero paints, and whether it is the fully resolved live one.
///
/// The last live record wins over both caches, even while a reload is in
/// flight (resume after a suspend, place change, midnight re-sync). Riverpod
/// keeps it as the previous value on reload, and re-painting it is what keeps
/// the card still: falling back to the cached record would flip [resolved] to
/// false, re-key the content switcher in [HeroBody] and blank-fade the whole
/// hero for ~180ms twice on every resume — the "card freezes, then updates"
/// glitch. An error is the only state that reads as no live record, so a
/// broken day still yields to the cache.
///
/// [cached] is the month-batch entry or the last-visited UI cache; when the
/// live record is absent (true cold start) it gives the hero something to
/// paint while the day resolves.
@visibleForTesting
({PanchangData record, bool resolved})? heroRecordFor({
  required AsyncValue<PanchangData> live,
  required PanchangData? cached,
}) {
  final liveRecord = live.hasError ? null : live.valueOrNull;
  final record = liveRecord ?? cached;
  if (record == null) return null;
  return (record: record, resolved: liveRecord != null);
}

/// True-cold placeholder: neutral block with festival-row-style bars (same
/// look as the Festivals & Events loading skeleton) so a slow first load
/// reads as loading content rather than a spinner or a black hole. It
/// reserves roughly the resolved card's height (see
/// [_trueColdSkeletonHeight]) so the cards below never shift on arrival.
class _TrueColdHeroPlaceholder extends StatelessWidget {
  const _TrueColdHeroPlaceholder();

  @override
  Widget build(BuildContext context) {
    final highContrast = AppTheme.highContrastOf(context);
    Widget bar() => const SkeletonBox(height: 76);
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppTheme.homeCardGutter),
      height: _trueColdSkeletonHeight,
      padding: const EdgeInsets.all(AppSpacing.s16),
      decoration: BoxDecoration(
        color: context.colors.onSurface.withValues(
          alpha: highContrast ? 0.14 : 0.08,
        ),
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          bar(),
          const SizedBox(height: AppSpacing.s10),
          bar(),
        ],
      ),
    );
  }
}
