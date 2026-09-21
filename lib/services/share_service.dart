import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:screenshot/screenshot.dart';
import 'package:share_plus/share_plus.dart';

import '../l10n/app_localizations.dart';
import '../models/festival.dart';
import '../widgets/festival_share_card.dart';

// Conditional import for file operations
import 'share_file/share_file.dart';

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
  /// On web, falls back to text-only sharing.
  Future<void> shareFestival(BuildContext context, Festival festival) async {
    try {
      // On web, use text-only sharing
      if (kIsWeb) {
        final l10n = AppLocalizations.of(context);
        await SharePlus.instance.share(
          ShareParams(
            subject: festival.name,
            text:
                '${l10n?.celebratingFestivalWithTithi(festival.name) ?? 'Celebrating ${festival.name} with Tithi App!'}\n\n'
                'Check out this festival on Tithi - your Hindu Panchang Calendar.',
          ),
        );
        return;
      }

      // 1. Create the widget to capture
      final widgetToCapture = Material(
        type: MaterialType.transparency,
        child: FestivalShareCard(festival: festival),
      );

      // Resolve locale-dependent strings before any await: the sheet may
      // close while capturing/sharing, unmounting [context].
      final l10n = AppLocalizations.of(context);
      final shareText =
          l10n?.celebratingFestivalWithTithi(festival.name) ??
          'Celebrating ${festival.name} with Tithi App!';

      // 2. Capture the widget
      final Uint8List imageBytes = await _screenshotController
          .captureFromWidget(
            widgetToCapture,
            delay: const Duration(milliseconds: 100),
            context: context,
            pixelRatio: 2.0,
          );

      // 3. Save to temporary file and share (mobile only)
      final imagePath = await saveImageToTemp(imageBytes, festival.name);
      if (imagePath == null) {
        throw Exception('Failed to save image');
      }

      // 4. Share the file
      final xFile = XFile(imagePath);
      await SharePlus.instance.share(
        ShareParams(subject: festival.name, text: shareText, files: [xFile]),
      );
    } catch (e) {
      debugPrint("Error sharing festival: $e");
      if (context.mounted) {
        final errorL10n = AppLocalizations.of(context);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(errorL10n?.failedToShare(e.toString()) ?? 'Failed to share: $e')));
      }
    }
  }
}
