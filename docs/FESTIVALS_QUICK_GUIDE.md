# Festival Data Quick Guide

Use this guide for the common festival-data workflow. The complete reference,
including implementation details and edge cases, is in
[FESTIVALS_Modification_GUIDE.md](FESTIVALS_Modification_GUIDE.md).

## 1. Where to edit

Edit only [assets/festivals.json](../assets/festivals.json). The app fingerprints
the file and reseeds its local data automatically on the next launch.

## 2. Minimal festival entry

```json
{
  "id": "unique_festival_id",
  "name": "Festival Name",
  "category": "major",
  "panchang_rules": {
    "masa": "Ashwin",
    "paksha": "Shukla",
    "tithi": 10,
    "conditions": "Dashami"
  }
}
```

### Required rules

| Field | Allowed values |
|---|---|
| `masa` | One of the 12 **Amanta** months, or `"*"` for any month |
| `paksha` | `"Shukla"`, `"Krishna"`, or `"*"` |
| `tithi` | `1`–`15`; use the paksha-relative number |
| `conditions` | Usually the tithi name; use `"Solar"` or `"<Name> Nakshatra"` for special matching |

Important:

- `tithi` is never `30`. `15` means Purnima in Shukla Paksha and Amavasya in
  Krishna Paksha.
- For Krishna Paksha, use the Amanta month that ends with the Amavasya.
  For example, Diwali is `Ashwin` + `Krishna` + `15`.
- Do not use `Adhika_*` for an ordinary annual festival.
- `id` is the Hive key. It must be unique and should use lowercase
  `snake_case`.

## 3. Choose the matching type

### Normal lunisolar festival

Match by Amanta month, paksha, and tithi:

```json
"panchang_rules": {
  "masa": "Phalguna",
  "paksha": "Krishna",
  "tithi": 1,
  "conditions": "Pratipada"
}
```

### Recurring vrat

Use wildcards for festivals such as monthly Ekadashi:

```json
"category": "vrat",
"panchang_rules": {
  "masa": "*",
  "paksha": "*",
  "tithi": 11,
  "conditions": "Ekadashi",
  "recurring": true
}
```

`recurring` controls filtering and yearly-list repetition. It does **not**
change how the festival matches a day.

### Solar festival

Use an exact, zero-padded Gregorian date:

```json
"panchang_rules": {
  "masa": "Pausha",
  "paksha": "*",
  "tithi": 0,
  "conditions": "Solar",
  "solarDate": "01-14"
}
```

For a Sankranti, also set `sankranti` to the solar ingress name and keep
`solarDate` as the fallback:

```json
"conditions": "Solar",
"solarDate": "01-14",
"sankranti": "Makara"
```

Solar festivals ignore `masa`, `paksha`, and `tithi` during matching, but keep
the conventional values shown above.

### Nakshatra-observed festival

Use the nakshatra in `conditions`; the stored `tithi` is documentation only:

```json
"panchang_rules": {
  "masa": "Ashwin",
  "paksha": "Shukla",
  "tithi": 7,
  "conditions": "Mula Nakshatra"
}
```

The nakshatra must prevail at sunrise. Use a valid Vedic nakshatra name.

## 4. Rules that commonly affect dates

- **Default matching:** the sunrise (udaya) tithi is used.
- **Grace:** by default, a tithi beginning within 60 minutes after sunrise
  also matches that day.
- **Strict sunrise matching:** set `"dominant_tithi": "strict"` when grace
  must not add another day. This is used for the Durga Puja observances.
- **Extended tithi:** omit `vriddhi` to keep all matching days. Use
  `"vriddhi": "first"` or `"second"` when only the first or last day of a
  consecutive run should be observed.
- **Skipped tithi:** Kshaya fallback is automatic; no data flag is needed.
- **Time-specific observance:** set `timingOverride` when the festival is
  decided at a checkpoint such as `"madhyahna"`, `"aparahna"`, `"nishita"`,
  or `"pradosh"`. The exact spelling `"nishita"` matters.

Do not delete duplicate North-Indian and Bengali observances of the same
tithi. They represent different traditions and can intentionally fall on
different dates.

## 5. Optional presentation and ritual data

- `displayPriority` is a **top-level** integer, not part of
  `panchang_rules`. Use it only when festivals collide; lower numbers appear
  first.
- `regions` is a top-level list. Use lowercase `north`, `south`, `east`,
  `west`, `central`, `northeast`, or `all`. Omit it for pan-India festivals.
- `visuals.image` should normally remain empty. If artwork is needed, follow
  [FESTIVAL_ARTWORK_GUIDE.md](FESTIVAL_ARTWORK_GUIDE.md).
- Keep `theme_color` empty; the event sheet uses the app’s primary color.
- `rituals` and `media` are optional. Empty ritual sections are valid and are
  simply not displayed.
- Use the existing spelling style around an entry. The parser accepts some
  legacy spellings, but new data should prefer camelCase keys such as
  `pujaKala`, `paranRule`, `clipToTithi`, and `avoidBhadra`.

## 6. Before you finish

1. Confirm the festival uses the correct Amanta month and tithi number.
2. Check whether it is normal, recurring, solar, Sankranti, or Nakshatra-based.
3. Decide whether grace, strict matching, or `vriddhi` is required.
4. Run:

   ```bash
   flutter analyze
   flutter test test/festival_data_test.dart test/panchang_data_test.dart
   ```

5. For matching-related changes, also run the focused tests that apply:

   ```bash
   flutter test test/festival_region_test.dart test/vriddhi_filter_test.dart test/dominant_grace_test.dart test/nakshatra_matching_test.dart test/festival_export_test.dart test/display_priority_test.dart
   ```

6. Relaunch the app and check the affected date in the calendar, event sheet,
   countdown/search, export, and notifications when relevant.
7. Compare the result with a trusted Panchang reference, especially around
   tithi transitions and extended or skipped tithis.

The Windows host cannot calculate real ephemeris positions. Device or
platform-plugin runs are required to validate true astronomical results.
