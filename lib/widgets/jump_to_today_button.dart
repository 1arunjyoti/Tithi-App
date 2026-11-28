import 'package:material_ui/material_ui.dart';
import 'package:material_3_expressive/material_3_expressive.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/anim/press_scale.dart';
import '../l10n/app_localizations.dart';
import '../providers/calendar_provider.dart';
import '../theme/app_metrics.dart';

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
        child: M3ETooltip(
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
