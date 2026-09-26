import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:tithi/features/settings/widgets/app_update_settings.dart';
import 'package:tithi/providers/accessibility_provider.dart';
import 'package:tithi/providers/app_update_provider.dart';
import 'package:tithi/providers/version_provider.dart';
import 'package:tithi/services/app_update_service.dart';

class _FixedAccessibility extends AccessibilityNotifier {
  @override
  AccessibilityState build() => const AccessibilityState();
}

class _FixedUpdateNotifier extends AppUpdateNotifier {
  _FixedUpdateNotifier(super.service, AppUpdateState initial) {
    state = initial;
  }
}

void main() {
  AppReleaseInfo releaseFixture() => AppReleaseInfo(
    tagName: 'v0.1.7',
    version: '0.1.7',
    name: 'Tithi 0.1.7',
    body: 'Notes from the older 0.1.7 release',
    htmlUrl: Uri.https(
      'github.com',
      '/1arunjyoti/Tithi-App/releases/tag/v0.1.7',
    ),
    publishedAt: null,
    apkUrl: Uri.https(
      'github.com',
      '/1arunjyoti/Tithi-App/releases/download/v0.1.7/app.apk',
    ),
    apkSizeBytes: 82100000,
  );

  PackageInfo installedInfo() => PackageInfo(
    appName: 'Tithi',
    packageName: 'app.tithi.pro',
    version: '0.5.0',
    buildNumber: '2',
  );

  Future<void> pumpCard(WidgetTester tester, AppUpdateState state) async {
    // Arrange is done by the caller via the fixed state; pump the card
    // with all platform-dependent providers overridden.
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          accessibilityProvider.overrideWith(_FixedAccessibility.new),
          packageInfoProvider.overrideWith((ref) => Future.value(installedInfo())),
          appUpdateProvider.overrideWith(
            (ref) => _FixedUpdateNotifier(AppUpdateService(), state),
          ),
        ],
        child: const MaterialApp(home: Scaffold(body: AppUpdateCard())),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('AppUpdateCard release notes visibility', () {
    testWidgets('hides notes of an older release when up to date', (
      tester,
    ) async {
      // Arrange: installed 0.5.0+2, latest published is the older 0.1.7.
      final state = AppUpdateState(
        status: AppUpdateStatus.upToDate,
        currentVersion: '0.5.0+2',
        release: releaseFixture(),
      );

      // Act
      await pumpCard(tester, state);

      // Assert: verdict visible, but the old release is not presented.
      expect(find.textContaining("You're up to date"), findsOneWidget);
      expect(find.textContaining('Notes from the older'), findsNothing);
      expect(find.textContaining('0.1.7'), findsNothing);
    });

    testWidgets('shows notes when an update is available', (tester) async {
      // Arrange
      final state = AppUpdateState(
        status: AppUpdateStatus.available,
        currentVersion: '0.5.0+2',
        release: releaseFixture(),
      );

      // Act
      await pumpCard(tester, state);

      // Assert
      expect(find.textContaining('Notes from the older'), findsOneWidget);
      expect(find.text('Download update'), findsOneWidget);
    });
  });
}
