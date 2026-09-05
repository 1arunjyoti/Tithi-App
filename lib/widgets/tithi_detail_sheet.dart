import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../l10n/app_localizations.dart';
import '../models/panchang_data.dart';
import '../providers/calendar_provider.dart';
import '../providers/panchang_provider.dart';
import '../theme/app_theme.dart';

/// Bottom sheet with full tithi timing details for a day.
///
/// Shows the sunrise (udaya) tithi's beginning and end, the transition to
/// the next tithi when one occurs before the next sunrise, and the
/// sunrise/sunset anchors — so squeeze cases where a short tithi touches
/// no sunrise (e.g. Navami on Oct 4 2026) are fully visible instead of
/// being skipped over between the surrounding days.
class TithiDetailSheet extends ConsumerWidget {
  final PanchangData panchang;

  const TithiDetailSheet({super.key, required this.panchang});

  static final DateFormat _fullFormat = DateFormat('h:mm a, MMM d');
  static final DateFormat _timeFormat = DateFormat('h:mm a');
  static final DateFormat _dateFormat = DateFormat('EEE, MMM d, y');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final coords = ref.watch(resolvedCoordinatesProvider);
    final timingsAsync = ref.watch(
      tithiTimingsProvider((
        date: panchang.date,
        tithiIndex: panchang.tithiIndex,
        latitude: coords.latitude,
        longitude: coords.longitude,
      )),
    );
    final displayNum =
        ref.watch(tithiDisplayModeProvider) == TithiDisplayMode.continuous30
        ? panchang.tithiIndex
        : panchang.tithiNumber;

    return Container(
      decoration: BoxDecoration(
        color: context.theme.scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Drag handle.
              Container(
                height: 32,
                alignment: Alignment.center,
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: context.colors.primary.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              // Header: paksha + sunrise tithi + date.
              Row(
                children: [
                  Icon(
                    panchang.isShukla
                        ? Icons.brightness_3
                        : Icons.brightness_2,
                    color: context.colors.primary,
                    size: 28,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n?.pakshaWithName(panchang.paksha) ??
                              '${panchang.paksha} Paksha',
                          style: context.textTheme.headlineMedium?.copyWith(
                            fontSize: 20,
                            color: context.colors.primary,
                          ),
                        ),
                        Text(
                          '${panchang.tithiName} · ${_dateFormat.format(panchang.date)}',
                          style: context.textTheme.bodyLarge?.copyWith(
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: context.colors.primary.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '$displayNum',
                      style: TextStyle(
                        color: context.colors.primary,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Sunrise tithi timings (exact start/end via binary search).
              timingsAsync.when(
                data: (timings) {
                  // Kshaya edge (no nearby occurrence): hide rather than
                  // show a wrong-lunation span.
                  if (timings == null) return const SizedBox.shrink();
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildInfoRow(
                        context,
                        Icons.access_time,
                        'Begins',
                        _fullFormat.format(timings.start),
                      ),
                      _buildInfoRow(
                        context,
                        Icons.access_time_filled,
                        'Ends',
                        // Prefer the precomputed transition instant when the
                        // tithi ends before the next sunrise; otherwise the
                        // searched end (next boundary, usually tomorrow).
                        _fullFormat.format(
                          panchang.tithiTransitionTime ?? timings.end,
                        ),
                      ),
                    ],
                  );
                },
                loading: () => const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Center(
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                ),
                error: (err, stack) => const SizedBox.shrink(),
              ),
              // Transition into the next tithi (squeeze-case visibility).
              if (panchang.hasTithiTransition) ...[
                const SizedBox(height: 8),
                _buildSectionHeader(
                  context,
                  icon: Icons.swap_horiz,
                  label:
                      'Transition → ${panchang.transitionTithiName} '
                      'at ${_timeFormat.format(panchang.tithiTransitionTime!)}',
                  color: context.colors.primary,
                ),
                Consumer(
                  builder: (context, ref, child) {
                    final nextTimingsAsync = ref.watch(
                      tithiTimingsProvider((
                        date: panchang.date,
                        tithiIndex: panchang.transitionTithiIndex!,
                        latitude: coords.latitude,
                        longitude: coords.longitude,
                      )),
                    );
                    return nextTimingsAsync.when(
                      data: (nextTimings) {
                        if (nextTimings == null) {
                          return const SizedBox.shrink();
                        }
                        return _buildInfoRow(
                          context,
                          Icons.access_time_filled,
                          '${panchang.transitionTithiName} ends',
                          _fullFormat.format(nextTimings.end),
                        );
                      },
                      loading: () => const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: Center(
                          child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        ),
                      ),
                      error: (err, stack) => const SizedBox.shrink(),
                    );
                  },
                ),
              ],
              // Sunrise/sunset anchors (the udaya-tithi reference points).
              if (panchang.sunrise != null)
                _buildInfoRow(
                  context,
                  Icons.wb_sunny_outlined,
                  l10n?.sunrise ?? 'Sunrise',
                  _timeFormat.format(panchang.sunrise!),
                ),
              if (panchang.sunset != null)
                _buildInfoRow(
                  context,
                  Icons.nights_stay_outlined,
                  l10n?.sunset ?? 'Sunset',
                  _timeFormat.format(panchang.sunset!),
                ),
              const SizedBox(height: 8),
              Text(
                'Udaya tithi: the tithi prevailing at sunrise. A short tithi '
                'can begin and end between two sunrises — both tithis are '
                'shown above so none is skipped.',
                style: context.textTheme.bodySmall?.copyWith(
                  color: context.colors.onSurface.withValues(alpha: 0.6),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(
    BuildContext context, {
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Row(
      children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: context.textTheme.headlineMedium?.copyWith(
              fontSize: 16,
              color: color,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInfoRow(
    BuildContext context,
    IconData icon,
    String label,
    String value,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, color: context.colors.primary, size: 22),
          const SizedBox(width: 12),
          Text(
            '$label:',
            style: context.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: context.textTheme.bodyLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
