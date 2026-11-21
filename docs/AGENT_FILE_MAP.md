# Agent file map (on-demand)

Full per-file reference for `AGENTS.md`. **Do not read this end-to-end.**
Open the one section for the layer you are changing. Root `AGENTS.md` has the
task routing, commands, hard rules and validation.

Paths are relative to the repo root. `(large)` means: edit surgically, prefer
extracting a helper over growing the file.

## Contents

1. [Architecture](#architecture)
2. [Entry and startup](#entry-and-startup)
3. [Core](#core)
4. [Models](#models)
5. [Panchang engine](#panchang-engine)
6. [Astronomy and calendar services](#astronomy-and-calendar-services)
7. [Festivals](#festivals)
8. [Calendar, home and hero](#calendar-home-and-hero)
9. [Detail sheets](#detail-sheets)
10. [Screens](#screens)
11. [Shared widgets](#shared-widgets)
12. [Other feature slices](#other-feature-slices)
13. [Other services](#other-services)
14. [App-wide providers](#app-wide-providers)
15. [Theme and localization](#theme-and-localization)
16. [Assets and tooling](#assets-and-tooling)

## Architecture

Intended direction: `screens/widgets -> providers -> services/domain -> models`.
`lib/core/` must not import `screens/` or `widgets/`; the one exception is
`core/notifications/scheduler.dart`, which runs the panchang pipeline.

```
lib/
  main.dart          app entry, startup order, midnight timer, lifecycle
  app/               AppBootstrap (startup phases), tile-cache cleanup
  core/              storage, location, format, navigation, notifications, perf
  models/            Hive models + value objects
  services/          engines and platform integrations
  features/<name>/   data/ domain/ providers/ widgets/
  providers/         app-wide Riverpod providers
  screens/           route-level widgets
  widgets/           shared UI kit + re-export shims
  theme/             palette, metrics, typography, motion
  l10n/              generated localizations + .arb sources
```

## Entry and startup

| Path | Responsibility |
|---|---|
| `lib/main.dart` | `main()`, startup order, `TithiApp` (theme/locale/accessibility), place-clock midnight timer, resume/background hooks, Jyotish dispose. |
| `lib/app/bootstrap.dart` | `AppBootstrap`: system UI, Hive/storage, timezone + place index warm-up, version warm-up, map tile cache, background Workmanager. |
| `lib/app/tile_orphan.dart` | One-time removal of the old FMTC tile database. |
| `lib/platform/platform_init.dart` | Android-only display-mode init (`initPlatformFeatures`). |

## Core

| Path | Responsibility |
|---|---|
| `core/storage/box_names.dart` | Canonical Hive box names (`settings`, `festivals`, `festival_occurrences`, `panchang_cache`, ...). |
| `core/storage/hive_adapters.dart` | Single adapter registration site. |
| `core/location/location_defaults.dart` | Delhi fallback coordinates. |
| `core/location/cached_location.dart` | Read persisted last-known coordinates. |
| `core/location/place_clock.dart` | `PlaceClock`: which zone defines civil days and reminder wall times. |
| `core/location/place_grid.dart` | `placeGridKey`: ~1.1 km cell identity. |
| `core/location/timezone_resolver.dart` | Coordinate -> IANA zone; legacy aliases. |
| `core/format/date_only.dart` | `dateOnly()` and date normalisation. |
| `core/format/bounded_cache.dart` | Insertion-ordered bounded cache. |
| `core/format/festival_labels.dart` | Shared festival label builders. |
| `core/locale/app_locale.dart` | Single app-locale resolution. |
| `core/calendar/calendar_guards.dart` | `guarded()` / `showsCalendarSystem()`. |
| `core/async/keep_alive.dart` | Keep-alive-with-timeout for expensive autoDispose providers. |
| `core/navigation/app_routes.dart` | `pushFadeThrough` / `pushSharedX`, Reduce-Motion aware. |
| `core/navigation/home_tab.dart` | Shell tab enum/order (`today`, `festivals`). |
| `core/navigation/haptic_back_button.dart` | Back button with gated haptic + press scale. |
| `core/notifications/scheduler.dart` | Notification scheduling engine (**large**). |
| `core/notifications/scheduling_parts.dart` | Channel builders and shared scheduling helpers. |
| `core/notifications/notification_keys.dart` | Hive keys + notification ID ranges. |
| `core/notifications/notification_content.dart` | Pure notification text helpers. |
| `core/notifications/festival_store.dart` | Festival loading for the background isolate. |
| `core/notifications/background_entrypoint.dart` | Workmanager callback dispatcher. |
| `core/feedback/app_haptics.dart` | Every haptic in the app. |
| `core/feedback/app_messages.dart` | SnackBar/message severity + styling. |
| `core/perf/startup_timeline.dart` | Opt-in cold-start marks (`--dart-define=tithi.startupTimeline=true`). |
| `core/anim/press_scale.dart` | Press-down microinteraction. |
| `core/anim/stagger_entrance.dart` | Staggered list entrance. |

## Models

| Path | Responsibility |
|---|---|
| `models/festival.dart` | `Festival`, `PanchangRules`, regional names, visuals, rituals; `matchesFestivalOnDay`, nakshatra tables (**large**). |
| `models/festival.g.dart` | Generated Hive adapters - never edit. |
| `models/panchang_data.dart` | `PanchangData` day value object, `BhadraWindow` (**large**). |
| `models/panchang_profile.dart` | Calculation profile (ayanamsa, limb/rise-set policy), persisted as JSON (**large**). |
| `models/panchang_school.dart` | `PanchangSchool { bisuddha, suryasiddhanta }` - **append-only** order. |
| `models/hindu_month_system.dart` | Amanta/Purnimant conversion. |
| `models/festival_filter.dart` / `festival_region.dart` | Category filter and region enums. |
| `models/eclipse.dart` | Eclipse model. |
| `models/weather_data.dart` | Weather models. |
| `models/shloka.dart` | Daily-wisdom shloka model. |
| `models/sankalpa.dart` / `sankalpa.g.dart` | Sankalpa Hive model + generated adapter. |
| `models/hive_type_ids.dart` | Central Hive type-ID registry. |

## Panchang engine

| Path | Responsibility |
|---|---|
| `services/panchang/panchang_service.dart` | Orchestrator: month/day computation, static LRU caches (**large**). |
| `services/panchang/ephemeris/panchang_ephemeris.dart` | Sun/Moon longitude interface; selects the school's implementation. |
| `services/panchang/ephemeris/surya_siddhanta_engine.dart` | Pure-Dart Surya Siddhanta theory + tuning. |
| `services/panchang_init/panchang_init.dart` | Copies bundled ephemeris files into app documents before first use (**large**). |
| `services/panchang_service.dart` | Barrel: `export 'panchang/panchang_service.dart'`. |
| `features/panchang/domain/panchang_day_resolver.dart` | The single per-day computation pipeline (**large**). |
| `features/panchang/domain/panchang_day.dart` | Canonical immutable `PanchangDay`. |
| `features/panchang/domain/panchang_day_projection.dart` | `PanchangDay -> PanchangData` projection. |
| `features/panchang/domain/tithi_transitions.dart` | Tithi boundary/transition math (**large**). |
| `features/panchang/domain/tithi_span.dart` | Tithi span type + helpers. |
| `features/panchang/domain/nakshatra_span.dart` | Nakshatra span + edge bisection. |
| `features/panchang/domain/yoga_karana_span.dart` | Yoga/karana spans at sunrise. |
| `features/panchang/domain/bhadra.dart` | Vishti/Bhadra windows. |
| `features/panchang/domain/root_solver.dart` | Adaptive root solver for astronomical crossings. |
| `features/panchang/domain/panchang_crossings.dart` | Lunation + solar-ingress crossings. |
| `features/panchang/data/panchang_cache.dart` | Hive cache, UI LRU, `locationSignature`. |
| `features/panchang/domain/occurrence_cache.dart` | Forward festival-scan cache. |

## Astronomy and calendar services

| Path | Responsibility |
|---|---|
| `services/solar_events_service.dart` | Sunrise/sunset/next sunrise per civil day + place (**large**). |
| `services/moon_events_service.dart` | Topocentric moonrise/moonset (**large**). |
| `services/sunrise_calculator.dart` / `moonrise_calculator.dart` | NOAA / fallback calculators. |
| `services/auspicious_timings.dart` | Abhijit, Brahma Muhurta, Madhyahna, Nishita, Godhuli, Pradosha. |
| `services/inauspicious_timings.dart` | Rahu Kalam, Yamaganda, Gulika. |
| `services/bengali_calendar/` | `bengali_calendar_service.dart`, `bengali_calendar_data.dart`, `bengali_month_start.dart`. |
| `services/bengali_calendar_service.dart` | Barrel re-export. |
| `services/hindu_calendar_service.dart` | Hindu month/era helpers (legacy provider lives here). |
| `services/eclipse_service.dart` | Upcoming eclipse calculation (legacy provider lives here). |
| `services/moon_phase_service.dart` | Moon phase/illumination (legacy provider lives here). |
| `services/planetary_view_service.dart` | Solar-system positions for the visualization. |
| `services/weather_service.dart` | Open-Meteo fetch. |

## Festivals

| Path | Responsibility |
|---|---|
| `assets/festivals.json` | **The festival data file.** Edit here; the app fingerprints and reseeds on next launch. |
| `services/festival_repository.dart` | Seed `festivals.json` into Hive, fingerprint/version, in-memory list. |
| `services/festival_matching_pipeline.dart` | Single source of truth for Vriddhi / dominant-tithi / sequence matching. |
| `services/festival_export_service.dart` | Full dataset + computed Panchang JSON export. |
| `features/countdown/domain/target_resolution.dart` | Shared "N festivals -> dated targets" forward scan. |
| `features/countdown/data/festival_year_snapshot.dart` | Persisted yearly list in `festival_occurrences`. |
| `features/countdown/providers/countdown_providers.dart` | Countdown providers (**large**). |
| `features/event_list/providers/event_providers.dart` | Upcoming-festival window for the home card. |

## Calendar, home and hero

| Path | Responsibility |
|---|---|
| `providers/calendar_provider.dart` | `todayDateProvider`, selected/focused month, `CalendarPreferences`, school, calendar-system providers (**large**). |
| `providers/panchang_provider.dart` | `panchangForDateProvider`, `todayPanchangProvider`, `monthlyPanchangProvider`, live tick, timings providers (**large**). |
| `providers/location_provider.dart` | Location service, permission gate, `placeClockProvider`, `calculationLocationProvider`, coordinates. |
| `providers/festival_provider.dart` | Festival repository + init + major/vrat lists. |
| `features/calendar/data/calendar_caches.dart` | Sync LRUs so cells paint stale labels while FFI runs. |
| `features/calendar/data/calendar_models.dart` | Public cell/header models. |
| `features/calendar/domain/cell_builders.dart` | Cell label builders. |
| `features/calendar/domain/header_builders.dart` | Header label builders (**large**). |
| `features/calendar/domain/month_navigation.dart` | Adaptive-month swipe policy. |
| `features/calendar/providers/cell_providers.dart` | Month cell providers. |
| `features/calendar/providers/header_provider.dart` | Header provider. |
| `widgets/calendar_widget.dart` | Calendar grid + adaptive Hindu/Bengali grid (**large**). |
| `widgets/calendar_day_semantics.dart` | Screen-reader node per day tile. |
| `screens/home_shell.dart` | Narrow-screen root: two mounted tabs + floating nav bar. |
| `screens/home_screen.dart` | Main home (wide sidebar / narrow body), drawer, FAB. |
| `screens/home_cards_screen.dart` | Toggle optional home cards. |
| `features/hero/domain/hero_content.dart` | Pure hero view-model (strings, chips, artwork). |
| `features/hero/providers/hero_providers.dart` | Bengali date for the hero header. |
| `features/hero/widgets/` | `artwork_window.dart`, `hero_chip.dart`, `hero_festival_image.dart`. |
| `widgets/paksha_hero_card.dart` | Hero renderer + `heroRecordFor` (**large**). |
| `widgets/major_festival_card.dart` | Featured festival card (**large**). |
| `widgets/event_list_widget.dart` | Home "Festivals & Events" card. |
| `widgets/festival_countdown_card.dart` | Home countdown card. |
| `widgets/moon_countdown_widget.dart` / `moon_animation_widget.dart` | Moon widgets. |
| `widgets/floating_nav_bar.dart` | Floating capsule nav (**large**). |
| `widgets/animated_tab_layer.dart` | Tab switch animation. |
| `widgets/jump_to_today_button.dart` | "Jump to today" control. |
| `widgets/responsive_layout.dart` | `ScreenType` breakpoints. |

## Detail sheets

| Path | Responsibility |
|---|---|
| `features/sheets/sheet_launcher.dart` | **Single entry point**: `showTithiDetailSheet`, `showEventDetailSheet`. |
| `features/sheets/domain/sheet_labels.dart` | Shared sheet header labels. |
| `features/sheets/widgets/` | Shared sheet kit: scaffold, hero header/tile, surface card, chips, info rows, section header, drag handle, edge dismiss, time formatters. |
| `widgets/tithi_detail_sheet.dart` | Tithi detail sheet (**large**). |
| `widgets/event_detail_sheet.dart` | Festival detail sheet (**large**). |
| `features/tithi_sheet/providers/sheet_providers.dart` | Bengali date for the tithi sheet. |
| `features/tithi_sheet/widgets/` | Timings, nakshatra, yoga/karana, auspicious, inauspicious cards. |
| `features/event_detail/domain/event_content.dart` | Event-sheet view-model. |
| `features/event_detail/domain/puja_samay.dart` | Puja-kala window + paran instant. |
| `features/event_detail/domain/puja_moonrise.dart` | Moonrise-anchored puja/paran. |
| `features/event_detail/providers/event_detail_providers.dart` | Expanded-description / hero-chip state. |

## Screens

| Path | Responsibility |
|---|---|
| `screens/all_festivals_screen.dart` | Year stepper, search, filters, yearly occurrence list (**large**). |
| `screens/festival_countdown_screen.dart` | Countdown list. |
| `screens/moon_phases_screen.dart` | Moon scrub + phases. |
| `screens/solar_system_screen.dart` | Solar-system visualization (**large**). |
| `screens/eclipse_screen.dart` | Eclipse tabs. |
| `screens/settings_screen.dart` | Settings hub. |
| `screens/location_picker_screen.dart` | Map/place picker (**large**). |
| `screens/about_screen.dart` / `privacy_policy_screen.dart` | Static pages. |
| `screens/sankalpa/` | Sankalpa list/create screens. |

## Shared widgets

| Path | Responsibility |
|---|---|
| `widgets/app_card.dart` | The one page-level card surface. |
| `widgets/app_divider.dart` / `inset_row_divider.dart` | Hairline rules. |
| `widgets/screen_body.dart` / `page_scaffold.dart` | Page shell + scroll body. |
| `widgets/state_views.dart` | `EmptyState` / error / loading state views. |
| `widgets/skeleton.dart` | Loading skeleton blocks. |
| `widgets/error_display_widget.dart` | Last-resort error screen. |
| `widgets/app_drawer.dart` / `app_drawer_button.dart` | Drawer + hamburger. |
| `widgets/settings_widgets.dart` | Settings section/row primitives. |
| `widgets/festival_row_tile.dart` | Shared festival row. |
| `widgets/festival_filter_chip.dart` / `festival_filter_sheet.dart` | Category/region filters. |
| `widgets/festival_search_delegate.dart` | Search. |
| `widgets/festival_thumbnail.dart` | Category glyph/artwork. |
| `widgets/festival_share_card.dart` / `shloka_share_card.dart` | Share-image cards. |
| `widgets/ritual_checklist_widget.dart` | Ritual checklist. |
| `widgets/weather_sheet.dart` | Weather bottom sheet. |
| `widgets/home_widget_card.dart` | Home-screen-widget promo card. |
| `widgets/panchang_init_error_banner.dart` / `panchang_init_failure_overlay.dart` | Panchang init failure UI. |
| `widgets/native_screens/native_screens.dart` | Barrel for FFI screens (eclipse, solar system). |

## Other feature slices

| Path | Responsibility |
|---|---|
| `features/ai/` | Opt-in "Ask AI" hand-off: domain (`ai_app_target`, `ai_context`, `ai_prompt`), providers, `ask_ai_sheet.dart`, settings section. |
| `features/home_widget/` | Android widget payload builders + promo-dismiss state. |
| `features/eclipse/` | Eclipse providers, card, list, details sheet. |
| `features/moon/providers/moon_providers.dart` | Moon phase providers. |
| `features/quote/` | Daily-wisdom providers + widget. |
| `features/schedule/` | Schedule-view providers + widget. |
| `features/settings/widgets/` | Settings sections: accessibility, app update, calendar, data, language, location, notifications, region. |
| `features/solar_system/` | Solar models/cache + painters. |
| `features/weather/providers/weather_providers.dart` | Weather provider. |

## Other services

| Path | Responsibility |
|---|---|
| `services/location_service.dart` | GPS, permission flow, Nominatim reverse geocode, persisted place (**large**). |
| `services/notification_service.dart` | Notification facade over `core/notifications` (**large**). |
| `services/app_update_service.dart` | GitHub Releases check/download/SHA-256/install (**large**). |
| `services/app_update/app_update_file.dart` | Streamed APK download. |
| `services/app_update/update_apk_name.dart` | APK naming contract. |
| `services/storage_service.dart` | Hive box orchestration, reset flows. |
| `services/share_service.dart` / `share_file/share_file.dart` | Share images/text; temp/documents file helpers. |
| `services/shloka_service.dart` | Shloka loading from `assets/data/shlokas.json`. |
| `services/sankalpa_service.dart` | Sankalpa Hive CRUD. |
| `services/ai_handoff_service.dart` | Launch external AI app with a composed prompt. |
| `services/home_widget.dart` | Android home-widget bridge + `HomeWidgetKind` contract. |

## App-wide providers

`accessibility_provider`, `app_update_provider`, `calendar_provider`,
`festival_provider`, `home_cards_visibility_provider`, `home_widget_provider`,
`locale_provider`, `location_provider`, `notification_provider`,
`panchang_provider`, `planetary_view_provider`, `ritual_state_provider`,
`sankalpa_provider`, `storage_provider`, `theme_provider`, `version_provider`,
`view_mode_provider`.

Compatibility barrels only - follow the `export`: `eclipse_provider`,
`festival_countdown_provider`, `moon_phase_provider`, `weather_provider`.

## Theme and localization

| Path | Responsibility |
|---|---|
| `theme/app_theme.dart` | Palette + component themes (**large**). |
| `theme/app_metrics.dart` | `AppSpacing`, `AppRadius`, `AppIconSize`. |
| `theme/app_typography.dart` | Bundled fonts, three tiers, fallback chains. |
| `theme/app_motion.dart` | Named durations/curves. |
| `l10n/app_en.arb` (+ `bn`, `hi`, `sa`) | Message sources. |
| `l10n/app_localizations*.dart` | Generated - never edit. |
| `l10n/fallback_localization_delegates.dart` | Missing-locale fallback. |

## Assets and tooling

| Path | Responsibility |
|---|---|
| `assets/ephe/` | Swiss Ephemeris data copied at startup. |
| `assets/data/shlokas.json` | Daily wisdom corpus. |
| `assets/data/in_city.json` | Indian city seed list. |
| `assets/fonts/`, `assets/images/`, `assets/icons/`, `assets/map_data/`, `assets/licenses/` | Bundled resources. |
| `tool/surya_siddhanta_probe.dart` | `check`/`fit` calibration CLI. |
| `tool/reference/` | Reference CSVs. |
| `bin/debug_tithi.dart`, `bin/test_festivals.dart`, `bin/test_sunrise.dart` | Ad-hoc debug scripts. |
| `scripts/compress_festival_images.py` | Artwork compression (800px / 200 KB). |
| `scripts/verify_festival_dates.py`, `verify_panchang.py`, `fetch_drik_ss.py` | Data verification helpers. |
| `scripts/check_architecture.ps1` | Architecture guardrails. |
| `.github/workflows/ci.yml` | Analyze + full test + `packages/jyotish` tests. |
| `test/` | Unit/widget suite (see `docs/AGENT_TESTING.md`). |
| `test/fixtures/panchang_golden/` | Locked golden fixtures + `README.md`. |
| `integration_test/` | Device-only ephemeris/festival/adhika checks. |

For `packages/jyotish/`, read `packages/jyotish/AGENTS.md`.
