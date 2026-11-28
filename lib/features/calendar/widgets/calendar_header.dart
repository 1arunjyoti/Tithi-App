import 'package:material_ui/material_ui.dart';
import 'package:material_3_expressive/material_3_expressive.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/app_localizations.dart';
import '../../../providers/calendar_provider.dart' as cp;
import '../../../theme/app_metrics.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/app_typography.dart';
import '../../../utils/tithi_localization.dart';
import '../data/calendar_models.dart';
import '../domain/header_builders.dart';
import '../providers/header_provider.dart';

/// Month header with chevrons, the tappable year/month label, and the
/// secondary lunar line. Shared by the Gregorian and adaptive grids.
class CalendarHeader extends ConsumerWidget {
  final DateTime focusedMonth;
  final VoidCallback onLeftChevronTap;
  final VoidCallback onRightChevronTap;
  final VoidCallback onYearTap;

  const CalendarHeader({
    super.key,
    required this.focusedMonth,
    required this.onLeftChevronTap,
    required this.onRightChevronTap,
    required this.onYearTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final primary = ref.watch(cp.primaryCalendarSystemProvider);
    final secondary = ref.watch(cp.secondaryCalendarSystemProvider);
    final hinduYearEra = ref.watch(cp.hinduYearEraProvider);
    final hinduMonthSystem = ref.watch(cp.hinduMonthSystemProvider);
    // Mirrors the provider's gating: subscribe to taps whenever the
    // secondary header has a tap-narrowed (range -> single) variant, so the
    // key lookup stays meaningful and taps skip this widget otherwise.
    final tapNarrowsSecondary =
        (primary == cp.AppCalendarSystem.gregorian &&
            (secondary == cp.AppCalendarSystem.hindu ||
                secondary == cp.AppCalendarSystem.bengali)) ||
        ((primary == cp.AppCalendarSystem.hindu ||
                primary == cp.AppCalendarSystem.bengali) &&
            secondary != cp.AppCalendarSystem.none &&
            secondary != primary);
    final tappedDate = tapNarrowsSecondary
        ? ref.watch(cp.tappedCalendarDateProvider)
        : null;
    // Gregorian compares by year-month; lunar spans straddle Gregorian
    // months, so pass the tap through and let the range builder validate
    // containment (out-of-span taps show the range).
    final tappedInMonth = tappedDate == null
        ? null
        : (primary == cp.AppCalendarSystem.gregorian
              ? (tappedDate.year == focusedMonth.year &&
                        tappedDate.month == focusedMonth.month
                    ? DateTime(
                        tappedDate.year,
                        tappedDate.month,
                        tappedDate.day,
                      )
                    : null)
              : DateTime(tappedDate.year, tappedDate.month, tappedDate.day));
    final headerDataAsync = ref.watch(calendarHeaderDataProvider);
    final localeCode = Localizations.localeOf(context).languageCode;
    // Stale header first so swipes never show bare Gregorian then flip;
    // fresh async data replaces it once FFI resolves. On a date tap the
    // tap-keyed entry misses until fresh data lands, so fall back to
    // the range entry (previous text) rather than bare Gregorian.
    final headerData =
        headerDataAsync.valueOrNull ??
        cachedHeaderSync(
          focusedMonth,
          primary,
          secondary,
          hinduYearEra,
          hinduMonthSystem,
          locale: localeCode,
          selectedDate: tappedInMonth,
        ) ??
        cachedHeaderSync(
          focusedMonth,
          primary,
          secondary,
          hinduYearEra,
          hinduMonthSystem,
          locale: localeCode,
        ) ??
        HeaderData(
          primaryText: localizeDigits(
            formatGregorianHeader(focusedMonth, AppLocalizations.of(context)),
            localeCode,
          ),
        );
    final materialL10n = MaterialLocalizations.of(context);

    final highContrast = AppTheme.highContrastOf(context);
    final onSurface = context.colors.onSurface;
    final dim = context.secondaryInk;

    Widget navButton({
      required IconData icon,
      required String tooltip,
      required VoidCallback onTap,
    }) {
      // Haptics stay in the navigate methods (per-path: page-turn buzz on
      // Gregorian, explicit buzz on Hindu/Bengali) — not here, to avoid
      // double feedback.
      return Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(AppRadius.dense),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.dense),
          onTap: onTap,
          child: M3ETooltip(
            message: tooltip,
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppRadius.dense),
                border: Border.all(
                  color: onSurface.withValues(alpha: highContrast ? 0.25 : 0.1),
                ),
              ),
              alignment: Alignment.center,
              child: Icon(icon, size: AppIconSize.small, color: onSurface),
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.s8,
        0,
        AppSpacing.s8,
        AppSpacing.s4,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          navButton(
            icon: Icons.chevron_left,
            tooltip: materialL10n.previousPageTooltip,
            onTap: onLeftChevronTap,
          ),
          Expanded(
            child: GestureDetector(
              onTap: onYearTap,
              behavior: HitTestBehavior.opaque,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Flexible(
                        child: Text(
                          headerData.primaryText,
                          style: TextStyle(
                            fontSize: AppTypography.sizeHeading,
                            fontWeight: AppTypography.semibold,
                            letterSpacing: -0.2,
                            color: onSurface,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.s4),
                      Icon(
                        Icons.expand_more,
                        size: AppIconSize.inline,
                        color: dim,
                      ),
                    ],
                  ),
                  if (headerData.secondaryAccent != null) ...[
                    const SizedBox(height: 1),
                    Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: headerData.secondaryAccent,
                            style: TextStyle(
                              fontSize: AppTypography.sizeFootnote,
                              letterSpacing: 0.2,
                              fontWeight: AppTypography.semibold,
                              color: context.colors.primary,
                            ),
                          ),
                          if (headerData.secondaryDim != null &&
                              headerData.secondaryDim!.isNotEmpty)
                            TextSpan(
                              text: ' · ${headerData.secondaryDim}',
                              style: TextStyle(
                                fontSize: AppTypography.sizeFootnote,
                                color: dim,
                              ),
                            ),
                        ],
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
          ),
          navButton(
            icon: Icons.chevron_right,
            tooltip: materialL10n.nextPageTooltip,
            onTap: onRightChevronTap,
          ),
        ],
      ),
    );
  }
}
