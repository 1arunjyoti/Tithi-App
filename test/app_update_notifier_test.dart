import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/http.dart' show Response;
import 'package:http/testing.dart';
import 'package:tithi/providers/app_update_provider.dart';
import 'package:tithi/services/app_update_service.dart';

/// Counts how many release requests actually reached the network, so a
/// test can prove that repeated taps did not start parallel work.
class _CountingClient {
  _CountingClient(this.handler);

  final Future<Response> Function(int call) handler;
  int calls = 0;

  MockClient build() {
    return MockClient((request) {
      if (request.url.path.endsWith('/releases/latest')) {
        return handler(++calls);
      }
      return Future.value(Response('{}', 200));
    });
  }
}

/// A client whose download body is driven by the test, so a download can
/// be observed mid-flight and cancelled.
class _ControllableClient extends http.BaseClient {
  final StreamController<List<int>> body = StreamController<List<int>>();
  int sendCalls = 0;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    sendCalls++;
    if (request.url.path.endsWith('/releases/latest')) {
      return http.StreamedResponse(
        Stream.value(
          utf8.encode(
            '{"tag_name":"v9.9.9+99","assets":[{"name":"a-release.apk",'
            '"browser_download_url":"https://x/a.apk","size":100}]}',
          ),
        ),
        200,
      );
    }
    return http.StreamedResponse(body.stream, 200, contentLength: 100);
  }
}

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    // The notifier resolves the installed version through
    // package_info_plus, which needs a platform channel in tests.
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('dev.fluttercommunity.plus/package_info'),
          (MethodCall call) async => <String, dynamic>{
            'appName': 'Tithi',
            'packageName': 'app.tithi.pro',
            'version': '0.5.0',
            'buildNumber': '2',
            'buildSignature': '',
            'installerStore': 'sideload',
          },
        );
  });

  group('AppUpdateNotifier concurrency', () {    test('ignores a second check while one is in flight', () async {
      // Arrange: hold the first response open so both taps overlap.
      final gate = Completer<Response>();
      final client = _CountingClient((call) {
        if (call == 1) return gate.future;
        return Future.value(Response('{"tag_name":"v9.9.9+99","assets":[]}', 200));
      });
      final notifier = AppUpdateNotifier(
        AppUpdateService(httpClient: client.build()),
      );

      // Act: three taps in a row, as a fast user would produce.
      final first = notifier.checkForUpdates(force: true);
      final second = notifier.checkForUpdates(force: true);
      final third = notifier.checkForUpdates(force: true);
      expect(notifier.isBusy, isTrue);

      gate.complete(Response('{"tag_name":"v0.6.0+3","assets":[]}', 200));
      await Future.wait([first, second, third]);

      // Assert: only the first request hit the network.
      expect(client.calls, equals(1));
      expect(notifier.isBusy, isFalse);
    });

    test('a check that fails still releases the in-flight lock', () async {
      // Arrange
      final client = _CountingClient((_) async => Response('boom', 500));
      final notifier = AppUpdateNotifier(
        AppUpdateService(httpClient: client.build()),
      );

      // Act
      await notifier.checkForUpdates(force: true);

      // Assert: an error must not wedge the card permanently.
      expect(notifier.isBusy, isFalse);
      expect(notifier.state.status, equals(AppUpdateStatus.error));
    });

    test('a retry after a failure is allowed immediately', () async {
      // Arrange: first call fails, second succeeds.
      final client = _CountingClient((call) async {
        if (call == 1) return Response('boom', 500);
        return Response('{"tag_name":"v0.6.0+3","assets":[]}', 200);
      });
      final notifier = AppUpdateNotifier(
        AppUpdateService(httpClient: client.build()),
      );

      // Act
      await notifier.checkForUpdates(force: true);
      await notifier.checkForUpdates();

      // Assert
      expect(client.calls, equals(2));
    });
  });

  group('AppUpdateNotifier download cancellation', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('tithi_cancel_test');
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

    test('shows cancelling, then returns to the offer', () async {
      // Arrange
      final client = _ControllableClient();
      final notifier = AppUpdateNotifier(AppUpdateService(httpClient: client));

      // Act: discover the release, then start the download.
      await notifier.checkForUpdates(force: true);
      expect(notifier.state.status, equals(AppUpdateStatus.available));

      final download = notifier.downloadUpdate();
      await Future<void>.delayed(Duration.zero);
      expect(notifier.state.status, equals(AppUpdateStatus.downloading));

      // Act: cancel while bytes are still arriving.
      client.body.add(List<int>.filled(10, 1));
      await Future<void>.delayed(Duration.zero);
      notifier.cancelDownload();
      // The stream only notices on the next chunk.
      expect(notifier.state.status, equals(AppUpdateStatus.cancelling));
      client.body.add(List<int>.filled(10, 2));
      await download;

      // Assert: back to a re-startable offer, lock released, no file.
      expect(notifier.state.status, equals(AppUpdateStatus.available));
      expect(notifier.isBusy, isFalse);
      final leftovers = tempDir
          .listSync()
          .whereType<File>()
          .where((f) => f.path.contains('tithi-update-'));
      expect(leftovers, isEmpty);
      await client.body.close();
    });
  });
}
