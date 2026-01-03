import 'dart:io';
import 'package:flutter/services.dart' show AssetBundle;
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

/// Mobile implementation - copies ephemeris files to the app's documents directory
Future<String?> copyEphemerisFiles(AssetBundle bundle) async {
  final appDir = await getApplicationDocumentsDirectory();
  final epheDir = Directory(p.join(appDir.path, 'ephe'));

  if (!await epheDir.exists()) {
    await epheDir.create(recursive: true);
  }

  // List of ephemeris files to copy
  final files = ['seas_18.se1', 'semo_18.se1', 'sepl_18.se1'];

  for (final file in files) {
    final targetFile = File(p.join(epheDir.path, file));
    // Check if file exists to avoid copying every time
    if (!await targetFile.exists()) {
      final data = await bundle.load('assets/ephe/$file');
      final bytes = data.buffer.asUint8List(
        data.offsetInBytes,
        data.lengthInBytes,
      );
      await targetFile.writeAsBytes(bytes);
    }
  }

  return epheDir.path;
}
