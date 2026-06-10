import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb, kReleaseMode;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'widgets/error_display_widget.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'l10n/app_localizations.dart';
import 'l10n/fallback_localization_delegates.dart';
import 'package:geolocator/geolocator.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:jyotish/jyotish.dart';
import 'package:flutter_map_tile_caching/flutter_map_tile_caching.dart';
import 'providers/location_provider.dart';
import 'providers/theme_provider.dart';
import 'providers/accessibility_provider.dart';
import 'providers/calendar_provider.dart';
import 'providers/locale_provider.dart';
import 'providers/version_provider.dart';
import 'theme/app_theme.dart';
import 'screens/home_screen.dart';
import 'models/festival.dart';
import 'models/sankalpa.dart';
import 'services/notification_service.dart';
import 'services/storage_service.dart';

// Conditional import for platform-specific features
import 'platform/platform_init.dart';

void main() {
  runZonedGuarded(
    () async {
      WidgetsFlutterBinding.ensureInitialized();

      // Set default status bar style for Shukla (light) theme
      SystemChrome.setSystemUIOverlayStyle(
        const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.dark,
          statusBarBrightness: Brightness.light,
        ),
      );

      // Set custom error widget to replace the red error screen
      ErrorWidget.builder = (FlutterErrorDetails details) {
        // In debug mode, show more details for development
        if (kReleaseMode) {
          return const ErrorDisplayWidget(
            message: 'An unexpected error occurred. Please restart the app.',
          );
        }
        // In debug mode, show the error message for easier debugging
        return ErrorDisplayWidget(message: details.exceptionAsString());
      };

      // Capture Flutter framework errors
      FlutterError.onError = (FlutterErrorDetails details) {
        FlutterError.presentError(details);
        // Log error for debugging
        debugPrint('Flutter error caught: ${details.exception}');
        debugPrint('Stack trace: ${details.stack}');
      };

      // Optimized Display Mode (90Hz/120Hz) - Skip on web
      if (!kIsWeb) {
        await initPlatformFeatures();
      }

      // Preload package/version metadata before first drawer animation.
      await warmVersionInfo();

      // Initialize Hive for offline storage
      await Hive.initFlutter();

      if (!kIsWeb) {
        await FMTCObjectBoxBackend().initialise(
          maxDatabaseSize: 256 * 1024 * 1024,
        );
        const tileStore = FMTCStore('osm_tiles');
        if (!await tileStore.manage.ready) {
          await tileStore.manage.create(maxLength: 8000);
        }
      }

      // Register Adapters
      Hive.registerAdapter(FestivalAdapter());
      Hive.registerAdapter(NameRegionalAdapter());
      Hive.registerAdapter(VisualsAdapter());
      Hive.registerAdapter(PurposeAdapter());
      Hive.registerAdapter(PanchangRulesAdapter());
      Hive.registerAdapter(RitualsAdapter());
      Hive.registerAdapter(MediaAdapter());
      Hive.registerAdapter(SankalpaAdapter()); // Type ID 10

      final storageService = StorageService();
      await storageService.init();

      // Initialize timezone for notifications
      tz_data.initializeTimeZones();

      // Initialize WorkManager for background notifications
      await NotificationService().initWorkManager();

      runApp(const ProviderScope(child: TithiApp()));
    },
    (error, stackTrace) {
      // Handle uncaught async Dart errors
      debugPrint('Uncaught async error: $error');
      debugPrint('Stack trace: $stackTrace');
    },
  );
}

/// Main app widget with dynamic theming
class TithiApp extends ConsumerStatefulWidget {
  const TithiApp({super.key});

  @override
  ConsumerState<TithiApp> createState() => _TithiAppState();
}

class _TithiAppState extends ConsumerState<TithiApp>
    with WidgetsBindingObserver {
  Timer? _midnightTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _scheduleMidnightRefresh();
  }

  /// Schedules a one-shot timer that fires just after midnight so that
  /// [todayDateProvider] (and anything that depends on it) is refreshed
  /// to the new calendar date without requiring an app restart.
  void _scheduleMidnightRefresh() {
    _midnightTimer?.cancel();
    final now = DateTime.now();
    final midnight = DateTime(now.year, now.month, now.day + 1);
    final delay = midnight.difference(now) + const Duration(seconds: 1);
    _midnightTimer = Timer(delay, () {
      if (mounted) {
        ref.read(todayDateProvider.notifier).setToday(DateTime.now());
      }
      _scheduleMidnightRefresh(); // re-arm for the following midnight
    });
  }

  @override
  void dispose() {
    _midnightTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    // Clean up Jyotish resources when app is disposed (BUG-01: single disposal site)
    try {
      final jyotish = Jyotish();
      if (jyotish.isInitialized) {
        jyotish.dispose();
      }
    } catch (e) {
      debugPrint('Error disposing Jyotish: $e');
    }
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    final locationService = ref.read(locationServiceProvider);
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      unawaited(locationService.markAppBackgrounded());
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeModeProvider);
    final darkTheme = ref.watch(darkThemeProvider);
    final accessibility = ref.watch(accessibilityProvider);
    final locale = ref.watch(localeProvider);

    return MaterialApp(
      title: 'Tithi',
      debugShowCheckedModeBanner: false,
      // Localization configuration - using fallback delegates for Sanskrit support
      localizationsDelegates: const [
        AppLocalizations.delegate,
        FallbackMaterialLocalizationsDelegate(), // Falls back to English for Sanskrit
        GlobalWidgetsLocalizations.delegate,
        FallbackCupertinoLocalizationsDelegate(), // Falls back to English for Sanskrit
      ],
      supportedLocales: const [
        Locale('en'), // English
        Locale('hi'), // Hindi
        Locale('bn'), // Bengali
        Locale('sa'), // Sanskrit
      ],
      // Handle locale resolution for unsupported Material locales like Sanskrit
      localeResolutionCallback: (locale, supportedLocales) {
        // If locale is null or not in our list, use first supported
        if (locale == null) {
          return supportedLocales.first;
        }
        // Check if Material widgets support this locale
        // Sanskrit is not supported by MaterialLocalizations, so we need special handling
        for (final supportedLocale in supportedLocales) {
          if (supportedLocale.languageCode == locale.languageCode) {
            return supportedLocale;
          }
        }
        return supportedLocales.first;
      },
      // For Material widgets (dialogs, pickers), use English fallback for Sanskrit
      localeListResolutionCallback: (locales, supportedLocales) {
        if (locales == null || locales.isEmpty) {
          return supportedLocales.first;
        }
        for (final locale in locales) {
          for (final supportedLocale in supportedLocales) {
            if (supportedLocale.languageCode == locale.languageCode) {
              return supportedLocale;
            }
          }
        }
        return supportedLocales.first;
      },
      locale: locale, // User-selected locale (null = system default)
      themeMode: themeMode,
      theme: AppTheme.shuklaTheme,
      darkTheme: darkTheme,
      builder: (context, child) {
        final scale = accessibility.largeText ? 1.3 : 1.0;
        final isDarkTheme = Theme.of(context).brightness == Brightness.dark;
        final overlayStyle = isDarkTheme
            ? const SystemUiOverlayStyle(
                statusBarColor: Colors.transparent,
                statusBarIconBrightness: Brightness.light,
                statusBarBrightness: Brightness.dark,
              )
            : const SystemUiOverlayStyle(
                statusBarColor: Colors.transparent,
                statusBarIconBrightness: Brightness.dark,
                statusBarBrightness: Brightness.light,
              );
        return MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(scale)),
          child: AnnotatedRegion<SystemUiOverlayStyle>(
            value: overlayStyle,
            child: child!,
          ),
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
  bool _showHomeScreen = false;
  bool _permissionRequested = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initLocationFlow();
    });
  }

  Future<void> _initLocationFlow() async {
    // Wait for location service to initialize
    await ref.read(locationInitProvider.future);

    if (mounted && !_showHomeScreen) {
      setState(() {
        _showHomeScreen = true;
      });
    }

    final locationService = ref.read(locationServiceProvider);
    final isFirstLaunch = await locationService.isFirstLaunch();

    if (isFirstLaunch && !_permissionRequested) {
      _permissionRequested = true;
      // Show dialog after first frame so UI is already visible
      if (mounted) {
        await _showFirstLaunchDialog();
        await locationService.markFirstLaunchComplete();
      }
    }
  }

  Future<void> _showFirstLaunchDialog() async {
    final l10n = AppLocalizations.of(context);
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.location_on, color: Colors.amber),
            const SizedBox(width: 8),
            Text(l10n?.locationAccess ?? 'Location Access'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n?.locationAccessDescription ??
                  'Tithi uses your location to calculate accurate Panchang data for your city.',
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 12),
            Text(
              l10n?.locationAccessBenefits ??
                  '• More accurate tithi calculations\n'
                      '• Location-specific moonrise/sunset times\n'
                      '• Your location data stays on your device',
              style: const TextStyle(fontSize: 14, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n?.skip ?? 'Skip'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.of(context).pop(true),
            icon: const Icon(Icons.check),
            label: Text(l10n?.enableLocation ?? 'Enable Location'),
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

  Future<void> _requestLocationPermission() async {
    final locationService = ref.read(locationServiceProvider);
    final l10n = AppLocalizations.of(context);

    // Check if location services are enabled
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              l10n?.pleaseEnableLocationServices ??
                  'Please enable location services on your device',
            ),
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
          SnackBar(
            content: Text(
              l10n?.locationPermissionDenied ??
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
          SnackBar(
            content: Text(
              l10n?.locationEnabledSuccess ?? 'Location enabled successfully!',
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Show HomeScreen as soon as location service is initialized
    // Permission dialog will appear in background if first launch
    if (_showHomeScreen) {
      return const HomeScreen();
    }

    // Only show loading screen while waiting for location service init
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
}
