# Jyotish and Panchang Improvement Plan

## Objective and scope

Make Tithi an India-first, location-specific Drik Panchang engine while
keeping `packages/jyotish` a correct, well-defined public Swiss Ephemeris
wrapper.

This plan distinguishes between:

- **Panchang-critical work**: can change an end user's daily tithi, festival,
  sunrise, or observance time.
- **Latent package/API work**: confirmed defects in public `jyotish` APIs that
  are not currently reached by the Tithi application.

The default target profile is Lahiri/Chitrapaksha, geocentric sidereal
ecliptic Sun and Moon, matched Hindu solar rise/set conventions, and Amanta as
the calculation basis.
Purnimanta and regional observance differences must be explicit profiles, not
presented as a universally correct alternative.

## Confirmed current state

- Tithi is calculated from the Sun--Moon longitude difference; ayanamsa
  cancels in this difference when the same frame is used for both bodies.
- Nakshatra, yoga, karana, masa, Adhika masa, Kshaya, Vriddhi, and several
  festival timing overrides are calculated locally. The app does not consume a
  precomputed external almanac.
- The app copies `sepl_18.se1`, `semo_18.se1`, and `seas_18.se1` before it
  initializes `jyotish` with that path. Those bundled files cover
  **1800--2399 CE**.
- The package's manual ayanamsa subtraction is not itself the primary
  Panchang defect for ordinary ecliptic longitude. Its confirmed error is that
  it is also applied to right ascension when equatorial coordinates are
  requested.
- The active app's highest date-assignment risk is its NOAA-style apparent
  sunrise calculation, not houses or planetary dignity.

## Phase 0 — contract, profile, and reference data

Create a versioned `PanchangProfile` domain model. `FestivalRegion` must not
be reused: it is a display-ordering preference only.

The profile must record:

- ayanamsa, with Lahiri as the default;
- month system: Amanta or Purnimanta;
- matched sunrise and sunset conventions;
- a separate Moon rise/set convention, including limb and refraction policy;
- IANA timezone for the selected place;
- festival-observance policy for sunrise, Madhyahna, Aparahna, Nishita,
  Pradosha, moonrise, Kshaya, Vriddhi, and dominant tithi;
- node convention and any regional rule set; and
- a calculation-engine version.

Extend `LocationData` and its persisted settings with altitude and timezone.
This is a data-model/storage migration, not a presentation setting: the
current model stores only latitude, longitude, city name, and timestamp.

Build a locked golden-reference dataset before changing behavior. Cover Delhi,
Kolkata, Mumbai, Varanasi, Chennai, and Guwahati; sunrise boundaries;
Kshaya/Vriddhi; Ekadashi; Amavasya/Purnima; Sankranti; Adhika masa; Bengali
dates; and dates immediately around a new moon/Sankranti coincidence. Record
the source, profile, location, timezone, instant precision, and tolerance for
every fixture. Do not copy proprietary app output without permission.

## Phase 1 — solar-events seam and Hindu rise/set migration (highest priority)

First route every current `SunriseCalculator` caller through one cached,
behavior-preserving solar-events provider or precomputed `PanchangDay` value.
It must initially delegate to the current NOAA-style calculator. This covers
calendar/day assembly, detail sheets, widgets, notifications, export,
`HinduCalendarService`, and Bengali calendar paths before any astronomical
behavior changes.

Phase 1 status: complete.

- **1a (seam):** `SolarEventsService` in
  `lib/services/solar_events_service.dart` is the single cached entry point;
  every production caller above reads it, and the Phase 0 golden set passed
  unchanged under `panchang-v1`.
- **1b (native convention):** `SwissSolarEventCalculator` now calls
  `swe_rise_trans()` with `SE_BIT_HINDU_RISING` (disc centre, no refraction,
  geocentric, no ecliptic latitude). `PanchangService.init()` configures it
  synchronously after the ephemeris files are copied and
  `Jyotish().initialize()` completes; a failure keeps the labelled NOAA
  fallback. Non-Android targets use that fallback until Phase 6 builds the
  native library for them.
- `kPanchangCalculationVersion` is `2` and `locationSignature` carries the
  version, so Hive caches from the NOAA convention are misses. In-memory
  Panchang/solar caches are cleared on initialization.
- `resolvedSolarContextProvider` supplies latitude, longitude, altitude, and
  IANA timezone to the main Panchang and calendar-flag compute paths. The
  Hindu convention is geocentric, so altitude does not move the event instant;
  the timezone is carried so events use the place zone. Timing/follow-on
  searches still pass latitude/longitude and are instant-equivalent.
- Call sites that only know latitude/longitude (detail sheets, notification
  scheduling, export, Bengali calendar, home widget, festival search) resolve
  through `SolarEventsService.placeTimezoneId`, published by
  `currentLocationProvider` in the UI isolate and from the persisted
  `cached_timezone` key in the notification background isolate. An explicit
  `timezoneId` argument still wins. This is a bridge, not the Phase 2 model.
- Remaining source limitation: `resolvePlaceTimezoneId` still seeds the zone
  from the device clock because the app ships no coordinate-to-zone table.
  India-first that is correct (one zone), but a user abroad viewing an Indian
  place gets the device zone. The place-lookup table is deferred with the
  Phase 2 place context; `timezone_resolver.dart` documents the limitation.
- The 82-case golden set was recaptured deliberately. The only semantic
  festival change is Delhi `2026-06-30`: the native sunrise moves past the
  Purnima -> Pratipada transition, so `[purnima]` becomes `[]` and the tithi is
  Krishna Pratipada. All sunrise/sunset values shift by roughly 3-5 minutes.
- The Janmashtami nishita defect remains the Phase 2 change described below;
  it is not part of the Phase 1b fixture recapture.

The implementation requirements were:

- Bind `swe_rise_trans()` and expose the required rise/set constants.
- Implement `SE_BIT_HINDU_RISING` as Tithi's Hindu solar-rise and solar-set
  default. It is the Swiss Ephemeris primitive for disc-centre,
  no-refraction, geocentric Hindu rising/setting.
- Keep seconds internally; round only for UI text.
- Make polar/no-rise conditions explicit errors or states rather than returning
  a fabricated 06:00/18:00 value.
- Resolve local civil time from the selected location's IANA timezone, not the
  device timezone.
- Version the convention and invalidate all Panchang/festival caches when it
  changes.
- `swe_rise_trans()` keeps only `SEFLG_EPHMASK | SEFLG_NONUT | SEFLG_TRUEPOS`
  from the ephemeris flag, so pass the backend only; `SEFLG_SIDEREAL` and
  `SEFLG_EQUATORIAL` are stripped. It calls `swe_set_topo(geopos[0..2])`
  internally for topocentric events and rejects `geopos[2]` outside
  `SEI_ECL_GEOALT_MIN..MAX`, so altitude is required for lunar events.
- Until Phase 6, this binding links only on Android: `swecl.c` is compiled only
  by `android/src/main/cpp/CMakeLists.txt`; Windows and Linux build an empty
  stub, and the iOS/macOS podspecs vendor no library. Keep a labelled NOAA
  fallback for other targets, or declare Android-only distribution.

Each festival rule is anchored to the local sunrise day. Ordinary rules sample
at sunrise; timing overrides sample Madhyahna, Aparahna, Nishita, Pradosha, or
moonrise checkpoints derived from sunrise, sunset, next sunrise, and moonrise.
This migration can move boundary-day results, so ship it only with the Phase 0
references and a visible methodology/version update.

## Phase 2 — one Panchang day and observance resolver

Create one application-domain Panchang computation pipeline. This is **new
domain work**, not a move from `jyotish`: `jyotish` currently has no tithi,
nakshatra, yoga, karana, masa, or festival concepts.

The canonical resolver must produce:

- Sun/Moon longitudes and provenance at requested instants;
- sunrise, sunset, next sunrise, moonrise, and moonset;
- tithi, nakshatra, yoga, karana, and their transition instants;
- Amanta masa, Adhika verdict, and display-system conversion;
- all festival checkpoint values; and
- a versioned calculation/provenance record.

**Missing solar events are data, not exceptions (Phase 2 acceptance
criterion).** At polar latitudes the Sun may not rise or set on a civil day.
`SolarEventsService` already reports that as `SolarEventUnavailable` instead
of a fabricated 06:00/18:00, but no production caller catches it, so such a
day currently fails as a computation error. The canonical day must carry
nullable sunrise, sunset, next sunrise, moonrise, and moonset, and the
calendar grid, detail sheets, notification scheduling, and export must skip
or label the missing event while still rendering the rest of the day. Do not
add a defensive `try/catch` before the day model exists: it would invent a UI
policy that this resolver then has to undo.

Route the calendar grid, detail sheets, widgets, notifications, exports,
search/countdowns, and event sheets through it. In particular, eliminate the
inline copy of sunrise/override/dominant/Kshaya matching in
`PanchangService.findNextFestivalOccurrence`.

Current day assembly is duplicated in `tithi_transitions.dart`, notification
scheduling, festival export, and `HinduCalendarService`; each duplicate is a
future behavior-drift risk.

Make the moonrise checkpoint real. `timingOverrideCheckpoints` and
`PanchangData.fromRawTithi` currently omit `'moonrise'` (it falls through to the
sunrise tithi), while `PanchangRules` documents it as valid. Shipped Karva
Chauth uses `pujaKala`/`paranRule: moonrise`, so its puja window follows
moonrise while its tithi match follows sunrise. Add `'moonrise'` to the
checkpoint set, the matcher, and the scheduler, and record the chosen policy in
`PanchangProfile`.

### Nishita checkpoint: Janmashtami boundary defect

The locked baseline exposes a real engine defect, not a fixture error.
`delhi-2026-09-04` and `mumbai-2026-09-04` resolve no `janmashtami`, although
`docs/Lunisolar_Shaka_Vikram_Reference.md` §6.3/§6.4 records 2026-09-04 for both
Smarta and Vaishnava observance (Ashtami must prevail at Nishita Kaal).

`panchang-v1` samples one instant: `resolveTithiCheckpoints` sets
`nishitaTime = sunset + (nextSunrise - sunset) / 2`, and
`PanchangData.fromRawTithi` maps `timingOverride: nishita` to the tithi at that
instant. Nishita Kaal is not a point. It is the eighth muhurta of the night, a
one-muhurta window (night duration / 15, about 46 minutes) centred on the night
midpoint. The midpoint can therefore fall after the tithi boundary while the
required tithi still prevails when the window opens.

Captured on 2026-09-04 with the `panchang-v1` engine:

| City | Night midpoint | Derived Nishita window | Ashtami ends | Tithi at midpoint | Result |
| --- | --- | --- | --- | --- | --- |
| Delhi | 00:20 | 23:57--00:43 | 00:15 | Navami (`24.005`) | no match (defect) |
| Mumbai | 00:37 | 00:14--01:01 | 00:15 | Navami (`24.018`) | no match (defect) |
| Kolkata | 23:36 | 23:13--23:59 | 00:15 | Ashtami (`23.971`) | match |
| Varanasi | 23:57 | 23:34--00:20 | 00:15 | Ashtami (`23.987`) | match |
| Chennai | 00:08 | 23:45--00:31 | 00:15 | Ashtami (`23.995`) | match |
| Guwahati | 23:22 | 22:59--23:45 | 00:15 | Ashtami (`23.960`) | match |

The raw value is the engine's tithi index at the sampled instant; 24.0 is the
Ashtami/Navami boundary. Delhi and Mumbai cross it before the midpoint, but
Ashtami is still current when their Nishita windows open.

Phase 2 must make the checkpoint a window:

- add the Nishita window definition (one muhurta, night duration / 15, centred
  on the night midpoint) to `PanchangProfile`;
- resolve the required tithi across the window rather than at one instant: at
  minimum evaluate the window opening and closing, and record in the profile
  which instant decides. For Janmashtami and Maha Shivaratri, the festival
  matches when the required tithi is current at the window opening; if the
  tithi begins inside the window, apply an explicit, documented precedence
  rule instead of falling back to the midpoint;
- route `timingOverride: nishita`, the scheduler, exports, and detail sheets
  through the same checkpoint; and
- version the policy so a future definition change is visible in provenance.

Acceptance criteria:

- `delhi-2026-09-04` and `mumbai-2026-09-04` resolve `janmashtami`;
- the other four cities keep resolving it;
- Maha Shivaratri and every other `nishita` festival keep their documented
  dates, with at least one regression case on each side of the window; and
- the fixture change is deliberate: `expectedFestivalIds` changes from `[]` to
  `["janmashtami"]` for Delhi and Mumbai, the `known-gap` tag and note are
  removed, and the source/old-result/new-result/reason are recorded per the
  fixture update rules.

### Boishakh-1 boundary defect

The locked baseline exposes a second real engine defect, found by checking the
Bengali transition fixtures against external sources. For West Bengal, Poila
Boishakh 1433 is **2026-04-15**: Mesha sankranti falls at 09:39 IST on
2026-04-14, and the Bisuddha Siddhanta rule assigns the sankranti civil day to
the outgoing month. Drik Panchang, Indian Express, and Times of India agree;
Wikipedia records 14 or 15 April for India and 14 April for Bangladesh, so the
West Bengal reading is the one this app must model.

The engine yields Boishakh 1 on **both** 2026-04-14 and 2026-04-15, and
2026-04-14 should be Choitro 30, 1432 (Prokerala's Bengali panjika for that
date; Hindupad records Choitro 1432 as Mar 16 - Apr 14). The cause is in
`BengaliCalendarService._resolveMonthStart`:

- `monthIndex` is derived from the Sun's longitude at local noon, so on
  2026-04-14 noon it is already Boishakh (post-ingress);
- the resolved `monthStart` is `sankrantiDay + 1` = 2026-04-15;
- `if (monthStart.isAfter(noon)) return fallback;` then returns the noon date
  itself, so 2026-04-14 claims day 1 of the month that starts on 2026-04-15;
- 2026-04-15 resolves normally to the same start, producing the duplicate.

The noon-anchored fallback was added to keep the grid bounded, so it must not
simply be removed. The correct resolution is: when the start of month `N` is
after noon, the civil day belongs to month `N-1`, and the answer is that
month's start (Choitro 1, 1432), not the noon date.

Acceptance criteria:

- `kolkata-2026-04-14` and `guwahati-2026-04-14` resolve
  `{1432, Choitro, 30}`;
- a new 2026-04-15 case for both cities resolves `{1433, Boishakh, 1}`, proving
  the duplicate day is gone and there is exactly one Boishakh 1 per year;
- the existing `kolkata-2026-10-17` / `guwahati-2026-10-17` Bengali transition
  cases keep their current values;
- the fixture diff, source, and reason are recorded per the update rules, and
  both records move from `engine-characterization` to `external-verified` with
  the citations above.

## Phase 3 - precise transitions, masa, and Adhika masa

Keep the existing astronomical definitions but replace coarse approximation
where it determines a boundary:

- Tithi: Sun--Moon separation in 12-degree segments.
- Nakshatra: sidereal Moon longitude in 13°20′ segments.
- Yoga: sidereal Sun + Moon longitude in 27 segments.
- Karana: half-tithi progression, including fixed karanas.
- Masa: lunation/new-moon and sidereal solar-ingress basis.
- Adhika masa: no solar Sankranti between consecutive new moons.

Add a shared adaptive root solver with seconds-level tolerance for tithi,
nakshatra, yoga, karana, new-moon, and Sankranti crossings.

This is mandatory for Adhika masa: the current new-moon solver stops at about
±3 hours, then compares the Sun's rashi at the two estimated new moons. A
new moon near Sankranti can therefore produce the wrong Adhika verdict. Reuse
the Bengali calendar's stronger Sankranti bisection design (about 20 seconds)
as the starting point for the shared ingress primitive.

Continue to separate three decisions in code and data:

1. astronomical fact: an element's start/end instant;
2. civil/religious day assignment; and
3. a named festival's observance rule.

## Phase 4 — `jyotish` correctness and API hardening

### Panchang-relevant package work

| Work | Required change |
|---|---|
| Ephemeris provenance | Preserve `swe_calc_ut()` return flags and warning text. Report requested/actual backend and reject fallback when the caller requires Swiss data. |
| Data-range enforcement | Report the actual loaded range per file via `swe_get_current_file_data()` (ifno 0 = planets, 1 = Moon, 2 = asteroids); the app asserts its expected 1800--2399 CE assets. Do not hardcode an asset range in the public package, and do not silently label Moshier fallback as Swiss Ephemeris output. The struct is populated only after the first `swe_calc_ut()` probe. |
| Native state and initialization | Serialize access to global Swiss Ephemeris state and make initialization idempotent with a shared in-flight future. Background and foreground isolates must initialize independently and safely. |
| Cache correctness | Use typed keys; include altitude for topocentric calls; omit location for geocentric calls; include calculation/profile version. Clear affected caches on disposal/configuration change. |
| Batch shape | Replace `Future.wait` pseudo-parallelism with a synchronous, state-aware batch designed around a Panchang day/checkpoint workload, not only arbitrary N-body calls. |

### Latent public-package API work

These are confirmed package defects, but currently do not affect Tithi's daily
Panchang path:

| Work | Required change |
|---|---|
| Dead sidereal constant | Correct or remove `SwissEphConstants.sidereal = 64`; no current execution path reads it. If native sidereal flags are adopted, use `64 * 1024`. |
| Manual sidereal frame bug | Do not subtract ayanamsa from `results[0]` when the result is equatorial right ascension. Prefer explicit coordinate-frame result types or reject incompatible combinations. |
| Sidereal houses | Bind `swe_houses_ex()` for sidereal house calculation. |
| Requested house system | Honor `houseSystem`; do not always calculate/label Placidus when Whole Sign was requested. |
| Dignity | Correct Venus debilitation to 177° and evaluate moola-trikona before generic own-sign dignity, with degree-range rules. |
| Input/model validation | Reject non-finite coordinates and invalid DMS components. Fix the hardcoded north/east location string in `VedicChartService`; `GeographicLocation.toString()` already handles N/S/E/W correctly. |
| Stable enum identifiers | Do not use `SiderealMode.name` as a persistence/cache key because it is a display-label field shadowing the usual enum name. Use the integer constant or an explicit stable key. |

Also remove the developer-specific macOS path from `SwissEphBindings`, correct
the README statement that `defaultFlags()` is tropical, and decide whether
`jyotish-js` is a maintained public artifact or should be separated/removed.

### Optional native sidereal path

`swe_set_sid_mode()` is already bound and called. Add an opt-in
`SEFLG_SIDEREAL` path by including the correct flag in `toSwissEphFlag()`,
removing the stale claim that it does not work in the compiled library, and
validating returned flags. Keep comparison tests against the established
ecliptic-longitude path before making it the default.

## Phase 5 — moonrise, moonset, and timing accuracy

Replace the pure-Dart approximate moonrise/moonset implementation for all
observance decisions with native Swiss Ephemeris rise/set results.

- The existing approximation may remain as a clearly labelled UI fallback
  only if it cannot influence festival or vrata assignment.
- Do not use `SE_BIT_HINDU_RISING` for Moon events: it ignores ecliptic
  latitude and uses geocentric coordinates. Configure topocentric Moon
  position with its actual ecliptic latitude plus an explicit lunar
  limb/refraction policy from `PanchangProfile`.
- Preserve the existing no-rise/no-set fallback behavior, but source its
  event times from the native calculation.
- Measure the tithi-sheet latency before release. The current approximation
  exists to avoid roughly 150 asynchronous samples per sheet; a direct native
  rise/set binding should avoid that regression.

## Phase 6 — platform, data, and licensing delivery

- Verify every Android ABI shipped by the app with reproducible CMake builds.
- Implement/package/test Swiss Ephemeris for Windows, Linux, macOS, and iOS,
  or remove unsupported platform claims from package metadata and docs.
- Add native-library smoke tests for every supported platform.
- Validate ephemeris assets after installation and show a safe, actionable
  error when they are missing/corrupt.
- Review Swiss Ephemeris licensing and distribution obligations before
  publishing. `packages/jyotish/pubspec.yaml` has no `publish_to: none`, so
  the package is publishable.

## Phase 7 — performance and cache rollout

After correctness is demonstrated:

- Make speed vectors optional where retrograde state is not needed.
- Reuse native buffers/state inside calculation batches.
- Use bounded typed LRU caches with hit/miss/eviction telemetry.
- Benchmark release-mode Android, not debug VM:
  - a single Sun/Moon request;
  - a full Panchang day with every checkpoint;
  - a month grid;
  - a forward festival search;
  - transition solving; and
  - moonrise/sunset detail-sheet loading.
- Introduce a calculation-engine version, for example `panchang-v2`, in every
  cached record/key. Invalidate old Hive and in-memory records; never mix old
  apparent-sunrise output with Hindu-sunrise output.

## Phase 8 — tests, CI, documentation, and release

Add:

- package tests for return flags, backend fallback, cache frame/altitude/time
  behavior, initialization races, coordinate-frame safety, houses, dignity,
  DMS validation, and stable enum keys;
- golden Swiss Ephemeris tests with the actual shipped files;
- Panchang golden tests from Phase 0;
- boundary/property tests for 0°/360°, tithi/nakshatra/yoga crossings,
  sunrise, Kshaya, Vriddhi, new-moon/Sankranti coincidence, and polar events;
- Android integration tests using real copied ephemeris assets;
- deterministic timezone tests using explicit IANA zones; and
- platform smoke tests for every platform claimed by the package.

Current Windows package integration tests fail because `swisseph.dll` is not
built/shipped; treat platform smoke coverage as a release gate.

Document the exact calculation methodology in-app and in the repository:
ephemeris backend/data range, Lahiri setting, coordinate frame, Hindu-sunrise
definition, timezone/location policy, month system, festival profile, and
known limits. Add a `changelogs.md` entry with every user-facing feature or
behavior change.

## Delivery order

1. Define `PanchangProfile`, migrate location data, and lock golden fixtures.
2. Route every solar-event consumer through the current-calculator provider or
   precomputed day data, with no behavior change.
3. Bind native Hindu Sun rise/set and change the provider once, with
   cache/version handling.
4. Centralize Panchang-day and observance resolution.
5. Implement precise transition/new-moon/Sankranti solvers and correct Adhika
   boundaries.
6. Add provenance/data-range enforcement, isolate-safe initialization, and
   Panchang-shaped batching in `jyotish`.
7. Replace observance-critical moonrise/moonset approximation using the
   separate Moon event policy.
8. Address latent chart/package APIs, platform delivery, documentation, and
   licensing.
9. Optimize against release-device benchmarks only after golden tests pass.

This order prioritizes the calculations that can change a user's displayed
Panchang date, then makes those calculations reproducible, testable, and fast.
