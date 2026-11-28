import 'package:material_ui/material_ui.dart';
import 'package:material_3_expressive/material_3_expressive.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tithi/theme/app_theme.dart';
import 'package:tithi/widgets/festival_filter_chip.dart';

/// The shared filter chip is an expressive filter chip in every palette, and
/// its tap still drives the caller's selection state.
void main() {
  for (final entry in {
    'Shukla': AppTheme.shuklaTheme,
    'Krishna': AppTheme.krishnaTheme,
    'Pure Dark': AppTheme.pureDarkTheme,
  }.entries) {
    testWidgets('expressive filter chip toggles (${entry.key})', (
      tester,
    ) async {
      var selected = false;
      await tester.pumpWidget(
        MaterialApp(
          theme: entry.value,
          home: Scaffold(
            body: Center(
              child: StatefulBuilder(
                builder: (context, setState) => FestivalFilterChip(
                  label: 'Major',
                  selected: selected,
                  onTap: () => setState(() => selected = true),
                ),
              ),
            ),
          ),
        ),
      );

      final chip = tester.widget<M3EChip>(find.byType(M3EChip));
      expect(chip.type, equals(M3EChipType.filter));
      expect(chip.selected, isFalse);

      await tester.tap(find.text('Major'));
      await tester.pumpAndSettle();

      expect(selected, isTrue);
      expect(tester.widget<M3EChip>(find.byType(M3EChip)).selected, isTrue);
    });
  }
}
