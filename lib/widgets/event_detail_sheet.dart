import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../l10n/app_localizations.dart';
import '../models/festival.dart';
import '../models/panchang_data.dart';
import '../theme/app_theme.dart';
import 'ritual_checklist_widget.dart';

/// Bottom sheet showing festival details with glassmorphism
class EventDetailSheet extends ConsumerWidget {
  final Festival festival;
  final PanchangData? panchang;

  const EventDetailSheet({super.key, required this.festival, this.panchang});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.3,
      maxChildSize: 0.9,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: context.theme.scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              // Drag handle
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: context.colors.onSurface.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              // Content
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.all(24),
                  children: [
                    // Festival name
                    Text(
                      festival.name,
                      style: context.textTheme.headlineLarge?.copyWith(
                        fontSize: 28,
                        color: context.colors.primary,
                      ),
                    ),
                    if (festival.nameHindi != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        festival.nameHindi!,
                        style: context.textTheme.headlineMedium?.copyWith(
                          fontSize: 20,
                          color: context.colors.onSurface.withValues(
                            alpha: 0.7,
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),

                    // Description
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: AppTheme.glassmorphism(
                        context: context,
                        opacity: 0.1,
                        ref: ref,
                      ),
                      child: Text(
                        festival.description,
                        style: context.textTheme.bodyLarge?.copyWith(
                          fontSize: 16,
                          height: 1.5,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Panchang info
                    Text(
                      AppLocalizations.of(context)?.panchangDetails ??
                          'Panchang Details',
                      style: context.textTheme.headlineMedium?.copyWith(
                        fontSize: 18,
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (panchang != null) ...[
                      _buildInfoRow(
                        context,
                        Icons.brightness_3,
                        AppLocalizations.of(context)?.paksha ?? 'Paksha',
                        '${panchang!.paksha} (${panchang!.isShukla ? (AppLocalizations.of(context)?.waxing ?? "Waxing") : (AppLocalizations.of(context)?.waning ?? "Waning")})',
                      ),
                      _buildInfoRow(
                        context,
                        Icons.calendar_today,
                        AppLocalizations.of(context)?.tithi ?? 'Tithi',
                        '${panchang!.tithiName} (T${panchang!.tithiNumber})',
                      ),
                    ] else ...[
                      // Generic info from festival object
                      _buildInfoRow(
                        context,
                        Icons.brightness_3,
                        AppLocalizations.of(context)?.paksha ?? 'Paksha',
                        festival.paksha,
                      ),
                      _buildInfoRow(
                        context,
                        Icons.calendar_today,
                        AppLocalizations.of(context)?.tithi ?? 'Tithi',
                        'Tithi ${festival.tithi}',
                      ),
                    ],
                    _buildInfoRow(
                      context,
                      Icons.category,
                      AppLocalizations.of(context)?.category ?? 'Category',
                      festival.category.isEmpty
                          ? (AppLocalizations.of(context)?.general ?? 'General')
                          : festival.category.toUpperCase(),
                    ),

                    // Rituals
                    if (festival.rituals.steps.isNotEmpty) ...[
                      const SizedBox(height: 24),
                      Text(
                        AppLocalizations.of(context)?.ritualsAndPractices ??
                            'Rituals & Practices',
                        style: context.textTheme.headlineMedium?.copyWith(
                          fontSize: 18,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: AppTheme.glassmorphism(
                          context: context,
                          opacity: 0.1,
                          ref: ref,
                        ),
                        child: Column(
                          children: festival.rituals.steps.asMap().entries.map((
                            entry,
                          ) {
                            final index = entry.key;
                            final ritual = entry.value;

                            // Create a stable ID for this ritual instance
                            // Format: YYYY-MM-DD_FestivalID_Index
                            // Format: YYYY-MM-DD_FestivalID_Index
                            // If panchang is null (search view), use a generic date prefix so it doesn't crash,
                            // or maybe just disable interactivity? For now let's use a dummy date.
                            final dateStr =
                                panchang?.date.toIso8601String().split(
                                  'T',
                                )[0] ??
                                'generic';
                            final ritualId = '${dateStr}_${festival.id}_$index';

                            return RitualChecklistWidget(
                              ritualId: ritualId,
                              label: ritual,
                            );
                          }).toList(),
                        ),
                      ),
                    ],

                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ],
          ),
        );
      },
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
