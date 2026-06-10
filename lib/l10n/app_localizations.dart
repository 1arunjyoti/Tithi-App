import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_bn.dart';
import 'app_localizations_en.dart';
import 'app_localizations_hi.dart';
import 'app_localizations_sa.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('bn'),
    Locale('en'),
    Locale('hi'),
    Locale('sa'),
  ];

  /// The name of the application
  ///
  /// In en, this message translates to:
  /// **'Tithi'**
  String get appTitle;

  /// Subtitle describing the app as a Vedic Calendar
  ///
  /// In en, this message translates to:
  /// **'Vedic Calendar'**
  String get vedaCalendar;

  /// Settings screen title and menu item
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// Section header for appearance/theme settings
  ///
  /// In en, this message translates to:
  /// **'APPEARANCE'**
  String get appearance;

  /// Section header for user preferences
  ///
  /// In en, this message translates to:
  /// **'PREFERENCES'**
  String get preferences;

  /// Section header for calendar settings
  ///
  /// In en, this message translates to:
  /// **'CALENDAR'**
  String get calendar;

  /// Section header for data and storage settings
  ///
  /// In en, this message translates to:
  /// **'DATA & STORAGE'**
  String get dataStorage;

  /// Section header for accessibility options
  ///
  /// In en, this message translates to:
  /// **'ACCESSIBILITY'**
  String get accessibility;

  /// Section header for about information
  ///
  /// In en, this message translates to:
  /// **'ABOUT'**
  String get about;

  /// Auto theme option - follows system/paksha
  ///
  /// In en, this message translates to:
  /// **'Auto'**
  String get themeAuto;

  /// Shukla (light/waxing moon) theme option
  ///
  /// In en, this message translates to:
  /// **'Shukla'**
  String get themeShukla;

  /// Pure dark/AMOLED theme option
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get themeDark;

  /// Krishna (dark/waning moon) theme option
  ///
  /// In en, this message translates to:
  /// **'Krishna'**
  String get themeKrishna;

  /// Setting title for daily notification toggle
  ///
  /// In en, this message translates to:
  /// **'Daily Notifications'**
  String get dailyNotifications;

  /// Subtitle when notifications are enabled
  ///
  /// In en, this message translates to:
  /// **'Scheduled daily'**
  String get notificationScheduled;

  /// Subtitle when notifications are disabled
  ///
  /// In en, this message translates to:
  /// **'Get notified about Tithi daily'**
  String get getNotifiedTithiDaily;

  /// Setting to choose notification time
  ///
  /// In en, this message translates to:
  /// **'Notification Time'**
  String get notificationTime;

  /// Setting title for automatic GPS location
  ///
  /// In en, this message translates to:
  /// **'Auto Location'**
  String get autoLocation;

  /// Subtitle explaining auto location purpose
  ///
  /// In en, this message translates to:
  /// **'Use GPS for precise Tithi calculation'**
  String get useGpsForTithi;

  /// Shows current location being used
  ///
  /// In en, this message translates to:
  /// **'Using: {cityName}'**
  String usingLocation(String cityName);

  /// Loading state while getting location
  ///
  /// In en, this message translates to:
  /// **'Fetching location...'**
  String get fetchingLocation;

  /// Error state when location cannot be determined
  ///
  /// In en, this message translates to:
  /// **'Location unavailable'**
  String get locationUnavailable;

  /// Setting title for home location picker
  ///
  /// In en, this message translates to:
  /// **'Home Location'**
  String get homeLocation;

  /// Placeholder when home location is not configured
  ///
  /// In en, this message translates to:
  /// **'Not set'**
  String get notSet;

  /// Screen title for location picker
  ///
  /// In en, this message translates to:
  /// **'Set Home Location'**
  String get setHomeLocation;

  /// Instruction on location picker screen
  ///
  /// In en, this message translates to:
  /// **'Drag map to position pin at your home'**
  String get dragMapToPin;

  /// Button to confirm selected location
  ///
  /// In en, this message translates to:
  /// **'Set This Location'**
  String get setThisLocation;

  /// Confirmation message after setting home location
  ///
  /// In en, this message translates to:
  /// **'Home location set to {address}'**
  String homeLocationSetTo(String address);

  /// Error message when location setting fails
  ///
  /// In en, this message translates to:
  /// **'Error setting location: {error}'**
  String errorSettingLocation(String error);

  /// Setting to choose first day of week
  ///
  /// In en, this message translates to:
  /// **'Start of Week'**
  String get startOfWeek;

  /// Sunday day name
  ///
  /// In en, this message translates to:
  /// **'Sunday'**
  String get sunday;

  /// Monday day name
  ///
  /// In en, this message translates to:
  /// **'Monday'**
  String get monday;

  /// Setting to choose primary calendar view type
  ///
  /// In en, this message translates to:
  /// **'Primary View'**
  String get primaryView;

  /// Tithi view option - shows lunar day
  ///
  /// In en, this message translates to:
  /// **'Tithi'**
  String get tithi;

  /// Festival view option - shows festivals
  ///
  /// In en, this message translates to:
  /// **'Festival'**
  String get festival;

  /// Moon view option - shows moon phase
  ///
  /// In en, this message translates to:
  /// **'Moon'**
  String get moon;

  /// Setting to choose primary calendar system
  ///
  /// In en, this message translates to:
  /// **'Primary Calendar'**
  String get primaryCalendar;

  /// Setting to choose secondary calendar system
  ///
  /// In en, this message translates to:
  /// **'Secondary Calendar'**
  String get secondaryCalendar;

  /// Title for primary calendar picker dialog
  ///
  /// In en, this message translates to:
  /// **'Select Primary Calendar'**
  String get selectPrimaryCalendar;

  /// Title for secondary calendar picker dialog
  ///
  /// In en, this message translates to:
  /// **'Select Secondary Calendar'**
  String get selectSecondaryCalendar;

  /// Action to clear cached location data
  ///
  /// In en, this message translates to:
  /// **'Clear Location Cache'**
  String get clearLocationCache;

  /// Confirmation after clearing location cache
  ///
  /// In en, this message translates to:
  /// **'Location cache cleared'**
  String get locationCacheCleared;

  /// Action to reset all app settings
  ///
  /// In en, this message translates to:
  /// **'Reset App Settings'**
  String get resetAppSettings;

  /// Confirmation dialog title for reset
  ///
  /// In en, this message translates to:
  /// **'Reset Settings?'**
  String get resetSettingsTitle;

  /// Confirmation dialog message explaining reset consequences
  ///
  /// In en, this message translates to:
  /// **'This will reset all your preferences and data to default. This cannot be undone.'**
  String get resetSettingsMessage;

  /// Cancel button text
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// Reset/confirm button text
  ///
  /// In en, this message translates to:
  /// **'Reset'**
  String get reset;

  /// Confirmation after app reset
  ///
  /// In en, this message translates to:
  /// **'App reset complete'**
  String get appResetComplete;

  /// Accessibility setting to reduce animations
  ///
  /// In en, this message translates to:
  /// **'Reduce Motion'**
  String get reduceMotion;

  /// Subtitle for reduce motion setting
  ///
  /// In en, this message translates to:
  /// **'Disable animations & effects'**
  String get disableAnimations;

  /// Setting to enable/disable vibration feedback
  ///
  /// In en, this message translates to:
  /// **'Haptic Feedback'**
  String get hapticFeedback;

  /// Subtitle for haptic feedback setting
  ///
  /// In en, this message translates to:
  /// **'Vibrate on touch interactions'**
  String get vibrateOnTouch;

  /// Accessibility setting for high contrast mode
  ///
  /// In en, this message translates to:
  /// **'High Contrast'**
  String get highContrast;

  /// Subtitle for high contrast setting
  ///
  /// In en, this message translates to:
  /// **'Solid backgrounds for better readability'**
  String get solidBackgrounds;

  /// Accessibility setting for larger text
  ///
  /// In en, this message translates to:
  /// **'Large Text'**
  String get largeText;

  /// Subtitle for large text setting
  ///
  /// In en, this message translates to:
  /// **'Increase text size globally'**
  String get increaseTextSize;

  /// Setting title for language selection
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// Title for language picker dialog
  ///
  /// In en, this message translates to:
  /// **'Select Language'**
  String get selectLanguage;

  /// Option to use system language setting
  ///
  /// In en, this message translates to:
  /// **'System Default'**
  String get systemDefault;

  /// Link to privacy policy screen
  ///
  /// In en, this message translates to:
  /// **'Privacy Policy'**
  String get privacyPolicy;

  /// Footer text showing app dedication
  ///
  /// In en, this message translates to:
  /// **'Made with ❤️ for Sanatan Dharma'**
  String get madeWithLove;

  /// Menu item to share the app
  ///
  /// In en, this message translates to:
  /// **'Share App'**
  String get shareApp;

  /// Text shared when user shares the app
  ///
  /// In en, this message translates to:
  /// **'Check out Tithi - The Vedic Calendar App! Download now: https://tithiapp.netlify.app/'**
  String get shareAppMessage;

  /// Menu item to rate the app
  ///
  /// In en, this message translates to:
  /// **'Rate Us'**
  String get rateUs;

  /// Menu item for about dialog
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get aboutApp;

  /// Option to switch to calendar/month view
  ///
  /// In en, this message translates to:
  /// **'Calendar View'**
  String get calendarView;

  /// Option to switch to schedule/list view
  ///
  /// In en, this message translates to:
  /// **'Schedule View'**
  String get scheduleView;

  /// Subtitle when in schedule view
  ///
  /// In en, this message translates to:
  /// **'Switch to month calendar'**
  String get switchToCalendar;

  /// Subtitle when in calendar view
  ///
  /// In en, this message translates to:
  /// **'Switch to event list'**
  String get switchToSchedule;

  /// App version display text
  ///
  /// In en, this message translates to:
  /// **'Version {version}'**
  String versionText(String version);

  /// Section header for events list
  ///
  /// In en, this message translates to:
  /// **'EVENTS'**
  String get events;

  /// Title for festivals section
  ///
  /// In en, this message translates to:
  /// **'Festivals & Events'**
  String get festivalsAndEvents;

  /// Empty state when no festivals
  ///
  /// In en, this message translates to:
  /// **'No festivals on this day'**
  String get noFestivalsOnThisDay;

  /// Label for today's main festival
  ///
  /// In en, this message translates to:
  /// **'Today\'s Festival'**
  String get todaysFestival;

  /// Subtitle when no festivals today
  ///
  /// In en, this message translates to:
  /// **'Tithi • No Festivals Today'**
  String get noFestivalsToday;

  /// Error message when panchang data fails to load
  ///
  /// In en, this message translates to:
  /// **'Error loading panchang: {error}'**
  String errorLoadingPanchang(String error);

  /// Section title for panchang information
  ///
  /// In en, this message translates to:
  /// **'Panchang Details'**
  String get panchangDetails;

  /// Label for lunar fortnight
  ///
  /// In en, this message translates to:
  /// **'Paksha'**
  String get paksha;

  /// Paksha display with name
  ///
  /// In en, this message translates to:
  /// **'{paksha} Paksha'**
  String pakshaWithName(String paksha);

  /// Waxing moon phase (Shukla paksha)
  ///
  /// In en, this message translates to:
  /// **'Waxing'**
  String get waxing;

  /// Waning moon phase (Krishna paksha)
  ///
  /// In en, this message translates to:
  /// **'Waning'**
  String get waning;

  /// Description for Shukla paksha
  ///
  /// In en, this message translates to:
  /// **'Waxing Moon Phase'**
  String get waxingMoonPhase;

  /// Description for Krishna paksha
  ///
  /// In en, this message translates to:
  /// **'Waning Moon Phase'**
  String get waningMoonPhase;

  /// Label for festival category
  ///
  /// In en, this message translates to:
  /// **'Category'**
  String get category;

  /// Default category name
  ///
  /// In en, this message translates to:
  /// **'General'**
  String get general;

  /// Section title for ritual checklist
  ///
  /// In en, this message translates to:
  /// **'Rituals & Practices'**
  String get ritualsAndPractices;

  /// Title for location permission dialog
  ///
  /// In en, this message translates to:
  /// **'Location Access'**
  String get locationAccess;

  /// Button to enable location access
  ///
  /// In en, this message translates to:
  /// **'Enable Location'**
  String get enableLocation;

  /// Button to skip/dismiss
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get skip;

  /// Explanation of why location is needed
  ///
  /// In en, this message translates to:
  /// **'Tithi uses your location to calculate accurate Panchang data for your city.'**
  String get locationAccessDescription;

  /// Benefits of enabling location
  ///
  /// In en, this message translates to:
  /// **'• More accurate tithi calculations\n• Location-specific moonrise/sunset times\n• Your location data stays on your device'**
  String get locationAccessBenefits;

  /// Title when location is off
  ///
  /// In en, this message translates to:
  /// **'Location Disabled'**
  String get locationDisabled;

  /// Message explaining location is disabled
  ///
  /// In en, this message translates to:
  /// **'Location is disabled. Enable it for more accurate Panchang calculations based on your city.'**
  String get locationDisabledMessage;

  /// Button to dismiss temporarily
  ///
  /// In en, this message translates to:
  /// **'Not Now'**
  String get notNow;

  /// Button to enable feature
  ///
  /// In en, this message translates to:
  /// **'Enable'**
  String get enable;

  /// Message when device location is off
  ///
  /// In en, this message translates to:
  /// **'Please enable location services on your device'**
  String get pleaseEnableLocationServices;

  /// Message when user denies location permission
  ///
  /// In en, this message translates to:
  /// **'Location permission denied. Using default location.'**
  String get locationPermissionDenied;

  /// Success message after enabling location
  ///
  /// In en, this message translates to:
  /// **'Location enabled successfully!'**
  String get locationEnabledSuccess;

  /// Tooltip for refresh location button
  ///
  /// In en, this message translates to:
  /// **'Refresh Location'**
  String get refreshLocation;

  /// Tooltip for go to today button
  ///
  /// In en, this message translates to:
  /// **'Go to Today'**
  String get goToToday;

  /// Loading state during app startup
  ///
  /// In en, this message translates to:
  /// **'Initializing...'**
  String get initializing;

  /// Privacy policy section title
  ///
  /// In en, this message translates to:
  /// **'Your Data Stays With You'**
  String get privacyYourDataStays;

  /// Privacy policy - data stays local explanation
  ///
  /// In en, this message translates to:
  /// **'Tithi is designed with a privacy-first, offline-first architecture. All astronomical calculations, calendar generation, event processing happen directly on your device and the app keeps working without a network. We do not collect, store, or transmit your personal data to any external servers.'**
  String get privacyYourDataDesc;

  /// Privacy policy section title
  ///
  /// In en, this message translates to:
  /// **'Location Usage'**
  String get privacyLocationUsage;

  /// Privacy policy - location usage explanation
  ///
  /// In en, this message translates to:
  /// **'We request access to your location solely to calculate accurate Tithi, Nakshatra, and sunrise/sunset timings, which depend on your specific geographic coordinates. Your location data is processed locally by the app and is never shared with third parties or stored on our servers.'**
  String get privacyLocationDesc;

  /// Privacy policy section title
  ///
  /// In en, this message translates to:
  /// **'Offline Functionality'**
  String get privacyOffline;

  /// Privacy policy - offline functionality explanation
  ///
  /// In en, this message translates to:
  /// **'The app works completely offline. It contains the Swiss Ephemeris data required for high-precision planetary calculations embedded within the app itself.'**
  String get privacyOfflineDesc;

  /// Privacy policy section title
  ///
  /// In en, this message translates to:
  /// **'Open Source Transparency'**
  String get privacyOpenSource;

  /// Privacy policy - open source explanation
  ///
  /// In en, this message translates to:
  /// **'Tithi is an open-source project. Our code is publicly available for audit, ensuring that our privacy promises are backed by verifiable transparency. What you see is exactly what you get.'**
  String get privacyOpenSourceDesc;

  /// Privacy policy last updated date
  ///
  /// In en, this message translates to:
  /// **'Last Updated: December 2025'**
  String get lastUpdated;

  /// Legal text shown in about dialog
  ///
  /// In en, this message translates to:
  /// **'© 2025 Tithi Project\nMade with ❤️ for Sanatan Dharma'**
  String get applicationLegalese;

  /// Title for moon phases screen
  ///
  /// In en, this message translates to:
  /// **'Moon Phases'**
  String get moonPhases;

  /// Label for next full moon date
  ///
  /// In en, this message translates to:
  /// **'Next Purnima'**
  String get nextPurnima;

  /// Label for next new moon date
  ///
  /// In en, this message translates to:
  /// **'Next Amavasya'**
  String get nextAmavasya;

  /// Full moon term
  ///
  /// In en, this message translates to:
  /// **'Purnima'**
  String get purnima;

  /// New moon term
  ///
  /// In en, this message translates to:
  /// **'Amavasya'**
  String get amavasya;

  /// Description for Purnima
  ///
  /// In en, this message translates to:
  /// **'Full Moon'**
  String get fullMoon;

  /// Description for Amavasya
  ///
  /// In en, this message translates to:
  /// **'New Moon'**
  String get newMoon;

  /// Empty state for upcoming moon phase dates
  ///
  /// In en, this message translates to:
  /// **'No upcoming dates found'**
  String get noUpcomingDates;

  /// Generic error message for data loading
  ///
  /// In en, this message translates to:
  /// **'Error loading data'**
  String get errorLoadingData;

  /// Button to retry failed action
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// Section header for astronomy features in drawer
  ///
  /// In en, this message translates to:
  /// **'Astronomy'**
  String get astronomy;

  /// Title for solar system screen
  ///
  /// In en, this message translates to:
  /// **'Solar System'**
  String get solarSystem;

  /// Title for planet positions feature
  ///
  /// In en, this message translates to:
  /// **'Planet Positions'**
  String get planetPositions;

  /// Tooltip for date picker
  ///
  /// In en, this message translates to:
  /// **'Select Date'**
  String get selectDate;

  /// Indicator for retrograde motion
  ///
  /// In en, this message translates to:
  /// **'Retrograde'**
  String get retrograde;

  /// Label for zodiac sign
  ///
  /// In en, this message translates to:
  /// **'Sign'**
  String get zodiacSign;

  /// Label for degree position
  ///
  /// In en, this message translates to:
  /// **'Degree'**
  String get degree;

  /// Label for ecliptic longitude
  ///
  /// In en, this message translates to:
  /// **'Longitude'**
  String get longitude;

  /// Title for eclipses screen
  ///
  /// In en, this message translates to:
  /// **'Eclipses'**
  String get eclipses;

  /// Section header for solar eclipses
  ///
  /// In en, this message translates to:
  /// **'Solar Eclipses'**
  String get solarEclipses;

  /// Section header for lunar eclipses
  ///
  /// In en, this message translates to:
  /// **'Lunar Eclipses'**
  String get lunarEclipses;

  /// Label for maximum eclipse time
  ///
  /// In en, this message translates to:
  /// **'Maximum Eclipse'**
  String get maxEclipse;

  /// Indicates eclipse is visible locally
  ///
  /// In en, this message translates to:
  /// **'Visible from your location'**
  String get visibleFromYourLocation;

  /// Indicates eclipse is not visible locally
  ///
  /// In en, this message translates to:
  /// **'Not visible from your location'**
  String get notVisibleFromYourLocation;

  /// When partial phase starts
  ///
  /// In en, this message translates to:
  /// **'Partial phase begins'**
  String get partialBegins;

  /// When partial phase ends
  ///
  /// In en, this message translates to:
  /// **'Partial phase ends'**
  String get partialEnds;

  /// When totality starts
  ///
  /// In en, this message translates to:
  /// **'Totality begins'**
  String get totalityBegins;

  /// When totality ends
  ///
  /// In en, this message translates to:
  /// **'Totality ends'**
  String get totalityEnds;

  /// Label for duration
  ///
  /// In en, this message translates to:
  /// **'Duration'**
  String get duration;

  /// Label for date
  ///
  /// In en, this message translates to:
  /// **'Date'**
  String get date;

  /// Plural form of day
  ///
  /// In en, this message translates to:
  /// **'days'**
  String get days;

  /// Label for today
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get today;

  /// Label for tomorrow
  ///
  /// In en, this message translates to:
  /// **'Tomorrow'**
  String get tomorrow;

  /// Number of days until an event
  ///
  /// In en, this message translates to:
  /// **'{days} days'**
  String daysFromNow(int days);

  /// Label used when countdown has reached the target time
  ///
  /// In en, this message translates to:
  /// **'Now!'**
  String get now;

  /// Accessibility label for custom moon phase paint widget
  ///
  /// In en, this message translates to:
  /// **'Current moon phase visualization'**
  String get currentMoonPhase;

  /// Accessibility label for center map pin
  ///
  /// In en, this message translates to:
  /// **'Map pin location'**
  String get mapPinLocation;

  /// Temple map screen title
  ///
  /// In en, this message translates to:
  /// **'Nearby Temples'**
  String get nearbyTemples;

  /// Button label to search nearby temples around current map center
  ///
  /// In en, this message translates to:
  /// **'Search Here'**
  String get searchHere;

  /// Button label to load next page of nearby temples
  ///
  /// In en, this message translates to:
  /// **'Load More'**
  String get loadMore;

  /// Accessibility prefix for temple map markers
  ///
  /// In en, this message translates to:
  /// **'Temple marker'**
  String get templeMarker;

  /// Distance text for temple details
  ///
  /// In en, this message translates to:
  /// **'{distance} km away'**
  String kmAway(String distance);

  /// Short text when exact temple distance is unavailable
  ///
  /// In en, this message translates to:
  /// **'Nearby'**
  String get nearby;

  /// Button label to open maps for directions
  ///
  /// In en, this message translates to:
  /// **'Get Directions'**
  String get getDirections;

  /// Error message when map app cannot be opened
  ///
  /// In en, this message translates to:
  /// **'Could not open maps'**
  String get couldNotOpenMaps;

  /// Error message when launching map app fails
  ///
  /// In en, this message translates to:
  /// **'Error launching maps: {error}'**
  String errorLaunchingMaps(String error);

  /// Error message when nearby temple fetch fails
  ///
  /// In en, this message translates to:
  /// **'Unable to fetch nearby temples. Please try again.'**
  String get templeSearchFailed;

  /// Accessibility label for user's location marker
  ///
  /// In en, this message translates to:
  /// **'Your location'**
  String get yourLocation;

  /// Title and button text for creating a new sankalpa
  ///
  /// In en, this message translates to:
  /// **'New Intention'**
  String get newIntention;

  /// Prompt text on sankalpa create screen
  ///
  /// In en, this message translates to:
  /// **'What is your Sankalpa?'**
  String get whatIsYourSankalpa;

  /// Label for sankalpa title input
  ///
  /// In en, this message translates to:
  /// **'Intention Title'**
  String get intentionTitle;

  /// Hint text for sankalpa title field
  ///
  /// In en, this message translates to:
  /// **'e.g., Chant Gayatri Mantra 108 times'**
  String get intentionTitleHint;

  /// Validation error for empty sankalpa title
  ///
  /// In en, this message translates to:
  /// **'Please enter a title'**
  String get pleaseEnterTitle;

  /// Label for optional sankalpa description
  ///
  /// In en, this message translates to:
  /// **'Description (Optional)'**
  String get descriptionOptional;

  /// Hint text for optional sankalpa description
  ///
  /// In en, this message translates to:
  /// **'Add specific details or mantra text...'**
  String get descriptionHint;

  /// Label for sankalpa duration section
  ///
  /// In en, this message translates to:
  /// **'Duration (Days)'**
  String get durationDays;

  /// Duration choice chip label
  ///
  /// In en, this message translates to:
  /// **'{count} Days'**
  String daysCount(int count);

  /// Label for custom duration option
  ///
  /// In en, this message translates to:
  /// **'Custom'**
  String get custom;

  /// Label for custom day value
  ///
  /// In en, this message translates to:
  /// **'Custom Days'**
  String get customDays;

  /// Section label for sankalpa reminder time
  ///
  /// In en, this message translates to:
  /// **'Daily Reminder Time'**
  String get dailyReminderTime;

  /// Primary action button to create sankalpa
  ///
  /// In en, this message translates to:
  /// **'Create Sankalpa'**
  String get createSankalpa;

  /// Generic save action
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// Success message when sankalpa is created
  ///
  /// In en, this message translates to:
  /// **'Sankalpa created successfully!'**
  String get sankalpaCreatedSuccessfully;

  /// Error message when saving sankalpa fails
  ///
  /// In en, this message translates to:
  /// **'Failed to save Sankalpa: {error}'**
  String failedToSaveSankalpa(String error);

  /// Sankalpa list screen title
  ///
  /// In en, this message translates to:
  /// **'My Sankalpas'**
  String get mySankalpas;

  /// Tab label for active items
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get active;

  /// Tab label for completed items
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get completed;

  /// Empty state message for completed sankalpas
  ///
  /// In en, this message translates to:
  /// **'No completed intentions yet'**
  String get noCompletedIntentionsYet;

  /// Empty state message for active sankalpas
  ///
  /// In en, this message translates to:
  /// **'Start a new spiritual journey'**
  String get startNewSpiritualJourney;

  /// Delete confirmation dialog title
  ///
  /// In en, this message translates to:
  /// **'Delete Sankalpa?'**
  String get deleteSankalpa;

  /// Delete confirmation dialog message
  ///
  /// In en, this message translates to:
  /// **'This action cannot be undone.'**
  String get deleteSankalpaMessage;

  /// Delete action label
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// Popup menu label to toggle sankalpa completion
  ///
  /// In en, this message translates to:
  /// **'Mark Complete/Incomplete'**
  String get markCompleteIncomplete;

  /// Progress label in sankalpa card
  ///
  /// In en, this message translates to:
  /// **'Day {current} of {total}'**
  String dayOf(int current, int total);

  /// Tooltip when today's sankalpa progress is already marked
  ///
  /// In en, this message translates to:
  /// **'Done for today'**
  String get doneForToday;

  /// Tooltip to mark today's sankalpa progress
  ///
  /// In en, this message translates to:
  /// **'Mark today as done'**
  String get markTodayAsDone;

  /// Reminder time label in sankalpa card
  ///
  /// In en, this message translates to:
  /// **'Reminder: {time}'**
  String reminderAt(String time);

  /// Completion date label in history tab
  ///
  /// In en, this message translates to:
  /// **'Completed on {date}'**
  String completedOn(String date);

  /// Weather bottom sheet title
  ///
  /// In en, this message translates to:
  /// **'Weather Details'**
  String get weatherDetails;

  /// Shown when weather service returns no data
  ///
  /// In en, this message translates to:
  /// **'Weather data unavailable'**
  String get weatherDataUnavailable;

  /// Generic error message with details
  ///
  /// In en, this message translates to:
  /// **'Error: {error}'**
  String errorMessage(String error);

  /// Credit text for weather source
  ///
  /// In en, this message translates to:
  /// **'Weather data by Open-Meteo'**
  String get weatherDataByOpenMeteo;

  /// Accessibility label for weather icon
  ///
  /// In en, this message translates to:
  /// **'Weather condition: {condition}'**
  String weatherCondition(String condition);

  /// Label for sunrise time
  ///
  /// In en, this message translates to:
  /// **'Sunrise'**
  String get sunrise;

  /// Label for sunset time
  ///
  /// In en, this message translates to:
  /// **'Sunset'**
  String get sunset;

  /// Weather metric label
  ///
  /// In en, this message translates to:
  /// **'Humidity'**
  String get humidity;

  /// Weather metric label
  ///
  /// In en, this message translates to:
  /// **'Wind'**
  String get wind;

  /// Weather metric label for feels-like temperature
  ///
  /// In en, this message translates to:
  /// **'Real Feel'**
  String get realFeel;

  /// Weather metric label
  ///
  /// In en, this message translates to:
  /// **'UV Index'**
  String get uvIndex;

  /// Weather forecast section title
  ///
  /// In en, this message translates to:
  /// **'Forecast'**
  String get forecast;

  /// Daylight duration text
  ///
  /// In en, this message translates to:
  /// **'Daylight: {hours}h {minutes}m'**
  String daylightDuration(int hours, int minutes);

  /// Tooltip text for opening festival search
  ///
  /// In en, this message translates to:
  /// **'Search Festivals'**
  String get searchFestivals;

  /// Title for permission required dialog
  ///
  /// In en, this message translates to:
  /// **'Permission Required'**
  String get permissionRequired;

  /// Message shown when location permission is denied forever
  ///
  /// In en, this message translates to:
  /// **'Location permission was permanently denied. Please enable it in your device settings.'**
  String get locationPermissionPermanentlyDenied;

  /// Action label to open app settings
  ///
  /// In en, this message translates to:
  /// **'Open Settings'**
  String get openSettings;

  /// Title text for month selection dialog
  ///
  /// In en, this message translates to:
  /// **'Select month'**
  String get selectMonth;

  /// Accessibility label for recenter map button
  ///
  /// In en, this message translates to:
  /// **'Recenter map'**
  String get recenterMap;

  /// Accessibility label for zoom in action
  ///
  /// In en, this message translates to:
  /// **'Zoom in'**
  String get zoomIn;

  /// Accessibility label for zoom out action
  ///
  /// In en, this message translates to:
  /// **'Zoom out'**
  String get zoomOut;

  /// Tooltip for moving timeline back by thirty days
  ///
  /// In en, this message translates to:
  /// **'Back 30 days'**
  String get back30Days;

  /// Tooltip for moving timeline back by one day
  ///
  /// In en, this message translates to:
  /// **'Back 1 day'**
  String get back1Day;

  /// Tooltip for moving timeline forward by one day
  ///
  /// In en, this message translates to:
  /// **'Forward 1 day'**
  String get forward1Day;

  /// Tooltip for moving timeline forward by thirty days
  ///
  /// In en, this message translates to:
  /// **'Forward 30 days'**
  String get forward30Days;

  /// Tooltip for starting timeline animation
  ///
  /// In en, this message translates to:
  /// **'Play animation'**
  String get playAnimation;

  /// Tooltip for pausing timeline animation
  ///
  /// In en, this message translates to:
  /// **'Pause animation'**
  String get pauseAnimation;

  /// Label for animation speed control
  ///
  /// In en, this message translates to:
  /// **'Speed'**
  String get speedLabel;

  /// Tooltip for heliocentric mode
  ///
  /// In en, this message translates to:
  /// **'Heliocentric'**
  String get heliocentric;

  /// Tooltip for geocentric mode
  ///
  /// In en, this message translates to:
  /// **'Geocentric'**
  String get geocentric;

  /// Label for planet distance value
  ///
  /// In en, this message translates to:
  /// **'Distance'**
  String get distance;

  /// Label for orbital period value
  ///
  /// In en, this message translates to:
  /// **'Orbit'**
  String get orbit;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['bn', 'en', 'hi', 'sa'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'bn':
      return AppLocalizationsBn();
    case 'en':
      return AppLocalizationsEn();
    case 'hi':
      return AppLocalizationsHi();
    case 'sa':
      return AppLocalizationsSa();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
