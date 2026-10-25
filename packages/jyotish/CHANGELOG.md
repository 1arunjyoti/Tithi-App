# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- `CalculationFlags.nativeSidereal()` / `useNativeSidereal` for opt-in
  `SEFLG_SIDEREAL` planetary positions.
- `EphemerisService.calculatePlanetPositions` and `calculateSunMoon`, plus
  `Jyotish.getSunMoonPositions`, for one state-aware Panchang batch.
- `EphemerisService.clearCache()`.

### Changed

- Position cache uses typed keys including the exact instant, frame, ayanamsa,
  engine version and topocentric altitude; geocentric entries omit location.
- `getMultiplePlanetPositions` no longer uses `Future.wait`; FFI calls are
  synchronous and now share one state setup and error buffer.
- `SiderealMode.name` is the stable enum name again; display text moved to
  `label`, and `persistenceKey` exposes the integer constant.

### Fixed

- Native sidereal and manual sidereal results can no longer share a cache entry.

## [1.0.1] - 2025-11-25

### Fixed

- Fixed package validation errors for pub.dev publishing
- Improved export organization (alphabetically sorted)

## [1.0.0] - 2025-10-19

### Added

- Initial release of Jyotish library
- Swiss Ephemeris integration via FFI
- Support for all major planets (Sun through Pluto)
- Lunar nodes (Mean and True Node)
- Lunar apogees (Black Moon Lilith)
- Major asteroids (Chiron, Pholus, Ceres, Pallas, Juno, Vesta)
- Tropical and sidereal zodiac calculations
- 40+ ayanamsa systems for sidereal calculations
- Geocentric and topocentric position calculations
- Retrograde detection
- Nakshatra (lunar mansion) calculations
- Zodiac sign and position calculations
- Speed/velocity calculations
- Comprehensive error handling
- Input validation
- Production-ready API
- Full documentation and examples
- Example Flutter app
- Platform support: Android, iOS, macOS, Linux, Windows

### Features

- High-precision astronomical calculations
- Easy-to-use API
- Batch planet calculations
- Flexible calculation flags
- Geographic location support with DMS conversion
- JSON serialization support
- Proper resource management

[1.0.1]: https://github.com/rajsanjib/jyotish-flutter-library/releases/tag/v1.0.1
[1.0.0]: https://github.com/rajsanjib/jyotish-flutter-library/releases/tag/v1.0.0
