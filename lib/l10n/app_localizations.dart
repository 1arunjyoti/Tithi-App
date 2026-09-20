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

  /// Settings tile title for exporting festivals
  ///
  /// In en, this message translates to:
  /// **'Export Festivals (JSON)'**
  String get exportFestivalsJson;

  /// Settings tile subtitle for exporting festivals
  ///
  /// In en, this message translates to:
  /// **'Save all festivals with Panchang details to a file'**
  String get exportFestivalsSubtitle;

  /// Title for export festivals bottom sheet
  ///
  /// In en, this message translates to:
  /// **'Export Festivals'**
  String get exportFestivals;

  /// Subtitle for export festivals bottom sheet
  ///
  /// In en, this message translates to:
  /// **'First occurrence of each festival in the chosen year'**
  String get exportFestivalsSubtitleYear;

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

  /// Name of the first lunar day
  ///
  /// In en, this message translates to:
  /// **'Pratipada'**
  String get tithiPratipada;

  /// Name of the second lunar day
  ///
  /// In en, this message translates to:
  /// **'Dwitiya'**
  String get tithiDwitiya;

  /// Name of the third lunar day
  ///
  /// In en, this message translates to:
  /// **'Tritiya'**
  String get tithiTritiya;

  /// Name of the fourth lunar day
  ///
  /// In en, this message translates to:
  /// **'Chaturthi'**
  String get tithiChaturthi;

  /// Name of the fifth lunar day
  ///
  /// In en, this message translates to:
  /// **'Panchami'**
  String get tithiPanchami;

  /// Name of the sixth lunar day
  ///
  /// In en, this message translates to:
  /// **'Shashthi'**
  String get tithiShashthi;

  /// Name of the seventh lunar day
  ///
  /// In en, this message translates to:
  /// **'Saptami'**
  String get tithiSaptami;

  /// Name of the eighth lunar day
  ///
  /// In en, this message translates to:
  /// **'Ashtami'**
  String get tithiAshtami;

  /// Name of the ninth lunar day
  ///
  /// In en, this message translates to:
  /// **'Navami'**
  String get tithiNavami;

  /// Name of the tenth lunar day
  ///
  /// In en, this message translates to:
  /// **'Dashami'**
  String get tithiDashami;

  /// Name of the eleventh lunar day
  ///
  /// In en, this message translates to:
  /// **'Ekadashi'**
  String get tithiEkadashi;

  /// Name of the twelfth lunar day
  ///
  /// In en, this message translates to:
  /// **'Dwadashi'**
  String get tithiDwadashi;

  /// Name of the thirteenth lunar day
  ///
  /// In en, this message translates to:
  /// **'Trayodashi'**
  String get tithiTrayodashi;

  /// Name of the fourteenth lunar day
  ///
  /// In en, this message translates to:
  /// **'Chaturdashi'**
  String get tithiChaturdashi;

  /// Name of the fifteenth waxing lunar day
  ///
  /// In en, this message translates to:
  /// **'Purnima'**
  String get tithiPurnima;

  /// Name of the fifteenth waning lunar day
  ///
  /// In en, this message translates to:
  /// **'Amavasya'**
  String get tithiAmavasya;

  /// Fallback name for an invalid lunar day
  ///
  /// In en, this message translates to:
  /// **'Unknown'**
  String get tithiUnknown;

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

  /// Moon illumination percentage label
  ///
  /// In en, this message translates to:
  /// **'{percent}% illuminated'**
  String illuminatedPercent(String percent);

  /// Label for the next tithi transition
  ///
  /// In en, this message translates to:
  /// **'Next tithi'**
  String get nextTithi;

  /// Time of a tithi transition
  ///
  /// In en, this message translates to:
  /// **'at {time}'**
  String atTime(String time);

  /// Label for yesterday
  ///
  /// In en, this message translates to:
  /// **'Yesterday'**
  String get yesterday;

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

  /// Label for moonrise time
  ///
  /// In en, this message translates to:
  /// **'Moonrise'**
  String get moonrise;

  /// Label for moonset time
  ///
  /// In en, this message translates to:
  /// **'Moonset'**
  String get moonset;

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

  /// Title for festival countdowns screen
  ///
  /// In en, this message translates to:
  /// **'Festival Countdowns'**
  String get festivalCountdowns;

  /// Tooltip for add countdown button
  ///
  /// In en, this message translates to:
  /// **'Add countdown'**
  String get addCountdown;

  /// Heading for countdown card screen
  ///
  /// In en, this message translates to:
  /// **'Festival Countdowns'**
  String get countdownHeading;

  /// Zero days display in countdown
  ///
  /// In en, this message translates to:
  /// **'0'**
  String get zeroDays;

  /// Days remaining label in countdown
  ///
  /// In en, this message translates to:
  /// **'{days} days to go'**
  String daysRemaining(Object days);

  /// Tooltip for removing countdown from home screen
  ///
  /// In en, this message translates to:
  /// **'Remove from home screen'**
  String get removeFromHomeScreen;

  /// Tooltip for removing countdown
  ///
  /// In en, this message translates to:
  /// **'Remove countdown'**
  String get removeCountdown;

  /// Snackbar message when a countdown is removed
  ///
  /// In en, this message translates to:
  /// **'Countdown removed'**
  String get countdownRemoved;

  /// Hint text for festival search field
  ///
  /// In en, this message translates to:
  /// **'Search festival name'**
  String get searchFestivalName;

  /// Empty state when no festivals match search
  ///
  /// In en, this message translates to:
  /// **'No festivals found'**
  String get noFestivalsFound;

  /// Empty state when user has no countdowns
  ///
  /// In en, this message translates to:
  /// **'No countdowns yet'**
  String get noCountdownsYet;

  /// Title for all festivals screen
  ///
  /// In en, this message translates to:
  /// **'All Festivals'**
  String get allFestivals;

  /// Hint text for festival search field
  ///
  /// In en, this message translates to:
  /// **'Search festivals'**
  String get searchFestivalsHint;

  /// Error message when festivals fail to load
  ///
  /// In en, this message translates to:
  /// **'Could not load festivals. Please try again.'**
  String get couldNotLoadFestivals;

  /// Error title in error display widget
  ///
  /// In en, this message translates to:
  /// **'Oops! Something went wrong'**
  String get oopsSomethingWentWrong;

  /// Generic error message in error display widget
  ///
  /// In en, this message translates to:
  /// **'An unexpected error occurred. Please try again.'**
  String get unexpectedErrorOccurred;

  /// Short error message for compact error display
  ///
  /// In en, this message translates to:
  /// **'Something went wrong'**
  String get somethingWentWrong;

  /// Snackbar message when privacy policy URL cannot be opened
  ///
  /// In en, this message translates to:
  /// **'Unable to open the privacy policy website.'**
  String get unableToOpenPrivacyPolicy;

  /// Snackbar message when sharing fails
  ///
  /// In en, this message translates to:
  /// **'Failed to share: {error}'**
  String failedToShare(String error);

  /// Text shared when sharing a festival
  ///
  /// In en, this message translates to:
  /// **'Celebrating {festivalName} with Tithi App!'**
  String celebratingFestivalWithTithi(String festivalName);

  /// Button text to dismiss dialog
  ///
  /// In en, this message translates to:
  /// **'Got it'**
  String get gotIt;

  /// Button text to add widget
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get add;

  /// Dialog title for manual widget instructions
  ///
  /// In en, this message translates to:
  /// **'Add Widget Manually'**
  String get addWidgetManually;

  /// Snackbar message when widget pin is requested
  ///
  /// In en, this message translates to:
  /// **'Widget pin requested — confirm on home screen'**
  String get widgetPinRequested;

  /// Snackbar message when widget pin fails
  ///
  /// In en, this message translates to:
  /// **'Could not pin widget. Try adding manually: long-press → Widgets → Tithi'**
  String get couldNotPinWidget;

  /// Tooltip for info button
  ///
  /// In en, this message translates to:
  /// **'Info'**
  String get infoTooltip;

  /// Tooltip for dismiss button
  ///
  /// In en, this message translates to:
  /// **'Dismiss'**
  String get dismissTooltip;

  /// Message shown when Solar System screen accessed on web
  ///
  /// In en, this message translates to:
  /// **'Solar System is not available on web'**
  String get solarSystemNotAvailableOnWeb;

  /// Message shown when Eclipse screen accessed on web
  ///
  /// In en, this message translates to:
  /// **'Eclipse screen is not available on web'**
  String get eclipseScreenNotAvailableOnWeb;

  /// Snackbar message while finding next festival occurrence
  ///
  /// In en, this message translates to:
  /// **'Finding next occurrence...'**
  String get findingNextOccurrence;

  /// Tooltip for navigating to next festival occurrence
  ///
  /// In en, this message translates to:
  /// **'Go to next occurrence'**
  String get goToNextOccurrence;

  /// Snackbar message when no upcoming festival occurrence found
  ///
  /// In en, this message translates to:
  /// **'Could not find upcoming occurrence within a year.'**
  String get couldNotFindUpcomingOccurrence;

  /// Snackbar message when there are no festivals to export
  ///
  /// In en, this message translates to:
  /// **'No festivals to export'**
  String get noFestivalsToExport;

  /// Dialog title while exporting festivals for a year
  ///
  /// In en, this message translates to:
  /// **'Exporting {year}'**
  String exportingYear(String year);

  /// Progress text during festival export
  ///
  /// In en, this message translates to:
  /// **'{done} / {total} festivals'**
  String festivalsExportedProgress(int done, int total);

  /// Snackbar message when export is cancelled
  ///
  /// In en, this message translates to:
  /// **'Export cancelled'**
  String get exportCancelled;

  /// Snackbar message when download starts on web
  ///
  /// In en, this message translates to:
  /// **'Download started'**
  String get downloadStarted;

  /// Snackbar message when export file cannot be saved
  ///
  /// In en, this message translates to:
  /// **'Could not save export file'**
  String get couldNotSaveExportFile;

  /// Dialog title when export is saved successfully
  ///
  /// In en, this message translates to:
  /// **'Saved'**
  String get saved;

  /// Confirmation message after successful export
  ///
  /// In en, this message translates to:
  /// **'{count} festivals exported for {year}.'**
  String festivalsExportedForYear(int count, String year);

  /// Button text to dismiss success dialog
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get done;

  /// Button text to share exported file
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get share;

  /// Snackbar message when export fails
  ///
  /// In en, this message translates to:
  /// **'Export failed: {error}'**
  String exportFailed(String error);

  /// File picker dialog title for saving festivals
  ///
  /// In en, this message translates to:
  /// **'Save festivals {year}'**
  String saveFestivalsYear(String year);

  /// About screen introduction heading
  ///
  /// In en, this message translates to:
  /// **'Built for daily practice'**
  String get aboutBuiltForDailyPractice;

  /// About screen introduction
  ///
  /// In en, this message translates to:
  /// **'Tithi blends traditional Panchang wisdom with modern clarity, so your rituals and observances stay on time and effortless.'**
  String get aboutDailyPracticeDescription;

  /// About screen features heading
  ///
  /// In en, this message translates to:
  /// **'What\'s inside'**
  String get aboutWhatsInside;

  /// About screen feature summary
  ///
  /// In en, this message translates to:
  /// **'Accurate tithi and nakshatra tracking, festival countdowns, local sunrise and sunset, and calm daily inspiration.'**
  String get aboutFeaturesDescription;

  /// About screen privacy policy link title
  ///
  /// In en, this message translates to:
  /// **'Detailed privacy policy'**
  String get detailedPrivacyPolicy;

  /// About screen privacy policy link subtitle
  ///
  /// In en, this message translates to:
  /// **'Read the full policy on our website'**
  String get readFullPrivacyPolicy;

  /// Tagline below the app name on the About screen
  ///
  /// In en, this message translates to:
  /// **'Vedic calendar for modern life'**
  String get aboutTagline;

  /// Purple theme option in settings
  ///
  /// In en, this message translates to:
  /// **'Purple'**
  String get themePurple;

  /// Snackbar when notification permission is denied
  ///
  /// In en, this message translates to:
  /// **'Notification permission denied. Please enable it in system settings.'**
  String get notificationPermissionDenied;

  /// Notification toggle failure; state is on or off
  ///
  /// In en, this message translates to:
  /// **'Could not turn notifications {state, select, on{on} other{off}} ({error}). Please try again.'**
  String notificationToggleFailed(String state, String error);

  /// Daily verse notification setting title
  ///
  /// In en, this message translates to:
  /// **'Daily Shloka'**
  String get dailyShloka;

  /// Daily verse notification setting subtitle
  ///
  /// In en, this message translates to:
  /// **'Get a daily spiritual verse'**
  String get dailyShlokaSubtitle;

  /// Daily Shloka toggle failure; state is on or off
  ///
  /// In en, this message translates to:
  /// **'Could not turn Daily Shloka {state, select, on{on} other{off}} ({error}). Please try again.'**
  String dailyShlokaToggleFailed(String state, String error);

  /// Festival reminder notification setting title
  ///
  /// In en, this message translates to:
  /// **'Festival Reminders'**
  String get festivalReminders;

  /// Festival reminder notification setting subtitle
  ///
  /// In en, this message translates to:
  /// **'Notify only for festivals, on the day or before'**
  String get festivalRemindersSubtitle;

  /// Festival reminder toggle failure; state is on or off
  ///
  /// In en, this message translates to:
  /// **'Could not turn Festival Reminders {state, select, on{on} other{off}} ({error}). Please try again.'**
  String festivalRemindersToggleFailed(String state, String error);

  /// Festival reminder time setting and picker title
  ///
  /// In en, this message translates to:
  /// **'Festival Reminder Time'**
  String get festivalReminderTime;

  /// Snackbar when saving the notification time fails
  ///
  /// In en, this message translates to:
  /// **'Could not update notification time ({error}). Please try again.'**
  String notificationTimeUpdateFailed(String error);

  /// Festival reminder timing option for the previous day
  ///
  /// In en, this message translates to:
  /// **'Day before'**
  String get festivalReminderDayBefore;

  /// Festival reminder timing option for both the day before and the festival day
  ///
  /// In en, this message translates to:
  /// **'Both'**
  String get festivalReminderBoth;

  /// Festival reminder timing option for the festival day
  ///
  /// In en, this message translates to:
  /// **'On the day'**
  String get festivalReminderOnDay;

  /// Snackbar when saving the festival reminder time fails
  ///
  /// In en, this message translates to:
  /// **'Could not update reminder time ({error}). Please try again.'**
  String reminderTimeUpdateFailed(String error);

  /// Hindu month system setting and selection sheet title
  ///
  /// In en, this message translates to:
  /// **'Hindu Month System'**
  String get hinduMonthSystem;

  /// Hindu month system selection explanation
  ///
  /// In en, this message translates to:
  /// **'Choose how months are named during Krishna Paksha'**
  String get hinduMonthSystemSubtitle;

  /// Hindu year era setting and selection sheet title
  ///
  /// In en, this message translates to:
  /// **'Hindu Year Era'**
  String get hinduYearEra;

  /// Hindu year era selection explanation
  ///
  /// In en, this message translates to:
  /// **'Choose the calendar era for year display'**
  String get hinduYearEraSubtitle;

  /// Tithi numbering setting and selection sheet title
  ///
  /// In en, this message translates to:
  /// **'Tithi Display'**
  String get tithiDisplay;

  /// Summary of the paksha-based tithi numbering option
  ///
  /// In en, this message translates to:
  /// **'Paksha (1-15)'**
  String get tithiDisplayPakshaRange;

  /// Tithi numbering selection explanation
  ///
  /// In en, this message translates to:
  /// **'Choose how tithis are numbered in the calendar'**
  String get tithiDisplaySubtitle;

  /// Paksha-based tithi numbering option title
  ///
  /// In en, this message translates to:
  /// **'Paksha Based'**
  String get tithiDisplayPakshaBased;

  /// Paksha-based tithi numbering option explanation
  ///
  /// In en, this message translates to:
  /// **'Show 1-15 for each paksha separately'**
  String get tithiDisplayPakshaDescription;

  /// Continuous tithi numbering option explanation
  ///
  /// In en, this message translates to:
  /// **'Show 1-30 continuously'**
  String get tithiDisplayContinuousDescription;

  /// Subject when sharing exported festival JSON
  ///
  /// In en, this message translates to:
  /// **'Tithi festivals {year}'**
  String festivalExportShareSubject(String year);

  /// Message when sharing exported festival JSON
  ///
  /// In en, this message translates to:
  /// **'Tithi festivals {year} with Panchang details (JSON)'**
  String festivalExportShareText(String year);

  /// Snackbar after adding a festival countdown
  ///
  /// In en, this message translates to:
  /// **'Countdown added for {festivalName}'**
  String countdownAddedForFestival(String festivalName);

  /// Snackbar when a festival countdown already exists
  ///
  /// In en, this message translates to:
  /// **'{festivalName} is already in your countdowns'**
  String festivalAlreadyInCountdowns(String festivalName);

  /// Map data attribution; preserve the OpenStreetMap brand name
  ///
  /// In en, this message translates to:
  /// **'OpenStreetMap contributors'**
  String get openStreetMapAttribution;

  /// Gesture hint below the interactive moon visualization
  ///
  /// In en, this message translates to:
  /// **'Drag to explore • Double-tap resets'**
  String get moonScrubHint;

  /// Moon illumination percentage, formatted to one decimal place
  ///
  /// In en, this message translates to:
  /// **'Illumination: {percentage}%'**
  String moonIllumination(String percentage);

  /// Compact day unit in the moon phase countdown
  ///
  /// In en, this message translates to:
  /// **'d'**
  String get dayUnitShort;

  /// Compact hour unit in the moon phase countdown
  ///
  /// In en, this message translates to:
  /// **'h'**
  String get hourUnitShort;

  /// Compact minute unit in the moon phase countdown
  ///
  /// In en, this message translates to:
  /// **'m'**
  String get minuteUnitShort;

  /// Compact duration for eclipse timings and moon countdowns
  ///
  /// In en, this message translates to:
  /// **'{hours}h {minutes}m'**
  String durationHoursMinutesShort(int hours, int minutes);

  /// Compact eclipse duration under one hour
  ///
  /// In en, this message translates to:
  /// **'{minutes}m'**
  String durationMinutesShort(int minutes);

  /// Planet distance in astronomical units, formatted to two decimal places
  ///
  /// In en, this message translates to:
  /// **'{distance} AU'**
  String distanceAstronomicalUnits(String distance);

  /// Planet orbital period rounded to whole days
  ///
  /// In en, this message translates to:
  /// **'{days}d'**
  String orbitalPeriodDaysShort(String days);

  /// Planet orbital period in years, formatted to one decimal place
  ///
  /// In en, this message translates to:
  /// **'{years}y'**
  String orbitalPeriodYearsShort(String years);

  /// Vikram calendar era label in the calendar year selector
  ///
  /// In en, this message translates to:
  /// **'Vikram Samvat'**
  String get vikramSamvat;

  /// Shaka calendar era label in the calendar year selector
  ///
  /// In en, this message translates to:
  /// **'Shaka Era'**
  String get shakaEra;

  /// Bengali calendar era label in the calendar year selector
  ///
  /// In en, this message translates to:
  /// **'Bengali Era'**
  String get bengaliEra;

  /// Title of the calendar year selection dialog
  ///
  /// In en, this message translates to:
  /// **'Select year'**
  String get selectYear;

  /// Bengali year with its era name in the year selector
  ///
  /// In en, this message translates to:
  /// **'{year} Bangabda'**
  String bengaliEraYear(int year);

  /// Gregorian month name in calendar headers
  ///
  /// In en, this message translates to:
  /// **'January'**
  String get monthJanuary;

  /// Gregorian month name in calendar headers
  ///
  /// In en, this message translates to:
  /// **'February'**
  String get monthFebruary;

  /// Gregorian month name in calendar headers
  ///
  /// In en, this message translates to:
  /// **'March'**
  String get monthMarch;

  /// Gregorian month name in calendar headers
  ///
  /// In en, this message translates to:
  /// **'April'**
  String get monthApril;

  /// Gregorian month name in calendar headers
  ///
  /// In en, this message translates to:
  /// **'May'**
  String get monthMay;

  /// Gregorian month name in calendar headers
  ///
  /// In en, this message translates to:
  /// **'June'**
  String get monthJune;

  /// Gregorian month name in calendar headers
  ///
  /// In en, this message translates to:
  /// **'July'**
  String get monthJuly;

  /// Gregorian month name in calendar headers
  ///
  /// In en, this message translates to:
  /// **'August'**
  String get monthAugust;

  /// Gregorian month name in calendar headers
  ///
  /// In en, this message translates to:
  /// **'September'**
  String get monthSeptember;

  /// Gregorian month name in calendar headers
  ///
  /// In en, this message translates to:
  /// **'October'**
  String get monthOctober;

  /// Gregorian month name in calendar headers
  ///
  /// In en, this message translates to:
  /// **'November'**
  String get monthNovember;

  /// Gregorian month name in calendar headers
  ///
  /// In en, this message translates to:
  /// **'December'**
  String get monthDecember;

  /// Abbreviated Sunday label in the calendar weekday row
  ///
  /// In en, this message translates to:
  /// **'SUN'**
  String get weekdaySundayShort;

  /// Abbreviated Monday label in the calendar weekday row
  ///
  /// In en, this message translates to:
  /// **'MON'**
  String get weekdayMondayShort;

  /// Abbreviated Tuesday label in the calendar weekday row
  ///
  /// In en, this message translates to:
  /// **'TUE'**
  String get weekdayTuesdayShort;

  /// Abbreviated Wednesday label in the calendar weekday row
  ///
  /// In en, this message translates to:
  /// **'WED'**
  String get weekdayWednesdayShort;

  /// Abbreviated Thursday label in the calendar weekday row
  ///
  /// In en, this message translates to:
  /// **'THU'**
  String get weekdayThursdayShort;

  /// Abbreviated Friday label in the calendar weekday row
  ///
  /// In en, this message translates to:
  /// **'FRI'**
  String get weekdayFridayShort;

  /// Abbreviated Saturday label in the calendar weekday row
  ///
  /// In en, this message translates to:
  /// **'SAT'**
  String get weekdaySaturdayShort;

  /// Attribution appended to shared verse text
  ///
  /// In en, this message translates to:
  /// **'Shared via Tithi App'**
  String get sharedViaTithiApp;

  /// Message accompanying a shared verse image
  ///
  /// In en, this message translates to:
  /// **'Daily Wisdom — Tithi App'**
  String get dailyWisdomShareMessage;

  /// Verse sharing option title
  ///
  /// In en, this message translates to:
  /// **'Share as image'**
  String get shareAsImage;

  /// Verse image sharing option subtitle
  ///
  /// In en, this message translates to:
  /// **'Verse card picture'**
  String get verseCardPicture;

  /// Verse text sharing option title
  ///
  /// In en, this message translates to:
  /// **'Share as text'**
  String get shareAsText;

  /// Verse text sharing option subtitle
  ///
  /// In en, this message translates to:
  /// **'Verse with translation'**
  String get verseWithTranslation;

  /// Copy verse option title
  ///
  /// In en, this message translates to:
  /// **'Copy text'**
  String get copyText;

  /// Copy verse option subtitle
  ///
  /// In en, this message translates to:
  /// **'Copy verse to clipboard'**
  String get copyVerseToClipboard;

  /// Snackbar when copying a verse fails
  ///
  /// In en, this message translates to:
  /// **'Could not copy verse'**
  String get couldNotCopyVerse;

  /// Snackbar after copying a verse
  ///
  /// In en, this message translates to:
  /// **'Verse copied'**
  String get verseCopied;

  /// Explains why a verse was chosen for a festival
  ///
  /// In en, this message translates to:
  /// **'Chosen for {festivalName}'**
  String chosenForFestival(String festivalName);

  /// Collapse additional verse translations
  ///
  /// In en, this message translates to:
  /// **'Show less'**
  String get showLess;

  /// Expand additional verse translations
  ///
  /// In en, this message translates to:
  /// **'Show more translations'**
  String get showMoreTranslations;

  /// Hide the verse translation
  ///
  /// In en, this message translates to:
  /// **'Hide translation'**
  String get hideTranslation;

  /// Show the verse translation
  ///
  /// In en, this message translates to:
  /// **'Show translation'**
  String get showTranslation;

  /// Collapse a festival description; title case
  ///
  /// In en, this message translates to:
  /// **'Show Less'**
  String get showLessTitleCase;

  /// Expand a festival description
  ///
  /// In en, this message translates to:
  /// **'Read More'**
  String get readMore;

  /// Named tithi with its numeric identifier in festival details
  ///
  /// In en, this message translates to:
  /// **'{tithiName} (T{number})'**
  String tithiNameWithNumber(String tithiName, int number);

  /// Lunar month label in festival details
  ///
  /// In en, this message translates to:
  /// **'Masa'**
  String get masa;

  /// Lunar mansion label in festival details
  ///
  /// In en, this message translates to:
  /// **'Nakshatra'**
  String get nakshatra;

  /// Beginning time label in festival details
  ///
  /// In en, this message translates to:
  /// **'Begins'**
  String get begins;

  /// Ending time label in festival details
  ///
  /// In en, this message translates to:
  /// **'Ends'**
  String get ends;

  /// Numeric tithi label when a tithi name is unavailable
  ///
  /// In en, this message translates to:
  /// **'Tithi {number}'**
  String tithiWithNumber(int number);

  /// Fasting rule label in festival details
  ///
  /// In en, this message translates to:
  /// **'Fasting / Vrat'**
  String get fastingVrat;

  /// Mantra heading in festival details
  ///
  /// In en, this message translates to:
  /// **'Mantra'**
  String get mantra;

  /// Astronomical timing information dialog title
  ///
  /// In en, this message translates to:
  /// **'Timing Note'**
  String get timingNote;

  /// Explains possible differences from local temple timings
  ///
  /// In en, this message translates to:
  /// **'Timings are calculated astronomically based on coordinates and may vary by a few minutes from local temple calendars due to atmospheric refraction, elevation, or calculation methods.'**
  String get timingNoteDescription;

  /// Empty state for the home screen festival list
  ///
  /// In en, this message translates to:
  /// **'No festivals in the next 3 days'**
  String get noFestivalsInNextThreeDays;

  /// Festival list loading error with details
  ///
  /// In en, this message translates to:
  /// **'Could not load festivals: {error}'**
  String couldNotLoadFestivalsWithError(String error);

  /// Button and accessibility label to view all festivals with a count
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{View all {count} festival} other{View all {count} festivals}}'**
  String viewAllFestivalsCount(int count);

  /// Button and accessibility label to view all festivals without a count
  ///
  /// In en, this message translates to:
  /// **'View all festivals'**
  String get viewAllFestivals;

  /// Singular day unit in a festival countdown
  ///
  /// In en, this message translates to:
  /// **'day'**
  String get day;

  /// Festival countdown card title
  ///
  /// In en, this message translates to:
  /// **'{title} Countdown'**
  String festivalCountdownTitle(String title);

  /// Relative time until a festival in a festival row
  ///
  /// In en, this message translates to:
  /// **'{days, plural, one{in 1 day} other{in {days} days}}'**
  String festivalInDays(int days);

  /// Festival search empty query hint
  ///
  /// In en, this message translates to:
  /// **'Search for festivals, vrats, and events'**
  String get searchFestivalsVratsAndEvents;

  /// Title of the home screen widget promotion card
  ///
  /// In en, this message translates to:
  /// **'Home Screen Widget'**
  String get homeScreenWidget;

  /// Subtitle when home screen widget pinning is available
  ///
  /// In en, this message translates to:
  /// **'Add festival countdowns to your home screen'**
  String get homeWidgetCountdownDescription;

  /// Short manual home screen widget installation hint
  ///
  /// In en, this message translates to:
  /// **'Long-press home screen → Widgets → Tithi'**
  String get homeWidgetManualHint;

  /// Full manual home screen widget installation instructions
  ///
  /// In en, this message translates to:
  /// **'1. Long-press on your home screen\n2. Tap \"Widgets\"\n3. Find \"Tithi\" and drag \"Festival Countdowns\" to your home screen\n\nThe widget shows all festivals from your Countdowns page.'**
  String get homeWidgetManualInstructions;

  /// Moon countdown loading error
  ///
  /// In en, this message translates to:
  /// **'Unable to load moon phase data'**
  String get unableToLoadMoonPhaseData;

  /// Compact label for a moon countdown that has reached its target
  ///
  /// In en, this message translates to:
  /// **'Now'**
  String get countdownNow;

  /// Compact moon countdown in days and hours
  ///
  /// In en, this message translates to:
  /// **'{days}d {hours}h'**
  String countdownDaysHours(int days, int hours);

  /// Hero card label for the selected day rather than today
  ///
  /// In en, this message translates to:
  /// **'Selected'**
  String get selected;

  /// Moon phase and illumination in the hero card and tithi details
  ///
  /// In en, this message translates to:
  /// **'{phase} · {percentage}% illuminated'**
  String moonPhaseIlluminated(String phase, String percentage);

  /// Upcoming tithi transition in the hero card
  ///
  /// In en, this message translates to:
  /// **'Next tithi {tithiName} at {time}'**
  String nextTithiAt(String tithiName, String time);

  /// Transition text showing when the next tithi begins
  ///
  /// In en, this message translates to:
  /// **'{tithiName} begins at {time}'**
  String tithiBeginsAt(String tithiName, String time);

  /// Transition text showing when the next tithi ends; dateTime follows the selected calendar
  ///
  /// In en, this message translates to:
  /// **'{tithiName} ends {dateTime}'**
  String tithiEndsAtDateTime(String tithiName, String dateTime);

  /// Explains sunrise tithi and short tithis in the tithi detail sheet
  ///
  /// In en, this message translates to:
  /// **'Udaya tithi: the tithi prevailing at sunrise. A short tithi can begin and end between two sunrises — both tithis are shown above so none is skipped.'**
  String get udayaTithiExplanation;

  /// Uppercase beginning time label in tithi details
  ///
  /// In en, this message translates to:
  /// **'BEGINS'**
  String get beginsUppercase;

  /// Uppercase ending time label in tithi details
  ///
  /// In en, this message translates to:
  /// **'ENDS'**
  String get endsUppercase;

  /// Uppercase transition section label in tithi details
  ///
  /// In en, this message translates to:
  /// **'TRANSITION'**
  String get transition;

  /// Single-letter Shukla Paksha marker in the schedule view
  ///
  /// In en, this message translates to:
  /// **'S'**
  String get shuklaPakshaInitial;

  /// Single-letter Krishna Paksha marker in the schedule view
  ///
  /// In en, this message translates to:
  /// **'K'**
  String get krishnaPakshaInitial;

  /// Wind speed in kilometers per hour in the weather sheet
  ///
  /// In en, this message translates to:
  /// **'{speed} kph'**
  String windSpeedKph(double speed);

  /// Continuous 30-day tithi display mode label
  ///
  /// In en, this message translates to:
  /// **'30 Days'**
  String get tithiDisplayThirtyDays;

  /// Snackbar shown when sharing as image fails
  ///
  /// In en, this message translates to:
  /// **'Could not create image'**
  String get couldNotCreateImage;

  /// Title of the share verse bottom sheet
  ///
  /// In en, this message translates to:
  /// **'Share verse'**
  String get shareVerse;

  /// Tooltip for the left arrow to navigate to yesterday's verse
  ///
  /// In en, this message translates to:
  /// **'Previous day\'s verse'**
  String get previousDaysVerse;

  /// Tooltip for the right arrow to navigate to tomorrow's verse
  ///
  /// In en, this message translates to:
  /// **'Next day\'s verse'**
  String get nextDaysVerse;

  /// Tooltip for the share icon in the festival detail sheet
  ///
  /// In en, this message translates to:
  /// **'Share Card'**
  String get shareCard;

  /// Subtitle of the home widget promo card when widget can be pinned
  ///
  /// In en, this message translates to:
  /// **'Add festival countdowns to your home screen'**
  String get homeWidgetCanPin;

  /// Brand label on the shloka share card image
  ///
  /// In en, this message translates to:
  /// **'DAILY WISDOM'**
  String get dailyWisdom;

  /// Section header label for tithi timings in the detail sheet
  ///
  /// In en, this message translates to:
  /// **'TITHI TIMINGS'**
  String get tithiTimings;

  /// Label for the tithi start time cell
  ///
  /// In en, this message translates to:
  /// **'BEGINS'**
  String get tithiBegins;

  /// Label for the tithi end time cell
  ///
  /// In en, this message translates to:
  /// **'ENDS'**
  String get tithiEnds;

  /// Label shown on the transition card in the tithi detail sheet
  ///
  /// In en, this message translates to:
  /// **'TRANSITION'**
  String get tithiTransition;

  /// Explainer text about udaya tithi in the tithi detail sheet
  ///
  /// In en, this message translates to:
  /// **'Udaya tithi: the tithi prevailing at sunrise. A short tithi can begin and end between two sunrises — both tithis are shown above so none is skipped.'**
  String get udayaTithiExplainer;

  /// Uppercase nakshatra section label in tithi details
  ///
  /// In en, this message translates to:
  /// **'NAKSHATRA'**
  String get nakshatraTimings;

  /// Nakshatra card headline showing when the sunrise nakshatra ends
  ///
  /// In en, this message translates to:
  /// **'{nakshatra} until {time}'**
  String nakshatraUntil(String nakshatra, String time);

  /// Nakshatra card subline showing the Vimshottari lord
  ///
  /// In en, this message translates to:
  /// **'Lord: {lord}'**
  String nakshatraLord(String lord);

  /// Nakshatra card subline showing how much of the span has elapsed
  ///
  /// In en, this message translates to:
  /// **'{percent}% elapsed'**
  String nakshatraElapsed(String percent);

  /// Nakshatra card line showing the upcoming nakshatra below the progress bar
  ///
  /// In en, this message translates to:
  /// **'Next: {nakshatra} at {time}'**
  String nakshatraNext(String nakshatra, String time);

  /// Vimshottari lord name
  ///
  /// In en, this message translates to:
  /// **'Ketu'**
  String get lordKetu;

  /// Vimshottari lord name
  ///
  /// In en, this message translates to:
  /// **'Venus'**
  String get lordVenus;

  /// Vimshottari lord name
  ///
  /// In en, this message translates to:
  /// **'Sun'**
  String get lordSun;

  /// Vimshottari lord name
  ///
  /// In en, this message translates to:
  /// **'Moon'**
  String get lordMoon;

  /// Vimshottari lord name
  ///
  /// In en, this message translates to:
  /// **'Mars'**
  String get lordMars;

  /// Vimshottari lord name
  ///
  /// In en, this message translates to:
  /// **'Rahu'**
  String get lordRahu;

  /// Vimshottari lord name
  ///
  /// In en, this message translates to:
  /// **'Jupiter'**
  String get lordJupiter;

  /// Vimshottari lord name
  ///
  /// In en, this message translates to:
  /// **'Saturn'**
  String get lordSaturn;

  /// Vimshottari lord name
  ///
  /// In en, this message translates to:
  /// **'Mercury'**
  String get lordMercury;

  /// Uppercase yoga/karana section label in tithi details
  ///
  /// In en, this message translates to:
  /// **'YOGA & KARANA'**
  String get yogaKaranaTimings;

  /// Cell label for yoga in the yoga/karana card
  ///
  /// In en, this message translates to:
  /// **'YOGA'**
  String get yogaLabel;

  /// Cell label for karana in the yoga/karana card
  ///
  /// In en, this message translates to:
  /// **'KARANA'**
  String get karanaLabel;

  /// Yoga/karana span line showing when the current span ends and what follows
  ///
  /// In en, this message translates to:
  /// **'until {time}, then {next}'**
  String untilThen(String time, String next);

  /// Uppercase inauspicious-timings section label in tithi details
  ///
  /// In en, this message translates to:
  /// **'INAUSPICIOUS TIMINGS'**
  String get inauspiciousTimings;

  /// Row name for Rahu Kalam in the day windows card
  ///
  /// In en, this message translates to:
  /// **'Rahu Kalam'**
  String get rahuKalam;

  /// Row name for Yamaganda in the day windows card
  ///
  /// In en, this message translates to:
  /// **'Yamaganda'**
  String get yamaganda;

  /// Row name for Gulika Kalam in the day windows card
  ///
  /// In en, this message translates to:
  /// **'Gulika Kalam'**
  String get gulikaKalam;

  /// Uppercase auspicious-timings section label in tithi details
  ///
  /// In en, this message translates to:
  /// **'AUSPICIOUS TIMINGS'**
  String get auspiciousTimings;

  /// Row name for Abhijit muhurta
  ///
  /// In en, this message translates to:
  /// **'Abhijit'**
  String get abhijit;

  /// Row name for Brahma Muhurta
  ///
  /// In en, this message translates to:
  /// **'Brahma Muhurta'**
  String get brahmaMuhurta;

  /// Row name for Madhyahna
  ///
  /// In en, this message translates to:
  /// **'Madhyahna'**
  String get madhyahna;

  /// Row name for Nishita
  ///
  /// In en, this message translates to:
  /// **'Nishita'**
  String get nishita;

  /// Row name for Godhuli
  ///
  /// In en, this message translates to:
  /// **'Godhuli'**
  String get godhuli;

  /// Row name for Pradosha
  ///
  /// In en, this message translates to:
  /// **'Pradosha'**
  String get pradosha;

  /// Abhijit subnote shown on Wednesdays
  ///
  /// In en, this message translates to:
  /// **'Avoided on Wednesday'**
  String get abhijitAvoided;

  /// Abhijit subnote shown on Tue/Thu/Sat
  ///
  /// In en, this message translates to:
  /// **'Especially auspicious today'**
  String get abhijitAuspicious;

  /// Madhyahna subnote showing the midpoint instant
  ///
  /// In en, this message translates to:
  /// **'midpoint {time}'**
  String midpointAt(String time);
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
