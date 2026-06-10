import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../l10n/app_localizations.dart';
import '../models/festival.dart';
import '../models/panchang_data.dart';
import '../providers/panchang_provider.dart';
import '../theme/app_theme.dart';
import '../services/share_service.dart';
import 'ritual_checklist_widget.dart';

/// Bottom sheet showing festival details with glassmorphism
class EventDetailSheet extends ConsumerWidget {
  final Festival festival;
  final PanchangData? panchang;

  const EventDetailSheet({super.key, required this.festival, this.panchang});

  // Parse a hex color string like '#FF5733' or 'FF5733' to a Color
  Color? _parseThemeColor(String hex) {
    if (hex.isEmpty) return null;
    try {
      final clean = hex.replaceAll('#', '');
      if (clean.length == 6) {
        return Color(int.parse('FF$clean', radix: 16));
      } else if (clean.length == 8) {
        return Color(int.parse(clean, radix: 16));
      }
    } catch (_) {}
    return null;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeColor =
        _parseThemeColor(festival.visuals.themeColor) ?? context.colors.primary;

    // Gather non-null, non-empty regional names
    final regionalNames = <String>[];
    if (festival.nameRegional.nameBengali?.isNotEmpty == true) {
      regionalNames.add(festival.nameRegional.nameBengali!);
    }
    if (festival.nameRegional.nameTelugu?.isNotEmpty == true) {
      regionalNames.add(festival.nameRegional.nameTelugu!);
    }
    if (festival.nameRegional.nameKannada?.isNotEmpty == true) {
      regionalNames.add(festival.nameRegional.nameKannada!);
    }
    if (festival.nameRegional.nameTamil?.isNotEmpty == true) {
      regionalNames.add(festival.nameRegional.nameTamil!);
    }
    if (festival.nameRegional.nameMalayalam?.isNotEmpty == true) {
      regionalNames.add(festival.nameRegional.nameMalayalam!);
    }

    final hasAdditionalDesc = festival.purpose.additionalDescription.isNotEmpty;
    final hasFasting =
        festival.rituals.fasting != null &&
        festival.rituals.fasting!.isNotEmpty;
    final hasMantra = festival.rituals.mantra.isNotEmpty;

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
              // Drag handle with theme color tint
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: themeColor.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              // Content
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.all(24),
                  children: [
                    // Festival name and Share button
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            festival.name,
                            style: context.textTheme.headlineLarge?.copyWith(
                              fontSize: 28,
                              color: themeColor,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: () =>
                              ShareService().shareFestival(context, festival),
                          icon: const Icon(Icons.share_outlined),
                          color: themeColor,
                          tooltip: 'Share Card',
                        ),
                      ],
                    ),

                    // Hindi name
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

                    // Regional names as chips
                    if (regionalNames.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: regionalNames
                            .map(
                              (name) => Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: themeColor.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: themeColor.withValues(alpha: 0.3),
                                  ),
                                ),
                                child: Text(
                                  name,
                                  style: context.textTheme.bodySmall?.copyWith(
                                    color: themeColor,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            )
                            .toList(),
                      ),
                    ],
                    const SizedBox(height: 16),

                    // Description
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: AppTheme.glassmorphism(
                        context: context,
                        ref: ref,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            festival.description,
                            style: context.textTheme.bodyLarge?.copyWith(
                              fontSize: 16,
                              height: 1.5,
                            ),
                          ),
                          if (hasAdditionalDesc) ...[
                            const SizedBox(height: 12),
                            Divider(
                              color: context.colors.onSurface.withValues(
                                alpha: 0.15,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              festival.purpose.additionalDescription,
                              style: context.textTheme.bodyMedium?.copyWith(
                                fontSize: 14,
                                height: 1.5,
                                color: context.colors.onSurface.withValues(
                                  alpha: 0.8,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Fasting / Vrat info
                    if (hasFasting) ...[
                      _buildSectionHeader(
                        context,
                        icon: Icons.self_improvement,
                        label: 'Fasting / Vrat',
                        color: themeColor,
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: AppTheme.glassmorphism(
                          context: context,
                          ref: ref,
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.restaurant_outlined,
                              color: themeColor,
                              size: 20,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                festival.rituals.fasting!,
                                style: context.textTheme.bodyMedium?.copyWith(
                                  height: 1.5,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],

                    // Panchang info
                    _buildSectionHeader(
                      context,
                      icon: Icons.auto_awesome,
                      label:
                          AppLocalizations.of(context)?.panchangDetails ??
                          'Panchang Details',
                      color: themeColor,
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
                      // Masa (Hindu month)
                      if (panchang!.masa.isNotEmpty)
                        _buildInfoRow(
                          context,
                          Icons.wb_sunny_outlined,
                          'Masa',
                          panchang!.masa
                              .replaceAll('_', ' ')
                              .split(' ')
                              .map(
                                (w) => w.isEmpty
                                    ? w
                                    : '${w[0].toUpperCase()}${w.substring(1)}',
                              )
                              .join(' '),
                        ),

                      // Tithi Timings using user's location
                      Consumer(
                        builder: (context, ref, child) {
                          final coords = ref.watch(resolvedCoordinatesProvider);
                          final timingsAsync = ref.watch(
                            tithiTimingsProvider((
                              date: panchang!.date,
                              tithiNumber: panchang!.tithiNumber,
                              latitude: coords.latitude,
                              longitude: coords.longitude,
                            )),
                          );

                          return timingsAsync.when(
                            data: (timings) {
                              final dateFormat = DateFormat('h:mm a, MMM d');
                              final startStr = dateFormat.format(timings.start);
                              final endStr = dateFormat.format(timings.end);

                              return Column(
                                children: [
                                  _buildInfoRow(
                                    context,
                                    Icons.access_time,
                                    'Begins',
                                    startStr,
                                  ),
                                  _buildInfoRow(
                                    context,
                                    Icons.access_time_filled,
                                    'Ends',
                                    endStr,
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
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                ),
                              ),
                            ),
                            error: (err, stack) => const SizedBox.shrink(),
                          );
                        },
                      ),
                    ] else ...[
                      // Generic info from festival object when no panchang available
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
                      // Masa from festival rules
                      if (festival.masa.isNotEmpty && festival.masa != '*')
                        _buildInfoRow(
                          context,
                          Icons.wb_sunny_outlined,
                          'Masa',
                          festival.masa
                              .replaceAll('_', ' ')
                              .split(' ')
                              .map(
                                (w) => w.isEmpty
                                    ? w
                                    : '${w[0].toUpperCase()}${w.substring(1)}',
                              )
                              .join(' '),
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
                      _buildSectionHeader(
                        context,
                        icon: Icons.checklist_rounded,
                        label:
                            AppLocalizations.of(context)?.ritualsAndPractices ??
                            'Rituals & Practices',
                        color: themeColor,
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: AppTheme.glassmorphism(
                          context: context,
                          ref: ref,
                        ),
                        child: Column(
                          children: festival.rituals.steps.asMap().entries.map((
                            entry,
                          ) {
                            final index = entry.key;
                            final ritual = entry.value;

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

                    // Mantra section
                    if (hasMantra) ...[
                      const SizedBox(height: 24),
                      _buildSectionHeader(
                        context,
                        icon: Icons.record_voice_over_outlined,
                        label: 'Mantra',
                        color: themeColor,
                      ),
                      const SizedBox(height: 12),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration:
                            AppTheme.glassmorphism(
                              context: context,
                              ref: ref,
                            ).copyWith(
                              border: Border.all(
                                color: themeColor.withValues(alpha: 0.25),
                              ),
                            ),
                        child: Text(
                          festival.rituals.mantra,
                          style: context.textTheme.bodyLarge?.copyWith(
                            fontFamily: 'serif',
                            fontSize: 15,
                            height: 1.8,
                            color: themeColor,
                          ),
                          textAlign: TextAlign.center,
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

  /// Builds a section header row with an icon, label, and a subtle divider line
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
        Text(
          label,
          style: context.textTheme.headlineMedium?.copyWith(
            fontSize: 18,
            color: color,
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
