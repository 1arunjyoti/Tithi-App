import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/anim/press_scale.dart';
import '../l10n/app_localizations.dart';
import '../providers/calendar_provider.dart';
import '../theme/app_metrics.dart';

/// Whether the calendar is showing something other than today: a month other
/// than the current one, or any selected day other than today.
///
/// Single source for both hosts of [JumpToTodayButton] — the floating nav
/// capsule (narrow shell) and the Scaffold FAB slot (wide layout) — so the two
/// can never disagree about when the action is needed.
///
/// "Today" comes from [todayDateProvider], not `DateTime.now()`: that provider
/// is the app's day (the place clock's date), refreshed at midnight and on a
/// place change, so a rollover or a non-device time zone cannot leave the
/// action hidden while the calendar shows yesterday. Watching it also means the
/// rule re-evaluates when the day changes, instead of caching a yes/no answer
/// computed against an instant that has since passed.
final jumpToTodayVisibleProvider = Provider<bool>((ref) {
  final focusedMonth = ref.watch(focusedMonthProvider);
  final selectedDate = ref.watch(selectedDateProvider);
  final today = ref.watch(todayDateProvider);
  return focusedMonth.year != today.year ||
      focusedMonth.month != today.month ||
      selectedDate.year != today.year ||
      selectedDate.month != today.month ||
      selectedDate.day != today.day;
});

/// Returns the calendar to the current month with today selected.
///
/// Month and selected date must move together: resetting only one leaves the
/// grid on the browsed month with today highlighted off-screen. Both come from
/// [todayDateProvider], the same day the rest of the app paints as "today".
void goToToday(WidgetRef ref) {
  final today = ref.read(todayDateProvider);
  setCalendarMonth(ref, today);
  ref.read(selectedDateProvider.notifier).setDate(today);
}

/// Icon-only "jump to today" action, shared by both hosts of the calendar
/// affordance: the floating nav capsule (narrow screens) and the Scaffold FAB
/// slot (wide screens).
class JumpToTodayButton extends ConsumerWidget {
  const JumpToTodayButton({super.key, this.shape = const CircleBorder()});

  /// Diameter. One step below the 64dp navigation capsule it floats beside, so
  /// it reads as a separate control rather than a fourth segment of the bar.
  static const double size = 56;

  /// Outline. The bar's copy is a circle, matching the pill language of the
  /// capsule; the wide layout passes the FAB's rounded square so that layout
  /// keeps the shape it had before this action moved.
  final ShapeBorder shape;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;

    return PressScale(
      child: SizedBox.square(
        dimension: size,
        child: Tooltip(
          message: l10n?.goToToday ?? 'Go to Today',
          child: Material(
            // An action, not navigation: it keeps the primary fill the FAB had
            // and does not compete with the capsule's translucent film.
            color: scheme.primary,
            shape: shape,
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () => goToToday(ref),
              child: Icon(
                Icons.today_rounded,
                size: AppIconSize.nav,
                color: scheme.onPrimary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
