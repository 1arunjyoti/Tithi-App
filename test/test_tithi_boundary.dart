import 'package:tithi/services/panchang/panchang_service_native.dart';
import 'package:jyotish/jyotish.dart';

// Just writing the static implementations of the logic to replace in the service file.
// The Tithi number is 1-30.

Future<DateTime> calculateTithiStartTime(
  DateTime approxDate,
  int targetTithiNum, {
  double latitude = 28.6139,
  double longitude = 77.2090,
}) async {
  // We'll calculate backwards from the approxDate until tithi drops below target.
  // Using a 1-minute step for high precision.
  // Maximum search is about 30 hours (1800 minutes).

  DateTime current = approxDate;
  int currentTithiNum = (await calculateTithiInternal(
    current,
    latitude,
    longitude,
  )).floor();

  // If the approxDate is ALREADY in the previous tithi, we need to go forward to find the start!
  bool scanningForward = false;

  if (currentTithiNum < targetTithiNum ||
      (targetTithiNum == 1 && currentTithiNum == 30)) {
    scanningForward = true;
  } else if (currentTithiNum > targetTithiNum ||
      (targetTithiNum == 30 && currentTithiNum == 1)) {
    // We are in a future tithi, we shouldn't be here ideally based on where this is called from,
    // but if we are, step back aggressively until we hit target.
    while (currentTithiNum != targetTithiNum) {
      current = current.subtract(const Duration(hours: 1));
      currentTithiNum = (await calculateTithiInternal(
        current,
        latitude,
        longitude,
      )).floor();
    }
  }

  // Binary search fine tuning (actually a stepping search is safer for circular tithis)
  if (scanningForward) {
    // Step forward by hours until we hit it, then step back by minutes
    while (currentTithiNum != targetTithiNum) {
      current = current.add(const Duration(hours: 1));
      currentTithiNum = (await calculateTithiInternal(
        current,
        latitude,
        longitude,
      )).floor();
    }
    // Now we are IN the target tithi. Step backwards by minute until we exit it.
    while (currentTithiNum == targetTithiNum) {
      current = current.subtract(const Duration(minutes: 1));
      currentTithiNum = (await calculateTithiInternal(
        current,
        latitude,
        longitude,
      )).floor();
    }
    // The minute AFTER it exited is the start.
    return current.add(const Duration(minutes: 1));
  } else {
    // Step backward by hours until we exit it, then step forward by minutes
    while (currentTithiNum == targetTithiNum) {
      current = current.subtract(const Duration(hours: 1));
      currentTithiNum = (await calculateTithiInternal(
        current,
        latitude,
        longitude,
      )).floor();
    }
    // Now we have EXITED the target tithi (we are in the previous). Step forward by minutes.
    while (currentTithiNum != targetTithiNum) {
      current = current.add(const Duration(minutes: 1));
      currentTithiNum = (await calculateTithiInternal(
        current,
        latitude,
        longitude,
      )).floor();
    }
    return current;
  }
}

Future<double> calculateTithiInternal(
  DateTime date,
  double lat,
  double lon,
) async {
  final location = GeographicLocation(latitude: lat, longitude: lon);
  final sun = await Jyotish().getPlanetPosition(
    planet: Planet.sun,
    dateTime: date,
    location: location,
  );
  final moon = await Jyotish().getPlanetPosition(
    planet: Planet.moon,
    dateTime: date,
    location: location,
  );
  double diff = moon.longitude - sun.longitude;
  if (diff < 0) diff += 360;
  return (diff / 12) + 1;
}
