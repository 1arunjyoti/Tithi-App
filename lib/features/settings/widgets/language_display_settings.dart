import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../providers/calendar_provider.dart';
import '../../../providers/locale_provider.dart';
import '../../../l10n/app_localizations.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/settings_widgets.dart';

class LanguageSetting extends ConsumerWidget {
  const LanguageSetting({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentLocale = ref.watch(localeProvider);
    final l10n = AppLocalizations.of(context);
    final currentName = currentLocale == null
        ? l10n?.systemDefault ?? 'System Default'
        : findSupportedLocale(currentLocale)?.nativeName ??
              currentLocale.languageCode;

    return SettingsActionTile(
      icon: Icons.language_rounded,
      title: l10n?.language ?? 'Language',
      trailing: Text(
        currentName,
        style: context.textTheme.bodyMedium?.copyWith(
          color: context.colors.primary,
          fontWeight: FontWeight.bold,
        ),
      ),
      onTap: () => _showLanguagePicker(context, ref),
    );
  }

  Future<void> _showLanguagePicker(BuildContext context, WidgetRef ref) async {
    final currentLocale = ref.read(localeProvider);
    final l10n = AppLocalizations.of(context);

    await SettingsBottomSheet.show(
      context: context,
      title: l10n?.selectLanguage ?? 'Select Language',
      children: [
        // System Default option
        SettingsPickerItem(
          title: l10n?.systemDefault ?? 'System Default',
          isSelected: currentLocale == null,
          onTap: () async {
            await ref.read(localeProvider.notifier).clearLocale();
            if (context.mounted) Navigator.pop(context);
          },
        ),
        // Supported locales
        ...supportedLocales.map((supported) {
          return SettingsPickerItem(
            title: supported.nativeName,
            subtitle: supported.name,
            isSelected:
                supported.locale.languageCode == currentLocale?.languageCode,
            onTap: () async {
              await ref
                  .read(localeProvider.notifier)
                  .setLocale(supported.locale);
              if (context.mounted) Navigator.pop(context);
            },
          );
        }),
      ],
    );
  }
}

class StartOfWeekSetting extends ConsumerWidget {
  const StartOfWeekSetting({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final startOfWeek = ref.watch(startOfWeekProvider);
    final l10n = AppLocalizations.of(context);
    return SettingsActionTile(
      icon: Icons.calendar_today_rounded,
      title: l10n?.startOfWeek ?? 'Start of Week',
      trailing: Text(
        startOfWeek == StartingDayOfWeek.sunday
            ? (l10n?.sunday ?? 'Sunday')
            : (l10n?.monday ?? 'Monday'),
        style: context.textTheme.bodyMedium?.copyWith(
          color: context.colors.primary,
          fontWeight: FontWeight.bold,
        ),
      ),
      onTap: () async {
        final newValue = startOfWeek == StartingDayOfWeek.sunday
            ? StartingDayOfWeek.monday
            : StartingDayOfWeek.sunday;
        await ref
            .read(calendarPreferencesProvider.notifier)
            .setStartOfWeek(newValue);
      },
    );
  }
}

class PrimaryViewSetting extends ConsumerWidget {
  const PrimaryViewSetting({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final primaryView = ref.watch(primaryEventViewProvider);
    final l10n = AppLocalizations.of(context);
    return SettingsActionTile(
      icon: Icons.view_agenda_rounded,
      title: l10n?.primaryView ?? 'Primary View',
      trailing: Text(
        primaryView == PrimaryEventView.tithi
            ? (l10n?.tithi ?? 'Tithi')
            : primaryView == PrimaryEventView.festival
            ? (l10n?.festival ?? 'Festival')
            : (l10n?.moon ?? 'Moon'),
        style: context.textTheme.bodyMedium?.copyWith(
          color: context.colors.primary,
          fontWeight: FontWeight.bold,
        ),
      ),
      onTap: () {
        final nextIndex =
            (primaryView.index + 1) % PrimaryEventView.values.length;
        ref
            .read(calendarPreferencesProvider.notifier)
            .setPrimaryView(PrimaryEventView.values[nextIndex]);
      },
    );
  }
}

