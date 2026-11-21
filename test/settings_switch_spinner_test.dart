import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tithi/theme/app_theme.dart';
import 'package:tithi/widgets/settings_widgets.dart';

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

    final spinner = find.byType(CircularProgressIndicator);
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

  testWidgets('no spinner is built when the row is not loading', (tester) async {
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

    expect(find.byType(CircularProgressIndicator), findsNothing);
  });
}
