import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../providers/calendar_provider.dart';
import '../../../l10n/app_localizations.dart';
import '../../../theme/app_theme.dart';
import '../../../models/hindu_month_system.dart';
import '../../../widgets/settings_widgets.dart';

class PrimaryCalendarSetting extends ConsumerWidget {
  const PrimaryCalendarSetting({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final primarySystem = ref.watch(primaryCalendarSystemProvider);
    final l10n = AppLocalizations.of(context);
    return SettingsActionTile(
      icon: Icons.event_note_rounded,
      title: l10n?.primaryCalendar ?? 'Primary Calendar',
      trailing: Text(
        primarySystem.label,
        style: context.textTheme.bodyMedium?.copyWith(
          color: context.colors.primary,
          fontWeight: FontWeight.bold,
        ),
      ),
      onTap: () => showCalendarSystemPicker(context, ref, isPrimary: true),
    );
  }
}

class SecondaryCalendarSetting extends ConsumerWidget {
  const SecondaryCalendarSetting({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final secondarySystem = ref.watch(secondaryCalendarSystemProvider);
    final l10n = AppLocalizations.of(context);
    return SettingsActionTile(
      icon: Icons.event_available_rounded,
      title: l10n?.secondaryCalendar ?? 'Secondary Calendar',
      trailing: Text(
        secondarySystem.label,
        style: context.textTheme.bodyMedium?.copyWith(
          color: context.colors.primary,
          fontWeight: FontWeight.bold,
        ),
      ),
      onTap: () => showCalendarSystemPicker(context, ref, isPrimary: false),
    );
  }
}

class HinduMonthSystemSetting extends ConsumerWidget {
  const HinduMonthSystemSetting({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final monthSystem = ref.watch(hinduMonthSystemProvider);
    final l10n = AppLocalizations.of(context);
    return SettingsActionTile(
      icon: Icons.date_range_rounded,
      title: l10n?.hinduMonthSystem ?? 'Hindu Month System',
      trailing: Text(
        monthSystem.label,
        style: context.textTheme.bodyMedium?.copyWith(
          color: context.colors.primary,
          fontWeight: FontWeight.bold,
        ),
      ),
      onTap: () => _showHinduMonthSystemPicker(context, ref),
    );
  }

  Future<void> _showHinduMonthSystemPicker(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final l10n = AppLocalizations.of(context);
    final currentSystem = ref.read(hinduMonthSystemProvider);

    await SettingsBottomSheet.show(
      context: context,
      title: l10n?.hinduMonthSystem ?? 'Hindu Month System',
      subtitle: l10n?.hinduMonthSystemSubtitle ??
          'Choose how months are named during Krishna Paksha',
      children: HinduMonthSystem.values.map((system) {
        return SettingsPickerItem(
          title: system.label,
          subtitle: system.description,
          isSelected: system == currentSystem,
          onTap: () async {
            await ref
                .read(calendarPreferencesProvider.notifier)
                .setHinduMonthSystem(system);
            if (context.mounted) Navigator.pop(context);
          },
        );
      }).toList(),
    );
  }
}

class HinduYearEraSetting extends ConsumerWidget {
  const HinduYearEraSetting({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final yearEra = ref.watch(hinduYearEraProvider);
    final l10n = AppLocalizations.of(context);
    return SettingsActionTile(
      icon: Icons.calendar_month_rounded,
      title: l10n?.hinduYearEra ?? 'Hindu Year Era',
      trailing: Text(
        yearEra.shortLabel,
        style: context.textTheme.bodyMedium?.copyWith(
          color: context.colors.primary,
          fontWeight: FontWeight.bold,
        ),
      ),
      onTap: () => _showHinduYearEraPicker(context, ref),
    );
  }

  Future<void> _showHinduYearEraPicker(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final l10n = AppLocalizations.of(context);
    final currentEra = ref.read(hinduYearEraProvider);

    await SettingsBottomSheet.show(
      context: context,
      title: l10n?.hinduYearEra ?? 'Hindu Year Era',
      subtitle: l10n?.hinduYearEraSubtitle ??
          'Choose the calendar era for year display',
      children: HinduYearEra.values.map((era) {
        return SettingsPickerItem(
          title: era.label,
          subtitle: era.description,
          isSelected: era == currentEra,
          onTap: () async {
            await ref
                .read(calendarPreferencesProvider.notifier)
                .setHinduYearEra(era);
            if (context.mounted) Navigator.pop(context);
          },
        );
      }).toList(),
    );
  }
}

class TithiDisplayModeSetting extends ConsumerWidget {
  const TithiDisplayModeSetting({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final displayMode = ref.watch(tithiDisplayModeProvider);
    final l10n = AppLocalizations.of(context);
    return SettingsActionTile(
      icon: Icons.calendar_view_day_rounded,
      title: l10n?.tithiDisplay ?? 'Tithi Display',
      trailing: Text(
        displayMode == TithiDisplayMode.pakshaBased
            ? (l10n?.tithiDisplayPakshaRange ?? 'Paksha (1-15)')
            : (l10n?.tithiDisplayThirtyDays ?? '30 Days'),
        style: context.textTheme.bodyMedium?.copyWith(
          color: context.colors.primary,
          fontWeight: FontWeight.bold,
        ),
      ),
      onTap: () => _showTithiDisplayModePicker(context, ref),
    );
  }

  Future<void> _showTithiDisplayModePicker(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final l10n = AppLocalizations.of(context);
    final currentMode = ref.read(tithiDisplayModeProvider);

    await SettingsBottomSheet.show(
      context: context,
      title: l10n?.tithiDisplay ?? 'Tithi Display',
      subtitle: l10n?.tithiDisplaySubtitle ??
          'Choose how tithis are numbered in the calendar',
      children: TithiDisplayMode.values.map((mode) {
        return SettingsPickerItem(
          title: mode == TithiDisplayMode.pakshaBased
              ? (l10n?.tithiDisplayPakshaBased ?? 'Paksha Based')
              : (l10n?.tithiDisplayThirtyDays ?? '30 Days'),
          subtitle: mode == TithiDisplayMode.pakshaBased
              ? (l10n?.tithiDisplayPakshaDescription ??
                  'Show 1-15 for each paksha separately')
              : (l10n?.tithiDisplayContinuousDescription ??
                  'Show 1-30 continuously'),
          isSelected: mode == currentMode,
          onTap: () async {
            await ref
                .read(calendarPreferencesProvider.notifier)
                .setTithiDisplayMode(mode);
            if (context.mounted) Navigator.pop(context);
          },
        );
      }).toList(),
    );
  }
}


Future<void> showCalendarSystemPicker(
  BuildContext context,
  WidgetRef ref, {
  required bool isPrimary,
}) async {
  final l10n = AppLocalizations.of(context);
  final currentSystem = isPrimary
      ? ref.read(primaryCalendarSystemProvider)
      : ref.read(secondaryCalendarSystemProvider);

  await SettingsBottomSheet.show(
    context: context,
    title: isPrimary
        ? (l10n?.selectPrimaryCalendar ?? 'Select Primary Calendar')
        : (l10n?.selectSecondaryCalendar ?? 'Select Secondary Calendar'),
    children: AppCalendarSystem.values.map((system) {
      return SettingsPickerItem(
        title: system.label,
        isSelected: system == currentSystem,
        onTap: () async {
          if (isPrimary) {
            await ref
                .read(calendarPreferencesProvider.notifier)
                .setPrimaryCalendarSystem(system);
          } else {
            await ref
                .read(calendarPreferencesProvider.notifier)
                .setSecondaryCalendarSystem(system);
          }
          if (context.mounted) Navigator.pop(context);
        },
      );
    }).toList(),
  );
}
