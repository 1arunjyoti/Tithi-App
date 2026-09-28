import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../../models/eclipse.dart';
import '../../../core/anim/stagger_entrance.dart';
import '../../../widgets/responsive_layout.dart';
import 'eclipse_card.dart';

/// Upcoming eclipses grouped into solar/lunar sections.
class EclipseList extends StatelessWidget {
  const EclipseList({super.key, required this.eclipses});

  final List<Eclipse> eclipses;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    if (eclipses.isEmpty) {
      return Center(child: Text(l10n.noUpcomingDates));
    }

    // Separate into solar and lunar
    final solarEclipses = eclipses.where((e) => e.type.isSolar).toList();
    final lunarEclipses = eclipses.where((e) => e.type.isLunar).toList();

    // Running stagger index across sections so solar → lunar flows as one
    // sequence. Few items total (eclipses are rare), so all animate.
    var staggerIndex = 0;
    return CenteredContent(
      maxWidth: 900,
      child: ListView(
        addRepaintBoundaries: false,
        padding: ResponsiveLayout.responsivePadding(context),
        children: [
          if (solarEclipses.isNotEmpty) ...[
            EclipseSectionHeader(
              title: l10n.solarEclipses,
              emoji: '☀️',
            ),
            const SizedBox(height: 12),
            for (final e in solarEclipses)
              StaggerEntrance(
                index: staggerIndex++,
                child: EclipseCard(eclipse: e),
              ),
            const SizedBox(height: 24),
          ],
          if (lunarEclipses.isNotEmpty) ...[
            EclipseSectionHeader(
              title: l10n.lunarEclipses,
              emoji: '🌙',
            ),
            const SizedBox(height: 12),
            for (final e in lunarEclipses)
              StaggerEntrance(
                index: staggerIndex++,
                child: EclipseCard(eclipse: e),
              ),
          ],
        ],
      ),
    );
  }
}

/// Emoji + title section header.
class EclipseSectionHeader extends StatelessWidget {
  const EclipseSectionHeader({
    super.key,
    required this.title,
    required this.emoji,
  });

  final String title;
  final String emoji;

  @override
  Widget build(BuildContext context) {
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
}
