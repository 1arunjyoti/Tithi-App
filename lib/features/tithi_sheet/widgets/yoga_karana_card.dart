import 'package:flutter/material.dart';

import '../../../theme/app_theme.dart';

/// Runs of [text] matching [emphasis] render in full onSurface while the
/// rest stays in [style] (dim). Used for the Yoga/Karana sublines so the
/// time portion ("3:42 PM, Oct 5") is never dimmed, regardless of each
/// language's word order. Falls back to plain dim text when [emphasis] is
/// null or absent.
class EmphasizedText extends StatelessWidget {
  const EmphasizedText({super.key, 
    required this.text,
    required this.emphasis,
    required this.style,
  });

  final String text;
  final String? emphasis;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    final e = emphasis;
    if (e == null || e.isEmpty || !text.contains(e)) {
      return Text(text, style: style);
    }
    final parts = text.split(e);
    final children = <InlineSpan>[];
    for (var i = 0; i < parts.length; i++) {
      if (parts[i].isNotEmpty) children.add(TextSpan(text: parts[i]));
      if (i < parts.length - 1) {
        children.add(
          TextSpan(
            text: e,
            style: TextStyle(color: context.colors.onSurface),
          ),
        );
      }
    }
    return Text.rich(TextSpan(style: style, children: children));
  }
}

/// Side-by-side Yoga/Karana card in the tithi-timings visual language:
/// border-tone outer background with a center divider, surface cells each
/// holding a primary icon, a dim letterspaced label, a bold onSurface name,
/// and an "until {time}, then {next}" subline whose time portion stays
/// undimmed ([yogaTime]/[karanaTime]). Null values render a spinner in
/// place (loading state).
class YogaKaranaCard extends StatelessWidget {
  const YogaKaranaCard({super.key, 
    required this.yogaLabel,
    required this.karanaLabel,
    this.yogaValue,
    this.yogaSubline,
    this.yogaTime,
    this.karanaValue,
    this.karanaSubline,
    this.karanaTime,
    required this.highContrast,
  });

  final String yogaLabel;
  final String karanaLabel;
  final String? yogaValue;
  final String? yogaSubline;
  final String? yogaTime;
  final String? karanaValue;
  final String? karanaSubline;
  final String? karanaTime;
  final bool highContrast;

  @override
  Widget build(BuildContext context) {
    final border = context.colors.onSurface.withValues(
      alpha: highContrast ? 0.2 : 0.1,
    );
    Widget cell({
      required IconData icon,
      required String label,
      String? value,
      String? subline,
      String? highlight,
    }) {
      return Expanded(
        child: Container(
          color: Theme.of(context).cardTheme.color ?? context.colors.surface,
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Icon(icon, size: 16, color: context.colors.primary),
                  const SizedBox(width: 6),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 10.5,
                      letterSpacing: 1.0,
                      fontWeight: FontWeight.w600,
                      color: context.colors.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              if (value == null)
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: context.colors.onSurface,
                  ),
                ),
              if (subline != null) ...[
                const SizedBox(height: 2),
                EmphasizedText(
                  text: subline,
                  emphasis: highlight,
                  style: TextStyle(
                    fontSize: 13,
                    color: context.colors.onSurface.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ],
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: border,
        borderRadius: BorderRadius.circular(16),
      ),
      clipBehavior: Clip.antiAlias,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            cell(
              icon: Icons.star_outline,
              label: yogaLabel,
              value: yogaValue,
              subline: yogaSubline,
              highlight: yogaTime,
            ),
            Container(width: 1, color: border),
            cell(
              icon: Icons.timelapse,
              label: karanaLabel,
              value: karanaValue,
              subline: karanaSubline,
              highlight: karanaTime,
            ),
          ],
        ),
      ),
    );
  }
}
