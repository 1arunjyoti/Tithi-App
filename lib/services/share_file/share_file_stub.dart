import 'dart:typed_data';

/// Stub implementation for web - file saving not supported
Future<String?> saveImageToTemp(Uint8List imageBytes, String name) async {
  // On web, we cannot save files to the file system
  return null;
}

/// Stub implementation for web - file saving not supported
Future<String?> saveTextToTemp(String content, String filename) async {
  // On web, we cannot save files to the file system
  return null;
}

/// Stub implementation for web - file saving not supported
Future<String?> saveTextToDocuments(String content, String filename) async {
  // On web, we cannot save files to the file system
  return null;
}

/// Stub implementation for web - nothing to purge without temp files.
Future<int> purgeOldShareImages({Duration maxAge = const Duration(days: 1)}) {
  return Future.value(0);
}
