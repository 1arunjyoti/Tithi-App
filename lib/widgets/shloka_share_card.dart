import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/shloka.dart';
import '../theme/app_theme.dart';

/// A single translation paragraph for the share image.
class ShlokaShareTranslation {
  final String text;
  final bool isHindi;

  const ShlokaShareTranslation(this.text, {required this.isHindi});
}

/// Standalone branded card for image sharing, mirroring [FestivalShareCard].
///
/// Rendered off-screen via `ScreenshotController.captureFromWidget`, so it
/// carries its own opaque gradient background and Tithi branding instead of
/// the on-screen glassmorphism (which needs the home background behind it).
/// Height wraps content; width clamps like the festival card.
class ShlokaShareCard extends StatelessWidget {
  final Shloka shloka;
  final List<ShlokaShareTranslation> translations;

  const ShlokaShareCard({
    super.key,
    required this.shloka,
    this.translations = const [],
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textTheme = context.textTheme;

    return LayoutBuilder(
      builder: (context, constraints) {
        final cardWidth = constraints.hasBoundedWidth
            ? constraints.maxWidth.clamp(280.0, 520.0).toDouble()
            : 400.0;

        return SizedBox(
          width: cardWidth,
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
                  padding: const EdgeInsets.all(28),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.auto_stories_rounded,
                        size: 40,
                        color: colors.primary,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'DAILY WISDOM',
                        style: textTheme.labelMedium?.copyWith(
                          color: colors.primary,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 2,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        shloka.text,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.martel(
                          fontSize: 20,
                          height: 1.6,
                          fontWeight: FontWeight.w600,
                          color: colors.onSurface,
                        ),
                      ),
                      if (shloka.transliteration.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Text(
                          shloka.transliteration,
                          textAlign: TextAlign.center,
                          style: textTheme.bodySmall?.copyWith(
                            color: colors.onSurface.withValues(alpha: 0.6),
                            fontStyle: FontStyle.italic,
                            height: 1.4,
                          ),
                        ),
                      ],
                      for (final translation in translations) ...[
                        const SizedBox(height: 14),
                        Text(
                          translation.text,
                          textAlign: TextAlign.center,
                          style: translation.isHindi
                              ? GoogleFonts.martel(
                                  fontSize: 16,
                                  height: 1.5,
                                  fontWeight: FontWeight.w500,
                                  color: colors.onSurface.withValues(
                                    alpha: 0.9,
                                  ),
                                )
                              : textTheme.bodyMedium?.copyWith(
                                  color: colors.onSurface.withValues(
                                    alpha: 0.8,
                                  ),
                                  fontStyle: FontStyle.italic,
                                  height: 1.4,
                                ),
                        ),
                      ],
                      const SizedBox(height: 14),
                      Text(
                        "— ${shloka.source}",
                        textAlign: TextAlign.center,
                        style: textTheme.labelMedium?.copyWith(
                          color: colors.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (shloka.themes.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Text(
                          shloka.themes.map((t) => '#$t').join('  '),
                          textAlign: TextAlign.center,
                          style: textTheme.labelSmall?.copyWith(
                            color: colors.primary.withValues(alpha: 0.8),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                      const SizedBox(height: 20),
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
                            'TITHI',
                            style: textTheme.titleMedium?.copyWith(
                              color: colors.primary,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.5,
                            ),
                          ),
                        ],
                      ),
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
