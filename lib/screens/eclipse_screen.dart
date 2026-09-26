import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../l10n/app_localizations.dart';
import '../providers/eclipse_provider.dart';
import '../theme/app_theme.dart';
import '../features/eclipse/widgets/eclipse_list.dart';

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
      body: Stack(
        children: [
          // Background - isolated in its own RepaintBoundary
          Positioned.fill(
            child: RepaintBoundary(
              child: Container(
                decoration: AppTheme.backgroundDecoration(context),
              ),
            ),
          ),
          SafeArea(
            child: eclipsesAsync.when(
              data: (eclipses) => EclipseList(eclipses: eclipses),
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
        ],
      ),
    );
  }

}
