import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tithi/widgets/animated_tab_layer.dart';

/// Reads the layer's animated presentation values.
double _opacity(WidgetTester tester) {
  return tester
      .widget<Opacity>(
        find.descendant(
          of: find.byType(AnimatedTabLayer),
          matching: find.byType(Opacity),
        ),
      )
      .opacity;
}

double _offset(WidgetTester tester) {
  final transform = tester.widget<Transform>(
    find.descendant(
      of: find.byType(AnimatedTabLayer),
      matching: find.byType(Transform),
    ),
  );
  return transform.transform.getTranslation().x;
}

Widget _layer({
  required TabLayerRole role,
  Widget? child,
  bool initiallyVisible = false,
  int direction = 1,
  double slide = 24,
  VoidCallback? onExited,
}) {
  return MaterialApp(
    home: Scaffold(
      body: AnimatedTabLayer(
        role: role,
        direction: direction,
        slide: slide,
        initiallyVisible: initiallyVisible,
        onExited: onExited,
        child: child ?? const Text('tab'),
      ),
    ),
  );
}

/// Counts its own builds, so a test can prove the transition never rebuilds
/// the tab's content.
class _CountingTab extends StatefulWidget {
  const _CountingTab({required this.onBuild});

  final VoidCallback onBuild;

  @override
  State<_CountingTab> createState() => _CountingTabState();
}

class _CountingTabState extends State<_CountingTab> {
  @override
  Widget build(BuildContext context) {
    widget.onBuild();
    return const Text('tab');
  }
}

void main() {
  group('AnimatedTabLayer', () {
    testWidgets('the entering tab fades in and slides in from the side', (
      tester,
    ) async {
      // Arrange / Act: a tab opened for the first time.
      await tester.pumpWidget(_layer(role: TabLayerRole.entering));

      // Assert: it starts hidden, one slide away from its place.
      expect(_opacity(tester), 0);
      expect(_offset(tester), 24);

      await tester.pump(const Duration(milliseconds: 125));
      final mid = _opacity(tester);
      expect(mid, greaterThan(0));
      expect(mid, lessThan(1));
      expect(_offset(tester), lessThan(24));
      expect(_offset(tester), greaterThan(0));

      await tester.pumpAndSettle();
      expect(_opacity(tester), 1);
      expect(_offset(tester), 0);
    });

    testWidgets('the entering tab slides in from the left when going back', (
      tester,
    ) async {
      // Arrange / Act
      await tester.pumpWidget(
        _layer(role: TabLayerRole.entering, direction: -1),
      );

      // Assert
      expect(_offset(tester), -24);
      await tester.pumpAndSettle();
      expect(_offset(tester), 0);
    });

    testWidgets('the exiting tab slides away as an opaque backdrop', (
      tester,
    ) async {
      // Arrange: the tab is on screen...
      await tester.pumpWidget(
        _layer(role: TabLayerRole.entering, initiallyVisible: true),
      );
      expect(_opacity(tester), 1);
      expect(_offset(tester), 0);

      // Act: ...and now it is being replaced.
      await tester.pumpWidget(_layer(role: TabLayerRole.exiting));
      await tester.pump(const Duration(milliseconds: 125));

      // Assert: half way out it has moved, but it is still fully opaque. The
      // incoming tab fades in over it, so no frame of the switch shows the
      // route background through the pair.
      expect(_opacity(tester), 1);
      expect(_offset(tester), lessThan(0));

      await tester.pumpAndSettle();
      expect(_opacity(tester), 1);
      expect(_offset(tester), -24);
    });

    testWidgets('an idle tab is invisible and out of the accessibility tree', (
      tester,
    ) async {
      // Arrange
      final semantics = tester.ensureSemantics();

      // Act
      await tester.pumpWidget(
        _layer(role: TabLayerRole.idle, child: const Text('hidden tab')),
      );

      // Assert: not painted, not announced - but still in the tree, so its
      // state survives.
      expect(_opacity(tester), 0);
      expect(find.text('hidden tab'), findsOneWidget);
      expect(find.bySemanticsLabel('hidden tab'), findsNothing);

      semantics.dispose();
    });

    testWidgets('an interrupted switch continues from where it was', (
      tester,
    ) async {
      // Arrange: a tab halfway through fading in...
      await tester.pumpWidget(_layer(role: TabLayerRole.entering));
      await tester.pump(const Duration(milliseconds: 125));
      final midOffset = _offset(tester);
      expect(midOffset, greaterThan(0));

      // Act: the user picks another tab before the first one has landed.
      await tester.pumpWidget(_layer(role: TabLayerRole.exiting));
      await tester.pump(const Duration(milliseconds: 50));

      // Assert: it carries on from where it got to instead of snapping to a
      // start value - it has not jumped back out to the far side, and it has
      // not fallen off the other one yet. The backdrop also stays opaque while
      // it reverses direction.
      final after = _offset(tester);
      expect(after, lessThan(midOffset));
      expect(after, greaterThan(-24));
      expect(_opacity(tester), 1);
    });

    testWidgets('a tab demoted mid-slide fades out instead of vanishing', (
      tester,
    ) async {
      // Arrange: a third tab is picked while this one is still sliding in, so
      // it is demoted to idle while it is only partly opaque.
      await tester.pumpWidget(_layer(role: TabLayerRole.entering));
      await tester.pump(const Duration(milliseconds: 125));
      final mid = _opacity(tester);
      expect(mid, greaterThan(0));
      expect(mid, lessThan(1));

      // Act
      await tester.pumpWidget(_layer(role: TabLayerRole.idle));

      // Assert: it fades over the rest of the switch. Snapping to 0 here would
      // flash the route behind the still-transparent incoming tab.
      expect(_opacity(tester), mid);
      await tester.pump(const Duration(milliseconds: 125));
      final fading = _opacity(tester);
      expect(fading, lessThan(mid));
      expect(fading, greaterThan(0));

      await tester.pumpAndSettle();
      expect(_opacity(tester), 0);
    });

    testWidgets('a tab that already finished leaving snaps out of the way', (
      tester,
    ) async {
      // Arrange: a tab that has completed its exit...
      await tester.pumpWidget(
        _layer(role: TabLayerRole.entering, initiallyVisible: true),
      );
      await tester.pumpWidget(_layer(role: TabLayerRole.exiting));
      await tester.pumpAndSettle();
      expect(_offset(tester), -24);
      expect(_opacity(tester), 1);

      // Act: ...is demoted once the switch moved on to yet another tab.
      await tester.pumpWidget(_layer(role: TabLayerRole.idle));

      // Assert: it is behind the incoming tab by then, so there is nothing to
      // fade and it can stop being painted at once.
      expect(_opacity(tester), 0);
    });

    testWidgets('a hidden tab cannot take keyboard focus', (tester) async {
      // Arrange: a focusable child, hidden behind a visible tab.
      final node = FocusNode();
      addTearDown(node.dispose);
      final child = Focus(
        autofocus: true,
        focusNode: node,
        child: const Text('tab'),
      );

      // Act
      await tester.pumpWidget(_layer(role: TabLayerRole.idle, child: child));
      await tester.pump();
      node.requestFocus();
      await tester.pump();

      // Assert: `IgnorePointer` only stops taps - without `ExcludeFocus` the
      // focus (and switch access) could still land on a tab nobody can see.
      expect(node.hasFocus, isFalse);

      // ...and the same node is focusable again once its tab is on screen.
      await tester.pumpWidget(
        _layer(
          role: TabLayerRole.entering,
          initiallyVisible: true,
          child: child,
        ),
      );
      await tester.pump();
      node.requestFocus();
      await tester.pump();
      expect(node.hasFocus, isTrue);
    });

    testWidgets('the tab content is not rebuilt while the transition runs', (
      tester,
    ) async {
      // Arrange
      var builds = 0;
      final child = _CountingTab(onBuild: () => builds++);
      await tester.pumpWidget(
        _layer(
          role: TabLayerRole.entering,
          initiallyVisible: true,
          child: child,
        ),
      );
      final before = builds;
      expect(before, greaterThan(0));

      // Act: the same child instance, a new role.
      await tester.pumpWidget(_layer(role: TabLayerRole.exiting, child: child));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 100));

      // Assert: the content was not rebuilt for any frame of the transition.
      expect(builds, before);
    });

    testWidgets('the exit callback fires once the tab has left', (
      tester,
    ) async {
      // Arrange
      var exited = 0;
      await tester.pumpWidget(
        _layer(
          role: TabLayerRole.entering,
          initiallyVisible: true,
          onExited: () => exited++,
        ),
      );

      // Act
      await tester.pumpWidget(
        _layer(role: TabLayerRole.exiting, onExited: () => exited++),
      );
      await tester.pumpAndSettle();

      // Assert
      expect(exited, 1);
    });

    testWidgets('an initially visible tab is on screen with no fade', (
      tester,
    ) async {
      // Arrange / Act
      await tester.pumpWidget(
        _layer(role: TabLayerRole.entering, initiallyVisible: true),
      );

      // Assert: no fade-in over the app's launch.
      expect(_opacity(tester), 1);
      expect(_offset(tester), 0);
    });
  });
}
