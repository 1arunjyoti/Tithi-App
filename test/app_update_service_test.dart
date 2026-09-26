import 'package:flutter_test/flutter_test.dart';
import 'package:tithi/services/app_update_service.dart';

void main() {
  group('AppUpdateService.normalizeVersion', () {
    test('strips a leading v and whitespace', () {
      // Arrange
      const tag = '  v0.6.0+3  ';

      // Act
      final normalized = AppUpdateService.normalizeVersion(tag);

      // Assert
      expect(normalized, equals('0.6.0+3'));
    });

    test('leaves plain versions untouched', () {
      expect(AppUpdateService.normalizeVersion('0.5.0+2'), equals('0.5.0+2'));
    });
  });

  group('AppUpdateService.compareVersions', () {
    test('orders patch versions correctly', () {
      // Arrange
      const current = '0.5.0+2';
      const latest = '0.6.0+3';

      // Act + Assert
      expect(AppUpdateService.compareVersions(current, latest), lessThan(0));
      expect(AppUpdateService.compareVersions(latest, current), greaterThan(0));
      expect(AppUpdateService.compareVersions(current, current), equals(0));
    });

    test('compares build numbers when cores are equal', () {
      expect(
        AppUpdateService.compareVersions('0.5.0+2', '0.5.0+3'),
        lessThan(0),
      );
      expect(
        AppUpdateService.compareVersions('0.5.0', '0.5.0+1'),
        lessThan(0),
      );
    });

    test('treats missing segments as zero', () {
      expect(AppUpdateService.compareVersions('0.5', '0.5.0'), equals(0));
      expect(AppUpdateService.compareVersions('1', '0.9.9'), greaterThan(0));
    });

    test('accepts tags with a leading v', () {
      expect(
        AppUpdateService.compareVersions('0.5.0+2', 'v0.6.0'),
        lessThan(0),
      );
    });
  });

  group('AppUpdateService.isNewerThan', () {
    test('detects a newer release with a higher build number', () {
      expect(AppUpdateService.isNewerThan('0.5.0+2', 'v0.6.0+3'), isTrue);
    });

    test('treats a same-name rebuild with higher build as an update', () {
      // Arrange: hotfix published without bumping the version name.
      const current = '0.5.0+2';
      const latest = '0.5.0+3';

      // Act + Assert
      expect(AppUpdateService.isNewerThan(current, latest), isTrue);
    });

    test('ignores identical versions', () {
      expect(AppUpdateService.isNewerThan('0.5.0+2', '0.5.0+2'), isFalse);
      expect(AppUpdateService.isNewerThan('0.5.0+2', 'v0.5.0+2'), isFalse);
    });

    test('ignores a higher version name with a lower build number', () {
      // Arrange: Android would reject this APK (versionCode not higher),
      // so it must never be offered as an update.
      const current = '0.5.0+10';
      const latest = '0.6.0+3';

      // Act + Assert
      expect(AppUpdateService.isNewerThan(current, latest), isFalse);
    });

    test('ignores an older version name even with a higher build number', () {
      expect(AppUpdateService.isNewerThan('0.6.0+3', '0.5.9+10'), isFalse);
    });

    test('returns false for blank versions', () {
      expect(AppUpdateService.isNewerThan('', '0.6.0+3'), isFalse);
      expect(AppUpdateService.isNewerThan('0.5.0+2', ''), isFalse);
    });
  });

  group('AppReleaseInfo.fromJson', () {
    Map<String, dynamic> releaseJson() {
      return {
        'tag_name': 'v0.6.0+3',
        'name': 'Tithi 0.6.0',
        'body': 'Bug fixes and improvements.',
        'html_url': 'https://github.com/1arunjyoti/Tithi-App/releases/tag/v0.6.0',
        'published_at': '2026-09-20T10:00:00Z',
        'assets': [
          {
            'name': 'tithi-0.6.0+3-release.apk',
            'browser_download_url':
                'https://github.com/1arunjyoti/Tithi-App/releases/download/v0.6.0/tithi-0.6.0+3-release.apk',
            'size': 42000000,
          },
          {
            'name': 'tithi-0.6.0+3-staging.apk',
            'browser_download_url':
                'https://github.com/1arunjyoti/Tithi-App/releases/download/v0.6.0/tithi-0.6.0+3-staging.apk',
            'size': 42000001,
          },
        ],
      };
    }

    test('parses version and prefers the release APK asset', () {
      // Arrange
      final json = releaseJson();

      // Act
      final release = AppReleaseInfo.fromJson(json);

      // Assert
      expect(release.tagName, equals('v0.6.0+3'));
      expect(release.version, equals('0.6.0+3'));
      expect(release.name, equals('Tithi 0.6.0'));
      expect(release.body, contains('Bug fixes'));
      expect(release.hasApk, isTrue);
      expect(
        release.apkUrl.toString(),
        contains('tithi-0.6.0+3-release.apk'),
      );
      expect(release.apkSizeBytes, equals(42000000));
      expect(release.publishedAt?.year, equals(2026));
    });

    test('reports no APK when the release has no apk asset', () {
      // Arrange
      final json = releaseJson()
        ..['assets'] = [
          {'name': 'notes.txt', 'browser_download_url': 'https://x/y'},
        ];

      // Act
      final release = AppReleaseInfo.fromJson(json);

      // Assert
      expect(release.hasApk, isFalse);
      expect(release.apkUrl, isNull);
    });

    test('falls back to any APK when no release APK exists', () {
      // Arrange
      final json = releaseJson()
        ..['assets'] = [
          {
            'name': 'app-debug.apk',
            'browser_download_url': 'https://x/app-debug.apk',
            'size': 10,
          },
        ];

      // Act
      final release = AppReleaseInfo.fromJson(json);

      // Assert
      expect(release.hasApk, isTrue);
      expect(release.apkUrl.toString(), contains('app-debug.apk'));
    });
  });
}
