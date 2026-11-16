import 'dart:ui' show Tristate;

import 'package:material_ui/material_ui.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tithi/providers/accessibility_provider.dart';
import 'package:tithi/theme/app_motion.dart';
import 'package:tithi/theme/app_theme.dart';
import 'package:tithi/widgets/floating_nav_bar.dart';

/// PressScale reads the accessibility box for its haptic gate; the real
/// notifier would open Hive, which these widget tests never initialize.
class _FixedAccessibility extends AccessibilityNotifier {
  @override
  AccessibilityState build() => const AccessibilityState();
}

const _destinations = [
  FloatingNavDestination(icon: Icons.today_rounded, label: 'Today'),
  FloatingNavDestination(
    icon: Icons.event_available_rounded,
    label: 'Festivals',
  ),
  FloatingNavDestination(icon: Icons.timer_rounded, label: 'Countdowns'),
];

Widget _harness({
  required int selected,
  required ValueChanged<int> onSelected,
  Widget? trailingAction,
  bool showTrailingAction = true,
  double textScale = 1.0,
  bool highContrast = false,
  List<FloatingNavDestination> destinations = _destinations,
}) {
  return ProviderScope(
    overrides: [accessibilityProvider.overrideWith(_FixedAccessibility.new)],
    child: MaterialApp(
      theme: ThemeData(useMaterial3: true),
      home: Scaffold(
        body: Builder(
          builder: (context) {
            final media = MediaQuery.of(context);
            return MediaQuery(
              data: media.copyWith(
                textScaler: TextScaler.linear(textScale),
                highContrast: highContrast,
              ),
              child: Column(
                children: [
                  const Expanded(child: SizedBox.shrink()),
                  FloatingNavBar(
                    destinations: destinations,
                    selectedIndex: selected,
                    onSelected: onSelected,
                    trailingAction: trailingAction,
                    showTrailingAction: showTrailingAction,
                  ),
                ],
              ),
            );
          },
        ),
      ),
    ),
  );
}

/// The three tap targets, one per destination (each is the destination's
/// GestureDetector, which owns the slot's full width).
Finder _targets() => find.descendant(
  of: find.byType(FloatingNavBar),
  matching: find.byType(GestureDetector),
);

/// The 44dp pills, one per destination, in destination order.
Finder _pills() => find.descendant(
  of: find.byType(FloatingNavBar),
  matching: find.byType(AnimatedContainer),
);

/// The DecoratedBox wrapping the capsule's clip: the surface that carries the
/// cast shadow (outside the clip, or the clip would slice it off).
DecoratedBox _shadowedCapsule(WidgetTester tester) {
  return tester.widget<DecoratedBox>(
    find
        .ancestor(
          of: find.byKey(FloatingNavBar.capsuleKey),
          matching: find.byType(DecoratedBox),
        )
        .first,
  );
}

/// Painted decoration of the pill at [index].
BoxDecoration _pillDecoration(WidgetTester tester, int index) {
  return tester.widget<AnimatedContainer>(_pills().at(index)).decoration!
      as BoxDecoration;
}

/// Painted label colour of the destination at [index].
Color? _pillLabelColor(WidgetTester tester, int index) {
  return tester
      .widget<AnimatedDefaultTextStyle>(
        find
            .descendant(
              of: _pills().at(index),
              matching: find.byType(AnimatedDefaultTextStyle),
            )
            .first,
      )
      .style
      .color;
}

void main() {
  group('FloatingNavBar', () {
    testWidgets('tapping an unselected destination reports its index', (
      tester,
    ) async {
      // Arrange
      int? tapped;
      await tester.pumpWidget(
        _harness(selected: 0, onSelected: (index) => tapped = index),
      );

      // Act: the label of an unselected destination is its tap target.
      await tester.tap(find.text('Countdowns'));
      await tester.pumpAndSettle();

      // Assert
      expect(tapped, 2);
    });

    testWidgets(
      'every destination paints its label, only the selected its icon',
      (tester) async {
        // Arrange / Act
        await tester.pumpWidget(_harness(selected: 1, onSelected: (_) {}));

        // Assert
        expect(find.text('Today'), findsOneWidget);
        expect(find.text('Festivals'), findsOneWidget);
        expect(find.text('Countdowns'), findsOneWidget);
        // Only the selected destination adds its icon.
        expect(find.byIcon(Icons.event_available_rounded), findsOneWidget);
        expect(find.byIcon(Icons.today_rounded), findsNothing);
        expect(find.byIcon(Icons.timer_rounded), findsNothing);
      },
    );

    testWidgets('capsule renders at its declared height', (tester) async {
      // Arrange / Act
      await tester.pumpWidget(_harness(selected: 0, onSelected: (_) {}));

      // Assert: the painted capsule is height + its bottom margin; `reserve`
      // adds one more margin above it so content never touches the pill.
      final size = tester.getSize(find.byType(FloatingNavBar));
      expect(size.height, FloatingNavBar.height + FloatingNavBar.margin);
      expect(FloatingNavBar.reserve, greaterThan(size.height));
    });

    testWidgets('the pill is slimmer than the capsule and centred in it', (
      tester,
    ) async {
      // Arrange / Act: every destination paints a 44dp pill; the selected one
      // only adds the accent fill.
      await tester.pumpWidget(_harness(selected: 0, onSelected: (_) {}));
      final capsule = tester.getRect(find.byKey(FloatingNavBar.capsuleKey));
      final pill = tester.getRect(
        find
            .descendant(
              of: find.byType(FloatingNavBar),
              matching: find.byType(AnimatedContainer),
            )
            .first,
      );

      // Assert: the capsule hugs the pill instead of parking empty air above
      // and below it, and what is left of the film is split evenly - the pill
      // is centred, not pushed to one edge.
      expect(pill.height, lessThan(capsule.height));
      expect(
        pill.top - capsule.top,
        moreOrLessEquals(capsule.bottom - pill.bottom, epsilon: 0.5),
      );
      // The pill still has to hold the icon and the label at 2x text.
      expect(pill.height, greaterThanOrEqualTo(44));
    });

    testWidgets('selected pill sits flush with the capsule edge', (
      tester,
    ) async {
      // Arrange
      await tester.pumpWidget(_harness(selected: 2, onSelected: (_) {}));
      final capsule = tester.getRect(find.byKey(FloatingNavBar.capsuleKey));
      final pills = find.descendant(
        of: find.byType(FloatingNavBar),
        matching: find.byType(AnimatedContainer),
      );

      // Act: the last destination is the selected one.
      final pill = tester.getRect(pills.last);

      // Assert: only the capsule's edge inset separates the pill from the
      // edge — no leftover free space parked out there.
      const edgeInset = 8.0;
      expect(
        pill.right,
        moreOrLessEquals(capsule.right - edgeInset, epsilon: 0.5),
      );
    });

    testWidgets('capsule is only as wide as the destinations need', (
      tester,
    ) async {
      // Arrange / Act
      await tester.pumpWidget(_harness(selected: 1, onSelected: (_) {}));

      // Assert: on this 800dp surface nothing stretches the capsule to the
      // screen width...
      final capsule = tester.getRect(find.byKey(FloatingNavBar.capsuleKey));
      const available = 800.0 - FloatingNavBar.margin * 2;
      expect(capsule.width, lessThan(available));
      // ... it is centred in the box the shell hands it ...
      expect(capsule.center.dx, moreOrLessEquals(400, epsilon: 0.5));
      // ... and the width came from the content, not from an equal share:
      // the longest label is painted in full, not ellipsized.
      final label = tester.renderObject<RenderParagraph>(
        find.text('Countdowns'),
      );
      expect(
        label.size.width,
        moreOrLessEquals(
          label.getMaxIntrinsicWidth(double.infinity),
          epsilon: 0.5,
        ),
      );
    });

    testWidgets('capsule stays inside a narrow screen', (tester) async {
      // Arrange
      tester.view.physicalSize = const Size(320, 700);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      // Act
      await tester.pumpWidget(_harness(selected: 2, onSelected: (_) {}));

      // Assert: clamped to the gutters instead of overflowing; the labels are
      // allowed to ellipsize, which Flexible + TextOverflow.ellipsis handles.
      final capsule = tester.getRect(find.byKey(FloatingNavBar.capsuleKey));
      expect(
        capsule.width,
        lessThanOrEqualTo(320 - FloatingNavBar.margin * 2 + 0.5),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('narrow screen keeps capsule and action inside the gutters', (
      tester,
    ) async {
      // Arrange
      tester.view.physicalSize = const Size(320, 700);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      const actionKey = Key('test-trailing-action');

      // Act
      await tester.pumpWidget(
        _harness(
          selected: 2,
          onSelected: (_) {},
          trailingAction: const SizedBox.square(key: actionKey, dimension: 56),
        ),
      );

      // Assert: the action takes its width from the capsule, not from the
      // screen margins, and nothing overflows.
      final capsule = tester.getRect(find.byKey(FloatingNavBar.capsuleKey));
      final action = tester.getRect(find.byKey(actionKey));
      expect(
        capsule.left,
        moreOrLessEquals(FloatingNavBar.margin, epsilon: 0.5),
      );
      expect(
        action.right,
        moreOrLessEquals(320 - FloatingNavBar.margin, epsilon: 0.5),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('trailing action floats outside the capsule, on its right', (
      tester,
    ) async {
      // Arrange: a stand-in with the real button's 56dp extent.
      const actionKey = Key('test-trailing-action');
      await tester.pumpWidget(
        _harness(
          selected: 0,
          onSelected: (_) {},
          trailingAction: const SizedBox.square(key: actionKey, dimension: 56),
        ),
      );

      // Act
      final capsule = tester.getRect(find.byKey(FloatingNavBar.capsuleKey));
      final action = tester.getRect(find.byKey(actionKey));

      // Assert: a sibling of the film, not a segment inside it...
      expect(action.left, greaterThan(capsule.right));
      expect(action.left - capsule.right, moreOrLessEquals(8, epsilon: 0.5));
      // ... on the same baseline...
      expect(
        action.center.dy,
        moreOrLessEquals(capsule.center.dy, epsilon: 0.5),
      );
      // ... and the pair is what gets centred.
      expect(
        (capsule.left + action.right) / 2,
        moreOrLessEquals(400, epsilon: 0.5),
      );
    });

    testWidgets('hidden trailing action collapses and re-centres the capsule', (
      tester,
    ) async {
      // Arrange
      const actionKey = Key('test-trailing-action');
      Widget build({required bool visible}) => _harness(
        selected: 0,
        onSelected: (_) {},
        trailingAction: const SizedBox.square(key: actionKey, dimension: 56),
        showTrailingAction: visible,
      );
      await tester.pumpWidget(build(visible: false));
      await tester.pumpAndSettle();

      // Act
      expect(find.byKey(actionKey), findsNothing);
      await tester.pumpWidget(build(visible: true));
      await tester.pumpAndSettle();

      // Assert: the slot reopens and the capsule makes room for it.
      final capsule = tester.getRect(find.byKey(FloatingNavBar.capsuleKey));
      final action = tester.getRect(find.byKey(actionKey));
      expect(action.left - capsule.right, moreOrLessEquals(8, epsilon: 0.5));
      expect(
        (capsule.left + action.right) / 2,
        moreOrLessEquals(400, epsilon: 0.5),
      );
    });

    testWidgets('trailing action fades in on opened space, not out of a clip', (
      tester,
    ) async {
      // Arrange
      const actionKey = Key('test-trailing-action');
      Widget build({required bool visible}) => _harness(
        selected: 0,
        onSelected: (_) {},
        trailingAction: const SizedBox.square(key: actionKey, dimension: 56),
        showTrailingAction: visible,
      );
      await tester.pumpWidget(build(visible: false));
      await tester.pumpAndSettle();

      Finder fade() => find
          .ancestor(of: find.byKey(actionKey), matching: find.byType(Opacity))
          .first;
      double opacity() => tester.widget<Opacity>(fade()).opacity;
      Rect slot() => tester.getRect(
        find
            .ancestor(of: find.byKey(actionKey), matching: find.byType(Align))
            .first,
      );

      // Act: step through the whole opening one frame at a time.
      await tester.pumpWidget(build(visible: true));

      // Assert: whenever the action is visible the clip already exposes all of
      // it, so it is never revealed edge-first (which is what read as the
      // button sliding out from behind the capsule)...
      var fadedPartWay = false;
      for (
        var elapsed = 0;
        elapsed < AppMotion.standard.inMilliseconds;
        elapsed += 10
      ) {
        await tester.pump(const Duration(milliseconds: 10));
        final alpha = opacity();
        if (alpha <= 0) continue;
        fadedPartWay = fadedPartWay || alpha < 1;
        expect(
          tester.getRect(find.byKey(actionKey)).left,
          greaterThanOrEqualTo(slot().left - 0.5),
          reason: 'the action was trimmed at ${elapsed + 10}ms',
        );
      }
      // ... because it comes in through the fade.
      expect(fadedPartWay, isTrue);

      // And it settles fully opaque in its final place.
      await tester.pumpAndSettle();
      expect(opacity(), 1.0);
    });

    testWidgets(
      'large text on a narrow screen with the action does not overflow',
      (tester) async {
        // Arrange: the worst realistic case - 320dp, the action's 56dp taken out
        // of the row, and every label at 2x.
        tester.view.physicalSize = const Size(320, 700);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        // Act
        await tester.pumpWidget(
          _harness(
            selected: 1,
            onSelected: (_) {},
            textScale: 2.0,
            trailingAction: const SizedBox.square(dimension: 56),
          ),
        );

        // Assert: fixed padding is reserved before the labels are split, so no
        // destination is ever narrower than what cannot shrink, and the bar
        // clamps inside the gutters instead of throwing a layout overflow.
        final capsule = tester.getRect(find.byKey(FloatingNavBar.capsuleKey));
        expect(
          capsule.width,
          lessThanOrEqualTo(320 - FloatingNavBar.margin * 2 + 0.5),
        );
        final targets = _targets();
        expect(targets, findsNWidgets(3));
        for (var i = 0; i < 3; i++) {
          final size = tester.getSize(targets.at(i));
          // Slots may shrink, but never below the reserved padding share, and
          // the tap target stays the full capsule height.
          expect(size.width, greaterThanOrEqualTo(32));
          expect(size.height, FloatingNavBar.height);
        }
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('very long labels clamp without overflowing', (tester) async {
      // Arrange: localized labels can be far longer than the English ones.
      tester.view.physicalSize = const Size(320, 700);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      // Act
      await tester.pumpWidget(
        _harness(
          selected: 2,
          onSelected: (_) {},
          textScale: 2.0,
          destinations: const [
            FloatingNavDestination(icon: Icons.today_rounded, label: 'Today'),
            FloatingNavDestination(
              icon: Icons.event_available_rounded,
              label: 'Festivals and Events',
            ),
            FloatingNavDestination(
              icon: Icons.timer_rounded,
              label: 'Upcoming Countdowns',
            ),
          ],
          trailingAction: const SizedBox.square(dimension: 56),
        ),
      );

      // Assert: the labels ellipsize into the resolved slots; the capsule and
      // the action still fit and nothing throws.
      expect(
        tester.getRect(find.byKey(FloatingNavBar.capsuleKey)).width,
        lessThanOrEqualTo(320 - FloatingNavBar.margin * 2 + 0.5),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'extreme narrow window drops the icon and shrinks the padding',
      (tester) async {
        // Arrange: narrower than padding + icon for all three options. The bar
        // must still lay out (no negative widths, no overflow) rather than
        // trusting that `screen - 2 * margin` always leaves room.
        tester.view.physicalSize = const Size(120, 500);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        // Act
        await tester.pumpWidget(
          _harness(
            selected: 0,
            onSelected: (_) {},
            textScale: 2.0,
            trailingAction: const SizedBox.square(dimension: 56),
          ),
        );

        // Assert: the selected destination gives up its icon, which is an
        // addition to the label, and the layout survives.
        expect(find.byIcon(Icons.today_rounded), findsNothing);
        expect(
          tester.getRect(find.byKey(FloatingNavBar.capsuleKey)).width,
          lessThanOrEqualTo(120 - FloatingNavBar.margin * 2 + 0.5),
        );
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('each destination is one tappable, selected-aware button', (
      tester,
    ) async {
      // Arrange
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(_harness(selected: 1, onSelected: (_) {}));

      // Act: `excludeSemantics` drops the painted label (and the inner
      // GestureDetector's node), so the destination's own node has to carry
      // the tap action itself.
      final selectedNode = tester.getSemantics(
        find.byWidgetPredicate(
          (widget) =>
              widget is Semantics && widget.properties.label == 'Festivals',
        ),
      );
      final otherNode = tester.getSemantics(
        find.byWidgetPredicate(
          (widget) => widget is Semantics && widget.properties.label == 'Today',
        ),
      );

      // Assert
      final selectedData = selectedNode.getSemanticsData();
      final otherData = otherNode.getSemanticsData();
      expect(selectedNode.label, 'Festivals');
      expect(selectedData.hasAction(SemanticsAction.tap), isTrue);
      expect(selectedData.flagsCollection.isButton, isTrue);
      expect(selectedData.flagsCollection.isSelected, Tristate.isTrue);

      expect(otherData.hasAction(SemanticsAction.tap), isTrue);
      expect(otherData.flagsCollection.isButton, isTrue);
      expect(otherData.flagsCollection.isSelected, Tristate.isFalse);

      // The handle must be released inside the test body: the framework
      // verifies that no handle outlives the test before tearDowns run.
      semantics.dispose();
    });

    testWidgets('the selected pill is an accent tint, not a solid block', (
      tester,
    ) async {
      // Arrange / Act
      await tester.pumpWidget(_harness(selected: 0, onSelected: (_) {}));

      // Assert: the fill carries the accent hue as a wash, and the label/icon
      // use the accent itself - a solid accent block would outshine the page
      // behind the film.
      final context = tester.element(find.byType(FloatingNavBar));
      final accent = AppTheme.festivalAccent(context);
      final fill = _pillDecoration(tester, 0).color!;
      expect(fill.withValues(alpha: 1), accent);
      expect(fill.a, lessThan(0.5));
      expect(_pillLabelColor(tester, 0), accent);
    });

    testWidgets('high contrast keeps the solid accent and its on-ink', (
      tester,
    ) async {
      // Arrange / Act
      await tester.pumpWidget(
        _harness(selected: 0, onSelected: (_) {}, highContrast: true),
      );

      // Assert: legibility wins over the tint - solid accent, on-accent ink.
      final context = tester.element(find.byType(FloatingNavBar));
      expect(_pillDecoration(tester, 0).color!.a, 1.0);
      expect(_pillLabelColor(tester, 0), AppTheme.onFestivalAccent(context));
    });

    testWidgets('the capsule is translucent and casts a shadow under it', (
      tester,
    ) async {
      // Arrange / Act
      await tester.pumpWidget(_harness(selected: 0, onSelected: (_) {}));

      // Assert: the film lets the (blurred) page through...
      final context = tester.element(find.byType(FloatingNavBar));
      final film = AppTheme.floatingOverlayDecoration(context, borderRadius: 0);
      expect(film.color!.a, lessThan(0.8));
      expect(film.color!.a, greaterThan(0.5));
      // ...the backdrop filter that makes it a film is still applied...
      expect(find.byType(BackdropFilter), findsOneWidget);
      // ...and the shadow is painted *around* the clip, not inside it: a
      // shadow in the film's decoration would be sliced off at the edges.
      final shadows =
          (_shadowedCapsule(tester).decoration as BoxDecoration).boxShadow!;
      expect(shadows, hasLength(2));
      expect(shadows.every((shadow) => shadow.color.a < 0.5), isTrue);
    });

    testWidgets('high contrast drops the blur and the shadow', (tester) async {
      // Arrange / Act
      await tester.pumpWidget(
        _harness(selected: 0, onSelected: (_) {}, highContrast: true),
      );

      // Assert: legibility over arbitrary content, and the strong border is
      // the separation - a soft shadow would blur the edge that mode needs.
      final context = tester.element(find.byType(FloatingNavBar));
      expect(AppTheme.floatingOverlayBlurs(context), isFalse);
      expect(find.byType(BackdropFilter), findsNothing);
      expect(
        (_shadowedCapsule(tester).decoration as BoxDecoration).boxShadow,
        isEmpty,
      );
      expect(
        AppTheme.floatingOverlayDecoration(context, borderRadius: 0).color!.a,
        1.0,
      );
    });
  });
}
