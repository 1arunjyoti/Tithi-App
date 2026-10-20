import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:tithi/features/sheets/widgets/sheet_link_tile.dart';
import 'package:tithi/services/storage_service.dart';

/// Widget-level proof for the shared sheet link row added in Phase 1:
/// both detail sheets use it to link to each other, so its label,
/// supporting line, chevron and tap behavior are pinned here.
void main() {
  setUp(() async {
    final tempDir = await Directory.systemTemp.createTemp('sheet_kit_test');
    Hive.init(tempDir.path);
    await StorageService().init();
  });

  tearDown(() async {
    await Hive.close();
  });

  Future<void> pumpTile(
    WidgetTester tester, {
    required String label,
    String? supporting,
    required VoidCallback onTap,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: Padding(
              padding: const EdgeInsets.all(20),
              child: SheetLinkTile(
                icon: Icons.calendar_month_outlined,
                label: label,
                supporting: supporting,
                onTap: onTap,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('renders the label, supporting line and chevron', (tester) async {
    await pumpTile(
      tester,
      label: 'View full panchang',
      supporting: 'Wed, 21 Oct 2026',
      onTap: () {},
    );

    expect(find.text('View full panchang'), findsOneWidget);
    expect(find.text('Wed, 21 Oct 2026'), findsOneWidget);
    expect(find.byIcon(Icons.chevron_right_rounded), findsOneWidget);
    expect(find.byIcon(Icons.calendar_month_outlined), findsOneWidget);
  });

  testWidgets('omits the supporting line when none is supplied', (
    tester,
  ) async {
    await pumpTile(tester, label: 'View full panchang', onTap: () {});

    expect(find.text('View full panchang'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(SheetLinkTile),
        matching: find.byType(Text),
      ),
      findsOneWidget,
    );
  });

  testWidgets('fires onTap once', (tester) async {
    var taps = 0;
    await pumpTile(
      tester,
      label: 'View full panchang',
      supporting: 'Wed, 21 Oct 2026',
      onTap: () => taps++,
    );

    await tester.tap(find.byType(SheetLinkTile));
    await tester.pumpAndSettle();

    expect(taps, 1);
  });
}
