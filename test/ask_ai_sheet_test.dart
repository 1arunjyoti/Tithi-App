import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:tithi/features/ai/domain/ai_app_target.dart';
import 'package:tithi/features/ai/domain/ai_prompt.dart';
import 'package:tithi/features/ai/providers/ai_providers.dart';
import 'package:tithi/features/ai/widgets/ask_ai_sheet.dart';
import 'package:tithi/models/festival.dart';
import 'package:tithi/models/hindu_month_system.dart';
import 'package:tithi/models/panchang_data.dart';
import 'package:tithi/providers/calendar_provider.dart';
import 'package:tithi/providers/location_provider.dart';
import 'package:tithi/providers/panchang_provider.dart';
import 'package:tithi/services/ai_handoff_service.dart';
import 'package:tithi/services/auspicious_timings.dart';
import 'package:tithi/services/inauspicious_timings.dart';
import 'package:tithi/services/storage_service.dart';

/// Widget-level proof for the Ask AI sheet: the preview really is the payload
/// that gets copied, the question travels with it, and the month digest waits
/// for its panchang instead of sending an empty month.
void main() {
  // The sheet reads the month system (Amanta/Purnimant) from the settings box,
  // so the box has to exist even though no test writes to it.
  setUp(() async {
    final tempDir = await Directory.systemTemp.createTemp('ask_ai_sheet_test');
    Hive.init(tempDir.path);
    await StorageService().init();
  });

  tearDown(() async {
    await Hive.close();
  });

  PanchangData day({DateTime? date, String? festival}) {
    final on = date ?? DateTime(2026, 10, 24);
    return PanchangData(
      date: on,
      rawTithi: 3.2,
      tithiNumber: 3,
      tithiName: PanchangData.tithiNameFor(3, 'Shukla'),
      paksha: 'Shukla',
      masa: 'Ashwin',
      festivals: [
        if (festival != null)
          Festival.fromJson({
            'id': festival,
            'name': festival,
            'purpose': {'description': 'A festival.'},
          }),
      ],
      sunrise: DateTime(on.year, on.month, on.day, 6, 34),
      sunset: DateTime(on.year, on.month, on.day, 18, 12),
      nakshatra: 'Rohini',
    );
  }

  Future<void> pumpTrigger(
    WidgetTester tester, {
    AiIntent intent = AiIntent.todayPanchang,
    DateTime? month,
    AuspiciousTimings? timings,
    InauspiciousTimings? inauspicious,
    List<Override> overrides = const [],
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          cityNameProvider.overrideWithValue(const AsyncData('Pune')),
          aiDeviceTimeZoneProvider.overrideWith(
            (ref) async => 'Asia/Kolkata',
          ),
          // The host is not Android, but these tests exercise the Android
          // experience (named apps in the primary action).
          aiDirectOpenSupportedProvider.overrideWithValue(true),
          ...overrides,
        ],
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => showAskAiSheet(
                  context,
                  intent: intent,
                  panchang: intent == AiIntent.todayPanchang ? day() : null,
                  month: month,
                  timings: timings,
                  inauspicious: inauspicious,
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  String previewText(WidgetTester tester) {
    return tester.widget<SelectableText>(find.byType(SelectableText)).data!;
  }

  testWidgets('preview shows the computed panchang and city, never coordinates', (
    tester,
  ) async {
    await pumpTrigger(tester);

    final preview = previewText(tester);
    expect(preview, contains('City: Pune'));
    expect(preview, contains('Time zone: Asia/Kolkata'));
    expect(preview, contains('Shukla Tritiya'));
    expect(preview, contains('Sunrise: 06:34'));
    expect(preview, contains('Sunset: 18:12'));
    // The consent dialog promises no coordinates; four decimal places is how
    // a latitude/longitude would leak in.
    expect(RegExp(r'\d+\.\d{4,}').hasMatch(preview), isFalse);

    // The question is seeded and editable.
    expect(
      find.text("Explain today's tithi in plain language."),
      findsOneWidget,
    );
  });

  testWidgets('copy puts the preview plus the edited question on the clipboard', (
    tester,
  ) async {
    final clipboard = <MethodCall>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') clipboard.add(call);
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );

    await pumpTrigger(tester);

    await tester.enterText(find.byType(TextField), 'When should I do puja?');
    await tester.pumpAndSettle();
    // The sheet body scrolls: bring the action row into view first.
    await tester.ensureVisible(find.text('Copy'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Copy'));
    await tester.pumpAndSettle();

    expect(clipboard, hasLength(1));
    final prompt = clipboard.single.arguments['text'] as String;
    expect(prompt, contains('City: Pune'));
    expect(prompt, contains('Question: When should I do puja?'));
    expect(prompt.trimRight(), endsWith('Answer in English.'));
    expect(find.text('Prompt copied'), findsOneWidget);
  });

  testWidgets('month digest waits for the panchang before enabling the actions', (
    tester,
  ) async {
    final pending = Completer<Map<DateTime, PanchangData>>();
    await pumpTrigger(
      tester,
      intent: AiIntent.monthDigest,
      month: DateTime(2026, 11),
      overrides: [
        monthlyPanchangProvider.overrideWith((ref, month) => pending.future),
      ],
    );

    expect(find.text("Preparing the month's panchang…"), findsOneWidget);
    final openButton = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Open AI app'),
    );
    expect(openButton.onPressed, isNull);

    // Resolving the month fills the preview and re-enables the hand-off.
    // One festival per day on purpose: the digest must carry the whole month,
    // not the first few entries.
    pending.complete({
      for (var d = 1; d <= 25; d++)
        DateTime(2026, 11, d): day(
          date: DateTime(2026, 11, d),
          festival: 'Festival $d',
        ),
    });
    await tester.pumpAndSettle();

    final preview = previewText(tester);
    expect(preview, contains('Month: November 2026'));
    expect(preview, contains('- 1 Nov: Festival 1'));
    expect(preview, contains('- 25 Nov: Festival 25'));
    final readyButton = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Open AI app'),
    );
    expect(readyButton.onPressed, isNotNull);
  });

  testWidgets('month digest asks for the month-normalized key', (tester) async {
    // `focusedMonthProvider` carries a day and a time (`DateTime.now()`, the
    // day a swipe landed on). Keying the family on that would start a second
    // full-month computation next to the calendar's instead of sharing it.
    final requested = <DateTime>[];
    await pumpTrigger(
      tester,
      intent: AiIntent.monthDigest,
      month: DateTime(2026, 11, 17, 14, 33, 12),
      overrides: [
        monthlyPanchangProvider.overrideWith((ref, month) {
          requested.add(month);
          return const <DateTime, PanchangData>{};
        }),
      ],
    );

    expect(requested, hasLength(1));
    expect(requested.single, DateTime(2026, 11));
  });

  testWidgets('month digest failure says so and offers a retry', (tester) async {
    var calls = 0;
    await pumpTrigger(
      tester,
      intent: AiIntent.monthDigest,
      month: DateTime(2026, 11),
      overrides: [
        monthlyPanchangProvider.overrideWith((ref, month) {
          calls++;
          return Future<Map<DateTime, PanchangData>>.error(
            StateError('panchang unavailable'),
          );
        }),
      ],
    );

    // No more silent "Preparing..." with both actions dead.
    expect(
      find.text("Couldn't prepare this month's panchang."),
      findsOneWidget,
    );
    expect(find.text('Preparing the month\'s panchang…'), findsNothing);
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, 'Open AI app'))
          .onPressed,
      isNull,
    );
    expect(calls, 1);

    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(calls, 2);
  });

  testWidgets('copy failure says so instead of looking dead', (tester) async {
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          throw PlatformException(code: 'clipboard-unavailable');
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );

    await pumpTrigger(tester);
    await tester.ensureVisible(find.text('Copy'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Copy'));
    await tester.pumpAndSettle();

    expect(find.text("Couldn't copy the prompt"), findsOneWidget);
    expect(find.text('Prompt copied'), findsNothing);
  });

  testWidgets('a missing chosen app asks before opening the share sheet', (
    tester,
  ) async {
    await pumpTrigger(
      tester,
      overrides: [
        aiTargetAppProvider.overrideWith(_GeminiTargetNotifier.new),
        aiHandoffServiceProvider.overrideWithValue(
          const _MissingAppHandoff(),
        ),
      ],
    );

    await tester.ensureVisible(find.text('Open Gemini'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Open Gemini'));
    await tester.pumpAndSettle();

    // The old flow dropped straight into a chooser with a 3s snackbar hidden
    // behind it; now the fallback is a choice.
    expect(find.text("Gemini isn't available"), findsOneWidget);
    expect(find.text('Share instead'), findsOneWidget);
    expect(find.text('Copy'), findsOneWidget);
  });

  testWidgets('primary action names the AI app chosen in Settings', (
    tester,
  ) async {
    await pumpTrigger(
      tester,
      overrides: [aiTargetAppProvider.overrideWith(_GeminiTargetNotifier.new)],
    );

    // The chooser step is gone for an explicit choice, so the button says
    // where the prompt is going.
    expect(find.text('Open Gemini'), findsOneWidget);
    expect(find.text('Open AI app'), findsNothing);
  });

  testWidgets('the exact message can be inspected before sending', (
    tester,
  ) async {
    await pumpTrigger(tester);

    // The summary shows the data block, not the instructions.
    expect(previewText(tester), isNot(contains('Do not invent')));

    await tester.ensureVisible(find.text('Show the exact message'));
    await tester.tap(find.text('Show the exact message'));
    await tester.pumpAndSettle();

    // Byte-for-byte what the intent carries: rules, markers, question and the
    // answer-language line. The old preview showed only the middle of this.
    final exact = previewText(tester);
    expect(exact, contains('Do not invent'));
    expect(exact, contains('--- PANCHANG DATA (from Tithi'));
    expect(exact, contains('City: Pune'));
    expect(
      exact,
      contains("Question: Explain today's tithi in plain language."),
    );
    expect(exact.trimRight(), endsWith('Answer in English.'));

    await tester.tap(find.text('Show the summary'));
    await tester.pumpAndSettle();
    expect(previewText(tester), isNot(contains('Do not invent')));
    expect(
      find.text('Also sends your question, and asks for the answer in your app language.'),
      findsOneWidget,
    );
  });

  testWidgets('the preview names the conventions and the committed timings', (
    tester,
  ) async {
    final source = day();
    await pumpTrigger(
      tester,
      timings: _timings(source.date),
      inauspicious: _inauspicious(source.date),
      overrides: [
        hinduMonthSystemProvider.overrideWithValue(HinduMonthSystem.purnimant),
      ],
    );

    final preview = previewText(tester);
    // The masa is only meaningful with the system that named it.
    expect(preview, contains('Purnimant month system (months end at Purnima)'));
    expect(preview, contains('Swiss Ephemeris with Lahiri ayanamsa'));
    // Muhurta questions are answered from Tithi's numbers, not the model's.
    expect(preview, contains('Auspicious timings (computed by Tithi):'));
    expect(preview, contains('- Abhijit muhurta: 11:52-12:26'));
    // "Is 10am a good time?" needs the avoid windows too.
    expect(preview, contains('Inauspicious timings'));
    expect(preview, contains('- Rahu Kalam: 08:02-09:30'));
    // Still no coordinates.
    expect(RegExp(r'\d+\.\d{4,}').hasMatch(preview), isFalse);
  });
}

/// Fixed windows so the widget test does not depend on the arithmetic.
AuspiciousTimings _timings(DateTime date) {
  DateTime at(int hour, int minute) =>
      DateTime(date.year, date.month, date.day, hour, minute);
  return AuspiciousTimings(
    abhijit: (start: at(11, 52), end: at(12, 26)),
    brahmaMuhurta: (start: at(4, 40), end: at(5, 25)),
    madhyahnaInstant: at(12, 23),
    madhyahnaWindow: (start: at(11, 32), end: at(12, 52)),
    nishita: (start: at(0, 2), end: at(0, 45)),
    godhuli: (start: at(18, 12), end: at(18, 28)),
    pradosha: (start: at(18, 12), end: at(19, 24)),
  );
}

/// Same explicit boundaries as the context test: a fixed timeline the payload
/// assertions can name.
InauspiciousTimings _inauspicious(DateTime date) {
  DateTime at(int hour, int minute) =>
      DateTime(date.year, date.month, date.day, hour, minute);
  return InauspiciousTimings(
    sunrise: at(6, 34),
    sunset: at(18, 12),
    boundaries: [
      at(6, 34),
      at(8, 2),
      at(9, 30),
      at(10, 58),
      at(12, 26),
      at(13, 54),
      at(15, 22),
      at(16, 50),
      at(18, 12),
    ],
    rahuSegment: 2,
    yamagandaSegment: 4,
    gulikaSegment: 3,
  );
}

/// Fixed target so the sheet can be exercised without the settings box.
class _GeminiTargetNotifier extends AiTargetAppNotifier {
  @override
  String build() => kAiAppTargets.first.id;
}

/// Reports the explicit choice as unresolvable, without touching a platform
/// channel, so the confirm-before-fallback path can be driven in a widget test.
class _MissingAppHandoff extends AiHandoffService {
  const _MissingAppHandoff();

  @override
  Future<AiHandoffResult> openAiApp({
    required String prompt,
    String preferredAppId = kAiTargetAuto,
    String? subject,
    Rect? sharePositionOrigin,
  }) async {
    return AiHandoffResult(
      AiHandoffOutcome.appUnavailable,
      missingApp: aiTargetById(preferredAppId),
    );
  }
}
