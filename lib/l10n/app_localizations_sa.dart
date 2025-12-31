// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Sanskrit (`sa`).
class AppLocalizationsSa extends AppLocalizations {
  AppLocalizationsSa([String locale = 'sa']) : super(locale);

  @override
  String get appTitle => 'तिथिः';

  @override
  String get vedaCalendar => 'वैदिकं पञ्चाङ्गम्';

  @override
  String get settings => 'संस्थापनम्';

  @override
  String get appearance => 'प्रदर्शनम्';

  @override
  String get preferences => 'प्राधान्यानि';

  @override
  String get calendar => 'पञ्चाङ्गम्';

  @override
  String get dataStorage => 'दत्तांशसंग्रहणम्';

  @override
  String get accessibility => 'सुगम्यता';

  @override
  String get about => 'परिचयः';

  @override
  String get themeAuto => 'स्वचालितम्';

  @override
  String get themeShukla => 'शुक्लः';

  @override
  String get themeDark => 'अन्धकारः';

  @override
  String get themeKrishna => 'कृष्णः';

  @override
  String get dailyNotifications => 'दैनिकसूचनाः';

  @override
  String get notificationScheduled => 'दैनिकं निर्धारितम्';

  @override
  String get getNotifiedTithiDaily => 'प्रतिदिनं तिथिसूचनां प्राप्नुवन्तु';

  @override
  String get notificationTime => 'सूचनासमयः';

  @override
  String get autoLocation => 'स्वचालितस्थानम्';

  @override
  String get useGpsForTithi => 'सटीकतिथिगणनायै GPS उपयुज्यताम्';

  @override
  String usingLocation(String cityName) {
    return 'उपयोगः: $cityName';
  }

  @override
  String get fetchingLocation => 'स्थानं प्राप्यते...';

  @override
  String get locationUnavailable => 'स्थानम् अनुपलब्धम्';

  @override
  String get homeLocation => 'गृहस्थानम्';

  @override
  String get notSet => 'न निर्धारितम्';

  @override
  String get setHomeLocation => 'गृहस्थानं निर्धारयतु';

  @override
  String get dragMapToPin => 'गृहे पिनं स्थापयितुं मानचित्रं कर्षतु';

  @override
  String get setThisLocation => 'एतत् स्थानं निर्धारयतु';

  @override
  String homeLocationSetTo(String address) {
    return 'गृहस्थानं $address इत्यत्र निर्धारितम्';
  }

  @override
  String errorSettingLocation(String error) {
    return 'स्थाननिर्धारणे त्रुटिः: $error';
  }

  @override
  String get startOfWeek => 'सप्ताहारम्भः';

  @override
  String get sunday => 'रविवासरः';

  @override
  String get monday => 'सोमवासरः';

  @override
  String get primaryView => 'प्राथमिकदृश्यम्';

  @override
  String get tithi => 'तिथिः';

  @override
  String get festival => 'उत्सवः';

  @override
  String get moon => 'चन्द्रः';

  @override
  String get primaryCalendar => 'प्राथमिकपञ्चाङ्गम्';

  @override
  String get secondaryCalendar => 'द्वितीयपञ्चाङ्गम्';

  @override
  String get selectPrimaryCalendar => 'प्राथमिकपञ्चाङ्गं चिनुत';

  @override
  String get selectSecondaryCalendar => 'द्वितीयपञ्चाङ्गं चिनुत';

  @override
  String get clearLocationCache => 'स्थानसंचयं शोधयतु';

  @override
  String get locationCacheCleared => 'स्थानसंचयः शोधितः';

  @override
  String get resetAppSettings => 'अनुप्रयोगसंस्थापनं पुनःस्थापयतु';

  @override
  String get resetSettingsTitle => 'संस्थापनं पुनःस्थापयतु?';

  @override
  String get resetSettingsMessage =>
      'एतेन सर्वाणि प्राधान्यानि दत्तांशाश्च मूलस्थितौ पुनःस्थाप्यन्ते। इदं पूर्ववत् कर्तुं न शक्यते।';

  @override
  String get cancel => 'रद्दं कुरुत';

  @override
  String get reset => 'पुनःस्थापयतु';

  @override
  String get appResetComplete => 'अनुप्रयोगपुनःस्थापनं सम्पूर्णम्';

  @override
  String get reduceMotion => 'गतिं न्यूनीकुरुत';

  @override
  String get disableAnimations => 'चलचित्राणि प्रभावाश्च निष्क्रियं कुरुत';

  @override
  String get hapticFeedback => 'स्पर्शप्रतिक्रिया';

  @override
  String get vibrateOnTouch => 'स्पर्शे कम्पनम्';

  @override
  String get highContrast => 'उच्चविपर्ययः';

  @override
  String get solidBackgrounds => 'उत्तमपठनीयतायै दृढपृष्ठभूमिः';

  @override
  String get largeText => 'वृहत्पाठ्यम्';

  @override
  String get increaseTextSize => 'वैश्विकरूपेण पाठ्यमानं वर्धयतु';

  @override
  String get language => 'भाषा';

  @override
  String get selectLanguage => 'भाषां चिनुत';

  @override
  String get systemDefault => 'यन्त्रमूलम्';

  @override
  String get privacyPolicy => 'गोपनीयतानीतिः';

  @override
  String get madeWithLove => 'सनातनधर्माय ❤️ निर्मितम्';

  @override
  String get shareApp => 'अनुप्रयोगं साझां कुरुत';

  @override
  String get shareAppMessage =>
      'तिथिः पश्यतु - वैदिकं पञ्चाङ्गम्! अधुना अवतारयतु: https://example.com/tithi';

  @override
  String get rateUs => 'मूल्याङ्कनं कुरुत';

  @override
  String get aboutApp => 'परिचयः';

  @override
  String get calendarView => 'पञ्चाङ्गदृश्यम्';

  @override
  String get scheduleView => 'अनुसूचीदृश्यम्';

  @override
  String get switchToCalendar => 'मासिकपञ्चाङ्गं गच्छतु';

  @override
  String get switchToSchedule => 'कार्यक्रमसूचीं गच्छतु';

  @override
  String versionText(String version) {
    return 'संस्करणम् $version';
  }

  @override
  String get events => 'कार्यक्रमाः';

  @override
  String get festivalsAndEvents => 'उत्सवाः कार्यक्रमाश्च';

  @override
  String get noFestivalsOnThisDay => 'अद्य उत्सवो नास्ति';

  @override
  String get todaysFestival => 'अद्यतनोत्सवः';

  @override
  String get noFestivalsToday => 'तिथिः • अद्य उत्सवो नास्ति';

  @override
  String errorLoadingPanchang(String error) {
    return 'पञ्चाङ्गप्रापणे त्रुटिः: $error';
  }

  @override
  String get panchangDetails => 'पञ्चाङ्गविवरणम्';

  @override
  String get paksha => 'पक्षः';

  @override
  String pakshaWithName(String paksha) {
    return '$paksha पक्षः';
  }

  @override
  String get waxing => 'शुक्लः';

  @override
  String get waning => 'कृष्णः';

  @override
  String get waxingMoonPhase => 'शुक्लपक्षः - वर्धमानचन्द्रः';

  @override
  String get waningMoonPhase => 'कृष्णपक्षः - क्षीयमाणचन्द्रः';

  @override
  String get category => 'वर्गः';

  @override
  String get general => 'सामान्यम्';

  @override
  String get ritualsAndPractices => 'विधयः साधनाश्च';

  @override
  String get locationAccess => 'स्थानप्राप्तिः';

  @override
  String get enableLocation => 'स्थानं सक्रियं कुरुत';

  @override
  String get skip => 'त्यजतु';

  @override
  String get locationAccessDescription =>
      'तिथिः भवतः नगराय सटीकपञ्चाङ्गदत्तांशं गणयितुं स्थानम् उपयुङ्क्ते।';

  @override
  String get locationAccessBenefits =>
      '• अधिकसटीकतिथिगणना\n• स्थानविशिष्टचन्द्रोदयसूर्यास्तसमयाः\n• भवतः स्थानदत्तांशः भवतः यन्त्रे एव तिष्ठति';

  @override
  String get locationDisabled => 'स्थानं निष्क्रियम्';

  @override
  String get locationDisabledMessage =>
      'स्थानं निष्क्रियम्। भवतः नगराधारितं अधिकसटीकपञ्चाङ्गगणनायै एनं सक्रियं कुरुत।';

  @override
  String get notNow => 'अधुना न';

  @override
  String get enable => 'सक्रियं कुरुत';

  @override
  String get pleaseEnableLocationServices =>
      'कृपया भवतः यन्त्रे स्थानसेवाः सक्रियाः कुरुत';

  @override
  String get locationPermissionDenied =>
      'स्थानानुज्ञा निराकृता। मूलस्थानम् उपयुज्यते।';

  @override
  String get locationEnabledSuccess => 'स्थानं सफलतया सक्रियम्!';

  @override
  String get refreshLocation => 'स्थानं नवीकुरुत';

  @override
  String get goToToday => 'अद्य गच्छतु';

  @override
  String get initializing => 'प्रारम्भः...';

  @override
  String get privacyYourDataStays => 'भवतः दत्तांशः भवता सह तिष्ठति';

  @override
  String get privacyYourDataDesc =>
      'तिथिः गोपनीयताप्रथम्, अनुसन्धानप्रथम् वास्तुकलया निर्मिता। सर्वाणि ज्योतिर्गणनानि, पञ्चाङ्गनिर्माणं, कार्यक्रमप्रक्रियाश्च साक्षात् भवतः यन्त्रे भवन्ति। वयं कस्मिन्नपि बाह्यसेवके भवतः व्यक्तिगतदत्तांशं न संगृह्णामः।';

  @override
  String get privacyLocationUsage => 'स्थानोपयोगः';

  @override
  String get privacyLocationDesc =>
      'वयं केवलं सटीकतिथि-नक्षत्र-सूर्योदयसूर्यास्तसमयगणनायै भवतः स्थानप्राप्त्यर्थं निवेदयामः।';

  @override
  String get privacyOffline => 'अनुसन्धानकार्यक्षमता';

  @override
  String get privacyOfflineDesc =>
      'प्रारम्भिकावतारणानन्तरं अनुप्रयोगः पूर्णतया अनुसन्धाने कार्यं करोति।';

  @override
  String get privacyOpenSource => 'मुक्तस्रोतपारदर्शिता';

  @override
  String get privacyOpenSourceDesc =>
      'तिथिः मुक्तस्रोतप्रकल्पः। अस्माकं कूटः परीक्षणाय सार्वजनिकरूपेण उपलब्धः।';

  @override
  String get lastUpdated => 'अन्तिमं नवीकृतम्: दिसम्बर २०२५';

  @override
  String get applicationLegalese =>
      '© २०२५ तिथिः प्रकल्पः\nसनातनधर्माय ❤️ निर्मितम्';

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
