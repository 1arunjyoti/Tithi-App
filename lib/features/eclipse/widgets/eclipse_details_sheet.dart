import 'package:material_ui/material_ui.dart';
import 'package:intl/intl.dart';

import '../../../l10n/app_localizations.dart';
import '../../../models/eclipse.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/app_metrics.dart';
import '../../../theme/app_typography.dart';
import '../../../widgets/app_bottom_sheet.dart';
import '../../../widgets/app_divider.dart';
import '../../../features/sheets/widgets/info_row.dart';

/// Presents the eclipse details bottom sheet.
void showEclipseDetailsSheet(BuildContext context, Eclipse eclipse) {
  final l10n = AppLocalizations.of(context)!;
  final isHindi = Localizations.localeOf(context).languageCode == 'hi';
  final maximum = eclipse.maxEclipseTime.toLocal();

  AppBottomSheet.show<void>(
    context,
    builder: (_) => SingleChildScrollView(
      primary: true,
      padding: const EdgeInsets.all(AppSpacing.s24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        // Stretch so the section rules span the full content width; the rows
        // own their own internal alignment.
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Title(
            icon: eclipse.type.icon,
            title: isHindi
                ? eclipse.type.displayNameHi
                : eclipse.type.displayName,
          ),
          const SizedBox(height: AppSpacing.s20),
          ..._detailRows(context, eclipse, l10n, maximum),
          const SizedBox(height: AppSpacing.s24),
        ],
      ),
    ),
  );
}

/// Heading icon + title. The glyph keeps its intrinsic width and never wraps:
/// constraining it to the row-icon slot made it break into several lines at
/// large text scales. The 12dp gap is explicit so the title always reads as a
/// separate column from the glyph.
class _Title extends StatelessWidget {
  const _Title({required this.icon, required this.title});

  final String icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          icon,
          softWrap: false,
          overflow: TextOverflow.visible,
          style: const TextStyle(fontSize: AppTypography.sizeHero),
        ),
        const SizedBox(width: AppSpacing.s12),
        Expanded(
          child: Text(
            title,
            style: Theme.of(context).textTheme.headlineSmall
                ?.copyWith(fontWeight: AppTypography.bold),
          ),
        ),
      ],
    );
  }
}

/// Builds the detail rows with one rhythm: 12dp between rows in a section,
/// 16dp on either side of a section rule. The pending gap is replaced (not
/// stacked) by a divider so the space above and below it always matches.
List<Widget> _detailRows(
  BuildContext context,
  Eclipse eclipse,
  AppLocalizations l10n,
  DateTime maximum,
) {
  final rows = <Widget>[];
  var gap = 0.0;

  void addRow(Widget row) {
    if (gap > 0) rows.add(SizedBox(height: gap));
    rows.add(row);
    gap = AppSpacing.s12;
  }

  void addDivider() {
    if (rows.isNotEmpty) rows.add(const SizedBox(height: AppSpacing.s16));
    rows.add(const AppDivider());
    rows.add(const SizedBox(height: AppSpacing.s16));
    gap = 0; // the rule already owns the space below it
  }

  addRow(
    buildInfoRow(
      context,
      Icons.calendar_today,
      l10n.date,
      DateFormat.yMMMd().format(maximum),
      dense: true,
    ),
  );
  addRow(
    buildInfoRow(
      context,
      Icons.access_time,
      l10n.maxEclipse,
      DateFormat.jm().format(maximum),
      dense: true,
    ),
  );

  if (eclipse.partialStart != null) {
    addRow(
      buildInfoRow(
        context,
        Icons.play_arrow,
        l10n.partialBegins,
        DateFormat.jm().format(eclipse.partialStart!.toLocal()),
        dense: true,
      ),
    );
  }
  if (eclipse.totalStart != null) {
    addRow(
      buildInfoRow(
        context,
        Icons.brightness_7,
        l10n.totalityBegins,
        DateFormat.jm().format(eclipse.totalStart!.toLocal()),
        dense: true,
      ),
    );
  }
  if (eclipse.totalEnd != null) {
    addRow(
      buildInfoRow(
        context,
        Icons.brightness_5,
        l10n.totalityEnds,
        DateFormat.jm().format(eclipse.totalEnd!.toLocal()),
        dense: true,
      ),
    );
  }
  if (eclipse.partialEnd != null) {
    addRow(
      buildInfoRow(
        context,
        Icons.stop,
        l10n.partialEnds,
        DateFormat.jm().format(eclipse.partialEnd!.toLocal()),
        dense: true,
      ),
    );
  }

  if (eclipse.totalDuration != null) {
    addDivider();
    addRow(
      buildInfoRow(
        context,
        Icons.timer,
        l10n.duration,
        _formatDuration(eclipse.totalDuration!),
        dense: true,
      ),
    );
  }

  addDivider();
  addRow(_visibilityRow(context, l10n, eclipse.visibleAtLocation));
  return rows;
}

/// Same icon + gap + body-medium metrics as the dense info rows, so the
/// visibility message starts on the same text column as every label above it.
Widget _visibilityRow(
  BuildContext context,
  AppLocalizations l10n,
  bool visible,
) {
  final color = visible
      ? AppTheme.success(Theme.of(context).brightness == Brightness.dark)
      : context.hintInk;
  return Row(
    children: [
      Icon(
        visible ? Icons.visibility : Icons.visibility_off,
        size: AppIconSize.medium,
        color: color,
      ),
      const SizedBox(width: AppSpacing.s12),
      Expanded(
        child: Text(
          visible
              ? l10n.visibleFromYourLocation
              : l10n.notVisibleFromYourLocation,
          style: context.textTheme.bodyMedium?.copyWith(
            color: color,
            fontWeight: AppTypography.medium,
          ),
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
