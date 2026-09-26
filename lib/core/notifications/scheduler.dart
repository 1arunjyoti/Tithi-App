import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:hive/hive.dart';
import 'package:timezone/timezone.dart' as tz;

import '../../models/festival.dart';
import '../../models/hindu_month_system.dart';
import '../../models/panchang_data.dart';
import '../../models/sankalpa.dart';
import '../../services/festival_matching_pipeline.dart';
import '../../services/panchang_service.dart';
import '../../services/shloka_service.dart';
import '../../services/storage_service.dart';
import '../../services/sunrise_calculator.dart';
import '../../utils/date_utils.dart';
import 'festival_store.dart';
import 'notification_keys.dart';
import 'scheduling_parts.dart';

// Phase 6b: scheduling engine extracted from services/notification_service.dart.
// The singleton keeps lifecycle (init/dispose), flag CRUD with rollback, and
// thin delegates; all scheduling, content building, permission, and sankalpa
// logic lives here, driven by an explicit seam: the plugin + the settings
// box. No Riverpod, no singletons — every method is testable with a fake
// box and a mock plugin.

/// Schedules, cancels, and builds notification content.
///
/// Constructed per call from the owning service
/// (`NotificationScheduler(plugin: ..., box: ...)`); holds no global state.
class NotificationScheduler {
  NotificationScheduler({required this.plugin, required this.box});

  final FlutterLocalNotificationsPlugin plugin;
  final Box? box;

  /// Get notification time (default 8:00 AM)
  Future<({int hour, int minute})> getNotificationTime() async {
    final hour = (box?.get(NotificationKeys.hour, defaultValue: 8) as int?) ?? 8;
    final minute = (box?.get(NotificationKeys.minute, defaultValue: 0) as int?) ?? 0;
    return (hour: hour, minute: minute);
  }

  /// Cancel all Shloka notifications
  Future<void> cancelShlokaNotifications() async {
    // Cancel IDs 1000 to 1006 (7 days)
    for (int i = 0; i < 7; i++) {
      await plugin.cancel(NotificationKeys.shlokaNotificationIdBase + i);
    }
  }

  /// Schedule upcoming Shloka notifications for the next 7 days
  Future<void> scheduleUpcomingShlokas() async {
    // SMELL-2: read the flag directly from the box instead of an async
    // isShlokaEnabled() call. Independent of the daily master switch.
    final shlokaEnabled =
        box?.get(NotificationKeys.shlokaEnabled, defaultValue: false) ?? false;
    if (!shlokaEnabled) return;

    await cancelShlokaNotifications();

    // ShlokaService is a singleton, no need to cache it
    final shlokaService = ShlokaService();
    await shlokaService.init();

    final time = await getNotificationTime();
    final now = tz.TZDateTime.now(tz.local);

    final shlokas = shlokaService.getShlokasForNextNDays(7);

    for (int i = 0; i < shlokas.length; i++) {
      var scheduledDate = tz.TZDateTime(
        tz.local,
        now.year,
        now.month,
        now.day,
        time.hour,
        time.minute,
      ).add(Duration(days: i));

      // If the calculated time for "today" (i=0) has passed,
      // we might still want to show it if we just enabled it?
      // Or strictly follow "future only".
      // Daily notification logic moves it to tomorrow if passed.
      // For shlokas, if today passed, we just skip scheduling "today's" notification
      // because the user will see it in the app anyway.

      if (scheduledDate.isBefore(now)) {
        // If it's today and passed, skip scheduling for today
        continue;
      }

      final notificationDetails = notificationChannel(
        id: 'tithi_shloka',
        name: 'Daily Shloka',
        description: 'Spiritual verses and quotes',
        highPriority: false,
      );

      await plugin.zonedSchedule(
        NotificationKeys.shlokaNotificationIdBase + i,
        'Daily Wisdom',
        '"${shlokas[i].text}"\n\n${shlokas[i].translation}',
        scheduledDate,
        notificationDetails,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      );
    }

    if (kDebugMode) {
      print('Scheduled upcoming Shloka notifications');
    }
  }

  /// Get festival reminder timing as a [FestivalReminderTiming] index
  /// (0 = on the day, 1 = one day before, 2 = both). Defaults to on-day.
  Future<int> getFestivalTiming() async {
    final timing =
        (box?.get(NotificationKeys.festivalTiming, defaultValue: 0) as int?) ?? 0;
    if (timing < 0 || timing > FestivalReminderTiming.values.length - 1) {
      return 0;
    }
    return timing;
  }

  /// Cancel all festival reminder notifications.
  Future<void> cancelFestivalNotifications() async {
    // IDs [NotificationKeys.festivalNotificationIdBase, +NotificationKeys.festivalWindowDays * 2):
    // two slots (on-day, day-before) per scanned day.
    for (int i = 0; i < NotificationKeys.festivalWindowDays * 2; i++) {
      await plugin.cancel(NotificationKeys.festivalNotificationIdBase + i);
    }
  }

  /// Schedule reminders for festivals in the next [NotificationKeys.festivalWindowDays] days
  /// (major preferred when several fall on one day).
  /// Day-before reminders fire at the notification time on the eve of
  /// the festival; on-day reminders fire at the notification time on the day.
  /// Past times are skipped; the 6-hourly WorkManager task re-runs this via
  /// [init], so festivals entering the window are never missed.
  Future<void> scheduleUpcomingFestivals() async {
    final enabled =
        box?.get(NotificationKeys.festivalEnabled, defaultValue: false) ?? false;
    if (!enabled) return;

    await cancelFestivalNotifications();

    final timing = await getFestivalTiming();
    final wantOnDay = timing != FestivalReminderTiming.dayBefore.index;
    final wantDayBefore = timing != FestivalReminderTiming.onDay.index;

    final coords = await readLastKnownLatLng();
    final latitude = coords.latitude;
    final longitude = coords.longitude;

    final settingsBox = await StorageService().openSettingsBox();
    final prefs = readCalendarPrefs(settingsBox);
    final monthSystem = prefs.monthSystem;
    final secondarySystem = prefs.secondarySystem;
    final yearEraIndex = prefs.yearEraIndex;
    final tithiMode = prefs.tithiMode;

    final service = PanchangService();
    await service.init();
    final festivals = await loadFestivalsForNotification();
    if (festivals.isEmpty) return;

    final time = await getNotificationTime();
    final now = tz.TZDateTime.now(tz.local);
    final today = DateTime(now.year, now.month, now.day);

    final notificationDetails = notificationChannel(
      id: 'tithi_festival',
      name: 'Festival Reminders',
      description: 'Reminders for upcoming festivals',
    );

    // Collect the window (padded ±2 days for Vriddhi edge runs), then
    // filter once through the shared pipeline before scheduling.
    final window = <DateTime, PanchangData>{};
    for (int i = -2; i < NotificationKeys.festivalWindowDays + 2; i++) {
      final date = today.add(Duration(days: i));
      final sunrise = SunriseCalculator.calculateSunriseIST(
        date: date,
        latitude: latitude,
        longitude: longitude,
      );
      window[date] = await computePanchangForDate(
        date: date,
        service: service,
        latitude: latitude,
        longitude: longitude,
        festivals: festivals,
        monthSystem: monthSystem,
        sunriseTime: sunrise,
      );
    }
    // Shared pipeline: same Vriddhi trimming as the UI grid, so reminders
    // never fire for a day the app hides (e.g. Oct 17 Navratri-Shashthi).
    // Padded ±2 days so runs straddling the window edge resolve correctly;
    // only in-window days are scheduled below.
    final filtered = applyVriddhiFilter(window);

    for (int i = 0; i < NotificationKeys.festivalWindowDays; i++) {
      final date = today.add(Duration(days: i));
      final panchang = filtered[date];
      if (panchang == null || !panchang.hasFestivals) continue;
      // Ranked festivals win; otherwise legacy major-first behaviour.
      final festival = primaryFestival(panchang.festivals);

      final displayMasa = displayMasaName(
        panchang.masa,
        panchang.paksha,
        monthSystem,
      ).replaceAll('_', ' ');
      final hinduDay =
          tithiMode == 0 ? panchang.tithiNumber : panchang.tithiIndex;
      final bodyLines = panchangBodyLines(
        date: date,
        panchang: panchang,
        displayMasa: displayMasa,
        secondarySystem: secondarySystem,
        yearEraIndex: yearEraIndex,
        hinduDay: hinduDay,
      );

      if (wantOnDay) {
        final onDay = tz.TZDateTime(
          tz.local,
          date.year,
          date.month,
          date.day,
          time.hour,
          time.minute,
        );
        if (!onDay.isBefore(now)) {
          await plugin.zonedSchedule(
            NotificationKeys.festivalNotificationIdBase + i * 2,
            festival.name,
            'Today • ${bodyLines.tithiIdentity}\n${bodyLines.dateLines}',
            onDay,
            notificationDetails,
            androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          );
        }
      }
      if (wantDayBefore) {
        final eve = tz.TZDateTime(
          tz.local,
          date.year,
          date.month,
          date.day,
          time.hour,
          time.minute,
        ).subtract(const Duration(days: 1));
        if (!eve.isBefore(now)) {
          await plugin.zonedSchedule(
            NotificationKeys.festivalNotificationIdBase + i * 2 + 1,
            festival.name,
            'Tomorrow • ${bodyLines.tithiIdentity}\n${bodyLines.dateLines}',
            eve,
            notificationDetails,
            androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          );
        }
      }
    }

    if (kDebugMode) {
      print('Scheduled upcoming festival notifications');
    }
  }

  /// Request notification permission.
  ///
  /// Returns true when notifications may be scheduled. Never throws: plugin
  /// errors (e.g. MissingPluginException on platforms without a registered
  /// implementation) fail closed with a log so the settings toggle can show
  /// the "permission denied" message instead of snapping back silently.
  Future<bool> requestPermission() async {
    try {
      final android = plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      if (android != null) {
        final granted = await android.requestNotificationsPermission();
        return granted ?? false;
      }

      final ios = plugin
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >();
      if (ios != null) {
        final granted = await ios.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        );
        return granted ?? false;
      }

      final macos = plugin
          .resolvePlatformSpecificImplementation<
            MacOSFlutterLocalNotificationsPlugin
          >();
      if (macos != null) {
        final granted = await macos.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        );
        return granted ?? false;
      }

      // No runtime permission model (e.g. Windows/Linux/web).
      return true;
    } catch (e) {
      debugPrint('Notification permission request failed: $e');
      return false;
    }
  }

  /// Throws a descriptive [StateError] when the OS currently blocks this
  /// app's notifications (e.g. the user revoked permission in system
  /// settings after granting it). Scheduling APIs "succeed" silently in
  /// that state, so enable paths must check first instead of leaving the
  /// toggle ON while nothing can ever fire.
  ///
  /// Fail-open when the check itself is unavailable (unknown platform or
  /// plugin error): the schedule attempt will surface real failures.
  Future<void> assertSystemNotificationsAllowed() async {
    try {
      final android = plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      if (android != null) {
        final enabled = await android.areNotificationsEnabled();
        if (enabled == false) {
          throw StateError(
            'Notifications are disabled for Tithi in system settings',
          );
        }
        return;
      }

      final ios = plugin
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >();
      if (ios != null) {
        final status = await ios.checkPermissions();
        if (status != null && !status.isEnabled) {
          throw StateError(
            'Notifications are disabled for Tithi in system settings',
          );
        }
        return;
      }

      final macos = plugin
          .resolvePlatformSpecificImplementation<
            MacOSFlutterLocalNotificationsPlugin
          >();
      if (macos != null) {
        final status = await macos.checkPermissions();
        if (status != null && !status.isEnabled) {
          throw StateError(
            'Notifications are disabled for Tithi in system settings',
          );
        }
        return;
      }
      // No OS-level gate to check (Windows/Linux/web).
    } on StateError {
      rethrow;
    } catch (e) {
      debugPrint('System notification check unavailable, proceeding: $e');
    }
  }

  /// Schedule daily notification
  Future<void> scheduleDailyNotification({String? title, String? body}) async {

    // Cancel existing notification first
    await plugin.cancel(NotificationKeys.dailyNotificationId);

    final time = await getNotificationTime();

    // Calculate next notification time
    final now = tz.TZDateTime.now(tz.local);
    var scheduledDate = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      time.hour,
      time.minute,
    );

    // If time has passed today, schedule for tomorrow
    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }

    final notificationDetails = notificationChannel(
      id: 'tithi_daily',
      name: 'Daily Tithi',
      description: 'Daily tithi and panchang notifications',
    );

    final content = await getDailyNotificationContent();
    final resolvedTitle = title ?? content.title;
    final resolvedBody = body ?? content.body;

    await plugin.zonedSchedule(
      NotificationKeys.dailyNotificationId,
      resolvedTitle,
      resolvedBody,
      scheduledDate,
      notificationDetails,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time, // Repeat daily
    );

    if (kDebugMode) {
      print('Scheduled daily notification for ${time.hour}:${time.minute}');
    }
  }

  Future<void> refreshDailyNotificationContent() async {
    final generated = await buildDailyNotificationContent();
    await box?.put(NotificationKeys.dailyTitle, generated.title);
    await box?.put(NotificationKeys.dailyBody, generated.body);
    await box?.put(NotificationKeys.dailyContentDate, panchangDateKey(DateTime.now()));
  }

  Future<({String title, String body})> getDailyNotificationContent() async {
    final todayKey = panchangDateKey(DateTime.now());
    final cachedDate = box?.get(NotificationKeys.dailyContentDate) as String?;
    final cachedTitle = box?.get(NotificationKeys.dailyTitle) as String?;
    final cachedBody = box?.get(NotificationKeys.dailyBody) as String?;

    if (cachedDate == todayKey && cachedTitle != null && cachedBody != null) {
      return (title: cachedTitle, body: cachedBody);
    }

    await refreshDailyNotificationContent();
    return (
      title: (box?.get(NotificationKeys.dailyTitle) as String?) ?? '🙏 Tithi Today',
      body:
          (box?.get(NotificationKeys.dailyBody) as String?) ??
          'Open to see today\'s panchang details',
    );
  }

  /// Full panchang for [date] with the same intraday checkpoints the app UI
  /// uses, so festival matching (timingOverride, Kshaya) agrees with what
  /// the user sees. Shared by the daily content and the festival scanner.
  Future<PanchangData> computePanchangForDate({
    required DateTime date,
    required PanchangService service,
    required double latitude,
    required double longitude,
    required List<Festival> festivals,
    required HinduMonthSystem monthSystem,
    required DateTime sunriseTime,
  }) async {
    final sunsetTime = SunriseCalculator.calculateSunsetIST(
      date: date,
      latitude: latitude,
      longitude: longitude,
    );
    final nextSunriseTime = SunriseCalculator.calculateSunriseIST(
      date: date.add(const Duration(days: 1)),
      latitude: latitude,
      longitude: longitude,
    );

    final rawTithi = await service.calculateTithi(
      sunriseTime,
      latitude: latitude,
      longitude: longitude,
    );
    final masa = await service.calculateMasa(
      sunriseTime,
      rawTithi,
      latitude: latitude,
      longitude: longitude,
    );
    // Intraday checkpoints so timingOverride festivals (madhyahna,
    // aparahna, nishita, pradosha) and Kshaya tithis match the app UI.
    final rawTithiMadhyahna = await service.calculateTithi(
      sunriseTime.add(
        Duration(minutes: sunsetTime.difference(sunriseTime).inMinutes ~/ 2),
      ),
      latitude: latitude,
      longitude: longitude,
    );
    final rawTithiAparahna = await service.calculateTithi(
      sunriseTime.add(
        Duration(
          minutes: sunsetTime.difference(sunriseTime).inMinutes * 3 ~/ 4,
        ),
      ),
      latitude: latitude,
      longitude: longitude,
    );
    final rawTithiNishita = await service.calculateTithi(
      sunsetTime.add(
        Duration(
          minutes: nextSunriseTime.difference(sunsetTime).inMinutes ~/ 2,
        ),
      ),
      latitude: latitude,
      longitude: longitude,
    );
    final rawTithiPradosha = await service.calculateTithi(
      sunsetTime.add(
        Duration(
          minutes: nextSunriseTime.difference(sunsetTime).inMinutes ~/ 10,
        ),
      ),
      latitude: latitude,
      longitude: longitude,
    );
    final rawTithiNextSunrise = await service.calculateTithi(
      nextSunriseTime,
      latitude: latitude,
      longitude: longitude,
    );
    final masaNextSunrise = await service.calculateMasa(
      nextSunriseTime,
      rawTithiNextSunrise,
      latitude: latitude,
      longitude: longitude,
    );
    // Dominant-tithi grace checkpoint (same Drik rule as the UI batch).
    final rawTithiDominant = await service.calculateTithi(
      sunriseTime.add(kDominantTithiGrace),
      latitude: latitude,
      longitude: longitude,
    );
    // Nakshatra at sunrise for nakshatra-conditioned festivals (Mula
    // Avahan). Gated so days without such festivals skip the extra call.
    final needsNakshatra = festivals.any((f) => f.nakshatraCondition != null);
    final nakshatraAtSunrise = needsNakshatra
        ? await service.calculateNakshatra(
            sunriseTime,
            latitude: latitude,
            longitude: longitude,
          )
        : null;

    return PanchangData.fromRawTithi(
      date: date,
      rawTithi: rawTithi,
      masa: masa,
      allFestivals: festivals,
      monthSystem: monthSystem,
      sunrise: sunriseTime,
      sunset: sunsetTime,
      rawTithiMadhyahna: rawTithiMadhyahna,
      rawTithiAparahna: rawTithiAparahna,
      rawTithiNishita: rawTithiNishita,
      rawTithiPradosha: rawTithiPradosha,
      rawTithiNextSunrise: rawTithiNextSunrise,
      masaNextSunrise: masaNextSunrise,
      nakshatraAtSunrise: nakshatraAtSunrise,
      rawTithiDominant: rawTithiDominant,
    );
  }

  Future<({String title, String body})> buildDailyNotificationContent() async {
    try {
      final coords = await readLastKnownLatLng();
      final latitude = coords.latitude;
      final longitude = coords.longitude;

      final settingsBox = await StorageService().openSettingsBox();
      final prefs = readCalendarPrefs(settingsBox);
      final monthSystem = prefs.monthSystem;

      final service = PanchangService();
      await service.init();

      final today = DateTime.now();
      final date = DateTime(today.year, today.month, today.day);

      final festivals = await loadFestivalsForNotification();
      // 3-day context so the shared Vriddhi filter can trim today correctly
      // (same result as the UI grid: e.g. no Navratri-Shashthi on the
      // second day of a Shashthi run).
      final contextDays = <DateTime, PanchangData>{};
      for (int i = -1; i <= 1; i++) {
        final day = date.add(Duration(days: i));
        final daySunrise = SunriseCalculator.calculateSunriseIST(
          date: day,
          latitude: latitude,
          longitude: longitude,
        );
        contextDays[day] = await computePanchangForDate(
          date: day,
          service: service,
          latitude: latitude,
          longitude: longitude,
          festivals: festivals,
          monthSystem: monthSystem,
          sunriseTime: daySunrise,
        );
      }
      final panchang =
          applyVriddhiFilter(contextDays)[date] ?? contextDays[date]!;
      // Display the masa in the user's selected month system (Purnimant
      // Krishna days carry the next month's name; Shukla is identical).
      final displayMasa = displayMasaName(
        panchang.masa,
        panchang.paksha,
        monthSystem,
      ).replaceAll('_', ' ');

      final hinduDay = prefs.tithiMode == 0
          ? panchang.tithiNumber
          : panchang.tithiIndex;
      final bodyLines = panchangBodyLines(
        date: date,
        panchang: panchang,
        displayMasa: displayMasa,
        secondarySystem: prefs.secondarySystem,
        yearEraIndex: prefs.yearEraIndex,
        hinduDay: hinduDay,
      );

      // First line is the festival name when one falls today (ranked
      // preferred, else major preferred, else first), matching the home
      // screen. Otherwise the tithi identity.
      if (panchang.hasFestivals) {
        final festival = primaryFestival(panchang.festivals);
        return (
          title: festival.name,
          body: '${bodyLines.tithiIdentity}\n${bodyLines.dateLines}',
        );
      }

      return (
        title: bodyLines.tithiIdentity,
        body: bodyLines.dateLines,
      );
    } catch (e, stack) {
      // BUG-MEDIUM-7: Surface the error instead of swallowing it silently.
      debugPrint('Failed to build notification content: $e\n$stack');
      return (
        title: '🙏 Tithi Today',
        body: 'Open to see today\'s panchang details',
      );
    }
  }

  Future<void> showTestNotification({
    required String title,
    required String body,
  }) async {

    final notificationDetails = notificationChannel(
      id: 'tithi_daily',
      name: 'Daily Tithi',
      description: 'Daily tithi and panchang notifications',
    );

    await plugin.show(0, title, body, notificationDetails);

    if (kDebugMode) {
      print('Showed test notification: $title');
    }
  }

  /// Cancel all notifications
  Future<void> cancelAllNotifications() async {
    await plugin.cancelAll();
    if (kDebugMode) {
      print('Cancelled all notifications');
    }
  }

  /// Returns a stable, collision-free notification ID for the given sankalpa.
  /// IDs are persisted in the notification Hive box so they survive restarts.
  int _getOrCreateSankalpaNotificationId(String sankalpaId) {
    final mapKey = '$NotificationKeys.sankalpaIdPrefix$sankalpaId';
    final existing = box?.get(mapKey) as int?;
    if (existing != null) return existing;

    // Allocate next sequential ID.
    final counter =
        (box?.get(NotificationKeys.sankalpaIdCounter, defaultValue: 0) as int?) ?? 0;
    final newId = NotificationKeys.sankalpaNotificationIdBase + counter;
    box?.put(NotificationKeys.sankalpaIdCounter, counter + 1);
    box?.put(mapKey, newId);
    return newId;
  }

  /// Schedule a specific sankalpa reminder
  Future<void> scheduleSankalpaReminder(Sankalpa sankalpa) async {
    if (sankalpa.isCompleted) return;

    // Use a persisted counter to guarantee unique IDs (replaces hashCode % 10000
    // which had collision risk after ~125 sankalpas).
    final notificationId = _getOrCreateSankalpaNotificationId(sankalpa.id);

    final now = tz.TZDateTime.now(tz.local);
    var scheduledDate = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      sankalpa.reminderHour,
      sankalpa.reminderMinute,
    );

    // If time passed, start tomorrow
    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }

    // Check if end date passed (if we used strict date checking)
    // For now, assume if not completed, keep reminding until duration ends + user marks complete
    // Actually, if we have duration, we should check if today + days remaining is valid.

    // Sankalpa model logic: it has endDate.
    if (scheduledDate.isAfter(
      tz.TZDateTime.from(
        sankalpa.endDate,
        tz.local,
      ).add(const Duration(days: 1)),
    )) {
      // Allow one day grace or stop exactly? Let's stop if past end date.
      return;
    }

    final notificationDetails = notificationChannel(
      id: 'tithi_sankalpa',
      name: 'Sankalpa Reminders',
      description: 'Daily reminders for your intentions',
    );

    await plugin.zonedSchedule(
      notificationId,
      'Sankalpa Reminder',
      sankalpa.title,
      scheduledDate,
      notificationDetails,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time, // Repeat daily
      payload: 'sankalpa:${sankalpa.id}',
    );

    if (kDebugMode) {
      print(
        'Scheduled sankalpa: ${sankalpa.title} at ${sankalpa.reminderHour}:${sankalpa.reminderMinute}',
      );
    }
  }

  /// Cancel a sankalpa reminder
  Future<void> cancelSankalpaReminder(String id) async {
    final notificationId = _getOrCreateSankalpaNotificationId(id);
    await plugin.cancel(notificationId);
    if (kDebugMode) {
      print('Cancelled sankalpa notification: $id (ID: $notificationId)');
    }
  }

  /// Cancel all sankalpa reminders (cleanup)
  Future<void> cancelAllSankalpaReminders(List<String> sankalpaIds) async {
    for (final id in sankalpaIds) {
      await cancelSankalpaReminder(id);
    }
  }
}
