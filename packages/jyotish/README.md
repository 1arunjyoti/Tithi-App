# Jyotish

A production-ready Flutter library for Vedic astrology calculations using Swiss Ephemeris. Provides high-precision sidereal planetary positions with Lahiri ayanamsa for authentic Jyotish (Vedic astrology) applications.

[![GitHub](https://img.shields.io/badge/GitHub-1arunjyoti%2FTithi--App-blue?logo=github)](https://github.com/1arunjyoti/Tithi-App)
[![License: AGPL-3.0](https://img.shields.io/badge/License-AGPL--3.0-blue.svg)](./LICENSE)
[![Swiss Ephemeris: AGPL-3.0](https://img.shields.io/badge/Swiss%20Ephemeris-AGPL--3.0-orange.svg)](./NOTICE)
[![Flutter](https://img.shields.io/badge/Flutter-%3E%3D3.0.0-blue?logo=flutter)](https://flutter.dev)

## Platform support

**Android only.** The package declares a single native platform because it is
the only one with a real build:

| Platform | Native Swiss Ephemeris | Status |
| --- | --- | --- |
| Android | Yes - `libswisseph.so` for `arm64-v8a`, `armeabi-v7a`, `x86_64` | Supported |
| iOS, macOS, Linux, Windows | No - plugin scaffolding only | Not supported |

The `ios/`, `macos/`, `linux/` and `windows/` directories contain Flutter
plugin stubs. They compile no Swiss Ephemeris, so on those platforms
`DynamicLibrary.open` fails and the host app falls back to its own
approximations. Do not add a platform to `pubspec.yaml` until it has a CMake or
podspec target that builds the library and a smoke test that proves it.

## License

Tithi and this wrapper are distributed under the **GNU Affero General Public
License v3** (see [LICENSE](./LICENSE)). The bundled Swiss Ephemeris C sources
and `.se1` data files are dual-licensed by Astrodienst AG under AGPLv3 or a
paid Professional license; this project uses the AGPLv3 option. Read
[NOTICE](./NOTICE) before distributing anything that contains them.

The wrapper is a fork of `rajsanjib/jyotish-flutter-library`, whose MIT license
is preserved in [LICENSE-MIT-upstream](./LICENSE-MIT-upstream). The package
keeps `publish_to: none` because the `jyotish` name belongs to that upstream
package; consume it as a path or git dependency.

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

## Installation

This package is not published to pub.dev. The `jyotish` name on pub.dev
belongs to the upstream project this is a fork of, and the fork is AGPLv3 (see
[NOTICE](./NOTICE)). Consume it from the Tithi repository instead:

```yaml
dependencies:
  jyotish:
    git:
      url: https://github.com/1arunjyoti/Tithi-App.git
      path: packages/jyotish
      ref: main # or a tag/branch that contains the fixes you need
```

Then run:

```bash
flutter pub get
```

### Alternative Installation Methods

**Using a specific tag/version:**

```yaml
dependencies:
  jyotish:
    git:
      url: https://github.com/1arunjyoti/Tithi-App.git
      path: packages/jyotish
      ref: v1.0.0 # Replace with desired version tag
```

**Using a specific branch:**

```yaml
dependencies:
  jyotish:
    git:
      url: https://github.com/1arunjyoti/Tithi-App.git
      path: packages/jyotish
      ref: feat/panchang-engine # or any other branch
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

### Provenance and loaded data range

Every position records which backend actually produced it. A missing `.se1`
file does not fail the calculation - Swiss Ephemeris falls back to Moshier - so
check provenance before treating a result as Swiss Ephemeris output:

```dart
final position = await jyotish.getPlanetPosition(...);
print(position.provenance?.backend);     // swiss, jpl, moshier or automatic
print(position.provenance?.usedFallback); // true for Moshier
```

`CalculationFlags(requireSwissEphemeris: true)` throws
`EphemerisBackendException` instead of returning a Moshier fallback.

To verify the actual files and years an install loaded:

```dart
final range = await jyotish.probeDataRange();
print(range.planets?.path);            // e.g. .../sepl_18.se1
print(range.coversYears(1800, 2399));  // app policy, not a package default
```

The package reports what loaded and does not hardcode an asset range; each
application decides which years its install must cover.

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

### Native sidereal frame

By default the package preserves its historical output: it calculates a
planet tropically, then subtracts `swe_get_ayanamsa_ut()` from the ecliptic
longitude. To let Swiss Ephemeris apply the ayanamsa, opt in explicitly:

```dart
final flags = CalculationFlags.nativeSidereal(SiderealMode.lahiri);
final sun = await jyotish.getPlanetPosition(
  planet: Planet.sun,
  dateTime: DateTime.now(),
  location: location,
  flags: flags,
);
```

`useNativeSidereal` sets `SEFLG_SIDEREAL`, validates that the engine returned
that frame, and skips the Dart subtraction. It cannot be combined with
`useTropical: true`. Native and manual Lahiri longitudes agree to well under an
arcminute in the package tests; the flag remains opt-in until app-level charts
have adopted it.

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

`calculateVedicChart` defaults to Whole Sign. Pass a Swiss Ephemeris
house-system code to request another system, for example
`houseSystem: 'P'` for Placidus. Cusps and angles are calculated in the
sidereal frame directly by `swe_houses_ex`, not by subtracting ayanamsa from
tropical cusps.

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

- `initialize({String? ephemerisPath})`: Initialize the library; concurrent
  calls in one isolate share one in-flight future, and every isolate must call
  it itself
- `getPlanetPosition(...)`: Calculate a single planet's position
- `getMultiplePlanetPositions(...)`: Calculate multiple planets in one state-aware batch
- `getSunMoonPositions(...)`: Calculate the Sun and Moon together for Panchang work
- `getAllPlanetPositions(...)`: Calculate all major planets
- `probeDataRange()`: Report the Swiss Ephemeris files and years actually loaded
- `clearCache()`: Drop the in-memory position cache (keys already include all inputs)
- `dispose()`: Clean up resources and cancel an in-flight initialization

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

- `CalculationFlags.defaultFlags()`: Sidereal (Lahiri), geocentric
- `CalculationFlags.siderealLahiri()`: Sidereal with Lahiri ayanamsa
- `CalculationFlags.sidereal(SiderealMode)`: Custom sidereal mode, historical
  path that subtracts ayanamsa from the tropical longitude in Dart
- `CalculationFlags.nativeSidereal(SiderealMode)`: Opt in to
  `SEFLG_SIDEREAL` so Swiss Ephemeris applies the ayanamsa
- `CalculationFlags.topocentric()`: Topocentric calculations
- `CalculationFlags(requireSwissEphemeris: true)`: Reject a Moshier fallback
  instead of returning it as Swiss Ephemeris output

`CalculationFlags` implements value equality. The default sidereal path is
unchanged until the native and historical frames have been compared on real
charts; see [Native sidereal frame](#native-sidereal-frame).

#### `SiderealMode` (enum)

Available ayanamsa systems for sidereal calculations.

Popular modes:

- `SiderealMode.lahiri`: Most common in Indian astrology
- `SiderealMode.faganBradley`: Western sidereal astrology
- `SiderealMode.krishnamurti`: KP astrology
- `SiderealMode.raman`: Raman ayanamsa
- 40+ other modes available

`SiderealMode.name` is the stable enum identifier and `persistenceKey` is the
Swiss Ephemeris integer. Both are safe in storage and cache keys. `label` is
display text only: it may be reworded, so never persist it.

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
2. **Batch Calculations**: Use `getMultiplePlanetPositions()` for multiple
   planets, or `getSunMoonPositions()` when a Panchang needs both bodies. FFI
   calls are synchronous, so these run as one ordered batch: global state is
   applied once and one native error buffer is reused. `Future.wait` would not
   make them parallel.
3. **Caching**: Positions are cached in memory under a typed key containing the
   instant, frame, ayanamsa, engine version, and — for topocentric requests —
   latitude, longitude and altitude. Geocentric entries intentionally omit the
   observer location. Use `clearCache()` only to release memory or force a
   fresh native calculation; `Jyotish.clearCache()` exposes the same for facade
   users.
4. **Resource Management**: Always call `dispose()` when done; it clears the
   cache and cancels an in-flight initialization.

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

The `jyotish-js/` directory is an incomplete, private TypeScript scaffold and
is not part of this Dart package's API or CI. See its README before adding work
there.

## License

Tithi is licensed under the GNU Affero General Public License v3. See the
[LICENSE](LICENSE) file for the full text and [NOTICE](./NOTICE) for the
Swiss Ephemeris terms.

Swiss Ephemeris is dual-licensed by Astrodienst AG: this project uses the
AGPLv3 option (not the Professional License), which is why the app itself is
AGPLv3.

## Credits

This library uses:

- [Swiss Ephemeris](https://www.astro.com/swisseph/) by Astrodienst AG
- Developed with ❤️ for the Flutter community

## Support

- Issues: [GitHub Issues](https://github.com/1arunjyoti/Tithi-App/issues)
- 📖 Documentation: [GitHub Wiki](https://github.com/1arunjyoti/Tithi-App/tree/main/packages/jyotish)
- 💬 Discussions: [GitHub Discussions](https://github.com/1arunjyoti/Tithi-App/discussions)

## Changelog

See [CHANGELOG.md](CHANGELOG.md) for version history.

## Roadmap

- [x] House calculations
- [ ] Aspect calculations
- [ ] Transit calculations
- [ ] Dasha system support
- [ ] Chart drawing utilities
- [ ] More example apps

---

Made with ❤️ using Swiss Ephemeris
