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
import 'package:jyotish/jyotish.dart';
import 'app/bootstrap.dart';
import 'core/feedback/app_messages.dart';
import 'core/storage/hive_adapters.dart';
import 'providers/location_provider.dart';
import 'providers/panchang_provider.dart';
import 'providers/theme_provider.dart';
import 'providers/accessibility_provider.dart';
import 'providers/calendar_provider.dart';
import 'providers/locale_provider.dart';
import 'theme/app_theme.dart';
import 'screens/home_screen.dart';

// Conditional import for platform-specific features
import 'platform/platform_init.dart';

void main() {
  runZonedGuarded(
    () async {
      WidgetsFlutterBinding.ensureInitialized();
      const bootstrap = AppBootstrap();
      await bootstrap.initSystem();

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

      // Independent warm-ups run concurrently: version metadata, Hive +
      // adapters + core boxes, and font preloads (bounded internally).
      registerHiveAdapters();
      await Future.wait([
        bootstrap.warmVersionInfo(),
        bootstrap.initStorage(),
        bootstrap.warmFonts(),
      ]);

      // Initialize timezone for notifications
      bootstrap.initTimezones();

      runApp(const ProviderScope(child: TithiApp()));

      // Post-first-frame: tile cache + Workmanager must never block it.
      // The temple map awaits AppBootstrap.tileCacheReady before tiles.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        unawaited(bootstrap.initTileCache());
        unawaited(bootstrap.initBackgroundWork());
      });
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
    if (state == AppLifecycleState.resumed) {
      // A tithi boundary may have passed while suspended (OS-held timers
      // are unreliable in the background): recompute the live tick so the
      // hero corrects instantly instead of showing a stale label.
      ref.invalidate(liveTithiTickProvider);
      // Same for the calendar date: the one-shot midnight timer may never
      // have fired while suspended, leaving todayDateProvider (and every
      // countdown derived from it) a day behind. Re-sync when the wall
      // date moved, and re-arm the midnight timer from now.
      final today = ref.read(todayDateProvider);
      final now = DateTime.now();
      if (today.year != now.year ||
          today.month != now.month ||
          today.day != now.day) {
        ref.read(todayDateProvider.notifier).setToday(now);
      }
      _scheduleMidnightRefresh();
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
      theme: AppTheme.resolveAccessible(
        AppTheme.shuklaTheme,
        highContrast: accessibility.highContrast,
        reduceMotion: accessibility.reduceMotion,
      ),
      darkTheme: AppTheme.resolveAccessible(
        darkTheme,
        highContrast: accessibility.highContrast,
        reduceMotion: accessibility.reduceMotion,
      ),
      builder: (context, child) {
        final scale = accessibility.largeText ? 1.3 : 1.0;
        final mediaQuery = MediaQuery.of(context);
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
          data: mediaQuery.copyWith(
            textScaler: TextScaler.linear(scale),
            // Reduce Motion: propagate app setting globally while still
            // respecting the OS-level disableAnimations flag.
            disableAnimations: accessibility.reduceMotion
                ? true
                : mediaQuery.disableAnimations,
            // High Contrast: propagate app setting globally while still
            // respecting the OS-level highContrast flag.
            highContrast: accessibility.highContrast
                ? true
                : mediaQuery.highContrast,
          ),
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
    try {
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
    } finally {
      // Wait for the device-location lookup to settle before unblocking
      // background festival seeding. The granted path only invalidates
      // `currentLocationProvider` without awaiting it, so without this the
      // gate completes while `resolvedCoordinatesProvider` still holds the
      // Delhi fallback — the month batch then computes once with fallback
      // coordinates and again when GPS finishes. Awaiting here (with a
      // timeout fallback) ensures seeding computes once with final
      // coordinates (granted → device; denied/skipped/failed → default).
      // Runs on every path — including later launches, where it completes
      // immediately — so seeding can never deadlock. Guarded: the wrapper
      // outlives the flow, but never crash teardown.
      try {
        await ref
            .read(currentLocationProvider.future)
            .timeout(const Duration(seconds: 10));
      } catch (_) {
        // GPS unavailable/timed out: fallback coordinates apply and
        // seeding still proceeds.
      }
      try {
        final gate = ref.read(locationPermissionGateProvider);
        if (!gate.isCompleted) gate.complete();
      } catch (_) {
        // Seeding stays gated only if the scope itself is gone (app exit).
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
            const Icon(Icons.location_on, color: AppTheme.locationAccent),
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
              style: TextStyle(
                fontSize: 14,
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.6),
              ),
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
        showAppMessage(
          context,
          l10n?.pleaseEnableLocationServices ??
              'Please enable location services on your device',
          kind: AppMessageKind.error,
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
        showAppMessage(
          context,
          l10n?.locationPermissionDenied ??
              'Location permission denied. Using default location.',
          kind: AppMessageKind.error,
        );
      }
    } else {
      await locationService.setLocationEnabled(true);
      // Trigger location fetch
      ref.invalidate(currentLocationProvider);
      if (mounted) {
        showAppMessage(
          context,
          l10n?.locationEnabledSuccess ?? 'Location enabled successfully!',
          kind: AppMessageKind.success,
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
        decoration: AppTheme.backgroundDecoration(context),
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
