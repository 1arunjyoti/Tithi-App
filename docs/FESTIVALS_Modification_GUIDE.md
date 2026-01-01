# Festival Data Editing Guide

This guide explains how to add or edit festivals in `festivals.json`.

## Calendar System

**Always use Amanta format** for the `masa` field. The app automatically handles Purnimant conversion.

## Festival Structure

```json
{
  "id": "unique_festival_id",
  "name": "Festival Name",
  "category": "major|vrat|regional",
  "panchang_rules": {
    "masa": "MonthName",
    "paksha": "Shukla|Krishna",
    "tithi": 1-15,
    "conditions": "",
    "recurring": true
  }
}
```

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

## Krishna Paksha Rule

For Krishna Paksha festivals, use the month that **ends** with that Amavasya:

| Festival  | Paksha     | Masa (Amanta) | Why                    |
| --------- | ---------- | ------------- | ---------------------- |
| Holi      | Krishna 1  | Phalguna      | After Phalguna Purnima |
| Shivratri | Krishna 14 | Magha         | Before Magha Amavasya  |
| Diwali    | Krishna 15 | Ashwin        | Ashwin Amavasya        |

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

- `"conditions": "Solar"` - For solar calendar festivals (Makar Sankranti)
- `"masa": "*"` - Matches any month
- `"paksha": "*"` - Matches both pakshas

## After Editing

Increment `festivalsVersion` in `lib/services/festival_repository.dart` to force cache refresh:

```dart
static const int festivalsVersion = 5; // Increment this
```
