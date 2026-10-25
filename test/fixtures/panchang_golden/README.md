# Panchang golden fixtures

A locked, version-controlled set of Panchang cases used as the regression
baseline for the Drik migration. The tests **read** these files and **never**
regenerate or overwrite them.

This is a regression lock first. It records what the engine actually produced
on the capture date so a later calculation change shows up as an explicit diff.
It is **not** an external accuracy certification: every record is currently
marked `source.kind = "engine-characterization"` (or `"provided-anchor"` for
the illustrative Kolkata case). Promote individual cases to
`"external-verified"` only with a citation in `source.notes`.

## Files

| File | Purpose |
| --- | --- |
| `india_drik_lahiri_amanta.json` | Date, place, profile, and expected Panchang outputs. |
| `festival_resolution.json` | Expected resolved festival IDs, keyed by `caseId`. |

Festival definitions and rules stay in `assets/festivals.json`. The fixture only
stores IDs, so changing a festival description or translation does not touch
the calculation baseline.

## Current baseline

- Engine tag: `panchang-v3` (`kPanchangCalculationVersion = 3`).
- Panchang schema: `2`. Schema 2 added `nakshatraStartsAt`, `nakshatraEndsAt`,
  `nextNakshatra`, and `nextSankranti`; the festival file stays at schema 1.
- Ayanamsa: Lahiri. Month system: Amanta. Timezone: `Asia/Kolkata`.
- Sunrise/sunset: native Swiss Ephemeris `swe_rise_trans()` with
  `SE_BIT_HINDU_RISING` - disc centre, no refraction, geocentric, and no
  ecliptic latitude. Values keep seconds internally; the fixture stores them
  at second precision. This replaces the Phase 0 NOAA apparent-upper-limb
  convention, which was minute-rounded.
- Non-Android targets keep the labelled NOAA fallback. Phase 6 narrowed the
  package to Android rather than building the native library for the other
  platforms, so the fallback is the permanent behaviour there. It is not the
  Hindu convention and must not be presented as one.
- Tithi, nakshatra, masa, and festival matching come from the shipped
  `computePanchangData` pipeline, including the Vriddhi filter on a three-day
  window (`date - 1 .. date + 1`).
- Yoga and karana are derived from the sidereal Sun/Moon longitudes at sunrise.
- Nakshatra edges come from the shared crossing solver through
  `resolveNakshatraSpan` (`lib/features/panchang/domain/nakshatra_span.dart`),
  the same path `nakshatraTimingsProvider` uses for the detail sheet.
- The next Sankranti comes from `findSankrantiInstant`: the first solar sign
  ingress strictly after sunrise, estimated with the mean solar rate
  (0.9856 deg/day) and bracketed within ±3 days.
- `moonrise` uses native `swe_rise_trans` (topocentric, true ecliptic
  latitude, `PanchangProfile.standard`), not the retired pure-Dart
  `MoonriseCalculator` series.

## Coverage

84 cases across 20 dates and 6 cities: Delhi, Kolkata, Mumbai, Varanasi,
Chennai, Guwahati. The `tags` array records intent; the validation test
requires the union to cover:

`kshaya`, `vriddhi`, `ekadashi`, `mahashivratri`, `janmashtami`, `diwali`,
`holi`, `ram_navami`, `sankranti`, `adhika`, `sunrise-boundary`,
`bengali-transition`, `moonrise-festival`, `ephemeris-boundary`,
`amanta-purnimanta`.

Notable cases:

- `delhi-2026-06-30` / `mumbai-2026-06-30`: the Purnima → Pratipada boundary
  falls near sunrise. Under the native Hindu convention Delhi's sunrise moves
  past the boundary, so Delhi joins Mumbai/Chennai in Krishna Pratipada;
  Kolkata, Varanasi, and Guwahati still resolve to Purnima. This is the one
  deliberate semantic fixture change from Phase 1b.
- `kolkata-2026-10-17`: Shashthi prevails at both the Oct 16 and Oct 17
  sunrises (Vriddhi), while Delhi advances to Saptami.
- `delhi-2026-09-04` / `mumbai-2026-09-04`: Janmashtami, the case that forced
  `panchang-v3`. A `nishita` rule now samples the Nishita window - the eighth
  of the fifteen night muhurtas, `sunset + 7/15 night` to `+ 8/15 night` -
  instead of the night midpoint, and matches the tithi at either edge.
  Delhi: Ashtami (raw 23.987) prevails at the opening (23:57:19), so the day
  resolves `janmashtami` (old result `[]`). Mumbai: Ashtami ends 00:14:06 and
  the window opens 00:14:11, so neither edge holds it and the result stays
  `[]`; the case is decided by ~6 seconds, is kept tagged `known-gap`, and is
  not an external accuracy claim. Kolkata/Varanasi/Chennai/Guwahati resolve on
  the same date. See `docs/jyotish_package_improvements_plan.md`, Phase 2,
  "Nishita checkpoint".
- `kolkata-2026-04-14` / `guwahati-2026-04-14`: **Boishakh-1 boundary, fixed in
  Phase 2.** West Bengal Poila Boishakh 1433 is 2026-04-15: Mesha sankranti is
  09:39 IST on 2026-04-14, and the Bengal rule gives the sankranti civil day to
  the outgoing month, so 2026-04-14 is Choitro 30, 1432 (Prokerala; Hindupad
  gives Choitro 1432 as Mar 16 - Apr 14). The engine used to emit Boishakh 1 on
  both dates; the expected diff was `{1433, Boishakh, 1}` -> `{1432, Choitro,
  30}` and these records are promoted to `external-verified`. The matching
  `*-2026-04-15` cases lock `{1433, Boishakh, 1}`, so there is exactly one
  Boishakh 1. See `docs/jyotish_package_improvements_plan.md`, Phase 2,
  "Boishakh-1 boundary defect".
- `delhi-1800-01-01` / `guwahati-2399-12-31`: bundled-ephemeris range
  boundaries.
- `kolkata-2026-04-14`: cross-check for the Sankranti lock. The captured Mesha
  ingress is 09:30:15 IST against a published 09:39 - the ~9 minute ayanamsa
  variant - so the ingress instants are engine characterization, not an
  accuracy claim. Every case carries its nakshatra edges and next ingress
  (schema 2).

## Lock and update rules

1. Tests may read the files, never write them. There is no auto-update mode.
2. A fixture change is a reviewed change. Record:
   - the source and profile (`source` block),
   - the old result (the diff),
   - the new result,
   - why the change is intentional.
3. Do not copy proprietary Panchang output without permission.
4. When a value changes, first decide whether the change is a regression or a
   deliberate accuracy fix. Only the latter may update the fixture.
5. Keep festival definitions in `assets/festivals.json`; do not copy names,
   descriptions, or rules into these files.

## Running the tests

```bash
# Always runs. Validates schema, references, tags, and coverage.
flutter test test/panchang_golden_fixture_test.dart

# Runs the real engine. Requires the native Swiss Ephemeris library and an
# IST host: the harness normalizes each case's civil day in the device zone
# (it does not pass the place timezone into the day pipeline) while the
# fixture stores +05:30 wall-clock times. Moonrise is not the reason for the
# requirement - it resolves the place zone from `location.timezone`.
$env:SWISSEPH_LIB_PATH = "C:\path\to\swisseph.dll"
flutter test test/panchang_golden_engine_test.dart
```

The engine test skips with a clear reason when the library or IST host is
missing. The pure validation test runs everywhere.

### Building the host DLL on Windows

The repository bundles the Swiss Ephemeris C sources. With MinGW:

```powershell
$src = "packages/jyotish/native/swisseph/swisseph-master/src"
$out = "$env:TEMP/swisseph-build"
New-Item -ItemType Directory -Force $out | Out-Null
gcc -w -shared -O2 -I $src -o "$out/swisseph.dll" `
  "$src/swedate.c" "$src/swehouse.c" "$src/swejpl.c" "$src/swemmoon.c" `
  "$src/swemplan.c" "$src/sweph.c" "$src/swephlib.c" "$src/swecl.c" `
  "$src/swehel.c" '-Wl,--export-all-symbols' -lm
```

Do not commit the DLL. It is a local test dependency.

## Schema notes

- `sunrise`, `sunset`, `tithiEndsAt`, `moonrise`, `nakshatraStartsAt`,
  `nakshatraEndsAt`, and `nextSankranti.at` are ISO-8601 timestamps with an
  explicit `+05:30` offset. `tithiEndsAt` may fall on the next civil date for a
  late transition; `nakshatraStartsAt` may fall on the previous civil date.
- `nakshatraAtSunrise` is the nakshatra prevailing at sunrise,
  `nakshatraStartsAt` its last ingress (at or before sunrise),
  `nakshatraEndsAt` the first instant of `nextNakshatra`. The span is always
  18-30 h and always straddles sunrise.
- `nextSankranti` is `{rashi, at}`: the first sidereal sign ingress strictly
  after sunrise, within 40 days. `rashi` must be the sign after the one that
  holds the sunrise Sun, and comes from the canonical `rashiNames` list.
- `tithiAtSunrise` and `nextTithi` store `paksha`, the paksha-relative
  `number` (1–15), and the canonical `name` (`Purnima`/`Amavasya` for 15).
- `tithiEndsAt` and `nextTithi` are both `null` when the sunrise tithi still
  prevails at the next sunrise (Vriddhi / no daytime transition).
- `masa` keeps the engine's `Adhika_<Masa>` prefix; `adhika` mirrors it.
  `masaPurnimanta` is the Amanta→Purnimanta display conversion.
- `bengaliDate` is present only on the Bengali transition cases.
- `tolerance.eventSeconds` applies to sunrise/sunset/tithiEndsAt/moonrise and
  to `nakshatraStartsAt`/`nakshatraEndsAt`/`nextSankranti.at`.
  `tolerance.longitudeArcseconds` applies to the Sun/Moon longitudes.
