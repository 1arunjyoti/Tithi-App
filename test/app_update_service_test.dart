import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' show Response;
import 'package:http/testing.dart';
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

    test('strips the CI --release tag marker', () {
      // Release tags are pushed as `v0.9.10+42--release`. If the marker leaks
      // into the build-number segment, `int.tryParse('42--release')` is null,
      // the build reads as 0, and every update is silently suppressed.
      expect(
        AppUpdateService.normalizeVersion('v0.9.10+42--release'),
        equals('0.9.10+42'),
      );
      expect(
        AppUpdateService.normalizeVersion('0.9.10+42--release'),
        equals('0.9.10+42'),
      );
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
      expect(AppUpdateService.compareVersions('0.5.0', '0.5.0+1'), lessThan(0));
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

  group('AppUpdateService.fullVersion', () {
    test('joins PackageInfo version and build number', () {
      expect(AppUpdateService.fullVersion('0.5.0', '5'), equals('0.5.0+5'));
    });

    test('handles tags and blank build numbers', () {
      expect(AppUpdateService.fullVersion('v0.5.0', '5'), equals('0.5.0+5'));
      expect(AppUpdateService.fullVersion('0.5.0', ''), equals('0.5.0'));
    });

  });

  group('AppUpdateService.baseBuildNumber', () {
    test('legacy fallback strips the per-ABI versionCode offset', () {
      // Only used for APKs predating the manifest meta-data, whose base is
      // necessarily below the 1000 stride.
      expect(AppUpdateService.baseBuildNumber('2043'), equals('43'));
      expect(AppUpdateService.baseBuildNumber('4043'), equals('43'));
      expect(AppUpdateService.baseBuildNumber('43'), equals('43'));
      expect(AppUpdateService.baseBuildNumber(''), equals(''));
    });
  });

  group('AppUpdateService.resolveBuildNumber', () {
    test('prefers the manifest +N even when it passes the ABI stride', () async {
      // 1044 cannot be decoded from a versionCode alone: 2044 would be
      // ambiguous between arm64 base 44 and universal base 2044.
      final service = AppUpdateService(baseBuildNumber: () async => '1044');
      expect(await service.resolveBuildNumber('3044'), equals('1044'));
    });

    test('falls back to the versionCode when the manifest has no value',
        () async {
      final service = AppUpdateService(baseBuildNumber: () async => '');
      expect(await service.resolveBuildNumber('2043'), equals('43'));
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

    test('ignores an identical sideloaded build published on github', () {
      // Arrange: 0.5.0(5) installed, same 0.5.0+5 tag published.
      // PackageInfo splits these into version "0.5.0" + buildNumber "5".
      final installed = AppUpdateService.fullVersion('0.5.0', '5');

      // Act + Assert
      expect(installed, equals('0.5.0+5'));
      expect(AppUpdateService.isNewerThan(installed, '0.5.0+5'), isFalse);
      expect(AppUpdateService.isNewerThan(installed, 'v0.5.0+5'), isFalse);
    });

    test('returns false for blank versions', () {
      expect(AppUpdateService.isNewerThan('', '0.6.0+3'), isFalse);
      expect(AppUpdateService.isNewerThan('0.5.0+2', ''), isFalse);
    });

    test('treats a --release tag as the release it names', () {
      // The workflow publishes under the clean tag, but a marker tag must not
      // turn an otherwise valid release into "no update available".
      expect(
        AppUpdateService.isNewerThan('0.9.10+42', 'v0.9.11+43--release'),
        isTrue,
      );
      expect(
        AppUpdateService.isNewerThan('0.9.11+43', 'v0.9.11+43--release'),
        isFalse,
      );
      expect(
        AppUpdateService.isNewerThan('0.9.11+43', 'v0.9.10+42--release'),
        isFalse,
      );
    });
  });

  group('AppUpdateService.displayVersion', () {
    test('keeps the build number visible', () {
      // A same-name rebuild must not look like the installed version.
      expect(AppUpdateService.displayVersion('0.5.0+3'), equals('0.5.0 (3)'));
      expect(AppUpdateService.displayVersion('0.6.0'), equals('0.6.0'));
      expect(AppUpdateService.displayVersion('v0.6.0+7'), equals('0.6.0 (7)'));
      expect(
        AppUpdateService.displayVersion('v0.9.10+42--release'),
        equals('0.9.10 (42)'),
      );
    });
  });

  group('AppReleaseInfo digest parsing', () {
    test('reads the published sha256 digest', () {
      // Arrange
      final json = {
        'tag_name': 'v0.6.0+3',
        'assets': [
          {
            'name': 'tithi-0.6.0+3-release.apk',
            'browser_download_url': 'https://x/app.apk',
            'size': 10,
            'digest':
                'sha256:ebcfe0fbf162be61d2e8029c83463b11612684bf1fc1d2cca8843ecb653b58ac',
          },
        ],
      };

      // Act
      final release = AppReleaseInfo.fromJson(json);

      // Assert
      expect(release.apkDigest, startsWith('sha256:'));
    });

    test('leaves the digest null when absent', () {
      // Arrange
      final json = {
        'tag_name': 'v0.6.0+3',
        'assets': [
          {'name': 'app.apk', 'browser_download_url': 'https://x/app.apk'},
        ],
      };

      // Act + Assert
      expect(AppReleaseInfo.fromJson(json).apkDigest, isNull);
    });
  });

  group('AppReleaseInfo ABI-aware APK selection', () {
    Map<String, dynamic> releaseWith(List<String> assetNames) {
      return {
        'tag_name': 'v0.9.10+42',
        'assets': [
          for (final name in assetNames)
            {
              'name': name,
              'browser_download_url': 'https://example.com/$name',
              'size': 42000000,
            },
        ],
      };
    }

    test('picks the asset for the device ABI', () {
      // CI publishes tithi-arm64-v8a-release.apk and
      // tithi-x86_64-release.apk in the same release.
      final json = releaseWith([
        'tithi-x86_64-release.apk',
        'tithi-arm64-v8a-release.apk',
      ]);

      expect(
        AppReleaseInfo.fromJson(
          json,
          supportedAbis: const ['arm64-v8a', 'armeabi-v7a'],
        ).apkUrl.toString(),
        contains('tithi-arm64-v8a-release.apk'),
      );
      expect(
        AppReleaseInfo.fromJson(
          json,
          supportedAbis: const ['x86_64', 'x86'],
        ).apkUrl.toString(),
        contains('tithi-x86_64-release.apk'),
      );
    });

    test('follows the device ABI preference order', () {
      // Build.SUPPORTED_ABIS lists the 32-bit compat ABI last; the primary
      // ABI must win even when its asset appears later in the release.
      final json = releaseWith([
        'tithi-armeabi-v7a-release.apk',
        'tithi-arm64-v8a-release.apk',
      ]);

      expect(
        AppReleaseInfo.fromJson(
          json,
          supportedAbis: const ['arm64-v8a', 'armeabi-v7a'],
        ).apkUrl.toString(),
        contains('tithi-arm64-v8a-release.apk'),
      );
    });

    test('falls back to a universal asset when no ABI matches', () {
      final json = releaseWith(['tithi-0.9.10+42-release.apk']);

      final info = AppReleaseInfo.fromJson(
        json,
        supportedAbis: const ['arm64-v8a'],
      );

      expect(info.apkUrl.toString(), contains('tithi-0.9.10+42-release.apk'));
    });

    test('reports no APK instead of a foreign-ABI build', () {
      final json = releaseWith(['tithi-arm64-v8a-release.apk']);

      final info = AppReleaseInfo.fromJson(
        json,
        supportedAbis: const ['x86_64', 'x86'],
      );

      expect(info.hasApk, isFalse);
    });

    test('keeps first-asset behaviour when the ABI list is unknown', () {
      final json = releaseWith([
        'tithi-arm64-v8a-release.apk',
        'tithi-x86_64-release.apk',
      ]);

      expect(
        AppReleaseInfo.fromJson(json).apkUrl.toString(),
        contains('tithi-arm64-v8a-release.apk'),
      );
    });

    test('fetchLatestRelease picks the APK for the device', () async {
      final service = AppUpdateService(
        httpClient: MockClient(
          (_) async => Response(
            jsonEncode(
              releaseWith([
                'tithi-arm64-v8a-release.apk',
                'tithi-x86_64-release.apk',
              ]),
            ),
            200,
          ),
        ),
        supportedAbis: () async => const ['x86_64', 'x86'],
      );

      final release = await service.fetchLatestRelease();

      expect(release, isNotNull);
      expect(release!.apkUrl.toString(), contains('tithi-x86_64-release.apk'));
    });
  });

  group('AppUpdateConfig.fromEnvironment', () {
    test('falls back to defaults without a dart-define', () {
      final config = AppUpdateConfig.fromEnvironment();
      expect(config.owner, equals('1arunjyoti'));
      expect(config.repo, equals('Tithi-App'));
    });
  });

  group('AppUpdateService.isCheckThrottled', () {
    test('is false before any check ran', () {
      expect(AppUpdateService().isCheckThrottled(), isFalse);
    });
  });

  group('AppUpdateService.fetchLatestRelease 404 handling', () {
    /// Routes the release endpoint and the repository probe separately.
    AppUpdateService serviceWith({
      required int releasesStatus,
      required int repoStatus,
    }) {
      return AppUpdateService(
        httpClient: MockClient((request) async {
          if (request.url.path.endsWith('/releases/latest')) {
            return Response('{"message":"Not Found"}', releasesStatus);
          }
          return Response('{"full_name":"1arunjyoti/Tithi-App"}', repoStatus);
        }),
      );
    }

    test(
      'reports no releases when the repository exists but is empty',
      () async {
        // Arrange: 404 on the release, 200 on the repository probe.
        final service = serviceWith(releasesStatus: 404, repoStatus: 200);

        // Act
        final release = await service.fetchLatestRelease();

        // Assert
        expect(release, isNull);
      },
    );

    test('reports a missing repository instead of "no releases"', () async {
      // Arrange: both endpoints 404 (renamed, moved or private repo).
      final service = serviceWith(releasesStatus: 404, repoStatus: 404);

      // Act + Assert: the user must not be told to wait for a release.
      await expectLater(
        service.fetchLatestRelease(),
        throwsA(
          isA<AppUpdateException>().having(
            (e) => e.message,
            'message',
            allOf(
              contains('could not be found'),
              isNot(contains('No releases published yet')),
            ),
          ),
        ),
      );
    });

    test(
      'assumes the repository is fine when the probe itself fails',
      () async {
        // Arrange: probe throws, so the "no releases" path is used.
        final service = AppUpdateService(
          httpClient: MockClient((request) async {
            if (request.url.path.endsWith('/releases/latest')) {
              return Response('{"message":"Not Found"}', 404);
            }
            throw const SocketException('probe failed');
          }),
        );

        // Act + Assert
        expect(await service.fetchLatestRelease(), isNull);
      },
    );
  });

  group('AppUpdateService.fetchLatestRelease rate limiting', () {
    AppUpdateService serviceReturning(Response response) {
      return AppUpdateService(httpClient: MockClient((_) async => response));
    }

    test('explains a 403 with no remaining quota', () async {
      // Arrange: GitHub's hourly unauthenticated quota is spent.
      final service = serviceReturning(
        Response(
          '{"message":"API rate limit exceeded"}',
          403,
          headers: {'x-ratelimit-remaining': '0'},
        ),
      );

      // Act + Assert
      await expectLater(
        service.fetchLatestRelease(),
        throwsA(
          isA<AppUpdateException>().having(
            (e) => e.message,
            'message',
            contains('rate limiting'),
          ),
        ),
      );
    });

    test('explains a 429 with no remaining quota', () async {
      // Arrange
      final service = serviceReturning(
        Response(
          '{"message":"Too Many Requests"}',
          429,
          headers: {'x-ratelimit-remaining': '0'},
        ),
      );

      // Act + Assert
      await expectLater(
        service.fetchLatestRelease(),
        throwsA(
          isA<AppUpdateException>().having(
            (e) => e.message,
            'message',
            contains('rate limiting'),
          ),
        ),
      );
    });

    test(
      'keeps the generic message for a 403 that is not rate limiting',
      () async {
        // Arrange: forbidden for some other reason, quota still available.
        final service = serviceReturning(
          Response(
            '{"message":"Forbidden"}',
            403,
            headers: {'x-ratelimit-remaining': '57'},
          ),
        );

        // Act + Assert
        await expectLater(
          service.fetchLatestRelease(),
          throwsA(
            isA<AppUpdateException>().having(
              (e) => e.message,
              'message',
              allOf(contains('HTTP 403'), isNot(contains('rate limiting'))),
            ),
          ),
        );
      },
    );
  });

  group('AppUpdateService check throttling', () {
    test('a completed check blocks an immediate repeat check', () async {
      // Arrange
      final service = AppUpdateService(
        httpClient: MockClient(
          (_) async => Response('{"tag_name":"v0.6.0+3","assets":[]}', 200),
        ),
      );
      expect(service.isCheckThrottled(), isFalse);

      // Act
      await service.fetchLatestRelease();

      // Assert: a double tap must not spend a second API call.
      expect(service.isCheckThrottled(), isTrue);
    });

    test('a failed check stays immediately retryable', () async {
      // Arrange: first check fails (offline), then the user reconnects.
      final service = AppUpdateService(
        httpClient: MockClient((_) async => Response('boom', 500)),
      );

      // Act
      await expectLater(
        service.fetchLatestRelease(),
        throwsA(isA<AppUpdateException>()),
      );

      // Assert: throttling must not punish a user who was offline.
      expect(service.isCheckThrottled(), isFalse);
    });

    test('a rate-limited check stays immediately retryable', () async {
      // Arrange
      final service = AppUpdateService(
        httpClient: MockClient(
          (_) async =>
              Response('{}', 403, headers: {'x-ratelimit-remaining': '0'}),
        ),
      );

      // Act
      await expectLater(
        service.fetchLatestRelease(),
        throwsA(isA<AppUpdateException>()),
      );

      // Assert
      expect(service.isCheckThrottled(), isFalse);
    });
  });

  group('AppReleaseInfo.fromJson', () {
    Map<String, dynamic> releaseJson() {
      return {
        'tag_name': 'v0.6.0+3',
        'name': 'Tithi 0.6.0',
        'body': 'Bug fixes and improvements.',
        'html_url':
            'https://github.com/1arunjyoti/Tithi-App/releases/tag/v0.6.0',
        'published_at': '2026-09-20T10:00:00Z',
        'assets': [
          {
            'name': 'tithi-0.6.0+3-release.apk',
            'browser_download_url':
                'https://github.com/1arunjyoti/Tithi-App/releases/download/v0.6.0/tithi-0.6.0+3-release.apk',
            'size': 42000000,
            'digest':
                'sha256:ebcfe0fbf162be61d2e8029c83463b11612684bf1fc1d2cca8843ecb653b58ac',
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
      expect(release.apkUrl.toString(), contains('tithi-0.6.0+3-release.apk'));
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
