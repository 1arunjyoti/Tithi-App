import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/locale/app_locale.dart';
import '../../../l10n/app_localizations.dart';
import '../../../models/festival.dart';
import '../../../models/panchang_data.dart';
import '../../../providers/calendar_provider.dart';
import '../../../providers/locale_provider.dart';
import '../../../providers/panchang_provider.dart';
import '../../../theme/app_metrics.dart';
import '../../../theme/app_theme.dart';
import '../../../utils/tithi_localization.dart';
import '../../ai/domain/ai_prompt.dart';
import '../../ai/providers/ai_providers.dart';
import '../../ai/widgets/ask_ai_sheet.dart';
import '../../sheets/sheet_launcher.dart';
import '../../sheets/widgets/info_row.dart';
import '../../sheets/widgets/section_header.dart';
import '../../sheets/widgets/sheet_explainer_card.dart';
import '../../sheets/widgets/sheet_link_tile.dart';
import '../../sheets/widgets/sheet_scaffold.dart';
import '../../sheets/widgets/sheet_surface_card.dart';
import '../domain/event_content.dart';
import '../domain/puja_samay.dart';
import 'event_description_card.dart';
import 'event_fasting_section.dart';
import 'event_panchang_section.dart';
import 'event_puja_samay_section.dart';
import 'event_rituals_cards.dart';
import 'event_sheet_hero.dart';
import 'event_sheet_info.dart';

/// Bottom sheet showing festival details in the tithi-sheet visual language.
///
/// Scaffold, hero header, chips, timings card and explainer are the shared
/// sheet kit; the body cards use the shared [SheetSurfaceCard] (surface fill,
/// 16pt radius) instead of glassmorphism so both sheets share fill, radius
/// and high-contrast behavior.
class EventDetailSheet extends ConsumerWidget {
  final Festival festival;

  /// The day's panchang when the caller already holds it. When null, the
  /// sheet resolves [date] itself (see [date]).
  final PanchangData? panchang;

  /// Occurrence date for callers that only know the festival (all-festivals
  /// list, home countdown). Ignored when [panchang] is supplied.
  final DateTime? date;

  /// True when this sheet was opened from the tithi sheet: its
  /// "View full panchang" link then pops back to that sheet instead of
  /// stacking an identical one.
  final bool openedFromTithiSheet;

  const EventDetailSheet({
    super.key,
    required this.festival,
    this.panchang,
    this.date,
    this.openedFromTithiSheet = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeColor = context.colors.primary;
    // Month system for Masa labels: Purnimant Krishna days carry the next
    // month's name (e.g. Janmashtami = Bhadrapada, not Shravana).
    final monthSystem = ref.watch(hinduMonthSystemProvider);
    final l10n = AppLocalizations.of(context);
    final locale = l10n?.localeName ?? 'en';
    // Opt-in gate: the AI row is hidden (not disabled) until Settings turns
    // the feature on.
    final aiAssistEnabled = ref.watch(aiAssistEnabledProvider);
    // Hero title follows the app language (Bengali/Hindi/Sanskrit names
    // under those locales, English otherwise), resolved from the language
    // setting like the tithi sheet — not the Material locale.
    final appLanguage = resolveAppLocale(
      ref.watch(localeProvider),
    ).languageCode;
    final displayName = festivalDisplayName(
      festival: festival,
      locale: appLanguage,
    );
    // Settings tithi display mode: paksha-based shows T1-15, continuous
    // shows T1-30 — resolved once here instead of inside row builders.
    final continuous =
        ref.watch(tithiDisplayModeProvider) == TithiDisplayMode.continuous30;
    final flags = eventFlags(festival);
    // Normalized ritual-window fields (null when absent/unknown → the
    // corresponding card or line hides).
    final pujaKala = normalizedPujaKala(festival);
    final paranRule = normalizedParanRule(festival);
    // Panchang resolution: callers that already hold the day's record pass
    // it directly; the all-festivals list and the home countdown only know
    // the festival + occurrence date, so the sheet resolves that date here.
    // While it loads (or with neither input) the rules-only fallback below
    // stands — no skeleton flash, the sheet upgrades in place.
    final requestedDate = date == null ? null : DateUtils.dateOnly(date!);
    final AsyncValue<PanchangData?> panchangAsync = panchang != null
        ? AsyncData<PanchangData?>(panchang)
        : requestedDate != null
        ? ref.watch(panchangForDateProvider(requestedDate))
        : const AsyncData<PanchangData?>(null);
    // Local promotes null checks for the section widgets below (fields
    // don't promote).
    final dayPanchang = panchangAsync.valueOrNull;
    // All derived labels/rows (features/event_detail/domain, unit tested).
    // Null without panchang data: the rules-only fallback rows below apply.
    final content = dayPanchang != null
        ? eventSheetContent(
            festival: festival,
            panchang: dayPanchang,
            monthSystem: monthSystem,
            continuousTithi: continuous,
            l10n: l10n,
          )
        : null;

    // Same high-contrast resolution as the tithi sheet (OS + app setting).
    final highContrast =
        AppTheme.highContrastOf(context) ||
        ref.watch(glassmorphismConfigProvider).isHighContrast;

    // Hero date line: observance weekday + Gregorian date. Falls back to the
    // requested occurrence date while the panchang loads, so date-only entry
    // points show the date immediately instead of shifting it in later.
    final headerDate = dayPanchang?.date ?? requestedDate;
    final heroChips = heroLanguageChips(
      festival: festival,
      locale: appLanguage,
    );
    // Observance rule sentence ("Observed on the day …"), mapped from
    // timingOverride with an English fallback like the other sheet strings.
    // Demoted to a caption on the Panchang Details section.
    final ruleLabel = observanceRuleLabel(observanceRuleKey(festival), l10n);
    final ruleSentence =
        l10n?.observedOnTheDay(ruleLabel) ?? 'Observed on the day $ruleLabel';
    final categoryLabel =
        content?.categoryLabel ??
        categoryLabelFor(festival: festival, l10n: l10n);

    return SheetScaffold(
      highContrast: highContrast,
      hero: EventSheetHero(
        festival: festival,
        content: content,
        headerDate: headerDate,
        displayName: displayName,
        categoryLabel: categoryLabel,
        heroChips: heroChips,
        highContrast: highContrast,
        locale: locale,
      ),
      body: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          EventDescriptionCard(
            festival: festival,
            hasAdditionalDesc: flags.additionalDesc,
            themeColor: themeColor,
          ),
          const SizedBox(height: AppSpacing.s12),

          // Panchang info (tithi-sheet section style).
          Row(
            children: [
              Expanded(
                child: SectionHeader(
                  text:
                      AppLocalizations.of(context)?.panchangDetails ??
                      'Panchang Details',
                ),
              ),
              if (content?.showTimings ?? false) buildTimingInfoButton(context),
            ],
          ),
          // Observance rule, demoted to a section caption: which tithi
          // checkpoint ("…at sunrise / midday / midnight") fixed this date.
          if (showsObservanceRule(festival)) ...[
            const SizedBox(height: AppSpacing.s4),
            ObservanceCaption(highContrast: highContrast, rule: ruleSentence),
          ],
          const SizedBox(height: AppSpacing.s10),
          if (dayPanchang != null && content != null) ...[
            EventPanchangSection(
              festival: festival,
              panchang: dayPanchang,
              content: content,
            ),
          ] else ...[
            // Generic info from festival rules when no panchang available.
            SheetSurfaceCard(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  buildInfoRow(
                    context,
                    Icons.brightness_3,
                    AppLocalizations.of(context)?.paksha ?? 'Paksha',
                    festival.paksha,
                  ),
                  buildInfoRow(
                    context,
                    Icons.calendar_today,
                    AppLocalizations.of(context)?.tithi ?? 'Tithi',
                    // Respect the Settings tithi display mode here too:
                    // festival rules store paksha-based 1-15, so map
                    // Krishna tithis to 16-30 in continuous mode.
                    ruleTithiLabel(
                      festival: festival,
                      continuous: continuous,
                      l10n: l10n,
                    ),
                  ),
                  // Masa from festival rules (stored Amanta) — converted
                  // for Purnimant display using the rule's own paksha.
                  if (festival.masa.isNotEmpty && festival.masa != '*')
                    buildInfoRow(
                      context,
                      Icons.wb_sunny_outlined,
                      AppLocalizations.of(context)?.masa ?? 'Masa',
                      localizedMasaLabel(
                        masa: festival.masa,
                        paksha: festival.paksha,
                        monthSystem: monthSystem,
                        locale: locale,
                      ),
                    ),
                  // Nakshatra from festival rules when tithi is
                  // overridden by one (stored tithi is then ignored).
                  if (festival.nakshatraCondition != null)
                    buildInfoRow(
                      context,
                      Icons.star_outline,
                      AppLocalizations.of(context)?.nakshatra ?? 'Nakshatra',
                      festival.nakshatraCondition!,
                    ),
                  buildInfoRow(
                    context,
                    Icons.category,
                    AppLocalizations.of(context)?.category ?? 'Category',
                    categoryLabel,
                  ),
                ],
              ),
            ),
          ],

          // Link into the day's tithi sheet (the other half of the
          // cross-link). Only once the day's panchang is known; when this
          // sheet was opened from the tithi sheet, pop back to it instead
          // of stacking a duplicate.
          if (dayPanchang != null) ...[
            const SizedBox(height: AppSpacing.s10),
            SheetLinkTile(
              icon: Icons.calendar_month_outlined,
              label: l10n?.viewFullPanchang ?? 'View full panchang',
              supporting: formatLocalizedDate(
                dayPanchang.date,
                'd MMMM y',
                locale,
              ),
              onTap: () {
                if (openedFromTithiSheet) {
                  Navigator.of(context).pop();
                  return;
                }
                showTithiDetailSheet(context, panchang: dayPanchang);
              },
            ),
          ],

          // AI hand-off (opt-in). Below the panchang link so the sheet's own
          // data keeps priority; works with or without resolved panchang.
          if (aiAssistEnabled) ...[
            const SizedBox(height: AppSpacing.s10),
            SheetLinkTile(
              icon: Icons.auto_awesome_outlined,
              label: l10n?.aiAskAboutFestival ?? 'Ask AI about this festival',
              supporting: l10n?.aiOpensYourApp ?? 'Opens your AI app',
              accent: themeColor,
              onTap: () => showAskAiSheet(
                context,
                intent: AiIntent.festival,
                festival: festival,
                panchang: dayPanchang,
              ),
            ),
          ],

          // Puja Samay ritual window (below Panchang Details). Needs the
          // day's anchors, so it hides without panchang data.
          if (dayPanchang != null && content != null && pujaKala != null) ...[
            const SizedBox(height: AppSpacing.s12),
            SectionHeader(
              text:
                  '${AppLocalizations.of(context)?.pujaSamay ?? 'Puja Samay'} · ${pujaKalaLabel(pujaKala, l10n)}',
            ),
            const SizedBox(height: AppSpacing.s10),
            EventPujaSamaySection(
              festival: festival,
              panchang: dayPanchang,
              content: content,
              kala: pujaKala,
            ),
          ],

          // Fasting / Vrat info (below Puja Samay), with the paran line
          // when the breaking time is critical. Paran needs a date, so it
          // only renders with panchang data.
          if (flags.fasting ||
              (paranRule != null &&
                  dayPanchang != null &&
                  content != null)) ...[
            const SizedBox(height: AppSpacing.s12),
            SectionHeader(
              text:
                  AppLocalizations.of(context)?.fastingVrat ?? 'Fasting / Vrat',
            ),
            const SizedBox(height: AppSpacing.s10),
            EventFastingSection(
              festival: festival,
              panchang: dayPanchang,
              content: content,
              paranRule: paranRule,
            ),
          ],

          // Rituals
          if (festival.rituals.steps.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.s12),
            SectionHeader(
              text:
                  AppLocalizations.of(context)?.ritualsAndPractices ??
                  'Rituals & Practices',
            ),
            const SizedBox(height: AppSpacing.s10),
            EventRitualsCard(festival: festival, themeColor: themeColor),
          ],

          // Mantra section
          if (flags.mantra) ...[
            const SizedBox(height: AppSpacing.s12),
            SectionHeader(
              text: AppLocalizations.of(context)?.mantra ?? 'Mantra',
            ),
            const SizedBox(height: AppSpacing.s10),
            EventMantraCard(festival: festival, themeColor: themeColor),
          ],

          // Timing note (shared explainer style) while timings resolve.
          if (content?.showTimings ?? false) ...[
            const SizedBox(height: AppSpacing.s12),
            SheetExplainerCard(
              text:
                  AppLocalizations.of(context)?.timingNoteDescription ??
                  'Timings are calculated astronomically based on coordinates and may vary by a few minutes from local temple calendars due to atmospheric refraction, elevation, or calculation methods.',
            ),
          ],
        ],
      ),
    );
  }
}
