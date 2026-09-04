import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';

/// Mobile implementation - saves image to temporary directory
Future<String?> saveImageToTemp(Uint8List imageBytes, String name) async {
  try {
    final directory = await getTemporaryDirectory();
    final imagePath =
        '${directory.path}/festival_share_${DateTime.now().millisecondsSinceEpoch}.png';
    final imageFile = File(imagePath);
    await imageFile.writeAsBytes(imageBytes);
    return imagePath;
  } catch (e) {
    return null;
  }
}

/// Mobile implementation - saves text content to a temporary file.
/// Returns the file path, or null on failure.
Future<String?> saveTextToTemp(String content, String filename) async {
  try {
    final directory = await getTemporaryDirectory();
    final safeName = filename.replaceAll(RegExp(r'[^\w\-.]+'), '_');
    final filePath = '${directory.path}/$safeName';
    final file = File(filePath);
    await file.writeAsString(content);
    return filePath;
  } catch (e) {
    return null;
  }
}

/// Mobile implementation - saves text content to the app's documents
/// directory, where it persists (unlike the cache/temp directory, which the
/// OS may purge). No storage permission needed. Returns the file path,
/// or null on failure.
Future<String?> saveTextToDocuments(String content, String filename) async {
  try {
    final directory = await getApplicationDocumentsDirectory();
    final safeName = filename.replaceAll(RegExp(r'[^\w\-.]+'), '_');
    final filePath = '${directory.path}/$safeName';
    final file = File(filePath);
    await file.writeAsString(content);
    return filePath;
  } catch (e) {
    return null;
  }
}
