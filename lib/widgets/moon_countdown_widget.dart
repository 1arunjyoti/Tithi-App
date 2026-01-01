import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/moon_phase_provider.dart';
import '../screens/moon_phases_screen.dart';
import '../l10n/app_localizations.dart';

/// Compact widget showing countdown to next Amavasya and Purnima
/// Designed for integration into the home screen
class MoonCountdownWidget extends ConsumerStatefulWidget {
  const MoonCountdownWidget({super.key});

  @override
  ConsumerState<MoonCountdownWidget> createState() =>
      _MoonCountdownWidgetState();
}

class _MoonCountdownWidgetState extends ConsumerState<MoonCountdownWidget> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    // Update countdown every minute
    _timer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final moonPhaseAsync = ref.watch(moonPhaseDataProvider);
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return GestureDetector(
      onTap: () {
        Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (_) => const MoonPhasesScreen()));
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
                ? [
                    Colors.indigo.shade900.withValues(alpha: 0.6),
                    Colors.deepPurple.shade900.withValues(alpha: 0.4),
                  ]
                : [
                    Colors.amber.shade100.withValues(alpha: 0.8),
                    Colors.orange.shade50.withValues(alpha: 0.6),
                  ],
          ),
          border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.1)
                : Colors.amber.shade200.withValues(alpha: 0.5),
          ),
          boxShadow: [
            BoxShadow(
              color: isDark
                  ? Colors.black.withValues(alpha: 0.3)
                  : Colors.amber.withValues(alpha: 0.2),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: moonPhaseAsync.when(
          data: (data) => _buildContent(context, data, l10n, isDark),
          loading: () => const Center(
            child: SizedBox(
              height: 60,
              child: CircularProgressIndicator.adaptive(),
            ),
          ),
          error: (e, _) => Center(
            child: Text(
              'Unable to load moon phase data',
              style: theme.textTheme.bodyMedium,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    dynamic data,
    AppLocalizations l10n,
    bool isDark,
  ) {
    final theme = Theme.of(context);

    return Row(
      children: [
        // Moon icon
        Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: isDark
                  ? [Colors.grey.shade300, Colors.grey.shade600]
                  : [Colors.amber.shade200, Colors.orange.shade300],
            ),
            boxShadow: [
              BoxShadow(
                color: isDark
                    ? Colors.indigo.withValues(alpha: 0.5)
                    : Colors.amber.withValues(alpha: 0.5),
                blurRadius: 16,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Icon(
            data.isShukla ? Icons.brightness_3 : Icons.brightness_2,
            color: isDark ? Colors.indigo.shade900 : Colors.orange.shade800,
            size: 32,
          ),
        ),
        const SizedBox(width: 16),
        // Countdown info
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Next Purnima
              _CountdownRow(
                label: l10n.nextPurnima,
                countdown: data.purnimaCountdown,
                icon: Icons.circle,
                iconColor: isDark ? Colors.amber : Colors.orange.shade600,
              ),
              const SizedBox(height: 8),
              // Next Amavasya
              _CountdownRow(
                label: l10n.nextAmavasya,
                countdown: data.amavasyaCountdown,
                icon: Icons.circle_outlined,
                iconColor: isDark ? Colors.grey.shade400 : Colors.grey.shade700,
              ),
            ],
          ),
        ),
        // Chevron
        Icon(
          Icons.chevron_right,
          color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
        ),
      ],
    );
  }
}

class _CountdownRow extends StatelessWidget {
  const _CountdownRow({
    required this.label,
    required this.countdown,
    required this.icon,
    required this.iconColor,
  });

  final String label;
  final Duration countdown;
  final IconData icon;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      children: [
        Icon(icon, size: 14, color: iconColor),
        const SizedBox(width: 6),
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
          ),
        ),
        const Spacer(),
        Text(
          _formatCountdown(countdown),
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.onSurface,
          ),
        ),
      ],
    );
  }

  String _formatCountdown(Duration duration) {
    if (duration.isNegative) {
      return 'Now';
    }

    final days = duration.inDays;
    final hours = duration.inHours % 24;

    if (days > 0) {
      return '${days}d ${hours}h';
    } else {
      final minutes = duration.inMinutes % 60;
      return '${hours}h ${minutes}m';
    }
  }
}
