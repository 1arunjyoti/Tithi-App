import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tithi/widgets/calendar_day_semantics.dart';

void main() {
  group('CalendarDaySemantics', () {
    testWidgets('collapses the tile into one labelled button', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: CalendarDaySemantics(
              dayLabel: '15',
              detail: 'Shukla Ashtami',
              isToday: true,
              isSelected: true,
              child: Text('15'),
            ),
          ),
        ),
      );

      expect(
        tester.getSemantics(find.byType(CalendarDaySemantics)),
        matchesSemantics(
          label: '15, Shukla Ashtami, Today, Selected',
          isButton: true,
          hasSelectedState: true,
          isSelected: true,
        ),
      );

      handle.dispose();
    });

    testWidgets('drops state words for a plain day', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: CalendarDaySemantics(dayLabel: '16', child: Text('16')),
          ),
        ),
      );

      expect(
        tester.getSemantics(find.byType(CalendarDaySemantics)),
        matchesSemantics(label: '16', isButton: true, hasSelectedState: true),
      );

      handle.dispose();
    });

    testWidgets('uses the localized state words', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: CalendarDaySemantics(
              dayLabel: '১',
              detail: 'শুক্লা অষ্টমী',
              isToday: true,
              todayLabel: 'আজ',
              child: Text('১'),
            ),
          ),
        ),
      );

      expect(
        tester.getSemantics(find.byType(CalendarDaySemantics)).label,
        '১, শুক্লা অষ্টমী, আজ',
      );

      handle.dispose();
    });
  });
}
