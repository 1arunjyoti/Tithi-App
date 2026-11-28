import 'package:material_ui/material_ui.dart';
import 'package:material_3_expressive/material_3_expressive.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tithi/providers/accessibility_provider.dart';
import 'package:tithi/theme/app_theme.dart';
import 'package:tithi/theme/app_typography.dart';
import 'package:tithi/widgets/app_buttons.dart';

class _StubAccessibility extends AccessibilityNotifier {
  @override
  AccessibilityState build() => const AccessibilityState();
}

void main() {
  testWidgets('shared button keeps the app semibold label', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [accessibilityProvider.overrideWith(_StubAccessibility.new)],
        child: MaterialApp(
          theme: AppTheme.shuklaTheme,
          home: const Scaffold(
            body: Center(
              child: AppButton(onPressed: null, child: Text('Save')),
            ),
          ),
        ),
      ),
    );

    final button = tester.widget<M3EButton>(find.byType(M3EButton));
    expect(
      button.decoration?.textStyle?.fontWeight,
      equals(AppTypography.semibold),
    );
    expect(button.size, equals(M3EButtonSize.md));
  });
}
