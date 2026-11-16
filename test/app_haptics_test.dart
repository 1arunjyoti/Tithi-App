import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tithi/core/feedback/app_haptics.dart';
import 'package:tithi/providers/accessibility_provider.dart';

/// The accessibility provider normally loads Hive; tests only need the flag.
class _FixedAccessibility extends AccessibilityNotifier {
  _FixedAccessibility(this.initial);

  final AccessibilityState initial;

  @override
  AccessibilityState build() => initial;
}

Future<WidgetRef> _pumpRef(
  WidgetTester tester, {
  required bool hapticsEnabled,
}) async {
  late WidgetRef ref;
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        accessibilityProvider.overrideWith(
          () => _FixedAccessibility(
            AccessibilityState(hapticFeedback: hapticsEnabled),
          ),
        ),
      ],
      child: Consumer(
        builder: (context, r, _) {
          ref = r;
          return const SizedBox.shrink();
        },
      ),
    ),
  );
  return ref;
}

Iterable<MethodCall> _vibrations(List<MethodCall> calls) =>
    calls.where((call) => call.method == 'HapticFeedback.vibrate');

void main() {
  group('AppHaptics', () {
    late List<MethodCall> calls;

    setUp(() {
      calls = <MethodCall>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, (call) async {
            calls.add(call);
            return null;
          });
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null);
    });

    testWidgets('stays silent when Haptic Feedback is off', (tester) async {
      final ref = await _pumpRef(tester, hapticsEnabled: false);

      AppHaptics.tap(ref);
      AppHaptics.impact(ref);
      await tester.pump();

      expect(_vibrations(calls), isEmpty);
    });

    testWidgets('buzzes once per call when enabled', (tester) async {
      final ref = await _pumpRef(tester, hapticsEnabled: true);

      AppHaptics.tap(ref);
      await tester.pump();
      expect(_vibrations(calls), hasLength(1));

      AppHaptics.impact(ref);
      await tester.pump();
      expect(_vibrations(calls), hasLength(2));
    });

    testWidgets('tap and impact ask the platform for different weights', (
      tester,
    ) async {
      final ref = await _pumpRef(tester, hapticsEnabled: true);

      AppHaptics.tap(ref);
      AppHaptics.impact(ref);
      await tester.pump();

      expect(_vibrations(calls).map((call) => call.arguments), [
        'HapticFeedbackType.lightImpact',
        'HapticFeedbackType.mediumImpact',
      ]);
    });
  });
}
