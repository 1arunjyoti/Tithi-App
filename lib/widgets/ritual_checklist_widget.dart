import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/ritual_state_provider.dart';
import '../theme/app_theme.dart';

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
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: InkWell(
        onTap: () {
          // Trigger Haptic Feedback
          HapticFeedback.lightImpact();

          // Toggle state
          ref.read(ritualStateProvider.notifier).toggleRitual(ritualId);
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isCompleted
                ? context.colors.primary.withValues(alpha: 0.1)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
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
                duration: const Duration(milliseconds: 200),
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
                        : context.colors.onSurface.withValues(alpha: 0.5),
                    width: 2,
                  ),
                ),
                child: isCompleted
                    ? Icon(
                        Icons.check,
                        size: 16,
                        color: context.colors.onPrimary,
                      )
                    : null,
              ),
              const SizedBox(width: 12),

              // Text
              Expanded(
                child: Text(
                  label,
                  style: context.textTheme.bodyLarge?.copyWith(
                    decoration: isCompleted
                        ? TextDecoration.lineThrough
                        : TextDecoration.none,
                    color: isCompleted
                        ? context.colors.onSurface.withValues(alpha: 0.6)
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
