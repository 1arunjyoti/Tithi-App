import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../models/festival.dart';
import '../theme/app_theme.dart';

class FestivalShareCard extends StatelessWidget {
  final Festival festival;

  const FestivalShareCard({super.key, required this.festival});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = context.colors;
    final textTheme = context.textTheme;
    final tithiText = festival.tithi != 0
        ? '${festival.paksha} • ${l10n.tithi} ${festival.tithi}'
        : festival.paksha;

    return LayoutBuilder(
      builder: (context, constraints) {
        final cardWidth = constraints.hasBoundedWidth
            ? constraints.maxWidth.clamp(280.0, 520.0).toDouble()
            : 400.0;
        final cardHeight = constraints.hasBoundedHeight
            ? constraints.maxHeight.clamp(420.0, 900.0).toDouble()
            : cardWidth * 1.5;

        return SizedBox(
          width: cardWidth,
          height: cardHeight,
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  colors.surfaceContainerHighest.withValues(alpha: 0.95),
                  colors.surface,
                ],
              ),
            ),
            child: Stack(
              children: [
                Positioned(
                  top: -100,
                  left: -100,
                  child: Container(
                    width: 300,
                    height: 300,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: colors.primary.withValues(alpha: 0.08),
                    ),
                  ),
                ),
                Positioned(
                  bottom: -50,
                  right: -50,
                  child: Container(
                    width: 250,
                    height: 250,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: colors.secondary.withValues(alpha: 0.08),
                    ),
                  ),
                ),

                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      Icon(Icons.auto_awesome, size: 64, color: colors.primary),
                      const SizedBox(height: 24),

                      Text(
                        festival.name,
                        textAlign: TextAlign.center,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: colors.onSurface,
                          letterSpacing: 1.2,
                        ),
                      ),
                      if (festival.nameHindi != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          festival.nameHindi!,
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: textTheme.titleLarge?.copyWith(
                            color: colors.onSurface.withValues(alpha: 0.75),
                          ),
                        ),
                      ],
                      const SizedBox(height: 16),

                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: colors.surface.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(50),
                          border: Border.all(
                            color: colors.outline.withValues(alpha: 0.4),
                          ),
                        ),
                        child: Text(
                          tithiText,
                          style: textTheme.bodyMedium?.copyWith(
                            color: colors.onSurface,
                            fontWeight: FontWeight.w500,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      Expanded(
                        child: Center(
                          child: SingleChildScrollView(
                            child: Text(
                              festival.description,
                              textAlign: TextAlign.center,
                              style: textTheme.bodyLarge?.copyWith(
                                height: 1.6,
                                color: colors.onSurface.withValues(alpha: 0.85),
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 16),

                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.calendar_month,
                            color: colors.primary,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            l10n.appTitle,
                            style: textTheme.titleMedium?.copyWith(
                              color: colors.primary,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.5,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
