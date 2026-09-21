import 'package:flutter/material.dart';

import '../../../theme/app_theme.dart';

/// Nakshatra span card in the tithi-timings visual language: surface fill
/// (no tinted outline), bold onSurface headline ("Rohini until 3:42 PM"),
/// dim lord/elapsed subline, a slim progress bar for the elapsed share of
/// the span, and the upcoming mansion below it ("Next: Mrigashira at
/// 3:42 PM"). The NAKSHATRA caption lives in a [SectionHeader] above the
/// card. Null strings render a spinner (loading state); a null [progress]
/// hides the bar, a null [nextline] hides the upcoming line.
class NakshatraCard extends StatelessWidget {
  const NakshatraCard({super.key, 
    this.headline,
    this.subline,
    this.progress,
    this.nextline,
    required this.highContrast,
  });

  final String? headline;
  final String? subline;
  final double? progress;
  final String? nextline;
  final bool highContrast;

  @override
  Widget build(BuildContext context) {
    final track = context.colors.onSurface.withValues(
      alpha: highContrast ? 0.2 : 0.1,
    );
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color ?? context.colors.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: (headline == null)
          ? const Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  headline!,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: context.colors.onSurface,
                  ),
                ),
                if (subline != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subline!,
                    style: TextStyle(
                      fontSize: 13,
                      color: context.colors.onSurface.withValues(alpha: 0.7),
                    ),
                  ),
                ],
                if (progress != null) ...[
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: LinearProgressIndicator(
                      value: progress!.clamp(0.0, 1.0),
                      minHeight: 6,
                      backgroundColor: track,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        context.colors.primary,
                      ),
                    ),
                  ),
                ],
                if (nextline != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    nextline!,
                    style: TextStyle(
                      fontSize: 13,
                      color: context.colors.onSurface.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ],
            ),
    );
  }
}
