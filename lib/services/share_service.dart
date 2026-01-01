import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:screenshot/screenshot.dart';
import 'package:share_plus/share_plus.dart';
import '../models/festival.dart';
import '../widgets/festival_share_card.dart';

class ShareService {
  // Singleton instance
  static final ShareService _instance = ShareService._internal();
  factory ShareService() => _instance;
  ShareService._internal();

  final ScreenshotController _screenshotController = ScreenshotController();

  /// Captures a [FestivalShareCard] as an image and shares it.
  ///
  /// This method builds the widget in the background (off-screen), captures it,
  /// saves it to a temporary file, and triggers the native share sheet.
  Future<void> shareFestival(BuildContext context, Festival festival) async {
    try {
      // 1. Create the widget to capture
      final widgetToCapture = Material(
        type: MaterialType.transparency,
        child: FestivalShareCard(festival: festival),
      );

      // 2. Capture the widget
      // We pass the context to ensure themes/media queries work if needed,
      // though our specific widget is self-contained.
      final Uint8List? imageBytes = await _screenshotController
          .captureFromWidget(
            widgetToCapture,
            delay: const Duration(
              milliseconds: 100,
            ), // Slight delay to ensure rendering
            context: context,
            pixelRatio: 2.0, // High resolution for better quality
          );

      if (imageBytes == null) {
        throw Exception("Failed to capture image");
      }

      // 3. Save to temporary directory
      final directory = await getTemporaryDirectory();
      final imagePath =
          '${directory.path}/festival_share_${DateTime.now().millisecondsSinceEpoch}.png';
      final imageFile = File(imagePath);
      await imageFile.writeAsBytes(imageBytes);

      // 4. Share the file
      final xFile = XFile(imagePath);

      // Determine device type (iPad needs a sharePositionOrigin)
      // For now, we just share plainly. share_plus handles platform logic well.
      await Share.shareXFiles(
        [xFile],
        text: 'Celebrating ${festival.name} with Tithi App!',
        subject: festival.name,
      );
    } catch (e) {
      debugPrint("Error sharing festival: $e");
      // Optionally show a snackbar or alert to the user
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to share: $e')));
      }
    }
  }
}
