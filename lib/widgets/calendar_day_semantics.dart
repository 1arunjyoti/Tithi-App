import 'package:flutter/material.dart';

/// Screen-reader node for one calendar day tile.
///
/// The tile is painted from a day number, an optional corner tithi/festival
/// label and a colour state. Without this the reader walked the raw text nodes
/// ("15", then "Shukla Ashtami") and never learned that the cell is tappable,
/// that it is the selected day, or that it is today.
///
/// Collapses the visual children into one label (`15, Shukla Ashtami, today,
/// selected`) and exposes the button/selected state. The tap handler stays on
/// the calendar grid, so this adds no gesture of its own.
///
/// [isSelected] is passed through unconditionally, so every tile advertises a
/// selected state (unselected tiles read "not selected") - that is what makes
/// the grid navigable as a set of selectable cells rather than plain buttons.
class CalendarDaySemantics extends StatelessWidget {
  const CalendarDaySemantics({
    super.key,
    required this.dayLabel,
    required this.child,
    this.detail,
    this.isToday = false,
    this.isSelected = false,
    this.todayLabel = 'Today',
    this.selectedLabel = 'Selected',
  });

  /// Primary cell text: the day number (already localized and digit-mapped),
  /// or the tithi/festival name in the non-Gregorian calendar modes.
  final String dayLabel;

  /// Secondary corner label (tithi, festival), when the mode shows one.
  final String? detail;

  final bool isToday;
  final bool isSelected;

  /// Localized state words, so the label follows the app language.
  final String todayLabel;
  final String selectedLabel;

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final parts = <String>[
      dayLabel,
      if (detail != null && detail!.isNotEmpty) detail!,
      if (isToday) todayLabel,
      if (isSelected) selectedLabel,
    ];
    return Semantics(
      label: parts.join(', '),
      button: true,
      selected: isSelected,
      excludeSemantics: true,
      child: child,
    );
  }
}
