// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Bengali Bangla (`bn`).
class AppLocalizationsBn extends AppLocalizations {
  AppLocalizationsBn([String locale = 'bn']) : super(locale);

  @override
  String get appTitle => 'তিথি';

  @override
  String get exportFestivalsJson => 'উৎসব এক্সপোর্ট করুন (JSON)';

  @override
  String get exportFestivalsSubtitle =>
      'সব উৎসব পঞ্জিকার বিবরণসহ একটি ফাইলে সংরক্ষণ করুন';

  @override
  String get exportFestivals => 'উৎসব এক্সপোর্ট করুন';

  @override
  String get exportFestivalsSubtitleYear =>
      'নির্বাচিত বছরে প্রতিটি উৎসবের প্রথম উদযাপন';

  @override
  String get vedaCalendar => 'বৈদিক পঞ্জিকা';

  @override
  String get settings => 'সেটিংস';

  @override
  String get appearance => 'চেহারা';

  @override
  String get preferences => 'পছন্দসমূহ';

  @override
  String get calendar => 'পঞ্জিকা';

  @override
  String get dataStorage => 'ডেটা এবং সঞ্চয়';

  @override
  String get accessibility => 'অ্যাক্সেসিবিলিটি';

  @override
  String get about => 'সম্পর্কে';

  @override
  String get themeAuto => 'স্বয়ংক্রিয়';

  @override
  String get themeShukla => 'শুক্ল';

  @override
  String get themeDark => 'গাঢ়';

  @override
  String get themeKrishna => 'কৃষ্ণ';

  @override
  String get dailyNotifications => 'দৈনিক বিজ্ঞপ্তি';

  @override
  String get notificationScheduled => 'দৈনিক নির্ধারিত';

  @override
  String get getNotifiedTithiDaily => 'প্রতিদিন তিথির বিজ্ঞপ্তি পান';

  @override
  String get notificationTime => 'বিজ্ঞপ্তির সময়';

  @override
  String get autoLocation => 'স্বয়ংক্রিয় অবস্থান';

  @override
  String get useGpsForTithi => 'সঠিক তিথি গণনার জন্য GPS ব্যবহার করুন';

  @override
  String usingLocation(String cityName) {
    return 'ব্যবহৃত হচ্ছে: $cityName';
  }

  @override
  String get fetchingLocation => 'অবস্থান সনাক্ত করা হচ্ছে...';

  @override
  String get locationUnavailable => 'অবস্থান অনুপলব্ধ';

  @override
  String get homeLocation => 'বাড়ির অবস্থান';

  @override
  String get notSet => 'সেট করা হয়নি';

  @override
  String get setHomeLocation => 'বাড়ির অবস্থান সেট করুন';

  @override
  String get dragMapToPin => 'মানচিত্র টেনে আপনার বাড়ির ওপর পিন রাখুন';

  @override
  String get setThisLocation => 'এই অবস্থান সেট করুন';

  @override
  String homeLocationSetTo(String address) {
    return 'বাড়ির অবস্থান $address-এ সেট করা হয়েছে';
  }

  @override
  String errorSettingLocation(String error) {
    return 'অবস্থান সেট করতে ত্রুটি: $error';
  }

  @override
  String get startOfWeek => 'সপ্তাহের শুরু';

  @override
  String get sunday => 'রবিবার';

  @override
  String get monday => 'সোমবার';

  @override
  String get primaryView => 'প্রাথমিক দৃশ্য';

  @override
  String get tithi => 'তিথি';

  @override
  String get tithiPratipada => 'প্রতিপদ';

  @override
  String get tithiDwitiya => 'দ্বিতীয়া';

  @override
  String get tithiTritiya => 'তৃতীয়া';

  @override
  String get tithiChaturthi => 'চতুর্থী';

  @override
  String get tithiPanchami => 'পঞ্চমী';

  @override
  String get tithiShashthi => 'ষষ্ঠী';

  @override
  String get tithiSaptami => 'সপ্তমী';

  @override
  String get tithiAshtami => 'অষ্টমী';

  @override
  String get tithiNavami => 'নবমী';

  @override
  String get tithiDashami => 'দশমী';

  @override
  String get tithiEkadashi => 'একাদশী';

  @override
  String get tithiDwadashi => 'দ্বাদশী';

  @override
  String get tithiTrayodashi => 'ত্রয়োদশী';

  @override
  String get tithiChaturdashi => 'চতুর্দশী';

  @override
  String get tithiPurnima => 'পূর্ণিমা';

  @override
  String get tithiAmavasya => 'অমাবস্যা';

  @override
  String get tithiUnknown => 'অজানা';

  @override
  String get festival => 'উৎসব';

  @override
  String get moon => 'চাঁদ';

  @override
  String get primaryCalendar => 'প্রাথমিক পঞ্জিকা';

  @override
  String get secondaryCalendar => 'দ্বিতীয় পঞ্জিকা';

  @override
  String get selectPrimaryCalendar => 'প্রাথমিক পঞ্জিকা নির্বাচন করুন';

  @override
  String get selectSecondaryCalendar => 'দ্বিতীয় পঞ্জিকা নির্বাচন করুন';

  @override
  String get clearLocationCache => 'অবস্থান ক্যাশ সাফ করুন';

  @override
  String get locationCacheCleared => 'অবস্থান ক্যাশ সাফ করা হয়েছে';

  @override
  String get resetAppSettings => 'অ্যাপ সেটিংস রিসেট করুন';

  @override
  String get resetSettingsTitle => 'সেটিংস রিসেট করবেন?';

  @override
  String get resetSettingsMessage =>
      'এটি আপনার সমস্ত পছন্দ এবং ডেটা ডিফল্টে রিসেট করবে। এটি পূর্বাবস্থায় ফেরানো যাবে না।';

  @override
  String get cancel => 'বাতিল';

  @override
  String get reset => 'রিসেট';

  @override
  String get appResetComplete => 'অ্যাপ রিসেট সম্পূর্ণ';

  @override
  String get reduceMotion => 'গতি কমান';

  @override
  String get disableAnimations => 'অ্যানিমেশন এবং ইফেক্ট বন্ধ করুন';

  @override
  String get hapticFeedback => 'হ্যাপটিক ফিডব্যাক';

  @override
  String get vibrateOnTouch => 'স্পর্শে কম্পন';

  @override
  String get highContrast => 'উচ্চ কনট্রাস্ট';

  @override
  String get solidBackgrounds => 'ভালো পাঠযোগ্যতার জন্য এক রঙের পটভূমি';

  @override
  String get largeText => 'বড় টেক্সট';

  @override
  String get increaseTextSize => 'বিশ্বব্যাপী টেক্সটের আকার বাড়ান';

  @override
  String get language => 'ভাষা';

  @override
  String get selectLanguage => 'ভাষা নির্বাচন করুন';

  @override
  String get systemDefault => 'সিস্টেম ডিফল্ট';

  @override
  String get privacyPolicy => 'গোপনীয়তা নীতি';

  @override
  String get madeWithLove => 'সনাতন ধর্মের জন্য ভালোবাসা ❤️ দিয়ে তৈরি';

  @override
  String get shareApp => 'অ্যাপ শেয়ার করুন';

  @override
  String get shareAppMessage =>
      'তিথি - বৈদিক পঞ্জিকা অ্যাপ দেখুন! এখনই ডাউনলোড করুন: https://tithiapp.netlify.app/';

  @override
  String get rateUs => 'রেটিং দিন';

  @override
  String get aboutApp => 'সম্পর্কে';

  @override
  String get calendarView => 'পঞ্জিকা দৃশ্য';

  @override
  String get scheduleView => 'সূচি দৃশ্য';

  @override
  String get switchToCalendar => 'মাসিক পঞ্জিকায় যান';

  @override
  String get switchToSchedule => 'ইভেন্ট তালিকায় যান';

  @override
  String versionText(String version) {
    return 'সংস্করণ $version';
  }

  @override
  String get events => 'ইভেন্টস';

  @override
  String get festivalsAndEvents => 'উৎসব এবং ইভেন্ট';

  @override
  String get noFestivalsOnThisDay => 'এই দিনে কোনো উৎসব নেই';

  @override
  String get todaysFestival => 'আজকের উৎসব';

  @override
  String get noFestivalsToday => 'তিথি • আজ কোনো উৎসব নেই';

  @override
  String errorLoadingPanchang(String error) {
    return 'পঞ্জিকা লোড করতে ত্রুটি: $error';
  }

  @override
  String get panchangDetails => 'পঞ্জিকা বিবরণ';

  @override
  String get paksha => 'পক্ষ';

  @override
  String pakshaWithName(String paksha) {
    return '$paksha পক্ষ';
  }

  @override
  String get waxing => 'শুক্ল';

  @override
  String get waning => 'কৃষ্ণ';

  @override
  String get waxingMoonPhase => 'শুক্ল পক্ষ - বর্ধমান চাঁদ';

  @override
  String get waningMoonPhase => 'কৃষ্ণ পক্ষ - ক্ষীয়মাণ চাঁদ';

  @override
  String get category => 'বিভাগ';

  @override
  String get general => 'সাধারণ';

  @override
  String get ritualsAndPractices => 'আচার এবং সাধনা';

  @override
  String get locationAccess => 'অবস্থান অ্যাক্সেস';

  @override
  String get enableLocation => 'অবস্থান সক্ষম করুন';

  @override
  String get skip => 'এড়িয়ে যান';

  @override
  String get locationAccessDescription =>
      'তিথি আপনার শহরের জন্য সঠিক পঞ্জিকা ডেটা গণনা করতে আপনার অবস্থান ব্যবহার করে।';

  @override
  String get locationAccessBenefits =>
      '• আরও সঠিক তিথি গণনা\n• অবস্থান-নির্দিষ্ট চন্দ্রোদয়/সূর্যাস্তের সময়\n• আপনার অবস্থান ডেটা আপনার ডিভাইসে থাকে';

  @override
  String get locationDisabled => 'অবস্থান অক্ষম';

  @override
  String get locationDisabledMessage =>
      'অবস্থান অক্ষম আছে। আপনার শহরের উপর ভিত্তি করে আরও সঠিক পঞ্জিকা গণনার জন্য এটি সক্ষম করুন।';

  @override
  String get notNow => 'এখন নয়';

  @override
  String get enable => 'সক্ষম করুন';

  @override
  String get pleaseEnableLocationServices =>
      'অনুগ্রহ করে আপনার ডিভাইসে অবস্থান পরিষেবা সক্ষম করুন';

  @override
  String get locationPermissionDenied =>
      'অবস্থান অনুমতি অস্বীকার করা হয়েছে। ডিফল্ট অবস্থান ব্যবহার করা হচ্ছে।';

  @override
  String get locationEnabledSuccess => 'অবস্থান সফলভাবে সক্ষম হয়েছে!';

  @override
  String get refreshLocation => 'অবস্থান রিফ্রেশ করুন';

  @override
  String get goToToday => 'আজকে যান';

  @override
  String get initializing => 'শুরু হচ্ছে...';

  @override
  String get privacyYourDataStays => 'আপনার ডেটা আপনার কাছে থাকে';

  @override
  String get privacyYourDataDesc =>
      'তিথি গোপনীয়তা-প্রথম, অফলাইন-প্রথম আর্কিটেকচার দিয়ে ডিজাইন করা হয়েছে। সমস্ত জ্যোতির্বিদ্যা গণনা, পঞ্জিকা তৈরি এবং ইভেন্ট প্রক্রিয়াকরণ সরাসরি আপনার ডিভাইসে হয় এবং নেটওয়ার্ক ছাড়াই অ্যাপটি কাজ করতে থাকে। আমরা কোনো বাহ্যিক সার্ভারে আপনার ব্যক্তিগত ডেটা সংগ্রহ, সঞ্চয় বা প্রেরণ করি না।';

  @override
  String get privacyLocationUsage => 'অবস্থান ব্যবহার';

  @override
  String get privacyLocationDesc =>
      'আমরা শুধুমাত্র সঠিক তিথি, নক্ষত্র এবং সূর্যোদয়/সূর্যাস্তের সময় গণনা করতে আপনার অবস্থানে অ্যাক্সেসের অনুরোধ করি, যা আপনার নির্দিষ্ট ভৌগলিক স্থানাঙ্কের উপর নির্ভর করে। আপনার অবস্থানের ডেটা অ্যাপের মাধ্যমে স্থানীয়ভাবেই প্রক্রিয়া হয় এবং কখনও তৃতীয় পক্ষের সাথে শেয়ার করা হয় না বা আমাদের সার্ভারে সংরক্ষণ করা হয় না।';

  @override
  String get privacyOffline => 'অফলাইন কার্যকারিতা';

  @override
  String get privacyOfflineDesc =>
      'অ্যাপটি সম্পূর্ণ অফলাইনে কাজ করে। উচ্চ-নির্ভুলতার গ্রহ গণনার জন্য প্রয়োজনীয় সুইস এফেমেরিস ডেটা অ্যাপের ভেতরেই এম্বেড করা আছে।';

  @override
  String get privacyOpenSource => 'ওপেন সোর্স স্বচ্ছতা';

  @override
  String get privacyOpenSourceDesc =>
      'তিথি একটি ওপেন-সোর্স প্রকল্প। আমাদের কোড নিরীক্ষার জন্য সর্বজনীনভাবে উপলব্ধ, যা নিশ্চিত করে যে আমাদের গোপনীয়তা প্রতিশ্রুতি যাচাইযোগ্য স্বচ্ছতা দ্বারা সমর্থিত। যা দেখা যায়, ঠিক তাই পাওয়া যায়।';

  @override
  String get lastUpdated => 'শেষ আপডেট: ডিসেম্বর ২০২৫';

  @override
  String get applicationLegalese =>
      '© ২০২৫ তিথি প্রকল্প\nসনাতন ধর্মের জন্য ভালোবাসা ❤️ দিয়ে তৈরি';

  @override
  String get moonPhases => 'চাঁদের কলা';

  @override
  String get nextPurnima => 'পরবর্তী পূর্ণিমা';

  @override
  String get nextAmavasya => 'পরবর্তী অমাবস্যা';

  @override
  String get purnima => 'পূর্ণিমা';

  @override
  String get amavasya => 'অমাবস্যা';

  @override
  String get fullMoon => 'পূর্ণ চাঁদ';

  @override
  String get newMoon => 'নতুন চাঁদ';

  @override
  String get noUpcomingDates => 'কোনো আসন্ন তারিখ পাওয়া যায়নি';

  @override
  String get errorLoadingData => 'ডেটা লোড করতে ত্রুটি';

  @override
  String get retry => 'আবার চেষ্টা করুন';

  @override
  String get astronomy => 'জ্যোতির্বিজ্ঞান';

  @override
  String get solarSystem => 'সৌরজগৎ';

  @override
  String get planetPositions => 'গ্রহের অবস্থান';

  @override
  String get selectDate => 'তারিখ নির্বাচন করুন';

  @override
  String get retrograde => 'বক্র';

  @override
  String get zodiacSign => 'রাশি';

  @override
  String get degree => 'অংশ';

  @override
  String get longitude => 'রেখাংশ';

  @override
  String get eclipses => 'গ্রহণ';

  @override
  String get solarEclipses => 'সূর্যগ্রহণ';

  @override
  String get lunarEclipses => 'চন্দ্রগ্রহণ';

  @override
  String get maxEclipse => 'সর্বোচ্চ গ্রহণ';

  @override
  String get visibleFromYourLocation => 'আপনার অবস্থান থেকে দেখা যাবে';

  @override
  String get notVisibleFromYourLocation => 'আপনার অবস্থান থেকে দেখা যাবে না';

  @override
  String get partialBegins => 'আংশিক পর্যায় শুরু';

  @override
  String get partialEnds => 'আংশিক পর্যায় শেষ';

  @override
  String get totalityBegins => 'পূর্ণ পর্যায় শুরু';

  @override
  String get totalityEnds => 'পূর্ণ পর্যায় শেষ';

  @override
  String get duration => 'সময়কাল';

  @override
  String get date => 'তারিখ';

  @override
  String get days => 'দিন';

  @override
  String get today => 'আজ';

  @override
  String illuminatedPercent(String percent) {
    return '$percent% আলোকিত';
  }

  @override
  String get nextTithi => 'পরবর্তী তিথি';

  @override
  String atTime(String time) {
    return '$time-এ';
  }

  @override
  String get yesterday => 'গতকাল';

  @override
  String get tomorrow => 'আগামীকাল';

  @override
  String daysFromNow(int days) {
    return '$days দিন';
  }

  @override
  String get now => 'এখন!';

  @override
  String get currentMoonPhase => 'বর্তমান চন্দ্র পর্যায় দৃশ্য';

  @override
  String get mapPinLocation => 'মানচিত্র পিন অবস্থান';

  @override
  String get nearbyTemples => 'কাছাকাছি মন্দির';

  @override
  String get searchHere => 'এখানে খুঁজুন';

  @override
  String get loadMore => 'আরও লোড করুন';

  @override
  String get templeMarker => 'মন্দির মার্কার';

  @override
  String kmAway(String distance) {
    return '$distance কিমি দূরে';
  }

  @override
  String get nearby => 'কাছাকাছি';

  @override
  String get getDirections => 'দিকনির্দেশ পান';

  @override
  String get couldNotOpenMaps => 'মানচিত্র খোলা যায়নি';

  @override
  String errorLaunchingMaps(String error) {
    return 'মানচিত্র চালু করতে ত্রুটি: $error';
  }

  @override
  String get templeSearchFailed =>
      'কাছাকাছি মন্দির পাওয়া যায়নি। আবার চেষ্টা করুন।';

  @override
  String get yourLocation => 'আপনার অবস্থান';

  @override
  String get newIntention => 'নতুন সংকল্প';

  @override
  String get whatIsYourSankalpa => 'আপনার সংকল্প কী?';

  @override
  String get intentionTitle => 'সংকল্পের শিরোনাম';

  @override
  String get intentionTitleHint => 'যেমন: ১০৮ বার গায়ত্রী মন্ত্র জপ';

  @override
  String get pleaseEnterTitle => 'দয়া করে একটি শিরোনাম লিখুন';

  @override
  String get descriptionOptional => 'বিবরণ (ঐচ্ছিক)';

  @override
  String get descriptionHint => 'বিশেষ বিবরণ বা মন্ত্রের পাঠ যোগ করুন...';

  @override
  String get durationDays => 'সময়কাল (দিন)';

  @override
  String daysCount(int count) {
    return '$count দিন';
  }

  @override
  String get custom => 'কাস্টম';

  @override
  String get customDays => 'কাস্টম দিন';

  @override
  String get dailyReminderTime => 'দৈনিক রিমাইন্ডারের সময়';

  @override
  String get createSankalpa => 'সংকল্প তৈরি করুন';

  @override
  String get save => 'সংরক্ষণ করুন';

  @override
  String get sankalpaCreatedSuccessfully => 'সংকল্প সফলভাবে তৈরি হয়েছে!';

  @override
  String failedToSaveSankalpa(String error) {
    return 'সংকল্প সংরক্ষণে ব্যর্থ: $error';
  }

  @override
  String get mySankalpas => 'আমার সংকল্পসমূহ';

  @override
  String get active => 'সক্রিয়';

  @override
  String get completed => 'সম্পন্ন';

  @override
  String get noCompletedIntentionsYet => 'এখনও কোনো সম্পন্ন সংকল্প নেই';

  @override
  String get startNewSpiritualJourney =>
      'একটি নতুন আধ্যাত্মিক যাত্রা শুরু করুন';

  @override
  String get deleteSankalpa => 'সংকল্প মুছে ফেলবেন?';

  @override
  String get deleteSankalpaMessage => 'এই কাজটি ফিরিয়ে আনা যাবে না।';

  @override
  String get delete => 'মুছুন';

  @override
  String get markCompleteIncomplete => 'সম্পন্ন/অসম্পন্ন চিহ্নিত করুন';

  @override
  String dayOf(int current, int total) {
    return 'দিন $current / $total';
  }

  @override
  String get doneForToday => 'আজকের জন্য সম্পন্ন';

  @override
  String get markTodayAsDone => 'আজ সম্পন্ন হিসেবে চিহ্নিত করুন';

  @override
  String reminderAt(String time) {
    return 'রিমাইন্ডার: $time';
  }

  @override
  String completedOn(String date) {
    return 'সম্পন্ন হয়েছে: $date';
  }

  @override
  String get weatherDetails => 'আবহাওয়ার বিবরণ';

  @override
  String get weatherDataUnavailable => 'আবহাওয়ার তথ্য পাওয়া যায়নি';

  @override
  String errorMessage(String error) {
    return 'ত্রুটি: $error';
  }

  @override
  String get weatherDataByOpenMeteo => 'Open-Meteo থেকে আবহাওয়ার তথ্য';

  @override
  String weatherCondition(String condition) {
    return 'আবহাওয়ার অবস্থা: $condition';
  }

  @override
  String get sunrise => 'সূর্যোদয়';

  @override
  String get sunset => 'সূর্যাস্ত';

  @override
  String get moonrise => 'চন্দ্রোদয়';

  @override
  String get moonset => 'চন্দ্রাস্ত';

  @override
  String get humidity => 'আর্দ্রতা';

  @override
  String get wind => 'বাতাস';

  @override
  String get realFeel => 'অনুভূত তাপমাত্রা';

  @override
  String get uvIndex => 'ইউভি সূচক';

  @override
  String get forecast => 'পূর্বাভাস';

  @override
  String daylightDuration(int hours, int minutes) {
    return 'দিনের আলো: $hoursঘ $minutesমি';
  }

  @override
  String get searchFestivals => 'উৎসব খুঁজুন';

  @override
  String get permissionRequired => 'অনুমতি প্রয়োজন';

  @override
  String get locationPermissionPermanentlyDenied =>
      'অবস্থান অনুমতি স্থায়ীভাবে অস্বীকৃত হয়েছে। অনুগ্রহ করে ডিভাইস সেটিংসে এটি চালু করুন।';

  @override
  String get openSettings => 'সেটিংস খুলুন';

  @override
  String get selectMonth => 'মাস নির্বাচন করুন';

  @override
  String get recenterMap => 'মানচিত্র পুনরায় কেন্দ্র করুন';

  @override
  String get zoomIn => 'জুম ইন';

  @override
  String get zoomOut => 'জুম আউট';

  @override
  String get back30Days => '৩০ দিন পিছনে';

  @override
  String get back1Day => '১ দিন পিছনে';

  @override
  String get forward1Day => '১ দিন সামনে';

  @override
  String get forward30Days => '৩০ দিন সামনে';

  @override
  String get playAnimation => 'অ্যানিমেশন চালান';

  @override
  String get pauseAnimation => 'অ্যানিমেশন বিরতি দিন';

  @override
  String get speedLabel => 'গতি';

  @override
  String get heliocentric => 'সূর্যকেন্দ্রিক';

  @override
  String get geocentric => 'ভূকেন্দ্রিক';

  @override
  String get distance => 'দূরত্ব';

  @override
  String get orbit => 'কক্ষপথ';

  @override
  String get festivalCountdowns => 'উৎসব কাউন্টডাউন';

  @override
  String get addCountdown => 'কাউন্টডাউন যোগ করুন';

  @override
  String get countdownHeading => 'উৎসব কাউন্টডাউন';

  @override
  String get zeroDays => '০';

  @override
  String daysRemaining(Object days) {
    return '$days দিন বাকি';
  }

  @override
  String get removeFromHomeScreen => 'হোম স্ক্রিন থেকে সরান';

  @override
  String get removeCountdown => 'কাউন্টডাউন সরান';

  @override
  String get countdownRemoved => 'কাউন্টডাউন সরানো হয়েছে';

  @override
  String get searchFestivalName => 'উৎসবের নাম খুঁজুন';

  @override
  String get noFestivalsFound => 'কোন উৎসব পাওয়া যায়নি';

  @override
  String get noCountdownsYet => 'এখনও কোনো কাউন্টডাউন নেই';

  @override
  String get allFestivals => 'সব উৎসব';

  @override
  String get searchFestivalsHint => 'উৎসব খুঁজুন';

  @override
  String get couldNotLoadFestivals => 'উৎসব লোড করা যায়নি। আবার চেষ্টা করুন।';

  @override
  String get oopsSomethingWentWrong => 'আরে! কিছু একটা ভুল হয়ে গেছে';

  @override
  String get unexpectedErrorOccurred =>
      'একটি অপ্রত্যাশিত ত্রুটি ঘটেছে। আবার চেষ্টা করুন।';

  @override
  String get somethingWentWrong => 'কিছু একটা ভুল হয়ে গেছে';

  @override
  String get unableToOpenPrivacyPolicy =>
      'গোপনীয়তা নীতির ওয়েবসাইট খোলা যায়নি।';

  @override
  String failedToShare(String error) {
    return 'শেয়ার করতে ব্যর্থ: $error';
  }

  @override
  String celebratingFestivalWithTithi(String festivalName) {
    return 'তিথি অ্যাপের সাথে $festivalName উদযাপন করুন!';
  }

  @override
  String get gotIt => 'বুঝেছি';

  @override
  String get add => 'যোগ করুন';

  @override
  String get addWidgetManually => 'উইজেট ম্যানুয়ালি যোগ করুন';

  @override
  String get widgetPinRequested =>
      'উইজেট পিনের অনুরোধ করা হয়েছে — হোম স্ক্রিনে নিশ্চিত করুন';

  @override
  String get couldNotPinWidget =>
      'উইজেট পিন করা যায়নি। ম্যানুয়ালি যোগ করার চেষ্টা করুন: দীর্ঘক্ষণ চেপে ধরুন → উইজেট → তিথি';

  @override
  String get infoTooltip => 'তথ্য';

  @override
  String get dismissTooltip => 'বন্ধ করুন';

  @override
  String get solarSystemNotAvailableOnWeb => 'ওয়েবে সৌরজগৎ উপলব্ধ নেই';

  @override
  String get eclipseScreenNotAvailableOnWeb =>
      'ওয়েবে গ্রহণ স্ক্রিন উপলব্ধ নেই';

  @override
  String get findingNextOccurrence => 'পরবর্তী উদযাপন খোঁজা হচ্ছে...';

  @override
  String get goToNextOccurrence => 'পরবর্তী উদযাপনে যান';

  @override
  String get couldNotFindUpcomingOccurrence =>
      'এক বছরের মধ্যে কোনো আসন্ন উদযাপন পাওয়া যায়নি।';

  @override
  String get noFestivalsToExport => 'এক্সপোর্ট করার মতো কোনো উৎসব নেই';

  @override
  String exportingYear(String year) {
    return '$year এক্সপোর্ট করা হচ্ছে';
  }

  @override
  String festivalsExportedProgress(int done, int total) {
    return '$done / $total উৎসব';
  }

  @override
  String get exportCancelled => 'এক্সপোর্ট বাতিল করা হয়েছে';

  @override
  String get downloadStarted => 'ডাউনলোড শুরু হয়েছে';

  @override
  String get couldNotSaveExportFile => 'এক্সপোর্ট ফাইল সংরক্ষণ করা যায়নি';

  @override
  String get saved => 'সংরক্ষিত হয়েছে';

  @override
  String festivalsExportedForYear(int count, String year) {
    return '$year সালের জন্য $countটি উৎসব এক্সপোর্ট করা হয়েছে।';
  }

  @override
  String get done => 'সম্পন্ন';

  @override
  String get share => 'শেয়ার করুন';

  @override
  String exportFailed(String error) {
    return 'এক্সপোর্ট ব্যর্থ: $error';
  }

  @override
  String saveFestivalsYear(String year) {
    return '$year সালের উৎসব সংরক্ষণ করুন';
  }

  @override
  String get aboutBuiltForDailyPractice => 'প্রতিদিনের সাধনার জন্য তৈরি';

  @override
  String get aboutDailyPracticeDescription =>
      'তিথি ঐতিহ্যবাহী পঞ্জিকার জ্ঞানকে আধুনিক স্পষ্টতার সাথে মিলিয়ে দেয়, যাতে আপনার আচার-অনুষ্ঠান ও ব্রত সময়মতো এবং সহজভাবে পালন করতে পারেন।';

  @override
  String get aboutWhatsInside => 'ভেতরে কী আছে';

  @override
  String get aboutFeaturesDescription =>
      'নির্ভুল তিথি ও নক্ষত্র হিসাব, উৎসবের কাউন্টডাউন, স্থানীয় সূর্যোদয় ও সূর্যাস্ত, এবং প্রতিদিনের শান্ত অনুপ্রেরণা।';

  @override
  String get detailedPrivacyPolicy => 'বিস্তারিত গোপনীয়তা নীতি';

  @override
  String get readFullPrivacyPolicy => 'আমাদের ওয়েবসাইটে সম্পূর্ণ নীতি পড়ুন';

  @override
  String get aboutTagline => 'আধুনিক জীবনের জন্য বৈদিক পঞ্জিকা';

  @override
  String get themePurple => 'বেগুনি';

  @override
  String get notificationPermissionDenied =>
      'বিজ্ঞপ্তির অনুমতি দেওয়া হয়নি। অনুগ্রহ করে সিস্টেম সেটিংসে এটি চালু করুন।';

  @override
  String notificationToggleFailed(String state, String error) {
    String _temp0 = intl.Intl.selectLogic(state, {
      'on': 'চালু',
      'other': 'বন্ধ',
    });
    return 'বিজ্ঞপ্তি $_temp0 করা যায়নি ($error)। আবার চেষ্টা করুন।';
  }

  @override
  String get dailyShloka => 'দৈনিক শ্লোক';

  @override
  String get dailyShlokaSubtitle => 'প্রতিদিন একটি আধ্যাত্মিক শ্লোক পান';

  @override
  String dailyShlokaToggleFailed(String state, String error) {
    String _temp0 = intl.Intl.selectLogic(state, {
      'on': 'চালু',
      'other': 'বন্ধ',
    });
    return 'দৈনিক শ্লোক $_temp0 করা যায়নি ($error)। আবার চেষ্টা করুন।';
  }

  @override
  String get festivalReminders => 'উৎসবের অনুস্মারক';

  @override
  String get festivalRemindersSubtitle =>
      'কেবল উৎসবের জন্য বিজ্ঞপ্তি, উৎসবের দিনে বা আগে';

  @override
  String festivalRemindersToggleFailed(String state, String error) {
    String _temp0 = intl.Intl.selectLogic(state, {
      'on': 'চালু',
      'other': 'বন্ধ',
    });
    return 'উৎসবের অনুস্মারক $_temp0 করা যায়নি ($error)। আবার চেষ্টা করুন।';
  }

  @override
  String get festivalReminderTime => 'উৎসব অনুস্মারকের সময়';

  @override
  String notificationTimeUpdateFailed(String error) {
    return 'বিজ্ঞপ্তির সময় আপডেট করা যায়নি ($error)। আবার চেষ্টা করুন।';
  }

  @override
  String get festivalReminderDayBefore => 'একদিন আগে';

  @override
  String get festivalReminderBoth => 'উভয়ই';

  @override
  String get festivalReminderOnDay => 'উৎসবের দিনে';

  @override
  String reminderTimeUpdateFailed(String error) {
    return 'অনুস্মারকের সময় আপডেট করা যায়নি ($error)। আবার চেষ্টা করুন।';
  }

  @override
  String get hinduMonthSystem => 'হিন্দু মাস পদ্ধতি';

  @override
  String get hinduMonthSystemSubtitle =>
      'কৃষ্ণ পক্ষে মাসের নামকরণ কীভাবে হবে তা বেছে নিন';

  @override
  String get hinduYearEra => 'হিন্দু বর্ষাব্দ';

  @override
  String get hinduYearEraSubtitle => 'বছর দেখানোর জন্য পঞ্জিকার অব্দ বেছে নিন';

  @override
  String get tithiDisplay => 'তিথি প্রদর্শন';

  @override
  String get tithiDisplayPakshaRange => 'পক্ষ (১-১৫)';

  @override
  String get tithiDisplaySubtitle =>
      'পঞ্জিকায় তিথি কীভাবে গণনা হবে তা বেছে নিন';

  @override
  String get tithiDisplayPakshaBased => 'পক্ষ অনুযায়ী';

  @override
  String get tithiDisplayPakshaDescription =>
      'প্রতিটি পক্ষে আলাদাভাবে ১-১৫ দেখান';

  @override
  String get tithiDisplayContinuousDescription => 'একাধারে ১-৩০ দেখান';

  @override
  String festivalExportShareSubject(String year) {
    return 'তিথি উৎসব $year';
  }

  @override
  String festivalExportShareText(String year) {
    return 'পঞ্চাঙ্গের বিবরণসহ তিথি উৎসব $year (JSON)';
  }

  @override
  String countdownAddedForFestival(String festivalName) {
    return '$festivalName-এর জন্য কাউন্টডাউন যোগ করা হয়েছে';
  }

  @override
  String festivalAlreadyInCountdowns(String festivalName) {
    return '$festivalName ইতিমধ্যেই আপনার কাউন্টডাউনে আছে';
  }

  @override
  String get openStreetMapAttribution => 'OpenStreetMap-এর অবদানকারীগণ';

  @override
  String get moonScrubHint => 'ঘুরে দেখতে টেনে আনুন • ডাবল-ট্যাপে রিসেট হবে';

  @override
  String moonIllumination(String percentage) {
    return 'আলোকিত: $percentage%';
  }

  @override
  String get dayUnitShort => 'দি';

  @override
  String get hourUnitShort => 'ঘ';

  @override
  String get minuteUnitShort => 'মি';

  @override
  String durationHoursMinutesShort(int hours, int minutes) {
    return '$hoursঘ $minutesমি';
  }

  @override
  String durationMinutesShort(int minutes) {
    return '$minutesমি';
  }

  @override
  String distanceAstronomicalUnits(String distance) {
    return '$distance AU';
  }

  @override
  String orbitalPeriodDaysShort(String days) {
    return '$daysদি';
  }

  @override
  String orbitalPeriodYearsShort(String years) {
    return '$yearsব';
  }

  @override
  String get vikramSamvat => 'বিক্রম সংবৎ';

  @override
  String get shakaEra => 'শকাব্দ';

  @override
  String get bengaliEra => 'বঙ্গাব্দ';

  @override
  String get selectYear => 'বছর নির্বাচন করুন';

  @override
  String bengaliEraYear(int year) {
    return '$year বঙ্গাব্দ';
  }

  @override
  String get monthJanuary => 'জানুয়ারি';

  @override
  String get monthFebruary => 'ফেব্রুয়ারি';

  @override
  String get monthMarch => 'মার্চ';

  @override
  String get monthApril => 'এপ্রিল';

  @override
  String get monthMay => 'মে';

  @override
  String get monthJune => 'জুন';

  @override
  String get monthJuly => 'জুলাই';

  @override
  String get monthAugust => 'আগস্ট';

  @override
  String get monthSeptember => 'সেপ্টেম্বর';

  @override
  String get monthOctober => 'অক্টোবর';

  @override
  String get monthNovember => 'নভেম্বর';

  @override
  String get monthDecember => 'ডিসেম্বর';

  @override
  String get weekdaySundayShort => 'রবি';

  @override
  String get weekdayMondayShort => 'সোম';

  @override
  String get weekdayTuesdayShort => 'মঙ্গল';

  @override
  String get weekdayWednesdayShort => 'বুধ';

  @override
  String get weekdayThursdayShort => 'বৃহ';

  @override
  String get weekdayFridayShort => 'শুক্র';

  @override
  String get weekdaySaturdayShort => 'শনি';

  @override
  String get sharedViaTithiApp => 'তিথি অ্যাপের মাধ্যমে শেয়ার করা';

  @override
  String get dailyWisdomShareMessage => 'দৈনিক জ্ঞান — তিথি অ্যাপ';

  @override
  String get shareAsImage => 'ছবি হিসেবে শেয়ার করুন';

  @override
  String get verseCardPicture => 'শ্লোক কার্ডের ছবি';

  @override
  String get shareAsText => 'লেখা হিসেবে শেয়ার করুন';

  @override
  String get verseWithTranslation => 'অনুবাদসহ শ্লোক';

  @override
  String get copyText => 'লেখা কপি করুন';

  @override
  String get copyVerseToClipboard => 'শ্লোক ক্লিপবোর্ডে কপি করুন';

  @override
  String get couldNotCopyVerse => 'শ্লোক কপি করা যায়নি';

  @override
  String get verseCopied => 'শ্লোক কপি করা হয়েছে';

  @override
  String chosenForFestival(String festivalName) {
    return '$festivalName-এর জন্য নির্বাচিত';
  }

  @override
  String get showLess => 'কম দেখান';

  @override
  String get showMoreTranslations => 'আরও অনুবাদ দেখান';

  @override
  String get hideTranslation => 'অনুবাদ লুকান';

  @override
  String get showTranslation => 'অনুবাদ দেখান';

  @override
  String get showLessTitleCase => 'কম দেখান';

  @override
  String get readMore => 'আরও পড়ুন';

  @override
  String tithiNameWithNumber(String tithiName, int number) {
    return '$tithiName (তি$number)';
  }

  @override
  String get masa => 'মাস';

  @override
  String get nakshatra => 'নক্ষত্র';

  @override
  String get begins => 'শুরু';

  @override
  String get ends => 'শেষ';

  @override
  String tithiWithNumber(int number) {
    return 'তিথি $number';
  }

  @override
  String get fastingVrat => 'উপবাস / ব্রত';

  @override
  String get mantra => 'মন্ত্র';

  @override
  String get timingNote => 'সময় সংক্রান্ত নোট';

  @override
  String get timingNoteDescription =>
      'সময়গুলো স্থানাঙ্কের ভিত্তিতে জ্যোতির্বিজ্ঞানের হিসাবে নির্ধারিত হয়, এবং বায়ুমণ্ডলীয় প্রতিসরণ, উচ্চতা বা গণনা পদ্ধতির কারণে স্থানীয় মন্দিরের পঞ্জিকার সময়ের সাথে কয়েক মিনিটের পার্থক্য হতে পারে।';

  @override
  String get noFestivalsInNextThreeDays => 'আগামী ৩ দিনে কোনো উৎসব নেই';

  @override
  String couldNotLoadFestivalsWithError(String error) {
    return 'উৎসব লোড করা যায়নি: $error';
  }

  @override
  String viewAllFestivalsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'সব $countটি উৎসব দেখুন',
      one: 'সব $countটি উৎসব দেখুন',
    );
    return '$_temp0';
  }

  @override
  String get viewAllFestivals => 'সব উৎসব দেখুন';

  @override
  String get day => 'দিন';

  @override
  String festivalCountdownTitle(String title) {
    return '$title কাউন্টডাউন';
  }

  @override
  String festivalInDays(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days দিনে',
      one: '1 দিনে',
    );
    return '$_temp0';
  }

  @override
  String get searchFestivalsVratsAndEvents => 'উৎসব, ব্রত ও ইভেন্ট খুঁজুন';

  @override
  String get homeScreenWidget => 'হোম স্ক্রিন উইজেট';

  @override
  String get homeWidgetCountdownDescription =>
      'হোম স্ক্রিনে উৎসবের কাউন্টডাউন যোগ করুন';

  @override
  String get homeWidgetManualHint =>
      'হোম স্ক্রিনে দীর্ঘভাবে চাপ দিন → উইজেট → তিথি';

  @override
  String get homeWidgetManualInstructions =>
      '1. হোম স্ক্রিনে দীর্ঘভাবে চাপ দিন\n2. \"উইজেট\"-এ ট্যাপ করুন\n3. \"তিথি\" খুঁজে নিন এবং \"উৎসব কাউন্টডাউন\" হোম স্ক্রিনে টেনে আনুন\n\nউইজেটটি আপনার কাউন্টডাউন পাতার সব উৎসব দেখায়।';

  @override
  String get unableToLoadMoonPhaseData => 'চাঁদের কলার তথ্য লোড করা যায়নি';

  @override
  String get countdownNow => 'এখন';

  @override
  String countdownDaysHours(int days, int hours) {
    return '$daysদি $hoursঘ';
  }

  @override
  String get selected => 'নির্বাচিত';

  @override
  String moonPhaseIlluminated(String phase, String percentage) {
    return '$phase · $percentage% আলোকিত';
  }

  @override
  String nextTithiAt(String tithiName, String time) {
    return 'পরবর্তী তিথি $tithiName, সময় $time';
  }

  @override
  String tithiBeginsAt(String tithiName, String time) {
    return '$tithiName শুরু হবে $time-এ';
  }

  @override
  String tithiEndsAtDateTime(String tithiName, String dateTime) {
    return '$tithiName শেষ হবে $dateTime';
  }

  @override
  String get udayaTithiExplanation =>
      'উদয় তিথি: সূর্যোদয়ের সময় প্রচলিত তিথি। একটি হ্রস্ব তিথি দুটি সূর্যোদয়ের মধ্যে শুরু ও শেষ হতে পারে — কোনো তিথি বাদ না পড়ে সেজন্য উপরে দুটি তিথিই দেখানো হয়েছে।';

  @override
  String get beginsUppercase => 'শুরু';

  @override
  String get endsUppercase => 'শেষ';

  @override
  String get transition => 'পরিবর্তন';

  @override
  String get shuklaPakshaInitial => 'শু';

  @override
  String get krishnaPakshaInitial => 'কৃ';

  @override
  String windSpeedKph(double speed) {
    return '$speed কিমি/ঘণ্টা';
  }

  @override
  String get tithiDisplayThirtyDays => '৩০ দিন';

  @override
  String get couldNotCreateImage => 'ছবি তৈরি করা যায়নি';

  @override
  String get shareVerse => 'শ্লোক শেয়ার করুন';

  @override
  String get previousDaysVerse => 'আগের দিনের শ্লোক';

  @override
  String get nextDaysVerse => 'পরের দিনের শ্লোক';

  @override
  String get shareCard => 'কার্ড শেয়ার করুন';

  @override
  String get homeWidgetCanPin => 'হোম স্ক্রিনে উৎসবের কাউন্টডাউন যোগ করুন';

  @override
  String get dailyWisdom => 'দৈনিক জ্ঞান';

  @override
  String get tithiTimings => 'তিথির সময়';

  @override
  String get tithiBegins => 'শুরু';

  @override
  String get tithiEnds => 'শেষ';

  @override
  String get tithiTransition => 'পরিবর্তন';

  @override
  String get udayaTithiExplainer =>
      'উদয় তিথি: সূর্যোদয়ের সময় প্রচলিত তিথি। একটি হ্রস্ব তিথি দুটি সূর্যোদয়ের মধ্যে শুরু ও শেষ হতে পারে — কোনো তিথি বাদ না পড়ে সেজন্য উপরে দুটি তিথিই দেখানো হয়েছে।';

  @override
  String get nakshatraTimings => 'নক্ষত্র';

  @override
  String nakshatraUntil(String nakshatra, String time) {
    return '$nakshatra $time পর্যন্ত';
  }

  @override
  String nakshatraLord(String lord) {
    return 'অধিপতি: $lord';
  }

  @override
  String nakshatraElapsed(String percent) {
    return '$percent% অতিবাহিত';
  }

  @override
  String nakshatraNext(String nakshatra, String time) {
    return 'পরবর্তী: $nakshatra, $time-এ';
  }

  @override
  String get lordKetu => 'কেতু';

  @override
  String get lordVenus => 'শুক্র';

  @override
  String get lordSun => 'সূর্য';

  @override
  String get lordMoon => 'চন্দ্র';

  @override
  String get lordMars => 'মঙ্গল';

  @override
  String get lordRahu => 'রাহু';

  @override
  String get lordJupiter => 'বৃহস্পতি';

  @override
  String get lordSaturn => 'শনি';

  @override
  String get lordMercury => 'বুধ';

  @override
  String get yogaKaranaTimings => 'যোগ ও করণ';

  @override
  String get yogaLabel => 'যোগ';

  @override
  String get karanaLabel => 'করণ';

  @override
  String untilThen(String time, String next) {
    return '$time পর্যন্ত, তারপর $next';
  }

  @override
  String get inauspiciousTimings => 'অশুভ সময়';

  @override
  String get rahuKalam => 'রাহুকাল';

  @override
  String get yamaganda => 'যমগণ্ড';

  @override
  String get gulikaKalam => 'গুলিকাকাল';

  @override
  String get auspiciousTimings => 'শুভ সময়';

  @override
  String get abhijit => 'অভিজিৎ';

  @override
  String get brahmaMuhurta => 'ব্রাহ্মমুহূর্ত';

  @override
  String get madhyahna => 'মধ্যাহ্ন';

  @override
  String get nishita => 'নিশিতা';

  @override
  String get godhuli => 'গোধূলি';

  @override
  String get pradosha => 'প্রদোষ';

  @override
  String get abhijitAvoided => 'বুধবারে পরিহৃত';

  @override
  String get abhijitAuspicious => 'আজ বিশেষভাবে শুভ';

  @override
  String midpointAt(String time) {
    return 'মধ্যবিন্দু $time';
  }
}
