import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import '../../../providers/location_provider.dart';
import '../../../l10n/app_localizations.dart';
import '../../../theme/app_theme.dart';
import '../../../screens/location_picker_screen.dart';
import '../../../widgets/settings_widgets.dart';

class LocationSettingsSection extends ConsumerWidget {
  const LocationSettingsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final locationAsync = ref.watch(currentLocationProvider);
    final locationService = ref.read(locationServiceProvider);
    final isEnabledAsync = ref.watch(locationEnabledProvider);

    final isEnabled = isEnabledAsync.whenOrNull(data: (val) => val);
    final isLoading = isEnabledAsync.isLoading;

    return SettingsSwitchTile(
      icon: Icons.location_on_rounded,
      title: l10n?.autoLocation ?? 'Auto Location',
      subtitle: locationAsync.when(
        data: (loc) {
          final cityName = loc?.cityName;
          if (cityName != null) {
            return l10n?.usingLocation(cityName) ?? 'Using: $cityName';
          }
          return l10n?.useGpsForTithi ??
              'Use GPS for precise Tithi calculation';
        },
        loading: () => l10n?.fetchingLocation ?? 'Fetching location...',
        error: (e, s) => l10n?.locationUnavailable ?? 'Location unavailable',
      ),
      value: isEnabled ?? false,
      isLoading: isLoading,
      onChanged: isEnabled == null
          ? null
          : (val) async {
              if (val) {
                // User wants to enable location
                var permission = await Geolocator.checkPermission();

                if (permission == LocationPermission.deniedForever) {
                  // Permission permanently denied, guide user to app settings
                  if (context.mounted) {
                    final shouldOpenSettings = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: Text(
                          l10n?.permissionRequired ?? 'Permission Required',
                        ),
                        content: Text(
                          l10n?.locationPermissionPermanentlyDenied ??
                              'Location permission was permanently denied. Please enable it in your device settings.',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, false),
                            child: Text(l10n?.cancel ?? 'Cancel'),
                          ),
                          FilledButton(
                            onPressed: () => Navigator.pop(ctx, true),
                            child: Text(l10n?.openSettings ?? 'Open Settings'),
                          ),
                        ],
                      ),
                    );

                    if (shouldOpenSettings == true) {
                      await Geolocator.openAppSettings();
                    }
                    return; // Don't enable until user grants permission manually
                  }
                }

                if (permission == LocationPermission.denied) {
                  permission = await Geolocator.requestPermission();
                  if (permission == LocationPermission.denied ||
                      permission == LocationPermission.deniedForever) {
                    // Permission still denied, don't enable
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            l10n?.locationPermissionDenied ??
                                'Location permission denied.',
                          ),
                        ),
                      );
                    }
                    return;
                  }
                }
              }

              await locationService.setLocationEnabled(val);
              // Invalidate both providers to refresh state
              ref.invalidate(locationEnabledProvider);
              ref.invalidate(currentLocationProvider);
            },
    );
  }
}


class HomeLocationSetting extends ConsumerWidget {
  const HomeLocationSetting({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final homeLocation = ref.watch(homeLocationProvider);

    return SettingsActionTile(
      icon: Icons.home_rounded,
      title: l10n?.homeLocation ?? 'Home Location',
      trailing: SizedBox(
        width: 120,
        child: Text(
          homeLocation?.cityName ?? (l10n?.notSet ?? 'Not set'),
          textAlign: TextAlign.end,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: context.textTheme.labelSmall?.copyWith(
            color: context.colors.onSurface.withValues(alpha: 0.6),
          ),
        ),
      ),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const LocationPickerScreen()),
        );
      },
    );
  }
}

