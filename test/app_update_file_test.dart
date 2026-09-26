import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' show Response;
import 'package:http/testing.dart';
import 'package:tithi/services/app_update/app_update_file.dart';
import 'package:tithi/services/app_update_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('updateApkFileName', () {
    test('builds a file-safe name from the release version', () {
      expect(updateApkFileName('0.6.0+3'), equals('tithi-update-0.6.0_3.apk'));
      expect(updateApkFileName('0.6.0'), equals('tithi-update-0.6.0.apk'));
    });
  });

  group('findCachedApkPath', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('tithi_update_test');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('plugins.flutter.io/path_provider'),
            (MethodCall call) async {
              if (call.method == 'getTemporaryDirectory') return tempDir.path;
              return null;
            },
          );
    });

    tearDown(() async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('plugins.flutter.io/path_provider'),
            null,
          );
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('returns the path of an already-downloaded APK', () async {
      // Arrange
      final file = File(
        '${tempDir.path}/${updateApkFileName('0.6.0+6')}',
      );
      await file.writeAsString('apk-bytes');

      // Act
      final found = await findCachedApkPath('0.6.0+6');

      // Assert
      expect(found, equals(file.path));
    });

    test('returns null when the version was never downloaded', () async {
      expect(await findCachedApkPath('0.6.0+6'), isNull);
    });
  });

  group('saveApkStream', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('tithi_update_test');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('plugins.flutter.io/path_provider'),
            (MethodCall call) async {
              if (call.method == 'getTemporaryDirectory') return tempDir.path;
              return null;
            },
          );
    });

    tearDown(() async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('plugins.flutter.io/path_provider'),
            null,
          );
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('writes stream bytes to the cache file', () async {
      // Arrange
      final stream = Stream<List<int>>.fromIterable([
        [1, 2, 3],
        [4, 5],
      ]);

      // Act
      final path = await saveApkStream(
        stream,
        updateApkFileName('0.6.0+6'),
      );

      // Assert
      expect(await File(path).readAsBytes(), equals([1, 2, 3, 4, 5]));
    });

    test('deletes the partial file when the stream fails', () async {
      // Arrange: yields some bytes, then the connection drops.
      Stream<List<int>> failing() async* {
        yield [1, 2, 3];
        throw const SocketException('connection cut');
      }

      final fileName = updateApkFileName('0.6.0+6');

      // Act + Assert: the error surfaces and no partial APK remains.
      await expectLater(
        saveApkStream(failing(), fileName),
        throwsA(isA<SocketException>()),
      );
      expect(await findCachedApkPath('0.6.0+6'), isNull);
    });
  });

  group('AppUpdateService.isApkIntact', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('tithi_update_test');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('plugins.flutter.io/path_provider'),
            (MethodCall call) async {
              if (call.method == 'getTemporaryDirectory') return tempDir.path;
              return null;
            },
          );
    });

    tearDown(() async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('plugins.flutter.io/path_provider'),
            null,
          );
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('rejects a file whose size does not match the release', () async {
      // Arrange: a download killed with the process leaves a stub file.
      final file = File('${tempDir.path}/tithi-update-0.6.0_6.apk');
      await file.writeAsString('truncated');

      // Act
      final intact = await AppUpdateService.isApkIntact(
        file.path,
        expectedSize: 77565243,
      );

      // Assert
      expect(intact, isFalse);
    });

    test('rejects an empty leftover file', () async {
      // Arrange
      final file = File('${tempDir.path}/empty.apk');
      await file.writeAsBytes(const []);

      // Act + Assert
      expect(await AppUpdateService.isApkIntact(file.path), isFalse);
    });

    test('accepts a complete file when the size matches', () async {
      // Arrange
      final file = File('${tempDir.path}/ok.apk');
      final bytes = List<int>.filled(64, 7);
      await file.writeAsBytes(bytes);

      // Act
      final intact = await AppUpdateService.isApkIntact(
        file.path,
        expectedSize: bytes.length,
      );

      // Assert
      expect(intact, isTrue);
    });

    test('rejects a size match whose digest differs', () async {
      // Arrange: right length, wrong contents.
      final file = File('${tempDir.path}/tampered.apk');
      await file.writeAsString('x' * 64);

      // Act
      final intact = await AppUpdateService.isApkIntact(
        file.path,
        expectedSize: 64,
        expectedDigest:
            'sha256:0000000000000000000000000000000000000000000000000000000000000000',
      );

      // Assert
      expect(intact, isFalse);
    });

    test('accepts a file matching the published digest', () async {
      // Arrange: sha256 of 64 'x' characters.
      final file = File('${tempDir.path}/verified.apk');
      await file.writeAsString('x' * 64);

      // Act
      final intact = await AppUpdateService.isApkIntact(
        file.path,
        expectedSize: 64,
        expectedDigest:
            'sha256:7ce100971f64e7001e8fe5a51973ecdfe1ced42befe7ee8d5fd6219506b5393c',
      );

      // Assert
      expect(intact, isTrue);
    });

    test('ignores a malformed digest instead of failing the download', () async {
      // Arrange
      final file = File('${tempDir.path}/ok2.apk');
      await file.writeAsString('abc');

      // Act
      final intact = await AppUpdateService.isApkIntact(
        file.path,
        expectedSize: 3,
        expectedDigest: 'not-a-digest',
      );

      // Assert
      expect(intact, isTrue);
    });

    test('findDownloadedApk deletes a truncated leftover', () async {
      // Arrange: cached file exists but is far smaller than the release.
      final file = File('${tempDir.path}/tithi-update-0.6.0_6.apk');
      await file.writeAsString('partial');
      final release = AppReleaseInfo(
        tagName: 'v0.6.0+6',
        version: '0.6.0+6',
        name: 'Tithi 0.6.0',
        body: '',
        htmlUrl: Uri.https('github.com', '/'),
        publishedAt: null,
        apkUrl: Uri.https('github.com', '/app.apk'),
        apkSizeBytes: 77565243,
        apkDigest: null,
      );
      final service = AppUpdateService(
        httpClient: MockClient((_) async => Response('{}', 200)),
      );

      // Act
      final found = await service.findDownloadedApk(release);

      // Assert: no install is offered, and the bad file is cleaned up.
      expect(found, isNull);
      expect(await file.exists(), isFalse);
    });

    test('findDownloadedApk returns an intact cached file', () async {
      // Arrange
      final file = File('${tempDir.path}/tithi-update-0.6.0_6.apk');
      await file.writeAsString('complete-apk-bytes');
      final release = AppReleaseInfo(
        tagName: 'v0.6.0+6',
        version: '0.6.0+6',
        name: 'Tithi 0.6.0',
        body: '',
        htmlUrl: Uri.https('github.com', '/'),
        publishedAt: null,
        apkUrl: Uri.https('github.com', '/app.apk'),
        apkSizeBytes: 18,
        apkDigest: null,
      );
      final service = AppUpdateService(
        httpClient: MockClient((_) async => Response('{}', 200)),
      );

      // Act
      final found = await service.findDownloadedApk(release);

      // Assert
      expect(found, equals(file.path));
    });
  });

  group('purgeOldUpdateApks', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('tithi_update_test');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('plugins.flutter.io/path_provider'),
            (MethodCall call) async {
              if (call.method == 'getTemporaryDirectory') return tempDir.path;
              return null;
            },
          );
    });

    tearDown(() async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('plugins.flutter.io/path_provider'),
            null,
          );
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('keeps only the newest APK and ignores other files', () async {
      // Arrange
      final oldApk = File('${tempDir.path}/tithi-update-0.5.0+5.apk');
      final newApk = File('${tempDir.path}/tithi-update-0.6.0+6.apk');
      final unrelated = File('${tempDir.path}/notes.txt');
      await oldApk.writeAsString('old');
      await newApk.writeAsString('new');
      await unrelated.writeAsString('keep me');

      // Act
      final removed = await purgeOldUpdateApks(keepPath: newApk.path);

      // Assert
      expect(removed, equals(1));
      expect(await oldApk.exists(), isFalse);
      expect(await newApk.exists(), isTrue);
      expect(await unrelated.exists(), isTrue);
    });

    test('returns zero when there is nothing to purge', () async {
      // Act + Assert
      expect(await purgeOldUpdateApks(), equals(0));
    });
  });
}
