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
  String get vedaCalendar => 'বৈদিক পঞ্জিকা';

  @override
  String get settings => 'সেটিংস';

  @override
  String get appearance => 'প্রদর্শন';

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
  String get themeDark => 'অন্ধকার';

  @override
  String get themeKrishna => 'কৃষ্ণ';

  @override
  String get dailyNotifications => 'দৈনিক বিজ্ঞপ্তি';

  @override
  String get notificationScheduled => 'দৈনিক নির্ধারিত';

  @override
  String get getNotifiedTithiDaily => 'প্রতিদিন তিথি সম্পর্কে বিজ্ঞপ্তি পান';

  @override
  String get notificationTime => 'বিজ্ঞপ্তির সময়';

  @override
  String get autoLocation => 'স্বয়ংক্রিয় অবস্থান';

  @override
  String get useGpsForTithi => 'সঠিক তিথি গণনার জন্য GPS ব্যবহার করুন';

  @override
  String usingLocation(String cityName) {
    return 'ব্যবহার করছে: $cityName';
  }

  @override
  String get fetchingLocation => 'অবস্থান আনা হচ্ছে...';

  @override
  String get locationUnavailable => 'অবস্থান অনুপলব্ধ';

  @override
  String get homeLocation => 'বাড়ির অবস্থান';

  @override
  String get notSet => 'সেট করা হয়নি';

  @override
  String get setHomeLocation => 'বাড়ির অবস্থান সেট করুন';

  @override
  String get dragMapToPin => 'আপনার বাড়িতে পিন রাখতে মানচিত্র টানুন';

  @override
  String get setThisLocation => 'এই অবস্থান সেট করুন';

  @override
  String homeLocationSetTo(String address) {
    return 'বাড়ির অবস্থান $address এ সেট করা হয়েছে';
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
  String get festival => 'উৎসব';

  @override
  String get moon => 'চাঁদ';

  @override
  String get primaryCalendar => 'প্রাথমিক পঞ্জিকা';

  @override
  String get secondaryCalendar => 'মাধ্যমিক পঞ্জিকা';

  @override
  String get selectPrimaryCalendar => 'প্রাথমিক পঞ্জিকা নির্বাচন করুন';

  @override
  String get selectSecondaryCalendar => 'মাধ্যমিক পঞ্জিকা নির্বাচন করুন';

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
  String get solidBackgrounds => 'ভালো পাঠযোগ্যতার জন্য কঠিন পটভূমি';

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
  String get madeWithLove => 'সনাতন ধর্মের জন্য ❤️ দিয়ে তৈরি';

  @override
  String get shareApp => 'অ্যাপ শেয়ার করুন';

  @override
  String get shareAppMessage =>
      'তিথি দেখুন - বৈদিক পঞ্জিকা অ্যাপ! এখনই ডাউনলোড করুন: https://example.com/tithi';

  @override
  String get rateUs => 'রেট দিন';

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
  String get noFestivalsOnThisDay => 'আজ কোন উৎসব নেই';

  @override
  String get todaysFestival => 'আজকের উৎসব';

  @override
  String get noFestivalsToday => 'তিথি • আজ কোন উৎসব নেই';

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
      'তিথি গোপনীয়তা-প্রথম, অফলাইন-প্রথম আর্কিটেকচার দিয়ে ডিজাইন করা হয়েছে। সমস্ত জ্যোতির্বিদ্যা গণনা, পঞ্জিকা তৈরি এবং ইভেন্ট প্রক্রিয়াকরণ সরাসরি আপনার ডিভাইসে হয়। আমরা কোনো বাহ্যিক সার্ভারে আপনার ব্যক্তিগত ডেটা সংগ্রহ, সঞ্চয় বা প্রেরণ করি না।';

  @override
  String get privacyLocationUsage => 'অবস্থান ব্যবহার';

  @override
  String get privacyLocationDesc =>
      'আমরা শুধুমাত্র সঠিক তিথি, নক্ষত্র এবং সূর্যোদয়/সূর্যাস্তের সময় গণনা করতে আপনার অবস্থানে অ্যাক্সেসের অনুরোধ করি, যা আপনার নির্দিষ্ট ভৌগলিক স্থানাঙ্কের উপর নির্ভর করে।';

  @override
  String get privacyOffline => 'অফলাইন কার্যকারিতা';

  @override
  String get privacyOfflineDesc =>
      'প্রাথমিক ডাউনলোডের পরে অ্যাপটি সম্পূর্ণ অফলাইনে কাজ করে। এতে উচ্চ-নির্ভুলতা গ্রহ গণনার জন্য প্রয়োজনীয় সুইস এফেমেরিস ডেটা এম্বেড করা আছে।';

  @override
  String get privacyOpenSource => 'ওপেন সোর্স স্বচ্ছতা';

  @override
  String get privacyOpenSourceDesc =>
      'তিথি একটি ওপেন-সোর্স প্রকল্প। আমাদের কোড নিরীক্ষার জন্য সর্বজনীনভাবে উপলব্ধ, যা নিশ্চিত করে যে আমাদের গোপনীয়তা প্রতিশ্রুতি যাচাইযোগ্য স্বচ্ছতা দ্বারা সমর্থিত।';

  @override
  String get lastUpdated => 'শেষ আপডেট: ডিসেম্বর 2025';

  @override
  String get applicationLegalese =>
      '© 2025 তিথি প্রকল্প\nসনাতন ধর্মের জন্য ❤️ দিয়ে তৈরি';

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
  String get today => 'আজ';

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
}
