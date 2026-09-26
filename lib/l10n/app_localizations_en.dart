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
  String get exportFestivalsJson => 'Export Festivals (JSON)';

  @override
  String get exportFestivalsSubtitle =>
      'Save all festivals with Panchang details to a file';

  @override
  String get exportFestivals => 'Export Festivals';

  @override
  String get exportFestivalsSubtitleYear =>
      'First occurrence of each festival in the chosen year';

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
  String get tithiPratipada => 'Pratipada';

  @override
  String get tithiDwitiya => 'Dwitiya';

  @override
  String get tithiTritiya => 'Tritiya';

  @override
  String get tithiChaturthi => 'Chaturthi';

  @override
  String get tithiPanchami => 'Panchami';

  @override
  String get tithiShashthi => 'Shashthi';

  @override
  String get tithiSaptami => 'Saptami';

  @override
  String get tithiAshtami => 'Ashtami';

  @override
  String get tithiNavami => 'Navami';

  @override
  String get tithiDashami => 'Dashami';

  @override
  String get tithiEkadashi => 'Ekadashi';

  @override
  String get tithiDwadashi => 'Dwadashi';

  @override
  String get tithiTrayodashi => 'Trayodashi';

  @override
  String get tithiChaturdashi => 'Chaturdashi';

  @override
  String get tithiPurnima => 'Purnima';

  @override
  String get tithiAmavasya => 'Amavasya';

  @override
  String get tithiUnknown => 'Unknown';

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
      'Check out Tithi - The Vedic Calendar App! Download now: https://tithiapp.netlify.app/';

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
      'Tithi is designed with a privacy-first, offline-first architecture. All astronomical calculations, calendar generation, event processing happen directly on your device and the app keeps working without a network. We do not collect, store, or transmit your personal data to any external servers.';

  @override
  String get privacyLocationUsage => 'Location Usage';

  @override
  String get privacyLocationDesc =>
      'We request access to your location solely to calculate accurate Tithi, Nakshatra, and sunrise/sunset timings, which depend on your specific geographic coordinates. Your location data is processed locally by the app and is never shared with third parties or stored on our servers.';

  @override
  String get privacyOffline => 'Offline Functionality';

  @override
  String get privacyOfflineDesc =>
      'The app works completely offline. It contains the Swiss Ephemeris data required for high-precision planetary calculations embedded within the app itself.';

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

  @override
  String illuminatedPercent(String percent) {
    return '$percent% illuminated';
  }

  @override
  String get nextTithi => 'Next tithi';

  @override
  String atTime(String time) {
    return 'at $time';
  }

  @override
  String get yesterday => 'Yesterday';

  @override
  String get tomorrow => 'Tomorrow';

  @override
  String daysFromNow(int days) {
    return '$days days';
  }

  @override
  String get now => 'Now!';

  @override
  String get currentMoonPhase => 'Current moon phase visualization';

  @override
  String get mapPinLocation => 'Map pin location';

  @override
  String get nearbyTemples => 'Nearby Temples';

  @override
  String get searchHere => 'Search Here';

  @override
  String get loadMore => 'Load More';

  @override
  String get templeMarker => 'Temple marker';

  @override
  String kmAway(String distance) {
    return '$distance km away';
  }

  @override
  String get nearby => 'Nearby';

  @override
  String get getDirections => 'Get Directions';

  @override
  String get couldNotOpenMaps => 'Could not open maps';

  @override
  String errorLaunchingMaps(String error) {
    return 'Error launching maps: $error';
  }

  @override
  String get templeSearchFailed =>
      'Unable to fetch nearby temples. Please try again.';

  @override
  String get yourLocation => 'Your location';

  @override
  String get newIntention => 'New Intention';

  @override
  String get whatIsYourSankalpa => 'What is your Sankalpa?';

  @override
  String get intentionTitle => 'Intention Title';

  @override
  String get intentionTitleHint => 'e.g., Chant Gayatri Mantra 108 times';

  @override
  String get pleaseEnterTitle => 'Please enter a title';

  @override
  String get descriptionOptional => 'Description (Optional)';

  @override
  String get descriptionHint => 'Add specific details or mantra text...';

  @override
  String get durationDays => 'Duration (Days)';

  @override
  String daysCount(int count) {
    return '$count Days';
  }

  @override
  String get custom => 'Custom';

  @override
  String get customDays => 'Custom Days';

  @override
  String get dailyReminderTime => 'Daily Reminder Time';

  @override
  String get createSankalpa => 'Create Sankalpa';

  @override
  String get save => 'Save';

  @override
  String get sankalpaCreatedSuccessfully => 'Sankalpa created successfully!';

  @override
  String failedToSaveSankalpa(String error) {
    return 'Failed to save Sankalpa: $error';
  }

  @override
  String get mySankalpas => 'My Sankalpas';

  @override
  String get active => 'Active';

  @override
  String get completed => 'Completed';

  @override
  String get noCompletedIntentionsYet => 'No completed intentions yet';

  @override
  String get startNewSpiritualJourney => 'Start a new spiritual journey';

  @override
  String get deleteSankalpa => 'Delete Sankalpa?';

  @override
  String get deleteSankalpaMessage => 'This action cannot be undone.';

  @override
  String get delete => 'Delete';

  @override
  String get markCompleteIncomplete => 'Mark Complete/Incomplete';

  @override
  String dayOf(int current, int total) {
    return 'Day $current of $total';
  }

  @override
  String get doneForToday => 'Done for today';

  @override
  String get markTodayAsDone => 'Mark today as done';

  @override
  String reminderAt(String time) {
    return 'Reminder: $time';
  }

  @override
  String completedOn(String date) {
    return 'Completed on $date';
  }

  @override
  String get weatherDetails => 'Weather Details';

  @override
  String get weatherDataUnavailable => 'Weather data unavailable';

  @override
  String errorMessage(String error) {
    return 'Error: $error';
  }

  @override
  String get weatherDataByOpenMeteo => 'Weather data by Open-Meteo';

  @override
  String weatherCondition(String condition) {
    return 'Weather condition: $condition';
  }

  @override
  String get sunrise => 'Sunrise';

  @override
  String get sunset => 'Sunset';

  @override
  String get moonrise => 'Moonrise';

  @override
  String get moonset => 'Moonset';

  @override
  String get humidity => 'Humidity';

  @override
  String get wind => 'Wind';

  @override
  String get realFeel => 'Real Feel';

  @override
  String get uvIndex => 'UV Index';

  @override
  String get forecast => 'Forecast';

  @override
  String daylightDuration(int hours, int minutes) {
    return 'Daylight: ${hours}h ${minutes}m';
  }

  @override
  String get searchFestivals => 'Search Festivals';

  @override
  String get permissionRequired => 'Permission Required';

  @override
  String get locationPermissionPermanentlyDenied =>
      'Location permission was permanently denied. Please enable it in your device settings.';

  @override
  String get openSettings => 'Open Settings';

  @override
  String get selectMonth => 'Select month';

  @override
  String get recenterMap => 'Recenter map';

  @override
  String get zoomIn => 'Zoom in';

  @override
  String get zoomOut => 'Zoom out';

  @override
  String get back30Days => 'Back 30 days';

  @override
  String get back1Day => 'Back 1 day';

  @override
  String get forward1Day => 'Forward 1 day';

  @override
  String get forward30Days => 'Forward 30 days';

  @override
  String get playAnimation => 'Play animation';

  @override
  String get pauseAnimation => 'Pause animation';

  @override
  String get speedLabel => 'Speed';

  @override
  String get heliocentric => 'Heliocentric';

  @override
  String get geocentric => 'Geocentric';

  @override
  String get distance => 'Distance';

  @override
  String get orbit => 'Orbit';

  @override
  String get festivalCountdowns => 'Festival Countdowns';

  @override
  String get addCountdown => 'Add countdown';

  @override
  String get countdownHeading => 'Festival Countdowns';

  @override
  String get zeroDays => '0';

  @override
  String daysRemaining(Object days) {
    return '$days days to go';
  }

  @override
  String get removeFromHomeScreen => 'Remove from home screen';

  @override
  String get removeCountdown => 'Remove countdown';

  @override
  String get countdownRemoved => 'Countdown removed';

  @override
  String get searchFestivalName => 'Search festival name';

  @override
  String get noFestivalsFound => 'No festivals found';

  @override
  String get noCountdownsYet => 'No countdowns yet';

  @override
  String get allFestivals => 'All Festivals';

  @override
  String get searchFestivalsHint => 'Search festivals';

  @override
  String get couldNotLoadFestivals =>
      'Could not load festivals. Please try again.';

  @override
  String get oopsSomethingWentWrong => 'Oops! Something went wrong';

  @override
  String get unexpectedErrorOccurred =>
      'An unexpected error occurred. Please try again.';

  @override
  String get somethingWentWrong => 'Something went wrong';

  @override
  String get unableToOpenPrivacyPolicy =>
      'Unable to open the privacy policy website.';

  @override
  String failedToShare(String error) {
    return 'Failed to share: $error';
  }

  @override
  String celebratingFestivalWithTithi(String festivalName) {
    return 'Celebrating $festivalName with Tithi App!';
  }

  @override
  String get gotIt => 'Got it';

  @override
  String get add => 'Add';

  @override
  String get addWidgetManually => 'Add Widget Manually';

  @override
  String get widgetPinRequested =>
      'Widget pin requested — confirm on home screen';

  @override
  String get couldNotPinWidget =>
      'Could not pin widget. Try adding manually: long-press → Widgets → Tithi';

  @override
  String get infoTooltip => 'Info';

  @override
  String get dismissTooltip => 'Dismiss';

  @override
  String get solarSystemNotAvailableOnWeb =>
      'Solar System is not available on web';

  @override
  String get eclipseScreenNotAvailableOnWeb =>
      'Eclipse screen is not available on web';

  @override
  String get findingNextOccurrence => 'Finding next occurrence...';

  @override
  String get goToNextOccurrence => 'Go to next occurrence';

  @override
  String get couldNotFindUpcomingOccurrence =>
      'Could not find upcoming occurrence within a year.';

  @override
  String get noFestivalsToExport => 'No festivals to export';

  @override
  String exportingYear(String year) {
    return 'Exporting $year';
  }

  @override
  String festivalsExportedProgress(int done, int total) {
    return '$done / $total festivals';
  }

  @override
  String get exportCancelled => 'Export cancelled';

  @override
  String get downloadStarted => 'Download started';

  @override
  String get couldNotSaveExportFile => 'Could not save export file';

  @override
  String get saved => 'Saved';

  @override
  String festivalsExportedForYear(int count, String year) {
    return '$count festivals exported for $year.';
  }

  @override
  String get done => 'Done';

  @override
  String get share => 'Share';

  @override
  String exportFailed(String error) {
    return 'Export failed: $error';
  }

  @override
  String saveFestivalsYear(String year) {
    return 'Save festivals $year';
  }

  @override
  String get aboutBuiltForDailyPractice => 'Built for daily practice';

  @override
  String get aboutDailyPracticeDescription =>
      'Tithi blends traditional Panchang wisdom with modern clarity, so your rituals and observances stay on time and effortless.';

  @override
  String get aboutWhatsInside => 'What\'s inside';

  @override
  String get aboutFeaturesDescription =>
      'Accurate tithi and nakshatra tracking, festival countdowns, local sunrise and sunset, and calm daily inspiration.';

  @override
  String get detailedPrivacyPolicy => 'Detailed privacy policy';

  @override
  String get readFullPrivacyPolicy => 'Read the full policy on our website';

  @override
  String get aboutTagline => 'Vedic calendar for modern life';

  @override
  String get themePurple => 'Purple';

  @override
  String get notificationPermissionDenied =>
      'Notification permission denied. Please enable it in system settings.';

  @override
  String notificationToggleFailed(String state, String error) {
    String _temp0 = intl.Intl.selectLogic(state, {'on': 'on', 'other': 'off'});
    return 'Could not turn notifications $_temp0 ($error). Please try again.';
  }

  @override
  String get dailyShloka => 'Daily Shloka';

  @override
  String get dailyShlokaSubtitle => 'Get a daily spiritual verse';

  @override
  String dailyShlokaToggleFailed(String state, String error) {
    String _temp0 = intl.Intl.selectLogic(state, {'on': 'on', 'other': 'off'});
    return 'Could not turn Daily Shloka $_temp0 ($error). Please try again.';
  }

  @override
  String get festivalReminders => 'Festival Reminders';

  @override
  String get festivalRemindersSubtitle =>
      'Notify only for festivals, on the day or before';

  @override
  String festivalRemindersToggleFailed(String state, String error) {
    String _temp0 = intl.Intl.selectLogic(state, {'on': 'on', 'other': 'off'});
    return 'Could not turn Festival Reminders $_temp0 ($error). Please try again.';
  }

  @override
  String get festivalReminderTime => 'Festival Reminder Time';

  @override
  String notificationTimeUpdateFailed(String error) {
    return 'Could not update notification time ($error). Please try again.';
  }

  @override
  String get festivalReminderDayBefore => 'Day before';

  @override
  String get festivalReminderBoth => 'Both';

  @override
  String get festivalReminderOnDay => 'On the day';

  @override
  String reminderTimeUpdateFailed(String error) {
    return 'Could not update reminder time ($error). Please try again.';
  }

  @override
  String get hinduMonthSystem => 'Hindu Month System';

  @override
  String get hinduMonthSystemSubtitle =>
      'Choose how months are named during Krishna Paksha';

  @override
  String get hinduYearEra => 'Hindu Year Era';

  @override
  String get hinduYearEraSubtitle => 'Choose the calendar era for year display';

  @override
  String get tithiDisplay => 'Tithi Display';

  @override
  String get tithiDisplayPakshaRange => 'Paksha (1-15)';

  @override
  String get tithiDisplaySubtitle =>
      'Choose how tithis are numbered in the calendar';

  @override
  String get tithiDisplayPakshaBased => 'Paksha Based';

  @override
  String get tithiDisplayPakshaDescription =>
      'Show 1-15 for each paksha separately';

  @override
  String get tithiDisplayContinuousDescription => 'Show 1-30 continuously';

  @override
  String festivalExportShareSubject(String year) {
    return 'Tithi festivals $year';
  }

  @override
  String festivalExportShareText(String year) {
    return 'Tithi festivals $year with Panchang details (JSON)';
  }

  @override
  String countdownAddedForFestival(String festivalName) {
    return 'Countdown added for $festivalName';
  }

  @override
  String festivalAlreadyInCountdowns(String festivalName) {
    return '$festivalName is already in your countdowns';
  }

  @override
  String get openStreetMapAttribution => 'OpenStreetMap contributors';

  @override
  String get moonScrubHint => 'Drag to explore • Double-tap resets';

  @override
  String moonIllumination(String percentage) {
    return 'Illumination: $percentage%';
  }

  @override
  String get dayUnitShort => 'd';

  @override
  String get hourUnitShort => 'h';

  @override
  String get minuteUnitShort => 'm';

  @override
  String durationHoursMinutesShort(int hours, int minutes) {
    return '${hours}h ${minutes}m';
  }

  @override
  String durationMinutesShort(int minutes) {
    return '${minutes}m';
  }

  @override
  String distanceAstronomicalUnits(String distance) {
    return '$distance AU';
  }

  @override
  String orbitalPeriodDaysShort(String days) {
    return '${days}d';
  }

  @override
  String orbitalPeriodYearsShort(String years) {
    return '${years}y';
  }

  @override
  String get vikramSamvat => 'Vikram Samvat';

  @override
  String get shakaEra => 'Shaka Era';

  @override
  String get bengaliEra => 'Bengali Era';

  @override
  String get selectYear => 'Select year';

  @override
  String bengaliEraYear(int year) {
    return '$year Bangabda';
  }

  @override
  String get monthJanuary => 'January';

  @override
  String get monthFebruary => 'February';

  @override
  String get monthMarch => 'March';

  @override
  String get monthApril => 'April';

  @override
  String get monthMay => 'May';

  @override
  String get monthJune => 'June';

  @override
  String get monthJuly => 'July';

  @override
  String get monthAugust => 'August';

  @override
  String get monthSeptember => 'September';

  @override
  String get monthOctober => 'October';

  @override
  String get monthNovember => 'November';

  @override
  String get monthDecember => 'December';

  @override
  String get weekdaySundayShort => 'SUN';

  @override
  String get weekdayMondayShort => 'MON';

  @override
  String get weekdayTuesdayShort => 'TUE';

  @override
  String get weekdayWednesdayShort => 'WED';

  @override
  String get weekdayThursdayShort => 'THU';

  @override
  String get weekdayFridayShort => 'FRI';

  @override
  String get weekdaySaturdayShort => 'SAT';

  @override
  String get sharedViaTithiApp => 'Shared via Tithi App';

  @override
  String get dailyWisdomShareMessage => 'Daily Wisdom — Tithi App';

  @override
  String get shareAsImage => 'Share as image';

  @override
  String get verseCardPicture => 'Verse card picture';

  @override
  String get shareAsText => 'Share as text';

  @override
  String get verseWithTranslation => 'Verse with translation';

  @override
  String get copyText => 'Copy text';

  @override
  String get copyVerseToClipboard => 'Copy verse to clipboard';

  @override
  String get couldNotCopyVerse => 'Could not copy verse';

  @override
  String get verseCopied => 'Verse copied';

  @override
  String chosenForFestival(String festivalName) {
    return 'Chosen for $festivalName';
  }

  @override
  String get showLess => 'Show less';

  @override
  String get showMoreTranslations => 'Show more translations';

  @override
  String get hideTranslation => 'Hide translation';

  @override
  String get showTranslation => 'Show translation';

  @override
  String get showLessTitleCase => 'Show Less';

  @override
  String get readMore => 'Read More';

  @override
  String tithiNameWithNumber(String tithiName, int number) {
    return '$tithiName (T$number)';
  }

  @override
  String get masa => 'Masa';

  @override
  String get nakshatra => 'Nakshatra';

  @override
  String get begins => 'Begins';

  @override
  String get ends => 'Ends';

  @override
  String tithiWithNumber(int number) {
    return 'Tithi $number';
  }

  @override
  String get fastingVrat => 'Fasting / Vrat';

  @override
  String get mantra => 'Mantra';

  @override
  String get timingNote => 'Timing Note';

  @override
  String get timingNoteDescription =>
      'Timings are calculated astronomically based on coordinates and may vary by a few minutes from local temple calendars due to atmospheric refraction, elevation, or calculation methods.';

  @override
  String get noFestivalsInNextThreeDays => 'No festivals in the next 3 days';

  @override
  String couldNotLoadFestivalsWithError(String error) {
    return 'Could not load festivals: $error';
  }

  @override
  String viewAllFestivalsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'View all $count festivals',
      one: 'View all $count festival',
    );
    return '$_temp0';
  }

  @override
  String get viewAllFestivals => 'View all festivals';

  @override
  String get day => 'day';

  @override
  String festivalCountdownTitle(String title) {
    return '$title Countdown';
  }

  @override
  String festivalInDays(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'in $days days',
      one: 'in 1 day',
    );
    return '$_temp0';
  }

  @override
  String get searchFestivalsVratsAndEvents =>
      'Search for festivals, vrats, and events';

  @override
  String get homeScreenWidget => 'Home Screen Widget';

  @override
  String get homeWidgetCountdownDescription =>
      'Add festival countdowns to your home screen';

  @override
  String get homeWidgetManualHint => 'Long-press home screen → Widgets → Tithi';

  @override
  String get homeWidgetManualInstructions =>
      '1. Long-press on your home screen\n2. Tap \"Widgets\"\n3. Find \"Tithi\" and drag \"Festival Countdowns\" to your home screen\n\nThe widget shows all festivals from your Countdowns page.';

  @override
  String get unableToLoadMoonPhaseData => 'Unable to load moon phase data';

  @override
  String get countdownNow => 'Now';

  @override
  String countdownDaysHours(int days, int hours) {
    return '${days}d ${hours}h';
  }

  @override
  String get selected => 'Selected';

  @override
  String moonPhaseIlluminated(String phase, String percentage) {
    return '$phase · $percentage% illuminated';
  }

  @override
  String nextTithiAt(String tithiName, String time) {
    return 'Next tithi $tithiName at $time';
  }

  @override
  String tithiBeginsAt(String tithiName, String time) {
    return '$tithiName begins at $time';
  }

  @override
  String tithiEndsAtDateTime(String tithiName, String dateTime) {
    return '$tithiName ends $dateTime';
  }

  @override
  String get udayaTithiExplanation =>
      'Udaya tithi: the tithi prevailing at sunrise. A short tithi can begin and end between two sunrises — both tithis are shown above so none is skipped.';

  @override
  String get beginsUppercase => 'BEGINS';

  @override
  String get endsUppercase => 'ENDS';

  @override
  String get transition => 'TRANSITION';

  @override
  String get observanceRuleUdaya => 'the tithi prevailing at sunrise';

  @override
  String get observanceRuleMadhyahna =>
      'the tithi prevailing at Madhyahna (midday)';

  @override
  String get observanceRuleAparahna =>
      'the tithi prevailing at Aparahna (afternoon)';

  @override
  String get observanceRuleNishita =>
      'the tithi prevailing at Nishita (midnight)';

  @override
  String get observanceRulePradosha =>
      'the tithi prevailing at Pradosha (dusk)';

  @override
  String get observanceRuleMoonrise => 'the tithi prevailing at moonrise';

  @override
  String observedOnTheDay(String rule) {
    return 'Observed on the day $rule';
  }

  @override
  String get pujaSamay => 'Puja Samay';

  @override
  String get sandhiJunction => 'Sandhi';

  @override
  String get pujaWindow => 'PUJA WINDOW';

  @override
  String pujaWindowDuration(int count, String kala) {
    return '$count ghatikas around $kala';
  }

  @override
  String get paranLabel => 'Paran (breaking the fast):';

  @override
  String get paranReasonMoonrise => 'after moonrise';

  @override
  String get paranReasonSunrise => 'after sunrise';

  @override
  String paranReasonPujaKala(String kala) {
    return 'after the $kala puja';
  }

  @override
  String get paranReasonDwadashi => 'in the Dwadashi window';

  @override
  String get shuklaPakshaInitial => 'S';

  @override
  String get krishnaPakshaInitial => 'K';

  @override
  String windSpeedKph(double speed) {
    return '$speed kph';
  }

  @override
  String get tithiDisplayThirtyDays => '30 Days';

  @override
  String get couldNotCreateImage => 'Could not create image';

  @override
  String get shareVerse => 'Share verse';

  @override
  String get previousDaysVerse => 'Previous day\'s verse';

  @override
  String get nextDaysVerse => 'Next day\'s verse';

  @override
  String get shareCard => 'Share Card';

  @override
  String get homeWidgetCanPin => 'Add festival countdowns to your home screen';

  @override
  String get dailyWisdom => 'DAILY WISDOM';

  @override
  String get tithiTimings => 'TITHI TIMINGS';

  @override
  String get tithiBegins => 'BEGINS';

  @override
  String get tithiEnds => 'ENDS';

  @override
  String get tithiTransition => 'TRANSITION';

  @override
  String get udayaTithiExplainer =>
      'Udaya tithi: the tithi prevailing at sunrise. A short tithi can begin and end between two sunrises — both tithis are shown above so none is skipped.';

  @override
  String get nakshatraTimings => 'NAKSHATRA';

  @override
  String nakshatraUntil(String nakshatra, String time) {
    return '$nakshatra until $time';
  }

  @override
  String nakshatraLord(String lord) {
    return 'Lord: $lord';
  }

  @override
  String nakshatraElapsed(String percent) {
    return '$percent% elapsed';
  }

  @override
  String nakshatraNext(String nakshatra, String time) {
    return 'Next: $nakshatra at $time';
  }

  @override
  String get lordKetu => 'Ketu';

  @override
  String get lordVenus => 'Venus';

  @override
  String get lordSun => 'Sun';

  @override
  String get lordMoon => 'Moon';

  @override
  String get lordMars => 'Mars';

  @override
  String get lordRahu => 'Rahu';

  @override
  String get lordJupiter => 'Jupiter';

  @override
  String get lordSaturn => 'Saturn';

  @override
  String get lordMercury => 'Mercury';

  @override
  String get yogaKaranaTimings => 'YOGA & KARANA';

  @override
  String get yogaLabel => 'YOGA';

  @override
  String get karanaLabel => 'KARANA';

  @override
  String untilThen(String time, String next) {
    return 'until $time, then $next';
  }

  @override
  String get inauspiciousTimings => 'INAUSPICIOUS TIMINGS';

  @override
  String get rahuKalam => 'Rahu Kalam';

  @override
  String get yamaganda => 'Yamaganda';

  @override
  String get gulikaKalam => 'Gulika Kalam';

  @override
  String get auspiciousTimings => 'AUSPICIOUS TIMINGS';

  @override
  String get abhijit => 'Abhijit';

  @override
  String get brahmaMuhurta => 'Brahma Muhurta';

  @override
  String get madhyahna => 'Madhyahna';

  @override
  String get nishita => 'Nishita';

  @override
  String get godhuli => 'Godhuli';

  @override
  String get pradosha => 'Pradosha';

  @override
  String get abhijitAvoided => 'Avoided on Wednesday';

  @override
  String get abhijitAuspicious => 'Especially auspicious today';

  @override
  String midpointAt(String time) {
    return 'midpoint $time';
  }

  @override
  String get checkForUpdates => 'Check for updates';

  @override
  String get checkingForUpdates => 'Checking for updates…';

  @override
  String get appUpToDate => 'You\'re up to date';

  @override
  String get updateAvailable => 'Update available';

  @override
  String updateAvailableVersion(String version) {
    return 'Version $version is available';
  }

  @override
  String get youHaveLatestVersion => 'You have the latest version';

  @override
  String get noReleasesPublished => 'No releases published yet';

  @override
  String get downloadUpdate => 'Download update';

  @override
  String get downloadingUpdate => 'Downloading update…';

  @override
  String downloadProgressPercent(String percent) {
    return '$percent% downloaded';
  }

  @override
  String get installUpdate => 'Install update';

  @override
  String get installingUpdate => 'Opening installer…';

  @override
  String get updateDownloaded => 'Update downloaded';

  @override
  String get updateCheckFailed => 'Couldn\'t check for updates';

  @override
  String get viewReleasesOnGitHub => 'View releases on GitHub';

  @override
  String get releaseNotes => 'What\'s new';

  @override
  String get allowInstallPermissionNote =>
      'Allow installs from Tithi in system settings, then tap Install again.';
}
