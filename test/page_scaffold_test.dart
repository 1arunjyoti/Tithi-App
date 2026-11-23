import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tithi/theme/app_theme.dart';
import 'package:tithi/widgets/page_scaffold.dart';

/// Marks the page content so the shell's wrappers can be read as its
/// ancestors (the app bar brings its own `SafeArea`, so a global `find.byType`
/// would match that one too).
const Key bodyKey = Key('page-body');

Finder _ancestorsOfBody(Finder matching) =>
    find.ancestor(of: find.byKey(bodyKey), matching: matching);

/// The ambient background, painted inside its own [RepaintBoundary].
Finder _isolatedBackground() => find.descendant(
  of: find.byType(PageScaffold),
  matching: find.byWidgetPredicate(
    (widget) =>
        widget is RepaintBoundary &&
        widget.child is Container &&
        (widget.child! as Container).decoration is BoxDecoration,
  ),
);

void main() {
  group('PageScaffold', () {
    testWidgets('paints behind the bar and the gesture handle by default', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.shuklaTheme,
          home: const PageScaffold(body: SizedBox.shrink(key: bodyKey)),
        ),
      );

      final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
      expect(scaffold.extendBodyBehindAppBar, isTrue);

      final appBar = tester.widget<AppBar>(find.byType(AppBar));
      expect(appBar.automaticallyImplyLeading, isFalse);
      expect(appBar.backgroundColor, Colors.transparent);
      expect(appBar.elevation, 0);

      // Background in its own boundary, so the gradient does not repaint on
      // every scroll frame.
      expect(_isolatedBackground(), findsOneWidget);

      // The gradient has to reach the gesture handle, so the safe area only
      // claims the top/side insets and the scroll view pads its own last row.
      final safeArea = tester.widget<SafeArea>(
        _ancestorsOfBody(find.byType(SafeArea)),
      );
      expect(safeArea.bottom, isFalse);
    });

    testWidgets('form-style shell keeps the body below the bar', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.shuklaTheme,
          home: const PageScaffold(
            extendBodyBehindAppBar: false,
            body: SizedBox.shrink(key: bodyKey),
          ),
        ),
      );

      final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
      expect(scaffold.extendBodyBehindAppBar, isFalse);

      // Nothing sits behind the bar, so there is no inset to avoid.
      expect(_ancestorsOfBody(find.byType(SafeArea)), findsNothing);

      // The background is still painted, but as a plain wrapper around the
      // body instead of an isolated layer behind it.
      expect(_isolatedBackground(), findsNothing);
      expect(
        _ancestorsOfBody(
          find.byWidgetPredicate(
            (widget) => widget is Container && widget.decoration != null,
          ),
        ),
        findsOneWidget,
      );
    });

    testWidgets('edge-to-edge shell adds no background and no safe area', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.shuklaTheme,
          home: const PageScaffold(
            background: false,
            safeArea: false,
            body: SizedBox.shrink(key: bodyKey),
          ),
        ),
      );

      // The map/canvas paints its own surface; a shell background would hide
      // it and a safe area would inset it off the screen edges.
      expect(_ancestorsOfBody(find.byType(SafeArea)), findsNothing);
      expect(_isolatedBackground(), findsNothing);
      expect(
        _ancestorsOfBody(
          find.byWidgetPredicate(
            (widget) => widget is Container && widget.decoration != null,
          ),
        ),
        findsNothing,
      );
    });

    testWidgets('centerTitle overrides the theme only when supplied', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.shuklaTheme,
          home: const PageScaffold(body: SizedBox.shrink(key: bodyKey)),
        ),
      );
      expect(tester.widget<AppBar>(find.byType(AppBar)).centerTitle, isNull);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.shuklaTheme,
          home: const PageScaffold(
            centerTitle: false,
            body: SizedBox.shrink(key: bodyKey),
          ),
        ),
      );
      expect(tester.widget<AppBar>(find.byType(AppBar)).centerTitle, isFalse);
    });

    testWidgets('forwards the app bar chrome and the drawer callback', (
      tester,
    ) async {
      bool? drawerOpened;
      var backTaps = 0;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.shuklaTheme,
          home: DefaultTabController(
            length: 1,
            child: PageScaffold(
              title: const Text('Title'),
              leading: IconButton(
                icon: const Icon(Icons.arrow_back_rounded),
                onPressed: () => backTaps++,
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.search_rounded),
                  onPressed: () {},
                ),
              ],
              bottom: const TabBar(tabs: [Tab(text: 'One')]),
              drawer: const Drawer(),
              onDrawerChanged: (isOpened) => drawerOpened = isOpened,
              body: const SizedBox.shrink(key: bodyKey),
            ),
          ),
        ),
      );

      expect(find.text('Title'), findsOneWidget);
      expect(find.byType(TabBar), findsOneWidget);
      expect(find.byIcon(Icons.search_rounded), findsOneWidget);

      await tester.tap(find.byIcon(Icons.arrow_back_rounded));
      expect(backTaps, 1);

      tester.state<ScaffoldState>(find.byType(Scaffold)).openDrawer();
      await tester.pumpAndSettle();
      expect(drawerOpened, isTrue);
    });
  });
}
