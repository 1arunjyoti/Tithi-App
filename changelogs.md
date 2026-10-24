# Changelogs

Brief notes on feature implementations, newest first. One entry per feature
(or per commit that ships one), written so a maintainer can find the code
again months later without reading the diff. Keep it short: a summary line,
then a few bullets. The full rationale stays in the commit message and the
code comments.

Format:

```markdown
## YYYY-MM-DD - <version from pubspec.yaml>

### <Feature name>
<one-line description of what the user gets>
- <key behaviour or constraint>
- <where it lives: files / services / providers>
```

---

## 2026-10-23 - 0.7.20+20

### Nishita observance window

Janmashtami and Maha Shivaratri are decided by the Nishita Kaal window instead
of a single night-midpoint sample, which restores Janmashtami on 2026-09-04 in
Delhi.

- Nishita Kaal is the eighth of the fifteen night muhurtas: `sunset + 7/15
  night` to `sunset + 8/15 night`. A `nishita` rule matches the tithi at the
  opening, or one still current at the close; the midpoint is never a fallback.
  The policy is `FestivalObservancePolicy.nishita` (`NishitaPolicy.windowEdges`;
  `midpoint` exists only to reproduce pre-v3 results).
- Window edges are computed in microseconds
  (`PanchangDayResolver._checkpoints`): the window is ~46 minutes wide, so
  whole-minute rounding can move a boundary tithi across it.
- `panchang-v3` / `kPanchangCalculationVersion = 3`: Panchang cache keys and
  the golden fixtures move with the version, so pre-v3 days are not reused.
- Both edges travel with the day: `PanchangCheckpointTithis.nishitaEnd`,
  `TithiCheckpoints.rawTithiNishitaEnd`, the `rawTithiNishitaEnd` argument of
  `PanchangData.fromRawTithi`, the scheduler, and the forward scan in
  `PanchangService.findNextFestivalOccurrence`. `checkpointTimeFor` on
  `SolarEventsService` gained a `nishitaEnd` case.
- Mumbai 2026-09-04 stays unmatched on purpose: Ashtami ends 00:14:06 and the
  window opens 00:14:11. Do not add a tolerance to force it; the golden fixture
  documents the margin.

### Canonical Panchang day

One immutable day value object replaces the four separate day-assembly paths
as they migrate onto it.

- `PanchangDay` carries the place context, solar/lunar anchors, tithi,
  nakshatra/yoga/karana, Amanta masa with the Adhika verdict, solar-anchored
  checkpoints, and provenance (engine version, ayanamsa, sunrise convention,
  ephemeris backend).
- Missing solar events are nulls, not exceptions: a polar day still resolves
  its tithi and masa. The tithi sample point is recorded
  (`PanchangTithiSample.sunrise` / `civilNoon`) so the UI can label a day
  that has no sunrise instead of pretending it does.
- `PanchangDayResolver` is the single computation pipeline; it does not
  decide festivals or touch Hive. Callers that own a cache pass
  `tithiSampler` / `masaSampler` instead of the resolver growing one, and
  `computeLimbs` / `computeCheckpoints` / `computeTransition` let a caller
  skip parts it never reads (each costs ephemeris calls). Lives in
  `lib/features/panchang/domain/panchang_day.dart` and
  `panchang_day_resolver.dart`; do not add another inline day assembly, route
  new callers through the resolver.
- The provider path already uses it: `resolveTithiCheckpoints` is a thin
  adapter over the resolver (keeping the Hive tithi cache) and its checkpoint
  times are nullable, so `computePanchangData` returns a day with null
  sunrise/sunset at polar latitudes instead of throwing.
- `TithiCheckpoints` instant fields are nullable and carry
  `tithiSample`/`tithiSampledAt`; a missing anchor means the anchored timing
  rule never matched, not that it matched at 06:00.
- The notification scheduler now computes each day through the resolver too,
  and no longer pre-reads sunrise at its call sites, so a polar location
  schedules the rest of the window instead of failing the run.
- The festival year export projects the resolver's day as well, so its
  sunrise/sunset/masa/nakshatra columns come from the same pipeline as the
  calendar and the scheduler.
- `HinduCalendarService.calculateDate` resolves the day with limbs,
  checkpoints, and transition turned off (it only reads the udaya tithi and
  masa) and keeps its shared Hive tithi/masa entries through the samplers, so
  the Hindu month grid and the Gregorian batch still warm each other.

### Place timezone for solar events

Sunrise/sunset reads that only know coordinates now use the selected place's
IANA zone instead of the device zone.

- `SolarEventsService.setPlaceTimezone()` publishes the place zone; an explicit
  `timezoneId` argument still wins, and changing the zone clears the event
  cache because entries are keyed by zone.
- Published by `currentLocationProvider` in the UI isolate and from the
  persisted `cached_timezone` Hive key in the notification background isolate
  (`readLastKnownTimezoneId`), so scheduling matches the app.
- Still device-seeded: `resolvePlaceTimezoneId` has no coordinate-to-zone
  table, so the zone is correct for India-first use but not for an Indian
  place viewed from abroad. The table is deferred to the Phase 2 place
  context.
- Lives in `lib/services/solar_events_service.dart`,
  `lib/providers/location_provider.dart`,
  `lib/core/location/cached_location.dart`, and
  `lib/core/notifications/scheduling_parts.dart`.

### Native Hindu sunrise/sunset

Panchang days now use the traditional Hindu solar-rise/set definition from
Swiss Ephemeris instead of the NOAA apparent-upper-limb approximation.

- `SwissSolarEventCalculator` calls `swe_rise_trans()` with
  `SE_BIT_HINDU_RISING` (disc centre, no refraction, geocentric) and keeps
  seconds internally; polar no-rise/no-set is an explicit
  `SolarEventUnavailable`, never a synthetic 06:00/18:00.
- `PanchangService.init()` installs the native calculator after the ephemeris
  files are available. Non-Android targets keep the labelled NOAA fallback
  until Phase 6.
- `kPanchangCalculationVersion` is now `2`; the version is part of
  `locationSignature`, and in-memory caches are cleared at startup, so old
  Hive results are not reused.
- `resolvedSolarContextProvider` passes altitude and IANA timezone through the
  main Panchang/calendar-flag compute paths. The Hindu convention is
  geocentric, so altitude does not change the event instant.
- Golden fixtures were deliberately recaptured: event times shift by roughly
  3-5 minutes, and Delhi `2026-06-30` changes from Purnima to Krishna
  Pratipada because native sunrise moves past the transition.
- Lives in `lib/services/solar_events_service.dart`, the `jyotish` bindings,
  and `test/fixtures/panchang_golden/`. The Janmashtami nishita defect remains
  the documented Phase 2 change.

### Solar-events seam

Every production sunrise/sunset read now goes through one cached service, with
no change to the NOAA-based output.

- `SolarEventsService` wraps the shipped `SunriseCalculator` behind a
  `SolarEventCalculator` strategy; `solarEventsService` is the process-wide
  instance. Cache keys include the civil day, place, device offset, and
  convention, so a timezone change cannot serve a stale instant.
- Calendar assembly, detail sheets, home-widget payloads, notifications,
  export, Hindu/Bengali calendar paths, and the occurrence finder all read the
  service; `SunriseCalculator` remains the Phase 1b fallback and parity
  reference.
- `forDate` bundles sunrise/sunset/next sunrise, and `checkpointTimeFor` keeps
  the shipped Madhyahna/Aparahna/Nishita/Pradosha arithmetic until Phase 2.
- Phase 1a only implements `apparentUpperLimb`; constructing the service with
  `hindu` throws until the native binding lands in Phase 1b.
- Lives in `lib/services/solar_events_service.dart`; tests in
  `test/solar_events_service_test.dart`.

### Panchang calculation profile

The first piece of the Drik Panchang migration: a versioned, serializable
description of the calculation contract, with no behavior change yet.

- `PanchangProfile` fixes the target defaults: Lahiri, Amanta, Hindu
  sunrise/sunset, traditional upper-limb moonrise, mean node.
- Persisted as a JSON map under `panchang_profile`; the ayanamsa is stored by
  Swiss Ephemeris sidereal-mode constant, never by enum index.
- `engineTag` / `cacheKey` cover every output-affecting field so a future cache
  cannot serve a record from a different contract.
- Moonrise is in the target checkpoint set, but the live matcher still omits it
  until Phase 2; nothing reads the profile before Phase 1b.
- Lives in `lib/models/panchang_profile.dart`; tests in
  `test/panchang_profile_test.dart`.

### Location altitude and IANA timezone

`LocationData` now carries an optional altitude and IANA zone, persisted with
the cached and home coordinates so a Panchang record can describe its own place.

- GPS fixes store the platform altitude (ellipsoidal, metres); manually picked
  places leave it null until an elevation lookup exists. Null means unknown,
  and Phase 1 must normalize before passing it to `swe_set_topo`.
- `timezoneId` is seeded from the device zone by `resolvePlaceTimezoneId`,
  with `Asia/Calcutta` canonicalized to `Asia/Kolkata`. Phase 0 ships no
  coordinate-to-zone table, so a place outside the device's zone is a known
  limitation; `setHomeLocation` accepts an explicit `timezoneId`.
- `LocationService.init()` backfills the zone for coordinates written before
  this change. A new fix without metadata deletes the old keys, so Mumbai
  cannot inherit Delhi's altitude.
- Stored under `cached_altitude` / `cached_timezone` and `home_altitude` /
  `home_timezone` in the `location_settings` box.

### Panchang golden reference fixtures

A locked 82-case regression baseline for the Drik migration, covering 19 dates
and six Indian cities without changing production calculations.

- Fixtures live in `test/fixtures/panchang_golden/` and are read-only in tests;
  no test or tool regenerates them. Update one only with source, old result, new
  result, and a documented reason.
- `india_drik_lahiri_amanta.json` locks sunrise/sunset, sunrise tithi and next
  tithi, nakshatra, yoga, karana, Sun/Moon longitudes, Amanta/Purnimanta masa,
  adhika flag, moonrise, and (for Bengali cases) the Bengali date.
- `festival_resolution.json` stores expected festival IDs only; rules and names
  stay in `assets/festivals.json`.
- Coverage includes Kshaya/Vriddhi, a one-minute sunrise boundary, Adhika
  Jyeshtha, Mahashivratri, Janmashtami, Diwali, Holi, Ram Navami, Karva Chauth,
  Bengali month transitions, and the 1800/2399 ephemeris boundaries.
- Pure validation runs everywhere; the engine comparison runs only when
  `SWISSEPH_LIB_PATH` is set on an IST host, because the Phase 0 NOAA sunrise
  calculator is device-timezone dependent. Known gaps (Delhi/Mumbai
  Janmashtami nishita, Bengali New Year date) are recorded in case notes rather
  than hidden. The Janmashtami defect is an explicit Phase 2 fix: replace the
  single night-midpoint sample with the one-muhurta Nishita Kaal window, then
  change the two expected results from `[]` to `["janmashtami"]`
  (`docs/jyotish_package_improvements_plan.md`, Phase 2).

### Panchang home-screen widgets

Four new Android home-screen widgets join the festival countdown: a hero card
for today's panchang, plus auspicious, inauspicious and combined timing widgets.

- Native widgets are dumb renderers. Dart pre-computes and localizes every
  string in all four app languages in
  `lib/features/home_widget/domain/panchang_widget_payload.dart`; payloads live
  under `hero_widget_data` / `timings_widget_data` in `HomeWidgetPreferences`.
- The timing payload carries today **and** tomorrow with ISO start/end instants
  (`kTimingsWidgetDayCount = 2`), so the native midnight alarm rolls over
  without the app. Do not trim it to one day.
- One `TimingWidgetService` backs all three timing widgets; the provider's mode
  extra (`auspicious` / `inauspicious` / `combined`) selects rows and section
  headers. The "now" marker is derived natively from the ISO instants.
- `WidgetRefreshReceiver` owns the shared heartbeat: a one-shot 00:01 alarm and
  a one-shot next-window-edge alarm, re-armed on boot / app update / clock
  changes and cancelled when no Tithi panchang widget remains. The window-edge
  alarm is armed only while a timing widget exists; a hero-only launcher gets
  just the daily refresh.
- All widgets share `widget_theme_override` (existing configure activity);
  app syncs never write it. The gallery in `lib/widgets/home_widget_card.dart`
  pins each provider by qualified Android name.
- The gallery starts collapsed to its header on both the home and countdown
  screens; tap the header (or its chevron) to reveal the five rows. Expansion
  is local to the card instance and is not persisted, so a re-mounted card
  starts compact again.
- The hero widget mirrors the app hero card: gradient + glow shell, uppercase
  tag + location pill, inline weekday + accent tithi title, a 44dp moon-phase
  tile and the next-tithi pill, with masa/nakshatra + sunrise/sunset in a
  compact footer. The moon phase is drawn natively from the payload's
  `illumination` / `isShukla`; the headline festival takes the artwork slot as
  an accent pill.
- The hero payload now carries `secondaryKind`, `illumination`, `isShukla`,
  `location`, and the structured `chipText` / `chipHighlight` / `chipSuffix` /
  `chipInlineIcon` parts. Keep those fields when changing the Dart payload
  builder; the native side uses them to style the title and chip without
  re-parsing localized sentences.
- The hero widget shows a refresh prompt when the stored day is not today
  instead of yesterday's panchang.
- Hero festival names follow the app language (regional name when available).
  Timing payload construction is isolated per day, and a failed widget
  repaint is retried on the next sync instead of being masked by the payload
  dedup cache.

### Live tithi clock refresh
The hero label now flips at the tithi boundary and after the app resumes,
instead of sticking to the clock instant captured on the first read.

- `liveNowProvider` is a plain `Provider`, so it caches its first value; the
  tick timer and the resume path invalidate it before `livePanchangProvider`
  rebuilds.
- Files: `lib/providers/panchang_provider.dart`, `lib/main.dart`.

## 2026-10-22 - 0.6.20+18

### Festival regions

Users now pick the region they live in, and festivals rooted there sort above
pan-India festivals, which sort above festivals from other regions.

- `Festival.regions` (Hive field 10) is a list of canonical tags -
  `north`/`south`/`east`/`west`/`central`/`northeast`/`all` - with `all` being
  exclusive. Missing/empty normalizes to `['all']`, so pre-region data and
  older Hive boxes behave exactly as before.
- Ordering only ever applies to same-day collisions: `sortedFestivalsForRegion`
  and `primaryFestivalForRegion` in `lib/models/festival_region.dart` are
  reused by the home hero deck, the festival rows, the all-festivals filter,
  the countdown targets and the notification scheduler.
- The preference is an enum index stored under `festival_region`
  (`kFestivalRegionPrefKey`), deliberately shared with the background
  scheduler so the key cannot drift. Append new regions at the end only.
- Settings reset had to invalidate `calendarPreferencesProvider` before the
  derived providers, otherwise the region survived the reset.
- Bundled entries are tagged in `assets/festivals.json`; the field is
  documented in `docs/FESTIVALS_Modification_GUIDE.md`.

### AI hand-off ("Ask AI")

The tithi and festival sheets can hand a panchang-aware prompt to an installed
assistant instead of the user retyping it.

- `lib/features/ai/domain/ai_prompt.dart` + `ai_context.dart` build the text;
  `lib/services/ai_handoff_service.dart` sends it with an explicit
  `ACTION_SEND` to one package (`android_intent_plus`), so the chooser
  disappears. Unresolvable targets fall back to the share sheet, not an error.
- Targets live in `ai_app_target.dart` as plain package ids and are declared in
  `AndroidManifest.xml` under `<queries>` - Android 11+ package visibility, not
  `QUERY_ALL_PACKAGES`.
- Choosing a target (or `auto`) is an AI ASSIST settings section; the sheet is
  `ask_ai_sheet.dart`.

### Shared festival artwork

Rows, the all-festivals list, search results and the tithi sheet all show the
same picture now, with a category glyph when a festival ships no artwork.

- `FestivalThumbnail` + `festivalRowIcon` in `lib/widgets/festival_thumbnail.dart`;
  asset paths and network URLs are both accepted, broken assets fall back to
  the glyph. One widget means one image-cache entry per festival.

### Sheet and row polish

- Sheet body cards and chips share `AppTheme.sheetCardDecoration` /
  `sheetHairline` instead of per-card styling. The hairline (not a shadow) is
  what separates white cards from the cream scaffold, and it keeps the
  non-lazy sheet scroll cheap.
- `AppTheme.festivalRowDecoration(isSelectedDay: true)` gives the rows of the
  currently viewed day an accent wash, so the active day reads as the primary
  group. It keys off the selected date, which may be today or a browsed date.
