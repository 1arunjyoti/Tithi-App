import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/format/date_only.dart';
import '../features/countdown/domain/target_resolution.dart';
import '../features/event_detail/domain/puja_moonrise.dart';
import '../features/event_detail/domain/puja_samay.dart';
import '../features/sheets/widgets/sheet_time_format.dart';
import '../l10n/app_localizations.dart';
import '../models/festival.dart';
import '../models/panchang_data.dart';
import '../providers/calendar_provider.dart';
import '../providers/panchang_provider.dart';
import '../services/solar_events_service.dart';
import '../theme/app_theme.dart';
import '../theme/app_metrics.dart';
import '../theme/app_typography.dart';
import 'app_card.dart';
import 'app_divider.dart';
import '../utils/tithi_localization.dart';
import 'festival_thumbnail.dart';

/// One observance line of the featured card: the localized caption and the
/// value it labels.
typedef _TimingEntry = ({String label, String value});

/// The large card the all-festivals list gives to a flagship festival: the
/// observance windows the event sheet shows, plus the date, tithi and
/// description a scanner needs.
///
/// "Featured" is a curated flag in the catalog (`Festival.featured`), not a
/// category and not a date heuristic. The catalog marks 96 of its 110
/// festivals `major` and only 7 ship artwork, so promoting the category turned
/// most of the list into identical tall cards (~73 of them showed a single
/// timing row under the divider); picking whichever major came next made
/// importance depend on the calendar and split celebrations that run for days.
/// ~20 records set the flag, so a whole celebration run keeps the card and
/// everything else, other majors included, stays a compact row.
///
/// The artwork square is drawn only when the festival ships a picture.
/// Without one the card leads with a glyph chip plus the typography, instead
/// of spending a quarter of its width on a placeholder icon.
class MajorFestivalCard extends ConsumerWidget {
  const MajorFestivalCard({super.key, required this.item, required this.onTap});

  final DatedFestival item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final date = item.date;
    final festival = item.festival;
    final l10n = AppLocalizations.of(context);
    final locale = l10n?.localeName ?? 'en';
    final colors = context.colors;
    final accent = AppTheme.festivalAccent(context);
    final hasArtwork = festival.visuals.image.trim().isNotEmpty;
    final coordinates = ref.watch(resolvedCoordinatesProvider);
    final AsyncValue<PanchangData?> panchangAsync = date == null
        ? const AsyncData(null)
        : ref.watch(panchangForDateProvider(dateOnly(date)));
    final panchang = panchangAsync.valueOrNull;
    // Full 1-30 index of the OBSERVED (festival) tithi, not the sunrise tithi:
    // a timingOverride festival can be observed on a neighbouring tithi.
    final AsyncValue<({DateTime start, DateTime end})?> tithiAsync =
        panchang == null || festival.tithi < 1
        ? const AsyncData(null)
        : ref.watch(
            tithiTimingsProvider((
              date: dateOnly(date!),
              tithiIndex: festival.resolveTithiIndex(panchang.paksha),
              latitude: coordinates.latitude,
              longitude: coordinates.longitude,
            )),
          );
    final tithi = tithiAsync.valueOrNull;
    final pujaKala = normalizedPujaKala(festival);
    final puja = panchang == null || pujaKala == null
        ? null
        : _pujaSpan(
            festival: festival,
            panchang: panchang,
            pujaKala: pujaKala,
            tithiEnd: tithi?.end,
            coordinates: coordinates,
          );

    final today = ref.watch(todayDateProvider);
    final isToday = date != null && isSameDay(date, today);
    final daysAway = date == null ? 0 : calendarDaysBetween(today, date);
    // The gold line carries the same two facts as a row: when, and which
    // tithi. The compact rows show "Shukla Ekadashi" and the card used to drop
    // it, leaving a bare "TITHI:" caption over a time range.
    final tithiName = l10n == null || panchang == null || festival.tithi < 1
        ? null
        : localizedPakshaTithiName(
            festival.resolveTithiIndex(panchang.paksha),
            l10n,
          );
    final dateLine = date == null
        ? null
        : [
            isToday
                ? (l10n?.today ?? 'Today')
                : formatLocalizedDate(date, 'EEE, d MMMM', locale),
            ?tithiName,
          ].join(' · ');
    // A chip instead of the row's " · in N days" suffix: the suffix made the
    // date line grow with the countdown and pushed the tithi name off narrow
    // cards.
    final countdown = !isToday && daysAway > 0 && l10n != null
        ? l10n.festivalInDays(daysAway)
        : null;
    final regionalName = _regionalName(festival, locale);
    final description = festival.description.trim();

    final paranValue = _paranValue(festival, pujaKala, l10n);
    final entries = <_TimingEntry>[
      if (tithi != null && panchang != null)
        (
          label: (l10n?.tithi ?? 'Tithi').toUpperCase(),
          value: sheetTimeRange(tithi.start, tithi.end, panchang.date, locale),
        ),
      if (puja != null && pujaKala != null && panchang != null)
        (
          label: pujaKalaLabel(pujaKala, l10n).toUpperCase(),
          value: sheetTimeRange(puja.start, puja.end, panchang.date, locale),
        ),
      if (paranValue != null)
        (label: _paranCaption(l10n).toUpperCase(), value: paranValue),
    ];
    // One composed label (as FestivalRowTile does): the inner Texts are
    // excluded below, so a screen reader hears the observance once, in order,
    // and the description is a hint rather than a fourth data point.
    final semanticsLabel = [
      festival.name,
      ?regionalName,
      ?dateLine,
      ?countdown,
      for (final entry in entries) '${entry.label}: ${entry.value}',
    ].join('. ');

    return AppCard(
      // 14, not the row's 12: a featured card must feel larger than the rows
      // it replaces. The accent edge marks today's observance (an ordinary
      // card keeps the neutral hairline).
      padding: const EdgeInsets.all(AppSpacing.s14),
      accent: isToday ? accent : null,
      onTap: onTap,
      semanticLabel: semanticsLabel,
      semanticHint: description.isEmpty ? null : description,
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Artwork only ever exists for a handful of festivals, so
          // it sizes from the card instead of the old fixed 96-108
          // square that dominated the text column.
          final imageSize = (constraints.maxWidth * 0.32).clamp(84.0, 104.0);
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (hasArtwork) ...[
                FestivalThumbnail(
                  festival: festival,
                  size: imageSize,
                  backgroundColor: AppTheme.festivalTileBackground(context),
                  glyphColor: accent,
                  glyphSize: AppIconSize.title,
                ),
                const SizedBox(width: AppSpacing.s12),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (!hasArtwork) ...[
                          _GlyphChip(
                            icon: festivalRowIcon(festival),
                            color: accent,
                          ),
                          const SizedBox(width: AppSpacing.s10),
                        ],
                        Expanded(
                          child: Text(
                            festival.name,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.ui(
                              fontSize: AppTypography.sizeHeading,
                              fontWeight: AppTypography.semibold,
                              // Full-strength ink, same as FestivalRowTile's
                              // name. Without an explicit colour this inherits
                              // bodyMedium's secondaryInk and reads muted next
                              // to the rows it replaces.
                              color: colors.onSurface,
                              height: 1.3,
                            ),
                          ),
                        ),
                        if (countdown != null) ...[
                          const SizedBox(width: AppSpacing.s8),
                          _CountdownChip(label: countdown, color: accent),
                        ],
                      ],
                    ),
                    if (regionalName != null) ...[
                      const SizedBox(height: AppSpacing.s2),
                      Text(
                        regionalName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: AppTypography.sizeDetail,
                          height: 1.2,
                          fontWeight: AppTypography.medium,
                          color: colors.onSurface.withValues(
                            alpha: AppTheme.contrastAlpha(context, 0.70),
                          ),
                        ),
                      ),
                    ],
                    if (dateLine != null) ...[
                      const SizedBox(height: AppSpacing.s4),
                      Text(
                        dateLine,
                        style: context.textTheme.titleSmall?.copyWith(
                          color: accent,
                          fontWeight: AppTypography.bold,
                        ),
                      ),
                    ],
                    if (description.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.s6),
                      // One line: the card already carries name,
                      // regional name, gold date line and timings,
                      // so the description is a hook, not a
                      // paragraph. Two lines made the card taller
                      // than the content it adds; the full text
                      // stays one tap away in the event sheet (and
                      // is the semantics hint).
                      Text(
                        description,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: AppTypography.sizeCaption,
                          height: 1.35,
                          fontWeight: AppTypography.medium,
                          color: colors.onSurface.withValues(
                            alpha: AppTheme.contrastAlpha(context, 0.72),
                          ),
                        ),
                      ),
                    ],
                    if (entries.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.s10),
                      const AppDivider(),
                    ],
                    for (final entry in entries)
                      _TimingRow(label: entry.label, value: entry.value),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.s4),
              // The rows end in a chevron; without one the card read
              // as static content until it was pressed.
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.s2),
                child: Icon(
                  Icons.chevron_right_rounded,
                  size: AppIconSize.medium,
                  color: colors.onSurface.withValues(
                    alpha: AppTheme.contrastAlpha(context, 0.32),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  /// Puja window for [festival] on [panchang]'s day, or null when the kala has
  /// no window there. Both ephemeris lookups degrade to null: a missing rise
  /// hides the window, exactly as the event sheet does, instead of throwing
  /// mid-build and taking the whole list down.
  PujaKalaSpan? _pujaSpan({
    required Festival festival,
    required PanchangData panchang,
    required String pujaKala,
    required DateTime? tithiEnd,
    required ({double latitude, double longitude}) coordinates,
  }) {
    DateTime? nextSunrise;
    try {
      nextSunrise = solarEventsService.sunrise(
        date: panchang.date.add(const Duration(days: 1)),
        latitude: coordinates.latitude,
        longitude: coordinates.longitude,
      );
    } catch (_) {
      nextSunrise = null;
    }
    return resolvePujaKala(
      kala: pujaKala,
      date: panchang.date,
      sunrise: panchang.sunrise,
      sunset: panchang.sunset,
      nextSunrise: nextSunrise,
      moonrise: pujaMoonrise(
        date: panchang.date,
        latitude: coordinates.latitude,
        longitude: coordinates.longitude,
      ),
      tithiEnd: tithiEnd,
      clipToTithi: festival.panchangRules.clipToTithi,
      sankrantiInstant: panchang.sankranti?.instant,
      bhadraWindows: panchang.bhadraWindows,
      avoidBhadra: festival.panchangRules.avoidBhadra,
    );
  }

  /// Fast-breaking rule as a phrase, or null when there is nothing to state.
  ///
  /// `after_puja_kala` names the festival's own kala ("after the Nishita
  /// puja"); without one the rule is undefined, so the row is hidden rather
  /// than claiming a generic "puja puja" window.
  String? _paranValue(
    Festival festival,
    String? pujaKala,
    AppLocalizations? l10n,
  ) {
    return switch (normalizedParanRule(festival)) {
      null => null,
      'moonrise' => l10n?.paranReasonMoonrise ?? 'after moonrise',
      'next_sunrise' => l10n?.paranReasonSunrise ?? 'after sunrise',
      'after_puja_kala' when pujaKala == null => null,
      'after_puja_kala' =>
        l10n?.paranReasonPujaKala(pujaKalaLabel(pujaKala!, l10n)) ??
            'after the ${pujaKalaLabel(pujaKala!, l10n)} puja',
      'dwadashi_window' =>
        l10n?.paranReasonDwadashi ?? 'in the Dwadashi window',
      final rule => rule,
    };
  }

  /// Compact paran caption: [AppLocalizations.paranLabel] is the fasting card's
  /// long caption ("Paran (breaking the fast):"), which would ellipsize over a
  /// timing value. Keep the leading word, localized.
  String _paranCaption(AppLocalizations? l10n) {
    final label = (l10n?.paranLabel ?? 'Paran').trim();
    final paren = label.indexOf('(');
    final head = (paren > 0 ? label.substring(0, paren) : label).trim();
    return head.endsWith(':')
        ? head.substring(0, head.length - 1).trim()
        : head;
  }

  /// Festival's name in the UI language, or null when the catalog only has the
  /// English one (a row that repeats the title is noise, not a translation).
  String? _regionalName(Festival festival, String localeName) {
    final names = festival.nameRegional;
    final language = localeName.toLowerCase().split(RegExp('[-_]')).first;
    final candidate = switch (language) {
      'hi' => names.nameHindi,
      'bn' => names.nameBengali,
      'sa' => names.nameSanskrith,
      'te' => names.nameTelugu,
      'kn' => names.nameKannada,
      'ta' => names.nameTamil,
      'ml' => names.nameMalayalam,
      _ => null,
    }?.trim();
    if (candidate == null ||
        candidate.isEmpty ||
        candidate == festival.name.trim()) {
      return null;
    }
    return candidate;
  }
}

/// Small category glyph shown when the festival ships no artwork: presence
/// without a 100dp placeholder square.
class _GlyphChip extends StatelessWidget {
  const _GlyphChip({required this.icon, required this.color});

  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: AppTheme.festivalTileBackground(context),
        borderRadius: BorderRadius.circular(AppRadius.dense),
      ),
      child: Icon(icon, size: AppIconSize.medium, color: color),
    );
  }
}

/// "in N days", set as a pill so it scans without lengthening the date line.
class _CountdownChip extends StatelessWidget {
  const _CountdownChip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.s8,
        vertical: AppSpacing.s4,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Text(
        label,
        maxLines: 1,
        style: TextStyle(
          color: color,
          fontSize: AppTypography.sizeFootnote,
          height: 1.2,
          fontWeight: AppTypography.bold,
        ),
      ),
    );
  }
}

/// One observance line: a muted caption above its value.
///
/// Caption-above-value rather than the old icon + inline caption: the caption
/// used to be the boldest text in the block (accent, 11px, w800) while the
/// value it labels sat at 12px and 78% ink, and the inline form needed a
/// `<220dp` fallback that fired on most phones. Stacked, every value starts on
/// the same x, nothing ellipsizes a localized kala name, and the value is the
/// loudest text after the festival name.
class _TimingRow extends StatelessWidget {
  const _TimingRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    // Captions can arrive localized with their own colon (paranLabel ships
    // with one); strip it instead of rendering "PARAN::".
    final caption = label.endsWith(':')
        ? label.substring(0, label.length - 1)
        : label;
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.s8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            caption,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: AppTypography.sizeMicro,
              height: 1.1,
              fontWeight: AppTypography.bold,
              letterSpacing: 0.7,
              color: colors.onSurface.withValues(
                alpha: AppTheme.contrastAlpha(context, 0.55),
              ),
            ),
          ),
          const SizedBox(height: 1),
          Text(
            value,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: AppTypography.sizeDetail,
              height: 1.2,
              fontWeight: AppTypography.semibold,
              color: colors.onSurface.withValues(
                alpha: AppTheme.contrastAlpha(context, 0.92),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
