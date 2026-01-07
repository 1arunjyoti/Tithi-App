import 'dart:typed_data';

/// Stub implementation for web - file saving not supported
Future<String?> saveImageToTemp(Uint8List imageBytes, String name) async {
  // On web, we cannot save files to the file system
  return null;
}
