import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:async' show unawaited;
import 'dart:convert' show utf8;
import 'dart:typed_data';
import '../../../providers/calendar_provider.dart';
import '../../../providers/festival_provider.dart';
import '../../../providers/location_provider.dart';
import '../../../providers/notification_provider.dart';
import '../../../providers/panchang_provider.dart';
import '../../../providers/storage_provider.dart';
import '../../../providers/theme_provider.dart';
import '../../../providers/locale_provider.dart';
import '../../../l10n/app_localizations.dart';
import '../../../providers/accessibility_provider.dart';
import '../../../services/festival_export_service.dart';
import '../../../services/share_file/share_file.dart';
import '../../../widgets/settings_widgets.dart';

class ClearCacheSetting extends ConsumerWidget {
  const ClearCacheSetting({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    return SettingsActionTile(
      icon: Icons.cleaning_services_rounded,
      title: l10n?.clearLocationCache ?? 'Clear Location Cache',
      onTap: () async {
        final scaffold = ScaffoldMessenger.of(context);
        await ref.read(locationServiceProvider).clearCache();
        ref.invalidate(currentLocationProvider);
        scaffold.showSnackBar(
          SnackBar(
            content: Text(
              l10n?.locationCacheCleared ?? 'Location cache cleared',
            ),
          ),
        );
      },
    );
  }
}

/// Exports every festival with its computed Panchang details for a chosen
/// year as JSON. The user picks the destination in the system save dialog
/// (Downloads, Drive, SD card...); on web it triggers a browser download.
class ExportFestivalsSetting extends ConsumerWidget {
  const ExportFestivalsSetting({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    return SettingsActionTile(
      icon: Icons.ios_share_rounded,
      title: l10n?.exportFestivalsJson ?? 'Export Festivals (JSON)',
      subtitle: l10n?.exportFestivalsSubtitle ?? 'Save all festivals with Panchang details to a file',
      onTap: () => _showYearPicker(context, ref),
    );
  }

  Future<void> _showYearPicker(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    final thisYear = DateTime.now().year;
    final years = [thisYear - 1, thisYear, thisYear + 1, thisYear + 2];

    await SettingsBottomSheet.show(
      context: context,
      title: l10n?.exportFestivals ?? 'Export Festivals',
      subtitle: l10n?.exportFestivalsSubtitleYear ?? 'First occurrence of each festival in the chosen year',
      children: years.map((year) {
        return SettingsPickerItem(
          title: year.toString(),
          isSelected: year == thisYear,
          onTap: () {
            Navigator.pop(context);
            _runExport(context, ref, year);
          },
        );
      }).toList(),
    );
  }

  Future<void> _runExport(
    BuildContext context,
    WidgetRef ref,
    int year,
  ) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);

    try {
      await ref.read(festivalInitProvider.future);
      final service = ref.read(panchangServiceProvider);
      if (!service.isInitialized) {
        await service.init();
      }
      final festivals = ref.read(festivalProvider);
      if (festivals.isEmpty) {
        messenger.showSnackBar(
          SnackBar(content: Text(l10n?.noFestivalsToExport ?? 'No festivals to export')),
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
              title: Text(l10n?.exportingYear(year.toString()) ?? 'Exporting $year'),
              content: ValueListenableBuilder<int>(
                valueListenable: progress,
                builder: (_, done, _) => Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    LinearProgressIndicator(
                      value: festivals.isEmpty
                          ? null
                          : done / festivals.length,
                    ),
                    const SizedBox(height: 12),
                    Text(l10n?.festivalsExportedProgress(done, festivals.length) ?? '$done / ${festivals.length} festivals'),
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
        ).whenComplete(() => dialogOpen = false),
      );
      dialogOpen = true;

      String? json;
      try {
        json = await FestivalExportService().exportYearJson(
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

      if (json == null) {
        messenger.showSnackBar(
          SnackBar(content: Text(l10n?.exportCancelled ?? 'Export cancelled')),
        );
        return;
      }

      // System save picker: the user chooses where the file goes
      // (Downloads, Drive, SD card...). On web this starts a download and
      // always resolves to null. If the picker itself throws (e.g. the
      // plugin is missing from a stale install), fall back to app-private
      // storage so the export still succeeds.
      final filename = 'tithi-festivals-$year.json';
      String? savedPath;
      var pickerFailed = false;
      try {
        // file_picker 13.x returns a Uri (was String?); keep the String
        // path contract below, with the raw URI as display fallback.
        final savedUri = await FilePicker.saveFile(
          dialogTitle: l10n?.saveFestivalsYear(year.toString()) ?? 'Save festivals $year',
          fileName: filename,
          type: FileType.custom,
          allowedExtensions: ['json'],
          bytes: Uint8List.fromList(utf8.encode(json)),
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

      if (!context.mounted) return;

      if (savedPath == null && kIsWeb && !pickerFailed) {
        messenger.showSnackBar(
          SnackBar(content: Text(l10n?.downloadStarted ?? 'Download started')),
        );
        return;
      }

      if (savedPath == null && !pickerFailed) {
        messenger.showSnackBar(
          SnackBar(content: Text(l10n?.exportCancelled ?? 'Export cancelled')),
        );
        return;
      }

      // Picker unavailable: persist in app-private documents instead.
      savedPath ??= await saveTextToDocuments(json, filename);
      if (savedPath == null || !context.mounted) {
        messenger.showSnackBar(
          SnackBar(content: Text(l10n?.couldNotSaveExportFile ?? 'Could not save export file')),
        );
        return;
      }
      final displayPath = savedPath;

      // Temp copy backs the optional Share action below.
      final sharePath = await saveTextToTemp(json, filename);
      if (!context.mounted) return;

      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(l10n?.saved ?? 'Saved'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l10n?.festivalsExportedForYear(festivals.length, year.toString()) ?? '${festivals.length} festivals exported for $year.'),
              const SizedBox(height: 8),
              Text(
                filename,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                displayPath,
                style: Theme.of(
                  dialogContext,
                ).textTheme.bodySmall,
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
                  await SharePlus.instance.share(
                    ShareParams(
                      files: [XFile(sharePath, mimeType: 'application/json')],
                      subject: l10n?.festivalExportShareSubject(year.toString()) ??
                          'Tithi festivals $year',
                      text: l10n?.festivalExportShareText(year.toString()) ??
                          'Tithi festivals $year with Panchang details (JSON)',
                    ),
                  );
                },
                child: Text(l10n?.share ?? 'Share'),
              ),
          ],
        ),
      );
    } catch (e) {
      debugPrint('Festival export failed: $e');
      messenger.showSnackBar(
        SnackBar(content: Text(l10n?.exportFailed(e.toString()) ?? 'Export failed: $e')),
      );
    }
  }
}

class ResetSettingsTile extends ConsumerWidget {
  const ResetSettingsTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final notificationService = ref.read(notificationServiceProvider);
    final locationService = ref.read(locationServiceProvider);
    final storageService = ref.read(storageServiceProvider);
    return SettingsActionTile(
      icon: Icons.restore_rounded,
      title: l10n?.resetAppSettings ?? 'Reset App Settings',
      onTap: () async {
        final confirm = await showDialog<bool>(
          context: context,
          builder: (c) => AlertDialog(
            title: Text(l10n?.resetSettingsTitle ?? 'Reset Settings?'),
            content: Text(
              l10n?.resetSettingsMessage ??
                  'This will reset all your preferences and data to default. This cannot be undone.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(c, false),
                child: Text(l10n?.cancel ?? 'Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(c, true),
                child: Text(
                  l10n?.reset ?? 'Reset',
                  style: TextStyle(
                    color: Theme.of(c).colorScheme.error,
                  ),
                ),
              ),
            ],
          ),
        );

        if (confirm == true) {
          await storageService.resetAll();

          await locationService.setLocationEnabled(false);
          await locationService.clearCache();
          await notificationService.cancelAllNotifications();

          // Reset providers
          ref.invalidate(startOfWeekProvider);
          ref.invalidate(primaryEventViewProvider);
          ref.invalidate(themeOverrideProvider);
          ref.invalidate(primaryCalendarSystemProvider);
          ref.invalidate(secondaryCalendarSystemProvider);
          ref.invalidate(hinduMonthSystemProvider);
          ref.invalidate(hinduYearEraProvider);
          ref.invalidate(localeProvider);
          ref.invalidate(accessibilityProvider);
          ref.invalidate(currentLocationProvider);
          ref.invalidate(locationEnabledProvider);
          ref.invalidate(homeLocationProvider);

          ref.invalidate(loadNotificationStateProvider);
          ref.read(notificationEnabledProvider.notifier).setEnabled(false);
          ref
              .read(shlokaNotificationEnabledProvider.notifier)
              .setEnabled(false);
          ref.read(notificationTimeProvider.notifier).setTime((
            hour: 8,
            minute: 0,
          ));

          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  l10n?.appResetComplete ?? 'App reset complete',
                  textScaler: MediaQuery.of(context).textScaler,
                ),
              ),
            );
          }
        }
      },
    );
  }
}

