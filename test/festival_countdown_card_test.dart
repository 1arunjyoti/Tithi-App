import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tithi/features/countdown/providers/countdown_providers.dart';
import 'package:tithi/models/festival.dart';
import 'package:tithi/providers/accessibility_provider.dart';
import 'package:tithi/theme/app_theme.dart';
import 'package:tithi/widgets/festival_countdown_card.dart';
import 'package:tithi/widgets/inset_row_divider.dart';

class _NoHapticsNotifier extends AccessibilityNotifier {
  @override
  AccessibilityState build() => const AccessibilityState(hapticFeedback: false);
}

Festival _festival(String id, String name) => Festival(
  id: id,
  name: name,
  category: 'major',
  nameRegional: NameRegional(nameEnglish: name),
  visuals: const Visuals(),
  purpose: const Purpose(description: 'Test description'),
  panchangRules: const PanchangRules(
    masa: '',
    paksha: 'Shukla',
    tithi: 1,
    conditions: '',
  ),
  rituals: const Rituals(steps: []),
  media: const Media(),
);

FestivalCountdownTarget _target({
  required String id,
  required String title,
  required int days,
}) {
  final now = DateTime.now();
  final day = DateTime(now.year, now.month, now.day).add(Duration(days: days));
  return FestivalCountdownTarget(
    id: id,
    title: title,
    festival: _festival(id, title),
    date: day,
    daysRemaining: days,
  );
}

void main() {
  Future<void> pumpCard(
    WidgetTester tester,
    List<FestivalCountdownTarget> targets,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          homeFestivalCountdownTargetsProvider.overrideWith(
            (ref) async => targets,
          ),
          accessibilityProvider.overrideWith(_NoHapticsNotifier.new),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(child: FestivalCountdownCard()),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('countdown rows sit flush on the base card', (tester) async {
    // Arrange
    await pumpCard(tester, [
      _target(id: 'diwali', title: 'Diwali', days: 130),
      _target(id: 'holi', title: 'Holi', days: 200),
      _target(id: 'pongal', title: 'Pongal', days: 260),
    ]);

    // Assert: one hairline between 3 rows, none after the last. The indent
    // clears the day badge *and* the row's own horizontal inset, so the
    // divider starts under the text column and not under the badge.
    expect(find.byType(InsetRowDivider), findsNWidgets(2));
    for (final divider in tester.widgetList<InsetRowDivider>(
      find.byType(InsetRowDivider),
    )) {
      expect(
        divider.leadingInset,
        FestivalCountdownTile.textColumnInset + AppTheme.homeCardRowInset,
      );
    }

    // Assert: the embedded row carries no surface of its own, and its
    // horizontal inset plus the base card's 4dp side padding add up to the
    // heading's 16dp gutter, so its day badge aligns with the heading.
    final surface = tester.widget<Container>(
      find
          .descendant(
            of: find.byType(InkWell).first,
            matching: find.byType(Container),
          )
          .first,
    );
    expect(surface.decoration, isNull);
    final padding = surface.padding! as EdgeInsets;
    expect(padding.left, AppTheme.homeCardRowInset);
    expect(padding.right, AppTheme.homeCardRowInset);
    expect(padding.top, greaterThan(0));

    final header = tester.getTopLeft(find.text('Festival Countdowns'));
    final badge = tester.getTopLeft(
      find.byWidget(
        tester
            .widgetList<Container>(
              find.descendant(
                of: find.byType(FestivalCountdownTile).first,
                matching: find.byType(Container),
              ),
            )
            .firstWhere((c) => c.constraints?.maxWidth == 76),
      ),
    );
    expect(badge.dx, closeTo(header.dx, 0.5));
  });

  testWidgets('countdown rows keep a comfortable tap target', (tester) async {
    // Arrange
    await pumpCard(tester, [
      _target(id: 'diwali', title: 'Diwali', days: 130),
      _target(id: 'holi', title: 'Holi', days: 200),
    ]);

    // Assert: the day badge alone is 76, so the flush row clears 48dp.
    for (final element in find.byType(FestivalCountdownTile).evaluate()) {
      expect(element.size!.height, greaterThanOrEqualTo(48));
    }
  });
}
