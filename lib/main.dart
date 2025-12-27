import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:nominatim_geocoding/nominatim_geocoding.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'providers/location_provider.dart';
import 'providers/theme_provider.dart';
import 'providers/accessibility_provider.dart';
import 'theme/app_theme.dart';
import 'screens/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Hive for offline storage
  await Hive.initFlutter();
  await Hive.openBox('settings');

  // Initialize timezone for notifications
  tz_data.initializeTimeZones();

  // Initialize Nominatim Geocoding with cache
  await NominatimGeocoding.init(reqCacheNum: 50);

  runApp(const ProviderScope(child: TithiApp()));
}

/// Main app widget with dynamic theming
class TithiApp extends ConsumerWidget {
  const TithiApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final darkTheme = ref.watch(darkThemeProvider);
    final accessibility = ref.watch(accessibilityProvider);

    return MaterialApp(
      title: 'Tithi',
      debugShowCheckedModeBanner: false,
      themeMode: themeMode,
      theme: AppTheme.shuklaTheme,
      darkTheme: darkTheme,
      builder: (context, child) {
        final scale = accessibility.largeText ? 1.3 : 1.0;
        return MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        );
      },
      home: const LocationPermissionWrapper(),
    );
  }
}

/// Wrapper widget to handle location permission flow
class LocationPermissionWrapper extends ConsumerStatefulWidget {
  const LocationPermissionWrapper({super.key});

  @override
  ConsumerState<LocationPermissionWrapper> createState() =>
      _LocationPermissionWrapperState();
}

class _LocationPermissionWrapperState
    extends ConsumerState<LocationPermissionWrapper> {
  bool _initialized = false;
  bool _showHomeScreen = false;

  @override
  void initState() {
    super.initState();
    _initLocationFlow();
  }

  Future<void> _initLocationFlow() async {
    // Wait for location service to initialize
    await ref.read(locationInitProvider.future);

    final locationService = ref.read(locationServiceProvider);
    final isFirstLaunch = await locationService.isFirstLaunch();

    if (isFirstLaunch) {
      // First launch: Show permission request dialog
      if (mounted) {
        await _showFirstLaunchDialog();
        await locationService.markFirstLaunchComplete();
      }
    } else {
      // Subsequent launch: Check if location is disabled
      final isLocationEnabled = await locationService.isLocationEnabled();
      if (!isLocationEnabled && mounted) {
        await _showEnableLocationDialog();
      }
    }

    if (mounted) {
      setState(() {
        _initialized = true;
        _showHomeScreen = true;
      });
    }
  }

  Future<void> _showFirstLaunchDialog() async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.location_on, color: Colors.amber),
            SizedBox(width: 8),
            Text('Location Access'),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Tithi uses your location to calculate accurate Panchang data for your city.',
              style: TextStyle(fontSize: 16),
            ),
            SizedBox(height: 12),
            Text(
              '• More accurate tithi calculations\n'
              '• Location-specific moonrise/sunset times\n'
              '• Your location data stays on your device',
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Skip'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.of(context).pop(true),
            icon: const Icon(Icons.check),
            label: const Text('Enable Location'),
          ),
        ],
      ),
    );

    if (result == true) {
      await _requestLocationPermission();
    } else {
      final locationService = ref.read(locationServiceProvider);
      await locationService.setLocationEnabled(false);
    }
  }

  Future<void> _showEnableLocationDialog() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.location_off, color: Colors.orange),
            SizedBox(width: 8),
            Text('Location Disabled'),
          ],
        ),
        content: const Text(
          'Location is disabled. Enable it for more accurate Panchang calculations based on your city.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Not Now'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Enable'),
          ),
        ],
      ),
    );

    if (result == true) {
      await _requestLocationPermission();
    }
  }

  Future<void> _requestLocationPermission() async {
    final locationService = ref.read(locationServiceProvider);

    // Check if location services are enabled
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please enable location services on your device'),
          ),
        );
      }
      await locationService.setLocationEnabled(false);
      return;
    }

    // Request permission
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      await locationService.setLocationEnabled(false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Location permission denied. Using default location.',
            ),
          ),
        );
      }
    } else {
      await locationService.setLocationEnabled(true);
      // Trigger location fetch
      ref.invalidate(currentLocationProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Location enabled successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_initialized) {
      return Scaffold(
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: Theme.of(context).scaffoldBackgroundColor == Colors.black
                  ? [Colors.black, Colors.black, Colors.black]
                  : Theme.of(context).brightness == Brightness.dark
                  ? [
                      const Color(0xFF10002B),
                      const Color(0xFF240046),
                      const Color(0xFF10002B),
                    ]
                  : [
                      const Color(0xFFFFFDF7),
                      const Color(0xFFFFECB3).withValues(alpha: 0.3),
                      const Color(0xFFFFFDF7),
                    ],
            ),
          ),
          child: const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Initializing...'),
              ],
            ),
          ),
        ),
      );
    }

    if (_showHomeScreen) {
      return const HomeScreen();
    }

    return const SizedBox.shrink();
  }
}
