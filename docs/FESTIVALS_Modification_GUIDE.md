# Festival Data Editing Guide

This guide explains how to add or edit festivals in `festivals.json`.

## Calendar System

**Always use Amanta format** for the `masa` field. The app automatically handles Purnimant conversion.

## Festival Structure

```json
{
  "id": "unique_festival_id",
  "name": "Festival Name",
  "category": "major|vrat|recurring",
  "displayPriority": 1,
  "nameRegional": {
    "nameSanskrith": "",
    "nameEnglish": "English name",
    "nameHindi": "",
    "nameBengali": "",
    "nameTelugu": "",
    "nameKannada": "",
    "nameTamil": "",
    "nameMalayalam": ""
  },
  "visuals": { "image": "", "theme_color": "" },
  "purpose": {
    "description": "One-line summary (shown on the sheet)",
    "addtional_description": "Longer text behind Read More (note legacy spelling — both spellings parse, see traps)"
  },
  "panchang_rules": {
    "masa": "MonthName",
    "paksha": "Shukla|Krishna",
    "tithi": 1-15,
    "conditions": "",
    "recurring": true,
    "solarDate": "MM-DD",
    "weekday": "Monday",
    "endTithi": 15,
    "timingOverride": "madhyahna|aparahna|nishita|pradosha",
    "vriddhi": "first|second|both",
    "pujaKala": "madhyahna|nishita|pradosha|moonrise|sunrise|sunset|sandhi_junction",
    "paranRule": "moonrise|next_sunrise|after_puja_kala|dwadashi_window",
    "clipToTithi": false
  },
  "rituals": {
    "steps": ["Step one", "Step two"],
    "mantra": "",
    "fasting": ""
  },
  "media": { "audio_stotra": "" }
}
```

All `panchang_rules` keys except `masa`/`paksha`/`tithi`/`conditions` are
optional and fall back to safe defaults when omitted (see field table
below). `visuals`, `rituals`, and `media` are likewise optional — the
parser defaults them to empty (13 current entries omit one or more,
mostly the terse Navratri sequence markers). `displayPriority`
(top-level, sibling of `id`/`name`/`category` — **not** inside
`panchang_rules`) is also optional; omit it unless the festival shares
its day with others and needs an explicit order (see Display Priority).
`category` in use: `major` (94 entries), `vrat` (12), `recurring` (2) —
the sheet shows fasting/rituals/mantra sections only when those fields
are non-empty, so an entry with empty `steps`/`mantra`/`fasting` renders
fewer sections by design, not by bug.

`category` and the `recurring` flag never affect matching — they only
drive filtering and headlines. The vrat list is `category == 'vrat'` OR
`recurring == true` (`vratProvider` in `lib/providers/festival_provider.dart`;
today that is the two Ekadashi vrats plus `purnima`/`amavasya`), the major
list is `category == 'major'`, and the day headline falls back to the
first `major` only when no `displayPriority` rank is present (see Display
Priority). So tagging a monthly vrat `recurring: true` controls which tab
it appears under, not which days it matches — matching still comes purely
from `masa`/`paksha`/`tithi` (usually with `"masa": "*"`).

## Panchang Rules

### Masa (Month)

Use Amanta month names:

| Month        | Approx. Gregorian |
| ------------ | ----------------- |
| Chaitra      | Mar-Apr           |
| Vaishakha    | Apr-May           |
| Jyeshtha     | May-Jun           |
| Ashadha      | Jun-Jul           |
| Shravana     | Jul-Aug           |
| Bhadrapada   | Aug-Sep           |
| Ashwin       | Sep-Oct           |
| Kartika      | Oct-Nov           |
| Margashirsha | Nov-Dec           |
| Pausha       | Dec-Jan           |
| Magha        | Jan-Feb           |
| Phalguna     | Feb-Mar           |

Only these 12 names ever match a computed masa — with three legacy
exceptions in the data:

- `ganga_dussehra` stores `"masa": "Adhika_Jyeshtha"`, so it matches only
  inside an intercalary Adhika-Jyeshtha month (e.g. 2026, 2037, 2045 — see
  `integration_test/adhika_verify_test.dart`). Do not use an `Adhika_*`
  masa for a normal annual festival; it will silently miss every common
  year. Adhika/Nija months are otherwise distinct masas for slicing and
  display (`schedule_view_widget.dart` renders `Adhika_Jyeshtha` as
  "Adhika Jyeshtha").
- `onam` stores `"masa": "Simha"` (a solar/Tamil month name), which is
  harmless because `Solar` festivals ignore `masa` entirely. `pongal` had
  the same problem in worse form (`Thai`/`Shukla`/15 with no `solarDate`,
  so it never fired at all) and was converted to `Solar` `"01-14"` like
  `makar_sankranti` — guarded by the Solar group in
  `test/festival_data_test.dart`.

### Paksha

- `Shukla` - Waxing moon (Pratipada to Purnima)
- `Krishna` - Waning moon (Pratipada to Amavasya)

### Tithi (1-15)

| Tithi | Name             |
| ----- | ---------------- |
| 1     | Pratipada        |
| 2     | Dwitiya          |
| 3     | Tritiya          |
| 4     | Chaturthi        |
| 5     | Panchami         |
| 6     | Shashthi         |
| 7     | Saptami          |
| 8     | Ashtami          |
| 9     | Navami           |
| 10    | Dashami          |
| 11    | Ekadashi         |
| 12    | Dwadashi         |
| 13    | Trayodashi       |
| 14    | Chaturdashi      |
| 15    | Purnima/Amavasya |

`tithi: 0` is the placeholder convention for `Solar` festivals (all five
use it — the value is ignored for matching, but the key must still parse;
a missing `tithi` also defaults to `0` in `PanchangRules.fromJson`, which
matches nothing). Never use `0` for a lunisolar festival.

## Krishna Paksha Rule

For Krishna Paksha festivals, use the month that **ends** with that Amavasya:

| Festival  | Paksha     | Masa (Amanta) | Why                    |
| --------- | ---------- | ------------- | ---------------------- |
| Holi      | Krishna 1  | Phalguna      | After Phalguna Purnima |
| Shivratri | Krishna 14 | Magha         | Before Magha Amavasya  |
| Diwali    | Krishna 15 | Ashwin        | Ashwin Amavasya        |

Storing a Purnimanta month name here fires ~a month late with no error.
`test/festival_data_test.dart` guards the known cases (Kamika, Varuthini,
Kajari, Janmashtami) — add a guard when you fix or add a Krishna festival.

## Two Traditions, One Engine

The engine computes Drik tithis (≈ Bisuddha Siddhanta). North-Indian
(Navratri sequence) and Bengali (Durga Puja) observances of the *same tithi*
can therefore legitimately land on different days, and the dataset carries
**both** entries on purpose — e.g. Ashwin Shukla 6 has
`sharad_navratri_katyayani_puja` *and* `shashthi_durga_puja`. This
duplication is load-bearing, not a mistake:

- Sequence side (Navratri day-forms): `"vriddhi": "first"` — the sequence
  advances from the run head.
- Puja side: default `"both"`, or `"second"` where Bengal keeps the later
  day (`saptami_durga_puja`).
- Never "fix" the duplication by deleting one side, and never change one
  side's tithi without checking the other.

Background on *why* they diverge (Drik vs Surya Siddhanta, vriddhi
resolution, Dashami-visarjan rule) is worked through in the repo history
around Oct 2026; the Telegraph 2026 piece ("twin tithis") is the canonical
external reference.

## Data Traps (Hard-Won)

1. **`tithi` is 1–15, never 30.** Matching compares against the
   paksha-relative number, so `"tithi": 30` silently matches nothing
   (this hid Koushiki Amavasya completely; correct value is 15).
2. **`addtional_description` (missing the second `i`) is the legacy key.**
   The parser accepts both spellings, so old and new entries coexist —
   do not mass-rename; just keep whichever spelling the neighboring
   entries use.
3. **`id` is the Hive key and must be unique** — duplicates silently
   overwrite each other on reseed. Avoid spaces (two legacy offenders
   exist); renaming an id is safe data-wise (reseed clears the box) but
   update any test referencing it.
4. **Spelling traps that fail silently:** `"nishita"` (not
   `nishitha`/`nisitha`) for `timingOverride`; Amanta (not Purnimanta)
   month names — both fall back to sunrise/offset behavior with no error.
5. **Festival artwork budget (`visuals.image`):** `image` is consumed by
    the home hero card (`_HeroFestivalImage` in
    `lib/widgets/paksha_hero_card.dart`, ~96px slot, `BoxFit.cover`) —
    keep it `""` unless the festival really needs artwork. When adding
    one, drop the source into `assets/images/festival/` and run
    `python scripts/compress_festival_images.py` from the repo root: it
    downsizes to **<=800px** longest side, converts to **WebP (q80)**,
    guarantees **<=200 KB** (stepping quality down, then size, until it
    fits), updates the `visuals.image` path in `assets/festivals.json`,
    and removes the original. `test/festival_image_assets_test.dart`
    fails on non-WebP, oversized, or unreferenced files, so CI catches
    what the script wasn't run on. `theme_color` is ignored by the event
    sheet (always app primary, per the comment in
    `lib/widgets/event_detail_sheet.dart`); the entries carrying hex
    values are inert documentation for future surfaces — leave new
    entries `""`.
6. **Empty sections are data, not bugs:** fasting/rituals/mantra blocks
   render only when their fields are non-empty.

## Examples

### Major Festival (Annual)

```json
{
  "id": "diwali",
  "name": "Diwali",
  "category": "major",
  "panchang_rules": {
    "masa": "Ashwin",
    "paksha": "Krishna",
    "tithi": 15,
    "conditions": "",
    "recurring": false
  }
}
```

### Recurring Vrat (Monthly)

```json
{
  "id": "ekadashi",
  "name": "Ekadashi",
  "category": "vrat",
  "panchang_rules": {
    "masa": "*",
    "paksha": "*",
    "tithi": 11,
    "conditions": "",
    "recurring": true
  }
}
```

### Special Conditions

The `conditions` field is informational for tithi festivals (it usually
echoes the tithi name, e.g. `"Shashthi"`) and is ignored during matching —
with two exceptions that **override** normal matching:

| Value | Effect |
| ----- | ------ |
| `"Solar"` | Fixed Gregorian date from `solarDate` (`"MM-DD"`, e.g. Makar Sankranti). Tithi/masa are ignored. |
| `"<Name> Nakshatra"` | Observed when that nakshatra prevails at sunrise within the given masa + paksha. The stored `tithi` is ignored for matching (keep it as documentation). Any of the 27 names below works; unknown names fall back to tithi matching. |

- `"masa": "*"` - Matches any month
- `"paksha": "*"` - Matches both pakshas
- Empty string behaves as wildcard too: stored `masa: ""` matches any
  computed masa (`festival.dart` skips the check), and stored `paksha: ""`
  falls back to the day's paksha via `resolvePaksha`. Prefer explicit
  `"*"` for new entries — `""` is a legacy shape, not a convention.

### Nakshatra-Observed Festivals

Some festivals follow a nakshatra, not a tithi. Saraswati Avahan must fall
on Mula Nakshatra during Ashwin Shukla — which lands on Saptami some years
(2025: Sep 29) and Shashthi others (2026: Oct 16). No static `tithi` value
can represent that, so the condition takes precedence:

```json
{
  "id": "sharad_navratri_saraswati Avahan",
  "panchang_rules": {
    "masa": "Ashwin",
    "paksha": "Shukla",
    "tithi": 7,
    "conditions": "Mula Nakshatra",
    "vriddhi": "first"
  }
}
```

Rules:

- Matching = `masa` (Amanta) + `paksha` + nakshatra prevailing at **sunrise**
  (udaya), consistent with the udaya-tithi rule used everywhere else.
- `tithi` is skipped for matching but still required by the schema — keep the
  most typical value as documentation.
- No Kshaya fallback: a nakshatra always owns a sunrise.
- The detail sheet shows a Nakshatra row and hides the tithi Begins/Ends span
  (it would mislead); export reports the day's tithi with a null span.
- Web builds have no ephemeris, so nakshatra festivals never match there
  (documented limitation).
- Vriddhi trimming applies normally (Mula can span two sunrises).

Valid names (Vedic order): Ashwini, Bharani, Krittika, Rohini, Mrigashira,
Ardra, Punarvasu, Pushya, Ashlesha, Magha, Purva Phalguni, Uttara Phalguni,
Hasta, Chitra, Swati, Vishakha, Anuradha, Jyeshtha, Mula, Purva Ashadha,
Uttara Ashadha, Shravana, Dhanishta, Shatabhisha, Purva Bhadrapada,
Uttara Bhadrapada, Revati.

Two nakshatra festivals ship today: `sharad_navratri_saraswati Avahan`
(`Mula Nakshatra`) and `sharad_navratri_saraswati_puja`
(`Purva Ashadha Nakshatra`), both Ashwin Shukla with `vriddhi: first`.

### Solar (Fixed Gregorian Date)

A `Solar` festival matches one Gregorian month-day every year and ignores
`tithi`/`masa`/`paksha` completely (`PanchangData.fromRawTithi` compares
only the `MM-DD` string):

```json
{ "id": "makar_sankranti",
  "panchang_rules": { "masa": "Pausha", "paksha": "*",
    "tithi": 0, "conditions": "Solar", "solarDate": "01-14" } }
```

Rules:

- `solarDate` is an exact zero-padded `"MM-DD"` string (`"01-14"`, not
  `"1-14"`) — any other shape never matches, with no error.
- Keep the shipped convention: `tithi: 0`, `paksha: "*"`, and the nearest
  masa as documentation (`Bhadrapada` for Vishwakarma, `Pausha` for Makar
  Sankranti/Lohri; `onam` carries the solar month `Simha`, which is fine
  precisely because `masa` is ignored here).
- `conditions: "Solar"` with a missing `solarDate` never matches: the
  Solar branch requires the date, and `matchesTithi` returns false for
  Solar otherwise. Both halves must be present.
- Current Solar set (5): `vishwakarma_puja` `09-17`, `onam` `08-26`,
  `makar_sankranti` `01-14`, `pongal` `01-14`, `lohri` `01-13`.
  (`pongal` shares Makar Sankranti's day; both match every Jan 14.)
- No Kshaya fallback, no grace window, no `timingOverride` path; export
  reports a null tithi span for Solar festivals.

### Timing Override

Most festivals match on the sunrise (udaya) tithi. Festivals decided at
another moment of the day set `timingOverride` (evaluated at that checkpoint
instead of sunrise):

| Value | Checkpoint | Example |
| ----- | ---------- | ------- |
| `"madhyahna"` | Midday (sunrise + half day-length) | Ganesh Chaturthi |
| `"aparahna"` | Afternoon (sunrise + 3/4 day-length) | Dussehra / Vijayadashami |
| `"nishita"` | Midnight (sunset + half night-length) | Maha Shivaratri |

Omitted (or any other value) = sunrise. Spelling matters: `"nishita"`,
not `"nishitha"`/`"nisitha"` — a misspelled value silently falls back to
sunrise.

### Dominant-Tithi Grace (60 Minutes After Sunrise)

A tithi beginning within 60 minutes after sunrise counts for that Gregorian
day (Drik convention). The engine samples one extra checkpoint at
sunrise + 60 min (`kDominantTithiGrace` in
`lib/services/festival_matching_pipeline.dart` — the single definition).

- **Additive only:** sunrise matches are never removed. A tithi owning the
  sunrise still matches even when the next tithi earns the day via grace
  (Oct 17 2026: Shashthi owns the sunrise, Saptami begins ~20 min later —
  both match, which is why Puja Shashthi spans 16+17 *and* Saptami reaches
  the 17th).
- Applies to sunrise-matched festivals only — `timingOverride`, `Solar`
  and `<Name> Nakshatra` festivals keep their own paths.
- New-moon wrap inside the window uses the next lunation's masa.
- Forward scanners (countdown/search/export) and notifications apply the
  same rule, so all surfaces agree.

### Vriddhi (Extended Tithi Spanning Two Sunrises)

When a tithi prevails at two consecutive sunrises, a festival matches both
days by default. Sequence festivals where the observance must advance take
only the first day of the run:

| Value | Effect | Default? |
| ----- | ------ | -------- |
| `"both"` | Keep every matching day (legacy behavior) | Yes — omit the field |
| `"first"` | Keep only the first day of a consecutive run | No |
| `"second"` | Keep only the last day of a consecutive run | No |

Unknown values fall back to `"both"`, so existing entries without the field
are unaffected.

Example (Oct 2026: Shashthi at sunrise on the 16th *and* 17th):

```json
// Navratri sequence advances → first day only (Oct 16)
{ "id": "sharad_navratri_katyayani_puja",
  "panchang_rules": { "masa": "Ashwin", "paksha": "Shukla",
    "tithi": 6, "conditions": "Shashthi", "vriddhi": "first" } }

// Bengali observance spans both days → no field needed (Oct 16 + 17)
{ "id": "shashthi_durga_puja",
  "panchang_rules": { "masa": "Ashwin", "paksha": "Shukla",
    "tithi": 6, "conditions": "Shashthi" } }
```

Trimming runs through the shared pipeline
(`lib/services/festival_matching_pipeline.dart`), so UI grid, single-day
sheet, export, countdown/search and notifications always agree. Non-consecutive
matches are separate runs and are never trimmed; single-day matches are
untouched.

### Kshaya (Skipped Tithi Owning No Sunrise)

Vriddhi's mirror image: when a tithi begins after one sunrise and ends
before the next, it owns no sunrise at all. Without a fallback its
festivals would vanish for the year, so the engine credits the skipped
tithi to the earlier day (`PanchangData.fromRawTithi`: when
`rawTithiNextSunrise` jumps by more than one index, each skipped index is
re-matched as paksha + tithi + masa).

Rules:

- Applies to checkpoint/grace matches only — `Solar` festivals return on
  their own path and `<Name> Nakshatra` festivals explicitly skip it (a
  nakshatra always owns a sunrise).
- Amavasya/Purnima-boundary skips (`skippedIndex == 1 || == 16`) are
  tested against `masaNextSunrise` as well as the day's masa, so a Kshaya
  Pratipada starting a new lunation still matches.
- Wrap-around past index 30 is handled (Shukla↔Krishna mapping shifts by
  15), but `masa`/`paksha`/`weekday` constraints still apply to the
  skipped tithi exactly as normal — Kshaya never widens a rule, it only
  supplies the missing day.
- Export has no tithi span for Kshaya occurrences (null Begins/Ends), and
  a year export's `occurrence` is null when the tithi never lands in that
  year (`festival_export_service.dart`).
- No data annotation needed: unlike `vriddhi`, Kshaya needs no field —
  every tithi rule gets the fallback automatically. Covered by the
  `Kshaya (skipped tithi) fallback` group in `test/panchang_data_test.dart`
  (synthetic `rawTithiNextSunrise` checkpoints: basic skip, non-skip miss,
  Amavasya-boundary masa) — the Kshaya Pratipada case in
  `test/hindu_adhika_month_test.dart` guards month slicing, not festival
  matching, so keep both.

### Weekday and Tithi-Range Constraints

Two optional `panchang_rules` refinements narrow (never widen) a match.
Neither is used by any of the 108 shipped entries — both parse, both are
tested only synthetically, so treat them as available but unproven in
production data:

- `weekday`: full English day name with capital first letter (`"Monday"`
  … `"Sunday"`), matched against the Gregorian date (`festival.dart`
  `weekdayMap`). Unknown or misspelled values are silently ignored (the
  constraint passes); an empty/missing value means no constraint. The
  constraint is only evaluated when callers pass a `date` — all shipped
  pipeline paths do (BUG-04), but a future caller matching without a date
  would silently drop the filter.
- `endTithi`: inclusive range — the festival matches any
  `tithi <= current <= endTithi` within the same paksha/masa
  (`currentTithi >= tithi && <= endTithi`). Keep `tithi <= endTithi`;
  an inverted range matches only the exact `tithi`.

```json
{ "id": "example_weekday_vrat",
  "panchang_rules": { "masa": "*", "paksha": "*",
    "tithi": 11, "conditions": "Ekadashi", "weekday": "Monday",
    "recurring": true } }
```

### Display Priority (Same-Day Ordering)

When several festivals match the same day, their list order — and which
one headlines the day (calendar subtitle, countdown, notifications) — is
controlled by the optional top-level `displayPriority` (int, lower shows
first). It lives **next to** `id`/`name`/`category`, not inside
`panchang_rules`:

```json
{ "id": "sharad_navratri_siddhidatri_puja",
  "category": "major",
  "displayPriority": 2,
  "panchang_rules": { "masa": "Ashwin", "paksha": "Shukla",
    "tithi": 9, "conditions": "Navami", "vriddhi": "first" } }
```

Rules:

- Omit it (= null) when the day has no ordering conflict — missing means
  "no override" and the day keeps its current order. The sort is stable
  and a no-op when nothing on the day carries a rank, so existing entries
  are unaffected.
- When at least one same-day festival carries a rank, ranked entries sort
  before unranked ones (unranked sink to the end, keeping their relative
  order); ties keep their existing relative order.
- Headline pick (`primaryFestival` in `lib/models/festival.dart`): the
  smallest rank wins when any rank is present; otherwise the legacy
  fallback applies (first `major`, else first).
- Only rank festivals that actually collide on a day. Current ranked set
  (7 entries): Durga Puja Shashthi→Dasami `1`, Siddhidatri `2`, Dussehra
  `3` — e.g. Navami renders Maha Navami (1) before Siddhidatri (2);
  Dashami renders Dasami Puja (1) before Dussehra (3). Without ranks
  these fall back to Hive A-Z order, which misordered the headline.
- Accepts ints (a JSON float is truncated via `toInt()`); non-numeric
  values parse as null (unranked). There is no reserved range — keep the
  existing 1/2/3 convention for the Durga Puja cluster and use the next
  free int for new collisions.

### Full Field Reference (`panchang_rules`)

| Field | Type | Default | Purpose |
| ----- | ---- | ------- | ------- |
| `masa` | string | (required) | Amanta month; `"*"` = any month |
| `paksha` | string | (required) | `Shukla` / `Krishna`; `"*"` = either |
| `tithi` | 0-15 | (required) | Paksha-relative tithi (15 = Purnima/Amavasya). Ignored for `Solar` (use `0`) and `<Name> Nakshatra` conditions (keep typical value as docs). |
| `conditions` | string | (required) | Tithi-name echo (informational; spelling variants like `Dasami`/`Dashami` are harmless), `"Solar"`, or `"<Name> Nakshatra"` (both override matching) |
| `recurring` | bool | `false` | Tab filter only (`vrat` tab = `category == 'vrat'` OR `recurring`), never matching |
| `solarDate` | string | — | Exact zero-padded `"MM-DD"` for `Solar` festivals; missing/other shapes never match |
| `weekday` | string | — | Full `"Monday"`…`"Sunday"` (case-sensitive; unknown = ignored); 0 shipped entries use it |
| `endTithi` | int | — | Inclusive tithi *range* (`tithi`…`endTithi`); 0 shipped entries use it |
| `timingOverride` | string | sunrise | `madhyahna` / `aparahna` / `nishita` / `pradosha` (dusk-window midpoint) checkpoint |
| `vriddhi` | string | `"both"` | `first` / `second` / `both` run trimming |
| `pujaKala` | string | — (null = no Puja Samay card) | Ritual window: `madhyahna` / `nishita` / `pradosha` (day-view windows), `moonrise` (48-min grace from the rise), `sandhi_junction` (48-min span centered on the festival tithi's end), or exact instants `sunrise` / `sunset` (Chhath arghya). Unknown values hide the card. |
| `paranRule` | string | — (null = no fast, or breaking isn't critical) | Fast-breaking range shown under Fasting / Vrat: `moonrise` (+48 min) / `next_sunrise` (+2 h) / `after_puja_kala` (~puja end) / `dwadashi_window` ([next sunrise + D/4, Dwadashi end]). Unknown values hide the line. |
| `clipToTithi` | bool | `false` | Non-nullable: absent == `false`. When `true`, the puja window end cuts at the festival tithi's end. Set only on Pradosh Vrata (kalam must stay inside Trayodashi). |
| `puja_kala` / `paran_rule` / `clip_to_tithi` | same | same | Snake_case twins of the three rows above — both spellings parse (camelCase first). Precedent: `additional_description` / `addtional_description`. Shipped data already uses `puja_kala` on Ganesh Chaturthi. |

Top-level (outside `panchang_rules`):

| Field | Type | Default | Purpose |
| ----- | ---- | ------- | ------- |
| `displayPriority` | int | — (null = no override) | Same-day order + headline pick; lower shows first (see Display Priority) |

## After Editing

No manual version bump needed: `FestivalRepository` fingerprints
`festivals.json` content (`_versionFromJsonContent` in
`lib/services/festival_repository.dart`) and reseeds Hive automatically on
the next launch whenever the file changes. Just relaunch the app (and, when
adding a `HiveField`, regenerate adapters with `build_runner`).

### Verification checklist

1. `flutter analyze` on touched files — clean.
2. `flutter test test/festival_data_test.dart test/vriddhi_filter_test.dart test/dominant_grace_test.dart test/nakshatra_matching_test.dart test/panchang_data_test.dart test/festival_export_test.dart test/display_priority_test.dart` — all green.
   Note: the `Dataset` groups in those files assert live annotations
   (`vriddhi`, `Mula Nakshatra`, `displayPriority`, Amanta months). If you
   intentionally change an annotation, update the corresponding expectation
   — a red dataset test means the data drifted, not (only) that the test
   is stale.
3. Relaunch and check the affected date on **all surfaces that show it**:
   calendar dot, event sheet (incl. Begins/Ends), countdown/search, and —
   for boundary weeks — the notification content. They share one pipeline,
   but verify anyway.
4. Cross-check tithi Begins/Ends against Drik Panchang for the year in
   question, especially within ±1 day of the change. In vriddhi/grace
   boundary weeks, confirm *both* traditions' days (e.g. Oct 2026:
   Navratri-17th *and* Bisuddha-18th), not just one side.
5. True ephemeris runs need a device build — this repo's Windows host has
   no native ephemeris library, so host-side `flutter test` covers matching
   logic with synthetic checkpoints, never real sky positions.
   `test/festivals_rule_test.dart` is device-only (it initializes the real
   `PanchangService` and fails under plain host `flutter test` with
   `MissingPluginException` from `path_provider`) — it needs a run
   environment with platform plugins, so it is intentionally absent from
   the command in step 2.

## Code Maintenance (Matching Pipeline Map)

Data edits stay in `assets/festivals.json`. If the *rules* need changing,
this is where each piece lives — add new surfaces here, never around it:

- Match definition: `Festival.matchesTithi` + `matchesFestivalOnDay`
  (`lib/models/festival.dart`); per-day assembly incl. Solar branch,
  checkpoint select, grace, and Kshaya fallback:
  `PanchangData.fromRawTithi` (`lib/models/panchang_data.dart`).
- Same-day ordering: `sortFestivalsByDisplayPriority` +
  `primaryFestival` (`lib/models/festival.dart`), applied at the end of
  `PanchangData.fromRawTithi`. Ranked first (lower first), unranked last,
  ties stable.
- Run trimming, grace constant, occurrence resolution:
  `lib/services/festival_matching_pipeline.dart` (single source of truth).
- UI: month grid + single-day-from-month-map (`lib/providers/panchang_provider.dart`;
  single-day never matches independently), calendar dots
  (`calendar_widget.dart` reads the filtered flag map).
- Occurrence scanners: `findNextFestivalOccurrence` (native + web
  `panchang_service` variants; loops duplicated, decision helpers shared) —
  feeds countdown, search, export.
- Notifications (`notification_service.dart`): same matcher + same filter
  over its window and 3-day daily context.
- Known duplications (same behavior, two code sites — change both):
  checkpoint computation (provider helper vs notification inline copy) and
  the native/web `findNext` loops.
