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
