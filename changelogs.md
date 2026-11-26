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

## 2026-11-23 - 0.9.16+45

### Rash Purnima keeps one day on the home card

- Purnima 2026 begins 23 Nov ~23:42: the 23rd's nishita window closes inside the tithi and the 24th's sunset still carries it, so the per-day home card showed Rash Purnima twice while the all-festivals occurrence scan showed one. Both readings come from the same matcher; the difference was that the card keeps every matching sunrise.
- `assets/festivals.json`: `rash_purnima` now sets `"vriddhi": "first"`, so the shared `applyVriddhiFilter` trims the extended run to the nishita night (23 Nov) in the month grid, home card and notifications — the same day the forward scan resolves.
- Constraint: `vriddhi` is the per-festival knob for a tithi spanning two sunrises; do not fix this by changing the nishita gap guard, which exists to keep Janmashtami from disappearing when its tithi ends before the window opens.
- Regression: `test/festival_data_test.dart` pins the rule so the two screens cannot drift again.

### Release builds survive a Maven Central 429

- A single `429 Too Many Requests` while Gradle resolved Kotlin plugin artifacts disabled the repository and cascaded into "Could not resolve" for every plugin, failing `assembleRelease` before any code compiled. Both artifacts named in the error (`kotlin-stdlib:2.4.21` and `kotlin-gradle-plugins-bom:2.2.20`) exist, so this was throttling, not a version conflict.
- Constraint: `.github/workflows/ci.yml` retries the signed APK build up to 3 times with 15/30s backoff only when the log matches a download/network failure; a real build or signing error still fails on the first attempt.
- Each attempt starts from a clean `build/app/outputs/flutter-apk` and tees its log to `$RUNNER_TEMP`, so a retry cannot ship stale APKs and the throttled log stays inspectable.
- The Gradle dependency cache (`~/.gradle/caches`, `~/.gradle/wrapper`) and its `restore-keys` remain in place; the retry covers the cold-cache case a restored cache cannot.

### Highlighted rows on the Festivals & Events card keep their spacing

Two festivals on the selected day now read as separate cards instead of one merged wash.

- A selected-day row carries an accent wash whose horizontal span contains the inset hairline's start. Drawn flush at that row's edge, the hairline merged into the wash instead of separating it. Any pair with at least one washed row now gets an 8px gap; only plain/plain pairs keep the hairline.
- Constraint: the wash is the separator around it, so no `InsetRowDivider` is emitted adjacent to a washed row. The divider's text-column inset is unchanged for plain rows.
- `lib/widgets/event_list_widget.dart` owns the choice (`_buildRows` + `_rowSeparator`); `AppTheme.festivalRowDecoration` and `FestivalRowTile` are untouched.
- Regression: `test/festivals_home_card_test.dart` pins the gap for washed/washed and washed/plain pairs, and keeps the hairline case for a plain/plain pair.

### Rash Purnima matches Kartika Purnima

- The entry used `"masa": "Kartik"`, but the matcher compares a festival's month literally against the computed Amanta name, so it never matched any day. The canonical name is `Kartika` (`docs/FESTIVALS_Modification_GUIDE.md`).
- `assets/festivals.json`: `rash_purnima` now uses `"masa": "Kartika"` and `timingOverride: "nishita"` so the night tithi decides the day; `pujaKala: "nishita"` stays for the displayed puja window.
- Constraint: every non-solar festival's `masa` must be a canonical Amanta month name (or `*`). A near-miss spelling does not error — it silently hides the festival.
- Regression: `test/festival_data_test.dart` pins canonical months for the whole catalog and an explicit Kartika Shukla 15 match for `rash_purnima`.

## 2026-11-23 - 0.9.10+43

### Updater reads the un-offset build number from the manifest

- Constraint: a release tag carries the base `+N`, but an installed `--split-per-abi` APK reports `abiIndex * 1000 + +N` as its `versionCode` (arm32=1, arm64=2, x86_64=4). Once `+N` reaches 1000 that number is ambiguous, so never decode the base from it while the manifest value is available. Keep the `baseBuildNumber` meta-data on every build.
- Gradle fills the `baseBuildNumber` meta-data from `flutter.versionCode` before Flutter applies the split-ABI offset (`android/app/build.gradle.kts`, `android/app/src/main/AndroidManifest.xml`); `MainActivity` exposes it on the `app.tithi.pro/app_update` channel and `queryBaseBuildNumber` reads it.
- `AppUpdateService.resolveBuildNumber` prefers that value; `fullVersion` is a pure join again and the old `% 1000` path is only a fallback for APKs predating the meta-data. The About chip still shows the real versionCode.
- Before this, a device on `0.9.10 (2043)` treated `v0.9.10+44` as older and Check for updates said "up to date", even though Android would have installed the 2044 APK.
- Regression: `test/app_update_service_test.dart` pins the legacy fallback and a manifest base above 1000; `test/app_update_notifier_test.dart` pins end-to-end offers for 2043 and for base 1044 (`PackageInfo.setMockInitialValues`, since `fromPlatform()` caches); `test/base_build_number_metadata_test.dart` pins the Gradle placeholder, manifest meta-data and Kotlin channel handler.

### Release publishing uses the clean version tag

- CI builds the release APKs in one `flutter build apk --split-per-abi` pass and publishes the GitHub release under the clean `vX.Y.Z+N` tag; the `--release` suffix only triggers the workflow. `AppUpdateService` parses `tag_name`, so a marker in the tag reads as build 0 and suppresses every update (`.github/workflows/ci.yml`, `lib/services/app_update_service.dart`).
- `AppUpdateService.normalizeVersion` also drops a `--<marker>` suffix as a safety net; `test/app_update_service_test.dart` pins `normalizeVersion`, `displayVersion` and `isNewerThan` against `--release` tags.
- Constraint: `lib/l10n/app_localizations*.dart` is analyzer-excluded (CI treats infos as fatal). Keep `flutter gen-l10n` output committed - CI regenerates it and fails when the committed copy is stale. Blank-line-only differences are ignored, because the pinned SDK inserts a blank line between the `intl` and localizations imports where newer generators do not.
- The release job caches only the NDK version `flutter.ndkVersion` names, under `$ANDROID_HOME/ndk`, instead of the whole preinstalled NDK tree.

### Release pipeline hardening (ABI-aware updates, repairable releases)

- The updater now picks the asset matching `Build.SUPPORTED_ABIS` (new `supportedAbis` method on `app.tithi.pro/app_update`) before downloading. CI ships two ABI-specific APKs, and the old "first `-release.apk`" rule handed x86_64 devices the arm64 build, which fails with `INSTALL_FAILED_NO_MATCHING_ABIS`. Keep the ABI token in asset names: a name without one is treated as universal, and an unknown ABI list (tests, non-Android) keeps the old order (`lib/services/app_update_service.dart`, `lib/services/app_update/app_update_file.dart`, `MainActivity.kt`).
- A newer release with no APK for this device's ABI now reports that instead of showing an Install button that dead-ends in "No installable update found" (`lib/providers/app_update_provider.dart`).
- Publishing is draft-first and idempotent: `gh release create --draft`, `gh release upload --clobber`, then publish. An existing release is reconciled instead of skipped, so a cancelled run can no longer leave one APK attached to a published release forever.
- CI refuses a `+N` that is not higher than every published release (`gh release list --exclude-drafts`, marker tags included, compared in `analyze-and-test`), and validates the `changelogs.md` block there too - a typo now fails in seconds instead of after two signed builds. The notes travel to the publish job as an artifact. The nested `packages/jyotish` is excluded from the root analyzer (its tests import `package:test`, which is absent from the app's package config) and is analyzed in its own step with its own config. The golden engine comparison is opt-in (`TITHI_RUN_GOLDEN_ENGINE=1`): its fixtures are characterization snapshots that drift when festival rules change, so they must not block a release.
- Security of the release path: tags reach the shell only as `$GITHUB_REF_NAME` (stripped of `--release*`), the workflow defaults to `permissions: contents: read` with `contents: write` only on `publish-release`, and the base64 keystore is scoped to the step that decodes it instead of job-level env (so `flutter build` and third-party actions never see it).
- The root SDK constraint now matches what the lock already required (`sdk: ^3.13.0`, `flutter: >=3.47.0`), both CI jobs print `flutter --version`, the Gradle cache key hashes `android/gradle.properties` (not matched by `android/**/*.gradle*`), and the release job runs on JDK 21 because AGP lint calls `List.removeLast()` (app bytecode still targets Java 17).

### Native splash is static; the mandala animates only while loading

- The platform splash is a single static mandala again: `splash.png` at every density, the centred bitmap in every `launch_background.xml`, and the mark in `android12splash.png`. `flutter_native_splash.yaml` points both image slots at `assets/splash/splash_icon.png`, with neutral colours (`#ffffff` / `#121212`) — saturated purple in any native resource was the MIUI magenta trigger.
- `lib/main.dart` keeps the location gate: `LocationPermissionWrapper` waits for `locationInitProvider` before showing `HomeShell`, so the first frame uses the saved place. The old "Initializing..." spinner is replaced by `AnimatedSplash`, which paints the same neutral colours as the native window and rotates/breathes while location loads. There is no forced hold, so a warm start does not add time.
- This is one brand moment, not two: the native mark is static, then the same mandala animates as a loading indicator before the app. `lib/widgets/animated_splash.dart` is wired back in; do not put the brand purple in its dark background or any native resource, or MIUI repaints magenta.
- `bootstrap.initDisplay()` (high refresh rate) is awaited before `runApp` again, so the animated loading splash renders at 90/120Hz from its first frame and the refresh-rate switch is hidden behind the static native splash. Version metadata, the boundary index, the tile cache and Workmanager stay post-frame.
- Release CI (`.github/workflows/ci.yml`) runs only on `v*` tags: analyze/test, signed arm64 + x86_64 APK builds, then a GitHub release whose notes are extracted from this changelog section.
- Regression: `test/animated_splash_test.dart` pins the static native config, the neutral Android 12 colours and the widget's motion/Reduce Motion behaviour.

### Android 12 starting window no longer magenta on MIUI dark mode

Cold starts in dark mode on MIUI 13 / Android 12 no longer paint a full-screen magenta fill.

- Root cause: MIUI ignores the Android 12 `windowSplashScreen*` attributes entirely and falls back to the legacy `windowBackground` (`@drawable/launch_background`). We had regenerated its `background.png` from the brand dark colour `#10002B`; MIUI's non-linear dark-mode inversion turned that bitmap into magenta. Restoring the neutral `#ffffff` / `#121212` bitmaps fixed it on-device. Every v31 theme permutation was irrelevant.
- Every dark-mode native colour is neutral: the YAML root and `android_12.color_dark`, `values-night-v31/styles.xml` and the legacy `background.png` bitmaps all use `#121212`. MIUI inverts saturated colours anywhere in the native phase, including the Android 12 background and the icon bitmap, so `#10002B` must never appear there. Light mode keeps `#ffffff` / `#F5F5F7`.
- The Android 12 icon is the static mandala from `assets/splash/splash_icon.png`. An opaque colour tile rendered as a masked square, and an empty slot substituted the launcher icon — both were rejected on-device.
- `AnimatedSplash` paints the MIUI-safe neutral `#121212` in dark mode (`_kNativeSplashDark`) instead of `AppTheme.splashBackgroundDark`, so the native window and the Flutter surface are one continuous screen. The brand purple is unchanged everywhere else.
- Regression: `test/animated_splash_test.dart` pins the neutral dark values, the static native icon, minimal v31 parents and the absence of app-resource `windowBackground` / `colorBackground` / `opacity` in the v31 launch theme.
- Constraint: keep every native dark colour neutral and the Android 12 icon on the static mandala. Re-check after every `dart run flutter_native_splash:create`; the brand colour belongs only in Flutter. If magenta returns, sample the native PNGs first.

## 2026-11-22 - 0.9.6+35

### Export festivals to Google Calendar (.ics)

A new Data & Storage tile writes the year's festival dates as an all-day iCalendar file that Google Calendar can import, alongside the existing JSON export.

- `lib/services/festival_calendar_export_service.dart` renders one VEVENT per resolved occurrence from the export document: all-day `DTSTART`/exclusive `DTEND`, stable UID, and Panchang timings (tithi span, sunrise/sunset) in the description. It folds lines to 75 octets, escapes TEXT values and never splits a UTF-8 character. No OAuth/internet — the .ics is saved/shared like the JSON file.
- `lib/services/festival_export_service.dart` now exposes `exportYear()` as the shared document builder; `exportYearJson()` renders the same document so both formats always describe the same dates. `lib/features/settings/widgets/festival_export_flow.dart` holds the progress/save/share flow used by both tiles.
- New tile in `lib/features/settings/widgets/data_settings.dart`, registered in `lib/screens/settings_screen.dart`. `lib/features/settings/widgets/festival_export_year_sheet.dart` owns the year picker: a row tap only moves the checkmark and an explicit "Export {year}" button proceeds, so selecting and proceeding are distinct steps. Both tiles name their format in the sheet title and explain that a save dialog comes next (three more keys in the four `.arb` files; regenerate with `flutter gen-l10n`).
- Hardening: the ICS builder reads every field through safe string/map helpers so a malformed row is skipped instead of throwing; UIDs use the catalog position (not the emitted-event ordinal) so re-import after a data change does not duplicate events. A tithi that ends on the next day gets both ends date-qualified in the description; the success message reports events actually written, not raw festival count. `exportYear()` isolates per-festival failures so one bad ephemeris read cannot discard the whole year, and the save/share flow tolerates empty picker paths and share-sheet errors.
- Constraint: keep festival events all-day (a tithi can cross midnight and wall-clock instants are location-bound); timing text belongs in the description. Never let the two exporters compute dates independently.
- Regression: `test/festival_calendar_export_test.dart` pins date formatting, escaping, folding/UTF-8, cross-midnight labels, stable UIDs, malformed-row skipping and accurate event counts. `test/festival_export_year_sheet_test.dart` pins that selecting a year keeps the sheet open and only the confirm button exports.

### All Festivals no longer skips early-year observances

The yearly festival list now resolves January vrats such as Shattila Ekadashi instead of jumping ahead to the following year.

- `lib/features/panchang/domain/festival_search_start.dart` owns the Gregorian fast-forward hint for `PanchangService.findNextFestivalOccurrence`. The old hint for a Jan 1 scan of Pausha landed on Oct 17 2026, so Shattila (Jan 14 2026) was skipped in All Festivals while the live month grid and home card still showed it. The hint now falls back to the previous lunisolar year when its current-year estimate is after the scan start, and the scan skips matches before its base date without spending the 420-day budget on them.
- Cache identity moved: the occurrence cache prefix is `occ9` (`occ8_*` purged) because the buggy scan cached the 2027 date under a Jan 1 2026 key, and `festivalYearSnapshotKey` gained `_r2` (`_resolutionVersion`) because the yearly list is a stored answer that the catalog fingerprint cannot invalidate. Bump both when scan semantics change, or an upgraded install keeps serving the old list.
- Regression: `test/festival_search_start_test.dart` pins the January Pausha case and the "never start after the base date" rule for all 12 Amanta months.
- Constraint: the month hint stays a pure optimization; the returned day still comes from the shared projection pipeline so calendar, countdown, search and export agree.

### Home-location map no longer spins while zooming

Pinching to zoom the Location screen used to rotate the map too; now only zoom and drag gestures move the camera.

- flutter_map enables `InteractiveFlag.rotate` together with pinch-zoom by default. With its gesture race off, both fire on the same two-finger pinch, so any slight finger twist spins the map.
- `lib/screens/location_picker_screen.dart` sets `MapOptions.interactionOptions` to `InteractionOptions(flags: kLocationPickerMapFlags)` - every flag except rotate. Pinch zoom, drag, double-tap and scroll-wheel zoom are unchanged.
- `MapOptions.onMapReady` calls `resetMapToNorth(_mapController)` so entry always lands north-up; that hook is the first point where the controller is attached and `rotate(0)` is safe.
- Constraint: keep `InteractiveFlag.rotate` out of `kLocationPickerMapFlags`; re-adding it makes every pinch rotate the map again. Keep the north reset on `onMapReady`, not in `initState`, where the controller has no map yet.
- Regression: `test/location_picker_map_test.dart` pins rotate off and pinch zoom / drag / double-tap on, and checks `resetMapToNorth` takes a rotated camera back to 0.

### Swipe the floating nav bar to switch tabs

On phone layouts, swiping the floating nav capsule moves between Today and Festivals just like tapping a destination.

- The swipe recognizer wraps the bar in `lib/screens/home_shell.dart`, not the bar widget: `FloatingNavBar` stays presentation-only, and the calendar's month-turn swipe in the content area never competes for the same gesture arena.
- Slow drags past 48px and fast flings past 300px/s both count; direction is resolved by `tabSwipeDirection` in `lib/core/navigation/home_tab.dart`, and the shell reuses its existing `select` path so the cross-fade, drawer reset and out-of-range guard stay in one place.
- Regression: `test/home_shell_navigation_test.dart` covers both directions, the short-drag no-op, the velocity-only fling and that a plain tap still switches tabs.
- Constraint: keep the detector outside the bar and inside `IgnorePointer` - moving it into the tabs would break month swiping, and moving it above the drawer gate would let a swipe reach through an open drawer.

### Animated branded splash

Startup now has a single animated logo moment: a colour-only platform splash hands off to the lotus mandala, which fades/scales in, rotates slowly, breathes and pulses inside a halo instead of a bare "Initializing..." spinner.

- `flutter_native_splash.yaml` is image-free; regenerated Android drawables drop `splash.png` from every density and `launch_background.xml` paints only the background colour. `android_12.image` points at `assets/splash/transparent.png` because Android 12 otherwise substitutes the launcher icon (also the mandala). The platform phase shows no logo at all. The old padded `assets/splash/splash_icon.png` is deleted and its hard-coded call removed from `scripts/pad_image.py` (the script itself stays as a reusable Pillow helper).
- `lib/widgets/animated_splash.dart` owns the four controllers; with no native mark to match, `kSplashLogoSize` is back to a hero-sized 168dp and the entrance fade/scale is restored. `lib/main.dart` (`LocationPermissionWrapper`) holds it for at least 400ms so the entrance is perceivable on warm starts; the hold and all loops collapse to zero/static under Reduce Motion.
- Regression: `test/animated_splash_test.dart` pins the native config (no root image, transparent Android 12 icon, no `@drawable/splash` in any launch background), the hold arithmetic, the rendered mark/name/tagline, and that rotation/loops are absent when motion is disabled.
- Constraint: do not restore an image to the root of `flutter_native_splash.yaml` or swap `assets/splash/transparent.png` for the mandala — either reintroduces a static logo phase before Flutter. Keep the 400ms hold off when `AppTheme.reduceMotionOf` is true.

### Splash hand-off has no colour flash

The brief solid-white window between process start and the first Flutter frame is gone: the native window already paints the splash colour, and less work runs before `runApp`.

- Native light colour is `#F5F5F7` and dark is `#121212` (neutral for MIUI, deliberately NOT `AppTheme.splashBackgroundDark`); legacy bitmaps are `#ffffff` / `#121212`. All four `values*/styles.xml` keep `NormalTheme`'s `android:windowBackground` at the platform default `?android:colorBackground`; pointing it at an app colour was a failed attempt to remove a white flash.
- MIUI/Xiaomi (reproduced on Redmi Note 10 Pro, Android 12) force-inverts saturated colours in the native splash; a purple `#10002B` background bitmap painted magenta. Both v31 `LaunchTheme` blocks keep the original platform parent and minimal item set with a literal `windowSplashScreenBackground` (`#F5F5F7` light, `#121212` dark). See "Android 12 starting window no longer magenta" above.
- The Android 12 icon is fully transparent (`assets/splash/transparent.png` at every density). An opaque colour tile rendered as a visible masked square; the earlier claim that transparency causes magenta was wrong — the bitmap colour was the cause.
- `AnimatedSplash` paints a flat `AppTheme.splashBackgroundLight`/`Dark` chosen from **system** brightness instead of `AppTheme.backgroundDecoration`'s dark `LinearGradient`, and the halo is a flat translucent disc rather than a `RadialGradient`. This keeps the hand-off predictable; the Impeller-gradient theory of the magenta was wrong.
- `lib/main.dart` now only awaits system setup, Hive and tzdata before `runApp`; display-mode opt-in, version warm-up, the place-boundary index, the tile cache and Workmanager all start in the post-frame callback.
- `lib/app/bootstrap.dart`: `initTimezones()` is tzdata only; `warmTimezoneIndex()` decodes the boundary index after the first frame. tzdata stays on the critical path because `TithiApp.initState` builds the place clock.
- Regression: `test/animated_splash_test.dart` pins the neutral native colours, the transparent Android 12 icon, platform-default `NormalTheme` backgrounds, literal v31 colours with app-resource `windowBackground`/`colorBackground` absent, and that the dark splash paints a flat background with **no gradient** in the tree.
- Constraint: keep the native dark colours neutral; the brand purple belongs only in Flutter. Never add app-resource `windowBackground`/`colorBackground` or `android:opacity` to a v31 `LaunchTheme`, and never reintroduce a `Gradient` into `AnimatedSplash`.

## 2026-11-22 - 0.9.6+34

### Ekadashi copy and timing tightened

The 26 named Ekadashis now use a strict sunrise rule and ship complete, reader-facing copy in every language the app shows.

- `assets/festivals.json`: all 26 carry `dominant_tithi: "strict"` alongside `vriddhi: "first"` — strict removes the post-sunrise grace that would pull a viddha day back onto Dashami, first keeps one observance in a genuine two-sunrise run. All 26 `panchang_rules` use the same seven keys in the same order.
- Every regional-name block fills Telugu, Kannada, Tamil and Malayalam; `pashankusha_ekadashi` displays as "Papankusha Ekadashi" (Pashankusha kept in the copy as the variant), with the etymology corrected to papa + ankusha and Padmanabha named as the deity. Mantras, fasting notes and five-step rituals are complete; developer-only prose and the hardcoded 2026 Nirjala date are gone, and the Vaishnava arunodaya caveat lives in the fasting field instead of all 26 descriptions.
- Regression: `test/festival_data_test.dart` now requires strict + first on the 24 named Ekadashis and both Adhika entries; both festival guides keep the pair together.
- Constraint: keep `strict` and `first` together — dropping either resolves viddha/vriddhi days to the wrong sunrise or shows the vrat twice.

### Ekadashis show their own names

Every Ekadashi now resolves to its own named vrat instead of all 24 days sharing one generic "Ekadashi" label.

- `assets/festivals.json` has one entry per named Ekadashi with a specific Amanta `masa`/`paksha` (the Krishna ones stored one month earlier, same offset as Diwali), `category: "vrat"`, `vriddhi: "first"` (one sunrise only — the pipeline cannot express the Dashami-touching viddha rule) and `paranRule: "dwadashi_window"`. Shravana Putrada replaces the mislabelled `pavitra_ekadashi`; Devshayani/Devutthani move from `major` to `vrat`; variant names (Shayani, Parsva/Vamana, Prabodhini, Vaikuntha) are in the regional-name copy.
- The wildcard `ekadashi_shukla` / `ekadashi_krishna` entries are gone; their slots now hold `padmini_ekadashi` / `parama_ekadashi` with `masa: "Adhika_Jyeshtha"` (the engine's exact `Adhika_` string), so an intercalary year such as 2026 shows its two extra Ekadashis while ordinary years show only the 24 named ones. No pipeline change.
- Regression: `test/festival_data_test.dart` pins all 24 rules, the absence of wildcard Ekadashis, the Adhika entries and distinct Kartika Shukla/Krishna matching in both month systems; cache/stamp tests follow the 127-entry catalog. Also restored the curated `featured` flag on `karva_chauth` and explicit `regions: ["all"]` on `dev_diwali`, both already required by existing dataset tests.
- Constraint: keep the Amanta storage convention and `vriddhi: "first"` — a wildcard masa or the default `"both"` silently re-collapses all days to one name or double-shows a vriddhi Ekadashi.

### Festival dates follow the primary calendar

Festival lists, countdowns and the festival sheet now show dates in the selected primary calendar instead of always falling back to Gregorian.

- `lib/providers/primary_date_label_provider.dart` is the single resolver: Gregorian keeps the caller's intl pattern, Hindu shows Purnimant-correct masa + paksha/tithi, Bengali shows `day month year` (Bengali script/digits under `bn`). It falls back to Gregorian while resolving, under `none`, or when a calendar service fails; the weekday stays Gregorian so callers only swap the date half.
- Applied in `lib/widgets/festival_row_tile.dart` (all-festivals rows, home card and tithi-sheet footer), `major_festival_card.dart`, `festival_countdown_card.dart`, and the event sheet (`event_detail_sheet.dart`, `event_sheet_hero.dart`, `event_puja_samay_section.dart`). Only labels changed — the dated occurrence and its countdown are untouched.
- Regression: `test/primary_date_label_provider_test.dart` covers each calendar branch, the `bn` script rule, the failure fallback and the row's short date line; existing Gregorian date assertions stay unchanged.
- Constraint: keep the Gregorian pattern argument and the synchronous fallback — the row must paint on the first frame, and the pattern preserves locale-specific month names. Do not widen the watch to the secondary calendar; this is a primary-calendar feature.

### Festival names follow the app language everywhere

Festival names now use the matching regional name from `assets/festivals.json` under Hindi, Bengali and Sanskrit instead of always showing English; the other name stays visible as a secondary line.

- `lib/core/format/festival_labels.dart` owns the single resolvers: `festivalDisplayName` (locale-tag aware, English fallback), `festivalAlternateName` (English ↔ regional swap for card subtitles) and `festivalMatchesName` / `festivalSearchHaystack` (search across every catalogued script). Canonical English stays for IDs, export, AI prompts and file names.
- Applied to rows/featured cards, schedule, both search delegates, countdowns and snack messages, share card/text, notification titles, home-widget payload, Daily Wisdom chip and hero artwork labels (`lib/widgets/`, `lib/features/{festival_search,countdown,hero,quote,schedule}/`, `lib/core/notifications/scheduler.dart`, `lib/services/{home_widget,share_service}.dart`).
- Changing the language re-schedules enabled reminders (`NotificationService.rescheduleAfterLanguageChange`, called from `lib/features/settings/widgets/language_display_settings.dart`); already-scheduled Android notifications would otherwise keep the old-language title until the next place change or WorkManager pass.
- Regression: `test/event_sheet_content_test.dart` covers locale tags, the secondary-name swap, multi-script search and blank/whitespace/unknown-locale fallbacks.
- Constraint: do not change `Festival.name` / Hive field 1 — the English name remains the stable key for lookup, cache identity and export.

### Settings scroll stays smooth while location initializes

The location row's loading spinner no longer makes the Preferences card repaint on every frame, so scrolling settings while the one-shot location read is pending no longer stutters.

- `SettingsSwitchTile` (`lib/widgets/settings_widgets.dart`) wraps its `InlineSpinner` in a `RepaintBoundary`; the animated `CircularProgressIndicator` used to invalidate the enclosing `SettingsGroupCard` boundary and re-rasterize all five rows each tick. No live stream is involved: `locationEnabledProvider` / `currentLocationProvider` are one-shot futures and are cached (`lib/providers/location_provider.dart`).
- Regression: `test/settings_switch_spinner_test.dart` asserts the boundary sits between the spinner and the tile, and that no spinner is built when the row is idle.

### Location picker opens without transition stutter

Drilling into the map from Settings → Home Location or the home hero's location chip no longer drops frames mid-push.

- `IndiaBoundaryLayer` (`lib/core/location/boundary_overlay.dart`) does the UTF-8 + JSON decode and ring extraction of the 7.5 MB / ~318k-point `assets/map_data/india_boundary.geojson` in a background isolate via `compute`, caches the flat rings for the app's lifetime, and renders an outline-only `PolylineLayer`. The old `GeoJsonLayer.asset` did all of that on the main isolate inside `initState`, which collided with the 300 ms `pushSharedX` animation.
- `LocationPickerScreen` (`lib/screens/location_picker_screen.dart`) mounts the new layer; both entry paths (`HeroHeader` chip and `HomeLocationSetting`) keep calling `AppRoutes.pushSharedX`, so no navigation behaviour changed.
- The outline keeps `AppTheme.mapBoundary` at 1.5 px with no fill, and a corrupt bundle yields no boundary rather than throwing during the push.
- Regression: `test/boundary_overlay_test.dart` locks ring extraction (MultiPolygon + Polygon, holes, degenerate and malformed rings).

## 2026-11-21 - 0.9.6+34

### All Festivals: full-strength featured title, icon-only search

The featured card's festival name now reads as strong as the compact rows, and searching is a tap on an icon in the chip strip instead of a permanent bar above the list.

- `MajorFestivalCard` (`lib/widgets/major_festival_card.dart`) gives the title an explicit `colors.onSurface`; a colourless `AppTypography.ui` inherited `bodyMedium`'s `secondaryInk` and looked muted next to `FestivalRowTile` names. Do not drop that colour again.
- `AllFestivalsScreen` (`lib/screens/all_festivals_screen.dart`) keeps one body row above the list: `_buildCategoryChips` leads with a search `IconButton`; tapping it swaps in a focused `_buildSearchField` in the same slot, with a single close button. `_closeSearch` cancels the debounce, clears the query and restores the chips, so no stale keystroke can re-filter after exit and no second clear-text X sits beside the dismiss button.
- Added `closeFestivalSearch` to all four `.arb` files and regenerated `lib/l10n/`; `test/major_festival_card_test.dart` and `test/all_festivals_screen_test.dart` cover the title colour and the icon/field swap.

## 2026-11-19 - 0.9.5+33

### Home hero updates in place instead of blanking

Returning to the app after a long suspend (or a place change) no longer makes the hero fade its text out and back in before showing the same day.

- `heroRecordFor` (`lib/widgets/paksha_hero_card.dart`) keeps painting the live record's previous value while it reloads, so `resolved` - and the `_HeroBody` content key `(date, resolved)` - does not flip to false. Riverpod reports a dependency rebuild as `AsyncLoading(isReloading)`, and the old `panchangAsync.when` took its `loading` branch because `skipLoadingOnReload` defaults to false; the fallback body re-keyed the switcher, which drops the old child and fades the new one in from transparent (~180ms of empty hero, again when the record landed).
- `AsyncError` still yields to the month-batch/last-visited cache, and `_TrueColdHeroPlaceholder` (extracted from the old inline fallback) now only appears when neither a live nor a cached record exists.
- Regression: `test/hero_record_test.dart` (reloading state keeps the previous record and stays `resolved`).

## 2026-11-17 - 0.9.1+31

### All Festivals shows any year, not just the current one

The screen's app-bar year stepper (chevron arrows plus a tappable year that opens the Material year picker) loads 1976-2076; each year resolves to its own occurrence dates instead of always showing today's year.

- `allFestivalOccurrencesProvider` (`lib/screens/all_festivals_screen.dart`) is now `FutureProvider.autoDispose.family<List<DatedFestival>, int>` keyed by year; resolution scans forward from Jan 1 of the picked year (correct for past years too). Past-year rows show plain dates, never "in N days".
- The year snapshot box keeps multiple years: `writeFestivalYearSnapshot` (`lib/features/countdown/data/festival_year_snapshot.dart`) no longer deletes every other `year1_` record; it prunes to the 8 most recent years and always keeps the record just written.
- The per-scan occurrence cache (`lib/features/panchang/domain/occurrence_cache.dart`) keeps January bases within +/-3 years of today (was: this year and next), so returning to a browsed year does not re-scan.
- The current year's list still auto-scrolls to today's point on open; other years open at January.
- The app bar title is left-aligned on this screen (`PageScaffold(centerTitle: false)`): the stepper widens the actions strip, so the theme's centered title would drift into the leftover middle space. `PageScaffold` now exposes an optional `centerTitle` override; leaving it null keeps every other screen on the theme setting.

## 2026-11-17 - 0.9.1+30

### All Festivals opens instantly after the app is evicted

The yearly list now paints from a persisted snapshot instead of rescanning the ephemeris on every cold start.

- `allFestivalOccurrencesProvider` (`lib/screens/all_festivals_screen.dart`) reads one Hive record per year/location/school/catalog generation before falling back to `resolveDatedFestivals`. Recurring vrat expansions are stored too, and resolution always runs Jan 1 through Dec 31, so the record cannot go stale inside the year.
- The snapshot lives in its own `festival_occurrences` box (`lib/features/countdown/data/festival_year_snapshot.dart`, `BoxNames.festivalOccurrences`), not the panchang cache box, so location-driven cache clears and catalog reseeds cannot wipe it.
- `locationSignature` (`lib/features/panchang/data/panchang_cache.dart`) rounds the cache identity to 2 decimals (~1.1 km) instead of 4 (~11 m). Ordinary GPS jitter between launches no longer changes the identity, so `preparePanchangCacheBox` stops clearing the box and the per-scan occurrence cache survives.
- Snapshot dates are stored as `YYYYMMDD` integers, not epoch millis, so a timezone change between launches cannot shift a row by a day.
- Occurrence generation bumped to `occ8` (and `occ7_*` purged): keys written with the 4-decimal identity are orphaned. Regression: `test/festival_year_snapshot_test.dart`.

### Home paints at the last used place instead of waiting for GPS

A cold start no longer holds every home card behind a device fix and reverse geocode; panchang computes immediately at the place the previous session ended on.

- `LocationService.init` seeds `_persistedLocation` from the Hive cache, and `lastKnownLocation` now answers with it when no live fix has arrived (`lib/services/location_service.dart`). Location disabled still resolves to the home/default place.
- `calculationLocationProvider` (`lib/providers/location_provider.dart`) starts at the persisted place and adopts a fresh fix only when it lands in another `placeGridKey` cell (~1.1 km, `lib/core/location/place_grid.dart`). Returning the same instance inside a cell is deliberate: a new `LocationData` would notify every panchang provider and restart the month batch for a few metres of drift.
- `locationSignature` now uses the shared `placeGridKey`, so "same place" and "same cache identity" cannot drift apart.
- `LocationPermissionWrapper` (`lib/main.dart`) completes the gate as soon as a saved place is readable and refreshes the device fix in the background; only a first launch with nothing saved still waits (10 s timeout) so the month batch does not compute twice.
- Cold-start marks: `StartupTimeline` (`lib/core/perf/startup_timeline.dart`) logs `[startup] +NNNms <stage>` for storage, timezones, first frame, location init/gate/fresh fix, ephemeris install, festival catalog, month batch, and each home card's first data. Off by default; enable with `flutter build apk --profile --dart-define=tithi.startupTimeline=true` (tests force it off).
- Regression: `test/calculation_location_test.dart`.

### Cold start stops re-hashing the bundled data files

A relaunch of the same build no longer SHA-256s the 1.9 MB ephemeris trio or re-reads and fingerprints the 230 KB festival catalog.

- Ephemeris: `copyEphemerisFiles` (`lib/services/panchang_init/panchang_init.dart`) records each installed file's expected hash, size and mtime in `ephe/.verify.json`. A launch that finds all three unchanged only stats the files (`hashed=0` in the `ephe-files` mark) and skips the full hash; a modified file, a new manifest hash or an unreadable record falls back to hashing and repair. The record is best-effort and never fails startup.
- Festival catalog: `FestivalRepository.init` stores the catalog fingerprint with the build that produced it (`version_build` = `version+buildNumber`, `version_seed` = `_festivalSeedVersion`) in `festival_settings`. A matching build with a non-empty box reuses the fingerprint instead of loading `assets/festivals.json`; an unknown build identity, a new build, a cleared box or a changed seed version always re-fingerprints. `hashed` in the `festival-init` mark reports which path ran.
- Constraint: editing `assets/festivals.json` without bumping `version`/build number keeps the old catalog on installed devices — bump the build.
- Regressions: `test/panchang_init_test.dart` (verification stamp), `test/festival_catalog_stamp_test.dart`.

## 2026-11-16 - 0.9.1+30

### Updated flutter version and gradle version

- Updated flutter version to 3.50.0, gradle version to 9.9.1 and agp to 9.3.1.
- Fixed related issues with the new flutter version, including the removal of deprecated APIs and the addition of new features.

## 2026-11-16 - 0.8.1+28

### One empty state, one error state, one skeleton

Every list, sheet and card now says "nothing here", "could not load" and "still loading" the same way - and an error can no longer print a raw exception into the UI.

- `EmptyState` / `ErrorState` (`lib/widgets/state_views.dart`) take a `StateViewVariant`: `page` (48dp faint glyph, centred), `card` (same inside card padding) and `inline` (20dp glyph on one line; the caller owns the outer padding, which is part of the card's row rhythm). `EmptyState` is display-only by design - each empty state already has its action in a toolbar, FAB or adjacent control.
- Error copy is always friendly, already-localised text (`l10n.couldNotLoadFestivals`, `l10n.errorLoadingData`, `l10n.weatherDataUnavailable`, ...). The exception goes to `debugPrint` at the catch site; `Text` never carries `error.toString()`. Pages that can reload pass `onRetry` (a provider `invalidate`), so the old dead-end red text is now recoverable.
- `SkeletonBox` / `SkeletonList` / `InlineSpinner` (`lib/widgets/skeleton.dart`): one tint (`onSurface` 0.06), radius from `AppRadius` (calendars pass `chip`, everything else `tile`), `strokeWidth: 2`, primary ink. Static on purpose - a shimmer would add a dependency and a Reduce Motion gate for no information gain.
- Migrated: 9 empty sites (countdown, all-festivals, sankalpa, eclipse, moon-phase tabs, both search delegates, weather, home event card), 11 error sites (countdown, all-festivals, home event card, eclipse, moon phases, solar system, moon countdown, weather, location search), and every inline spinner (tithi sheet cards, settings/update rows, location picker, event detail, home-widget card, countdown tile).
- Full-screen loads keep `CircularProgressIndicator.adaptive()`; `PanchangInitErrorBanner`/`FailureOverlay` (persistent warning + settings action) and the hero artwork placeholder keep their own shapes.
- `ErrorDisplayWidget` is now only the global `ErrorWidget.builder` crash screen; its unused `compact` branch is deleted, and local data errors use the calmer `ErrorState`.
- `test/state_views_test.dart` locks the variants, the action-free empty state, retry wiring, the 0.06 skeleton tint/radius, `SkeletonList` geometry and `InlineSpinner` size/stroke.

### One spacing ladder, one radius scale, named icon sizes

Padding, corners and icon sizes now come from three shared scales, so a sheet cannot pick 11dp where the next screen picks 12 and two cards that look the same can no longer round to 14 and 16.

- `AppSpacing` (`lib/theme/app_metrics.dart`) is a 2dp ladder: `s2`, `s4`, `s6`, `s8`, `s10`, `s12`, `s14`, `s16`, `s18`, `s20`, `s22`, `s24`, `s28`, `s32`. Anything above `maxStep` (32) is a component dimension - a 44dp avatar, a 168dp moon disc - and stays a literal where the widget owns it. ~700 `EdgeInsets`/`SizedBox` values migrated; off-grid 3/5 snap to `s4` and 11 snaps to `s12`.
- `AppRadius` is role-named and nine steps: `micro` 2, `small` 4, `chip` 8, `dense` 12, `tile` 16, `round` 20, `card` 24, `sheet` 32, `pill` 999, plus `sheetTop`. 18 shipped values snapped to it (1/3 -> `micro`, 6 -> `chip`, 10/13 -> `dense`, 14 -> `tile`, 28 -> `card`, 50/99 -> `pill`); the festival-row selected-day wash moves 14 -> 16 as a result. `AppTheme.pageGutter`/`cardRadius`/`cardRadiusCompact`/`cardGap` are now aliases, so existing call sites keep working.
- `AppIconSize` keeps every shipped pixel (no icon was resized) but names the role: `inline` 14, `small` 16, `dense` 18, `medium` 20, `large` 22, `nav` 24, `title` 28, `hero` 32, `feature` 40, `avatar` 44, `empty` 48, `display` 56, `splash` 64. Numeric `Icon(size:)`, `iconSize:` and `glyphSize:` are gone from `lib/`.
- Exempt by design: a `SizedBox` with a `child:` is a fixed-size box (spinner, thumbnail), not a gap, and `SizedBox(height: 1)` and `>32` sizes stay literal. Canvas painter geometry (planet radii, blur) is untouched.
- `test/app_metrics_test.dart` locks the three ladders (ascending, 2dp grid, retired radii absent) and is a textual guard: a numeric `EdgeInsets` value up to 32, an on-ladder `SizedBox` gap, a numeric corner radius or a numeric icon size in `lib/` fails the suite.

### One type scale, one weight set, one shared theme type map

Sizes are picked from a named ladder instead of 21 one-off numbers, and the four colour palettes build the same serif-heading / sans-body map, so a heading can no longer land half a point off its neighbour or be serif in one theme and sans in another.

- `AppTypography.sizeLadder` (`lib/theme/app_typography.dart`) is the only place a text size is named: `sizeMicro` 10, `sizeFootnote` 11, `sizeCaption` 12, `sizeDetail` 13, `sizeBody` 14, `sizeProse` 15, `sizeSubtitle` 16, `sizeHeading` 18, `sizeTitle` 20, `sizeHeadline` 22, `sizeDisplay` 24, `sizeHero` 32, `sizeGlyph` 64. Pick by job, not by number; 117 raw `fontSize:` literals migrated.
- The retired half-point steps were folded into their neighbour (`10.5 -> 10`, `11.5 -> 11`, `12.5 -> 12`, `13.5 -> 13`, `14.5 -> 14`); `17`/`19` use the 16/18 heading steps they were shadowing. Every change shrinks or holds, except 9 -> 10 on canvas labels; `sizeHeading` sits exactly on `displayMinimumSize`, so it stays serif.
- Weights are `AppTypography.regular`/`medium`/`semibold`/`bold` (400/500/600/700) - the only faces `pubspec.yaml` ships. `FontWeight.w800` (10 sites) was never rendered and is now `bold`; `bold`/`w700`/`normal`/`w400` spellings collapsed the same way.
- `AppTheme._appTextTheme` + `_appBarTitle` build the type map once for shukla, krishna and pure-dark themes; only the ink is passed in. Roles the map does not override keep their Material 3 sizes (which `Theme` merges in per locale) - `test/app_typography_test.dart` reads the live theme to lock that.
- Canvas text gets the family chain too: the solar-system painter's zodiac/degree ring now uses `AppTypography.telemetry` and its planet names `AppTypography.ui`, both with the Indic fallbacks - a painter inherits no theme, so a Bengali planet name used to fall back to the platform face.
- `test/typography_scale_test.dart` is a textual guard (like `test/no_web_target_test.dart`): no numeric `fontSize:` and no `FontWeight.` anywhere in `lib/` outside `app_typography.dart`, and every file that names `AppTypography` must import it.
- Use a Material role where the widget already has one (`bodyMedium`, `titleMedium`, `labelSmall` match the ladder); the token is for `Text` styled by hand.

## 2026-11-15 - 0.8.1+27

### One haptic gate, named motion tokens, screen-reader labels

Buzzes, animation lengths and assistive labels now come from shared helpers, so the Accessibility switches and the Reduce Motion setting can no longer be bypassed by a call site that forgot the gate.

- `AppHaptics` (`lib/core/feedback/app_haptics.dart`) is the only place the app calls `HapticFeedback`: `AppHaptics.tap(ref)` (lightImpact - taps, selection, toggles) and `AppHaptics.impact(ref)` (mediumImpact - deliberate actions only, the Paksha hero's manual page turn). Two weights, both checking `accessibilityProvider.hapticFeedback`; ~22 hand-inlined `if (ref.read(...).hapticFeedback)` blocks collapsed into it. Pass `haptic: false` to `PressScale` where the tap callback already buzzes so the scale animates without a second buzz.
- `AppMotion` (`lib/theme/app_motion.dart`) names the durations by job - `press` 100, `chrome` 150, `subtle` 180, `standard` 200, `resize` 220, `emphasized` 250, `scroll` 260, `entrance` 280, `page` 300, `staggerStep` 60 - plus `standardCurve` / `emphasizedCurve` / `exitCurve`. Always gate a token with `AppMotion.of(context, token)`: it delegates to `AppTheme.animationDuration`, so Reduce Motion and the OS `disableAnimations` flag collapse it to 1ms. A raw `Duration(milliseconds:)` in an implicit animation silently ignores that setting.
- Reduce Motion coverage filled in where it was missing: `ask_ai_sheet` keyboard padding, `event_detail_sheet`'s two `AnimatedSize` toggles, and the page/tab/stagger controllers, which now read their durations from the same tokens.
- New `CalendarDaySemantics` (`lib/widgets/calendar_day_semantics.dart`) collapses a day tile into one node - `15, Shukla Ashtami, Today, Selected` - instead of leaving the reader on the raw day-number text. Every tile reports a selected state (unselected reads "not selected"), so the grid is a set of selectable cells; state words come from `l10n.today` / `l10n.selected`, and the tap handler stays on the grid.
- Icon-only buttons in `all_festivals_screen`, `festival_countdown_screen` and `festival_search_delegate` gained tooltips (`l10n.clearSearch`, `MaterialLocalizations.backButtonTooltip`), and decorative artwork (about logo, drawer logo, the Paksha hero's deck imagery) is now `excludeFromSemantics` instead of being read as an unlabelled image. The hero festival image's asset branch carries its `semanticLabel` the way the network branch already did.
- `test/app_haptics_test.dart` (silence when off, one buzz per call, the two platform weights), `test/app_motion_test.dart` (token values, curves, 1ms collapse) and `test/calendar_day_semantics_test.dart` (label/flag shape, plain day, Bengali) lock the behaviour.

### Shared hairline rule and muted text levels

Rules and de-emphasized text now come from two shared helpers, so dividers match inside one screen and quiet text follows High Contrast instead of being pinned to a per-call alpha.

- `AppDivider` (`lib/widgets/app_divider.dart`) is the only place the app builds a `Divider`: `AppDivider()` (onSurface 0.1) separates sections/panels, `AppDivider.row()` (0.08) separates rows sharing one card surface; both are 1px with optional `indent`/`endIndent`.
- `AppTheme.hairlineAlpha(context, normal)` lifts both weights to 0.22 under High Contrast - not `contrastAlpha`'s full ink, because an opaque 1px rule reads as a hard border. Card/sheet edges keep `sheetHairline`.
- `InsetRowDivider` is now a thin delegate to `AppDivider.row(indent: leadingInset)`; `SettingsDivider` is deleted and its 22 settings/home-cards/ai call sites use `AppDivider()`.
- `MutedInk` (`lib/theme/app_theme.dart`, next to `ThemeExtension`): `secondaryInk` (0.7, information-bearing), `hintInk` (0.55, metadata/quiet affordances), `faintInk` (0.35, decorative glyphs only - 0.6 in High Contrast). Over 100 raw `onSurface.withValues` ink sites migrated; every change darkens text, never lightens it.
- Deliberately untouched: sheet hairlines/card fills, the solar-system canvas, the map picker surface, the schedule view, the drawer and the Paksha hero. `test/app_divider_test.dart` / `test/muted_ink_test.dart` lock the weights, the High Contrast values and the inset delegation.

### Shared page shell and back button

Every full-screen page now builds from one `PageScaffold`, and pushed pages share one back button, so app-bar height, background layering and gesture-handle clearance can no longer drift screen to screen.

- `PageScaffold` (`lib/widgets/page_scaffold.dart`) owns the transparent `AppBar` (`automaticallyImplyLeading: false`, elevation 0), the `RepaintBoundary` around `AppTheme.backgroundDecoration`, and the `SafeArea(bottom: false)` that lets the gradient paint behind the gesture handle. Its defaults are the reading-page shape; `extendBodyBehindAppBar: false` is the form shape (background becomes a plain wrapper, the safe area is ignored) used by the sankalpa list and create screens.
- `background: false` / `safeArea: false` is the edge-to-edge escape hatch: the home screen's body paints its own background and insets (and wide layouts keep the drawer flush), and the map picker paints tiles.
- Migrated: about, all festivals, eclipse, festival countdown, home, home cards, location picker, moon phases, privacy policy, settings, solar system, sankalpa list and sankalpa create. Each screen still passes its own `leading` because the shell cannot guess: `HapticBackButton()` when pushed, `AppDrawerButton()` when hosted as a tab, `null` for the wide home layout.
- `HapticBackButton` (`lib/core/navigation/haptic_back_button.dart`) gained `circled` and the native back tooltip. The circle is reserved for bars floating over imagery (the map picker); about/settings/home cards/privacy used to paste a circle-backed button and eclipse/countdown a plain arrow - pushed pages are all plain now.
- `test/page_scaffold_test.dart` locks the three shapes (reading, form, edge-to-edge) plus chrome/drawer forwarding. It keys the body and reads the shell as its ancestors, because the app bar brings its own `SafeArea`.

### Shared page-card layout

Cards on every page now share one surface, one corner radius and the same distance from the screen edge; the home screen is the reference rather than the exception.

- `AppCard` (`lib/widgets/app_card.dart`) owns the surface (`AppTheme.cardDecoration`), the radius shared by the card _and_ its ripple, the haptic `InkWell` tap, and the single-node semantics pattern. `ScreenBody` (`lib/widgets/screen_body.dart`) owns the outer frame: 12dp gutter on every breakpoint and the 800dp reading width.
- `AppTheme.pageGutter` (12, aliased by `homeCardGutter`), `cardRadius` (24), `cardRadiusCompact` (16) and `cardGap` (16) are the only numbers a card should use. `AppTheme.cardDecoration(accent: ...)` is the featured edge; ordinary cards keep the neutral hairline - an accent edge on every card makes the whole screen read as featured.
- Migrated: home (calendar, quote, festivals, countdown and widget cards - pixel-identical), eclipse, all festivals (16dp/900 -> 12dp/800, row gaps 10 -> 16), moon phases, festival countdown screen, sankalpa list (elevated 16dp `Card` -> flat 24dp page card).
- Text screens migrated too: settings, home-cards picker, about, privacy policy and the sankalpa create form went from a 24dp gutter to `ScreenBody`, and their hand-rolled `Material`/`Ink`/`Container` cards (`AppUpdateCard`, the group cards, the about/privacy cards) are now `AppCard`. Inner paddings (16/20/24) stay - they express hierarchy, not the page frame.
- Last `AppCard` bypasses closed: `FestivalCountdownTile`'s standalone branch is an `AppCard` (the embedded branch stays surface-free and keeps its 12dp row inset so the home base card's flush rows and dividers still work), and `_CountdownLoadingCard`, `_LoadingCard` and `_UnresolvableCard` use it instead of calling `glassmorphism` directly.
- `GlassmorphismConfig.getDecoration` is deleted: it duplicated `AppTheme.glassmorphism` branch for branch and was the second surface path settings cards used. `GlassmorphismConfig` now only caches `isHighContrast` for `AppTheme.glassmorphism`'s provider read.
- `SettingsGroupCard` passes `clipBehavior: Clip.antiAlias` to its `AppCard`: it owns no padding, so a row's `ListTile` hover wash is a square and painted past the 24dp corners. A card that hosts its own ink (rows) must clip, the way `SheetSurfaceCard` already does for `SheetLinkTile`.
- `ResponsiveLayout.responsivePadding` (16/32/48 by breakpoint) and `CenteredContent` (max 900 on eclipses) are gone; they were the per-screen gutter/width drift.
- Sheets keep `sheetCardDecoration` / `sheetHairline`: a sheet body card sits on the sheet surface, not on the page, and its padding is intentionally tighter.

### Eclipse tabs

Solar and lunar eclipses are two tabs instead of two stacked sections, so the lunar list no longer sits below six solar cards and needs a scroll to reach.

- `EclipseScreen` is stateful with a 2-tab `TabController` in the app bar; each tab is an `EclipseList` already filtered by `EclipseType.isSolar` / `isLunar` (import `models/eclipse.dart` - the provider re-export does not include the extension).
- Per-tab empty state and stagger restart; the eclipse-type colour stays on the card badge, while the card edge keeps the neutral hairline.
- `EclipseCard` composes one semantics label (type, days until, date, max-eclipse time, visibility) like the festival rows; `AppCard` excludes the visual text and keeps the tap action.

### Home card highlight spacing

The selected-day wash and the press highlight now extend past the row content instead of hugging the tile and chevron.

- `AppTheme.homeCardRowInset` (12) is the breathing room inside a row's surface; `AppTheme.homeCardRowPadding` (4) is the card's side padding. They sum to the 16dp heading gutter, so keep them in that relationship.
- `FestivalRowTile` and `FestivalCountdownTile` gained `horizontalPadding`; `InsetRowDivider` indents by `textColumnInset + homeCardRowInset`.
- `HomeWidgetCard`'s header ripple takes the same inset, and its right padding is symmetric when mounted without the dismiss button (countdown screen).
- All Festivals non-featured rows use opaque card white + `sheetHairline` in light mode (the old 5% `onSurface` wash read as disabled); dark palettes keep the `onSurface` tint.

## 2026-11-14 - 0.8.1+26

### Category chips on All Festivals

The all-festivals list now has All / Major / Vrat / Recurring / Featured chips directly under the search field, so the common narrowing is one tap instead of a trip through the filter sheet.

- `FestivalCategoryFilter` gained `featured` (`lib/models/festival_filter.dart`); its matcher reads the curated `Festival.featured` flag, **not** `category` — 96 of 110 catalog records are `category: 'major'`, so "Featured" must keep meaning the ~20 curated flagships (the ones the list renders as `MajorFestivalCard`).
- Chip order is `FestivalCategoryFilter.values` order; append new values at the end. The strip is `AllFestivalsScreen.categoryChipsKey`, built by `_buildCategoryChips` in `lib/screens/all_festivals_screen.dart`.
- The chips and the app-bar sheet write the same `_filters` state: `_selectCategory` uses `copyWith`, so a region picked in the sheet is preserved when a chip is tapped. The sheet still opens with the strip's choice staged and gains the Featured chip too.
- One shared `FestivalFilterChip` + `festivalCategoryFilterLabel()` (`lib/widgets/festival_filter_chip.dart`) renders both entry points, so their tint/label cannot drift.
- `FestivalFilterChip` fills via `ChoiceChip.color` (a `WidgetStateProperty`), **not** `selectedColor`: `RawChip` resolves the fill a selection fade _starts_ from through the chip defaults' `color` (`colorScheme.secondaryContainer`, fully opaque) and only the _end_ through `selectedColor`, so `selectedColor` alone flashed a solid off-palette block on every tap in both the strip and the sheet. With `color` set, the chip switches between transparent and the primary wash with no fade — keep it that way, and see `test/festival_filter_chip_test.dart`, which samples the painted fill mid-fade in all three palettes and fails if any frame is more opaque than the wash.
- Tests in `test/all_festivals_screen_test.dart`: sheet taps must be scoped to `find.byType(BottomSheet)` — the strip renders the same labels behind the modal.

### Moon phases list legibility

The upcoming Purnima/Amavasya rows now read at full ink instead of the theme's hint colour.

- Row date line: `bodyMedium` resolves to the Shukla hint ink (`shuklaInkTertiary` #6E6E76), so the row overrides it to `colorScheme.onSurface` at w600; the time line moves from `onSurface` 0.6 to 0.72.
- The "in N days" pill pins its label to `onSurface` (dark on the amber tint in light, light on the indigo tint in the dark palettes), and the empty-list message uses 0.8 ink instead of the inherited hint colour.
- `test/moon_scrub_test.dart` ("Upcoming dates list legibility") renders the screen in Shukla/Krishna/Pure Dark and asserts ≥7:1 for the date and ≥4.5:1 for the time against the page background (translucent ink is alpha-blended first). Keep those thresholds when restyling this list.

### Two-destination nav bar

The floating bar now has Today and Festivals only; Countdowns is still one tap away in the drawer, which opens it as a full screen over the current tab.

- `HomeTab` is `{ today, festivals }` (`lib/core/navigation/home_tab.dart`). `HomeShell` indexes `HomeTab.values` with the bar's `onSelected` and with `_tab()`, so the destination list in `build()` must keep the enum's order and length.
- The drawer's Countdowns entry no longer selects a tab: it pops the drawer and pushes `FestivalCountdownScreen` as a peer route (`AppDrawer._navigateTo`), the same as Moon Phases/Settings/About.
- `AppDrawer` dropped its `onSelectTab` callback (Countdowns was its only consumer). The screens keep their own `onSelectTab` flag because it decides hosted-vs-pushed chrome (hamburger vs back arrow).
- The home card's "view all" still switches to the Festivals tab, so `HomeShell` must pass `onSelectTab: _selectTab` to **both** tabs — `HomeScreen` forwards it to `EventListWidget`, and a missing callback silently falls back to pushing a second `AllFestivalsScreen` over the shell (guarded by `test/home_shell_navigation_test.dart`).
- `FestivalCountdownScreen` lost its `tabRevealProvider` re-tap scroll handler (nothing re-selects it now); its `_scrollController` stays for the lists.

### Cross-script type system (bundled, offline)

Titles, body copy and astronomical labels now share harmonised Latin + Indic typefaces, with no runtime font fetching.

- Three tiers in `AppTypography` (`lib/theme/app_typography.dart`): `display` = Newsreader + Tiro Devanagari Hindi/Bangla/Tamil/Telugu + Noto Serif Malayalam; `ui` = Plus Jakarta Sans + Noto Sans Devanagari/Bengali/Tamil/Telugu/Malayalam; `telemetry` = Space Grotesk; `shloka` = Tiro Devanagari Sanskrit.
- Every tier carries an explicit `fontFamilyFallback` chain, so mixed "Kartika Chaturthi • कार्तिक चतुर्थी" strings never drop to the Android system font. Adding a script = add the family to `pubspec.yaml` and to the matching fallback list; no other wiring.
- Theme coverage (`lib/theme/app_theme.dart`): `displayLarge/Medium/Small`, `headlineLarge/Medium/Small`, `titleLarge` and the app-bar title are serif; `titleMedium` and below are Jakarta with tabular figures (calendar digits, countdowns align). `theme.fontFamily`/`fontFamilyFallback` are set on all three themes too.
- Serif stays on the hero tithi title, month heading, section headings, sheet date lines and shlokas. Dense scannable lists use the sans: `festival_row_tile.dart` names are `ui(fontSize: 16, w600)` and the featured `major_festival_card.dart` name is `ui(fontSize: 18, w600)` - ~110 rows are read top-to-bottom, and Newsreader at 15-17pt slows that scan.
- `AppTypography.displayMinimumSize` (18pt) is a hard floor: `display(fontSize: < 18)` silently returns the `ui()` style, because Newsreader's hairlines go faint at small sizes on low-DPI light-mode screens. Call sites that need sub-18pt text should pass their size to `display()` (not `copyWith(fontSize:)` afterwards) so the guard applies.
- Display/shloka styles default to a loose 1.35/1.6 line box so Devanagari/Bengali top and bottom matras are not clipped - do not tighten below 1.3 anywhere (section headings take 1.3 deliberately).
- Fonts are bundled in `assets/fonts/` (49 files, ~7.2 MB) and registered in `pubspec.yaml`; `google_fonts` is removed and `AppBootstrap.warmFonts` is gone. Never reintroduce network font fetching.
- SIL OFL texts live in `assets/licenses/OFL-<family>.txt` and are registered for the app license page by `AppTypography.registerFontLicenses()` (called from `main()`); add a family to that list when adding a font.
- Telemetry examples: hero eyebrow (`paksha_hero_card.dart`) and the Purnima/Amavasya countdown (`moon_countdown_widget.dart`); festival mantras and daily-wisdom shlokas use the `shloka` tier.

### Flush festival rows on the home cards

The Festivals & Events and Festival Countdowns cards now read as one surface each: rows lost their inner boxes, so long festival titles get the reclaimed width and the lists scan without nested cards.

- `AppTheme.festivalRowDecoration` returns `const BoxDecoration()` for standard rows; only `isSelectedDay` rows keep a borderless accent wash (`alpha 0.08`, radius 14). High Contrast uses `0.18` plus a 1px accent edge, since colour alone cannot carry the selection there.
- Home rows are separated by `InsetRowDivider` (`lib/widgets/inset_row_divider.dart`) indented past the leading tile - `FestivalRowTile.textColumnInset` (60) and `FestivalCountdownTile.textColumnInset` (90) - at `onSurface` alpha 0.08 (0.22 in High Contrast), with no divider after the last row.
- `FestivalRowTile.flush` and the embedded `FestivalCountdownTile` (`showTitle: false`) drop their horizontal padding so the squircle tile/day badge lines up with the card heading; the full-width `InkWell` (radius 14) keeps the whole row tappable.
- Rows that are not on a card keep their own surface through `AppTheme.festivalListRowDecoration` (all-festivals list). The tithi sheet's "festivals on this day" rows are flush with their section header.

### Crisp Daylight (Shukla) surface system

The light theme now reads as crisp white cards on a cool-neutral page with one vermilion accent, instead of warm beige-on-beige layers.

- Palette lives in `AppTheme` (`lib/theme/app_theme.dart`): page `#F5F5F7`, opaque cards `#FFFFFF`, 1px `#E5E5EA` hairline, ink `#111113`, accent `#E84A1B` (deep `#C2410C`, saffron `#FF5A1F`).
- `AppTheme.glassmorphism` and `GlassmorphismConfig.getDecoration` return opaque white + hairline + no `boxShadow` in light; the dark and High Contrast branches are unchanged.
- Moon-countdown and sheet-header/body surfaces are white/flat in light; festival glyph tiles are neutral `#F2F2F7`, so the vermilion glyph is the only colour. Light calendar selected/today states use the accent family.
- The **home-screen paksha hero is the one intentional warm surface**: it keeps the previous peach gradient (`#FFF3E0`→`#FFE0B2`), brown ink, burnt-orange accent, glow, grain and translucent chips via the `homeHero*` helpers; every sheet/detail surface must use the crisp `hero*` helpers instead. `homeHeroDecoration`/`homeHeroGradient`/`homeHeroForeground`/`homeHeroAccent`/`homeHeroChip*` are home-only, and `paksha_hero_card.dart` + `features/hero/widgets/hero_chip.dart` are their only consumers.
- Constraint: do not reintroduce translucent card fills, cream/peach page tints, or card shadows in the light theme. Shadows/glows are dark-theme only (`heroGlow` returns transparent in light, which also keeps the calendar's selected-tile glow off); the home hero's warm glow is separate in `homeHeroGlow`.

## 2026-11-13 - 0.8.1+25

### Edge-to-edge system bars

The app now paints behind the status and gesture/3-button navigation bars instead of leaving an opaque strip at the bottom, and the floating nav bar still clears the gesture handle.

- `MainActivity` opts into edge-to-edge with `WindowCompat.setDecorFitsSystemWindows(window, false)`, transparent status/navigation bars, and `isNavigationBarContrastEnforced = false` (API 29+). `FlutterActivity` is not a `ComponentActivity`, so it cannot call `androidx.activity`'s `enableEdgeToEdge()`.
- `AppBootstrap.initSystem` requests `SystemUiMode.edgeToEdge` on Android (the engine only supports it from API 29; `MainActivity.onPostResume` re-asserts the layout below that).
- `AppTheme.systemUiOverlayStyle(Brightness)` is the single source of bar styling: transparent status/nav colors and divider, contrast scrims off, icon brightness from the theme. `MaterialApp` re-applies it per theme, so the bars stay transparent across palettes.
- `FloatingNavBar` already lifts itself by `MediaQuery.viewPadding.bottom`; with edge-to-edge that is now the real gesture-bar inset, so the capsule sits above the handle rather than under it.
- **Scrolling content must not be inset by the bar.** A `SafeArea` around a scroll view shrinks the _viewport_, so the last row stops exactly at the handle and the bare page background below it reads as a dedicated navigation-bar band even though the bar is transparent. Full-screen bodies therefore use `SafeArea(bottom: false)` and add `AppTheme.navigationBarInset(context)` to the scrollable's own bottom padding (`home_screen`, `all_festivals_screen`, `festival_countdown_screen`, `settings_screen`, `about_screen`, `privacy_policy_screen`, `home_cards_screen`, `moon_phases_screen`, `eclipse_screen`, `schedule_view_widget`, `eclipse_list`).
- `solar_system_screen` is not scrollable but is the same trap: its bottom time panel has a rounded, shadowed surface that must run to the screen edge, so the body uses `SafeArea(bottom: false)` and the panel carries `AppTheme.navigationBarInset(context)` in its own bottom padding instead. Anything positioned relative to that stack's bottom (`_buildZoomControls`) adds the inset back to keep its clearance.
- Sheets and the drawer keep their own `SafeArea`: there the bar sits over an interactive surface, and content behind it would be unreachable.

### Tinted selection and depth in the floating nav bar

The selected destination is now a soft accent wash instead of a solid accent block, and the capsule casts a shadow, so the bar reads as floating above the page rather than laid flat on it.

- `AppTheme.accentTint` (`lib/theme/app_theme.dart`) is the accent at 18% alpha; `AppTheme.onAccentTint` is the accent itself for the label and icon, because the fill is only a wash. Both are generic, not nav-specific.
- High Contrast keeps the solid accent (a tint is what would fail there) and pairs it with `onFestivalAccent`.
- `FloatingNavBar._surface` resolves the pair once per build; `test/floating_nav_bar_test.dart` asserts hue, alpha < 0.5, and the High Contrast fallback.
- The film over the blur is thinner (`floatingOverlayDecoration`: 0.68 light / 0.66 dark, was 0.78 / 0.72) so the backdrop blur is actually visible; those two alphas are the depth-vs-legibility knob.
- `AppTheme.floatingOverlayShadows` is a static two-layer shadow (wide lift + tight contact edge) painted by a `DecoratedBox` **outside** the capsule's `ClipRRect` — inside the film's decoration it would be sliced off. Empty under High Contrast, which keeps the solid fill and strong border instead.
- Tint alpha, film alpha and the shadow list are the knobs; the `BackdropFilter` (sigma 20) stays as-is and is still skipped under High Contrast.

### Major festival cards

The all-festivals list gives its large, information-rich card to the festivals the catalog marks as flagship — the observance windows the event sheet shows, plus the date, tithi and description a scanner needs.

- "Featured" is a curated `featured` flag in `assets/festivals.json` (`Festival.featured`, Hive field 11, read by `Festival.fromJson`), not a category and not a date heuristic: `AllFestivalsScreen` uses `MajorFestivalCard` whenever `festival.featured`. It is date-independent, so a past flagship keeps the card and a whole run (Durga Puja Shashthi→Dasami) stays featured instead of splitting at the first day.
- 20 of 110 records set `"featured": true` today. Everything else, including the other 76 `major` entries, keeps `FestivalRowTile`. Adding one is a **data edit only** — add the flag to the record; `FestivalExportService` round-trips it. Do not re-derive the set from `category` (96/110 are `major`), `displayPriority` (same-day ordering, 7 records) or `visuals.image` (7 records, 6 share `durga_puja.webp`); `test/festival_data_test.dart` guards its size and `test/festival_first_launch_test.dart` proves field 11 survives a Hive round-trip.
- Field 11 is stored as the nullable `featuredFlag` and exposed through `bool get featured => featuredFlag ?? false`. Never read `featuredFlag` directly: null is how a box written before the field existed _and_ a hot-reloaded instance of the class both look, and a non-nullable field turned those into a `Null is not a subtype of bool` crash.
- The artwork square is drawn only when `visuals.image` is set; without artwork the card leads with a 40dp glyph chip instead of spending a quarter of its width on a placeholder icon. The card also carries what the rows had and it had dropped: the tithi by name on the gold date line, a one-line description, and the festival's name in the UI language when the catalog has one.
- Timings are caption-above-value (caption 10.5/55% ink, value 13/w600/92%). The caption used to be the boldest text in the card while the time it labelled sat at 12px/78%, and the old inline form needed a `<220dp` stacked fallback that fired on most phones.
- The "in N days" countdown is a chip in the title row instead of a date-line suffix; a chevron marks the card as tappable; today's card gets an accent hairline (`BoxDecoration.copyWith` on the glass fill).
- `localizedPakshaTithiName` (`lib/utils/tithi_localization.dart`) is the single 1-30 → paksha+phase conversion (15 = Purnima, 30 = Amavasya); reuse it instead of re-deriving `% 15`. Timings use `sheetTimeRange`, `pujaMoonrise` degrades to null, `after_puja_kala` hides the row without a kala, and semantics stay one composed label over an `ExcludeSemantics` body (full description as the hint).
- Lives in `lib/widgets/major_festival_card.dart`; covered by `test/major_festival_card_test.dart` (rows, wording, artwork vs chip, regional name, today border, 320dp + 1.6x text) and the featured cases in `test/all_festivals_screen_test.dart`.

### Festivals cache self-heals after a model change

Upgrading across a festival-model change now starts the app instead of crashing before the first frame; the stored copy is discarded and re-seeded from the bundled catalog when it no longer matches the model.

- `kFestivalCacheSchemaVersion` (`lib/models/festival.dart`) is stored in `festival_settings` under `StorageService.festivalsSchemaKey` (`hiveSchema`). `StorageService.openFestivalsBox()` deletes the cached box _before_ opening it when the marker differs, so an ordinary upgrade never decodes records with the wrong adapter. Bump the constant when a field's type or meaning changes; an additive optional field does not need it.
- Why the pre-check: Hive decodes every record while _opening_ a non-lazy box, and a decode failure is also reported as an unhandled async error (its internal `_openingBoxes` completer has no listener) even when the throw is caught. The `tier` (int) → `featured` (bool) field 11 rename left ints in the previous box and crashed startup exactly that way.
- The box is a rebuildable cache, never a source of truth, so it also self-heals without a marker: a decode failure from `Hive.openBox` is caught, the box deleted and reopened empty, and `FestivalRepository` reseeds 110 records from `assets/festivals.json`.
- The discard retries (3 × 20ms) because Hive releases the failed open's file handles asynchronously and Windows can lose the delete race. If the box still cannot be rebuilt, it falls back to an in-memory box for the session: the catalog renders, and the next launch retries the disk.
- `AppBootstrap.warmVersionInfo()` now swallows its own failure like `warmFonts()`; an optional warm-up must never keep `runApp` from happening. `initStorage()` stays awaited and fatal.
- Regression: `test/festival_cache_recovery_test.dart` covers the schema pre-check (no decode attempted), the decode-failure fallback, and a null stored flag reading as not featured.

## 2026-11-12 - 0.8.1+24

### Borderless floating navigation

The floating navbar now blends into the page without a visible outline.

- Normal palettes keep the translucent fill and blur without a border.
- High Contrast retains its strong border for legibility.
- Shared decoration lives in `lib/theme/app_theme.dart`.

### Festivals card uses the mounted Festivals tab

The home card's "View all" action now opens the same Festivals screen chrome as the bottom navigation tab.

- In the narrow shell, the action selects `HomeTab.festivals`, preserving the mounted list and its scroll position.
- Standalone and wide layouts keep pushing `AllFestivalsScreen` as before.
- The selector is passed from `HomeScreen` to `EventListWidget` (`lib/screens/home_screen.dart`, `lib/widgets/event_list_widget.dart`).

### Drawer is reachable from every tab

Festivals and Countdowns now have the hamburger (and the edge swipe) too, so Sankalpas, Moon Phases, Settings and the rest are one tap away from any destination instead of a detour through Today.

- Both tab screens take `onSelectTab` + `onDrawerStateChanged` like `HomeScreen`; a non-null `onSelectTab` means "hosted as a shell tab", which adds one `AppDrawer` to that Scaffold and puts `AppDrawerButton` (`lib/widgets/app_drawer_button.dart`, shared with `HomeScreen`) in the leading slot. Pushed full-page, the leading slot stays `HapticBackButton`.
- Each tab hosts its own drawer, so `HomeShell` clears `_drawerOpen` on a tab switch: a missed close callback must not leave the capsule hidden on the tab just opened.
- Covered by the `drawer` group in `test/all_festivals_screen_test.dart` (hosted opens the drawer and reports it; pushed has no drawer and no hamburger).

### Drawer destinations switch the shell tab instead of pushing a copy

Picking "Festival Countdowns" in the drawer now selects the Countdowns tab: the capsule highlights it, back returns through Today, and the tab keeps the state it already had.

- `AppDrawer.onSelectTab` (`lib/widgets/app_drawer.dart`) is set by `HomeShell` through `HomeScreen.onSelectTab`; the entry pops the drawer and selects `HomeTab.countdowns`. When it is null (the wide sidebar, and every screen that pushes the drawer on its own) the entry keeps pushing `FestivalCountdownScreen`.
- `HomeTab` (`lib/core/navigation/home_tab.dart`) names the shell destinations so the drawer and the shell never hardcode a tab index.
- Covered by `test/app_drawer_test.dart` (select path asserts no route was pushed; null path asserts a push still starts).

### Re-tapping the selected destination returns its tab to the top

Tapping Today, Festivals or Countdowns while it is already selected scrolls that tab back to its first item, the way every other tab bar behaves.

- `HomeShell._select` bumps `tabRevealProvider(tab)` (`lib/core/navigation/home_tab.dart`), a `StateProvider.family<int, HomeTab>` counter, instead of ignoring the re-tap. Each tab watches its own entry and scrolls itself, because the three tabs disagree on what "the top" is.
- `_HomeBodyState` owns the calendar `CustomScrollView`'s controller; the schedule view keeps its own, so a re-tap there is a no-op. `AllFestivalsScreen` uses its `ItemScrollController` (`ScrollablePositionedList` owns its offset and exposes no `ScrollController`). `FestivalCountdownScreen` is a `ConsumerStatefulWidget` now and shares one controller across its three list variants (only one is mounted at a time).
- Animations use `AppTheme.animationDuration(context, 260ms)`, so Reduce Motion jumps straight to the top.

### Jump to today joins the floating nav bar

On narrow screens the calendar's "jump to today" action now floats beside the navigation capsule on the same baseline, instead of hovering above it, so the two controls read as one bar and nothing floats in the content's way.

- `JumpToTodayButton` (`lib/widgets/jump_to_today_button.dart`) is the single 56dp icon-only action for both hosts; `jumpToTodayVisibleProvider` is the single rule (another month focused, or another day selected) and `goToToday` moves month, date and `tappedCalendarDateProvider` together.
- "Today" is `todayDateProvider` (the app's place-clock day, refreshed at midnight and on a place change), not `DateTime.now()`. That matches the calendar's own seeding _and_ makes the rule re-evaluate at a midnight rollover, when the calendar is left showing yesterday.
- It sits _outside_ the capsule: `FloatingNavBar.trailingAction` is a sibling in the bar's row, and the capsule is `Flexible`, so the action takes width from the capsule (labels shrink/ellipsize) rather than from the screen gutters. `showTrailingAction` opens the slot as one staggered transition (`_TrailingAction`: width first, then the action fades in on the opened space), so the bar re-centres instead of jumping and the button never slides out of a moving clip.
- Shown only on the Today tab; `HomeScreen.showJumpToToday: false` from the shell prevents a second live copy (the wide layout still uses the Scaffold FAB slot).

### Floating bottom navigation capsule

Narrow screens now get a Google-Photos-style floating pill with three top-level tabs (Today / Festivals / Countdowns) that keeps each tab's state instead of pushing and popping screens.

- `HomeShell` (`lib/screens/home_shell.dart`) owns the tab index: the tabs are stacked, each one wrapped in an `AnimatedTabLayer` (`TickerMode` keeps offscreen tabs from ticking), tabs mount on first visit only (`AllFestivalsScreen` resolves ~100 occurrences through the ephemeris and must not run at startup), and back returns to Today before leaving the app (`PopScope`).
- Switching tabs is a transition, not a swap. The incoming tab fades in and slides 24dp from the side the switch is heading towards; the outgoing one slides out the other way but stays fully opaque, acting as the backdrop, so no frame of the switch shows the route behind the pair (fading both left the composite ~25% transparent at the midpoint and cost a second full-screen layer per frame). 250ms through `AppTheme.animationDuration`, so Reduce Motion collapses it. The tabs are a plain `Stack` rather than an `IndexedStack` because both have to be on screen at once; the contract the `IndexedStack` gave is kept - only the visible tab is painted, hit-testable, focusable (`ExcludeFocus`) and exposed to accessibility services, and every tab stays in the tree with its scroll offset, search text and filters intact. `AnimatedTabLayer` (`lib/widgets/animated_tab_layer.dart`) never rebuilds the tab's content while it animates, a switch that interrupts another one continues from where it had got to instead of snapping (a tab demoted mid-slide fades out, one whose exit already finished snaps, since it is covered by then), and the exit is complete when the slide ends - tracked on the offset controller, not on opacity.
- The bar (`lib/widgets/floating_nav_bar.dart`) is presentation-only: every destination paints its label, and the selected one adds its icon inside an accent-tinted pill. The capsule is content-sized (`Center` + `Row(mainAxisSize: min)`), so it is only as wide as the three options need, centred, and clamped to `screen - 2 * margin`. Widths are resolved per destination (`_resolveSlots`) from one `TextPainter` per label per build: the parts that cannot shrink (horizontal padding, the selected icon) are reserved first, then the remainder is split by measured label width, so a clamped bar can never hand a pill less than its own padding/icon (the previous flex weights could overflow at large text scales). A still-too-narrow bar drops the icon before it eats label space, and the last slot absorbs the rounding remainder.
- Each destination is a single semantics node (`button`, `selected`, label) that owns its tap action, with `excludeSemantics` so the painted label is announced once. The action must be declared on that node: excluding descendants also drops the inner `GestureDetector`'s own semantics action.
- The capsule is deliberately slim: 56dp tall around a 44dp pill, so only 6dp of film sits above and below it and the bar reads as the pill's backing rather than a band of empty air. The tap target is the whole capsule (each slot is its full height), so the pill does not have to be the 48dp minimum. The corner radius is `height / 2` (a stadium) and is passed to both the clip and `AppTheme.floatingOverlayDecoration`; `height` / `_pillHeight` are the two knobs, and `reserve` (tab scroll padding, FAB and snackbar lift) follows `height` automatically.
- Rebuilds stay local. `HomeShell` caches each tab's widget instance (mounted tabs keep state but do not rebuild on a tab switch), memoizes the snackbar `ThemeData`, and watches `jumpToTodayVisibleProvider` in a `Consumer` around the bar, so selecting a date no longer rebuilds all three tabs.
- `FloatingNavBar.capsuleKey` marks the painted capsule (the bar's own box spans the screen so it can centre the capsule) — use it, not `FloatingNavBar`, to measure or assert width.
- All transitions route through `AppTheme.animationDuration`.
- The capsule is a real overlay: `AppTheme.floatingOverlayDecoration` keeps the film translucent in every palette (Pure Dark's `glassmorphism` would be opaque and read as a docked footer) and the widget adds a `BackdropFilter` blur, skipped under High Contrast.
- The film carries a tonal lift (10% white into `colorScheme.surface` dark, 4% primary into white light) so it reads above both the page and the card fill: Pure Dark's bare surface at 62% came out darker than its `#1E1E1E` cards, reading as a hole.
- Nothing shrinks the tab viewport. Each tab takes a `bottomContentInset` (`HomeShell` passes `FloatingNavBar.reserve`) for scroll padding only, so content scrolls _under_ the pill; the home FAB is lifted by the same value, and floating snackbars get it via a `snackBarTheme.insetPadding` override in the shell.
- Narrow screens only: at >= 900dp (`ResponsiveLayout.tabletBreakpoint`) the shell returns `HomeScreen` unchanged, keeping the 280px sidebar as the only navigation.
- The bar hides while `HomeScreen`'s drawer is open (`HomeScreen.onDrawerStateChanged`), since the drawer paints inside that Scaffold, below the shell's overlay.
- Labels are single short nouns (`navToday` / `navFestivals` / `navCountdowns`) in en/hi/bn/sa. They are always painted; when the capsule is clamped to a narrow screen (or the app's 1.3x large-text scale), each label shrinks inside its measured share and ellipsizes instead of overflowing.

## 2026-11-06 - 0.8.1+23

### Shukla body uses a neutral off-white instead of warm cream

The light theme's page background is a flat `#FAFAF6`, so the orange primary reads as an accent on a neutral surface instead of tinting the whole screen.

- `AppTheme.shuklaBackground` is the single source: `scaffoldBackgroundColor` and the app bar background build from it, and `backgroundDecoration` returns it flat for light mode.
- The light ambient gradient is gone (the amber wash composited the body back to cream at any visible alpha); the violet gradient is now dark-theme only. Hero peach cards and the accent palette still carry the warmth.
- Dark (Krishna / Pure Dark) themes unchanged; high-contrast light still flattens to pure white via the scaffold color.
- Where: `lib/theme/app_theme.dart`.

### Theme switching no longer flashes the Krishna palette

Picking a theme now swaps in one frame; the app never paints plum/purple "in between" on the way from Shukla to Dark (or when the OS flips auto mode).

- MaterialApp was cross-fading `ThemeData` over 200ms; `ThemeData.lerp` flips `brightness` to dark at t=0.5 while `scaffoldBackgroundColor` is still mid-grey, so `AppTheme.isPureDarkTheme()` (scaffold == black) failed and every brightness-aware helper fell through to the Krishna branch.
- `themeAnimationDuration: Duration.zero` on the root `MaterialApp` (main.dart) — the three palettes have no meaningful midpoint.
- Constraint: keep theme variant detection out of interpolated `ThemeData`; if a theme animation is ever reintroduced, it needs an explicit palette id instead of `scaffoldBackgroundColor == Colors.black`.

## 2026-10-30 - 0.8.1+22

### Panjika switch keeps the home screen alive

Switching between Bisuddhasiddhanta and Suryasiddhanta now recomputes the home screen and calendar in place instead of leaving them blank until a restart.

- `panchangInitProvider` now **watches** `panchangServiceProvider`: a school switch replaces the service with a new, uninitialized instance, so the init future must be invalidated with it. Reading the service kept serving the previous instance's completed init; downstream computations then threw `PanchangService not initialized`, the hero fell back to its skeleton and the festival card said "No festivals".
- Calendar month/header providers, the tithi sheet, the schedule label and `upcomingFestivalsProvider` watch the school (or the shared init), so their cached families recompute. The tithi/nakshatra/yoga-karana timing families, the moon-phase providers and festival export await the shared init instead of calling `service.init()` themselves.
- Sync caches are school-keyed: `festivalMonthPrecacheKey`, `secondaryCacheKey`, `monthPrecacheKey`, `adaptiveNavKey` and the persisted adaptive signature in `lib/features/calendar/data/calendar_caches.dart`, plus `headerCacheKey` in `header_builders.dart`. Without the suffix the instant stale fallback showed one school's labels, headers and nav targets under the other.
- Regression: `test/panchang_school_switch_test.dart` initializes the first service, swaps the school and asserts the replacement is initialized; it fails if the init goes back to `read`.

### Durga Puja 2026 keeps its two-sunrise days under both Panjika systems

Durga Puja resolves to the reference dates instead of gaining an extra Saptami (Bisuddha) or Ashtami (Surya Siddhanta) day.

- New per-rule `dominant_tithi` (`"grace"` default, `"strict"` opt-out) in `PanchangRules` (`lib/models/festival.dart`, Hive field 15 with `defaultValue: 'grace'`). `PanchangData.fromRawTithi` skips the 60-minute dominant-tithi grace window for `strict` rules; everything else is unchanged.
- The five `*_durga_puja` entries in `assets/festivals.json` are `"dominant_tithi": "strict"` with `vriddhi` left at the default `"both"`. `saptami_durga_puja` no longer carries `vriddhi: "second"` — Surya Siddhanta Saptami is a real two-sunrise run and must stay on both days.
- Result: Bisuddha Shashthi Oct 16 + 17, Saptami Oct 18 only; Surya Siddhanta Shashthi Oct 16 only, Saptami Oct 17 + 18. Ashtami Oct 19 through Dashami Oct 21 under both.
- Regression: `test/durga_puja_2026_test.dart` pins both day maps from the supplied tithi boundaries and proves the grace path would have added the spurious day.

## 2026-10-28 - 0.7.20+21

### Surya Siddhanta Panjika system

Settings now offers Bisuddhasiddhanta and Suryasiddhanta; the selected system drives the Panchang and the Bengali calendar.

- `PanchangSchool` (`lib/models/panchang_school.dart`) is persisted by name under `panchang_school`; missing/unknown values fall back to `bisuddha`, so existing installs keep the current behaviour.
- All Sun/Moon reads go through `PanchangEphemeris` (`lib/services/panchang/ephemeris/`): Drik uses Swiss Ephemeris + Lahiri, Surya Siddhanta uses the pure-Dart mean-motion engine with only the manda correction.
- `PanchangProfile.school` is part of `cacheKey`; `kPanchangCalculationVersion` is now **4** and `schemaVersion` **2**. `locationSignature`, the Bengali month/date caches and every process-local cache in `PanchangService` (`_tithiCache`, `_sunLongitudeCache`, `_lunationVerdicts`) key on the school, so a switch cannot serve the other system's days. `_lunationVerdicts` is a `static` map that decides **masa and adhika**, i.e. the Hindu and Bengali month names, so leaving it unkeyed showed the previous school's month for up to 8 lunations after a switch; `clearCaches()` now drops it as well.
- The Surya Siddhanta engine is the classical text (`SuryaSiddhantaTuning.classical`): mean motions plus the manda correction, no sighra iteration. `tool/surya_siddhanta_probe.dart fit` solves the six calibration parameters; against the modern ephemeris it reaches ~1.4 degrees RMS over 1900-2100.
- **`kSuryaSiddhantaTuning` in `surya_siddhanta_engine.dart` is the single paste point for a calibration.** It is the default for both `SuryaSiddhantaEngine` and `ephemerisFor`, so one edit reaches the panchang, the Bengali calendar and the notification isolate. It now ships **calibrated** against a New Delhi Surya Siddhanta panjika (see the last two bullets); leaving it at `SuryaSiddhantaTuning.classical` means "uncalibrated".
- Calibration workflow without a reference database: `tool/surya_siddhanta_probe.dart check <date> --tithi ... --ends HH:MM --csv` per date, ~10 dates over 10+ years, then `fit` the collected CSV. A printed **limb end time** is the sharpest datum (it pins the limb to an exact degree); a limb _name_ is only a 12-degree bin. All times are read as IST, not machine-local, so results do not depend on the developer's timezone.
- `fit` freezes the Sun when the references are tithi-only: elongation rows cannot see the absolute frame, and letting both epochs move leaves a null direction that pushes the fit hundreds of degrees from the text. Nakshatra or yoga **end times** do see the absolute frame, so those unfreeze it.
- `fit` searches 24 lunar-apogee starting points, because a single Gauss-Newton start lands in a local minimum: the apogee longitude is periodic in the residual, so the linearised step overshoots and gets clamped. On the New Delhi reference file this was the difference between 3.7 and 0.003 degrees RMS.
- The manda correction is applied as a **magnitude** with the quadrant choosing the sign. Feeding an already-signed jya into the quadrant rule inverts the equation over the half orbit from perigee back to apogee; that bug was worth up to 10 degrees for the Moon and is locked by `test/surya_siddhanta_engine_test.dart`.
- Sunrise, sunset, moonrise and moonset still come from Swiss Ephemeris, so Surya Siddhanta mode is SS lunar limbs on modern solar events - not a faithful reproduction of a panjika that computes its own sunrise. Sankranti is _not_ in that list: it is solved from the ephemeris, so the Bengali month and the Hindu masa do follow the school.
- The background notification isolate reads the same preference and sets `activePanchangSchool` before computing.
- **Calibrated against a New Delhi Surya Siddhanta panjika.** The tuning is fitted to 26 tithi and nakshatra end times for New Delhi from `tool/reference/surya_siddhanta_delhi_2005_2026.csv` (2005-2026) and then checked against 15 **yoga** end times held out of the fit (`..._yoga.csv`). All 41 boundaries reproduce to within 0.005 deg, the rounding limit of the source's own times. The fitted bijas are all under ~1.1 arcsec/year, i.e. the source applies no drift correction - traditional siddhantic arithmetic - and this engine is the same model. The **bisuddha** option is the Drik Ganita school (Swiss Ephemeris + Lahiri, observationally drift-corrected) and therefore misses the same boundaries by 1-3 degrees; that is the difference between the two schools, not a defect in either. `verify <reference.csv>` is the regression check for the shipped tuning and exits non-zero above 0.01 deg.
- **The reference source is not a printed Gupta Press page.** It is a Surya Siddhanta panjika for New Delhi (values agree with Drik Panchang's Surya Siddhanta mode) whose sunrise is _modern_: the app's Swiss Delhi sunrise reproduces all 15 of its sunrises to 0 minutes, while Kolkata is off ~45 min. So 0.005 deg measures agreement with the same arithmetic, and it validates the engine against a Surya Siddhanta source, not against the printed page. For the same reason **siddhantic sunrise is deliberately not implemented** - it would move the app away from this source. Sunrise/sunset/moonrise/moonset and everything derived from them (udaya-tithi labelling, Rahu kalam, Yamaganda, Gulika, Abhijit, Choghadiya, Hora) stay modern; sankranti and the Bengali month _do_ follow the school, since they are solved from the ephemeris.
- `test/panchang_school_dispatch_test.dart` guards the seam _between_ the schools, which no single-school test can: it asserts `ephemerisFor` returns the implementation the school names (distinct `tag`s, so cache keys cannot collide), that the two disagree by >0.2 deg of Sun and >0.5 deg of Moon at one instant, that `suryasiddhanta` lands within 0.01 deg of a reference tithi/nakshatra boundary while `bisuddha` misses it by >0.2 deg, and that the SS path is geocentric (same result for Delhi and Kolkata).

### Nishita observances never disappear

A `timingOverride: nishita` festival now always finds a day, instead of vanishing for a whole year when its tithi ends between sunset and the Nishita window.

- Symptom: `findNextFestivalOccurrence` returned `null`, so Janmashtami 2025/2026/2035 were missing under Suryasiddhanta (SS ends Krishna Ashtami 2026-09-04 at 23:03 IST, 54 min before the 23:57 window opening) and Maha Shivaratri 2031 was missing under **both** schools (it also skipped a year in 2041).
- The fallback matches on the sunset sample, but **only** when the same tithi did not already cover the _previous_ night's window - otherwise a ~20 h tithi still runs at the next sunset and every observance becomes two days. Measured: the naive "accept sunset" rule changed 27 of 96 nishita festival-years; this rule changes 4, all of them the previously-empty ones, with 0 empty and 0 new multi-day runs.
- New `PanchangCheckpoints.previousNishita` = `sunrise - 8/15 night` (the previous night's Nishita opening; the two nights differ by under 2 min, so it costs no extra solar call), sampled into `PanchangCheckpointTithis.previousNishita` and passed as `PanchangData.fromRawTithi(rawTithiPreviousNishita:)`. Both matching seams carry it - `projectPanchangDay` (scan, grid flags) and `TithiCheckpoints`/`computePanchangData` (grid, day detail) - so the scan cannot find a date the grid leaves blank.
- Files: `panchang_day.dart`, `panchang_day_resolver.dart`, `panchang_day_projection.dart`, `tithi_transitions.dart`, `panchang_data.dart`. Regression tests: `test/panchang_data_test.dart` ("Nishita window matching") and `test/festival_occurrence_scan_test.dart` (Janmashtami 2026 under SS, through `computePanchangData`).

---

## 2026-10-26 - 0.7.20+21

### Sankranti transit matching and punya kala

Makar Sankranti and Pongal now fall on the Sun's actual ingress day and show the traditional punya kala.

- `sankranti: "Makara"` matches the ingress day; an after-sunset ingress moves the observance to the next day (Drik rule).
- `puja_kala: "punya_kala"` shows 40 ghatis from the transit, clipped to daylight; a shifted observance starts at sunrise.
- `solarDate` stays as the fallback for callers that skip the ingress search, and a computed day with no ingress never falls back.
- The ingress search runs only when a festival declares `sankranti`, so ordinary months pay nothing.
- Files: `panchang_day_resolver.dart` (`_sankranti`), `panchang_data.dart`, `puja_samay.dart`, `assets/festivals.json`.

### Bhadra-free puja windows

Raksha Bandhan's puja window now avoids Bhadra (Vishti karana).

- `avoid_bhadra: true` trims the kalam to the Bhadra-free part, falls back to Pradosha when the target window is covered, and hides the card if neither has 12 usable minutes.
- Bhadra windows are solved from karana crossings only when a matched festival asks, so other days pay nothing.
- Files: `lib/features/panchang/domain/bhadra.dart`, `puja_samay.dart`, `tithi_transitions.dart`, `assets/festivals.json`.

### Godhuli puja kala

Tulsi Vivah now shows its Godhuli (cow-dust hour) window instead of aparahna.

- `puja_kala: "godhuli"` spans sunset to sunset + one day-ghati (D/30).
- Files: `assets/festivals.json` (`tulsi_vivah`), `puja_samay.dart`.

## 2026-10-26 - 0.7.20+21

### Purvahna and Aparahna observance windows

Festival matching and Puja Samay cards now support the forenoon and afternoon
observance checkpoints.

- `purvahna` samples the tithi at one quarter of daylight after sunrise.
- `pujaKala: "purvahna"` spans sunrise to midday; `"aparahna"` spans the
  third-to-fourth fifths of daylight.
- The canonical day resolver, cached transition path, labels, and authoring
  documentation use the same checkpoint names.

## 2026-10-26 - 0.7.20+21

### Arunodaya timing checkpoint

Festival rules may use `timingOverride: "brahma_muhurta_start"` or
`"arunodaya_start"` for the two pre-sunrise checkpoints.

- Brahma Muhurta starts at sunrise minus two fifteenths of the night; Arunodaya
  starts at sunrise minus one fifteenth.
- Matching, checkpoint sampling, labels, profile configuration, and festival
  authoring documentation use the same checkpoint.

### Sayahna and Chandrodaya checkpoints

Festival rules may use the three Sayahna positions or `chandrodaya` for
the Moonrise checkpoint.

- Sayahna uses the fifth daylight part: start at `S + 4D/5`, center at
  `S + 9D/10`, and end at sunset.
- `chandrodaya` is an alias of the existing native Moonrise checkpoint.
- The observance-rule banner reads its valid checkpoints from
  `timingOverrideCheckpoints`, so the alias renders as moonrise instead of
  falling back to sunrise.

## 2026-10-26 - 0.7.20+21

### Pradosh timing overrides

Festival rules may use `timingOverride: "pradosh"` to evaluate the tithi at
the Pradosh dusk checkpoint.

- Keeps the existing `pradosha` spelling valid for shipped festival data.
- Applies the alias consistently to festival matching, checkpoint resolution,
  labels, and authoring documentation.
- `pujaKala` accepts both spellings too, so a dusk Puja Samay card renders
  whichever one the data uses.

## 2026-10-25 - 0.7.20+21

### Jyotish native-state and edge-case hardening

Concurrent native calculations remain isolated, and boundary longitude/time inputs
produce consistent results across package and app services.

- All direct Swiss Ephemeris consumers, including eclipse and rise/set services,
  use the process-wide native lock.
- Julian-day conversion preserves microsecond precision, matching cache identity.
- Zodiac, sign-position, and nakshatra accessors normalize negative longitudes.

### Vedic charts honour the requested house system and sidereal frame

`calculateVedicChart(houseSystem:)` now calculates and labels the system the
caller asks for, with cusps and angles taken directly from the sidereal engine.

- `swe_houses_ex` is bound with `SEFLG_SIDEREAL`; `EphemerisService.calculateHouses`
  accepts optional `CalculationFlags`, sets the ayanamsa mode, and no longer
  forces Placidus or subtracts ayanamsa from cusps/ascendant/MC. Without flags
  the method keeps its historical tropical result.
- `VedicChartService` validates the house code and labels the result (`Whole
Sign`, `Placidus`, ...). 'G' (Gauquelin) stays unsupported because it writes 36
  cusps into the standard 13-element buffer.
- Sidereal equatorial planet requests (`useEquatorial` without `useTropical`)
  are rejected: ayanamsa is an ecliptic offset, not a right-ascension offset.
- Dignity lives in `lib/src/services/planetary_dignity.dart`: Venus debilitation
  is 177° (27° Virgo), Jupiter is 275° (5° Capricorn), and degree-based
  moola-trikona is evaluated before generic own-sign dignity.
- `GeographicLocation` rejects non-finite coordinates/altitude and invalid DMS
  components; chart location strings now use N/S/E/W. Tests in
  `packages/jyotish/test/{houses,planetary_dignity,geographic_location,equatorial_frame}_test.dart`.

### Ephemeris provenance and loaded data ranges are visible

A missing `.se1` file no longer hides behind a position that looks like Swiss
Ephemeris output, and startup can verify the range the library actually opened.

- `PlanetPosition.provenance` records the requested and actual backend, the
  native return flags and any warning; `usedFallback` is true for Moshier.
- `CalculationFlags(requireSwissEphemeris: true)` throws
  `EphemerisBackendException` instead of returning a fallback, including when a
  cached fallback is reused.
- `Jyotish.probeDataRange()` / `EphemerisService.probeDataRange()` bind
  `swe_get_current_file_data()` after a Sun/Moon probe and report each file's
  actual 1800-2399 (or other) range. The package reports ranges; the app owns
  the expected-year policy.
- `Jyotish.initialize()` and `EphemerisService.initialize()` share one in-flight
  future, allow retry after failure and cancel cleanly on `dispose()`. Each
  isolate still initializes its own instance; native state is process-global.
- App startup checks `kEphemerisExpectedStartYear/EndYear` and the on-device
  smoke test asserts the loaded range and a Swiss provenance.

### Ephemeris batches, typed cache and opt-in native sidereal

Panchang Sun/Moon work runs as one batch, cached positions can no longer mix
frames, and callers can ask Swiss Ephemeris for native sidereal longitude.

- `EphemerisService.calculatePlanetPositions` and `calculateSunMoon` replace
  the `Future.wait` pseudo-parallelism: global state is applied once, one
  native error buffer is reused, and cached planets are skipped. Exposed as
  `Jyotish.getSunMoonPositions`; `PanchangService.calculateTithi` and
  `calculateSunMoonLongitudes` use it.
- Position cache keys are typed (`_PositionCacheKey`): exact instant, flags,
  ayanamsa and `EphemerisService.calculationVersion`; latitude/longitude/
  altitude only for topocentric requests, so geocentric results ignore the
  observer. `clearCache()` is exposed on the service and `Jyotish`;
  `dispose()` clears it.
- `CalculationFlags.useNativeSidereal` (plus `nativeSidereal()`) sets
  `SEFLG_SIDEREAL`, checks the returned flag and skips the Dart ayanamsa
  subtraction. The default remains the historical manual path until charts
  adopt it; native + tropical is rejected.
- `SiderealMode.label` replaces the shadowing `name` field, so `.name` is the
  stable enum identifier again; `persistenceKey` exposes the Swiss integer.
  Display labels are never persisted.
- `jyotish-js/` is marked private and documented as an incomplete scaffold,
  not part of the Dart API or CI.
- Tests: `packages/jyotish/test/{native_sidereal,position_cache}_test.dart`.

## 2026-10-23 - 0.7.20+20

### Licensing resolved: AGPLv3, with install docs that match

The project is now explicitly AGPLv3 end to end, and consumers are told how to
get the fixed package instead of the unfixed upstream one.

- Root `license`, `packages/jyotish/LICENSE` and the READMEs are AGPLv3; the
  upstream wrapper's MIT text is kept in
  `packages/jyotish/LICENSE-MIT-upstream` and still covers the upstream
  portions of the code. The choice is recorded (2026-10-25) in
  `packages/jyotish/NOTICE`.
- `publish_to: none` stays because the `jyotish` name belongs to the upstream
  pub.dev package, not because of the license; `packages/jyotish/README.md`
  installs it as a git dependency on `1arunjyoti/Tithi-App` with
  `path: packages/jyotish`.
- The unused prebuilt `native/swisseph/swisseph-master/libswisseph.dylib` was
  deleted: AGPL binary, unclear provenance, and no build target referenced it.

### Ephemeris assets are checksum-verified before and after install

A corrupted or mismatched `.se1` now fails on launch with a clear message
instead of surfacing later as an opaque `swe_calc` error.

- `kEphemerisAssetSha256` (`lib/services/panchang_init/panchang_init.dart`) is
  the build manifest: the installer checks the bundled asset before copying it
  and the installed copy on every launch, on top of the size + `SWISSEPH`
  header check.
- Replacing a file in `assets/ephe/` without updating the manifest fails
  `test/panchang_init_test.dart`, which recomputes the hashes from disk.
- `copyEphemerisFiles` takes `sha256ByFile` (defaults to the const manifest) so
  tests can install synthetic bytes.

### A failed ephemeris install is visible on every screen

The error banner moved out of the home body and above the navigator, so pushed
screens and dialogs show it too.

- `PanchangInitFailureOverlay`
  (`lib/widgets/panchang_init_failure_overlay.dart`) is mounted from
  `MaterialApp.builder`: it returns the app untouched when init succeeds, and on
  failure puts `PanchangInitErrorBanner` above it and removes the status-bar
  inset the banner covers so an app bar does not pad twice.
- The home-only `PanchangInitErrorBanner` in `lib/screens/home_screen.dart` is
  gone; retry still invalidates `panchangInitProvider`.
- Tests: `test/panchang_init_failure_overlay_test.dart`.

### CI builds the native engine and gates analyze + tests

Every push and PR now runs the analyzer and the full suite with a real Swiss
Ephemeris library instead of failing on a host without one.

- `.github/workflows/ci.yml` compiles the nine C sources from
  `packages/jyotish/native/swisseph/swisseph-master/src` with
  `gcc -shared -fPIC`, exports `SWISSEPH_LIB_PATH`, pins `TZ=Asia/Kolkata`,
  then runs `flutter analyze`, `flutter test` and the package's own tests.
- Keep that file list in sync with `SWISSEPH_SRC` in
  `packages/jyotish/android/src/main/cpp/CMakeLists.txt`.
- `swisseph_bindings.dart` no longer contains a hardcoded developer macOS path;
  off Android the supported route is `SWISSEPH_LIB_PATH`, then the platform
  loader.
- The analyzer baseline is 0 issues, which is what lets the gate exist.

### A broken native engine fails startup instead of silently approximating

If the native Swiss Ephemeris library does not load, the home screen now says
so and offers a retry instead of quietly showing 1-3 minute approximations as
real sunrise/sunset/moonrise times.

- `ensureNativeEngineInstalled` (`lib/services/panchang_init/panchang_init.dart`)
  throws `EphemerisEngineException` when `SolarEventsService` or
  `MoonEventsService` failed to install its native calculator. It only throws on
  `kNativeEnginePlatforms` (Android); the other platforms keep the documented
  approximation.
- `PanchangService.init` calls the guard after both `configureSwiss` calls;
  each service now records `nativeSetupError` instead of only logging.
- `PanchangInitErrorBanner` renders any `PanchangInitException`, so the engine
  message replaces the generic error copy.
- Tests: guard cases in `test/panchang_init_test.dart`, banner copy in
  `test/panchang_init_error_banner_test.dart`.

### Moonset is locked in the golden fixture

The tithi sheet's moonset chip now has the same regression lock as moonrise.

- Fixture schema 3 adds `moonset` to 83 of the 84 cases (native
  `swe_rise_trans`, `PanchangProfile.standard`); `varanasi-2026-02-24` omits it
  as a genuine no-set day and the engine test falsifies that null the same way
  as the no-moonrise case. No existing value changed.
- `test/moon_events_test.dart` asserts `upperLimb` vs `lowerLimb` moonset differ
  by minutes, pinning the limb policy to an instant rather than only a bit.
- `GoldenExpected.moonset` + `validateGoldenStructure` require an explicit
  offset and the case's civil date.

### Tithi sheet and export times are second-precise, and the lock is tightened

The tithi detail sheet and the festival export now show the same second-precise
boundaries the day pipeline uses, instead of a value rounded to the minute.

- `resolveTithiSpan` (`lib/features/panchang/domain/tithi_span.dart`) is the one
  tithi-span resolver: outward scan from the festival day (2 h steps, ±2 days),
  both edges through `solveAngleCrossing`, null for a Kshaya tithi or a failed
  sample. `tithiTimingsProvider` and `FestivalExportService` both call it;
  `PanchangService.calculateTithiStartTime` / `calculateTithiEndTime` /
  `_findNearestTithiOccurrence` are deleted.
- The 78 non-null `tithiEndsAt` values in the golden fixture were recaptured.
  The old ones came from the 1-minute bisection and stored up to 50 s of
  cross-city spread for one global instant; they now agree to the second.
- `test/panchang_golden_fixture_test.dart` asserts that cross-city agreement
  (≤ 2 s), so a location-dependent path cannot come back silently.
- `test/panchang_golden_engine_test.dart` now proves a locked `moonrise: null`
  is a real no-rise day: both neighbouring days must have a rise and their gap
  must exceed 24 h.
- `delhi-1800-01-01` `moonrise` is written at `+05:30` like every other
  timestamp; it was the only value on truncated LMT `+05:53`, which parsed 20 s
  off the unchanged instant.

### Nakshatra edges and Sankranti instants are locked in the golden fixture

The Panchang regression lock now covers the sunrise nakshatra's edges and the
next solar ingress, so a solver change can no longer silently move "Rohini
until 3:42 PM" or the Bengali month boundary.

- `resolveNakshatraSpan` (`lib/features/panchang/domain/nakshatra_span.dart`)
  owns the span math that used to be inline in `nakshatraTimingsProvider`; the
  provider is a thin wrapper and `bisectNakshatraEdge` moved with it.
- Fixture schema 2 adds `nakshatraStartsAt`, `nakshatraEndsAt`, `nextNakshatra`
  and `nextSankranti {rashi, at}` to all 84 cases. No existing value changed;
  the recapture is recorded in the fixture `source.notes`.
- `rashiNames` (`lib/models/hindu_month_system.dart`) is the canonical
  Mesha..Meena list, kept next to `sunRashiIndex`.
- Tests: `test/panchang_golden_engine_test.dart` recomputes both through the
  production path; `test/panchang_golden_fixture_test.dart` checks the
  successor nakshatra, the 18-30 h span, and that the ingress rashi follows the
  locked sunrise Sun.

### Precise new-moon and Bengali month-start failures

A new moon or Bengali month start that cannot be resolved now fails visibly
instead of silently shifting by half a day and potentially flipping the Adhika
month.

- `resolveNewMoonInstant` (`lib/features/panchang/domain/panchang_crossings.dart`)
  retries the bracket at ±7 days; `_refineNewMoonInstant` then throws
  `CrossingResolutionException`. The old "best of seven noons" fallback
  (±12 h) is gone.
- Bengali month starts now resolve through `resolveBengaliMonthStart`
  (`lib/services/bengali_calendar/bengali_month_start.dart`), a pure function
  over a Sun-longitude sampler. It routes through `findSankrantiInstant` (so
  the tested helper is the production path), keeps the 35-day guard scan, and
  throws `BengaliMonthStartException` instead of using the Apr-14
  approximation.
- `solveRoot` is documented as upward-only (a descending crossing returns
  null). New tests: `test/bengali_month_start_test.dart`,
  `test/nakshatra_edge_test.dart`, plus widening/failure and descending cases
  in `test/root_solver_test.dart`.
- Deferred at the time: fixture values for nakshatra edges and Sankranti
  instants. Closed by the schema-2 recapture above ("Nakshatra edges and
  Sankranti instants are locked in the golden fixture").

### Yoga and karana spans use the shared solver

The tithi detail sheet's "until 3:42 PM" yoga/karana times are now solved by
the same crossing primitive as tithi and nakshatra, so they are second-precise
instead of minute-rounded.

- `resolveYogaKaranaSpan`
  (`lib/features/panchang/domain/yoga_karana_span.dart`) solves the continuous
  Sun+Moon sum (yoga, 27 segments) and elongation (karana, 60 segments of 6°)
  through `solveAngleCrossing`, including the 360→0 wrap for the last segment.
- `yogaKaranaTimingsProvider` (`lib/providers/panchang_provider.dart`) is now a
  thin wrapper; the provider-local index bisection is gone.
- `test/yoga_karana_span_test.dart` covers both ends, the wrap and the
  hide-on-null failure paths.
- Corrects the Phase 3 note that claimed yoga/karana had no consumer: the
  tithi detail sheet has shown these spans all along.

### Ephemeris install fails loudly instead of silently

The app now verifies its bundled Swiss Ephemeris data and explains what to do
when it is missing or corrupt, instead of showing an empty calendar.

- `lib/services/panchang_init/panchang_init.dart` checks each installed `.se1`
  file (at least 1 KB and a `SWISSEPH` header), re-copies anything that fails,
  and writes through a `.part` file plus rename so an interrupted first launch
  cannot leave a truncated file that looks valid on the next run. A missing or
  corrupt bundled asset throws `EphemerisAssetException` with a reinstall
  instruction instead of a bare `Unable to load asset`.
- `PanchangInitErrorBanner` (`lib/widgets/panchang_init_error_banner.dart`) is
  mounted at the top of the home body and shows that message with a Retry that
  invalidates `panchangInitProvider`. The calendar still degrades to an empty
  month by design; the banner is now the explanation.
- Tests: `test/panchang_init_test.dart` (valid, truncated, zero-byte,
  wrong-header, atomicity, missing/corrupt asset) and
  `test/panchang_init_error_banner_test.dart` (message, generic fallback,
  retry). `integration_test/native_ephemeris_smoke_test.dart` is the on-device
  check that the assets install, `libswisseph.so` loads, and both native
  rise/set calculators are active.
- Package metadata: `packages/jyotish` declares Android as its only native
  platform, has `publish_to: none`, an Android CMake path relative to the
  package root (a debug APK now contains `libswisseph.so` for all three
  declared ABIs), and a `NOTICE` recording the unresolved Swiss Ephemeris
  AGPL-or-commercial license choice. Desktop and iOS native builds remain a
  documented follow-up.

### Native moonrise and moonset

Moonrise and moonset now come from Swiss Ephemeris instead of a truncated
pure-Dart lunar series, so the instants that decide Karva Chauth's puja and
paran are no longer 1-3 minutes out.

- `MoonEventsService` (`lib/services/moon_events_service.dart`) mirrors the
  solar seam: a `MoonEventCalculator` strategy, a bounded cache, a published
  place zone, and a labelled `ApproximateMoonEventCalculator` fallback for
  platforms without the native library. `moonEventsService` is the global.
- The native calculator deliberately does **not** use `SE_BIT_HINDU_RISING`:
  that bit drops ecliptic latitude and parallax, which move a lunar rise by up
  to an hour. Rise/set is topocentric and apparent, with limb/refraction from
  `PanchangProfile.lunarLimb` / `lunarRefraction` (`upperLimb` + `standard`
  refraction by default). `SE_BIT_DISC_BOTTOM = 2048` was added to the
  bindings for the lower-limb policy.
- `swe_rise_trans` only searches forward, so a result is discarded unless it
  falls on the requested civil day. That check is what keeps "no moonrise
  today" as null instead of silently returning tomorrow's rise;
  `findPreviousRise` / `findNextSet` keep the prevailing-event fallback.
- Cost: one synchronous FFI call per event. Measured ~394 µs/day uncached and
  ~11 µs/day cached, against ~898 µs/day for the approximation it replaces, so
  the tithi sheet does not regress.
- Wired through `PanchangService.init` / `clearCaches`,
  `PanchangDayResolver` (injectable `moonEvents`), `event_detail_sheet`
  (observance input), `tithi_detail_sheet` (chips) and
  `SolarEventsService.checkpointTimeFor('moonrise')`, so no remaining code
  path can return the approximation for an observance. `MoonriseCalculator`
  survives only as the fallback delegate.
- Golden fixture `moonrise` values were recaptured under the new convention:
  83 values, 27 moved more than the 60 s tolerance, range -120 s to +120 s.
  `source.notes` records old result, new result and reason.

### Precise crossing solver (tithi, nakshatra, new moon, Sankranti)

Tithi and nakshatra edges, new moons and Sankranti ingresses are now solved to
the second, and the Adhika-masa verdict no longer changes from day to day inside
one lunation.

- `solveRoot` / `solveAngleCrossing` (`lib/features/panchang/domain/root_solver.dart`):
  one bisection for every cyclic crossing, 1 s default tolerance. It verifies
  the bracket up front (residual `<= 0` before, `> 0` after) and returns null
  instead of a plausible-looking wrong instant.
- `findNewMoonInstant` / `findSankrantiInstant`
  (`lib/features/panchang/domain/panchang_crossings.dart`): estimate -> daily
  sample bracket -> solve. `_refineNewMoonInstant` used to stop at ~±3 h, which
  is enough to put a new moon on the wrong side of a Sankranti.
- `findSunriseTithiTransition` and `bisectNakshatraEdge`
  (`lib/features/panchang/domain/tithi_transitions.dart`) use the same
  primitive. Nakshatra edges target half a segment past (or before) the sunrise
  index so both directions are upward crossings.
- Bengali `_resolveMonthStart` replaces its 12-round (~20 s) bisection with the
  shared solver and keeps its ±3-day bracket, 35-day fallback and historic
  approximation.
- Removed `wrapPairIndex` / `interpolateNewMoonInstant`
  (`lib/models/hindu_month_system.dart`) as dead approximation code;
  `newMoonDistance` stays as the last-resort fallback pick.
- Yoga and karana still have no transition consumer. The primitive covers them,
  but nothing asks for their boundary instants yet.

### Place clock: device vs selected place

"Today", the midnight rollover and reminder times now follow one explicit clock:
live location uses the phone's clock, a place picked on the map uses that
place's clock.

- `PlaceClock` / `resolvePlaceClock` (`lib/core/location/place_clock.dart`):
  live location -> device; manual place -> its IANA zone; neither -> Delhi
  (`Asia/Kolkata`). `LocationService.placeClock` is the synchronous source;
  `placeClockProvider` (`lib/providers/location_provider.dart`) exposes it and
  must never start location init (it would open Hive in every widget test).
- Picking a place on the map now turns "use current location" off
  (`setHomeLocation`). Before, the GPS fix silently won and the pick had no
  effect. After any place or toggle change call `refreshPlaceContext(ref)`; it
  also re-derives the notification clock and re-schedules reminders.
- `todayDateProvider`, `selectedDateProvider`, `focusedMonthProvider`,
  `heavyFocusedMonthProvider`, `jumpToToday()`, the midnight timer, the resume
  sync and every `isSameDay(..., DateTime.now())` site read the clock, so the
  day label, countdowns and highlights cannot disagree.
- Reminders (`NotificationScheduler`) build their wall times and content date
  on the clock instead of `tz.local`; the background isolate derives the same
  clock from `location_enabled` + `home_timezone` (`readPlaceClock`). No
  reminder is anchored to a panchang instant yet (puja kala, nishita); when one
  is added it should fire at the place instant.
- `solarEventsService.setPlaceTimezone(null)` now means "device zone" (live
  location). `kPlaceContextVersion` 2 -> 3 because the same cache key can now
  resolve instants in the other zone.
- Hero location chip appends the zone abbreviation ("Varanasi · IST") only when
  the place clock differs from the device's.

### Place timezone from coordinates

A place now carries the time zone it actually observes, so viewing Varanasi from
New York uses IST instead of the device zone.

- `resolvePlaceTimezone` (`lib/core/location/timezone_resolver.dart`) looks the
  coordinate up in the bundled `timezone_finder` boundaries
  (`findLocation(longitude, latitude)` - longitude first). Fallback order is
  place -> device zone -> `Asia/Kolkata`; the fallback covers open ocean (data
  stops ~22 km offshore), a boundary id missing from the tzdb, and tzdata that
  was never initialized.
- tzdata must come from `package:timezone/data/latest_all.dart` (both
  `AppBootstrap.initTimezones` and the WorkManager entrypoint): `latest` omits
  106 of the 419 boundary identifiers and a hit throws `StateError`.
- Provenance is stored with the zone in `home_timezone_source` /
  `cached_timezone_source` (`place`, `user`, `device`; values stable once
  shipped). `_backfillPlaceMetadata` retries only `device`-marked or legacy
  marker-less values, so an explicit `timezoneId` override is never clobbered.
- `setHomeLocation` resolves the zone itself; the picker no longer needs to.
- Cached days are invalidated once: `locationSignature` gained
  `kPlaceContextVersion` (`_p2`) because instants cached under a foreign device
  zone would otherwise be served with the place's zone.
- Dependency: `timezone ^0.11.2`, `timezone_finder ^1.0.0`,
  `flutter_local_notifications ^22.3.2` (20.x converted its positional
  parameters to named ones). ODbL credit shown on the About screen
  (`timezoneDataCredit`, `kTimezoneBoundaryAttribution`).
- Superseded by the place clock above: the civil day and reminder wall times
  follow the selected place when it was picked manually, the device otherwise.

### Poila Boishakh on the right day

The Bengali calendar no longer reports Boishakh 1 on the sankranti day itself,
so 14 April 2026 reads Choitro 30, 1432 and Poila Boishakh 1433 is 15 April.

- `BengaliCalendarService._resolveMonthStart` now returns
  `({int index, DateTime start})`. When the Bengal rule puts month `N`'s start
  after noon, the day belongs to month `N-1`, so the previous month is resolved
  (one step only) instead of returning the noon date as day 1.
- `calculateDate` takes the month name and Bangabda year from the resolved
  index, not the noon rashi, and `_monthStartFor` caches under that index. Do
  not derive either from `monthIndex` again; the sankranti civil day's rashi is
  already the new month.
- The bounded noon fallback is kept as an unreachable one-step guard. Do not
  remove it: it protects the calendar grid from a mis-resolution.
- Locked by `test/bengali_calendar_month_start_test.dart` (transition in both
  directions, day continuity, one Boishakh 1 per year) and the golden cases
  `kolkata/guwahati-2026-04-14` (`{1432, Choitro, 30}`, now
  `external-verified`) plus new `*-2026-04-15` cases. Engine stays
  `panchang-v3`.

### Festival scan on the canonical day

The next-festival scan and the calendar grid now agree on which day a festival
falls on, because both match against the same projected day.

- `PanchangService.findNextFestivalOccurrence` resolves one canonical
  `PanchangDay` per candidate date and projects it with `projectPanchangDay`
  (`lib/features/panchang/domain/panchang_day_projection.dart`), the single
  day -> `PanchangData` projection also used by the notification scheduler. The
  ~240-line inline matcher is gone; do not reintroduce sunrise/override/Kshaya
  matching at a call site.
- Deliberate behaviour change: the scan no longer accepts a sunrise match for a
  `timingOverride` festival. The old copy did, which disagreed with
  `PanchangData.fromRawTithi`; a boundary date could differ between the
  countdown and the grid.
- A polar candidate day no longer throws: the old scan called
  `solarEventsService.sunrise` directly and let `SolarEventUnavailable` escape,
  so no date resolved. The day's null sunrise means the tithi is sampled at
  civil noon and the scan continues.
- Engine stays `panchang-v3`; no golden fixture moved.
  `test/festival_occurrence_scan_test.dart` locks scan/grid parity (Nishita,
  madhyahna, moonrise-puja, a Kshaya tithi, and a polar day).

### Moonrise observance checkpoint

A festival rule can now be decided by the tithi at moonrise (`timingOverride:
moonrise`), which `PanchangRules` already documented but the matcher silently
ignored.

- `PanchangCheckpointTithis.moonrise` is the tithi at the day's own moonrise;
  `PanchangDayResolver` samples it under the `moonrise` cache point and
  `TithiCheckpoints.rawTithiMoonrise` / `rawTithiMoonrise:` carry it to the
  scheduler and export paths.
- `timingOverrideCheckpoints` includes `moonrise`, so such a rule is matched
  only at the rise: no sunrise match, no dominant grace, Kshaya fallback kept.
  `SolarEventsService.checkpointTimeFor('moonrise')` returns the rise for the
  forward scan.
- `FestivalObservancePolicy.moonrise` records the no-rise policy:
  `MoonrisePolicy.fallbackToSunrise` (default) uses the day's own tithi when the
  Moon does not rise; `requireRise` would move the observance instead. Do not
  change the default without a fixture diff.
- No shipped festival sets `timingOverride: moonrise` yet, so no result moves and
  the engine stays `panchang-v3`. Karva Chauth still matches at sunrise; its
  `pujaKala`/`paranRule: moonrise` only drives the puja window.

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
