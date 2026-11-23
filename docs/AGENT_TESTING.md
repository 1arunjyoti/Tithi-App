# Agent testing map (on-demand)

Read this only when you need to pick tests. Root `AGENTS.md` has the commands
and the routing table.

**Rule:** run `flutter analyze` plus the one nearest `test/<subject>_test.dart`.
Do not run the whole suite to validate a single-file change; CI does that.

## When to add a test

| Change | New test? | Must pass |
|---|---|---|
| New behaviour | Yes - one test per meaningful branch | The new test |
| Bug fix | Yes - the failing test comes first, so it fails before the fix | The new test |
| Refactor / file move | No, *unless* the moved path has no coverage - then add a characterization test **before** moving | Every existing test touching the moved code |
| Formatting, docs, dependency bump | No | `flutter analyze` only |

Refactoring is defined by behaviour staying identical, so existing tests are the
proof - a refactor with no tests over the changed code is unverified, not
verified-by-inspection. Do not add a test that only restates the new structure
(`expect(Widget, isA<Widget>())`), and do not rewrite an existing test to match
new output unless the behaviour change was intended.

When you skip a test, report which command you ran instead.

## Helper files (not tests - do not run directly)

| Path | Purpose |
|---|---|
| `test/flutter_test_config.dart` | Suite-wide config: disables `StartupTimeline` logging. |

## Panchang engine and maths

| Test | Covers |
|---|---|
| `panchang_data_test.dart` | `PanchangData` value object, projections. |
| `panchang_day_resolver_test.dart` | Per-day pipeline: sunrise anchoring, limb selection. |
| `panchang_calculation_test.dart` | End-to-end month/day calculation. |
| `panchang_golden_fixture_test.dart` | Locked fixtures in `test/fixtures/panchang_golden/`. |
| `panchang_golden_engine_test.dart` | Engine output against golden expectations. |
| `panchang_school_dispatch_test.dart` | School -> ephemeris implementation dispatch. |
| `panchang_school_switch_test.dart` | Switching school invalidates and recomputes. |
| `panchang_profile_test.dart` | Profile serialisation, ayanamsa/limb policy. |
| `panchang_polar_day_test.dart` | High-latitude no-sunrise/no-sunset days. |
| `panchang_ui_cache_test.dart` | UI LRU + Hive cache identity. |
| `panchang_init_test.dart` | Ephemeris file copy on first use. |
| `surya_siddhanta_engine_test.dart` | Pure-Dart Surya Siddhanta theory + tuning. |
| `tithi_span_test.dart`, `tithi_transition_test.dart` | Tithi boundaries and spans. |
| `nakshatra_edge_test.dart` | Nakshatra edge bisection. |
| `yoga_karana_test.dart`, `yoga_karana_span_test.dart` | Yoga/karana at sunrise. |
| `bhadra_test.dart` | Vishti/Bhadra windows. |
| `root_solver_test.dart` | Adaptive astronomical root solver. |
| `live_tithi_test.dart` | Live tick/current-tithi behaviour. |
| `ephemeris_range_test.dart` | Ephemeris data-range guards. |

## Festivals

| Test | Covers |
|---|---|
| `festival_data_test.dart` | `assets/festivals.json` schema and integrity. |
| `festivals_rule_test.dart` | Panchang-rule matching. |
| `vriddhi_filter_test.dart` | Vriddhi (two-day) selection. |
| `dominant_grace_test.dart` | Dominant-tithi grace windows. |
| `nakshatra_matching_test.dart` | Nakshatra-based festival rules. |
| `festival_occurrence_scan_test.dart` | Forward scan -> dated occurrences. |
| `festival_year_snapshot_test.dart` | `festival_occurrences` persistence. |
| `festival_catalog_stamp_test.dart` | Catalog fingerprint/reseed. |
| `festival_cache_recovery_test.dart` | Corrupt/partial cache recovery. |
| `festival_first_launch_test.dart` | Cold-start seeding. |
| `festival_export_test.dart`, `festival_export_day_test.dart` | JSON export of data + panchang. |
| `festival_image_assets_test.dart` | Every referenced artwork exists. |
| `festival_region_test.dart` | Region filtering. |
| `display_priority_test.dart` | Which festival wins a day. |
| `durga_puja_2026_test.dart` | Known tricky multi-day case. |
| `adhika_new_moon_test.dart`, `hindu_adhika_month_test.dart` | Adhika-masa handling. |

## Calendar, home, hero, UI

| Test | Covers |
|---|---|
| `hero_record_test.dart` | `heroRecordFor` selection/resolution. |
| `hero_content_test.dart` | Hero view-model strings/chips. |
| `hero_layout_test.dart` | Hero layout at breakpoints. |
| `hero_chip_test.dart`, `hero_location_chip_test.dart` | Hero chips. |
| `paksha_hero_artwork_test.dart`, `hero_grain_painter_test.dart` | Artwork window + painter. |
| `calendar_header_tap_test.dart` | Header tap -> month navigation. |
| `calendar_day_semantics_test.dart` | Screen-reader nodes per day tile. |
| `adaptive_swipe_test.dart` | Adaptive-month swipe policy. |
| `home_shell_navigation_test.dart` | Shell tabs + re-tap scroll-to-top. |
| `home_cards_visibility_test.dart`, `home_cards_scroll_test.dart` | Optional home cards. |
| `festivals_home_card_test.dart`, `major_festival_card_test.dart`, `festival_countdown_card_test.dart` | Home cards. |
| `floating_nav_bar_test.dart`, `animated_tab_layer_test.dart`, `jump_to_today_button_test.dart` | Shell chrome. |
| `all_festivals_screen_test.dart` | Year stepper, search, filters. |
| `event_overflow_test.dart`, `festival_row_decoration_test.dart` | List-row layout edges. |
| `festival_filter_chip_test.dart`, `festival_search_artwork_test.dart`, `festival_thumbnail_test.dart` | List affordances. |
| `event_list_cache_test.dart` | Upcoming-window cache. |

## Sheets

| Test | Covers |
|---|---|
| `tithi_detail_sheet_test.dart` | Tithi sheet content/sections. |
| `event_detail_sheet_test.dart` | Festival sheet content. |
| `event_sheet_content_test.dart` | Event view-model. |
| `puja_samay_test.dart` | Puja-kala + paran windows. |
| `sheet_kit_test.dart` | Shared sheet primitives. |
| `panchang_init_error_banner_test.dart`, `panchang_init_failure_overlay_test.dart` | Init failure UI. |

## Timings, astronomy, location

| Test | Covers |
|---|---|
| `solar_events_service_test.dart` | Sunrise/sunset per civil day. |
| `moon_events_test.dart`, `moonrise_calculator_test.dart` | Moonrise/moonset. |
| `auspicious_timings_test.dart`, `inauspicious_timings_test.dart` | Muhurta/Rahu-kalam windows. |
| `calculation_location_test.dart` | Which coordinates feed calculation. |
| `location_fallback_test.dart` | Delhi fallback path. |
| `location_data_test.dart` | Place persistence/seed data. |
| `timezone_resolver_test.dart` | Coordinate -> IANA zone, aliases. |
| `place_clock_test.dart` | Place clock / civil-day boundary. |
| `bengali_calendar_date_cache_test.dart`, `bengali_calendar_month_start_test.dart`, `bengali_month_start_test.dart` | Bengali calendar. |
| `hindu_calendar_day_test.dart`, `hindu_month_system_test.dart`, `hindu_year_era_test.dart` | Hindu month/era conversion. |
| `moon_scrub_test.dart`, `solar_system_models_test.dart` | Moon/solar-system views. |

## Notifications, update, AI, misc

| Test | Covers |
|---|---|
| `notification_scheduler_panchang_test.dart` | Scheduler runs the panchang pipeline. |
| `app_update_service_test.dart`, `app_update_file_test.dart`, `app_update_notifier_test.dart`, `app_update_card_test.dart` | Update check/download/install. |
| `ai_app_target_test.dart`, `ai_context_test.dart`, `ai_section_test.dart`, `ask_ai_sheet_test.dart` | Ask-AI hand-off. |
| `panchang_widget_payload_test.dart`, `home_widget_card_test.dart` | Android home-widget payload. |
| `shloka_test.dart` | Daily-wisdom corpus. |
| `app_metrics_test.dart`, `app_motion_test.dart`, `app_typography_test.dart`, `typography_scale_test.dart`, `muted_ink_test.dart`, `shukla_crisp_theme_test.dart`, `system_bars_test.dart` | Design-system tokens/themes. |
| `app_haptics_test.dart`, `press_scale_test.dart`, `state_views_test.dart`, `page_scaffold_test.dart`, `app_divider_test.dart`, `app_drawer_test.dart` | Shared widget kit. |
| `no_web_target_test.dart` | Fails if web scaffolding returns. |
| `widget_test.dart` | Smoke test. |

## jyotish package

`packages/jyotish/test/*` needs `SWISSEPH_LIB_PATH`. Read
`packages/jyotish/AGENTS.md` before touching native code.

## Device-only

`integration_test/` covers real ephemeris maths, festival dates and adhika
months on a device. The Windows host cannot run these - use a device or CI.
