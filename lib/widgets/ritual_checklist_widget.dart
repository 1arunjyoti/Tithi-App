import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/feedback/app_haptics.dart';
import '../providers/ritual_state_provider.dart';
import '../theme/app_theme.dart';
import '../theme/app_metrics.dart';
import '../theme/app_motion.dart';

class RitualChecklistWidget extends ConsumerWidget {
  final String ritualId;
  final String label;

  const RitualChecklistWidget({
    super.key,
    required this.ritualId,
    required this.label,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch the individual ritual state
    final isCompleted = ref.watch(ritualStateProvider)[ritualId] ?? false;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.s6),
      child: InkWell(
        onTap: () {
          AppHaptics.tap(ref);

          // Toggle state
          ref.read(ritualStateProvider.notifier).toggleRitual(ritualId);
        },
        borderRadius: BorderRadius.circular(AppRadius.dense),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.s12),
          decoration: BoxDecoration(
            color: isCompleted
                ? context.colors.primary.withValues(alpha: 0.1)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(AppRadius.dense),
            border: Border.all(
              color: isCompleted
                  ? context.colors.primary.withValues(alpha: 0.5)
                  : context.colors.onSurface.withValues(alpha: 0.1),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Checkbox/Icon
              AnimatedContainer(
                duration: AppMotion.of(context, AppMotion.standard),
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: isCompleted
                      ? context.colors.primary
                      : Colors.transparent,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isCompleted
                        ? context.colors.primary
                        : context.hintInk,
                    width: 2,
                  ),
                ),
                child: isCompleted
                    ? Icon(
                        Icons.check,
                        size: AppIconSize.small,
                        color: context.colors.onPrimary,
                      )
                    : null,
              ),
              const SizedBox(width: AppSpacing.s12),

              // Text
              Expanded(
                child: Text(
                  label,
                  style: context.textTheme.bodyLarge?.copyWith(
                    decoration: isCompleted
                        ? TextDecoration.lineThrough
                        : TextDecoration.none,
                    color: isCompleted
                        ? context.secondaryInk
                        : context.colors.onSurface,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
