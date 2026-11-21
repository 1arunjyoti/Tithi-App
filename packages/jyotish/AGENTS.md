# AGENTS.md - jyotish (local FFI package)

Swiss Ephemeris FFI bindings consumed by the Tithi app as a path dependency
(`jyotish: path: packages/jyotish`). Not published (`publish_to: none`).
AGPLv3 because it bundles Swiss Ephemeris - read `NOTICE` before changing
distribution.

App-level rules live in the root `AGENTS.md`; this file only covers the native
package.

## Platform support

**Android only.** `pubspec.yaml` declares `platforms: { android: { ffiPlugin: true } }`
and the CMake target compiles Swiss Ephemeris into `libswisseph.so` for
`arm64-v8a`, `armeabi-v7a`, `x86_64`.

`ios/`, `linux/`, `macos/`, `windows/` are scaffolding only: they build no Swiss
Ephemeris. Do not add them to `platforms:` unless you also add a build target
and a smoke test - otherwise consumers silently get an approximation.

## Map

| Path | Responsibility |
|---|---|
| `lib/jyotish.dart` | Public barrel - the only import surface for the app. |
| `lib/src/jyotish_core.dart` | `initJyotish` / `disposeJyotish`, ephemeris path resolution. |
| `lib/src/bindings/swisseph_bindings.dart` | Raw FFI bindings (**large**, generated-style - do not hand-edit casually). |
| `lib/src/services/ephemeris_service.dart` | Positions, rise/set, sidereal helpers, position cache (**large**). |
| `lib/src/services/vedic_chart_service.dart` | Houses/chart. |
| `lib/src/services/planetary_dignity.dart` | Dignity/exaltation tables. |
| `lib/src/models/` | `Planet`, `PlanetPosition`, `SunMoonPositions`, `GeographicLocation`, `CalculationFlags`, `EphemerisProvenance`, `EphemerisDataRange`, `VedicChart`. |
| `lib/src/constants/planet_constants.dart` | Swiss Ephemeris body IDs. |
| `android/src/main/cpp/CMakeLists.txt` | Android native build. `SWISSEPH_SRC` must stay in sync with `.github/workflows/ci.yml`. |
| `native/swisseph/` | Vendored Swiss Ephemeris C sources. |
| `test/` | Package tests (see below). |
| `scripts/` | Standalone examples, not part of the build. |

## Rules

- Keep `SWISSEPH_SRC` in `android/src/main/cpp/CMakeLists.txt` identical to the
  file list CI compiles. Adding a C source in one place only breaks the other.
- Do not add a platform to `platforms:` without a build target and a smoke test.
- `lib/src/bindings/swisseph_bindings.dart` mirrors the C headers; change it
  only alongside the corresponding `native/swisseph/` source.
- The app owns lifecycle: `initJyotish` once at startup, `disposeJyotish` on
  app teardown (`lib/main.dart`). Do not init per call.
- No web target anywhere in this package.

## Tests

Host tests need `SWISSEPH_LIB_PATH` pointing at a built `libswisseph.so`
(CI builds it from `native/swisseph/swisseph-master/src`). Without it, tests
fail with `Failed to initialize Jyotish` - they do not skip.

```bash
cd packages/jyotish
flutter test                       # needs SWISSEPH_LIB_PATH
flutter test test/jyotish_test.dart
```

| Test | Covers |
|---|---|
| `jyotish_test.dart` | Init/dispose, position basics. |
| `native_sidereal_test.dart` | Sidereal mode + ayanamsa. |
| `equatorial_frame_test.dart` | Frame conversions. |
| `houses_test.dart` | House cusps. |
| `position_cache_test.dart` | Position cache correctness. |
| `planetary_dignity_test.dart` | Dignity tables. |
| `geographic_location_test.dart` | Coordinate model. |
| `calculation_flags_test.dart` | Flag combinations. |
| `ephemeris_provenance_test.dart` | Data-range/provenance reporting. |

On Windows the host cannot build or run the real ephemeris. Validate with a
device build or `integration_test/` in the app.

## Build

```bash
cd packages/jyotish && flutter pub get    # requires Android NDK for the native target
```
