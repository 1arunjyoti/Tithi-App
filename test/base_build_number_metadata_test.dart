// Regression guard for the un-offset +N used by the in-app updater.
//
// Flutter's --split-per-abi offsets each APK's versionCode, so once +N passes
// 1000 the installed versionCode can no longer be decoded back to the number
// in a release tag. The base value must stay in the manifest and be exposed
// over the update channel (see changelogs.md, 2026-11-23).

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Base build number wiring', () {
    test('Gradle fills the placeholder from flutter.versionCode', () {
      final gradle = File('android/app/build.gradle.kts').readAsStringSync();
      expect(gradle, contains('manifestPlaceholders["baseBuildNumber"]'));
      expect(gradle, contains('flutter.versionCode.toString()'));
    });

    test('the manifest declares baseBuildNumber meta-data', () {
      final manifest = File(
        'android/app/src/main/AndroidManifest.xml',
      ).readAsStringSync();
      expect(manifest, contains('android:name="baseBuildNumber"'));
      expect(manifest, contains(r'android:value="${baseBuildNumber}"'));
    });

    test('MainActivity serves it on the update channel', () {
      final activity = File(
        'android/app/src/main/kotlin/app/tithi/pro/MainActivity.kt',
      ).readAsStringSync();
      expect(activity, contains('"baseBuildNumber" ->'));
      expect(activity, contains('PackageManager.GET_META_DATA'));
    });
  });
}
