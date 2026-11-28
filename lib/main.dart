import 'dart:async';

import 'package:flutter/foundation.dart' show kReleaseMode;
import 'package:material_ui/material_ui.dart';
import 'package:material_3_expressive/material_3_expressive.dart';
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
import 'core/location/place_clock.dart';
import 'core/location/place_grid.dart';
import 'core/perf/startup_timeline.dart';
import 'core/storage/hive_adapters.dart';
import 'providers/location_provider.dart';
import 'providers/panchang_provider.dart';
import 'providers/theme_provider.dart';
import 'providers/accessibility_provider.dart';
import 'providers/calendar_provider.dart';
import 'providers/home_widget_provider.dart';
import 'providers/locale_provider.dart';
import 'services/location_service.dart';
import 'theme/app_theme.dart';
import 'theme/app_metrics.dart';
import 'theme/app_typography.dart';
import 'screens/home_shell.dart';
import 'widgets/animated_splash.dart';
import 'widgets/app_buttons.dart';
import 'widgets/app_dialog.dart';
import 'widgets/panchang_init_failure_overlay.dart';

void main() {
  runZonedGuarded(
    () async {
      StartupTimeline.start();
      WidgetsFlutterBinding.ensureInitialized();
      StartupTimeline.mark('binding-ready');
      // Bundled font licenses (SIL OFL) for the About/license page.
      AppTypography.registerFontLicenses();
      const bootstrap = AppBootstrap();
      await bootstrap.initSystem();
      StartupTimeline.mark('system-ready');

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

      // Set the high refresh rate before the first frame so the animated
      // loading splash runs at 90/120Hz from the start and the switch happens
      // behind the static native splash. It is one platform-channel call, and
      // any failure is swallowed by initDisplay().
      await bootstrap.initDisplay();

      // Version metadata, the place boundary index, the tile cache and
      // Workmanager do not paint the splash, so they run after the first frame.
      registerHiveAdapters();
      await bootstrap.initStorage();
      StartupTimeline.mark('storage-ready');

      // tzdata must be loaded before `TithiApp.initState` builds the place
      // clock; the boundary index it used to warm here is deferred below.
      await bootstrap.initTimezones();
      StartupTimeline.mark('timezones-ready');

      runApp(const ProviderScope(child: TithiApp()));

      // Post-first-frame: nothing below may block the splash.
      // The temple map awaits AppBootstrap.tileCacheReady before tiles.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        StartupTimeline.mark('first-frame');
        unawaited(bootstrap.warmVersionInfo());
        unawaited(bootstrap.warmTimezoneIndex());
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
  ///
  /// The midnight is the *place clock's* midnight: with a manually selected
  /// place the app's "today" is that place's day, so the timer must re-arm on
  /// its boundary, not the phone's.
  void _scheduleMidnightRefresh() {
    _midnightTimer?.cancel();
    final clock = ref.read(placeClockProvider);
    final now = nowInPlaceClock(clock);
    final midnight = nextMidnightInPlaceClock(clock);
    var delay = midnight.difference(now) + const Duration(seconds: 1);
    if (delay.isNegative) delay = const Duration(seconds: 1);
    _midnightTimer = Timer(delay, () {
      if (mounted) {
        ref
            .read(todayDateProvider.notifier)
            .setToday(nowInPlaceClock(ref.read(placeClockProvider)));
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
      // Refresh the wall-clock seam too; livePanchangProvider reads it and a
      // cached first-read instant would keep the pre-boundary label.
      ref.invalidate(liveNowProvider);
      ref.invalidate(liveTithiTickProvider);
      // Same for the calendar date: the one-shot midnight timer may never
      // have fired while suspended, leaving todayDateProvider (and every
      // countdown derived from it) a day behind. Re-sync when the wall
      // date moved, and re-arm the midnight timer from now.
      final today = ref.read(todayDateProvider);
      final now = nowInPlaceClock(ref.read(placeClockProvider));
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
    // Keeps the hero + timing home-screen widgets fed for the whole session,
    // even when the promo card on the home screen is dismissed.
    ref.watch(panchangWidgetSyncProvider);
    // A place change moves "today" to another clock: re-anchor the date and
    // re-arm the midnight timer against the new zone instead of waiting for
    // the phone's next midnight.
    ref.listen(placeClockProvider, (previous, next) {
      if (previous == next) return;
      ref.read(todayDateProvider.notifier).setToday(nowInPlaceClock(next));
      _scheduleMidnightRefresh();
    });

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
      // Instant palette swap. MaterialApp otherwise cross-fades ThemeData over
      // 200ms, and ThemeData/ColorScheme.lerp flips `brightness` to dark at the
      // halfway point while `scaffoldBackgroundColor` is still a mid grey.
      // AppTheme.isPureDarkTheme() decides "pure dark vs Krishna" from
      // `scaffold == Colors.black`, so during that window it takes the Krishna
      // branch and paints plum cards / purple accents on the way from Shukla to
      // Pure Dark (and back). The three palettes share no meaningful midpoint,
      // so there is nothing worth interpolating: switch in one frame.
      themeAnimationDuration: Duration.zero,
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
        final overlayStyle = AppTheme.systemUiOverlayStyle(
          Theme.of(context).brightness,
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
            // A failed ephemeris install must be visible on every route, not
            // just on the home screen: most panchangInitProvider consumers
            // degrade to empty data instead of showing the error themselves.
            child: PanchangInitFailureOverlay(
              child: child ?? const SizedBox.shrink(),
            ),
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
    // The place the previous session ended on, when there is one. Read after
    // the first-launch dialog: skipping it disables location, which changes
    // what `lastKnownLocation` answers.
    LocationData? savedPlace;
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
      savedPlace = locationService.lastKnownLocation;
    } finally {
      // A saved place is enough to start computing: the first frame paints the
      // place the user actually used, and the device fix (with its reverse
      // geocode) refreshes in the background. Waiting for it here meant every
      // home card sat on a skeleton behind a GPS fix + Nominatim round trip
      // that can take seconds after Android evicted the process.
      //
      // With no saved place (first launch, or a failed cache read) keep the old
      // behaviour: wait for the device lookup so the month batch does not
      // compute once with the Delhi fallback and again with the real fix.
      if (savedPlace != null) {
        unawaited(_refreshDevicePlace(savedPlace));
      } else {
        try {
          await ref
              .read(currentLocationProvider.future)
              .timeout(const Duration(seconds: 10));
        } catch (_) {
          // GPS unavailable/timed out: fallback coordinates apply and
          // seeding still proceeds.
        }
      }
      StartupTimeline.mark('location-gate', {'saved': savedPlace != null});
      try {
        final gate = ref.read(locationPermissionGateProvider);
        if (!gate.isCompleted) gate.complete();
      } catch (_) {
        // Seeding stays gated only if the scope itself is gone (app exit).
      }
    }
  }

  /// Fetches the device fix without blocking the gate, then reports whether it
  /// moved far enough to invalidate the day computation.
  ///
  /// The recompute itself is not triggered here:
  /// [calculationLocationProvider] adopts the new fix once it is known, and
  /// ignoring sub-grid moves keeps a stationary device from restarting the
  /// month batch right after it painted.
  Future<void> _refreshDevicePlace(LocationData savedPlace) async {
    final LocationData? fresh;
    try {
      fresh = await ref.read(currentLocationProvider.future);
    } catch (_) {
      // GPS or geocoding unavailable: the saved place stands for this session.
      return;
    }
    if (fresh == null) return;
    final moved = !samePlaceGrid(
      latitudeA: savedPlace.latitude,
      longitudeA: savedPlace.longitude,
      latitudeB: fresh.latitude,
      longitudeB: fresh.longitude,
    );
    StartupTimeline.mark('location-fresh', {
      'moved': moved,
      'city': fresh.cityName ?? '-',
    });
  }

  Future<void> _showFirstLaunchDialog() async {
    final l10n = AppLocalizations.of(context);
    final result = await AppDialog.show<bool>(
      context,
      title: l10n?.locationAccess ?? 'Location Access',
      icon: const Icon(Icons.location_on, color: AppTheme.locationAccent),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n?.locationAccessDescription ?? 'Tithi uses your location to calculate accurate Panchang data for your city.',
            style: const TextStyle(fontSize: AppTypography.sizeSubtitle),
          ),
          const SizedBox(height: AppSpacing.s12),
          Text(
            l10n?.locationAccessBenefits ??
                '• More accurate tithi calculations\n'
                    '• Location-specific moonrise/sunset times\n'
                    '• Your location data stays on your device',
            style: TextStyle(
              fontSize: AppTypography.sizeBody,
              color: context.secondaryInk,
            ),
          ),
        ],
      ),
      barrierDismissible: false,
      actions: [
        AppButton(
          style: M3EButtonStyle.text,
          onPressed: () =>
              Navigator.of(context, rootNavigator: true).pop(false),
          child: Text(l10n?.skip ?? 'Skip'),
        ),
        AppButton(
          icon: const Icon(Icons.check),
          label: Text(l10n?.enableLocation ?? 'Enable Location'),
          onPressed: () => Navigator.of(context, rootNavigator: true).pop(true),
        ),
      ],
    );

    if (result == true) {
      await _requestLocationPermission();
    } else {
      final locationService = ref.read(locationServiceProvider);
      await locationService.setLocationEnabled(false);
      refreshPlaceContext(ref);
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
      refreshPlaceContext(ref);
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
      refreshPlaceContext(ref);
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
      // Trigger location fetch; the clock moves to the device's.
      refreshPlaceContext(ref);
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
    // Keep the app off screen until the saved place is loaded, so the first
    // frame is the place the user actually used. The animated mandala is the
    // loading UI: it replaces the old "Initializing..." spinner and starts on
    // the same colour as the native splash, so the hand-off is continuous.
    if (_showHomeScreen) {
      return const HomeShell();
    }
    return const AnimatedSplash();
  }
}
