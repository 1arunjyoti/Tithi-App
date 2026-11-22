import 'dart:async' show unawaited;
import 'dart:convert' show utf8;
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/feedback/app_messages.dart';
import '../../../l10n/app_localizations.dart';
import '../../../providers/calendar_provider.dart';
import '../../../providers/festival_provider.dart';
import '../../../providers/panchang_provider.dart';
import '../../../services/festival_export_service.dart';
import '../../../services/share_file/share_file.dart';
import '../../../theme/app_metrics.dart';
import '../../../theme/app_typography.dart';

/// A rendered festival export file plus the strings used to present it.
class FestivalExportPayload {
  const FestivalExportPayload({
    required this.filename,
    required this.content,
    required this.mimeType,
    required this.shareSubject,
    required this.shareText,
    required this.savedMessage,
  });

  final String filename;
  final String content;
  final String mimeType;
  final String shareSubject;
  final String shareText;
  final String savedMessage;
}

/// Builds a format-specific file from the shared export document.
typedef FestivalPayloadBuilder = FestivalExportPayload Function(
  Map<String, dynamic> document,
);

/// Shared flow for the festival export settings tiles: resolve the year's
/// festival data once (with progress UI), render it through [buildPayload],
/// save via the system picker with an app-storage fallback, and offer Share.
///
/// Keeping the ephemeris computation in one place means the JSON and calendar
/// files always describe the same dates for the same year/location/settings.
Future<void> runFestivalExport({
  required BuildContext context,
  required WidgetRef ref,
  required int year,
  required FestivalPayloadBuilder buildPayload,
}) async {
  final l10n = AppLocalizations.of(context);

  try {
    await ref.read(festivalInitProvider.future);
    // Shared init: a Panjika switch replaces the service instance, so
    // initializing it here directly could race the app-wide init.
    await ref.read(panchangInitProvider.future);
    final service = ref.read(panchangServiceProvider);
    final festivals = ref.read(festivalProvider);
    if (festivals.isEmpty) {
      if (!context.mounted) return;
      showAppMessage(
        context,
        l10n?.noFestivalsToExport ?? 'No festivals to export',
        kind: AppMessageKind.error,
      );
      return;
    }
    final coords = ref.read(resolvedCoordinatesProvider);
    final monthSystem = ref.read(hinduMonthSystemProvider);
    final yearEra = ref.read(hinduYearEraProvider);

    final progress = ValueNotifier<int>(0);
    var cancelled = false;
    var dialogOpen = false;
    if (!context.mounted) {
      progress.dispose();
      return;
    }
    unawaited(
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => PopScope(
          canPop: false,
          child: AlertDialog(
            title: Text(
              l10n?.exportingYear(year.toString()) ?? 'Exporting $year',
            ),
            content: ValueListenableBuilder<int>(
              valueListenable: progress,
              builder: (_, done, _) => Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  LinearProgressIndicator(
                    value: festivals.isEmpty ? null : done / festivals.length,
                  ),
                  const SizedBox(height: AppSpacing.s12),
                  Text(
                    l10n?.festivalsExportedProgress(done, festivals.length) ??
                        '$done / ${festivals.length} festivals',
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => cancelled = true,
                child: Text(l10n?.cancel ?? 'Cancel'),
              ),
            ],
          ),
        ),
      )
          .whenComplete(() => dialogOpen = false)
          // A dialog that fails to show (lost context, route overflow) must
          // not surface as an unhandled async error from this fire-and-forget.
          .catchError((Object _) {}),
    );
    dialogOpen = true;

    Map<String, dynamic>? document;
    try {
      document = await FestivalExportService().exportYear(
        festivals: festivals,
        service: service,
        latitude: coords.latitude,
        longitude: coords.longitude,
        monthSystem: monthSystem,
        yearEra: yearEra,
        year: year,
        onProgress: (done, _) => progress.value = done,
        isCancelled: () => cancelled,
      );
    } finally {
      progress.dispose();
      if (dialogOpen && context.mounted) {
        Navigator.of(context).pop();
      }
    }

    if (document == null) {
      if (!context.mounted) return;
      showAppMessage(context, l10n?.exportCancelled ?? 'Export cancelled');
      return;
    }

    final payload = buildPayload(document);
    final content = payload.content;
    final filename = payload.filename;

    // System save picker: the user chooses where the file goes
    // (Downloads, Drive, SD card...); a null result means cancelled. If the
    // picker itself throws (e.g. the plugin is missing from a stale install),
    // fall back to app-private storage so the export still succeeds.
    String? savedPath;
    var pickerFailed = false;
    try {
      // file_picker 13.x returns a Uri (was String?); keep the String path
      // contract below, with the raw URI as display fallback.
      final savedUri = await FilePicker.saveFile(
        dialogTitle:
            l10n?.saveFestivalsYear(year.toString()) ?? 'Save festivals $year',
        fileName: filename,
        bytes: Uint8List.fromList(utf8.encode(content)),
      );
      try {
        savedPath = savedUri?.toFilePath();
      } catch (_) {
        savedPath = savedUri?.toString();
      }
    } catch (e) {
      debugPrint('Save picker unavailable, using app storage: $e');
      pickerFailed = true;
    }
    // A non-null but empty path (some SAF providers return one) is not a
    // saved file; treat it like a cancelled picker.
    if (savedPath != null && savedPath.trim().isEmpty) savedPath = null;

    if (!context.mounted) return;

    if (savedPath == null && !pickerFailed) {
      showAppMessage(context, l10n?.exportCancelled ?? 'Export cancelled');
      return;
    }

    // Picker unavailable: persist in app-private documents instead.
    savedPath ??= await saveTextToDocuments(content, filename);
    if (!context.mounted) return;
    if (savedPath == null) {
      showAppMessage(
        context,
        l10n?.couldNotSaveExportFile ?? 'Could not save export file',
        kind: AppMessageKind.error,
      );
      return;
    }
    final displayPath = savedPath;

    // Temp copy backs the optional Share action below.
    final sharePath = await saveTextToTemp(content, filename);
    if (!context.mounted) return;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n?.saved ?? 'Saved'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(payload.savedMessage),
            const SizedBox(height: AppSpacing.s8),
            Text(
              filename,
              style: const TextStyle(fontWeight: AppTypography.bold),
            ),
            const SizedBox(height: AppSpacing.s4),
            Text(
              displayPath,
              style: Theme.of(dialogContext).textTheme.bodySmall,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(l10n?.done ?? 'Done'),
          ),
          if (sharePath != null)
            TextButton(
              onPressed: () async {
                Navigator.pop(dialogContext);
                try {
                  await SharePlus.instance.share(
                    ShareParams(
                      files: [XFile(sharePath, mimeType: payload.mimeType)],
                      subject: payload.shareSubject,
                      text: payload.shareText,
                    ),
                  );
                } catch (e) {
                  // A cancelled/forcibly-closed share sheet must not become an
                  // unhandled async error; the file is already saved.
                  debugPrint('Festival export share failed: $e');
                }
              },
              child: Text(l10n?.share ?? 'Share'),
            ),
        ],
      ),
    );
  } catch (e) {
    debugPrint('Festival export failed: $e');
    if (context.mounted) {
      showAppMessage(
        context,
        l10n?.exportFailed(e.toString()) ?? 'Export failed: $e',
        kind: AppMessageKind.error,
      );
    }
  }
}
