import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

PackageInfo? _cachedPackageInfo;

/// Pre-warm version info during app startup to avoid UI jank on first drawer open.
Future<void> warmVersionInfo() async {
  _cachedPackageInfo ??= await PackageInfo.fromPlatform();
}

/// Provider that returns the app version information
final packageInfoProvider = FutureProvider<PackageInfo>((ref) async {
  _cachedPackageInfo ??= await PackageInfo.fromPlatform();
  return _cachedPackageInfo!;
});

/// Helper provider that returns just the formatted version string (e.g. "1.0.0 (12)")
final versionStringProvider = FutureProvider<String>((ref) async {
  final info = await ref.watch(packageInfoProvider.future);
  return info.version;
});
