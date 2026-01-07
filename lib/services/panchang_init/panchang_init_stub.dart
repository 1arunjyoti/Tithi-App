import 'package:flutter/services.dart' show AssetBundle;

/// Stub implementation for web - ephemeris file operations not supported
Future<String?> copyEphemerisFiles(AssetBundle bundle) async {
  // On web, we cannot copy files to the file system
  // Return null to indicate no ephemeris path available
  return null;
}
