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
  `timezoneId` argument still wins.
- Place zone resolution is coordinate-based, not device-based: see "Place
  timezone lookup" below.
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

### Place timezone lookup

**Fixed.** `resolvePlaceTimezone` (`lib/core/location/timezone_resolver.dart`)
turns coordinates into the zone the *place* observes, so an Indian user abroad
viewing an Indian city gets `Asia/Kolkata`, not the device zone.

- Bundled boundaries: `timezone_finder` (MIT code, ODbL boundary data) is
  compiled into the app on every target; no network and no asset loading. The
  lookup is `findLocation(longitude, latitude)` - GeoJSON argument order.
- tzdata must be loaded from `package:timezone/data/latest_all.dart`, not
  `latest.dart`: `latest` omits 106 of the 419 boundary identifiers and a hit
  throws `StateError`. Both `AppBootstrap.initTimezones` and the WorkManager
  entrypoint use `latest_all`; `timezone` is therefore `^0.11.2` and
  `flutter_local_notifications` moves to `^22.3.2` (its 20.x API converted
  positional parameters to named ones).
- Fallback order: boundary hit -> device zone -> `Asia/Kolkata`. The fallback
  covers open ocean (the data stops ~22 km offshore), an identifier missing
  from the loaded tzdb, and tzdata that was never initialized.
- Provenance is persisted beside the zone: `home_timezone_source` /
  `cached_timezone_source` hold `place`, `user`, or `device` (`TimezoneSource`,
  values stable once shipped). `_backfillPlaceMetadata` re-resolves only
  `device`-marked or legacy marker-less values, so a later upgrade heals old
  device-seeded rows without overwriting an explicit override.
- ODbL attribution is required wherever the data ships:
  `kTimezoneBoundaryAttribution` is shown on the About screen
  (`timezoneDataCredit`).
- Two product questions, now decided: the app runs on one **place clock**.
  Live location (the "use current location" switch) means the device clock;
  a place picked on the map means that place's clock, including its civil
  midnight and its reminder wall times; with neither, the Delhi fallback's
  clock. `PlaceClock` / `resolvePlaceClock` own that rule, and
  `LocationService.placeClock` is the single synchronous source. Picking a
  place turns live location off so the choice actually takes effect. No
  reminder is anchored to a panchang instant yet (puja kala, nishita); when
  one is added it should fire at the place instant.

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

**Status:** the canonical day and resolver exist as `PanchangDay` /
`PanchangDayResolver` in `lib/features/panchang/domain/`, with nullable solar
anchors, recorded tithi sample point, and provenance. All four day-assembly
call sites are migrated: `resolveTithiCheckpoints` is an adapter over the
resolver that keeps the Hive tithi cache (its checkpoint instants are nullable,
so `computePanchangData` renders a polar day instead of throwing); the
notification scheduler reads the resolver and no longer pre-reads sunrise at
its call sites; the festival year export projects the resolver's day; and
`HinduCalendarService.calculateDate` resolves with limbs/checkpoints/transition
turned off while keeping its shared Hive tithi and masa entries.

The forward scan in `PanchangService.findNextFestivalOccurrence` is migrated
too. It resolves one canonical day per candidate date and projects it through
`projectPanchangDay` (`lib/features/panchang/domain/panchang_day_projection.dart`)
into the same `PanchangData` the grid matches against, so the scan and the grid
share one definition of "matches today"; the ~240-line inline copy of the
sunrise/override/dominant/Kshaya rules is gone. Two consequences are deliberate:

- the scan is now *stricter* for `timingOverride` festivals. The inline copy
  returned a sunrise match that `PanchangData.fromRawTithi` rejects, so a
  boundary date could differ between the countdown and the calendar;
- a polar candidate day no longer throws. `solarEventsService.sunrise` used to
  raise `SolarEventUnavailable` out of the search; the canonical day carries a
  null sunrise, the tithi is sampled at civil noon, and the scan resolves.

The moonrise checkpoint the migration blocked on exists (see "Moonrise
checkpoint" below); migrating before it would have encoded the old sunrise
fallback for `moonrise` rules. The engine version stays `panchang-v3` and no
golden fixture moved.

**Missing solar events are data, not exceptions (Phase 2 acceptance
criterion).** At polar latitudes the Sun may not rise or set on a civil day.
`SolarEventsService` already reports that as `SolarEventUnavailable` instead
of a fabricated 06:00/18:00, but no production caller caught it, so such a
day used to fail as a computation error. The canonical day carries nullable
sunrise, sunset, next sunrise, moonrise, and moonset, and the
calendar grid, detail sheets, notification scheduling, and export must skip
or label the missing event while still rendering the rest of the day. Do not
add a defensive `try/catch` before the day model exists: it would invent a UI
policy that this resolver then has to undo.

Route the calendar grid, detail sheets, widgets, notifications, exports,
search/countdowns, and event sheets through it. The inline copy of
sunrise/override/dominant/Kshaya matching in
`PanchangService.findNextFestivalOccurrence` was the last duplicate and is now
removed; `test/festival_occurrence_scan_test.dart` locks the scan/grid parity.

Current day assembly is duplicated in `tithi_transitions.dart`, notification
scheduling, festival export, and `HinduCalendarService`; each duplicate is a
future behavior-drift risk.

Make the moonrise checkpoint real. `timingOverrideCheckpoints` and
`PanchangData.fromRawTithi` omitted `'moonrise'` (it fell through to the sunrise
tithi) while `PanchangRules` documented it as valid; shipped Karva Chauth uses
`pujaKala`/`paranRule: moonrise`, so its puja window followed moonrise while its
tithi match followed sunrise. Implemented in the section below.

### Nishita checkpoint: Janmashtami boundary defect

**Fixed in `panchang-v3`** (`kPanchangCalculationVersion = 3`,
`kPanchangEngineVersion = 'panchang-v3'`).

The locked baseline exposed a real engine defect, not a fixture error.
`delhi-2026-09-04` resolved no `janmashtami`, although
`docs/Lunisolar_Shaka_Vikram_Reference.md` §6.3/§6.4 records 2026-09-04 for both
Smarta and Vaishnava observance (Ashtami must prevail at Nishita Kaal).

`panchang-v1`/`v2` sampled one instant: `nishitaTime = sunset + (nextSunrise -
sunset) / 2`, and `PanchangData.fromRawTithi` mapped `timingOverride: nishita`
to the tithi at that instant. Nishita Kaal is not a point. It is the eighth of
the fifteen night muhurtas: the window `sunset + 7/15 night` to
`sunset + 8/15 night`, about 46 minutes, centred on the night midpoint. The
midpoint can therefore fall after the tithi boundary while the required tithi
still prevails when the window opens.

Shipped rule (`FestivalObservancePolicy.nishita = NishitaPolicy.windowEdges`):

- the tithi at the window **opening** decides, so a required tithi that ends
  between the opening and the midpoint still matches (the Delhi defect);
- a tithi that only arrives before the window **closes** also matches, so an
  observance is not lost because its tithi began a few minutes inside the
  window;
- the midpoint is never a fallback; `NishitaPolicy.midpoint` exists only to
  reproduce pre-v3 results.

Implementation map: `PanchangCheckpoints.nishita` / `.nishitaEnd` and
`PanchangCheckpointTithis.nishita` / `.nishitaEnd` in
`panchang_day_resolver.dart` (microsecond edges), `TithiCheckpoints`, the
matcher in `PanchangData.fromRawTithi`, and
`SolarEventsService.checkpointTimeFor` (`nishita` = opening, `nishitaEnd` =
closing). `PanchangService.findNextFestivalOccurrence` projects the same
canonical day, so both edges reach the scan unchanged.

Result, re-measured with the native Hindu sunrise convention:

| City | Nishita window | Tithi at opening | Tithi at close | Result |
| --- | --- | --- | --- | --- |
| Delhi | 23:57:19--00:43:16 | Ashtami (`23.987`) | Navami (`24.022`) | match |
| Mumbai | 00:14:11--01:00:53 | Navami (`24.0001`) | Navami (`24.036`) | no match |
| Kolkata | 23:12:25--23:58:51 | Ashtami (`23.953`) | Ashtami (`23.988`) | match |
| Varanasi / Chennai / Guwahati | | Ashtami | Ashtami | match |

The raw value is the engine's tithi index at the sampled instant; 24.0 is the
Ashtami/Navami boundary.

Mumbai is a documented knife edge, not a remaining defect. Ashtami ends at
00:14:06 IST - a geocentric instant, identical for every city - and Mumbai's
window opens at 00:14:11, roughly six seconds later, so neither edge holds
Ashtami and the observance falls on 2026-09-05 under the window rule. The
pre-v3 note claimed the window "opens with Ashtami" from minute-rounded Phase 0
times (Ashtami end 00:14:36); the native Hindu sunrise/sunset moved the window
edge past the boundary. No tolerance is applied: a guard band would decide a
one-day outcome on sub-minute arithmetic. The fixture records the engine's
answer as `engine-characterization` (still tagged `known-gap`) instead of
asserting an observance date, and the case is the standing example of a
boundary decided by seconds.

Fixture diff: `delhi-2026-09-04` `[]` -> `["janmashtami"]`, with the
`known-gap` tag and note removed; `mumbai-2026-09-04` keeps `[]` with its note
rewritten to the measured boundaries; the profile block moves to `panchang-v3` /
`calculationVersion: 3`. The other four cities are unchanged.

### Moonrise checkpoint

A `moonrise` rule was documented as valid in `PanchangRules` but silently fell
through to the sunrise tithi: neither `timingOverrideCheckpoints` nor
`PanchangData.fromRawTithi` had a `moonrise` case. Karva Chauth made the gap
visible - its puja window and paran follow moonrise (`pujaKala`/`paranRule`),
while its date was decided at sunrise.

Implemented:

- `PanchangCheckpointTithis.moonrise` is the tithi at
  `PanchangSolarDay.moonrise`. It is the only checkpoint sampled at a primary
  lunar anchor rather than a solar offset, so the instant stays on the solar
  day and the sampled tithi travels with the checkpoint set.
- `PanchangDayResolver._checkpointTithis` samples it under the `moonrise` cache
  point. `TithiCheckpoints.rawTithiMoonrise`,
  `PanchangData.fromRawTithi(rawTithiMoonrise:)`, the notification scheduler,
  and `test/verify_dates.dart` carry it.
- `timingOverrideCheckpoints` includes `moonrise`, so a moonrise rule is tested
  only at the rise - no sunrise match and no dominant grace, exactly like the
  other overrides - and keeps the Kshaya fallback.
- `SolarEventsService.checkpointTimeFor('moonrise')` returns the day's rise. The
  forward scan reads the checkpoint off the canonical day it already resolves,
  so the scan and the grid sample the same instant.
- `FestivalObservancePolicy.moonrise` records the no-rise policy:
  `MoonrisePolicy.fallbackToSunrise` (shipped) uses the day's own tithi when the
  Moon does not rise; `requireRise` would move the observance to a day whose
  Moon does rise.

No shipped festival rule sets `timingOverride: moonrise` yet, so no result
moves and the engine version stays `panchang-v3`. The policy adds a
`moonrise:` segment to `PanchangProfile.cacheKey`, so Panchang caches
invalidate once. Promoting Karva Chauth's date rule from sunrise to moonrise is
a data change that needs an external check and a fixture diff, and is not part
of this step.

### Boishakh-1 boundary defect

**Fixed.** `kolkata-2026-04-14` / `guwahati-2026-04-14` now resolve
`{1432, Choitro, 30}`, and the new `*-2026-04-15` cases resolve
`{1433, Boishakh, 1}`. Engine version stays `panchang-v3`; this is a calendar
resolution fix, not a Panchang calculation change.

The locked baseline exposed a second real engine defect, found by checking the
Bengali transition fixtures against external sources. For West Bengal, Poila
Boishakh 1433 is **2026-04-15**: Mesha sankranti falls at 09:39 IST on
2026-04-14, and the Bisuddha Siddhanta rule assigns the sankranti civil day to
the outgoing month. Drik Panchang, Indian Express, and Times of India agree;
Wikipedia records 14 or 15 April for India and 14 April for Bangladesh, so the
West Bengal reading is the one this app must model. 2026-04-14 is Choitro 30,
1432 (Prokerala's Bengali panjika for that date; Hindupad records Choitro 1432
as Mar 16 - Apr 14).

The engine used to yield Boishakh 1 on **both** 2026-04-14 and 2026-04-15. The
cause was in `BengaliCalendarService._resolveMonthStart`:

- `monthIndex` is derived from the Sun's longitude at local noon, so on
  2026-04-14 noon it is already Boishakh (post-ingress);
- the resolved `monthStart` is `sankrantiDay + 1` = 2026-04-15;
- `if (monthStart.isAfter(noon)) return fallback;` then returned the noon date
  itself, so 2026-04-14 claimed day 1 of the month that starts on 2026-04-15;
- 2026-04-15 resolved normally to the same start, producing the duplicate.

The noon-anchored fallback existed to keep the grid bounded, so it was not
simply removed. The fix keeps the bound and corrects the answer:

- `_resolveMonthStart` returns `({int index, DateTime start})`. When month `N`
  starts after noon, it resolves month `N-1` at the noon before that start and
  returns that month's index and start, one step only (the outgoing month's
  start is 29-32 days earlier, so it cannot land on its own sankranti day).
  The noon fallback remains as the unreachable one-step guard.
- `_monthStartFor` caches under the resolved index, and `calculateDate` takes
  the month name and Bangabda year from the resolved index instead of the
  noon's rashi. Both were previously derived from `monthIndex`, so returning
  the previous month's start alone would have produced Choitro day 30 labelled
  Boishakh 1433.
- `test/bengali_calendar_month_start_test.dart` locks the transition (forward
  and reverse order, so the month-start cache cannot decide it), the
  day-by-day continuity across April 2026, and exactly one Boishakh 1 in
  2025-2027.

Fixture diff (reviewed, per the update rules): both 2026-04-14 cases changed
`bengaliDate` `{1433, Boishakh, 1}` -> `{1432, Choitro, 30}` and moved to
`external-verified` with the citations above; `kolkata-2026-04-15` and
`guwahati-2026-04-15` were added (`{1433, Boishakh, 1}`, full Panchang fields
captured from the engine). `kolkata-2026-10-17` / `guwahati-2026-10-17` keep
their values (Ashshin 30 -> Kartik 1).

Acceptance criteria, all met:

- `kolkata-2026-04-14` and `guwahati-2026-04-14` resolve
  `{1432, Choitro, 30}`;
- the new 2026-04-15 cases resolve `{1433, Boishakh, 1}`, proving the duplicate
  day is gone and there is exactly one Boishakh 1 per year;
- the existing `kolkata-2026-10-17` / `guwahati-2026-10-17` Bengali transition
  cases keep their current values;
- the fixture diff, source, and reason are recorded per the update rules, and
  both 2026-04-14 records moved from `engine-characterization` to
  `external-verified` with the citations above.

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

### Crossing solver: what shipped

- `solveRoot` / `solveAngleCrossing` in
  `lib/features/panchang/domain/root_solver.dart` are the shared primitive: one
  bisection, 1 s default tolerance, bracket verified up front (residual `<= 0`
  before, `> 0` after) and null instead of a plausible wrong instant.
  `signedAngleDelta` provides the mod-360 fold that makes cyclic longitudes
  solvable without unwrapping.
- `findNewMoonInstant` / `findSankrantiInstant` in
  `lib/features/panchang/domain/panchang_crossings.dart` bracket by daily
  sampling around an estimate and then solve. `_refineNewMoonInstant` resolves
  the new moon to the second; the ~±3 h error is gone, so a new moon cannot
  land on the wrong side of a nearby Sankranti. The old nearest-noon fallback
  (`newMoonDistance`, ±12 h) was removed: `resolveNewMoonInstant` retries at
  ±7 days and then throws `CrossingResolutionException`, because a wrong Adhika
  month is worse than a visible failure.
- `findSankrantiInstant` now has a production caller: the Bengali month start
  resolves its ingress through it, so the tested helper and the shipping path
  are the same code. The 35-day guard scan remains for a mismatched boundary.
- `findSunriseTithiTransition` (`lib/features/panchang/domain/tithi_transitions.dart`)
  and `bisectNakshatraEdge`
  (`lib/features/panchang/domain/nakshatra_span.dart`) replaced their own
  1-minute bisections. The nakshatra edge targets half a segment past (or
  before) the sunrise index, so both directions are upward crossings;
  `test/nakshatra_edge_test.dart` pins that target math directly.
- Bengali month starts moved to
  `lib/services/bengali_calendar/bengali_month_start.dart`
  (`resolveBengaliMonthStart`), a pure function over a Sun-longitude sampler.
  It dropped the 12-round (~20 s) bisection for the shared solver and removed
  the historic Apr-14 approximation: a sampler that cannot produce an ingress
  now throws `BengaliMonthStartException` instead of returning a day-off
  month start. `test/bengali_month_start_test.dart` covers the normal,
  Sankranti-civil-day, guard-scan and failure paths without FFI.
- `solveRoot` is documented as upward-only; a descending crossing returns
  null. `test/root_solver_test.dart` pins that contract.
- `wrapPairIndex` and `interpolateNewMoonInstant` were deleted as dead
  approximation code.
- Yoga and karana already had a consumer: the tithi detail sheet's
  `yogaKaranaTimingsProvider` shows "until 3:42 PM". It used a provider-local
  1-minute index bisection, so it was migrated to `resolveYogaKaranaSpan`
  (`lib/features/panchang/domain/yoga_karana_span.dart`), which solves the
  continuous Sun+Moon sum and elongation through `solveAngleCrossing`.
  `test/yoga_karana_span_test.dart` covers both ends, the 360 wrap and the
  failure paths.
- The golden fixture locks both the nakshatra span and the next Sankranti
  (schema 2). `resolveNakshatraSpan`
  (`lib/features/panchang/domain/nakshatra_span.dart`) is now the production
  path - `nakshatraTimingsProvider` is a thin wrapper - so
  `test/panchang_golden_engine_test.dart` compares the fixture against the same
  code the detail sheet runs, not a test-local bisection. The ingress comes from
  `findSankrantiInstant` with a mean-motion estimate
  (`sunrise + (30 - degInSign) / 0.9856` days).

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

### Lunar rise/set: what shipped

- `MoonEventsService` (`lib/services/moon_events_service.dart`) is the lunar
  counterpart of `SolarEventsService`: `MoonEventCalculator` strategy,
  `SwissMoonEventCalculator` production implementation,
  `ApproximateMoonEventCalculator` labelled fallback, bounded cache, published
  place zone, and the global `moonEventsService`. It returns null for a
  missing event instead of throwing, because a no-rise day is a normal monthly
  occurrence the observances already handle.
- The convention is topocentric and apparent with the Moon's true ecliptic
  latitude: `SE_BIT_GEOCTR_NO_ECL_LAT` and `SE_BIT_HINDU_RISING` are never
  set. Limb and refraction come from `PanchangProfile.lunarLimb` /
  `lunarRefraction` (`upperLimb` + `standard` by default), and
  `SE_BIT_DISC_BOTTOM = 2048` was added to the bindings for the lower-limb
  policy. `riseSetBits` is the single place that mapping lives.
- `swe_rise_trans` only searches forward, so a result is discarded unless it
  lands on the requested civil day. Without that check a no-rise day returns
  tomorrow's rise, which would move a moonrise observance onto the wrong day.
  `findPreviousRise` / `findNextSet` preserve the prevailing-event fallback by
  walking a 48 h window in the direction the forward-only primitive allows.
- Wired through `PanchangService.init` / `clearCaches`, `PanchangDayResolver`
  (injectable `moonEvents`; `_solarDay` reads `forDate`),
  `event_detail_sheet._pujaMoonrise` (the observance input),
  `tithi_detail_sheet`'s chips and
  `SolarEventsService.checkpointTimeFor('moonrise')` (vestigial but kept
  consistent). `MoonriseCalculator` survives only as the fallback delegate.
- Latency: the ~150-sample worry in the plan does not apply. `swe_rise_trans`
  is one synchronous FFI call per event. Measured on the Windows host over 40
  Delhi days: approximation ~898 µs/day for both events, native uncached
  ~394 µs/day, native cached ~11 µs/day. The native path is both more accurate
  and about twice as fast as the scan it replaces, so no async conversion or
  precomputation was needed.
- The golden fixture's `moonrise` values were recaptured under the new
  convention (83 values; 27 moved more than the 60 s tolerance, spread of
  ±120 s). `source.notes` records old result, new result and reason.
  `test/moon_events_test.dart` pins the convention, the no-rise contract, the
  fallbacks and the resolver wiring.

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

### Platform, data and licensing: what shipped

- Platform claims now match reality: Android is the only platform with a real
  native build, so it is the only one `packages/jyotish/pubspec.yaml` declares
  (`android: ffiPlugin: true`). The `ios/`, `linux/`, `macos/` and `windows/`
  directories remain as plugin scaffolding and build no Swiss Ephemeris. A
  platform may only be added back with a CMake/podspec target that compiles the
  library plus a smoke test that proves it loaded.
- Android CMake path: `packages/jyotish/android/src/main/cpp/CMakeLists.txt`
  resolves `native/swisseph/...` from the package root
  (`CMAKE_CURRENT_SOURCE_DIR/../../../..`) instead of the repository root. The
  old form only worked while the package sat at `packages/jyotish` in this
  monorepo and broke as soon as it was consumed from the pub cache.
- Asset validation: `lib/services/panchang_init/panchang_init.dart` verifies
  each installed `.se1` file (at least 1 KB and a `SWISSEPH` header), re-copies
  anything that fails, and writes through a sibling `.part` file plus rename so
  an interrupted first launch cannot leave a truncated file that passes the
  next launch's check. A missing or corrupt bundled asset throws
  `EphemerisAssetException` with a user-facing recovery step.
- Error surface: `PanchangInitErrorBanner`
  (`lib/widgets/panchang_init_error_banner.dart`) is mounted at the top of the
  home body and appears when `panchangInitProvider` fails. Without it the
  calendar's deliberate error-to-empty-map behaviour made a broken install look
  like a month with no festivals. Retry invalidates the provider.
- Tests: `test/panchang_init_test.dart` covers valid, truncated, zero-byte and
  wrong-header installs, atomicity, and both exception paths;
  `test/panchang_init_error_banner_test.dart` covers the banner and retry;
  `integration_test/native_ephemeris_smoke_test.dart` is the on-device check
  that the assets install, `libswisseph.so` loads and both native calculators
  are active (needs a connected Android device).
- Licensing: `packages/jyotish/NOTICE` records that the bundled Swiss
  Ephemeris is AGPLv3-or-commercial from Astrodienst while the Dart/Kotlin
  wrapper is MIT, and that no license choice has been recorded. `publish_to:
  none` keeps the package off pub.dev until that decision is made, and the
  README platform and license claims were corrected to match. This remains a
  release blocker, not a code task.
- Deferred: running the on-device smoke test on each ABI, and real native
  builds for Windows, Linux, macOS and iOS. What is verified today is the
  build side: `flutter build apk --debug` completes with the package-root
  CMake path and the APK contains `libswisseph.so` for `arm64-v8a` (~540 KB),
  `armeabi-v7a` (~509 KB) and `x86_64` (~628 KB). The desktop and iOS targets
  cannot be built or tested on the Windows development host, so they need
  macOS/CI hardware and are treated as follow-ups rather than claimed support.


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
