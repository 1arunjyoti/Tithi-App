// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Tithi';

  @override
  String get vedaCalendar => 'Vedic Calendar';

  @override
  String get settings => 'Settings';

  @override
  String get appearance => 'APPEARANCE';

  @override
  String get preferences => 'PREFERENCES';

  @override
  String get calendar => 'CALENDAR';

  @override
  String get dataStorage => 'DATA & STORAGE';

  @override
  String get accessibility => 'ACCESSIBILITY';

  @override
  String get about => 'ABOUT';

  @override
  String get themeAuto => 'Auto';

  @override
  String get themeShukla => 'Shukla';

  @override
  String get themeDark => 'Dark';

  @override
  String get themeKrishna => 'Krishna';

  @override
  String get dailyNotifications => 'Daily Notifications';

  @override
  String get notificationScheduled => 'Scheduled daily';

  @override
  String get getNotifiedTithiDaily => 'Get notified about Tithi daily';

  @override
  String get notificationTime => 'Notification Time';

  @override
  String get autoLocation => 'Auto Location';

  @override
  String get useGpsForTithi => 'Use GPS for precise Tithi calculation';

  @override
  String usingLocation(String cityName) {
    return 'Using: $cityName';
  }

  @override
  String get fetchingLocation => 'Fetching location...';

  @override
  String get locationUnavailable => 'Location unavailable';

  @override
  String get homeLocation => 'Home Location';

  @override
  String get notSet => 'Not set';

  @override
  String get setHomeLocation => 'Set Home Location';

  @override
  String get dragMapToPin => 'Drag map to position pin at your home';

  @override
  String get setThisLocation => 'Set This Location';

  @override
  String homeLocationSetTo(String address) {
    return 'Home location set to $address';
  }

  @override
  String errorSettingLocation(String error) {
    return 'Error setting location: $error';
  }

  @override
  String get startOfWeek => 'Start of Week';

  @override
  String get sunday => 'Sunday';

  @override
  String get monday => 'Monday';

  @override
  String get primaryView => 'Primary View';

  @override
  String get tithi => 'Tithi';

  @override
  String get festival => 'Festival';

  @override
  String get moon => 'Moon';

  @override
  String get primaryCalendar => 'Primary Calendar';

  @override
  String get secondaryCalendar => 'Secondary Calendar';

  @override
  String get selectPrimaryCalendar => 'Select Primary Calendar';

  @override
  String get selectSecondaryCalendar => 'Select Secondary Calendar';

  @override
  String get clearLocationCache => 'Clear Location Cache';

  @override
  String get locationCacheCleared => 'Location cache cleared';

  @override
  String get resetAppSettings => 'Reset App Settings';

  @override
  String get resetSettingsTitle => 'Reset Settings?';

  @override
  String get resetSettingsMessage =>
      'This will reset all your preferences and data to default. This cannot be undone.';

  @override
  String get cancel => 'Cancel';

  @override
  String get reset => 'Reset';

  @override
  String get appResetComplete => 'App reset complete';

  @override
  String get reduceMotion => 'Reduce Motion';

  @override
  String get disableAnimations => 'Disable animations & effects';

  @override
  String get hapticFeedback => 'Haptic Feedback';

  @override
  String get vibrateOnTouch => 'Vibrate on touch interactions';

  @override
  String get highContrast => 'High Contrast';

  @override
  String get solidBackgrounds => 'Solid backgrounds for better readability';

  @override
  String get largeText => 'Large Text';

  @override
  String get increaseTextSize => 'Increase text size globally';

  @override
  String get language => 'Language';

  @override
  String get selectLanguage => 'Select Language';

  @override
  String get systemDefault => 'System Default';

  @override
  String get privacyPolicy => 'Privacy Policy';

  @override
  String get madeWithLove => 'Made with ❤️ for Sanatan Dharma';

  @override
  String get shareApp => 'Share App';

  @override
  String get shareAppMessage =>
      'Check out Tithi - The Vedic Calendar App! Download now: https://example.com/tithi';

  @override
  String get rateUs => 'Rate Us';

  @override
  String get aboutApp => 'About';

  @override
  String get calendarView => 'Calendar View';

  @override
  String get scheduleView => 'Schedule View';

  @override
  String get switchToCalendar => 'Switch to month calendar';

  @override
  String get switchToSchedule => 'Switch to event list';

  @override
  String versionText(String version) {
    return 'Version $version';
  }

  @override
  String get events => 'EVENTS';

  @override
  String get festivalsAndEvents => 'Festivals & Events';

  @override
  String get noFestivalsOnThisDay => 'No festivals on this day';

  @override
  String get todaysFestival => 'Today\'s Festival';

  @override
  String get noFestivalsToday => 'Tithi • No Festivals Today';

  @override
  String errorLoadingPanchang(String error) {
    return 'Error loading panchang: $error';
  }

  @override
  String get panchangDetails => 'Panchang Details';

  @override
  String get paksha => 'Paksha';

  @override
  String pakshaWithName(String paksha) {
    return '$paksha Paksha';
  }

  @override
  String get waxing => 'Waxing';

  @override
  String get waning => 'Waning';

  @override
  String get waxingMoonPhase => 'Waxing Moon Phase';

  @override
  String get waningMoonPhase => 'Waning Moon Phase';

  @override
  String get category => 'Category';

  @override
  String get general => 'General';

  @override
  String get ritualsAndPractices => 'Rituals & Practices';

  @override
  String get locationAccess => 'Location Access';

  @override
  String get enableLocation => 'Enable Location';

  @override
  String get skip => 'Skip';

  @override
  String get locationAccessDescription =>
      'Tithi uses your location to calculate accurate Panchang data for your city.';

  @override
  String get locationAccessBenefits =>
      '• More accurate tithi calculations\n• Location-specific moonrise/sunset times\n• Your location data stays on your device';

  @override
  String get locationDisabled => 'Location Disabled';

  @override
  String get locationDisabledMessage =>
      'Location is disabled. Enable it for more accurate Panchang calculations based on your city.';

  @override
  String get notNow => 'Not Now';

  @override
  String get enable => 'Enable';

  @override
  String get pleaseEnableLocationServices =>
      'Please enable location services on your device';

  @override
  String get locationPermissionDenied =>
      'Location permission denied. Using default location.';

  @override
  String get locationEnabledSuccess => 'Location enabled successfully!';

  @override
  String get refreshLocation => 'Refresh Location';

  @override
  String get goToToday => 'Go to Today';

  @override
  String get initializing => 'Initializing...';

  @override
  String get privacyYourDataStays => 'Your Data Stays With You';

  @override
  String get privacyYourDataDesc =>
      'Tithi is designed with a privacy-first, offline-first architecture. All astronomical calculations, calendar generation, and event processing happen directly on your device. We do not collect, store, or transmit your personal data to any external servers.';

  @override
  String get privacyLocationUsage => 'Location Usage';

  @override
  String get privacyLocationDesc =>
      'We request access to your location solely to calculate accurate Tithi, Nakshatra, and sunrise/sunset timings, which depend on your specific geographic coordinates. Your location data is processed locally by the app and is never shared with third parties or stored on our servers.';

  @override
  String get privacyOffline => 'Offline Functionality';

  @override
  String get privacyOfflineDesc =>
      'The app works completely offline after the initial download. It contains the Swiss Ephemeris data required for high-precision planetary calculations embedded within the app itself.';

  @override
  String get privacyOpenSource => 'Open Source Transparency';

  @override
  String get privacyOpenSourceDesc =>
      'Tithi is an open-source project. Our code is publicly available for audit, ensuring that our privacy promises are backed by verifiable transparency. What you see is exactly what you get.';

  @override
  String get lastUpdated => 'Last Updated: December 2025';

  @override
  String get applicationLegalese =>
      '© 2025 Tithi Project\nMade with ❤️ for Sanatan Dharma';

  @override
  String get moonPhases => 'Moon Phases';

  @override
  String get nextPurnima => 'Next Purnima';

  @override
  String get nextAmavasya => 'Next Amavasya';

  @override
  String get purnima => 'Purnima';

  @override
  String get amavasya => 'Amavasya';

  @override
  String get fullMoon => 'Full Moon';

  @override
  String get newMoon => 'New Moon';

  @override
  String get noUpcomingDates => 'No upcoming dates found';

  @override
  String get errorLoadingData => 'Error loading data';

  @override
  String get retry => 'Retry';

  @override
  String get astronomy => 'Astronomy';

  @override
  String get solarSystem => 'Solar System';

  @override
  String get planetPositions => 'Planet Positions';

  @override
  String get selectDate => 'Select Date';

  @override
  String get retrograde => 'Retrograde';

  @override
  String get zodiacSign => 'Sign';

  @override
  String get degree => 'Degree';

  @override
  String get longitude => 'Longitude';

  @override
  String get eclipses => 'Eclipses';

  @override
  String get solarEclipses => 'Solar Eclipses';

  @override
  String get lunarEclipses => 'Lunar Eclipses';

  @override
  String get maxEclipse => 'Maximum Eclipse';

  @override
  String get visibleFromYourLocation => 'Visible from your location';

  @override
  String get notVisibleFromYourLocation => 'Not visible from your location';

  @override
  String get partialBegins => 'Partial phase begins';

  @override
  String get partialEnds => 'Partial phase ends';

  @override
  String get totalityBegins => 'Totality begins';

  @override
  String get totalityEnds => 'Totality ends';

  @override
  String get duration => 'Duration';

  @override
  String get date => 'Date';

  @override
  String get days => 'days';

  @override
  String get today => 'Today';
}
