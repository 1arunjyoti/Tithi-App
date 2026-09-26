import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:hive/hive.dart';
import 'package:intl/intl.dart';

import '../../models/hindu_month_system.dart';
import '../../models/panchang_data.dart';
import '../../services/storage_service.dart';
import '../location/cached_location.dart';
import 'notification_content.dart';

// P0-2: shared notification building blocks extracted from scheduler.dart.
// Five near-identical channel builders, two lat/lng reads, two calendar
// prefs reads, and two festival body assemblers now have one definition.

/// Shared Android+iOS notification channel.
///
/// [highPriority] selects Importance.high/Priority.high (festival, daily,
/// test, sankalpa); shloka channels omit both (pass false) to preserve the
/// exact pre-refactor payloads.
NotificationDetails notificationChannel({
  required String id,
  required String name,
  required String description,
  bool highPriority = true,
}) {
  final androidDetails = AndroidNotificationDetails(
    id,
    name,
    channelDescription: description,
    importance: highPriority ? Importance.high : Importance.defaultImportance,
    priority: highPriority ? Priority.high : Priority.defaultPriority,
    icon: '@mipmap/launcher_icon',
    largeIcon: const DrawableResourceAndroidBitmap('@mipmap/launcher_icon'),
  );

  const iosDetails = DarwinNotificationDetails(
    presentAlert: true,
    presentBadge: true,
    presentSound: true,
  );

  return NotificationDetails(android: androidDetails, iOS: iosDetails);
}

/// Last-known coordinates via the location settings box.
Future<({double latitude, double longitude})> readLastKnownLatLng() async {
  final locationBox = await StorageService().openLocationSettingsBox();
  return readCachedLatLng(locationBox);
}

/// Reads the Hindu month system from a settings box (safe default).
HinduMonthSystem readMonthSystem(Box<dynamic> settingsBox) {
  final index =
      (settingsBox.get(
                'hindu_month_system',
                defaultValue: HinduMonthSystem.amanta.index,
              )
              as int?) ??
          HinduMonthSystem.amanta.index;
  if (index >= 0 && index < HinduMonthSystem.values.length) {
    return HinduMonthSystem.values[index];
  }
  return HinduMonthSystem.amanta;
}

/// Calendar display preferences + month system from the settings box.
/// Indices mirror AppCalendarSystem (0=none, 1=gregorian, 2=hindu, 3=bengali)
/// and TithiDisplayMode (0=pakshaBased, 1=continuous30); raw ints keep
/// background-isolate code free of Riverpod.
({
  HinduMonthSystem monthSystem,
  int secondarySystem,
  int yearEraIndex,
  int tithiMode,
})
readCalendarPrefs(Box<dynamic> settingsBox) {
  return (
    monthSystem: readMonthSystem(settingsBox),
    secondarySystem:
        (settingsBox.get('secondary_calendar_system', defaultValue: 2)
                as int?) ??
            2,
    yearEraIndex:
        (settingsBox.get('hindu_year_era', defaultValue: 1) as int?) ?? 1,
    tithiMode:
        (settingsBox.get('tithi_display_mode', defaultValue: 1) as int?) ?? 1,
  );
}

/// Festival body lines for [date]: tithi identity + Gregorian/secondary lines.
/// Shared by the festival scanner and the daily content builder so reminders
/// never disagree with the home screen.
({String tithiIdentity, String dateLines}) panchangBodyLines({
  required DateTime date,
  required PanchangData panchang,
  required String displayMasa,
  required int secondarySystem,
  required int yearEraIndex,
  required int hinduDay,
}) {
  final tithiIdentity =
      '${panchang.paksha} ${panchang.tithiName} – $displayMasa';
  final gregorianLine = DateFormat('EEEE, d MMMM yyyy').format(date);
  final secondaryLine = secondaryCalendarLine(
    secondarySystem: secondarySystem,
    date: date,
    displayMasa: displayMasa,
    rawMasa: panchang.masa,
    yearEraIndex: yearEraIndex,
    hinduDay: hinduDay,
  );
  final dateLines = secondaryLine == null
      ? gregorianLine
      : '$gregorianLine\n$secondaryLine';
  return (tithiIdentity: tithiIdentity, dateLines: dateLines);
}
