import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:flutter_localizations/flutter_localizations.dart'
    show GlobalWidgetsLocalizations;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tithi/features/eclipse/providers/eclipse_providers.dart';
import 'package:tithi/features/moon/domain/moon_distance.dart';
import 'package:tithi/features/moon/domain/moon_viewing.dart';
import 'package:tithi/features/moon/providers/moon_details_providers.dart';
import 'package:tithi/features/moon/widgets/moon_insight_cards.dart';
import 'package:tithi/providers/accessibility_provider.dart';
import 'package:tithi/features/moon/widgets/moon_timings_card.dart';
import 'package:tithi/l10n/app_localizations.dart';
import 'package:tithi/models/eclipse.dart';
import 'package:tithi/services/moon_distance_service.dart';

/// Accessibility state without Hive (the settings box is closed under
/// flutter_test).
class FakeAccessibilityNotifier extends AccessibilityNotifier {
  @override
  AccessibilityState build() => const AccessibilityState();
}

void main() {
  testWidgets('moon detail cards render sky times, distance and eclipse', (
    tester,
  ) async {
    final date = DateTime(2026, 6, 15);
    final rise = DateTime(2026, 6, 15, 19);
    final set = DateTime(2026, 6, 16, 5);
    final container = ProviderContainer(
      overrides: [
        accessibilityProvider.overrideWith(FakeAccessibilityNotifier.new),
        moonSkyTimesProvider.overrideWith(
          (ref, d) async => MoonSkyTimes(rise: rise, set: set),
        ),
        moonViewingWindowProvider.overrideWith(
          (ref, d) async =>
              MoonViewingWindow(start: rise, end: set, isMorning: false),
        ),
        moonDistanceInfoProvider.overrideWith(
          (ref, d) async => const MoonDistanceInfo(
            distanceKm: 357000,
            kind: MoonDistanceKind.supermoon,
          ),
        ),
        upcomingEclipsesProvider.overrideWith(
          (ref) async => [
            Eclipse(
              type: EclipseType.lunarTotal,
              maxEclipseTime: DateTime(2026, 6, 30, 12),
              visibleAtLocation: true,
            ),
          ],
        ),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: SingleChildScrollView(
              child: Column(
                children: [
                  MoonTimingsCard(date: date),
                  MoonDistanceCard(date: date),
                  const MoonEclipseCard(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Best viewing time'), findsOneWidget);
    expect(find.text('Moonrise'), findsOneWidget);
    expect(find.text('Moonset'), findsOneWidget);
    expect(find.text('Moon distance'), findsOneWidget);
    expect(find.textContaining('km from Earth'), findsWidgets);
    expect(find.text('Supermoon'), findsOneWidget);
    expect(find.text('Next eclipse'), findsOneWidget);
    expect(find.text('Visible from your location'), findsOneWidget);
  });

  testWidgets('eclipse card hides when only solar eclipses are upcoming', (
    tester,
  ) async {
    final container = ProviderContainer(
      overrides: [
        accessibilityProvider.overrideWith(FakeAccessibilityNotifier.new),
        upcomingEclipsesProvider.overrideWith(
          (ref) async => [
            Eclipse(
              type: EclipseType.solarTotal,
              maxEclipseTime: DateTime(2026, 8, 12, 12),
            ),
          ],
        ),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          localizationsDelegates: [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: MoonEclipseCard()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Next eclipse'), findsNothing);
  });
}
