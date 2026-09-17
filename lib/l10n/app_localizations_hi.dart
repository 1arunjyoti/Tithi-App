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
  String get exportFestivalsJson => 'त्योहार एक्सपोर्ट करें (JSON)';

  @override
  String get exportFestivalsSubtitle =>
      'सभी त्योहारों को पंचांग विवरण के साथ फ़ाइल में सहेजें';

  @override
  String get exportFestivals => 'त्योहार एक्सपोर्ट करें';

  @override
  String get exportFestivalsSubtitleYear =>
      'चुने गए वर्ष में प्रत्येक त्योहार का पहला आयोजन';

  @override
  String get vedaCalendar => 'वैदिक पंचांग';

  @override
  String get settings => 'सेटिंग्स';

  @override
  String get appearance => 'दिखावट';

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
  String get notificationTime => 'सूचना का समय';

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
  String get dragMapToPin =>
      'पिन को अपने घर पर स्थित करने के लिए नक्शे को खींचें';

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
  String get tithiPratipada => 'प्रतिपदा';

  @override
  String get tithiDwitiya => 'द्वितीया';

  @override
  String get tithiTritiya => 'तृतीया';

  @override
  String get tithiChaturthi => 'चतुर्थी';

  @override
  String get tithiPanchami => 'पंचमी';

  @override
  String get tithiShashthi => 'षष्ठी';

  @override
  String get tithiSaptami => 'सप्तमी';

  @override
  String get tithiAshtami => 'अष्टमी';

  @override
  String get tithiNavami => 'नवमी';

  @override
  String get tithiDashami => 'दशमी';

  @override
  String get tithiEkadashi => 'एकादशी';

  @override
  String get tithiDwadashi => 'द्वादशी';

  @override
  String get tithiTrayodashi => 'त्रयोदशी';

  @override
  String get tithiChaturdashi => 'चतुर्दशी';

  @override
  String get tithiPurnima => 'पूर्णिमा';

  @override
  String get tithiAmavasya => 'अमावस्या';

  @override
  String get tithiUnknown => 'अज्ञात';

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
      'तिथि - वैदिक पंचांग ऐप देखें! अभी डाउनलोड करें: https://tithiapp.netlify.app/';

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
  String get noFestivalsOnThisDay => 'इस दिन कोई त्योहार नहीं';

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
  String get locationAccess => 'स्थान एक्सेस';

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
  String get locationEnabledSuccess => 'स्थान सफलतापूर्वक सक्षम किया गया!';

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
      'तिथि को गोपनीयता-प्रथम, ऑफ़लाइन-प्रथम वास्तुकला के साथ डिज़ाइन किया गया है। सभी खगोलीय गणनाएँ, पंचांग निर्माण और कार्यक्रम प्रसंस्करण सीधे आपके डिवाइस पर होते हैं और ऐप बिना नेटवर्क के भी काम करता रहता है। हम आपका व्यक्तिगत डेटा किसी भी बाहरी सर्वर पर एकत्र, संग्रहीत या प्रेषित नहीं करते।';

  @override
  String get privacyLocationUsage => 'स्थान उपयोग';

  @override
  String get privacyLocationDesc =>
      'हम केवल सटीक तिथि, नक्षत्र और सूर्योदय/सूर्यास्त समय की गणना के लिए आपके स्थान तक पहुँच का अनुरोध करते हैं, जो आपके विशिष्ट भौगोलिक निर्देशांकों पर निर्भर करते हैं। आपका स्थान डेटा ऐप द्वारा स्थानीय रूप से संसाधित होता है और कभी भी तृतीय पक्षों के साथ साझा नहीं किया जाता या हमारे सर्वर पर संग्रहीत नहीं होता।';

  @override
  String get privacyOffline => 'ऑफ़लाइन कार्यक्षमता';

  @override
  String get privacyOfflineDesc =>
      'ऐप पूरी तरह से ऑफ़लाइन काम करता है। उच्च-सटीकता ग्रहीय गणनाओं के लिए आवश्यक स्विस एफेमेरिस डेटा ऐप के भीतर ही एम्बेडेड है।';

  @override
  String get privacyOpenSource => 'ओपन सोर्स पारदर्शिता';

  @override
  String get privacyOpenSourceDesc =>
      'तिथि एक ओपन-सोर्स प्रोजेक्ट है। हमारा कोड ऑडिट के लिए सार्वजनिक रूप से उपलब्ध है, जो यह सुनिश्चित करता है कि हमारी गोपनीयता प्रतिबद्धताएँ सत्यापित पारदर्शिता द्वारा समर्थित हैं। जो दिखता है, बिल्कुल वही मिलता है।';

  @override
  String get lastUpdated => 'अंतिम अपडेट: दिसंबर २०२५';

  @override
  String get applicationLegalese =>
      '© २०२५ तिथि प्रोजेक्ट\nसनातन धर्म के लिए ❤️ से बनाया गया';

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
  String get noUpcomingDates => 'कोई आगामी तारीख़ें नहीं मिलीं';

  @override
  String get errorLoadingData => 'डेटा लोड करने में त्रुटि';

  @override
  String get retry => 'पुनः प्रयास करें';

  @override
  String get astronomy => 'खगोल विज्ञान';

  @override
  String get solarSystem => 'सौर मंडल';

  @override
  String get planetPositions => 'ग्रहों की स्थिति';

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
  String get solarEclipses => 'सूर्यग्रहण';

  @override
  String get lunarEclipses => 'चंद्रग्रहण';

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
  String get date => 'दिनांक';

  @override
  String get days => 'दिन';

  @override
  String get today => 'आज';

  @override
  String illuminatedPercent(String percent) {
    return '$percent% प्रकाशित';
  }

  @override
  String get nextTithi => 'अगली तिथि';

  @override
  String atTime(String time) {
    return '$time पर';
  }

  @override
  String get yesterday => 'बीता कल';

  @override
  String get tomorrow => 'कल';

  @override
  String daysFromNow(int days) {
    return '$days दिन';
  }

  @override
  String get now => 'अभी!';

  @override
  String get currentMoonPhase => 'वर्तमान चंद्र कला दृश्य';

  @override
  String get mapPinLocation => 'मानचित्र पिन स्थान';

  @override
  String get nearbyTemples => 'निकटवर्ती मंदिर';

  @override
  String get searchHere => 'यहाँ खोजें';

  @override
  String get loadMore => 'और लोड करें';

  @override
  String get templeMarker => 'मंदिर चिन्ह';

  @override
  String kmAway(String distance) {
    return '$distance किमी दूर';
  }

  @override
  String get nearby => 'पास में';

  @override
  String get getDirections => 'दिशा प्राप्त करें';

  @override
  String get couldNotOpenMaps => 'मैप नहीं खोले जा सके';

  @override
  String errorLaunchingMaps(String error) {
    return 'मैप खोलने में त्रुटि: $error';
  }

  @override
  String get templeSearchFailed =>
      'निकटवर्ती मंदिर नहीं मिल सके। कृपया पुनः प्रयास करें।';

  @override
  String get yourLocation => 'आपका स्थान';

  @override
  String get newIntention => 'नया संकल्प';

  @override
  String get whatIsYourSankalpa => 'आपका संकल्प क्या है?';

  @override
  String get intentionTitle => 'संकल्प शीर्षक';

  @override
  String get intentionTitleHint => 'जैसे: गायत्री मंत्र १०८ बार जप';

  @override
  String get pleaseEnterTitle => 'कृपया शीर्षक दर्ज करें';

  @override
  String get descriptionOptional => 'विवरण (वैकल्पिक)';

  @override
  String get descriptionHint => 'विशेष विवरण या मंत्र पाठ जोड़ें...';

  @override
  String get durationDays => 'अवधि (दिन)';

  @override
  String daysCount(int count) {
    return '$count दिन';
  }

  @override
  String get custom => 'कस्टम';

  @override
  String get customDays => 'कस्टम दिन';

  @override
  String get dailyReminderTime => 'दैनिक रिमाइंडर समय';

  @override
  String get createSankalpa => 'संकल्प बनाएँ';

  @override
  String get save => 'सहेजें';

  @override
  String get sankalpaCreatedSuccessfully => 'संकल्प सफलतापूर्वक बनाया गया!';

  @override
  String failedToSaveSankalpa(String error) {
    return 'संकल्प सहेजने में विफल: $error';
  }

  @override
  String get mySankalpas => 'मेरे संकल्प';

  @override
  String get active => 'सक्रिय';

  @override
  String get completed => 'पूर्ण';

  @override
  String get noCompletedIntentionsYet => 'अभी तक कोई पूर्ण संकल्प नहीं';

  @override
  String get startNewSpiritualJourney => 'नई आध्यात्मिक यात्रा शुरू करें';

  @override
  String get deleteSankalpa => 'संकल्प हटाएँ?';

  @override
  String get deleteSankalpaMessage => 'यह क्रिया पूर्ववत नहीं की जा सकती।';

  @override
  String get delete => 'हटाएँ';

  @override
  String get markCompleteIncomplete => 'पूर्ण/अपूर्ण चिह्नित करें';

  @override
  String dayOf(int current, int total) {
    return 'दिन $current / $total';
  }

  @override
  String get doneForToday => 'आज के लिए पूर्ण';

  @override
  String get markTodayAsDone => 'आज को पूर्ण चिह्नित करें';

  @override
  String reminderAt(String time) {
    return 'रिमाइंडर: $time';
  }

  @override
  String completedOn(String date) {
    return 'पूर्ण हुआ: $date';
  }

  @override
  String get weatherDetails => 'मौसम विवरण';

  @override
  String get weatherDataUnavailable => 'मौसम डेटा उपलब्ध नहीं';

  @override
  String errorMessage(String error) {
    return 'त्रुटि: $error';
  }

  @override
  String get weatherDataByOpenMeteo => 'Open-Meteo द्वारा मौसम डेटा';

  @override
  String weatherCondition(String condition) {
    return 'मौसम स्थिति: $condition';
  }

  @override
  String get sunrise => 'सूर्योदय';

  @override
  String get sunset => 'सूर्यास्त';

  @override
  String get humidity => 'आर्द्रता';

  @override
  String get wind => 'हवा';

  @override
  String get realFeel => 'अनुभूत ताप';

  @override
  String get uvIndex => 'यूवी सूचकांक';

  @override
  String get forecast => 'पूर्वानुमान';

  @override
  String daylightDuration(int hours, int minutes) {
    return 'दिन का प्रकाश: $hoursघं $minutesमि';
  }

  @override
  String get searchFestivals => 'त्योहार खोजें';

  @override
  String get permissionRequired => 'अनुमति आवश्यक';

  @override
  String get locationPermissionPermanentlyDenied =>
      'स्थान अनुमति स्थायी रूप से अस्वीकृत है। कृपया इसे अपने डिवाइस सेटिंग्स में सक्षम करें।';

  @override
  String get openSettings => 'सेटिंग्स खोलें';

  @override
  String get selectMonth => 'माह चुनें';

  @override
  String get recenterMap => 'मानचित्र को पुनः केंद्रित करें';

  @override
  String get zoomIn => 'ज़ूम इन';

  @override
  String get zoomOut => 'ज़ूम आउट';

  @override
  String get back30Days => '३० दिन पीछे';

  @override
  String get back1Day => '१ दिन पीछे';

  @override
  String get forward1Day => '१ दिन आगे';

  @override
  String get forward30Days => '३० दिन आगे';

  @override
  String get playAnimation => 'एनिमेशन चलाएँ';

  @override
  String get pauseAnimation => 'एनिमेशन रोकें';

  @override
  String get speedLabel => 'गति';

  @override
  String get heliocentric => 'सूर्यकेन्द्रीय';

  @override
  String get geocentric => 'भूकेन्द्रीय';

  @override
  String get distance => 'दूरी';

  @override
  String get orbit => 'कक्षा';

  @override
  String get festivalCountdowns => 'त्योहार काउंटडाउन';

  @override
  String get addCountdown => 'काउंटडाउन जोड़ें';

  @override
  String get countdownHeading => 'त्योहार काउंटडाउन';

  @override
  String get zeroDays => '०';

  @override
  String daysRemaining(Object days) {
    return '$days दिन बाकी';
  }

  @override
  String get removeFromHomeScreen => 'होम स्क्रीन से हटाएँ';

  @override
  String get removeCountdown => 'काउंटडाउन हटाएँ';

  @override
  String get countdownRemoved => 'काउंटडाउन हटाया गया';

  @override
  String get searchFestivalName => 'त्योहार का नाम खोजें';

  @override
  String get noFestivalsFound => 'कोई त्योहार नहीं मिले';

  @override
  String get noCountdownsYet => 'अभी तक कोई काउंटडाउन नहीं';

  @override
  String get allFestivals => 'सभी त्योहार';

  @override
  String get searchFestivalsHint => 'त्योहार खोजें';

  @override
  String get couldNotLoadFestivals =>
      'त्योहार लोड नहीं हो सके। कृपया पुनः प्रयास करें।';

  @override
  String get oopsSomethingWentWrong => 'ओह! कुछ गड़बड़ हो गई';

  @override
  String get unexpectedErrorOccurred =>
      'एक अप्रत्याशित त्रुटि हुई। कृपया पुनः प्रयास करें।';

  @override
  String get somethingWentWrong => 'कुछ गड़बड़ हो गई';

  @override
  String get unableToOpenPrivacyPolicy =>
      'गोपनीयता नीति वेबसाइट नहीं खोली जा सकी।';

  @override
  String failedToShare(String error) {
    return 'साझा करने में विफल: $error';
  }

  @override
  String celebratingFestivalWithTithi(String festivalName) {
    return 'तिथि ऐप के साथ $festivalName मनाइए!';
  }

  @override
  String get gotIt => 'समझ गया';

  @override
  String get add => 'जोड़ें';

  @override
  String get addWidgetManually => 'विजेट मैन्युअल रूप से जोड़ें';

  @override
  String get widgetPinRequested =>
      'विजेट पिन का अनुरोध किया गया — होम स्क्रीन पर पुष्टि करें';

  @override
  String get couldNotPinWidget =>
      'विजेट पिन नहीं हो सका। मैन्युअल रूप से जोड़ने का प्रयास करें: देर तक दबाएँ → विजेट → तिथि';

  @override
  String get infoTooltip => 'जानकारी';

  @override
  String get dismissTooltip => 'बंद करें';

  @override
  String get solarSystemNotAvailableOnWeb => 'सौर मंडल वेब पर उपलब्ध नहीं है';

  @override
  String get eclipseScreenNotAvailableOnWeb =>
      'ग्रहण स्क्रीन वेब पर उपलब्ध नहीं है';

  @override
  String get findingNextOccurrence => 'अगला आयोजन खोजा जा रहा है...';

  @override
  String get goToNextOccurrence => 'अगले आयोजन पर जाएँ';

  @override
  String get couldNotFindUpcomingOccurrence =>
      'एक वर्ष के भीतर कोई आगामी आयोजन नहीं मिला।';

  @override
  String get noFestivalsToExport => 'एक्सपोर्ट करने के लिए कोई त्योहार नहीं';

  @override
  String exportingYear(String year) {
    return '$year एक्सपोर्ट किया जा रहा है';
  }

  @override
  String festivalsExportedProgress(int done, int total) {
    return '$done / $total त्योहार';
  }

  @override
  String get exportCancelled => 'एक्सपोर्ट रद्द किया गया';

  @override
  String get downloadStarted => 'डाउनलोड शुरू हुआ';

  @override
  String get couldNotSaveExportFile => 'एक्सपोर्ट फ़ाइल सहेजी नहीं जा सकी';

  @override
  String get saved => 'सहेजा गया';

  @override
  String festivalsExportedForYear(int count, String year) {
    return '$year के लिए $count त्योहार एक्सपोर्ट किए गए।';
  }

  @override
  String get done => 'हो गया';

  @override
  String get share => 'साझा करें';

  @override
  String exportFailed(String error) {
    return 'एक्सपोर्ट विफल: $error';
  }

  @override
  String saveFestivalsYear(String year) {
    return 'त्योहार सहेजें $year';
  }

  @override
  String get aboutBuiltForDailyPractice => 'दैनिक साधना के लिए बनाया गया';

  @override
  String get aboutDailyPracticeDescription =>
      'तिथि पारंपरिक पंचांग की ज्ञानता को आधुनिक स्पष्टता के साथ जोड़ती है, ताकि आपके अनुष्ठान और व्रत समय पर और सहज रूप से रहें।';

  @override
  String get aboutWhatsInside => 'इसमें क्या है';

  @override
  String get aboutFeaturesDescription =>
      'सटीक तिथि और नक्षत्र ट्रैकिंग, त्योहार काउंटडाउन, स्थानीय सूर्योदय और सूर्यास्त, और शांत दैनिक प्रेरणा।';

  @override
  String get detailedPrivacyPolicy => 'विस्तृत गोपनीयता नीति';

  @override
  String get readFullPrivacyPolicy => 'पूरी नीति हमारी वेबसाइट पर पढ़ें';

  @override
  String get aboutTagline => 'आधुनिक जीवन के लिए वैदिक पंचांग';

  @override
  String get themePurple => 'बैंगनी';

  @override
  String get notificationPermissionDenied =>
      'सूचना की अनुमति नहीं मिली। कृपया इसे सिस्टम सेटिंग्स में सक्षम करें।';

  @override
  String notificationToggleFailed(String state, String error) {
    String _temp0 = intl.Intl.selectLogic(state, {
      'on': 'चालू',
      'other': 'बंद',
    });
    return 'सूचनाएँ $_temp0 नहीं की जा सकीं ($error)। कृपया पुनः प्रयास करें।';
  }

  @override
  String get dailyShloka => 'दैनिक श्लोक';

  @override
  String get dailyShlokaSubtitle => 'प्रतिदिन एक आध्यात्मिक श्लोक प्राप्त करें';

  @override
  String dailyShlokaToggleFailed(String state, String error) {
    String _temp0 = intl.Intl.selectLogic(state, {
      'on': 'चालू',
      'other': 'बंद',
    });
    return 'दैनिक श्लोक $_temp0 नहीं किया जा सका ($error)। कृपया पुनः प्रयास करें।';
  }

  @override
  String get festivalReminders => 'त्योहार अनुस्मारक';

  @override
  String get festivalRemindersSubtitle =>
      'केवल त्योहारों के लिए सूचना, उसी दिन या पहले';

  @override
  String festivalRemindersToggleFailed(String state, String error) {
    String _temp0 = intl.Intl.selectLogic(state, {
      'on': 'चालू',
      'other': 'बंद',
    });
    return 'त्योहार अनुस्मारक $_temp0 नहीं किया जा सका ($error)। कृपया पुनः प्रयास करें।';
  }

  @override
  String get festivalReminderTime => 'त्योहार अनुस्मारक का समय';

  @override
  String notificationTimeUpdateFailed(String error) {
    return 'सूचना का समय अद्यतन नहीं हो सका ($error)। कृपया पुनः प्रयास करें।';
  }

  @override
  String get festivalReminderDayBefore => 'एक दिन पहले';

  @override
  String get festivalReminderBoth => 'दोनों';

  @override
  String get festivalReminderOnDay => 'उसी दिन';

  @override
  String reminderTimeUpdateFailed(String error) {
    return 'अनुस्मारक का समय अद्यतन नहीं हो सका ($error)। कृपया पुनः प्रयास करें।';
  }

  @override
  String get hinduMonthSystem => 'हिन्दू मास प्रणाली';

  @override
  String get hinduMonthSystemSubtitle =>
      'चुनें कि कृष्ण पक्ष में महीनों का नामकरण कैसे हो';

  @override
  String get hinduYearEra => 'हिन्दू वर्ष संवत्';

  @override
  String get hinduYearEraSubtitle => 'वर्ष प्रदर्शन के लिए पंचांग संवत् चुनें';

  @override
  String get tithiDisplay => 'तिथि प्रदर्शन';

  @override
  String get tithiDisplayPakshaRange => 'पक्ष (१-१५)';

  @override
  String get tithiDisplaySubtitle =>
      'चुनें कि पंचांग में तिथियाँ कैसे गिनी जाएँ';

  @override
  String get tithiDisplayPakshaBased => 'पक्ष आधारित';

  @override
  String get tithiDisplayPakshaDescription =>
      'प्रत्येक पक्ष के लिए अलग से १-१५ दिखाएँ';

  @override
  String get tithiDisplayContinuousDescription => 'लगातार १-३० दिखाएँ';

  @override
  String festivalExportShareSubject(String year) {
    return 'तिथि त्योहार $year';
  }

  @override
  String festivalExportShareText(String year) {
    return 'पंचांग विवरण के साथ तिथि त्योहार $year (JSON)';
  }

  @override
  String countdownAddedForFestival(String festivalName) {
    return '$festivalName के लिए काउंटडाउन जोड़ा गया';
  }

  @override
  String festivalAlreadyInCountdowns(String festivalName) {
    return '$festivalName पहले से ही आपके काउंटडाउन में है';
  }

  @override
  String get openStreetMapAttribution => 'OpenStreetMap योगदानकर्ता';

  @override
  String get moonScrubHint => 'देखने के लिए खींचें • डबल-टैप से रीसेट';

  @override
  String moonIllumination(String percentage) {
    return 'प्रकाशित: $percentage%';
  }

  @override
  String get dayUnitShort => 'दि';

  @override
  String get hourUnitShort => 'घं';

  @override
  String get minuteUnitShort => 'मि';

  @override
  String durationHoursMinutesShort(int hours, int minutes) {
    return '$hoursघं $minutesमि';
  }

  @override
  String durationMinutesShort(int minutes) {
    return '$minutesमि';
  }

  @override
  String distanceAstronomicalUnits(String distance) {
    return '$distance AU';
  }

  @override
  String orbitalPeriodDaysShort(String days) {
    return '$daysदि';
  }

  @override
  String orbitalPeriodYearsShort(String years) {
    return '$yearsव';
  }

  @override
  String get vikramSamvat => 'विक्रम संवत्';

  @override
  String get shakaEra => 'शक संवत्';

  @override
  String get bengaliEra => 'बंगाली संवत्';

  @override
  String get selectYear => 'वर्ष चुनें';

  @override
  String bengaliEraYear(int year) {
    return '$year बंगाब्द';
  }

  @override
  String get monthJanuary => 'जनवरी';

  @override
  String get monthFebruary => 'फ़रवरी';

  @override
  String get monthMarch => 'मार्च';

  @override
  String get monthApril => 'अप्रैल';

  @override
  String get monthMay => 'मई';

  @override
  String get monthJune => 'जून';

  @override
  String get monthJuly => 'जुलाई';

  @override
  String get monthAugust => 'अगस्त';

  @override
  String get monthSeptember => 'सितंबर';

  @override
  String get monthOctober => 'अक्टूबर';

  @override
  String get monthNovember => 'नवंबर';

  @override
  String get monthDecember => 'दिसंबर';

  @override
  String get weekdaySundayShort => 'रवि';

  @override
  String get weekdayMondayShort => 'सोम';

  @override
  String get weekdayTuesdayShort => 'मंगल';

  @override
  String get weekdayWednesdayShort => 'बुध';

  @override
  String get weekdayThursdayShort => 'गुरु';

  @override
  String get weekdayFridayShort => 'शुक्र';

  @override
  String get weekdaySaturdayShort => 'शनि';

  @override
  String get sharedViaTithiApp => 'तिथि ऐप के माध्यम से साझा किया गया';

  @override
  String get dailyWisdomShareMessage => 'दैनिक ज्ञान — तिथि ऐप';

  @override
  String get shareAsImage => 'छवि के रूप में साझा करें';

  @override
  String get verseCardPicture => 'श्लोक कार्ड की छवि';

  @override
  String get shareAsText => 'पाठ के रूप में साझा करें';

  @override
  String get verseWithTranslation => 'अनुवाद सहित श्लोक';

  @override
  String get copyText => 'पाठ कॉपी करें';

  @override
  String get copyVerseToClipboard => 'श्लोक क्लिपबोर्ड पर कॉपी करें';

  @override
  String get couldNotCopyVerse => 'श्लोक कॉपी नहीं हो सका';

  @override
  String get verseCopied => 'श्लोक कॉपी हो गया';

  @override
  String chosenForFestival(String festivalName) {
    return '$festivalName के लिए चुना गया';
  }

  @override
  String get showLess => 'कम दिखाएँ';

  @override
  String get showMoreTranslations => 'और अनुवाद दिखाएँ';

  @override
  String get hideTranslation => 'अनुवाद छिपाएँ';

  @override
  String get showTranslation => 'अनुवाद दिखाएँ';

  @override
  String get showLessTitleCase => 'कम दिखाएँ';

  @override
  String get readMore => 'और पढ़ें';

  @override
  String tithiNameWithNumber(String tithiName, int number) {
    return '$tithiName (ति$number)';
  }

  @override
  String get masa => 'मास';

  @override
  String get nakshatra => 'नक्षत्र';

  @override
  String get begins => 'प्रारंभ';

  @override
  String get ends => 'समाप्ति';

  @override
  String tithiWithNumber(int number) {
    return 'तिथि $number';
  }

  @override
  String get fastingVrat => 'उपवास / व्रत';

  @override
  String get mantra => 'मंत्र';

  @override
  String get timingNote => 'समय संबंधी टिप्पणी';

  @override
  String get timingNoteDescription =>
      'समय निर्देशांकों के आधार पर खगोलीय गणना से निकाले जाते हैं, और वायुमंडलीय अपवर्तन, ऊँचाई या गणना विधियों के कारण स्थानीय मंदिर पंचांग से कुछ मिनटों का अंतर हो सकता है।';

  @override
  String get noFestivalsInNextThreeDays => 'अगले ३ दिनों में कोई त्योहार नहीं';

  @override
  String couldNotLoadFestivalsWithError(String error) {
    return 'त्योहार लोड नहीं हो सके: $error';
  }

  @override
  String viewAllFestivalsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'सभी $count त्योहार देखें',
      one: 'सभी $count त्योहार देखें',
    );
    return '$_temp0';
  }

  @override
  String get viewAllFestivals => 'सभी त्योहार देखें';

  @override
  String get day => 'दिन';

  @override
  String festivalCountdownTitle(String title) {
    return '$title काउंटडाउन';
  }

  @override
  String festivalInDays(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days दिनों में',
      one: '१ दिन में',
    );
    return '$_temp0';
  }

  @override
  String get searchFestivalsVratsAndEvents =>
      'त्योहार, व्रत और कार्यक्रम खोजें';

  @override
  String get homeScreenWidget => 'होम स्क्रीन विजेट';

  @override
  String get homeWidgetCountdownDescription =>
      'अपनी होम स्क्रीन पर त्योहार काउंटडाउन जोड़ें';

  @override
  String get homeWidgetManualHint =>
      'होम स्क्रीन को देर तक दबाएँ → विजेट → तिथि';

  @override
  String get homeWidgetManualInstructions =>
      '१. अपनी होम स्क्रीन को देर तक दबाएँ\n२. \"विजेट\" पर टैप करें\n३. \"तिथि\" खोजें और \"त्योहार काउंटडाउन\" को होम स्क्रीन पर खींचें\n\nविजेट आपके काउंटडाउन पेज के सभी त्योहार दिखाता है।';

  @override
  String get unableToLoadMoonPhaseData => 'चंद्र कला का डेटा लोड नहीं हो सका';

  @override
  String get countdownNow => 'अभी';

  @override
  String countdownDaysHours(int days, int hours) {
    return '$daysदि $hoursघं';
  }

  @override
  String get selected => 'चयनित';

  @override
  String moonPhaseIlluminated(String phase, String percentage) {
    return '$phase · $percentage% प्रकाशित';
  }

  @override
  String nextTithiAt(String tithiName, String time) {
    return 'अगली तिथि $tithiName, समय $time';
  }

  @override
  String tithiBeginsAt(String tithiName, String time) {
    return '$tithiName प्रारंभ होगी $time पर';
  }

  @override
  String tithiEndsAtDateTime(String tithiName, String dateTime) {
    return '$tithiName समाप्त होगी $dateTime';
  }

  @override
  String get udayaTithiExplanation =>
      'उदय तिथि: सूर्योदय के समय प्रचलित तिथि। एक छोटी तिथि दो सूर्योदयों के बीच आरंभ और समाप्त हो सकती है — कोई तिथि छूट न जाए, इसलिए दोनों तिथियाँ ऊपर दिखाई गई हैं।';

  @override
  String get beginsUppercase => 'प्रारंभ';

  @override
  String get endsUppercase => 'समाप्ति';

  @override
  String get transition => 'संक्रमण';

  @override
  String get shuklaPakshaInitial => 'शु';

  @override
  String get krishnaPakshaInitial => 'कृ';

  @override
  String windSpeedKph(double speed) {
    return '$speed किमी/घंटा';
  }

  @override
  String get tithiDisplayThirtyDays => '३० दिन';

  @override
  String get couldNotCreateImage => 'छवि नहीं बनाई जा सकी';

  @override
  String get shareVerse => 'श्लोक साझा करें';

  @override
  String get previousDaysVerse => 'पिछले दिन का श्लोक';

  @override
  String get nextDaysVerse => 'अगले दिन का श्लोक';

  @override
  String get shareCard => 'कार्ड साझा करें';

  @override
  String get homeWidgetCanPin => 'अपनी होम स्क्रीन पर त्योहार काउंटडाउन जोड़ें';

  @override
  String get dailyWisdom => 'दैनिक ज्ञान';

  @override
  String get tithiTimings => 'तिथि समय';

  @override
  String get tithiBegins => 'प्रारंभ';

  @override
  String get tithiEnds => 'समाप्ति';

  @override
  String get tithiTransition => 'संक्रमण';

  @override
  String get udayaTithiExplainer =>
      'उदय तिथि: सूर्योदय के समय प्रचलित तिथि। एक छोटी तिथि दो सूर्योदयों के बीच आरंभ और समाप्त हो सकती है — कोई तिथि छूट न जाए, इसलिए दोनों तिथियाँ ऊपर दिखाई गई हैं।';
}
