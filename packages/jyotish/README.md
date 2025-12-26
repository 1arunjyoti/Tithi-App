# Jyotish

A production-ready Flutter library for Vedic astrology calculations using Swiss Ephemeris. Provides high-precision sidereal planetary positions with Lahiri ayanamsa for authentic Jyotish (Vedic astrology) applications.

[![GitHub](https://img.shields.io/badge/GitHub-rajsanjib%2Fjyotish--flutter--library-blue?logo=github)](https://github.com/rajsanjib/jyotish-flutter-library)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Flutter](https://img.shields.io/badge/Flutter-%3E%3D3.0.0-blue?logo=flutter)](https://flutter.dev)

## Features

✨ **High-Precision Sidereal Calculations**: Uses Swiss Ephemeris with Lahiri ayanamsa for accurate Vedic astrology

🌍 **Authentic Vedic System**:

- Sidereal zodiac
- Lahiri ayanamsa (default) with support for 40+ other ayanamsas
- Geocentric and topocentric calculations

🪐 **Comprehensive Planet Support**:

- Traditional Vedic planets (Sun, Moon, Mercury, Venus, Mars, Jupiter, Saturn)
- Rahu and Ketu (Lunar Nodes)
- Optional outer planets (Uranus, Neptune, Pluto)
- Lunar apogees and asteroids

📍 **Rich Vedic Data**:

- Sidereal longitude, latitude, and distance
- Zodiac sign and position within sign
- 27 Nakshatras with pada (quarter) divisions
- Retrograde detection
- Velocity/speed calculations

🎯 **Complete Vedic Chart**:

- Birth chart calculation with house cusps
- Rahu and Ketu positions
- Planetary dignities (exaltation, debilitation, own sign, moola trikona)
- Combustion detection
- Whole Sign house system

🎯 **Easy to Use**: Simple, intuitive API designed for Vedic astrology

🔒 **Production Ready**: Proper error handling, input validation, and resource management

## Platform Support

| Platform | Support |
| -------- | ------- |
| Android  | ✅      |
| iOS      | ✅      |
| macOS    | ✅      |
| Linux    | ✅      |
| Windows  | ✅      |

## Installation

Add this to your package's `pubspec.yaml` file:

```yaml
dependencies:
  jyotish:
    git:
      url: https://github.com/rajsanjib/jyotish-flutter-library.git
      ref: main # or specify a tag/branch
```

Then run:

```bash
flutter pub get
```

### Alternative Installation Methods

You can also specify a specific version or branch:

**Using a specific tag/version:**

```yaml
dependencies:
  jyotish:
    git:
      url: https://github.com/rajsanjib/jyotish-flutter-library.git
      ref: v1.0.0 # Replace with desired version tag
```

**Using a specific branch:**

```yaml
dependencies:
  jyotish:
    git:
      url: https://github.com/rajsanjib/jyotish-flutter-library.git
      ref: develop # or any other branch
```

**For local development:**

```yaml
dependencies:
  jyotish:
    path: ../path/to/jyotish # Relative path to local library
```

### Swiss Ephemeris Data Files

The library requires Swiss Ephemeris data files for calculations. You have two options:

1. **Include data files in your app** (recommended for production):

   - Download ephemeris files from [Swiss Ephemeris](https://www.astro.com/ftp/swisseph/ephe/)
   - Place them in your app's assets folder
   - Initialize with the path to the data files

2. **Use built-in ephemeris** (limited accuracy):
   - The library includes a basic ephemeris for quick testing
   - Not recommended for production use

## Usage

### Basic Example

```dart
import 'package:jyotish/jyotish.dart';

void main() async {
  // Create an instance
  final jyotish = Jyotish();

  // Initialize the library
  await jyotish.initialize();

  // Define a location
  final location = GeographicLocation(
    latitude: 27.7172,  // Kathmandu, Nepal
    longitude: 85.3240,
    altitude: 1400,
  );

  // Calculate Sun's position (always sidereal with Lahiri ayanamsa)
  final sunPosition = await jyotish.getPlanetPosition(
    planet: Planet.sun,
    dateTime: DateTime.now(),
    location: location,
  );

  print('Sun is at ${sunPosition.formattedPosition}'); // Sidereal position
  print('Longitude: ${sunPosition.longitude}°');
  print('Nakshatra: ${sunPosition.nakshatra}');
  print('Is Retrograde: ${sunPosition.isRetrograde}');

  // Clean up
  jyotish.dispose();
}
```

### Calculate Multiple Planets

```dart
// Calculate all traditional Vedic planets at once
final positions = await jyotish.getAllPlanetPositions(
  dateTime: DateTime(2024, 1, 1, 12, 0),
  location: location,
);

for (final entry in positions.entries) {
  print('${entry.key.displayName}: ${entry.value.formattedPosition}');
}
```

### Custom Ayanamsa

```dart
// Use a different ayanamsa (default is Lahiri)
final flags = CalculationFlags.sidereal(SiderealMode.krishnamurti);

final position = await jyotish.getPlanetPosition(
  planet: Planet.moon,
  dateTime: DateTime.now(),
  location: location,
  flags: flags,
);
```

### Advanced: Custom Calculation Flags

```dart
// Create custom calculation flags
final flags = CalculationFlags(
  siderealMode: SiderealMode.krishnamurti,
  useTopocentric: true,
  calculateSpeed: true,
);

final position = await jyotish.getPlanetPosition(
  planet: Planet.mars,
  dateTime: DateTime.now(),
  location: location,
  flags: flags,
);
```

### Vedic Astrology Chart

```dart
// Calculate a complete Vedic astrology birth chart
final chart = await jyotish.calculateVedicChart(
  dateTime: DateTime(1990, 5, 15, 14, 30), // Birth time
  location: location, // Birth place
);

// Access Ascendant (Lagna)
print('Ascendant: ${chart.ascendantSign}');
print('Ascendant Degree: ${chart.ascendant}°');

// Access planetary positions with Vedic-specific data
final sunInfo = chart.getPlanet(Planet.sun);
if (sunInfo != null) {
  print('Sun in ${sunInfo.zodiacSign}');
  print('House: ${sunInfo.house}');
  print('Nakshatra: ${sunInfo.nakshatra} (Pada ${sunInfo.pada})');
  print('Dignity: ${sunInfo.dignity.english}'); // e.g., "Exalted", "Debilitated"
  print('Combust: ${sunInfo.isCombust}');
}

// Access Rahu (North Node) and Ketu (South Node)
print('Rahu in ${chart.rahu.zodiacSign} - House ${chart.rahu.house}');
print('Ketu in ${chart.ketu.zodiacSign} - always 180° from Rahu');

// Get planets by house
final firstHousePlanets = chart.getPlanetsInHouse(1);

// Get planets by dignity
final exaltedPlanets = chart.exaltedPlanets;
final debilitatedPlanets = chart.debilitatedPlanets;
final combustPlanets = chart.combustPlanets;
final retrogradePlanets = chart.retrogradePlanets;

// Access house cusps
for (int i = 0; i < 12; i++) {
  print('House ${i + 1}: ${chart.houses.cusps[i]}°');
}
```

**Vedic Features:**

- ✨ Sidereal zodiac with Lahiri ayanamsa (authentic Vedic calculations)
- 🏠 Whole Sign house system
- 🌟 Rahu (North Node) and Ketu (South Node) as separate entities
- 🎯 Planetary dignities: Exalted, Debilitated, Own Sign, Moola Trikona, etc.
- 🔥 Combustion detection (planets too close to Sun)
- 📍 27 Nakshatras with pada (quarter) divisions
- ♃ Retrograde motion detection
- 🌍 Support for 40+ different ayanamsas (Lahiri, Krishnamurti, Raman, etc.)

**Note**: This library is designed specifically for Vedic astrology and uses sidereal calculations. All planetary positions are calculated in the sidereal zodiac, not tropical (Western astrology).

### Location from Degrees, Minutes, Seconds

```dart
final location = GeographicLocation.fromDMS(
  latDegrees: 27,
  latMinutes: 43,
  latSeconds: 1.92,
  isNorth: true,
  lonDegrees: 85,
  lonMinutes: 19,
  lonSeconds: 26.4,
  isEast: true,
  altitude: 1400,
);
```

## API Reference

### Main Classes

#### `Jyotish`

The main entry point for the library.

- `initialize({String? ephemerisPath})`: Initialize the library
- `getPlanetPosition(...)`: Calculate a single planet's position
- `getMultiplePlanetPositions(...)`: Calculate multiple planets
- `getAllPlanetPositions(...)`: Calculate all major planets
- `dispose()`: Clean up resources

#### `Planet` (enum)

Enumeration of supported celestial bodies.

Available planets:

- `Planet.sun`, `Planet.moon`
- `Planet.mercury`, `Planet.venus`, `Planet.mars`
- `Planet.jupiter`, `Planet.saturn`
- `Planet.uranus`, `Planet.neptune`, `Planet.pluto`
- `Planet.meanNode`, `Planet.trueNode`
- `Planet.chiron`, `Planet.ceres`, etc.

Static methods:

- `Planet.majorPlanets`: Sun through Pluto
- `Planet.traditionalPlanets`: Sun through Saturn
- `Planet.asteroids`: Chiron, Ceres, Pallas, Juno, Vesta

#### `PlanetPosition`

Contains calculated position data.

Properties:

- `longitude`: Ecliptic longitude (0-360°)
- `latitude`: Ecliptic latitude
- `distance`: Distance from Earth in AU
- `longitudeSpeed`: Degrees per day
- `zodiacSign`: Name of zodiac sign
- `positionInSign`: Degrees within sign (0-30°)
- `nakshatra`: Indian lunar mansion name
- `nakshatraPada`: Quarter of nakshatra (1-4)
- `isRetrograde`: Whether planet is in retrograde motion
- `formattedPosition`: Human-readable position string

#### `GeographicLocation`

Represents a location on Earth.

Properties:

- `latitude`: -90 to 90 (North positive)
- `longitude`: -180 to 180 (East positive)
- `altitude`: Meters above sea level

#### `CalculationFlags`

Controls calculation behavior.

Factory constructors:

- `CalculationFlags.defaultFlags()`: Tropical, geocentric
- `CalculationFlags.siderealLahiri()`: Sidereal with Lahiri ayanamsa
- `CalculationFlags.sidereal(SiderealMode)`: Custom sidereal mode
- `CalculationFlags.topocentric()`: Topocentric calculations

#### `SiderealMode` (enum)

Available ayanamsa systems for sidereal calculations.

Popular modes:

- `SiderealMode.lahiri`: Most common in Indian astrology
- `SiderealMode.faganBradley`: Western sidereal astrology
- `SiderealMode.krishnamurti`: KP astrology
- `SiderealMode.raman`: Raman ayanamsa
- 40+ other modes available

## Error Handling

The library throws specific exception types:

```dart
try {
  final position = await jyotish.getPlanetPosition(...);
} on InitializationException catch (e) {
  print('Failed to initialize: $e');
} on CalculationException catch (e) {
  print('Calculation failed: $e');
} on ValidationException catch (e) {
  print('Invalid input: $e');
} on JyotishException catch (e) {
  print('General error: $e');
}
```

## Example App

Run the example app to see the library in action:

```bash
cd example
flutter run
```

The example app demonstrates:

- Calculating all major planet positions
- Switching between tropical and sidereal zodiac
- Displaying position in multiple formats
- Showing nakshatra and retrograde status

## Advanced Topics

### Custom Ephemeris Path

```dart
await jyotish.initialize(
  ephemerisPath: '/path/to/ephemeris/files',
);
```

### Topocentric vs Geocentric

Geocentric positions are calculated from Earth's center (default).
Topocentric positions are calculated from a specific location on Earth's surface.

```dart
final flags = CalculationFlags(useTopocentric: true);
```

### Understanding Ayanamsa

The ayanamsa is the difference between tropical and sidereal zodiac systems. Different systems use different reference points:

- **Lahiri**: Official ayanamsa of India
- **Fagan-Bradley**: Popular in Western sidereal astrology
- **Krishnamurti**: Used in KP system

Get current ayanamsa value:

```dart
final service = EphemerisService();
await service.initialize();
final ayanamsa = await service.getAyanamsa(
  dateTime: DateTime.now(),
  mode: SiderealMode.lahiri,
);
print('Lahiri Ayanamsa: ${ayanamsa.toStringAsFixed(6)}°');
```

## Performance Considerations

1. **Initialization**: Call `initialize()` once at app startup
2. **Batch Calculations**: Use `getMultiplePlanetPositions()` for multiple planets
3. **Caching**: Consider caching results if querying the same time repeatedly
4. **Resource Management**: Always call `dispose()` when done

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

This library is licensed under the MIT License. See the [LICENSE](LICENSE) file for details.

Swiss Ephemeris is licensed under GNU GPL v2 or Swiss Ephemeris Professional License.

## Credits

This library uses:

- [Swiss Ephemeris](https://www.astro.com/swisseph/) by Astrodienst AG
- Developed with ❤️ for the Flutter community

## Support

- Issues: [GitHub Issues](https://github.com/rajsanjib/jyotish-flutter-library/issues)
- 📖 Documentation: [GitHub Wiki](https://github.com/rajsanjib/jyotish-flutter-library/wiki)
- 💬 Discussions: [GitHub Discussions](https://github.com/rajsanjib/jyotish-flutter-library/discussions)

## Changelog

See [CHANGELOG.md](CHANGELOG.md) for version history.

## Roadmap

- [ ] House calculations
- [ ] Aspect calculations
- [ ] Transit calculations
- [ ] Dasha system support
- [ ] Chart drawing utilities
- [ ] More example apps

---

Made with ❤️ using Swiss Ephemeris
