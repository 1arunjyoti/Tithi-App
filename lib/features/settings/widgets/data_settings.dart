import 'dart:convert' show JsonEncoder;

import 'package:material_ui/material_ui.dart';
import 'package:material_3_expressive/material_3_expressive.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../providers/calendar_provider.dart';
import '../../../providers/location_provider.dart';
import '../../../providers/notification_provider.dart';
import '../../../providers/storage_provider.dart';
import '../../../providers/theme_provider.dart';
import '../../../providers/locale_provider.dart';
import '../../../l10n/app_localizations.dart';
import '../../../core/feedback/app_messages.dart';
import '../../../providers/accessibility_provider.dart';
import '../../../services/festival_calendar_export_service.dart';
import 'festival_export_flow.dart';
import 'festival_export_year_sheet.dart';
import '../../../widgets/app_buttons.dart';
import '../../../widgets/app_dialog.dart';
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
        await ref.read(locationServiceProvider).clearCache();
        ref.invalidate(currentLocationProvider);
        if (!context.mounted) return;
        showAppMessage(
          context,
          l10n?.locationCacheCleared ?? 'Location cache cleared',
          kind: AppMessageKind.success,
        );
      },
    );
  }
}

/// Exports every festival with its computed Panchang details for a chosen
/// year as JSON. The user picks the destination in the system save dialog
/// (Downloads, Drive, SD card...).
class ExportFestivalsSetting extends ConsumerWidget {
  const ExportFestivalsSetting({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    return SettingsActionTile(
      icon: Icons.ios_share_rounded,
      title: l10n?.exportFestivalsJson ?? 'Export Festivals (JSON)',
      subtitle:
          l10n?.exportFestivalsSubtitle ??
          'Save all festivals with Panchang details to a file',
      onTap: () => FestivalExportYearSheet.show(
        context: context,
        title: l10n?.exportFestivalsJson ?? 'Export Festivals (JSON)',
        subtitle:
            l10n?.exportJsonYearSheetSubtitle ??
            "Choose a year. You'll then pick where to save the JSON file.",
        onExport: (year) => _runJsonExport(context, ref, year, l10n),
      ),
    );
  }

  Future<void> _runJsonExport(
    BuildContext context,
    WidgetRef ref,
    int year,
    AppLocalizations? l10n,
  ) async {
    await runFestivalExport(
      context: context,
      ref: ref,
      year: year,
      buildPayload: (document) {
        final count = document['festivalCount'] ?? 0;
        return FestivalExportPayload(
          filename: 'tithi-festivals-$year.json',
          content: const JsonEncoder.withIndent('  ').convert(document),
          mimeType: 'application/json',
          shareSubject:
              l10n?.festivalExportShareSubject(year.toString()) ??
              'Tithi festivals $year',
          shareText:
              l10n?.festivalExportShareText(year.toString()) ??
              'Tithi festivals $year with Panchang details (JSON)',
          savedMessage:
              l10n?.festivalsExportedForYear(count, year.toString()) ??
              '$count festivals exported for $year.',
        );
      },
    );
  }
}

/// Exports festival dates as an iCalendar (.ics) file that Google Calendar
/// (and any other calendar app) can import. Each festival is an all-day event
/// on its observance date, with the Panchang timings in the description.
class ExportFestivalsCalendarSetting extends ConsumerWidget {
  const ExportFestivalsCalendarSetting({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    return SettingsActionTile(
      icon: Icons.calendar_month_rounded,
      title: l10n?.exportFestivalsCalendar ?? 'Add to Google Calendar (.ics)',
      subtitle:
          l10n?.exportFestivalsCalendarSubtitle ??
          'Save festival dates as a calendar file you can import',
      onTap: () => FestivalExportYearSheet.show(
        context: context,
        title: l10n?.exportFestivalsCalendar ?? 'Add to Google Calendar (.ics)',
        subtitle: l10n?.exportCalendarYearSheetSubtitle ?? "Choose a year. You'll then pick where to save the .ics file for Google Calendar.",
        onExport: (year) => _runCalendarExport(context, ref, year, l10n),
      ),
    );
  }

  Future<void> _runCalendarExport(
    BuildContext context,
    WidgetRef ref,
    int year,
    AppLocalizations? l10n,
  ) async {
    await runFestivalExport(
      context: context,
      ref: ref,
      year: year,
      buildPayload: (document) {
        // Report events actually written, not the raw festival count: a year
        // may contain festivals whose dates could not be resolved.
        final count = FestivalCalendarExportService.countEvents(document);
        return FestivalExportPayload(
          filename: 'tithi-festivals-$year.ics',
          content: FestivalCalendarExportService().buildIcs(document),
          mimeType: 'text/calendar',
          shareSubject:
              l10n?.festivalCalendarShareSubject(year.toString()) ??
              'Tithi festivals $year (Calendar)',
          shareText:
              l10n?.festivalCalendarShareText(year.toString()) ??
              'Import Tithi festival dates for $year into Google Calendar (.ics)',
          savedMessage:
              l10n?.festivalsExportedToCalendar(count, year.toString()) ??
              '$count festivals exported to calendar for $year.',
        );
      },
    );
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
        final confirm = await AppDialog.show<bool>(
          context,
          title: l10n?.resetSettingsTitle ?? 'Reset Settings?',
          content: Text(
            l10n?.resetSettingsMessage ?? 'This will reset all your preferences and data to default. This cannot be undone.',
          ),
          actions: [
            Builder(
              builder: (c) => AppButton(
                style: M3EButtonStyle.text,
                onPressed: () => Navigator.pop(c, false),
                child: Text(l10n?.cancel ?? 'Cancel'),
              ),
            ),
            Builder(
              builder: (c) => AppButton(
                style: M3EButtonStyle.text,
                onPressed: () => Navigator.pop(c, true),
                child: Text(
                  l10n?.reset ?? 'Reset',
                  style: TextStyle(color: Theme.of(c).colorScheme.error),
                ),
              ),
            ),
          ],
        );

        if (confirm == true) {
          await storageService.resetAll();

          await locationService.setLocationEnabled(false);
          await locationService.clearCache();
          await notificationService.cancelAllNotifications();

          // Reset providers
          // Invalidate the source notifier first: the derived providers below
          // re-read from it, and a cleared Hive box alone does not refresh its
          // in-memory state (this kept e.g. the festival region stale).
          ref.invalidate(calendarPreferencesProvider);
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
          ref.invalidate(placeClockProvider);

          ref.invalidate(loadNotificationStateProvider);
          ref.read(notificationEnabledProvider.notifier).setEnabled(false);
          ref
              .read(shlokaNotificationEnabledProvider.notifier)
              .setEnabled(false);
          ref.read(moonNotificationEnabledProvider.notifier).setEnabled(false);
          ref.read(notificationTimeProvider.notifier).setTime((
            hour: 8,
            minute: 0,
          ));

          if (context.mounted) {
            showAppMessage(
              context,
              l10n?.appResetComplete ?? 'App reset complete',
              kind: AppMessageKind.success,
            );
          }
        }
      },
    );
  }
}
