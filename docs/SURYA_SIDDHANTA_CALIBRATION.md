# Calibrating the Surya Siddhanta school

The Surya Siddhanta engine is a faithful port of the classical text, but the text
anchors every mean longitude at 0 for the Kali epoch and carries no *bija*
(seed) correction. Applied literally, it does not land on the frame a modern
printed panjika uses — aligning the Sun to Lahiri alone needs an epoch offset
near −11.6°. So matching a specific authority requires a calibrated
`SuryaSiddhantaTuning`.

You do **not** need a reference database. Ten dates are enough.

## Why ten dates, and which ten

`fit` solves six parameters: an epoch longitude and an annual bija for the Sun,
the Moon, and the Moon's apogee.

- **Epoch vs bija.** Over a short span almost any split between the two fits
  equally well, and the result extrapolates wildly outside the sample. `fit`
  therefore refuses to move the bija when the references span less than ten
  years, and says so. **Spread the dates over at least ten years** — twenty is
  better.
- **Which dates.** Any dates work, but prefer days where the tithi runs well
  past sunrise. A panjika labels a civil day by the tithi at sunrise, so a date
  whose tithi changes within an hour of sunrise is decided by the sunrise
  convention rather than by the lunar model. `check` flags these as weak.

## The datum that makes this practical

A printed tithi name only says the elongation is somewhere inside a 12° bin.
A printed **tithi end time** says the elongation is exactly `12 * n` degrees at
that instant — a direct measurement. Use end times whenever the panjika prints
them.

## Workflow

One date, one command:

```bash
dart run tool/surya_siddhanta_probe.dart check 2026-01-15 \
    --tithi "Krishna Ekadashi" --nakshatra Anuradha --ends 09:20 --csv
```

It prints the engine's tithi, nakshatra and longitudes, compares them with what
you passed, warns if the date sits near a boundary, and — with `--csv` — emits a
row for the reference file:

```
date,ends,tithi
2026-01-15,09:20,26
```

Collect the rows into one CSV. When you have ten or more spanning ten-plus
years:

```bash
dart run tool/surya_siddhanta_probe.dart fit references.csv
```

`fit` prints a `const SuryaSiddhantaTuning(...)` block. Paste it over
`kSuryaSiddhantaTuning` in
`lib/services/panchang/ephemeris/surya_siddhanta_engine.dart`. That constant is
the default for both `SuryaSiddhantaEngine` and `ephemerisFor`, so one edit
reaches the panchang, the Bengali calendar and the notification isolate.

Then re-run `check` on a few dates. `check` always uses
`kSuryaSiddhantaTuning`, so a pass there means the app will print the same
tithi.

## Reference file formats

A plain CSV. Header required, one row per date. Columns are matched **by name**,
so their order does not matter, and blank lines and lines starting with `#` are
ignored.

| Columns | Meaning |
| --- | --- |
| `date,ends,tithi` | "Tithi `n` ends at `date` + `ends`." The sharpest form. |
| `date,tithi` | Tithi ordinal at 06:00 IST. Only a 12° bin. |
| `date,sun,moon` | Sidereal longitudes in degrees. Best, but a panjika won't print them. |

`date` is `YYYY-MM-DD` or a full ISO instant. Times are IST.

`tithi` in an `ends` row must be a whole number (`26`, not `26.0` and not
`Krishna Ekadashi`) — the tool rejects anything else rather than silently
discarding the end time.

### Example: ten dates over eleven years

```csv
date,ends,tithi
2015-03-11,21:47,22
2016-07-02,08:12,28
2017-11-20,14:05,3
2018-02-08,19:30,14
2019-06-27,10:15,25
2020-09-14,06:40,8
2021-12-03,22:10,29
2023-04-19,16:25,17
2024-08-07,11:55,6
2025-10-26,07:20,12
```

Then:

```bash
dart run tool/surya_siddhanta_probe.dart fit references.csv
```

Mixed files are allowed — a few `date,sun,moon` rows alongside the end times
will calibrate the absolute frame too, which is what nakshatra, yoga and masa
need.

All times are read as **IST**, not machine-local, so a calibration derived on
one machine is reproducible on another.

## What tithi data cannot calibrate

Tithi and tithi-end rows constrain only the Moon-minus-Sun elongation. The
absolute frame is invisible to them: adding the same offset to both epoch
longitudes changes no tithi. `fit` therefore freezes the Sun and lets the Moon
absorb the whole offset when the file has no absolute-frame datum.

An **end time** for nakshatra (Moon alone) or yoga (the sum, so both offsets add)
does see the absolute frame, so a file carrying nakshatra ends together with
tithi ends - or yoga ends - unfreezes the Sun and calibrates everything at once.
That is why the reference set below uses tithi *and* nakshatra end times rather
than tithi names: the names pin each limb to a 12°-wide bin, while an end time is
a point measurement.

## Known limitations after calibration

- **Sunrise, sunset, moonrise and moonset stay modern.** `SolarEventCalculator`
  uses Swiss Ephemeris, so Surya Siddhanta mode is SS lunar limbs on modern solar
  events. That is deliberate, not a shortcut: the reference set below was
  measured against a source whose sunrise is *modern* (its sunrise matches the
  app's Delhi sunrise to the minute on all 15 dates), so adding a siddhantic
  sunrise would move the app away from it. Sunrise decides udaya-tithi boundary
  cases and every sunrise/sunset division (Rahu kalam, Yamaganda, Gulika,
  Abhijit, Choghadiya, Hora), so this is still the main way the app can differ
  from a panjika that computes its own sunrise.
- **The Moon carries only the manda term.** Evection and variation are absent,
  and the text's epicycle gives a 5.10° maximum equation against the modern
  6.29°. Against the *modern* ephemeris the calibrated model reaches roughly
  1.4° RMS over 1900–2100. That number is a statement about the modern
  ephemeris, not about the panjika - see below.
- **1900–2100 is the supported range.** Outside it the linear bija is an
  extrapolation.

## The New Delhi reference result, and what it implies

The shipped tuning is fitted to 26 tithi and nakshatra end times for **New Delhi**
between 2005 and 2026, then checked against 15 **yoga** end times that the fit
never saw. Every one of the 41 boundaries is reproduced to within 0.005°, which is
half a minute of the clock - the rounding limit of the source's own times.

### What the source is, and what it is not

The reference values come from a Surya Siddhanta panjika for New Delhi. They are
**not** a transcription of a printed Gupta Press page, and this document must not
be read as validating one. Three measurements say so:

- **The frame is Delhi.** Solar noon implied by the printed sunrise/sunset sits at
  77.2°E. Kolkata would be ~88.4°E.
- **Its sunrise is modern, not siddhantic.** The app's modern Swiss sunrise at
  Delhi reproduces all 15 printed sunrises to **0 minutes**; at Kolkata the same
  calculation is off by ~45 minutes, i.e. exactly the longitude gap. A siddhantic
  sunrise would not land on the modern one this precisely.
- **The values agree with Drik Panchang's Surya Siddhanta mode** (arithmetic
  `suryasiddhanta`, ayanamsha `chitra-paksha`), which is what
  `scripts/fetch_drik_ss.py` scrapes. The garbled limb spellings in the source
  pages ("Nabami", "Dbitiya") are that site's Bengali transliteration, not print.

So the 0.005° figure measures **agreement with the same arithmetic**, which is
what you would expect from a correct implementation - not a printed page matching
an approximation to arc-seconds. That makes the engine well validated against a
Surya Siddhanta source, and it leaves the printed Gupta Press comparison
unmeasured. Getting 2-3 dates from a real Gupta Press page would close that gap.

### What the fit says about the school

Two independent details:

- The fitted bijas come out near zero (`sunBija` 0.47″, `moonBija` -0.03″,
  `apsisBija` -1.06″ per year), i.e. the source applies no drift correction and
  its mean motions are the text's own.
- On 2015-03-11 the engine puts the end of Krishna Panchami at 06:30 IST, six
  minutes before the printed sunrise of 06:36; the source labels that day
  Shashthi, and its karana list (Garaja then Vanija) is the karana pair that only
  Krishna Shashthi has.

That is what "traditional Surya Siddhanta arithmetic" means in practice, and it
is why the two schools are not near-equivalent. The **bisuddha** option is Drik
Ganita - Swiss Ephemeris positions, observationally drift-corrected, i.e. the
modern school that Bisuddha (Vishuddha) Siddhanta names. It misses these same
boundaries by 1° to 3°. So `suryasiddhanta` is the option that reproduces this
source, and `bisuddha` is the option that matches the sky.

That distinction is the whole point of offering both. Neither is a bug - they
answer different questions, and the app lets the user pick which question they
are asking.

Two consequences to keep in mind before trusting the fit elsewhere:

- The calibration is measured over 2005-2026 only. Outside that span the engine
  follows the text's mean motions. A siddhantic panjika does the same, so this is
  the right behaviour, but nothing in the reference set confirms 1900 or 2100.
- Sunrise stays modern, so udaya-tithi boundary cases (a tithi that ends within a
  few minutes of sunrise) can still differ from a panjika that computes its own
  sunrise. The lunar limbs themselves agree to the minute.

## Tool commands

```
check <date> [--at HH:MM] [--tithi ...] [--ends HH:MM] [--nakshatra ...] [--csv]
probe <date> [<date> ...]
probe --range <from> <to> [--step <days>]
fit <reference.csv> [--rows]
verify <reference.csv> [--rows]
```

`fit` searches 24 lunar-apogee starting points. A single Gauss-Newton start
lands in a local minimum often enough to be misleading: the apogee longitude is
periodic in the residual, so the linearised step overshoots, gets clamped, and
the damping then accepts a near-zero step. Before the multi-start was added the
same reference file reported 3.7° RMS; with it, 0.003°.

`verify` measures the **shipped** tuning without changing it, and exits non-zero
if any row is worse than 0.01°. Use it as the regression check:

```
dart run tool/surya_siddhanta_probe.dart verify \
  tool/reference/surya_siddhanta_delhi_2005_2026_yoga.csv
```
