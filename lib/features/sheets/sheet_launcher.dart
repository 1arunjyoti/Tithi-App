import 'package:flutter/material.dart';

import '../../models/festival.dart';
import '../../models/panchang_data.dart';
import '../../theme/app_theme.dart';
import '../../widgets/event_detail_sheet.dart';
import '../../widgets/tithi_detail_sheet.dart';

/// Single entry point for the two day-detail sheets.
///
/// Every caller used to repeat the same modal options by hand. Owning them
/// here means a new entry point — including the sheet-to-sheet links added
/// on top of this kit — cannot accidentally drop scroll control, the
/// transparent background (the sheets paint their own hero header) or the
/// Reduce-Motion-aware animation style.
///
/// [useRootNavigator] is deliberately left at its default (`false`): sheets
/// stay on the navigator that owns the caller's context, which is the
/// existing behaviour. Flipping it here would change back-button and
/// dismissal semantics for every current entry point.
Future<void> showTithiDetailSheet(
  BuildContext context, {
  required PanchangData panchang,
}) async {
  await showModalBottomSheet<void>(
    context: context,
    sheetAnimationStyle: AppTheme.sheetAnimationStyleOf(context),
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => TithiDetailSheet(panchang: panchang),
  );
}

/// Opens the festival detail sheet.
///
/// [panchang] is optional because several entry points only know the
/// festival. Pass [date] (the occurrence date) in that case and the sheet
/// resolves the day's panchang itself; without either it keeps the
/// rules-only layout.
///
/// [fromTithiSheet] marks a festival sheet opened from the tithi sheet, so
/// its "View full panchang" link pops back to the sheet underneath instead
/// of stacking a second copy of the same day.
Future<void> showEventDetailSheet(
  BuildContext context, {
  required Festival festival,
  PanchangData? panchang,
  DateTime? date,
  bool fromTithiSheet = false,
}) async {
  await showModalBottomSheet<void>(
    context: context,
    sheetAnimationStyle: AppTheme.sheetAnimationStyleOf(context),
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => EventDetailSheet(
      festival: festival,
      panchang: panchang,
      date: date,
      openedFromTithiSheet: fromTithiSheet,
    ),
  );
}
