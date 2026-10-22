import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:tithi/features/ai/domain/ai_app_target.dart';
import 'package:tithi/features/ai/providers/ai_providers.dart';
import 'package:tithi/features/ai/widgets/ai_section.dart';
import 'package:tithi/services/ai_handoff_service.dart';
import 'package:tithi/services/storage_service.dart';

/// The AI settings group: the app picker only exists where a direct open can
/// work, and an assistant that cannot take the hand-off is shown as such
/// instead of being offered as a working choice.
void main() {
  setUp(() async {
    final tempDir = await Directory.systemTemp.createTemp('ai_section_test');
    Hive.init(tempDir.path);
    await StorageService().init();
  });

  tearDown(() async {
    await Hive.close();
  });

  Future<void> pumpSection(
    WidgetTester tester, {
    bool directOpen = false,
    Set<String> installed = const <String>{},
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          aiDirectOpenSupportedProvider.overrideWithValue(directOpen),
          aiHandoffServiceProvider.overrideWithValue(
            _AvailabilityHandoff(installed),
          ),
        ],
        child: const MaterialApp(home: Scaffold(body: AiSection())),
      ),
    );
    await tester.pumpAndSettle();
  }

  Finder inDialog(Finder matching) => find.descendant(
    of: find.byType(AlertDialog),
    matching: matching,
  );

  testWidgets('the app picker is hidden where no app can be opened directly', (
    tester,
  ) async {
    await pumpSection(tester);

    expect(find.text('AI app'), findsNothing);
    expect(find.text('AI assist'), findsOneWidget);
    expect(find.text('How it works'), findsOneWidget);
  });

  testWidgets('the app picker lists assistants with their availability', (
    tester,
  ) async {
    await pumpSection(tester, directOpen: true, installed: {'gemini'});

    expect(find.text('AI app'), findsOneWidget);
    await tester.tap(find.text('AI app'));
    await tester.pumpAndSettle();

    final tiles = tester
        .widgetList<ListTile>(inDialog(find.byType(ListTile)))
        .toList();

    // Automatic is always a real choice; the six named apps follow.
    expect(tiles, hasLength(kAiAppTargets.length + 1));
    expect(tiles.first.onTap, isNotNull);
    expect(tiles.first.enabled, isTrue);

    final gemini = tiles[1];
    expect(gemini.onTap, isNotNull);
    expect(gemini.subtitle, isNull);
    for (final missing in tiles.skip(2)) {
      expect(missing.onTap, isNull);
      expect(missing.enabled, isFalse);
      expect(
        (missing.subtitle! as Text).data,
        'Not installed',
        reason: 'an app that cannot resolve the intent must say so',
      );
    }

    expect(
      inDialog(find.text('Not installed')),
      findsNWidgets(kAiAppTargets.length - 1),
    );
  });
}

/// Reports availability without touching a platform channel, so the picker can
/// be exercised on the host too.
class _AvailabilityHandoff extends AiHandoffService {
  const _AvailabilityHandoff(this.installed);

  final Set<String> installed;

  @override
  Future<bool> canOpen(AiAppTarget target) async => installed.contains(target.id);
}
