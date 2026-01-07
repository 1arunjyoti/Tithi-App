import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../l10n/app_localizations.dart';
import '../models/panchang_data.dart';
import '../models/festival.dart';
import '../providers/calendar_provider.dart';
import '../providers/panchang_provider.dart';
import '../providers/accessibility_provider.dart';
import '../theme/app_theme.dart';
import 'event_detail_sheet.dart';

/// Widget showing events/festivals for the selected date or date range
class EventListWidget extends ConsumerStatefulWidget {
  const EventListWidget({super.key});

  @override
  ConsumerState<EventListWidget> createState() => _EventListWidgetState();
}

class _EventListWidgetState extends ConsumerState<EventListWidget> {
  DateTimeRange? _selectedRange;

  @override
  Widget build(BuildContext context) {
    final selectedDate = ref.watch(selectedDateProvider);

    // If range mode is active, show range festivals
    if (_selectedRange != null) {
      return _buildRangeEventList(context);
    }

    // Default: single date mode
    final panchangAsync = ref.watch(panchangForDateProvider(selectedDate));

    return panchangAsync.when(
      data: (panchang) => _buildEventList(context, panchang),
      loading: () => const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: CircularProgressIndicator(),
        ),
      ),
      error: (error, stack) {
        final l10n = AppLocalizations.of(context);
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              l10n?.errorLoadingPanchang(error.toString()) ??
                  'Error loading panchang: $error',
              style: TextStyle(color: context.colors.error),
            ),
          ),
        );
      },
    );
  }

  Widget _buildEventList(BuildContext context, PanchangData panchang) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Panchang summary card
        _buildPanchangCard(context, panchang),
        const SizedBox(height: 16),

        // Festivals section header with date range button
        _buildFestivalsHeader(context),
        const SizedBox(height: 12),

        // Festivals list
        if (panchang.hasFestivals)
          ...panchang.festivals.map(
            (festival) => _buildFestivalCard(context, festival, panchang),
          )
        else
          _buildNoFestivalsCard(context),

        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildRangeEventList(BuildContext context) {
    final range = _selectedRange!;
    final dayCount = range.end.difference(range.start).inDays + 1;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Range header with clear button
        _buildRangeHeader(context, range),
        const SizedBox(height: 16),

        // Festivals from all dates in range
        FutureBuilder<
          List<({DateTime date, Festival festival, PanchangData panchang})>
        >(
          future: _getFestivalsInRange(range),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: CircularProgressIndicator(),
                ),
              );
            }

            if (snapshot.hasError) {
              return Center(
                child: Text(
                  'Error loading festivals: ${snapshot.error}',
                  style: TextStyle(color: context.colors.error),
                ),
              );
            }

            final festivals = snapshot.data ?? [];

            if (festivals.isEmpty) {
              return _buildNoFestivalsInRangeCard(context, dayCount);
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${festivals.length} festival${festivals.length > 1 ? 's' : ''} found',
                  style: context.textTheme.bodyMedium?.copyWith(
                    color: context.colors.onSurface.withValues(alpha: 0.7),
                  ),
                ),
                const SizedBox(height: 12),
                ...festivals.map(
                  (item) => _buildFestivalCardWithDate(
                    context,
                    item.festival,
                    item.panchang,
                    item.date,
                  ),
                ),
              ],
            );
          },
        ),

        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildFestivalsHeader(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          AppLocalizations.of(context)?.festivalsAndEvents ??
              'Festivals & Events',
          style: context.textTheme.headlineMedium?.copyWith(fontSize: 18),
        ),
        Tooltip(
          message: 'View festivals in date range',
          child: InkWell(
            onTap: _showDateRangePicker,
            borderRadius: BorderRadius.circular(20),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: context.colors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(
                Icons.date_range,
                size: 20,
                color: context.colors.primary,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRangeHeader(BuildContext context, DateTimeRange range) {
    final dateFormat = DateFormat('MMM d');
    final startStr = dateFormat.format(range.start);
    final endStr = dateFormat.format(range.end);
    final yearStr = range.start.year != range.end.year
        ? '${range.start.year} - ${range.end.year}'
        : '${range.start.year}';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: AppTheme.glassmorphism(
        context: context,
        opacity: 0.15,
        ref: ref,
      ),
      child: Row(
        children: [
          Icon(Icons.date_range, color: context.colors.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Festivals from $startStr to $endStr',
                  style: context.textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  yearStr,
                  style: context.textTheme.bodyMedium?.copyWith(
                    color: context.colors.onSurface.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () {
              if (ref.read(accessibilityProvider).hapticFeedback) {
                HapticFeedback.selectionClick();
              }
              setState(() {
                _selectedRange = null;
              });
            },
            icon: Icon(
              Icons.close,
              color: context.colors.onSurface.withValues(alpha: 0.6),
            ),
            tooltip: 'Clear date range',
          ),
        ],
      ),
    );
  }

  Future<void> _showDateRangePicker() async {
    if (ref.read(accessibilityProvider).hapticFeedback) {
      HapticFeedback.selectionClick();
    }

    final selectedDate = ref.read(selectedDateProvider);
    final initialRange = DateTimeRange(
      start: selectedDate,
      end: selectedDate.add(const Duration(days: 7)),
    );

    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(1976, 1, 1),
      lastDate: DateTime(2076, 12, 31),
      initialDateRange: initialRange,
      helpText: 'Select date range (Gregorian dates)',
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
              primary: context.colors.primary,
              onPrimary: Colors.white,
              surface: Theme.of(context).scaffoldBackgroundColor,
            ),
          ),
          child: child!,
        );
      },
    );

    if (range != null) {
      setState(() {
        _selectedRange = range;
      });
    }
  }

  Future<List<({DateTime date, Festival festival, PanchangData panchang})>>
  _getFestivalsInRange(DateTimeRange range) async {
    final results =
        <({DateTime date, Festival festival, PanchangData panchang})>[];
    final dayCount = range.end.difference(range.start).inDays + 1;

    for (int i = 0; i < dayCount; i++) {
      final date = range.start.add(Duration(days: i));
      try {
        final panchang = await ref.read(panchangForDateProvider(date).future);
        for (final festival in panchang.festivals) {
          results.add((date: date, festival: festival, panchang: panchang));
        }
      } catch (_) {
        // Skip dates with errors
      }
    }

    return results;
  }

  Widget _buildPanchangCard(BuildContext context, PanchangData panchang) {
    final isShukla = panchang.isShukla;
    final moonIcon = isShukla ? Icons.brightness_3 : Icons.brightness_2;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: AppTheme.glassmorphism(
        context: context,
        opacity: 0.1,
        ref: ref,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(moonIcon, color: context.colors.primary, size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AppLocalizations.of(
                            context,
                          )?.pakshaWithName(panchang.paksha) ??
                          '${panchang.paksha} Paksha',
                      style: context.textTheme.headlineMedium?.copyWith(
                        fontSize: 20,
                        color: context.colors.primary,
                      ),
                    ),
                    Text(
                      panchang.tithiName,
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
                  '${panchang.tithiNumber}',
                  style: TextStyle(
                    color: context.colors.primary,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFestivalCard(
    BuildContext context,
    dynamic festival,
    PanchangData panchang,
  ) {
    final isMajor = festival.category == 'major';

    return GestureDetector(
      onTap: () {
        if (ref.read(accessibilityProvider).hapticFeedback) {
          HapticFeedback.selectionClick();
        }
        _showFestivalDetail(context, festival, panchang);
      },
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: AppTheme.glassmorphism(
          context: context,
          opacity: isMajor ? 0.2 : 0.1,
          ref: ref,
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: context.colors.primary.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                isMajor ? Icons.celebration : Icons.event,
                color: context.colors.primary,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    festival.name,
                    style: context.textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                  if (festival.description.isNotEmpty)
                    Text(
                      festival.description,
                      style: context.textTheme.bodyMedium?.copyWith(
                        fontSize: 13,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: context.colors.onSurface.withValues(alpha: 0.5),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFestivalCardWithDate(
    BuildContext context,
    Festival festival,
    PanchangData panchang,
    DateTime date,
  ) {
    final isMajor = festival.category == 'major';
    final dateFormat = DateFormat('EEE, MMM d');

    return GestureDetector(
      onTap: () {
        if (ref.read(accessibilityProvider).hapticFeedback) {
          HapticFeedback.selectionClick();
        }
        _showFestivalDetail(context, festival, panchang);
      },
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: AppTheme.glassmorphism(
          context: context,
          opacity: isMajor ? 0.2 : 0.1,
          ref: ref,
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: context.colors.primary.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                isMajor ? Icons.celebration : Icons.event,
                color: context.colors.primary,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    festival.name,
                    style: context.textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        Icons.calendar_today,
                        size: 12,
                        color: context.colors.onSurface.withValues(alpha: 0.6),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        dateFormat.format(date),
                        style: context.textTheme.bodySmall?.copyWith(
                          color: context.colors.primary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: context.colors.onSurface.withValues(alpha: 0.5),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoFestivalsCard(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: AppTheme.glassmorphism(
        context: context,
        opacity: 0.1,
        ref: ref,
      ),
      child: Column(
        children: [
          Icon(
            Icons.event_available,
            size: 48,
            color: context.colors.onSurface.withValues(alpha: 0.4),
          ),
          const SizedBox(height: 12),
          Text(
            AppLocalizations.of(context)?.noFestivalsOnThisDay ??
                'No festivals on this day',
            style: context.textTheme.bodyLarge?.copyWith(
              color: context.colors.onSurface.withValues(alpha: 0.6),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoFestivalsInRangeCard(BuildContext context, int dayCount) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: AppTheme.glassmorphism(
        context: context,
        opacity: 0.1,
        ref: ref,
      ),
      child: Column(
        children: [
          Icon(
            Icons.event_busy,
            size: 48,
            color: context.colors.onSurface.withValues(alpha: 0.4),
          ),
          const SizedBox(height: 12),
          Text(
            'No festivals in the selected $dayCount-day range',
            style: context.textTheme.bodyLarge?.copyWith(
              color: context.colors.onSurface.withValues(alpha: 0.6),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  void _showFestivalDetail(
    BuildContext context,
    dynamic festival,
    PanchangData panchang,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) =>
          EventDetailSheet(festival: festival, panchang: panchang),
    );
  }
}
