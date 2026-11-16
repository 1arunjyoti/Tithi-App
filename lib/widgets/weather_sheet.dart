import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/weather_data.dart';
import '../providers/weather_provider.dart';
import '../models/panchang_data.dart';
import '../providers/panchang_provider.dart';
import '../providers/calendar_provider.dart';
import '../services/weather_service.dart';
import '../l10n/app_localizations.dart';
import '../utils/tithi_localization.dart';
import '../theme/app_typography.dart';
import '../theme/app_metrics.dart';
import 'state_views.dart';

class WeatherSheet extends ConsumerWidget {
  const WeatherSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final weatherAsync = ref.watch(currentWeatherProvider);
    // Also show sunrise/sunset as it was the entry point
    final selectedDate = ref.watch(selectedDateProvider);
    final panchangAsync = ref.watch(panchangForDateProvider(selectedDate));
    final panchang = panchangAsync.asData?.value;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.s24),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: AppRadius.sheetTop,
        border: Border(
          top: BorderSide(
            color: Theme.of(
              context,
            ).colorScheme.outlineVariant.withValues(alpha: 0.2),
          ),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(bottom: AppSpacing.s24),
            decoration: BoxDecoration(
              color: Theme.of(
                context,
              ).colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(AppRadius.micro),
            ),
          ),

          Text(
            l10n.weatherDetails,
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: AppTypography.bold),
          ),
          const SizedBox(height: AppSpacing.s24),

          weatherAsync.when(
            data: (result) {
              if (result == null) {
                return EmptyState(
                  icon: Icons.cloud_off_outlined,
                  title: l10n.weatherDataUnavailable,
                  variant: StateViewVariant.card,
                );
              }
              if (result is WeatherFailure) {
                return ErrorState(
                  message: l10n.errorMessage(result.error.message),
                  variant: StateViewVariant.card,
                );
              }
              final data = (result as WeatherSuccess).data;
              return _buildWeatherContent(context, data, panchang);
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, stack) {
              debugPrint('Weather load failed: $error');
              return ErrorState(
                message: l10n.weatherDataUnavailable,
                onRetry: () => ref.invalidate(currentWeatherProvider),
                variant: StateViewVariant.card,
              );
            },
          ),
          const SizedBox(height: AppSpacing.s24),
          Text(
            l10n.weatherDataByOpenMeteo,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.s8),
        ],
      ),
    );
  }

  Widget _buildWeatherContent(
    BuildContext context,
    WeatherData data,
    PanchangData? panchang,
  ) {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      '${data.temperature.round()}°',
                      style: const TextStyle(
                        fontSize: AppTypography.sizeGlyph,
                        fontWeight: AppTypography.bold,
                        height: 1,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.s8),
                    Semantics(
                      label: l10n.weatherCondition(data.conditionText),
                      child: Image.network(
                        data.conditionIcon,
                        width: 64,
                        height: 64,
                        errorBuilder: (_, _, _) =>
                            const Icon(Icons.wb_sunny, size: AppIconSize.empty),
                      ),
                    ),
                  ],
                ),
                Text(
                  data.conditionText,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),

            // Sunrise/Sunset info panel
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                _buildSunRow(
                  context,
                  Icons.wb_sunny_outlined,
                  l10n.sunrise,
                  panchang?.sunrise,
                ),
                const SizedBox(height: AppSpacing.s12),
                _buildSunRow(
                  context,
                  Icons.nightlight_round,
                  l10n.sunset,
                  panchang?.sunset,
                ),
                if (panchang?.sunrise != null && panchang?.sunset != null) ...[
                  const SizedBox(height: AppSpacing.s12),
                  _buildDaylightRow(
                    context,
                    panchang!.sunrise!,
                    panchang.sunset!,
                  ),
                ],
              ],
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.s32),

        // Grid of details
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildDetailItem(
              context,
              l10n.humidity,
              '${data.humidity}%',
              Icons.water_drop_outlined,
            ),
            _buildDetailItem(
              context,
              l10n.wind,
              '${data.windSpeed} kph',
              Icons.air,
            ),
            _buildDetailItem(
              context,
              l10n.realFeel,
              '${data.feelsLike.round()}°',
              Icons.thermostat,
            ),
            _buildDetailItem(
              context,
              l10n.uvIndex,
              '${data.uv}',
              Icons.wb_sunny,
            ),
          ],
        ),
        if (data.forecast.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.s32),
          Text(
            l10n.forecast,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: AppTypography.bold),
          ),
          const SizedBox(height: AppSpacing.s16),
          Row(
            children: data.forecast
                .map(
                  (f) => Expanded(
                    child: Container(
                      margin: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.s4,
                      ),
                      padding: const EdgeInsets.all(AppSpacing.s12),
                      decoration: BoxDecoration(
                        color: Theme.of(context)
                            .colorScheme
                            .surfaceContainerHighest
                            .withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(AppRadius.tile),
                      ),
                      child: Column(
                        children: [
                          Text(
                            formatLocalizedDate(f.date, 'EEE', l10n.localeName),
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(fontWeight: AppTypography.bold),
                          ),
                          const SizedBox(height: AppSpacing.s8),
                          Image.network(
                            f.conditionIcon,
                            width: 40,
                            height: 40,
                            errorBuilder: (_, _, _) => const Icon(
                              Icons.wb_sunny,
                              size: AppIconSize.hero,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.s8),
                          Text(
                            '${f.maxTemp.round()}° / ${f.minTemp.round()}°',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          const SizedBox(height: AppSpacing.s4),
                          Text(
                            f.conditionText,
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: AppTypography.sizeMicro,
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
        ],
      ],
    );
  }

  Widget _buildSunRow(
    BuildContext context,
    IconData icon,
    String label,
    DateTime? time,
  ) {
    final timeStr = time != null
        ? TimeOfDay.fromDateTime(time).format(context)
        : '--:--';

    return Row(
      children: [
        Icon(
          icon,
          size: AppIconSize.small,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: AppSpacing.s4),
        Text(
          '$label: $timeStr',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Widget _buildDaylightRow(
    BuildContext context,
    DateTime sunrise,
    DateTime sunset,
  ) {
    final l10n = AppLocalizations.of(context)!;
    final duration = sunset.difference(sunrise);
    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;

    return Row(
      children: [
        Icon(
          Icons.wb_twilight,
          size: AppIconSize.small,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: AppSpacing.s4),
        Text(
          l10n.daylightDuration(hours, minutes),
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Widget _buildDetailItem(
    BuildContext context,
    String label,
    String value,
    IconData icon,
  ) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(AppSpacing.s12),
          decoration: BoxDecoration(
            color: Theme.of(
              context,
            ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: Theme.of(context).colorScheme.primary),
        ),
        const SizedBox(height: AppSpacing.s8),
        Text(value, style: const TextStyle(fontWeight: AppTypography.bold)),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            fontSize: AppTypography.sizeMicro,
          ),
        ),
      ],
    );
  }
}
