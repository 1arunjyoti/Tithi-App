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
