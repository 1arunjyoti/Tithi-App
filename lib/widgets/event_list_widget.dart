import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../l10n/app_localizations.dart';
import '../models/panchang_data.dart';
import '../providers/calendar_provider.dart';
import '../providers/panchang_provider.dart';
import '../providers/accessibility_provider.dart';
import '../theme/app_theme.dart';
import 'event_detail_sheet.dart';
import 'package:flutter/services.dart';

/// Widget showing events/festivals for the selected date
class EventListWidget extends ConsumerWidget {
  const EventListWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedDate = ref.watch(selectedDateProvider);
    final panchangAsync = ref.watch(panchangForDateProvider(selectedDate));

    return panchangAsync.when(
      data: (panchang) => _buildEventList(context, ref, panchang),
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

  Widget _buildEventList(
    BuildContext context,
    WidgetRef ref,
    PanchangData panchang,
  ) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Panchang summary card
          _buildPanchangCard(context, ref, panchang),
          const SizedBox(height: 16),

          // Festivals section
          if (panchang.hasFestivals) ...[
            Text(
              AppLocalizations.of(context)?.festivalsAndEvents ??
                  'Festivals & Events',
              style: context.textTheme.headlineMedium?.copyWith(fontSize: 18),
            ),
            const SizedBox(height: 12),
            ...panchang.festivals.map(
              (festival) =>
                  _buildFestivalCard(context, ref, festival, panchang),
            ),
          ] else
            _buildNoFestivalsCard(context, ref),

          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildPanchangCard(
    BuildContext context,
    WidgetRef ref,
    PanchangData panchang,
  ) {
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
                  'T${panchang.tithiNumber}',
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
    WidgetRef ref,
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

  Widget _buildNoFestivalsCard(BuildContext context, WidgetRef ref) {
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
