// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Hindi (`hi`).
class AppLocalizationsHi extends AppLocalizations {
  AppLocalizationsHi([String locale = 'hi']) : super(locale);

  @override
  String get appTitle => 'तिथि';

  @override
  String get vedaCalendar => 'वैदिक पंचांग';

  @override
  String get settings => 'सेटिंग्स';

  @override
  String get appearance => 'प्रदर्शन';

  @override
  String get preferences => 'प्राथमिकताएँ';

  @override
  String get calendar => 'पंचांग';

  @override
  String get dataStorage => 'डेटा और संग्रहण';

  @override
  String get accessibility => 'सुगम्यता';

  @override
  String get about => 'परिचय';

  @override
  String get themeAuto => 'स्वचालित';

  @override
  String get themeShukla => 'शुक्ल';

  @override
  String get themeDark => 'गहरा';

  @override
  String get themeKrishna => 'कृष्ण';

  @override
  String get dailyNotifications => 'दैनिक सूचनाएँ';

  @override
  String get notificationScheduled => 'दैनिक निर्धारित';

  @override
  String get getNotifiedTithiDaily => 'प्रतिदिन तिथि की सूचना प्राप्त करें';

  @override
  String get notificationTime => 'सूचना समय';

  @override
  String get autoLocation => 'स्वचालित स्थान';

  @override
  String get useGpsForTithi => 'सटीक तिथि गणना के लिए GPS का उपयोग करें';

  @override
  String usingLocation(String cityName) {
    return 'उपयोग: $cityName';
  }

  @override
  String get fetchingLocation => 'स्थान प्राप्त हो रहा है...';

  @override
  String get locationUnavailable => 'स्थान अनुपलब्ध';

  @override
  String get homeLocation => 'घर का स्थान';

  @override
  String get notSet => 'सेट नहीं';

  @override
  String get setHomeLocation => 'घर का स्थान सेट करें';

  @override
  String get dragMapToPin => 'पिन को अपने घर पर लगाने के लिए नक्शा खींचें';

  @override
  String get setThisLocation => 'यह स्थान सेट करें';

  @override
  String homeLocationSetTo(String address) {
    return 'घर का स्थान $address पर सेट किया गया';
  }

  @override
  String errorSettingLocation(String error) {
    return 'स्थान सेट करने में त्रुटि: $error';
  }

  @override
  String get startOfWeek => 'सप्ताह की शुरुआत';

  @override
  String get sunday => 'रविवार';

  @override
  String get monday => 'सोमवार';

  @override
  String get primaryView => 'प्राथमिक दृश्य';

  @override
  String get tithi => 'तिथि';

  @override
  String get festival => 'त्योहार';

  @override
  String get moon => 'चंद्रमा';

  @override
  String get primaryCalendar => 'प्राथमिक पंचांग';

  @override
  String get secondaryCalendar => 'द्वितीयक पंचांग';

  @override
  String get selectPrimaryCalendar => 'प्राथमिक पंचांग चुनें';

  @override
  String get selectSecondaryCalendar => 'द्वितीयक पंचांग चुनें';

  @override
  String get clearLocationCache => 'स्थान कैश साफ़ करें';

  @override
  String get locationCacheCleared => 'स्थान कैश साफ़ किया गया';

  @override
  String get resetAppSettings => 'ऐप सेटिंग्स रीसेट करें';

  @override
  String get resetSettingsTitle => 'सेटिंग्स रीसेट करें?';

  @override
  String get resetSettingsMessage =>
      'यह आपकी सभी प्राथमिकताओं और डेटा को डिफ़ॉल्ट पर रीसेट कर देगा। यह पूर्ववत नहीं किया जा सकता।';

  @override
  String get cancel => 'रद्द करें';

  @override
  String get reset => 'रीसेट';

  @override
  String get appResetComplete => 'ऐप रीसेट पूर्ण';

  @override
  String get reduceMotion => 'गति कम करें';

  @override
  String get disableAnimations => 'एनिमेशन और इफेक्ट्स बंद करें';

  @override
  String get hapticFeedback => 'हैप्टिक फीडबैक';

  @override
  String get vibrateOnTouch => 'स्पर्श पर कंपन';

  @override
  String get highContrast => 'उच्च कंट्रास्ट';

  @override
  String get solidBackgrounds => 'बेहतर पठनीयता के लिए ठोस पृष्ठभूमि';

  @override
  String get largeText => 'बड़ा टेक्स्ट';

  @override
  String get increaseTextSize => 'वैश्विक रूप से टेक्स्ट का आकार बढ़ाएं';

  @override
  String get language => 'भाषा';

  @override
  String get selectLanguage => 'भाषा चुनें';

  @override
  String get systemDefault => 'सिस्टम डिफ़ॉल्ट';

  @override
  String get privacyPolicy => 'गोपनीयता नीति';

  @override
  String get madeWithLove => 'सनातन धर्म के लिए ❤️ से बनाया गया';

  @override
  String get shareApp => 'ऐप शेयर करें';

  @override
  String get shareAppMessage =>
      'तिथि देखें - वैदिक पंचांग ऐप! अभी डाउनलोड करें: https://example.com/tithi';

  @override
  String get rateUs => 'रेट करें';

  @override
  String get aboutApp => 'परिचय';

  @override
  String get calendarView => 'पंचांग दृश्य';

  @override
  String get scheduleView => 'अनुसूची दृश्य';

  @override
  String get switchToCalendar => 'मासिक पंचांग पर जाएँ';

  @override
  String get switchToSchedule => 'कार्यक्रम सूची पर जाएँ';

  @override
  String versionText(String version) {
    return 'संस्करण $version';
  }

  @override
  String get events => 'कार्यक्रम';

  @override
  String get festivalsAndEvents => 'त्योहार और कार्यक्रम';

  @override
  String get noFestivalsOnThisDay => 'आज कोई त्योहार नहीं';

  @override
  String get todaysFestival => 'आज का त्योहार';

  @override
  String get noFestivalsToday => 'तिथि • आज कोई त्योहार नहीं';

  @override
  String errorLoadingPanchang(String error) {
    return 'पंचांग लोड करने में त्रुटि: $error';
  }

  @override
  String get panchangDetails => 'पंचांग विवरण';

  @override
  String get paksha => 'पक्ष';

  @override
  String pakshaWithName(String paksha) {
    return '$paksha पक्ष';
  }

  @override
  String get waxing => 'शुक्ल';

  @override
  String get waning => 'कृष्ण';

  @override
  String get waxingMoonPhase => 'शुक्ल पक्ष - बढ़ता चंद्रमा';

  @override
  String get waningMoonPhase => 'कृष्ण पक्ष - घटता चंद्रमा';

  @override
  String get category => 'श्रेणी';

  @override
  String get general => 'सामान्य';

  @override
  String get ritualsAndPractices => 'विधि और साधना';

  @override
  String get locationAccess => 'स्थान पहुँच';

  @override
  String get enableLocation => 'स्थान सक्षम करें';

  @override
  String get skip => 'छोड़ें';

  @override
  String get locationAccessDescription =>
      'तिथि आपके शहर के लिए सटीक पंचांग डेटा की गणना के लिए आपके स्थान का उपयोग करता है।';

  @override
  String get locationAccessBenefits =>
      '• अधिक सटीक तिथि गणना\n• स्थान-विशिष्ट चंद्रोदय/सूर्यास्त समय\n• आपका स्थान डेटा आपके डिवाइस पर रहता है';

  @override
  String get locationDisabled => 'स्थान अक्षम';

  @override
  String get locationDisabledMessage =>
      'स्थान अक्षम है। अपने शहर के आधार पर अधिक सटीक पंचांग गणना के लिए इसे सक्षम करें।';

  @override
  String get notNow => 'अभी नहीं';

  @override
  String get enable => 'सक्षम करें';

  @override
  String get pleaseEnableLocationServices =>
      'कृपया अपने डिवाइस पर स्थान सेवाएँ सक्षम करें';

  @override
  String get locationPermissionDenied =>
      'स्थान अनुमति अस्वीकृत। डिफ़ॉल्ट स्थान का उपयोग कर रहे हैं।';

  @override
  String get locationEnabledSuccess => 'स्थान सफलतापूर्वक सक्षम!';

  @override
  String get refreshLocation => 'स्थान रीफ्रेश करें';

  @override
  String get goToToday => 'आज पर जाएँ';

  @override
  String get initializing => 'प्रारंभ हो रहा है...';

  @override
  String get privacyYourDataStays => 'आपका डेटा आपके पास रहता है';

  @override
  String get privacyYourDataDesc =>
      'तिथि को गोपनीयता-प्रथम, ऑफ़लाइन-प्रथम वास्तुकला के साथ डिज़ाइन किया गया है। सभी खगोलीय गणनाएँ, पंचांग निर्माण और कार्यक्रम प्रसंस्करण सीधे आपके डिवाइस पर होते हैं। हम किसी भी बाहरी सर्वर पर आपका व्यक्तिगत डेटा एकत्र, संग्रहीत या प्रेषित नहीं करते।';

  @override
  String get privacyLocationUsage => 'स्थान उपयोग';

  @override
  String get privacyLocationDesc =>
      'हम केवल सटीक तिथि, नक्षत्र और सूर्योदय/सूर्यास्त समय की गणना के लिए आपके स्थान तक पहुँच का अनुरोध करते हैं, जो आपके विशिष्ट भौगोलिक निर्देशांकों पर निर्भर करते हैं। आपका स्थान डेटा स्थानीय रूप से ऐप द्वारा संसाधित होता है।';

  @override
  String get privacyOffline => 'ऑफ़लाइन कार्यक्षमता';

  @override
  String get privacyOfflineDesc =>
      'प्रारंभिक डाउनलोड के बाद ऐप पूरी तरह से ऑफ़लाइन काम करता है। इसमें उच्च-सटीकता ग्रहीय गणनाओं के लिए आवश्यक स्विस एफेमेरिस डेटा एम्बेडेड है।';

  @override
  String get privacyOpenSource => 'ओपन सोर्स पारदर्शिता';

  @override
  String get privacyOpenSourceDesc =>
      'तिथि एक ओपन-सोर्स प्रोजेक्ट है। हमारा कोड ऑडिट के लिए सार्वजनिक रूप से उपलब्ध है, यह सुनिश्चित करते हुए कि हमारी गोपनीयता प्रतिबद्धताएँ सत्यापित पारदर्शिता द्वारा समर्थित हैं।';

  @override
  String get lastUpdated => 'अंतिम अपडेट: दिसंबर 2025';

  @override
  String get applicationLegalese =>
      '© 2025 तिथि प्रोजेक्ट\nसनातन धर्म के लिए ❤️ से बनाया गया';

  @override
  String get moonPhases => 'चंद्र कलाएँ';

  @override
  String get nextPurnima => 'अगली पूर्णिमा';

  @override
  String get nextAmavasya => 'अगली अमावस्या';

  @override
  String get purnima => 'पूर्णिमा';

  @override
  String get amavasya => 'अमावस्या';

  @override
  String get fullMoon => 'पूर्ण चंद्रमा';

  @override
  String get newMoon => 'नया चंद्रमा';

  @override
  String get noUpcomingDates => 'कोई आगामी तिथियाँ नहीं मिलीं';

  @override
  String get errorLoadingData => 'डेटा लोड करने में त्रुटि';

  @override
  String get retry => 'पुनः प्रयास करें';

  @override
  String get astronomy => 'खगोल विज्ञान';

  @override
  String get solarSystem => 'सौर मंडल';

  @override
  String get planetPositions => 'ग्रह स्थिति';

  @override
  String get selectDate => 'तिथि चुनें';

  @override
  String get retrograde => 'वक्री';

  @override
  String get zodiacSign => 'राशि';

  @override
  String get degree => 'अंश';

  @override
  String get longitude => 'देशांतर';

  @override
  String get eclipses => 'ग्रहण';

  @override
  String get solarEclipses => 'सूर्य ग्रहण';

  @override
  String get lunarEclipses => 'चंद्र ग्रहण';

  @override
  String get maxEclipse => 'अधिकतम ग्रहण';

  @override
  String get visibleFromYourLocation => 'आपके स्थान से दृश्य';

  @override
  String get notVisibleFromYourLocation => 'आपके स्थान से दृश्य नहीं';

  @override
  String get partialBegins => 'आंशिक चरण प्रारंभ';

  @override
  String get partialEnds => 'आंशिक चरण समाप्त';

  @override
  String get totalityBegins => 'पूर्णता प्रारंभ';

  @override
  String get totalityEnds => 'पूर्णता समाप्त';

  @override
  String get duration => 'अवधि';

  @override
  String get date => 'तिथि';

  @override
  String get days => 'दिन';

  @override
  String get today => 'आज';
}
