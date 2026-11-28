import 'package:material_3_expressive/material_3_expressive.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tithi/providers/accessibility_provider.dart';
import 'package:tithi/theme/app_theme.dart';
import 'package:tithi/widgets/settings_widgets.dart';

/// Stub for the Hive-backed accessibility provider; haptics read it on tap.
class _StubAccessibility extends AccessibilityNotifier {
  @override
  AccessibilityState build() => const AccessibilityState();
}

/// Hosts a tile whose value actually changes on toggle, so the switch's
/// response to a value change can be measured frame by frame.
class _ToggleHost extends StatefulWidget {
  const _ToggleHost({super.key, this.reduceMotion = false});

  final bool reduceMotion;

  @override
  State<_ToggleHost> createState() => _ToggleHostState();
}

class _ToggleHostState extends State<_ToggleHost> {
  bool _value = false;

  @override
  Widget build(BuildContext context) {
    return MediaQuery(
      data: MediaQuery.of(context)
          .copyWith(disableAnimations: widget.reduceMotion),
      child: Scaffold(
        body: SettingsSwitchTile(
          icon: Icons.notifications_active_rounded,
          title: 'Daily Notifications',
          subtitle: 'Get notified daily',
          value: _value,
          onChanged: (value) async => setState(() => _value = value),
        ),
      ),
    );
  }
}

/// The thumb is the circular DecoratedBox whose child is the sized handle.
Finder _thumb() => find.descendant(
  of: find.byType(M3ESwitch),
  matching: find.byWidgetPredicate((widget) {
    if (widget is! DecoratedBox || widget.decoration is! BoxDecoration) {
      return false;
    }
    final decoration = widget.decoration as BoxDecoration;
    return decoration.shape == BoxShape.circle &&
        widget.child is SizedBox &&
        (widget.child as SizedBox).width! >= 16;
  }),
);

Future<void> _pumpHost(
  WidgetTester tester, {
  required bool reduceMotion,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [accessibilityProvider.overrideWith(_StubAccessibility.new)],
      child: MaterialApp(
        theme: AppTheme.shuklaTheme,
        home: _ToggleHost(
          key: ValueKey<bool>(reduceMotion),
          reduceMotion: reduceMotion,
        ),
      ),
    ),
  );
}

/// A pending one-shot read (location init) shows an inline spinner in the
/// settings list. The spinner animates every frame; without its own boundary
/// that repaint climbs to SettingsGroupCard's RepaintBoundary and re-rasterizes
/// the whole card, which is felt as scroll stutter.
void main() {
  testWidgets('the loading spinner is isolated from its group card', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AppTheme.shuklaTheme,
          home: const Scaffold(
            body: SettingsSwitchTile(
              icon: Icons.location_on_rounded,
              title: 'Auto Location',
              subtitle: 'Fetching location...',
              value: false,
              isLoading: true,
              onChanged: null,
            ),
          ),
        ),
      ),
    );

    final spinner = find.byType(M3EProgressIndicator);
    expect(spinner, findsOneWidget);

    // Walk from the spinner up to the tile: a RepaintBoundary must sit between
    // them, otherwise the per-frame animation dirties the surrounding card.
    var isolated = false;
    tester.element(spinner).visitAncestorElements((element) {
      if (element.widget is RepaintBoundary) {
        isolated = true;
        return false;
      }
      if (element.widget is SettingsSwitchTile) return false;
      return true;
    });
    expect(isolated, isTrue);
  });

  testWidgets('no spinner is built when the row is not loading', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AppTheme.shuklaTheme,
          home: const Scaffold(
            body: SettingsSwitchTile(
              icon: Icons.location_on_rounded,
              title: 'Auto Location',
              subtitle: 'Using: Kolkata',
              value: true,
              onChanged: null,
            ),
          ),
        ),
      ),
    );

    expect(find.byType(M3EProgressIndicator), findsNothing);
  });

  // The settings row must use the Expressive switch (spring handle, state
  // layer, drag support) rather than the classic Material Switch, and a
  // pending one-shot disables it just like the old control did.
  testWidgets('uses an expressive switch that reports toggles', (tester) async {
    final toggles = <bool>[];
    // Haptics read the accessibility provider (backed by Hive); stub it so the
    // tap can exercise the switch callback without opening a box in a test.
    await tester.pumpWidget(
      ProviderScope(
        overrides: [accessibilityProvider.overrideWith(_StubAccessibility.new)],
        child: MaterialApp(
          theme: AppTheme.shuklaTheme,
          home: Scaffold(
            body: SettingsSwitchTile(
              icon: Icons.notifications_active_rounded,
              title: 'Daily Notifications',
              subtitle: 'Get notified daily',
              value: false,
              onChanged: (value) async => toggles.add(value),
            ),
          ),
        ),
      ),
    );

    expect(find.byType(M3ESwitch), findsOneWidget);
    expect(find.byType(Switch), findsNothing);

    await tester.tap(find.byType(M3ESwitch));
    await tester.pump();
    expect(toggles, equals(<bool>[true]));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [accessibilityProvider.overrideWith(_StubAccessibility.new)],
        child: MaterialApp(
          theme: AppTheme.shuklaTheme,
          home: const Scaffold(
            body: SettingsSwitchTile(
              icon: Icons.location_on_rounded,
              title: 'Auto Location',
              subtitle: 'Fetching location...',
              value: false,
              isLoading: true,
              onChanged: null,
            ),
          ),
        ),
      ),
    );
    expect(tester.widget<M3ESwitch>(find.byType(M3ESwitch)).onChanged, isNull);
  });

  // M3ESwitch springs ignore MediaQuery.disableAnimations, so AppSwitch
  // remounts the control at its final value when Reduce Motion is on.
  testWidgets('reduce motion snaps the handle; normal motion springs', (
    tester,
  ) async {
    for (final reduceMotion in <bool>[false, true]) {
      await _pumpHost(tester, reduceMotion: reduceMotion);
      expect(_thumb(), findsOneWidget);

      final before = tester.getTopLeft(_thumb()).dx;
      await tester.tap(find.byType(M3ESwitch));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      final after50ms = tester.getTopLeft(_thumb()).dx;
      await tester.pumpAndSettle();
      final settled = tester.getTopLeft(_thumb()).dx;

      final travel = settled - before;
      expect(travel, greaterThan(10));
      if (reduceMotion) {
        expect(after50ms, settled);
      } else {
        expect(after50ms, lessThan(settled));
      }
    }
  });

  testWidgets('reduce motion keeps focus across the switch remount', (
    tester,
  ) async {
    await _pumpHost(tester, reduceMotion: true);
    final switchElement = tester.element(find.byType(M3ESwitch));
    final node = switchElement
        .findAncestorWidgetOfExactType<Focus>()!
        .focusNode!;

    node.requestFocus();
    await tester.pump();
    expect(node.hasFocus, isTrue);

    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pump();
    expect(node.hasFocus, isTrue);
  });
}
