import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tithi/theme/app_metrics.dart';
import 'package:tithi/theme/app_theme.dart';
import 'package:tithi/widgets/skeleton.dart';
import 'package:tithi/widgets/state_views.dart';

/// Pumps [child] under the Shukla theme; the state views read their inks from
/// the theme extensions, so they need a real palette to resolve.
Widget _host(Widget child) {
  return MaterialApp(
    theme: AppTheme.shuklaTheme,
    home: Scaffold(body: Center(child: child)),
  );
}

void main() {
  group('EmptyState', () {
    testWidgets('page variant renders one 48dp glyph, title and body', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          const EmptyState(
            icon: Icons.event_busy_rounded,
            title: 'No festivals yet',
            message: 'Add one from the toolbar.',
          ),
        ),
      );

      final icon = tester.widget<Icon>(find.byType(Icon));
      expect(icon.size, AppIconSize.empty);
      expect(icon.icon, Icons.event_busy_rounded);
      expect(find.text('No festivals yet'), findsOneWidget);
      expect(find.text('Add one from the toolbar.'), findsOneWidget);
    });

    testWidgets('page variant is display-only: no action button', (
      tester,
    ) async {
      // Every empty state in the app already has its action in a toolbar, a
      // FAB or an adjacent control; a second copy here would duplicate it.
      await tester.pumpWidget(
        _host(const EmptyState(icon: Icons.inbox, title: 'Nothing here')),
      );

      expect(find.byType(FilledButton), findsNothing);
      expect(find.byType(TextButton), findsNothing);
    });

    testWidgets('inline variant is a 20dp glyph on one line', (tester) async {
      await tester.pumpWidget(
        _host(
          const EmptyState(
            icon: Icons.event_available_rounded,
            title: 'No festivals in the next 3 days',
            variant: StateViewVariant.inline,
          ),
        ),
      );

      final icon = tester.widget<Icon>(find.byType(Icon));
      expect(icon.size, AppIconSize.medium);
      expect(find.byType(Row), findsOneWidget);
      expect(find.text('No festivals in the next 3 days'), findsOneWidget);
    });

    testWidgets('card variant keeps the title and body inside card padding', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          const EmptyState(
            icon: Icons.cloud_off_outlined,
            title: 'Weather unavailable',
            variant: StateViewVariant.card,
          ),
        ),
      );

      final padding = tester.widget<Padding>(
        find
            .descendant(
              of: find.byType(EmptyState),
              matching: find.byType(Padding),
            )
            .first,
      );
      expect(
        padding.padding,
        const EdgeInsets.symmetric(
          horizontal: AppSpacing.s16,
          vertical: AppSpacing.s24,
        ),
      );
    });

    testWidgets('title and body are announced as one node', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        _host(
          const EmptyState(
            icon: Icons.inbox,
            title: 'No countdowns yet',
            message: 'Pin a festival to start one.',
          ),
        ),
      );

      expect(
        find.bySemanticsLabel(
          'No countdowns yet. Pin a festival to start one.',
        ),
        findsOneWidget,
      );
      handle.dispose();
    });
  });

  group('ErrorState', () {
    testWidgets('defaults to the generic heading and offers retry', (
      tester,
    ) async {
      var retries = 0;
      await tester.pumpWidget(
        _host(
          ErrorState(
            message: 'Could not load festivals. Please try again.',
            onRetry: () => retries++,
          ),
        ),
      );

      expect(find.text('Something went wrong'), findsOneWidget);
      expect(
        find.text('Could not load festivals. Please try again.'),
        findsOneWidget,
      );

      await tester.tap(find.text('Retry'));
      expect(retries, 1);
    });

    testWidgets('keeps a caller-supplied heading', (tester) async {
      await tester.pumpWidget(
        _host(
          const ErrorState(
            title: 'Weather unavailable',
            message: 'Please try again in a moment.',
          ),
        ),
      );

      expect(find.text('Weather unavailable'), findsOneWidget);
      expect(find.text('Something went wrong'), findsNothing);
    });

    testWidgets('no retry control when the caller cannot retry', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(const ErrorState(message: 'Something went wrong.')),
      );

      expect(find.byType(FilledButton), findsNothing);
      expect(find.byType(TextButton), findsNothing);
    });

    testWidgets('renders the friendly copy verbatim, never an exception', (
      tester,
    ) async {
      // The detail belongs in the log: a Text must never carry `Exception:`.
      await tester.pumpWidget(
        _host(
          const ErrorState(
            message: 'Could not load festivals. Please try again.',
          ),
        ),
      );

      expect(find.textContaining('Exception'), findsNothing);
      expect(
        find.text('Could not load festivals. Please try again.'),
        findsOneWidget,
      );
    });

    testWidgets('inline variant stays on one line with a text retry', (
      tester,
    ) async {
      var retries = 0;
      await tester.pumpWidget(
        _host(
          ErrorState(
            message: 'Could not load festivals.',
            onRetry: () => retries++,
            variant: StateViewVariant.inline,
          ),
        ),
      );

      expect(find.byType(Row), findsOneWidget);
      expect(find.byType(FilledButton), findsNothing);

      await tester.tap(find.byType(TextButton));
      expect(retries, 1);
    });
  });

  group('SkeletonBox', () {
    testWidgets('paints one 6% surface tint at the requested radius', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(const SkeletonBox(height: 76, radius: AppRadius.chip)),
      );

      final box = tester.widget<Container>(
        find.descendant(
          of: find.byType(SkeletonBox),
          matching: find.byType(Container),
        ),
      );
      final decoration = box.decoration! as BoxDecoration;
      expect(
        decoration.color!.a,
        closeTo(AppTheme.shuklaTheme.colorScheme.onSurface.a * 0.06, 0.001),
      );
      expect(decoration.borderRadius, BorderRadius.circular(AppRadius.chip));
      expect(tester.getSize(find.byType(SkeletonBox)).height, 76);
    });
  });

  group('SkeletonList', () {
    testWidgets('renders the requested item count at the requested height', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(const SkeletonList(count: 4, itemHeight: 40, gap: AppSpacing.s8)),
      );

      expect(find.byType(SkeletonBox), findsNWidgets(4));
      for (final element in find.byType(SkeletonBox).evaluate()) {
        expect(tester.getSize(find.byWidget(element.widget)).height, 40);
      }
    });

    testWidgets('defaults to three 76dp rows', (tester) async {
      await tester.pumpWidget(_host(const SkeletonList()));

      expect(find.byType(SkeletonBox), findsNWidgets(3));
      expect(tester.getSize(find.byType(SkeletonBox).first).height, 76);
    });
  });

  group('InlineSpinner', () {
    testWidgets('defaults to the 16dp inline size on the primary ink', (
      tester,
    ) async {
      await tester.pumpWidget(_host(const InlineSpinner()));

      final size = tester.getSize(find.byType(InlineSpinner));
      expect(size.width, AppIconSize.small);
      expect(size.height, AppIconSize.small);

      final spinner = tester.widget<CircularProgressIndicator>(
        find.byType(CircularProgressIndicator),
      );
      expect(spinner.strokeWidth, 2);
      expect(spinner.color, AppTheme.shuklaTheme.colorScheme.primary);
    });

    testWidgets('honours an explicit size and colour', (tester) async {
      await tester.pumpWidget(
        _host(const InlineSpinner(size: AppIconSize.large, color: Colors.teal)),
      );

      expect(tester.getSize(find.byType(InlineSpinner)).width, 22);
      final spinner = tester.widget<CircularProgressIndicator>(
        find.byType(CircularProgressIndicator),
      );
      expect(spinner.color, Colors.teal);
    });
  });
}
