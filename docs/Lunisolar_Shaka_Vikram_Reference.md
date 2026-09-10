# Lunisolar Shaka & Vikram Samvat Calendar — Complete Technical Reference

## Purpose

This document provides every technical detail an AI agent or developer needs to correctly implement, fix, and verify a Hindu lunisolar calendar engine. It covers both the Vikram Samvat and Shaka Samvat era systems in their lunisolar (panchang) form — not the official solar Shaka used by the Government of India.

---

## 1. What "Lunisolar" Means

A lunisolar calendar uses BOTH the Moon and the Sun:

- **Lunar component:** Months are defined by the Moon's phase cycle (tithis). A tithi = the time the Moon takes to move 12° relative to the Sun (~19 to ~26 hours, not a fixed 24-hour day).
- **Solar component:** The year is anchored to the Sun's cycle (the tropical or sidereal year ~365.25 days). Since 12 lunar months only total ~354 days, an intercalary month (Adhika Masa) is inserted approximately every 2.7 years to keep the lunar calendar aligned with the solar year.

This is different from:
- A purely lunar calendar (like the Islamic calendar) — which drifts ~11 days per year and does not correct
- A purely solar calendar (like the Gregorian or the official Shaka national calendar) — which uses fixed month lengths and ignores the Moon

---

## 2. The Tithi System

### 2.1 Definition

A tithi is the time it takes for the Moon-Sun longitudinal difference to increase by exactly 12°.

```
tithi = ceil((Moon_longitude - Sun_longitude) / 12°)
```

The full cycle is 360°, divided into 30 tithis:
- Shukla Paksha (waxing): tithi 1 (Pratipada) to tithi 15 (Purnima) — Moon-Sun diff goes from 0° to 180°
- Krishna Paksha (waning): tithi 1 (Pratipada) to tithi 15 (Amavasya) — Moon-Sun diff goes from 180° to 360°(=0°)

### 2.2 Tithi Indexing

There are two conventions. The **standard panchang convention is 1-based**:

| Index (1-based) | Paksha | Tithi Name |
|---|---|---|
| 1 | Shukla | Pratipada |
| 2 | Shukla | Dwitiya |
| 3 | Shukla | Tritiya |
| 4 | Shukla | Chaturthi |
| 5 | Shukla | Panchami |
| 6 | Shukla | Shashthi |
| 7 | Shukla | Saptami |
| 8 | Shukla | Ashtami |
| 9 | Shukla | Navami |
| 10 | Shukla | Dashami |
| 11 | Shukla | Ekadashi |
| 12 | Shukla | Dwadashi |
| 13 | Shukla | Trayodashi |
| 14 | Shukla | Chaturdashi |
| 15 | Shukla | Purnima |
| 16 | Krishna | Pratipada |
| 17 | Krishna | Dwitiya |
| 18 | Krishna | Tritiya |
| 19 | Krishna | Chaturthi |
| 20 | Krishna | Panchami |
| 21 | Krishna | Shashthi |
| 22 | Krishna | Saptami |
| 23 | Krishna | Ashtami |
| 24 | Krishna | Navami |
| 25 | Krishna | Dashami |
| 26 | Krishna | Ekadashi |
| 27 | Krishna | Dwadashi |
| 28 | Krishna | Trayodashi |
| 29 | Krishna | Chaturdashi |
| 30 | Krishna | Amavasya |

**0-based alternative (some software uses this):** Same sequence but starts at 0 instead of 1. Index 0 = Shukla Pratipada, index 14 = Purnima, index 15 = Krishna Pratipada, index 29 = Amavasya.

**CRITICAL:** Always specify which indexing convention your app uses. If the app uses 0-based in the daily view but 1-based in the export, there will be an off-by-one error. Standardize on 1-based to match Drik Panchang, ProKerala, Vidhyamitra, and all major panchang sources.

### 2.3 Tithi Length

A tithi is NOT a fixed 24-hour day. It can range from approximately 19 to 26 hours. This means:
- A single tithi can span parts of two Gregorian dates
- Two tithis can fall on the same Gregorian date
- The tithi prevailing at sunrise (Udaya Tithi) determines the festival day

### 2.4 Tithi Names (both pakshas)

Shukla (waxing): Pratipada, Dwitiya, Tritiya, Chaturthi, Panchami, Shashthi, Saptami, Ashtami, Navami, Dashami, Ekadashi, Dwadashi, Trayodashi, Chaturdashi, Purnima

Krishna (waning): Pratipada, Dwitiya, Tritiya, Chaturthi, Panchami, Shashthi, Saptami, Ashtami, Navami, Dashami, Ekadashi, Dwadashi, Trayodashi, Chaturdashi, Amavasya

---

## 3. The Month (Masa)

### 3.1 Lunar Month Definition

A lunar month is defined by one full Moon-Sun cycle (one new moon to the next, or one full moon to the next):

- **Amanta system:** Month starts at Shukla Pratipada (day after Amavasya/new moon) and ends at the next Amavasya. Month = Amavasya to Amavasya.
- **Purnimanta system:** Month starts at Krishna Pratipada (day after Purnima/full moon) and ends at the next Purnima. Month = Purnima to Purnima.

### 3.2 Month Length

Each lunar month is either **29 or 30 days** (averaging ~29.53 days). The exact length varies month to month and year to year, determined by the actual lunar astronomy. There is no fixed day count.

### 3.3 The 12 Lunar Months (in order)

| # | Month Name | Approximate Gregorian Period |
|---|---|---|
| 1 | Chaitra | March – April |
| 2 | Vaishakha | April – May |
| 3 | Jyeshtha | May – June |
| 4 | Ashadha | June – July |
| 5 | Shravana | July – August |
| 6 | Bhadrapada | August – September |
| 7 | Ashwin | September – October |
| 8 | Kartika | October – November |
| 9 | Margashirsha | November – December |
| 10 | Pausha | December – January |
| 11 | Magha | January – February |
| 12 | Phalguna | February – March |

### 3.4 Adhika Masa (Intercalary Month)

- 12 lunar months = ~354 days
- 1 solar year = ~365.25 days
- Mismatch = ~11 days per year
- Correction: An **Adhika Masa** (extra month) is inserted approximately every 32.5 lunar months (~2.7 years)
- When a lunar month name repeats, the first occurrence is the "pure" (Nija) month and the second is the "Adhika" (extra) month
- A year with Adhika Masa has 13 months (~384 days)
- The Adhika month is determined by which lunar month does NOT contain a solar sankranti (Sun's entry into a new zodiac sign). That month repeats.

### 3.5 Kshaya Masa (Omitted Month)

- Rare phenomenon where a lunar month is omitted because no sankranti falls within it
- Always paired with two Adhika Masas in the same year
- Occurs once every 19 to 141 years
- Must be handled in historical date conversions

### 3.6 Which Month a Tithi Belongs To

The determination of which lunar month a given tithi belongs to is based on the **solar sign at the preceding new moon** (Amanta) or **full moon** (Purnimanta):

- Find the new moon (amavasya) that precedes the current Shukla Paksha
- Determine the Sun's zodiac sign (rashi) at that new moon
- The rashis map to month names (Mesha/Aries → Vaishakha, Vrishabha/Taurus → Jyeshtha, etc.)
- That mapping determines the Amanta month name
- For Purnimanta, the Krishna Paksha belongs to the NEXT month (see section 5)

---

## 4. Amanta vs Purnimanta Month Systems

### 4.1 Core Difference

These are two ways of LABELING the same lunar cycle. The tithis, pakshas, and Gregorian dates are identical. Only the month NAME attached to Krishna Paksha differs.

| Property | Amanta | Purnimanta |
|---|---|---|
| Month ends on | Amavasya (new moon) | Purnima (full moon) |
| Month starts with | Shukla Pratipada | Krishna Pratipada |
| Fortnight order | Shukla → Krishna | Krishna → Shukla |
| Krishna Paksha belongs to | Current month (ending at new moon) | Next month (started at previous full moon) |
| Regions | South & West India | North India |

### 4.2 The Shift Rule

For Krishna Paksha tithis only:

```
Purnimanta masa = next month after Amanta masa
```

| Amanta masa | Purnimanta masa (for Krishna Paksha) |
|---|---|
| Chaitra | Vaishakha |
| Vaishakha | Jyeshtha |
| Jyeshtha | Ashadha |
| Ashadha | Shravana |
| Shravana | Bhadrapada |
| Bhadrapada | Ashwin |
| Ashwin | Kartika |
| Kartika | Margashirsha |
| Margashirsha | Pausha |
| Pausha | Magha |
| Magha | Phalguna |
| Phalguna | Chaitra |

**Shukla Paksha tithis carry the SAME month name in both systems. No shift needed.**

### 4.3 Design Pattern for Apps

Store the Amanta masa as the base computation field (`masa`), and derive the Purnimanta masa as a display field (`masaDisplay`):

```python
if monthSystem == "purnimanta" and paksha == "Krishna":
    masaDisplay = next_month(masa)  # shift forward by one
else:
    masaDisplay = masa  # same for Shukla Paksha or Amanta system
```

---

## 5. The Two Era Systems

### 5.1 Vikram Samvat (VS)

| Property | Value |
|---|---|
| Epoch | 57 BCE |
| Offset from Gregorian | +57 (after New Year) or +56 (before New Year) |
| Calendar type | Always lunisolar |
| New Year | Chaitra Shukla Pratipada (lunar, varies Mar 22 – Apr 17) |
| Regions | North India, West India, Nepal |
| Common uses | Religious almanacs, wedding invitations, festivals, sankalpa |

### 5.2 Shaka Samvat (Lunisolar version)

| Property | Value |
|---|---|
| Epoch | 78 CE |
| Offset from Gregorian | −78 (after New Year) or −79 (before New Year) |
| Calendar type | Lunisolar (traditional/panchang) OR Solar (official government) |
| New Year (lunisolar) | Chaitra Shukla Pratipada (same day as Vikram — varies) |
| New Year (official solar) | March 22 fixed (March 21 in leap years) |
| Regions | South & West India |
| Common uses | Government gazettes (official solar), religious panchangs (lunisolar), sankalpa in South India |

### 5.3 The 135-Year Relationship

```
Vikram = Shaka + 135
Shaka = Vikram − 135
```

For 2026 CE (after Chaitra Pratipada, March 19):
- Vikram Samvat = 2026 + 57 = **2083**
- Shaka Samvat = 2026 − 78 = **1948**
- Check: 2083 − 1948 = 135 ✓

### 5.4 New Year Boundary

Both lunisolar eras share the same New Year: **Chaitra Shukla Pratipada**.

This is NOT a fixed Gregorian date. It varies year to year (March 22 – April 17) because it depends on when the first tithi after the spring amavasya occurs.

For 2026: Chaitra Shukla Pratipada = **March 19** (Pratipada began at 6:52 AM IST).

```
if date >= Chaitra_Shukla_Pratipada:
    Vikram = Gregorian_year + 57
    Shaka = Gregorian_year - 78
else:
    Vikram = Gregorian_year + 56
    Shaka = Gregorian_year - 79
```

**IMPORTANT:** The Chaitra Pratipada date must be computed astronomically each year. Do NOT hardcode March 19 or March 22 — it changes every year.

### 5.5 Regional New Year Variations (Vikram Samvat)

Some regions start the Vikram year on a different day:

| Region | New Year starts | Gregorian timing |
|---|---|---|
| Most of North India | Chaitra Shukla Pratipada | March–April (lunar, varies) |
| Gujarat | Kartik Shukla Pratipada (after Diwali) | October–November |
| Nepal (solar Bikram Sambat) | Baisakh 1 | ~April 13–15 (solar) |

If your app supports multiple regions, store the New Year convention as a config option, not a hardcoded assumption.

### 5.6 Official Solar Shaka vs Lunisolar Shaka

| Property | Official Solar Shaka | Lunisolar Shaka |
|---|---|---|
| New Year | March 22 (fixed) | Chaitra Shukla Pratipada (varies) |
| Month lengths | Fixed 30/31 days | Variable 29/30 days |
| Intercalary | None | Adhika Masa |
| Leap year | Follows Gregorian | Based on sankranti timing |
| Used for | Government, Gazette, AIR | Panchangs, festivals, rituals |
| Year for Sep 5, 2026 | 1948 | 1948 (same because Sep 5 is well after both New Years) |
| Year for Mar 20, 2026 | 1947 (before Mar 22) | 1948 (after Chaitra Pratipada Mar 19) |

**The two versions can disagree for dates between the lunisolar New Year and March 22.** In 2026, this window is March 19–22. For dates in this window, the lunisolar Shaka year has already incremented but the official solar Shaka has not.

---

## 6. The Festival Date Determination Rule

### 6.1 Udaya Tithi Rule (Standard)

The standard rule for determining festival dates:

1. Compute the tithi prevailing at **sunrise** (Udaya Tithi) for the location
2. The festival is observed on the Gregorian date where the required tithi prevails at sunrise

### 6.2 Dominant Tithi Convention (Used by Drik Panchang)

When a tithi begins shortly after sunrise (within ~30–60 minutes), many panchangs still assign the festival to that date because the new tithi dominates the daytime. This is the convention Drik Panchang follows.

**Rule of thumb:**
- If tithi X begins within ~60 minutes after sunrise → festival is on that date (dominant tithi)
- If tithi X ends shortly after sunrise → festival is on the PREVIOUS date (previous tithi dominated)

### 6.3 Special Cases

Some festivals have special determination rules:

| Festival | Decisive moment | Rule |
|---|---|---|
| Janmashtami | Nishita Kaal (midnight) | Ashtami must prevail at midnight |
| Maha Shivaratri | Nishita Kaal (midnight) | Chaturdashi must prevail at midnight |
| Diwali | Pradosh Kaal (dusk) | Amavasya must prevail at dusk |
| Ekadashi | Sunrise | Ekadashi must prevail at sunrise (Smarta); or next sunrise if Saptami overlaps (Vaishnava) |
| Chhath Puja | Sunset | Shashthi must prevail at sunset |

### 6.4 Smarta vs Vaishnava

For some festivals (especially Janmashtami and Ekadashi), Smarta and Vaishnava traditions may differ by one day:

- **Smarta:** Priority to Nishita Kaal (midnight) presence
- **Vaishnava:** Priority to Udaya Tithi (sunrise) and Rohini Nakshatra; never observes on Saptami

In 2026, both traditions agreed on Janmashtami = September 4. In some years (like 2025) they differ by one day.

---

## 7. Sunrise/Sunset Calculation

### 7.1 Why It Matters

Sunrise time determines the Udaya Tithi (the tithi at sunrise), which determines the festival date. Sunrise varies by location (latitude/longitude) and date.

### 7.2 Calculation

Sunrise/sunset must be computed for the **specific location** using astronomical algorithms. They cannot be hardcoded or approximated with a fixed offset.

For Kolkata (22.589°N, 88.389°E), sunrise on September 5, 2026 = 05:20 IST. This will be different for Delhi, Mumbai, Chennai, etc.

### 7.3 Tolerance

Panchang sunrise/sunset times can differ by a few minutes between sources due to:
- Atmospheric refraction models (34' vs 50' arcminutes)
- Exact horizon definition (geometric vs apparent)
- Elevation/terrain

A tolerance of ±5 minutes is standard for verification.

---

## 8. Nakshatra

### 8.1 Definition

The ecliptic is divided into 27 nakshatras (lunar mansions), each spanning 13°20' (360° / 27).

```
nakshatra = floor(Moon_longitude / (360/27))
```

Each nakshatra is further divided into 4 padas (quarters) of 3°20' each.

### 8.2 The 27 Nakshatras

Ashwini, Bharani, Krittika, Rohini, Mrigashira, Ardra, Punarvasu, Pushya, Ashlesha, Magha, Purva Phalguni, Uttara Phalguni, Hasta, Chitra, Swati, Vishakha, Anuradha, Jyeshtha, Mula, Purva Ashadha, Uttara Ashadha, Shravana, Dhanishta, Shatabhisha, Purva Bhadrapada, Uttara Bhadrapada, Revati

### 8.3 Relevance to Festivals

Some festivals require a specific nakshatra in addition to a tithi:
- Janmashtami: Rohini nakshatra (Krishna's birth star)
- Some ekadashis: Specific nakshatra combinations

---

## 9. Ayanamsa

### 9.1 What It Is

Ayanamsa is the difference between the tropical (sayana) and sidereal (nirayana) zodiacs. It accounts for the precession of the equinoxes (~50.3 arcseconds per year).

### 9.2 Lahiri Ayanamsa

The most widely used ayanamsa in India (officially adopted by the Government of India in 1957). Drik Panchang uses Lahiri ayanamsa.

```
sidereal_longitude = tropical_longitude - Lahiri_ayanamsa
```

The Lahiri ayanamsa for 2026 is approximately 24°10'.

### 9.3 Why It Matters for Tithi Calculation

Both Sun and Moon longitudes must be sidereal (nirayana) — i.e., ayanamsa-corrected — for tithi and nakshatra calculations. Using tropical longitudes will give wrong tithis.

---

## 10. Implementation Checklist for a Calendar Engine

### 10.1 Core Computation

- [ ] Use an ephemeris (JPL DE421 or Swiss Ephemeris) for Sun/Moon positions
- [ ] Apply Lahiri ayanamsa to convert tropical to sidereal longitudes
- [ ] Compute tithi = floor((Moon_sidereal - Sun_sidereal) / 12°) at each time step
- [ ] Compute sunrise/sunset for the user's location (latitude/longitude)
- [ ] Determine Udaya Tithi (tithi at sunrise) for each Gregorian date
- [ ] Determine lunar month from the solar sign at the preceding amavasya

### 10.2 Month System

- [ ] Store Amanta masa as the base computation
- [ ] Derive Purnimanta masa = next_month(Amanta) for Krishna Paksha only
- [ ] Shukla Paksha masa is the same in both systems
- [ ] `masa` field = Amanta (base), `masaDisplay` field = Purnimanta-adjusted (for display)

### 10.3 Era System

- [ ] Vikram = Gregorian + 57 (after Chaitra Pratipada) or + 56 (before)
- [ ] Shaka = Vikram - 135
- [ ] Compute Chaitra Pratipada date astronomically each year — do NOT hardcode
- [ ] Support regional New Year variations (Gujarat, Nepal) if needed

### 10.4 Adhika Masa

- [ ] Detect when a lunar month has no sankranti → mark as Adhika
- [ ] Label as "Adhika_[MonthName]" (e.g., "Adhika_Jyeshtha")
- [ ] The Adhika month does NOT advance the year number
- [ ] Handle Kshaya Masa (rare omission) for historical dates

### 10.5 Festival Rules

- [ ] Each festival has a rule: {masa, paksha, tithi, conditions}
- [ ] Match the rule against computed Udaya Tithi
- [ ] Apply dominant tithi convention (tithi begins within 60 min of sunrise = same day)
- [ ] Handle special timing rules (Nishita, Pradosh) for specific festivals
- [ ] Support Smarta vs Vaishnava date determination if needed

### 10.6 Tithi Indexing

- [ ] Use 1-based indexing consistently (Pratipada=1 ... Amavasya=30)
- [ ] Do NOT mix 0-based and 1-based in different parts of the app
- [ ] `tithiNumber` = 1-15 (within paksha), `tithiIndex` = 1-30 (across full cycle)

### 10.7 Export/Serialization

- [ ] When exporting to JSON, ensure `masa` and `masaDisplay` are both written
- [ ] For Purnimanta mode exports, use `masaDisplay` for the month name
- [ ] Ensure timestamps are consistently in IST (or clearly labeled with timezone)
- [ ] Include both vsYear and shakaYear in every occurrence

---

## 11. Verification Checklist

### 11.1 For Each Festival

1. **Tithi at sunrise:** Compute independently and compare to `tithiNumber`
2. **Paksha:** Verify Shukla/Krishna matches the tithi index
3. **Masa (Amanta):** Verify the Amanta month name
4. **Masa (Purnimanta):** Verify masaDisplay = next month for Krishna Paksha
5. **Vikram year:** Verify = Gregorian + 57 (or + 56 before Chaitra Pratipada)
6. **Shaka year:** Verify = Vikram − 135
7. **Sunrise:** Compare to independently computed sunrise (±5 min tolerance)
8. **Sunset:** Compare to independently computed sunset (±5 min)

### 11.2 Common Bugs to Watch For

| Bug | Symptom | Root Cause |
|---|---|---|
| masa not shifted for Purnimanta | Krishna Paksha festival shows Amanta month name | Export uses `masa` instead of `masaDisplay` |
| Year off by 1 | Festival before Chaitra Pratipada has wrong year | Hardcoded March 22 instead of astronomical Chaitra Pratipada |
| Tithi off by 1 | All tithis shifted by one | 0-based vs 1-based indexing mismatch |
| NULL occurrence | Festival has no date | Engine can't resolve rule (e.g., solar festival in lunar engine) |
| Sunrise off by hours | All timings shifted | Double-adding IST offset or wrong timezone |
| Adhika Masa not labeled | Month appears twice with no distinction | Engine doesn't detect sankranti-free months |

---

## 12. Key Astronomical Values for 2026

| Value | Date/Value |
|---|---|
| Chaitra Shukla Pratipada (New Year) | March 19, 2026 (Pratipada begins 06:52 AM IST) |
| Vikram Samvat (after Mar 19) | 2083 |
| Shaka Samvat (after Mar 19) | 1948 |
| Vikram Samvat (before Mar 19) | 2082 |
| Shaka Samvat (before Mar 19) | 1947 |
| Lahiri Ayanamsa (2026) | ~24°10' |
| Adhika Masa in 2026 | Adhika Jyeshtha (May–June 2026) |

---

## 13. Sample Date: September 5, 2026 (Today)

| Field | Value | Source |
|---|---|---|
| Gregorian date | September 5, 2026 (Saturday) | — |
| Tithi at sunrise | Krishna Navami (tithi 9) | Computed from DE421 ephemeris |
| Tithi index (1-based) | 24 | Standard convention |
| Tithi index (0-based) | 23 | Alternative convention |
| Paksha | Krishna | — |
| Amanta masa | Shravana | Drik Panchang, ProKerala, R-Astro |
| Purnimanta masa | Bhadrapada | Drik Panchang, ProKerala, R-Astro |
| Vikram Samvat | 2083 (Siddharthi) | All sources |
| Shaka Samvat | 1948 (Parabhava) | All sources |
| Sunrise (Kolkata) | 05:20 IST | Computed + ShreeKundli |
| Sunset (Kolkata) | 17:49 IST | Computed |
| Official solar Shaka date | Bhadrapada 14, 1948 | Fixed calendar count from Mar 22 |

---

## Sources

- Drik Panchang (drikpanchang.com) — primary reference for festival dates, tithi timings, masa assignments
- ProKerala Panchang (prokerala.com) — cross-reference for tithi, nakshatra, samvat years
- Vidhyamitra (vidhyamitra.com) — cross-reference for Kolkata panchang
- R-Astro (r-astro.com) — cross-reference for Kolkata daily panchang
- ShreeKundli (shreekundli.com) — cross-reference for tithi timings, sunrise
- Wikipedia: Vikram Samvat, Shaka era, Indian national calendar, Hindu calendar
- Calendar Reform Committee (1957) — official Shaka calendar specification
- JPL DE421 ephemeris — independent astronomical computation
- Skyfield library — ephemeris computation framework
