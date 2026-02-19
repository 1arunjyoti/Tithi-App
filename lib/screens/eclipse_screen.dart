import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../l10n/app_localizations.dart';
import '../models/eclipse.dart';
import '../providers/eclipse_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/responsive_layout.dart';

/// Screen displaying upcoming eclipses
class EclipseScreen extends ConsumerWidget {
  const EclipseScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final eclipsesAsync = ref.watch(upcomingEclipsesProvider);
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(l10n.eclipses),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: RepaintBoundary(
        child: Container(
          decoration: AppTheme.backgroundDecoration(context),
          child: SafeArea(
            child: eclipsesAsync.when(
              data: (eclipses) => _buildEclipseList(context, ref, eclipses),
              loading: () =>
                  const Center(child: CircularProgressIndicator.adaptive()),
              error: (e, _) => Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.error_outline,
                      size: 48,
                      color: theme.colorScheme.error,
                    ),
                    const SizedBox(height: 16),
                    Text(l10n.errorLoadingData),
                    const SizedBox(height: 8),
                    ElevatedButton(
                      onPressed: () => ref.refresh(upcomingEclipsesProvider),
                      child: Text(l10n.retry),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEclipseList(
    BuildContext context,
    WidgetRef ref,
    List<Eclipse> eclipses,
  ) {
    final l10n = AppLocalizations.of(context)!;

    if (eclipses.isEmpty) {
      return Center(child: Text(l10n.noUpcomingDates));
    }

    // Separate into solar and lunar
    final solarEclipses = eclipses.where((e) => e.type.isSolar).toList();
    final lunarEclipses = eclipses.where((e) => e.type.isLunar).toList();

    return CenteredContent(
      maxWidth: 900,
      child: ListView(
        padding: ResponsiveLayout.responsivePadding(context),
        children: [
          if (solarEclipses.isNotEmpty) ...[
            _buildSectionHeader(context, l10n.solarEclipses, '☀️'),
            const SizedBox(height: 12),
            ...solarEclipses.map((e) => _buildEclipseCard(context, ref, e)),
            const SizedBox(height: 24),
          ],
          if (lunarEclipses.isNotEmpty) ...[
            _buildSectionHeader(context, l10n.lunarEclipses, '🌙'),
            const SizedBox(height: 12),
            ...lunarEclipses.map((e) => _buildEclipseCard(context, ref, e)),
          ],
        ],
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title, String emoji) {
    final theme = Theme.of(context);

    return Row(
      children: [
        Text(emoji, style: const TextStyle(fontSize: 24)),
        const SizedBox(width: 8),
        Text(
          title,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.onSurface,
          ),
        ),
      ],
    );
  }

  Widget _buildEclipseCard(
    BuildContext context,
    WidgetRef ref,
    Eclipse eclipse,
  ) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final isHindi = Localizations.localeOf(context).languageCode == 'hi';

    // Use theme-based colors for eclipse types
    final typeColor = eclipse.type.isSolar
        ? theme.colorScheme.primary
        : theme.colorScheme.secondary;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: AppTheme.glassmorphism(
        context: context,
        ref: ref,
        borderRadius: 16,
        border: Border.all(color: typeColor.withValues(alpha: 0.3)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _showEclipseDetails(context, eclipse),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Type and date row
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Eclipse type badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: typeColor.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        isHindi
                            ? eclipse.type.displayNameHi
                            : eclipse.type.displayName,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: typeColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const Spacer(),
                    // Days until
                    if (eclipse.daysUntil >= 0)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.1,
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          eclipse.daysUntil == 0
                              ? l10n.today
                              : '${eclipse.daysUntil} ${l10n.days}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),

                // Date and time
                Row(
                  children: [
                    Icon(
                      Icons.calendar_today,
                      size: 16,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      DateFormat.yMMMEd().format(
                        eclipse.maxEclipseTime.toLocal(),
                      ),
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(
                      Icons.access_time,
                      size: 16,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${l10n.maxEclipse}: ${DateFormat.jm().format(eclipse.maxEclipseTime.toLocal())}',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.7,
                        ),
                      ),
                    ),
                  ],
                ),

                // Visibility indicator
                if (eclipse.visibleAtLocation) ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Icon(
                        Icons.visibility,
                        size: 16,
                        color: Colors.green,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        l10n.visibleFromYourLocation,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: Colors.green,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      if (eclipse.localMagnitude != null) ...[
                        const SizedBox(width: 8),
                        Text(
                          '(${(eclipse.localMagnitude! * 100).toStringAsFixed(0)}%)',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: Colors.green,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showEclipseDetails(BuildContext context, Eclipse eclipse) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final isHindi = Localizations.localeOf(context).languageCode == 'hi';

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Title
            Row(
              children: [
                Text(eclipse.type.icon, style: const TextStyle(fontSize: 32)),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    isHindi
                        ? eclipse.type.displayNameHi
                        : eclipse.type.displayName,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Date and time
            _buildDetailRow(
              context,
              Icons.calendar_today,
              l10n.date,
              DateFormat.yMMMMEEEEd().format(eclipse.maxEclipseTime.toLocal()),
            ),
            const SizedBox(height: 12),
            _buildDetailRow(
              context,
              Icons.access_time,
              l10n.maxEclipse,
              DateFormat.jms().format(eclipse.maxEclipseTime.toLocal()),
            ),

            // Phase times
            if (eclipse.partialStart != null) ...[
              const SizedBox(height: 12),
              _buildDetailRow(
                context,
                Icons.play_arrow,
                l10n.partialBegins,
                DateFormat.jm().format(eclipse.partialStart!.toLocal()),
              ),
            ],
            if (eclipse.totalStart != null) ...[
              const SizedBox(height: 12),
              _buildDetailRow(
                context,
                Icons.brightness_7,
                l10n.totalityBegins,
                DateFormat.jm().format(eclipse.totalStart!.toLocal()),
              ),
            ],
            if (eclipse.totalEnd != null) ...[
              const SizedBox(height: 12),
              _buildDetailRow(
                context,
                Icons.brightness_5,
                l10n.totalityEnds,
                DateFormat.jm().format(eclipse.totalEnd!.toLocal()),
              ),
            ],
            if (eclipse.partialEnd != null) ...[
              const SizedBox(height: 12),
              _buildDetailRow(
                context,
                Icons.stop,
                l10n.partialEnds,
                DateFormat.jm().format(eclipse.partialEnd!.toLocal()),
              ),
            ],

            // Duration
            if (eclipse.totalDuration != null) ...[
              const SizedBox(height: 16),
              Divider(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.1),
              ),
              const SizedBox(height: 16),
              _buildDetailRow(
                context,
                Icons.timer,
                l10n.duration,
                _formatDuration(eclipse.totalDuration!),
              ),
            ],

            // Visibility
            const SizedBox(height: 16),
            Divider(color: theme.colorScheme.onSurface.withValues(alpha: 0.1)),
            const SizedBox(height: 16),
            Row(
              children: [
                Icon(
                  eclipse.visibleAtLocation
                      ? Icons.visibility
                      : Icons.visibility_off,
                  color: eclipse.visibleAtLocation ? Colors.green : Colors.grey,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    eclipse.visibleAtLocation
                        ? l10n.visibleFromYourLocation
                        : l10n.notVisibleFromYourLocation,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: eclipse.visibleAtLocation
                          ? Colors.green
                          : Colors.grey,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(
    BuildContext context,
    IconData icon,
    String label,
    String value,
  ) {
    final theme = Theme.of(context);

    return Row(
      children: [
        Icon(icon, size: 20, color: theme.colorScheme.primary),
        const SizedBox(width: 12),
        Text(
          '$label:',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
          ),
        ),
        const Spacer(),
        Text(
          value,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;

    if (hours > 0) {
      return '${hours}h ${minutes}m';
    }
    return '${minutes}m';
  }
}
