# Bisuddha Siddhanta Bengali Calendar — Implementation Guide for AI Agents

> **Purpose:** This document provides complete rules and instructions for implementing a Bengali calendar (Panjika) based on the Bisuddha Siddhanta (Drik Ganita) system. It is written for an AI agent or developer who already has a Hindu panchang engine and needs to add Bengali calendar support on top of it.

---

## 1. What Is Bisuddha Siddhanta?

**Bisuddha Siddhanta** (also spelled Vishuddha Siddhanta) is the "purified/reformed" school of Bengali almanac calculation. It uses **modern observational astronomy** (Drik Ganita) instead of the ancient Surya Siddhanta formulae used by the traditional Gupta Press school.

### Key facts:
- **Calculation method:** Drik Ganita — modern observational astronomy
- **Ayanamsa:** Lahiri (Chitrapaksha) — the same ayanamsa used by the Government of India's Rashtriya Panchang
- **Ephemeris:** JPL DE series (DE421/DE406/DE430) or Swiss Ephemeris; Chapront Moon ELP-2000 for lunar positions
- **Delta-T (ΔT):** Morrison/Stephenson corrections (Espenak's polynomial), essential for historical accuracy
- **Adopted by:** Ramakrishna Mission (Belur Math), Kanchi Matha, Government of India Rashtriya Panchang
- **First published:** 1890 CE (1297 BS) by Madhab Chandra Chattopadhyay

### If your existing Hindu panchang engine already uses:
- Drik Ganita (not Surya Siddhanta)
- Lahiri ayanamsa
- Modern ephemeris (Skyfield/Swiss Ephemeris)

...then **your engine already computes the correct tithis, nakshatras, yogas, and karanas for the Bisuddha Siddhanta school.** The Bengali calendar is a **presentation layer** on top of the same astronomical computations, with a different solar-month structure, different era, and different year-start.

---

## 2. The Two-Layer Architecture

The Bengali Panjika has two independent layers that are displayed together on each day:

### Layer 1: Solar Month Layer (the "calendar date")
- Determines the **Bengali date** (e.g., "Ashshin 16, 1433 Bangabda")
- Based on the Sun's sidereal longitude crossing 30° zodiac boundaries (sankrantis)
- Uses the **Bengal sankranti rule** to decide which Gregorian day starts each solar month
- This is the primary calendar — what determines the Bangabda year, month, and day number

### Layer 2: Lunar Tithi Layer (for festivals and panchanga)
- Determines the **tithi, nakshatra, yoga, karana** for each day
- Same Drik Ganita computation as your existing Hindu panchang
- Same Udaya Tithi rule (tithi prevailing at sunrise)
- Same Adhika Masa / Kshaya Masa logic
- Festival dates are determined by this layer, NOT by the solar month

**Both layers are computed independently and displayed together.** A single day entry in a Bengali Panjika shows:
```
Solar date: Ashshin 16, 1433 Bangabda
Lunar tithi: Ashwin Krishna Navami (prevailing at sunrise)
Nakshatra: Anuradha
Yoga: ...
Karana: ...
Sunrise: 5:28 AM, Sunset: 5:32 PM
Festivals: Durga Puja — Maha Navami
```

---

## 3. Solar Month Layer — Complete Rules

### 3.1 The 12 Solar Months

The Bengali calendar has 12 solar months. Each month corresponds to the Sun's transit through one sidereal zodiac sign (rashi), spanning exactly 30° of ecliptic longitude.

| # | Bengali Name | Bengali Script | Sanskrit Name | Zodiac Sign (Rashi) | Longitude Range | Starts ~ (Gregorian) |
|---|---|---|---|---|---|---|
| 1 | Boishakh | বৈশাখ | Vaishakha | Mesha (Aries) | 0° – 30° | April 14/15 |
| 2 | Joishtho | জ্যৈষ্ঠ | Jyeshtha | Vrishabha (Taurus) | 30° – 60° | May 15/16 |
| 3 | Asharh | আষাঢ় | Ashadha | Mithuna (Gemini) | 60° – 90° | June 15/16 |
| 4 | Shrabon | শ্রাবণ | Shravana | Karkataka (Cancer) | 90° – 120° | July 16/17 |
| 5 | Bhadro | ভাদ্র | Bhadrapada | Simha (Leo) | 120° – 150° | Aug 16/17 |
| 6 | Ashshin | আশ্বিন | Ashwin | Kanya (Virgo) | 150° – 180° | Sep 16/17 |
| 7 | Kartik | কার্তিক | Kartika | Tula (Libra) | 180° – 210° | Oct 17/18 |
| 8 | Ogrohayon | অগ্রহায়ণ | Margashirsha | Vrishchika (Scorpio) | 210° – 240° | Nov 16/17 |
| 9 | Poush | পৌষ | Pausha | Dhanu (Sagittarius) | 240° – 270° | Dec 15/16 |
| 10 | Magh | মাঘ | Magha | Makara (Capricorn) | 270° – 300° | Jan 14/15 |
| 11 | Falgun | ফাল্গুন | Phalguna | Kumbha (Aquarius) | 300° – 330° | Feb 13/14 |
| 12 | Choitro | চৈত্র | Chaitra | Meena (Pisces) | 330° – 360° | Mar 15/16 |

**Important:** The first month is Boishakh (starting at 0° = Mesha sankranti), NOT Chaitra. The year cycles Boishakh → Choitro.

### 3.2 Sankranti Computation

A **sankranti** is the moment the Sun's sidereal ecliptic longitude crosses a 30° boundary.

**Algorithm:**
1. Compute the Sun's sidereal longitude at frequent intervals (e.g., every hour)
2. Sidereal longitude = Tropical longitude − Lahiri Ayanamsa
3. Detect when the longitude crosses any multiple of 30° (0°, 30°, 60°, ..., 330°)
4. Refine to sub-minute precision using binary search or interpolation
5. The crossing moment is the **sankranti moment** (in local time, IST for Kolkata)

**Each sankranti maps to a month start:**
- 0° (Mesha sankranti) → Boishakh begins
- 30° (Vrishabha sankranti) → Joishtho begins
- 60° (Mithuna sankranti) → Asharh begins
- 90° (Karkataka sankranti) → Shrabon begins
- 120° (Simha sankranti) → Bhadro begins
- 150° (Kanya sankranti) → Ashshin begins
- 180° (Tula sankranti) → Kartik begins
- 210° (Vrishchika sankranti) → Ogrohayon begins
- 240° (Dhanu sankranti) → Poush begins
- 270° (Makara sankranti) → Magh begins
- 300° (Kumbha sankranti) → Falgun begins
- 330° (Meena sankranti) → Choitro begins

### 3.3 The Bengal Sankranti Rule (Month Start Determination)

This is the **most critical rule** for the Bengali calendar. It determines which Gregorian day is "Day 1" of each solar month.

**Rule:**
Given a sankranti moment (the exact time the Sun crosses into a new zodiac sign):

1. Determine the **sunrise** time on the Gregorian day when the sankranti occurs
2. Determine the **midnight** that follows that sunrise (i.e., midnight at the end of that same civil day, which is 00:00 of the next Gregorian day)
3. Apply the rule:

| Sankranti occurs... | Month begins on... |
|---|---|
| **Before sunrise** of day D | Day D (same day) — see Note below |
| **Between sunrise and following midnight** of day D | Day D + 1 (next day) |
| **After midnight** (i.e., in the early morning of day D+1, before sunrise of D+1) | Day D + 2 (day after next) |

**Note on "before sunrise" case:** If the sankranti occurs before sunrise, it technically belongs to the previous civil day's night. In practice, the standard simplified rule most implementations use is:

- **If sankranti is between sunrise and the following midnight → month starts the NEXT day**
- **If sankranti is after midnight → month starts the DAY AFTER the next day (i.e., +2 days)**

This is what causes Pohela Boishakh to sometimes fall on April 15 in West Bengal (traditional/Bisuddha Siddhanta calculation) while Bangladesh's reformed calendar always uses April 14.

**Edge case (rare):** According to some calendrical scholars, if the zodiac sign change occurs within approximately ±24 minutes of midnight (between 11:36 PM and 12:24 AM in temporal time), special rules apply depending on the month and weekday. This is an extremely rare edge case. For practical implementation, the simplified sunrise-to-midnight / after-midnight rule is sufficient and matches what Bisuddha Siddhanta Panjika actually publishes.

### 3.4 Day Count Within a Solar Month

Once the month start date is determined:

1. **Day 1** = the Gregorian day determined by the sankranti rule above
2. **Day 2** = the next Gregorian day
3. Continue counting until the **next sankranti** occurs
4. The next sankranti triggers the start of the next month

Solar months can be **29, 30, 31, or 32 days** long, depending on how long the Sun takes to traverse the 30° segment. This varies from year to year due to Earth's elliptical orbit (Kepler's second law — Sun moves faster near perihelion in January, slower near aphelion in July).

**Typical month lengths (approximate):**
- Boishakh–Bhadro: 31 days each (Sun moving slowly, near aphelion)
- Ashshin–Choitro: 29–30 days each (Sun moving faster, near perihelion)
- Falgun: 30 days (31 in Gregorian leap years)

### 3.5 The Day Begins at Sunrise

In the Bengali calendar, **the day begins at sunrise**, not at midnight. This means:

- "Ashshin 16" refers to the period from **sunrise on Gregorian Oct 3** to **sunrise on Gregorian Oct 4**
- If an event occurs at 2:00 AM on October 4 (before sunrise), it still belongs to the **previous Bengali day** (Ashshin 16, not Ashshin 17)
- All tithi/nakshatra determinations use the tithi prevailing at **sunrise** of that day (Udaya Tithi rule)

**Sunrise computation for the Bengali calendar (Bisuddha Siddhanta):**
- Compute astronomical sunrise for the observer's location
- Use **geometric sunrise**: center of the Sun's disc at the horizon
- Apply standard refraction correction (≈34') and solar semi-diameter (≈16')
- Total depression angle for sunrise computation: approximately 50' (arcminutes)
  - Some traditional sources use 47' (Lahiri's value: 31' refraction + 16' semi-diameter)
  - For practical purposes, either value gives results within 1–2 minutes
- The computed sunrise time must be in **local time** (IST for Kolkata)

### 3.6 Bangabda Era

The Bengali calendar era is called **Bangabda** (বঙ্গাব্দ), abbreviated as "BS" (Bangla San/Sal/Sombat).

**Year calculation:**
```
Bangabda Year = Gregorian Year − 593
```

**But the year increments at Pohela Boishakh, not January 1:**

| Gregorian Date | Bangabda Year |
|---|---|
| January 1 – April 14 (before Pohela Boishakh) | Gregorian − 594 |
| April 15 – December 31 (after Pohela Boishakh) | Gregorian − 593 |

**Example for 2026:**
- January 1 – April 14, 2026 → Bangabda **1432**
- April 15, 2026 (Pohela Boishakh) → Bangabda **1433** begins
- April 15 – December 31, 2026 → Bangabda **1433**

**Zero year:** 593 CE (the year from which the era is counted backward). After Pohela Boishakh, the Bangabda year is 593 less than the Gregorian year. Before Pohela Boishakh, it is 594 less.

### 3.7 Year Start (Pohela Boishakh)

The Bengali new year (**Pohela Boishakh** / **Poila Boishakh**) is:
- The day determined by applying the Bengal sankranti rule to the **Mesha sankranti** (Sun enters sidereal Aries, 0°)
- In the Bisuddha Siddhanta system, this typically falls on **April 14 or April 15**
- In the Bangladesh reformed calendar, it is always **April 14** (fixed by reform)
- For the West Bengal / Bisuddha Siddhanta implementation, it should be **computed astronomically** using the sankranti rule, not fixed

---

## 4. Lunar Tithi Layer — Complete Rules

### 4.1 Tithi Computation

The tithi layer is **identical to your existing Hindu panchang engine** if it uses Drik Ganita. No changes needed to the core computation.

**Tithi formula:**
```
tithi = floor((Moon_sidereal_longitude − Sun_sidereal_longitude) / 12) + 1
```
- Result is 1-based: 1 = Pratipada, ... 15 = Purnima, 16 = Pratipada (Krishna), ... 30 = Amavasya
- Or equivalently: tithi_index (1–15) + paksha (Shukla/Krishna)

**Udaya Tithi rule:** The tithi prevailing at **sunrise** determines the day's tithi. If a tithi transition occurs between two sunrises, the day is labeled with the tithi that was present at sunrise.

**Kshaya Tithi handling:** If a tithi is skipped (never prevails at sunrise because it begins and ends between two consecutive sunrises), the same rules apply as in your Hindu calendar implementation. See your existing Kshaya Tithi handling documentation.

### 4.2 Nakshatra, Yoga, Karana

Same Drik Ganita computation as your Hindu panchang:
- **Nakshatra:** `floor(Moon_sidereal_longitude / (360/27)) + 1` → one of 27 nakshatras
- **Yoga:** `floor((Sun_sidereal_longitude + Moon_sidereal_longitude) / (360/27)) + 1` → one of 27 yogas
- **Karana:** Derived from tithi (each tithi has 2 karanas) — same as Hindu panchang

### 4.3 Lunar Month Naming (for Festival Determination)

The Bengali Panjika uses the **same lunar month names** as the Hindu calendar for festival determination. The lunar month is named after the solar month in which the lunar month's full moon (Purnima) or new moon (Amavasya) falls.

**In the Bengali tradition, the Purnimanta system is used** for naming lunar months in the context of festivals:

- A lunar month is named after the solar month in which its **Purnima (full moon)** falls
- The month begins with Krishna Paksha (waning fortnight) and ends with Shukla Paksha (waxing fortnight)
- For Krishna Paksha festivals, the Purnimanta month name is one month ahead of the Amanta month name (same as your existing `masa`/`masaDisplay` split)

**However**, since the Bengali Panjika displays both the solar month date AND the lunar tithi, the lunar month name is often shown in its Amanta form alongside the tithi (e.g., "Ashwin Krishna Navami" where Ashwin is the Amanta lunar month). The Purnimanta convention is used mainly in traditional discourse, not always in the printed panjika.

**Recommendation:** Use the same Amanta/Purnimanta handling your app already implements. The `masa` field stores the Amanta month name, `masaDisplay` stores the Purnimanta name. This works identically for the Bengali calendar.

### 4.4 Adhika Masa (Intercalary Month)

The Bengali calendar has **no Adhika Masa in the solar month layer** (solar months are fixed to sankrantis — each month always exists). However, the **lunar tithi layer** has Adhika Masa, determined by the same rules as the Hindu calendar:

- If a lunar month (new moon to new moon) contains **no sankranti**, it is an **Adhika Masa** (extra month)
- The Adhika Masa takes the name of the following month with the prefix "Adhika"
- The next lunar month (which contains the sankranti) is the "Nija" (real) month
- Adhika Masa occurs approximately every 2.7 years (32.5 solar months)
- In 2026, there is an **Adhika Jyeshtha** (May 17 – June 15)

**This is identical to your existing Hindu calendar implementation.** No changes needed.

### 4.5 Festival Date Determination

Festivals are determined by the **lunar tithi**, not by the solar date. The same festival-to-tithi mapping table used in your Hindu calendar applies. Key Bengali festivals and their tithis:

| Festival | Tithi | Notes |
|---|---|---|
| Durga Puja — Mahalaya | Ashwin Krishna Amavasya (Pitr Paksha Amavasya) | |
| Durga Puja — Maha Saptami | Ashwin Shukla Saptami | |
| Durga Puja — Maha Ashtami | Ashwin Shukla Ashtami | |
| Durga Puja — Maha Navami | Ashwin Shukla Navami | |
| Durga Puja — Vijaya Dashami | Ashwin Shukla Dashami | |
| Lakshmi Puja (Bengal) | Ashwin Krishna Purnima (Kojagari Purnima) | Note: Bengal celebrates Lakshmi Puja on Purnima, not Diwali |
| Kali Puja / Diwali | Kartika Krishna Chaturdashi / Amavasya | |
| Bhai Phonta | Kartika Krishna Dwitiya | (Bhai Dooj in North India) |
| Jagaddhatri Puja | Kartika Shukla Navami | |
| Saraswati Puja | Magha Shukla Panchami | (Vasant Panchami) |
| Dol Purnima / Holi | Phalguna Purnima | |
| Rath Yatra | Ashadha Shukla Dwitiya | |
| Janmashtami | Bhadrapada Krishna Ashtami | |
| Raksha Bandhan | Shravana Purnima | |
| Jhulan Yatra | Shravana Shukla Ekadashi to Purnima | |
| Manasa Puja | Shravana Krishna Panchami (Saptami in some traditions) | |
| Chaitra Durga Puja (Basanti) | Chaitra Shukla Saptami to Navami | |

**Bengali-specific note:** Lakshmi Puja in Bengal falls on **Ashwin Purnima** (Kojagari Purnima / Sharad Purnima), NOT on Amavasya (Diwali night) as in North India. This is a key regional difference.

---

## 5. Data Model — JSON Schema for Bengali Calendar Day

Here is the recommended JSON structure for each day in the Bengali calendar:

```json
{
  "gregorianDate": "2026-10-03",
  "weekday": "Saturday",
  "bengali": {
    "solarDate": {
      "day": 16,
      "month": "Ashshin",
      "monthIndex": 6,
      "year": 1433,
      "era": "Bangabda",
      "season": "Sharat (Autumn)",
      "monthStart": "2026-09-17",
      "monthEnd": "2026-10-16",
      "daysInMonth": 30
    },
    "sankranti": {
      "name": "Tula Sankranti",
      "moment": "2026-10-17T08:23:00+05:30",
      "nextSankranti": "Vrishchika Sankranti",
      "nextSankrantiMoment": "2026-11-16T19:45:00+05:30"
    }
  },
  "panchanga": {
    "tithi": {
      "index": 23,
      "name": "Navami",
      "paksha": "Krishna",
      "masa": "Ashwin",
      "masaDisplay": "Ashwin",
      "startTime": "2026-10-02T14:35:00+05:30",
      "endTime": "2026-10-03T12:10:00+05:30",
      "isKshaya": false
    },
    "nakshatra": {
      "name": "Anuradha",
      "startTime": "2026-10-03T03:22:00+05:30",
      "endTime": "2026-10-04T05:15:00+05:30"
    },
    "yoga": {
      "name": "Sukarma",
      "startTime": "...",
      "endTime": "..."
    },
    "karana": {
      "name": "Vanija",
      "startTime": "...",
      "endTime": "..."
    },
    "sunrise": "2026-10-03T05:28:00+05:30",
    "sunset": "2026-10-03T17:18:00+05:30",
    "moonrise": "...",
    "moonset": "..."
  },
  "festivals": [
    {
      "name": "Durga Puja — Maha Navami",
      "type": "major",
      "tithi": "Ashwin Krishna Navami"
    }
  ]
}
```

### Field explanations:

**`bengali.solarDate`:**
- `day`: Day number within the solar month (1-based)
- `month`: Bengali month name (transliterated: "Ashshin")
- `monthIndex`: 1-based month number (1 = Boishakh, 12 = Choitro)
- `year`: Bangabda year
- `era`: Always "Bangabda"
- `season`: The traditional Bengali 6-season cycle (see Section 6)
- `monthStart`/`monthEnd`: Gregorian dates of the first and last day of this solar month
- `daysInMonth`: Total number of days in this solar month (29–32)

**`bengali.sankranti`:**
- The sankranti that starts the current solar month (not the next one)
- `moment`: Exact IST timestamp of the Sun's zodiac entry
- `nextSankranti`: Name and moment of the upcoming sankranti (starts the next month)

**`panchanga.tithi`:**
- Same structure as your existing Hindu calendar JSON
- `masa`: Amanta lunar month name (computation anchor)
- `masaDisplay`: Purnimanta lunar month name (presentation layer) — same logic as your existing implementation
- Timestamps are in IST

---

## 6. Bengali Seasons (Ritu)

The Bengali calendar divides the year into **6 seasons** (ritu), each spanning 2 solar months:

| # | Season (English) | Season (Bengali) | Months | Approximate Period |
|---|---|---|---|---|
| 1 | Summer | গ্রীষ্ম (Grishsho) | Boishakh, Joishtho | Mid-April – Mid-June |
| 2 | Monsoon/Rainy | বর্ষা (Bôrsha) | Asharh, Shrabon | Mid-June – Mid-August |
| 3 | Autumn | শরৎ (Shôrôd) | Bhadro, Ashshin | Mid-August – Mid-October |
| 4 | Late Autumn/Dry | হেমন্ত (Hemonto) | Kartik, Ogrohayon | Mid-October – Mid-December |
| 5 | Winter | শীত (Sheet) | Poush, Magh | Mid-December – Mid-February |
| 6 | Spring | বসন্ত (Bôsôntô) | Falgun, Choitro | Mid-February – Mid-April |

---

## 7. Weekdays

The Bengali calendar uses a 7-day week, same as the Gregorian. Day names are derived from the Navagraha (nine celestial bodies):

| Day (English) | Bengali Name | Celestial Body |
|---|---|---|
| Sunday | রবিবার (Rôbibar) | Sun (Ravi) |
| Monday | সোমবার (Shombar) | Moon (Soma) |
| Tuesday | মঙ্গলবার (Mônggôlbar) | Mars (Mangala) |
| Wednesday | বুধবার (Budhbar) | Mercury (Budha) |
| Thursday | বৃহস্পতিবার (Brihôspôtibar) | Jupiter (Brihaspati) |
| Friday | শুক্রবার (Shukrôbar) | Venus (Shukra) |
| Saturday | শনিবার (Shônibar) | Saturn (Shani) |

**Week starts on Sunday** (not Monday).

---

## 8. Implementation Algorithm — Step by Step

### Step 1: Compute Sankranti Dates for the Year

For each of the 12 zodiac boundaries (0°, 30°, 60°, ..., 330°):

```
For each boundary B in [0, 30, 60, 90, 120, 150, 180, 210, 240, 270, 300, 330]:
    1. Find the UTC moment when Sun's sidereal longitude = B
       - Use binary search on Sun's geocentric sidereal longitude
       - Sidereal longitude = Tropical longitude - Lahiri Ayanamsa
       - Precision target: ±30 seconds
    2. Convert to IST (UTC + 5:30)
    3. Determine the Gregorian date D on which this sankranti moment falls
       (Note: if the moment is between 00:00 and sunrise, it belongs to the
        previous civil day for sunrise purposes — see Step 2)
    4. Compute sunrise time for date D at observer's location
    5. Determine midnight following sunrise of date D:
       - This is 00:00 (midnight) of date D+1 in local time
    6. Apply the Bengal sankranti rule:
       - If sankranti moment is between [sunrise of D, midnight end of D]:
           month_start_date = D + 1
       - If sankranti moment is after midnight (i.e., between 00:00 and sunrise of D+1):
           month_start_date = D + 2
       - If sankranti moment is before sunrise of D (i.e., it fell in the night of D-1):
           month_start_date = D (the sankranti belongs to D's daytime period)
           (This case is equivalent to "sankranti occurred before sunrise → same day)
    7. Record: {sankranti_moment, month_name, month_start_date}
```

### Step 2: Build the Solar Month Calendar

```
For each of the 12 solar months:
    1. month_start = date from Step 1
    2. month_end = (next month's start date) - 1 day
    3. day_count = month_end - month_start + 1
    4. Assign sequential day numbers: day 1, 2, 3, ..., day_count
    5. Determine Bangabda year:
       - If month_index == 1 (Boishakh): new Bangabda year starts
       - Bangabda year = (Gregorian year of month_start) - 593
         (after Pohela Boishakh in April)
       - For months Jan-Apr (before Boishakh): Bangabda = Gregorian - 594
```

### Step 3: Compute Panchanga for Each Day

For each day in the solar month calendar:

```
1. Compute sunrise time for this date at observer's location
   - Use geometric sunrise (center of Sun at horizon, with refraction)
   - Result in IST

2. Compute the tithi at sunrise:
   - Get Sun's sidereal longitude at sunrise
   - Get Moon's sidereal longitude at sunrise
   - tithi = floor((Moon - Sun) / 12) + 1
   - Determine paksha (Shukla if tithi 1-15, Krishna if tithi 16-30)
   - Find tithi start and end times (binary search for tithi transitions)

3. Compute nakshatra at sunrise (same as Hindu panchang)
4. Compute yoga at sunrise (same as Hindu panchang)
5. Compute karana at sunrise (same as Hindu panchang)
6. Compute moonrise/moonset (same as Hindu panchang)
7. Determine lunar month name (Amanta masa, Purnimanta masaDisplay)
   - Same logic as existing Hindu calendar implementation
8. Check for festivals matching this tithi
```

### Step 4: Handle Edge Cases

**Kshaya Tithi (skipped tithi):**
- If a tithi begins and ends between two consecutive sunrises, it never prevails at sunrise
- It gets "skipped" in the daily display
- Same handling as your existing Hindu calendar Kshaya Tithi fix
- Consider displaying two tithis: "Ashtami → Navami (transition time)"

**Adhika Masa:**
- The solar month layer is unaffected (solar months always exist)
- The lunar tithi layer shows "Adhika" prefix on the masa name when applicable
- Same detection logic as Hindu calendar: lunar month with no sankranti = Adhika

**Year boundary:**
- Bangabda year changes at Boishakh 1 (mid-April), NOT at January 1
- Days in January–April before Pohela Boishakh belong to the PREVIOUS Bangabda year
- This is analogous to how Vikram/Shaka year changes at Chaitra Shukla Pratipada

---

## 9. Differences from Your Existing Hindu Calendar Implementation

| Aspect | Hindu Calendar (existing) | Bengali Calendar (to implement) |
|---|---|---|
| Primary month type | Lunar (Amanta/Purnimanta) | Solar (sankranti-based) |
| Month start | Lunar (new moon / full moon) | Solar (sankranti + Bengal rule) |
| Month length | 29–30 days (lunar) | 29–32 days (solar, variable) |
| Year start | Chaitra Shukla Pratipada (~March) | Boishakh 1 (~April 14/15) |
| Era | Vikram (57 BCE) or Shaka (78 CE) | Bangabda (593 CE) |
| Era formula | Vikram = Greg + 57; Shaka = Greg − 78 | Bangabda = Greg − 593 (after Apr 14/15) |
| Adhika Masa | In lunar months | In lunar tithi layer (NOT in solar months) |
| Festival determination | Tithi at sunrise | Tithi at sunrise (SAME) |
| Tithi computation | Drik Ganita | Drik Ganita (SAME) |
| Nakshatra/Yoga/Karana | Drik Ganita | Drik Ganita (SAME) |
| Sunrise computation | Same | Same (geometric sunrise with refraction) |
| Day start | Sunrise | Sunrise (SAME) |
| Calendar output format | Lunar month + tithi | Solar month + day number AND tithi |

**Summary:** Your existing Drik Ganita engine computes tithis, nakshatras, yogas, and karanas correctly for the Bisuddha Siddhanta school. What you need to ADD is:
1. Solar month computation with the Bengal sankranti rule
2. Bangabda era numbering
3. Bengali month/season names
4. The dual-layer display (solar date + lunar tithi)

---

## 10. Verification Against References

### 10.1 Reference Sources for Cross-Checking

| Source | URL / Reference | What to Check |
|---|---|---|
| Bisuddha Siddhanta Panjika | Published annually from Kolkata | Authoritative for festival dates and tithi timings |
| Drik Panchang (Bengali Panjika) | drikpanchang.com → Bengali Panjika section | Online cross-reference; uses Drik Ganita |
| ProKerala Bengali Panjika | prokerala.com/astrology/bengali-panjika/ | Shows both Surya Siddhanta and Bisuddha Siddhanta side by side |
| Government of India Rashtriya Panchang | Published by Positional Astronomy Centre, Kolkata | Should match Bisuddha Siddhanta (same calculation method) |
| Hindu Calculator Bengali Panjika | hinducalculator.com/bengali-panjika/ | Shows solar month + tithi + festivals |

### 10.2 Key Verification Points

1. **Pohela Boishakh date:** Should be April 14 or 15 (computed, not fixed). Cross-check against Drik Panchang's Mesha Sankranti page for West Bengal.

2. **Durga Puja dates:** The tithi timings (Saptami/Ashtami/Navami start and end times) should match the Bisuddha Siddhanta Panjika, NOT the Gupta Press Panjika. If your engine uses Drik Ganita, it will match Bisuddha Siddhanta by default.

3. **Sankranti moments:** Should match Drik Panchang's sankranti timings (both use Lahiri ayanamsa + modern ephemeris).

4. **Sunrise/sunset:** Should match published Kolkata sunrise/sunset times. Kolkata is at 22.5891°N, 88.3885°E.

5. **Adhika Masa detection:** In 2026, Adhika Jyeshtha occurs (May 17 – June 15). Verify your lunar tithi layer correctly identifies this.

### 10.3 Known Differences: Bisuddha Siddhanta vs Gupta Press (Surya Siddhanta)

For verification, be aware that the two schools can differ by up to 1 day on festival dates and by several hours on tithi transition times:

| Element | Bisuddha Siddhanta (Drik) | Gupta Press (Surya Siddhanta) | Typical Difference |
|---|---|---|---|
| Sunrise | ~5:18 AM (Aug, Kolkata) | ~5:30 AM | +12 min |
| Tithi transition | Astronomically precise | Drifted ~5–6 hours | 1h 15min – 2h 35min |
| Festival date | Matches Govt of India | Sometimes 1 day different | 0–1 day |

Your implementation should match the **Bisuddha Siddhanta column**, not the Gupta Press column.

---

## 11. Summary — Implementation Checklist

- [ ] Add solar month computation module (sankranti detection + Bengal rule)
- [ ] Add Lahiri ayanamsa computation (if not already present)
- [ ] Add Bangabda era numbering (Gregorian − 593/594 based on Pohela Boishakh)
- [ ] Add Bengali month names (12 solar months: Boishakh → Choitro)
- [ ] Add Bengali season names (6 ritus: Grishsho → Bôsôntô)
- [ ] Add Bengali weekday names
- [ ] Implement the Bengal sankranti rule:
  - Sunrise to midnight → next day
  - After midnight → day after next
- [ ] Ensure sunrise computation uses geometric sunrise with refraction (center of Sun at horizon)
- [ ] Ensure tithi/nakshatra/yoga/karana engine uses Drik Ganita (already done if using Skyfield/Swiss Ephemeris)
- [ ] Add dual-layer output: solar date + lunar tithi on each day
- [ ] Add festival mapping with Bengali-specific conventions (e.g., Lakshmi Puja on Purnima, not Diwali)
- [ ] Handle Adhika Masa in the lunar layer (same as Hindu calendar)
- [ ] Handle Kshaya Tithi (same as Hindu calendar)
- [ ] Handle year boundary (Bangabda year changes at Boishakh 1, not Jan 1)
- [ ] Cross-verify Pohela Boishakh date and Durga Puja dates against Bisuddha Siddhanta Panjika
- [ ] Add JSON output schema per Section 5

---

## Appendix A: Sankranti → Month Mapping Quick Reference

| Sankranti Name | Zodiac Entry | Longitude | Bengali Month Starts |
|---|---|---|---|
| Mesha Sankranti | Aries | 0° | Boishakh (month 1, new year) |
| Vrishabha Sankranti | Taurus | 30° | Joishtho (month 2) |
| Mithuna Sankranti | Gemini | 60° | Asharh (month 3) |
| Karkataka Sankranti | Cancer | 90° | Shrabon (month 4) |
| Simha Sankranti | Leo | 120° | Bhadro (month 5) |
| Kanya Sankranti | Virgo | 150° | Ashshin (month 6) |
| Tula Sankranti | Libra | 180° | Kartik (month 7) |
| Vrishchika Sankranti | Scorpio | 210° | Ogrohayon (month 8) |
| Dhanu Sankranti | Sagittarius | 240° | Poush (month 9) |
| Makara Sankranti | Capricorn | 270° | Magh (month 10) |
| Kumbha Sankranti | Aquarius | 300° | Falgun (month 11) |
| Meena Sankranti | Pisces | 330° | Choitro (month 12) |

## Appendix B: Reference Location

For traditional Bengali Panjika calculations, the reference location is **Kolkata**:

- **Latitude:** 22°35' N (22.5833°N) — traditional; 22.5891°N — modern
- **Longitude:** 88°22.6' E (88.3767°E) — traditional; 88.3885°E — modern
- **Timezone:** IST (UTC + 5:30)

The Bisuddha Siddhanta Panjika software documentation specifies **22°35'N, 88°22.6'E** as the reference coordinates for Bengal calculations. However, for a modern app, it is recommended to use the user's actual location for sunrise/sunset computations while keeping Kolkata as the default.

## Appendix C: Ayanamsa Details

**Lahiri (Chitrapaksha) Ayanamsa:**
- Zero epoch: 285 CE (when the ayanamsa was exactly 0°)
- Reference star: Spica (Chitra) fixed at exactly 180° sidereal longitude
- Annual precession rate: ~50.2388475 arcseconds per year
- Current value (2026): approximately 24.2°
- Formula (simplified): `Ayanamsa = 23.85306° + 1.39722° × T + 0.00030861° × T²`
  where T = (year − 285) / 100
- More precise computation uses the full precession model (Vondrák et al. or IAU 2006)

**This is the same ayanamsa your existing Hindu panchang engine should already use** (it's the standard for Drik Ganita and the Government of India's Rashtriya Panchang).

## Appendix D: Ephemeris Requirements

For Bisuddha Siddhanta-level accuracy:

| Requirement | Specification |
|---|---|
| Solar ephemeris | JPL DE421/DE430/DE406, or Swiss Ephemeris, or Meeus algorithms (Ch. 25) |
| Lunar ephemeris | JPL DE421/DE430/DE406, or Chapront ELP-2000/82, or Meeus (Ch. 47) |
| Ayanamsa | Lahiri (Chitrapaksha) |
| ΔT | Morrison/Stephenson, or Espenak's polynomial |
| Precision target | Sun: ±0.01° (±36 arcsec); Moon: ±0.003° (±10 arcsec) |
| Timing precision | ±1–3 minutes for tithi/nakshatra transitions |
| Sunrise precision | ±1–2 minutes |

If using **Skyfield** (as your existing verify_panchang.py does), you already meet these requirements with JPL DE421.bsp.

## Appendix E: Bangladesh vs West Bengal Calendar Differences

| Feature | West Bengal (Bisuddha Siddhanta) | Bangladesh (Reformed 1966/1987) |
|---|---|---|
| Pohela Boishakh | April 14 or 15 (computed) | Always April 14 (fixed) |
| Month lengths | Variable (29–32 days, astronomically computed) | Fixed (Boishakh–Bhadro: 31, Ashshin: 31, rest: 30; Falgun +1 in leap years) |
| Calculation | Drik Ganita (astronomical) | Fixed month lengths matching Gregorian |
| Authority | Bisuddha Siddhanta Panjika | Bangla Academy reform |
| Sankranti rule | Bengal rule (sunrise-to-midnight) | N/A (months are fixed) |

**This guide implements the West Bengal / Bisuddha Siddhanta version** (astronomically computed, not fixed month lengths).

---

*Document compiled from: Wikipedia (Bengali calendar, Vishuddha Siddhanta Panjika, Panjika), Drik Panchang, ProKerala Bengali Panjika, Bisuddha Siddhanta Panjika software documentation, Calendars of India (arXiv:1007.0062), Indian Calendrical Calculations (TAU), GetBengal, Scroll.in, and Times of India sources.*
