# Jyotish Library - Quick Start Guide

## What is Jyotish?

Jyotish is a production-ready Flutter library for calculating planetary positions using the Swiss Ephemeris. It provides high-precision astronomical calculations for astrology and astronomy applications.

## Key Features

- 🌍 Calculate positions for Sun, Moon, and all major planets
- 📍 Support for tropical and sidereal (Vedic) zodiac systems
- 🎯 Nakshatra (lunar mansion) calculations
- ⚡ Retrograde motion detection
- 🔧 Multiple ayanamsa systems (40+ options)
- 💯 Production-ready with comprehensive error handling

## Quick Installation

```yaml
dependencies:
  jyotish: ^1.0.0
```

## 5-Minute Tutorial

```dart
import 'package:jyotish/jyotish.dart';

void main() async {
  // 1. Create instance and initialize
  final jyotish = Jyotish();
  await jyotish.initialize();

  // 2. Define your location
  final location = GeographicLocation(
    latitude: 27.7172,   // Kathmandu
    longitude: 85.3240,
  );

  // 3. Calculate a planet's position
  final sun = await jyotish.getPlanetPosition(
    planet: Planet.sun,
    dateTime: DateTime.now(),
    location: location,
  );

  // 4. Use the results
  print('Sun is at: ${sun.formattedPosition}');
  print('Zodiac: ${sun.zodiacSign}');
  print('Nakshatra: ${sun.nakshatra}');
  print('Retrograde: ${sun.isRetrograde}');

  // 5. Calculate all planets
  final all = await jyotish.getAllPlanetPositions(
    dateTime: DateTime.now(),
    location: location,
  );

  all.forEach((planet, position) {
    print('${planet.displayName}: ${position.formattedPosition}');
  });

  // 6. Clean up
  jyotish.dispose();
}
```

## Sidereal (Vedic) Astrology

```dart
// Use Lahiri ayanamsa (most common in Vedic astrology)
final flags = CalculationFlags.siderealLahiri();

final moon = await jyotish.getPlanetPosition(
  planet: Planet.moon,
  dateTime: DateTime.now(),
  location: location,
  flags: flags,
);

print('Moon (Sidereal): ${moon.formattedPosition}');
print('Nakshatra: ${moon.nakshatra}');
print('Pada: ${moon.nakshatraPada}');
```

## Common Use Cases

### Birth Chart Calculation

```dart
final birthDateTime = DateTime(1990, 5, 15, 14, 30);
final birthPlace = GeographicLocation(
  latitude: 28.6139,   // New Delhi
  longitude: 77.2090,
);

final planets = await jyotish.getAllPlanetPositions(
  dateTime: birthDateTime,
  location: birthPlace,
  flags: CalculationFlags.siderealLahiri(),
);

// Now you have all planetary positions for the birth chart
```

### Current Planetary Transits

```dart
final transits = await jyotish.getAllPlanetPositions(
  dateTime: DateTime.now(),
  location: myLocation,
);

// Check what's happening in the sky right now
```

### Moon Phases and Nakshatras

```dart
final moon = await jyotish.getPlanetPosition(
  planet: Planet.moon,
  dateTime: DateTime.now(),
  location: location,
);

print('Current Nakshatra: ${moon.nakshatra}');
print('Pada: ${moon.nakshatraPada}');
print('Position: ${moon.formattedPositionDMS}');
```

## Available Planets

- **Luminaries**: `Planet.sun`, `Planet.moon`
- **Inner Planets**: `Planet.mercury`, `Planet.venus`, `Planet.mars`
- **Outer Planets**: `Planet.jupiter`, `Planet.saturn`, `Planet.uranus`, `Planet.neptune`, `Planet.pluto`
- **Lunar Nodes**: `Planet.meanNode` (Rahu), `Planet.trueNode`
- **Asteroids**: `Planet.chiron`, `Planet.ceres`, `Planet.pallas`, `Planet.juno`, `Planet.vesta`

## Important Notes

### Setup Requirements

The library requires the Swiss Ephemeris native library. See [SETUP.md](SETUP.md) for detailed installation instructions.

### Ephemeris Data

For production use, download and include Swiss Ephemeris data files for improved accuracy. See [SETUP.md](SETUP.md) for details.

### Error Handling

Always wrap calculations in try-catch:

```dart
try {
  final position = await jyotish.getPlanetPosition(...);
} on JyotishException catch (e) {
  print('Error: $e');
}
```

## What's Inside PlanetPosition?

```dart
position.longitude         // 0-360 degrees
position.latitude          // -90 to 90 degrees
position.distance          // Distance in AU
position.zodiacSign        // "Aries", "Taurus", etc.
position.positionInSign    // 0-30 degrees within sign
position.nakshatra         // "Ashwini", "Bharani", etc.
position.nakshatraPada     // 1-4
position.isRetrograde      // true/false
position.longitudeSpeed    // degrees per day
position.formattedPosition // "15° Taurus 30'"
```

## Next Steps

1. ✅ Read [SETUP.md](SETUP.md) for installation
2. ✅ Check out the [example app](example/)
3. ✅ Read the full [README.md](README.md)
4. ✅ Explore the API documentation
5. ✅ Join our community and contribute!

## Get Help

- 📖 [Full Documentation](README.md)
- 🔧 [Setup Guide](SETUP.md)
- 💡 [Examples](example/)
- 🐛 [Report Issues](https://github.com/yourusername/jyotish/issues)

---

Happy coding with Jyotish! 🌟
