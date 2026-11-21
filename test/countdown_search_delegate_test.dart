import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tithi/features/countdown/providers/countdown_providers.dart';
import 'package:tithi/l10n/app_localizations.dart';
import 'package:tithi/models/festival.dart';
import 'package:tithi/providers/accessibility_provider.dart';
import 'package:tithi/providers/festival_provider.dart';
import 'package:tithi/features/festival_search/widgets/countdown_search_delegate.dart';

// Characterization tests for the countdown festival search, written before the
// delegate moved out of festival_countdown_screen.dart into
// features/festival_search/widgets/. They pin the matching rules (Bengali
// names, already-added exclusion, major-first sort), both empty states and the
// tap result, so the extraction cannot silently change what a user sees.

class _NoHapticsNotifier extends AccessibilityNotifier {
  @override
  AccessibilityState build() => const AccessibilityState(hapticFeedback: false);
}

/// Countdown list pinned to a fixed set of ids (the real notifier reads Hive).
class _FixedCountdownPrefs extends FestivalCountdownPreferencesNotifier {
  _FixedCountdownPrefs(this.ids);

  final List<String> ids;

  @override
  FestivalCountdownPreferences build() => FestivalCountdownPreferences(
    countdownIds: ids,
    homeCountdownIds: const {},
  );
}

Festival _festival({
  required String id,
  required String name,
  String category = 'major',
  String? hindi,
  String? bengali,
}) {
  return Festival(
    id: id,
    name: name,
    category: category,
    nameRegional: NameRegional(
      nameEnglish: name,
      nameHindi: hindi,
      nameBengali: bengali,
    ),
    visuals: const Visuals(),
    purpose: const Purpose(description: 'A test festival.'),
    panchangRules: const PanchangRules(
      masa: '',
      paksha: 'Shukla',
      tithi: 4,
      conditions: '',
    ),
    rituals: const Rituals(steps: []),
    media: const Media(),
  );
}

void main() {
  late List<Festival?> results;

  setUp(() => results = []);

  Future<void> pumpSearch(
    WidgetTester tester, {
    required List<Festival> festivals,
    List<String> countdownIds = const [],
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          festivalProvider.overrideWithValue(festivals),
          accessibilityProvider.overrideWith(_NoHapticsNotifier.new),
          festivalCountdownPreferencesProvider.overrideWith(
            () => _FixedCountdownPrefs(countdownIds),
          ),
        ],
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: _SearchHost(onResult: results.add),
        ),
      ),
    );
    await tester.tap(find.text('open search'));
    await tester.pumpAndSettle();
  }

  Future<void> type(WidgetTester tester, String query) async {
    await tester.enterText(find.byType(TextField), query);
    await tester.pumpAndSettle();
  }

  testWidgets('excludes festivals already in the countdown list', (
    tester,
  ) async {
    await pumpSearch(
      tester,
      festivals: [
        _festival(id: 'aarti', name: 'Aarti'),
        _festival(id: 'aarambh', name: 'Aarambh', category: 'vrat'),
      ],
      countdownIds: const ['aarti'],
    );

    await type(tester, 'aa');

    expect(find.text('Aarambh'), findsOneWidget);
    expect(find.text('Aarti'), findsNothing);
  });

  testWidgets('matches a Bengali name', (tester) async {
    await pumpSearch(
      tester,
      festivals: [
        _festival(id: 'navratri', name: 'Navratri', bengali: 'Sharodiya'),
        _festival(id: 'diwali', name: 'Diwali'),
      ],
    );

    await type(tester, 'sharodiya');

    expect(find.text('Navratri'), findsOneWidget);
    expect(find.text('Diwali'), findsNothing);
  });

  testWidgets('lists major festivals before minor ones', (tester) async {
    await pumpSearch(
      tester,
      festivals: [
        _festival(id: 'aarambh', name: 'Aarambh', category: 'vrat'),
        _festival(id: 'aarti', name: 'Aarti'),
      ],
    );

    await type(tester, 'aa');

    final majorY = tester.getTopLeft(find.text('Aarti')).dy;
    final minorY = tester.getTopLeft(find.text('Aarambh')).dy;
    expect(majorY, lessThan(minorY));
  });

  testWidgets('shows the prompt glyph before any query', (tester) async {
    await pumpSearch(
      tester,
      festivals: [_festival(id: 'x', name: 'Diwali')],
    );

    expect(find.byIcon(Icons.search_rounded), findsOneWidget);
    expect(find.text('Diwali'), findsNothing);
  });

  testWidgets('shows the no-results state for an unmatched query', (
    tester,
  ) async {
    await pumpSearch(
      tester,
      festivals: [_festival(id: 'x', name: 'Diwali')],
    );

    await type(tester, 'zzzz');

    expect(find.text('No festivals found'), findsOneWidget);
  });

  testWidgets('tapping a result closes the search with that festival', (
    tester,
  ) async {
    await pumpSearch(
      tester,
      festivals: [
        _festival(id: 'diwali', name: 'Diwali'),
        _festival(id: 'dussehra', name: 'Dussehra'),
      ],
    );

    await type(tester, 'dus');
    await tester.tap(find.text('Dussehra'));
    await tester.pumpAndSettle();

    expect(results, hasLength(1));
    expect(results.single?.id, 'dussehra');
    expect(find.text('open search'), findsOneWidget);
  });
}

/// Kept as a widget (not a closure) so the test can host it under
/// `MaterialApp` while the delegate receives a live [WidgetRef].
class _SearchHost extends ConsumerWidget {
  const _SearchHost({required this.onResult});

  final void Function(Festival?) onResult;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: Builder(
        builder: (context) => TextButton(
          onPressed: () async {
            final result = await showSearch<Festival?>(
              context: context,
              delegate: CountdownFestivalSearchDelegate(ref: ref),
            );
            onResult(result);
          },
          child: const Text('open search'),
        ),
      ),
    );
  }
}
