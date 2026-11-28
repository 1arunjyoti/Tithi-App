import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_3_expressive/material_3_expressive.dart';
import 'package:material_ui/material_ui.dart';

import 'package:tithi/features/settings/widgets/notification_settings.dart';
import 'package:tithi/providers/accessibility_provider.dart';
import 'package:tithi/providers/notification_provider.dart';
import 'package:tithi/services/notification_service.dart';
import 'package:tithi/theme/app_theme.dart';

class _EnabledNotifications extends NotificationEnabledNotifier {
  @override
  bool build() => true;
}

class _StubAccessibility extends AccessibilityNotifier {
  @override
  AccessibilityState build() => const AccessibilityState();
}

/// The settings notification-time row used the framework `TimePickerDialog`
/// with a hand-tuned `TimePickerThemeData`. It must open the Material 3
/// Expressive time picker instead.
void main() {
  testWidgets('notification time opens the expressive time picker', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          accessibilityProvider.overrideWith(_StubAccessibility.new),
          notificationServiceProvider.overrideWithValue(NotificationService()),
          loadNotificationStateProvider.overrideWith((ref) async {}),
          notificationEnabledProvider.overrideWith(_EnabledNotifications.new),
        ],
        child: MaterialApp(
          theme: AppTheme.shuklaTheme,
          home: const Scaffold(body: NotificationSettings()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final row = find.text('Notification Time');
    expect(row, findsOneWidget);
    await tester.tap(row);
    await tester.pumpAndSettle();

    expect(find.byType(M3ETimePickerDialog), findsOneWidget);
    expect(find.byType(TimePickerDialog), findsNothing);
  });
}
