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

- Engine tag: `panchang-v1` (`kPanchangCalculationVersion = 1`).
- Ayanamsa: Lahiri. Month system: Amanta. Timezone: `Asia/Kolkata`.
- Sunrise: the current NOAA-style `SunriseCalculator`
  (`apparent_upper_limb_noaa`), which is **minute-rounded**. Phase 1 will move
  this to the Swiss Ephemeris `hindu_rising` convention; that change is
  expected to move sunrise/sunset by up to about a minute and will require a
  reviewed fixture update.
- Tithi, nakshatra, masa, and festival matching come from the shipped
  `computePanchangData` pipeline, including the Vriddhi filter on a three-day
  window (`date - 1 .. date + 1`).
- Yoga and karana are derived from the sidereal Sun/Moon longitudes at sunrise.
- `moonrise` uses `MoonriseCalculator` (upper-limb rise, local civil day).

## Coverage

82 cases across 19 dates and 6 cities: Delhi, Kolkata, Mumbai, Varanasi,
Chennai, Guwahati. The `tags` array records intent; the validation test
requires the union to cover:

`kshaya`, `vriddhi`, `ekadashi`, `mahashivratri`, `janmashtami`, `diwali`,
`holi`, `ram_navami`, `sankranti`, `adhika`, `sunrise-boundary`,
`bengali-transition`, `moonrise-festival`, `ephemeris-boundary`,
`amanta-purnimanta`.

Notable cases:

- `delhi-2026-06-30` / `mumbai-2026-06-30`: the Purnima → Pratipada boundary
  falls about one minute after sunrise, so the same date resolves to Purnima
  in Delhi and Pratipada in Mumbai/Chennai.
- `kolkata-2026-10-17`: Shashthi prevails at both the Oct 16 and Oct 17
  sunrises (Vriddhi), while Delhi advances to Saptami.
- `delhi-2026-09-04` / `mumbai-2026-09-04`: known Janmashtami gap — nishita
  (00:20) samples just after Ashtami ends (00:15), so the nishita-override
  festival does not resolve. Kolkata/Varanasi/Chennai/Guwahati resolve on the
  same date. Revisit with the Phase 2 checkpoint policy.
- `kolkata-2026-04-14`: the West Bengal rule yields Boishakh 1; the fixture
  notes that the sankranti rule should be cross-checked before external
  verification.
- `delhi-1800-01-01` / `guwahati-2399-12-31`: bundled-ephemeris range
  boundaries.

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
# IST host (the Phase 0 solar calculator uses the device timezone).
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

- `sunrise`, `sunset`, `tithiEndsAt`, and `moonrise` are ISO-8601 timestamps
  with an explicit `+05:30` offset. `tithiEndsAt` may fall on the next civil
  date for a late transition.
- `tithiAtSunrise` and `nextTithi` store `paksha`, the paksha-relative
  `number` (1–15), and the canonical `name` (`Purnima`/`Amavasya` for 15).
- `tithiEndsAt` and `nextTithi` are both `null` when the sunrise tithi still
  prevails at the next sunrise (Vriddhi / no daytime transition).
- `masa` keeps the engine's `Adhika_<Masa>` prefix; `adhika` mirrors it.
  `masaPurnimanta` is the Amanta→Purnimanta display conversion.
- `bengaliDate` is present only on the Bengali transition cases.
- `tolerance.eventSeconds` applies to sunrise/sunset/tithiEndsAt/moonrise.
  `tolerance.longitudeArcseconds` applies to the Sun/Moon longitudes.
