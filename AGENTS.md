# AGENTS.md - Tithi

Offline Hindu calendar / Panchang app. Flutter, Android-first,
`flutter_riverpod` + Hive, Swiss Ephemeris through the local `packages/jyotish`
FFI package. **No web target.**

This file is the always-loaded index. Use the routing table first; open a
linked detail doc only for the layer you are changing. Do not scan `lib/`.

## Commands

```bash
flutter analyze                     # CI fails on infos too: keep it at zero
flutter test                        # full suite
flutter test test/<name>_test.dart  # one file
flutter test test/<name>_test.dart -n "<group>"

flutter pub run build_runner build --delete-conflicting-outputs   # Hive model changes
flutter gen-l10n                                                  # lib/l10n/*.arb changes
pwsh scripts/check_architecture.ps1                               # architecture guardrails
```

- FFI tests need `SWISSEPH_LIB_PATH` (host `libswisseph.so`). On Windows the host
  cannot run real ephemeris maths - validate on a device or with
  `integration_test/`.
- `flutter test` also runs `test/no_web_target_test.dart`; it fails if web
  scaffolding returns.
- Flutter SDK `^3.10.4`; CI pins Flutter `3.47.4` stable.

## Routing: task -> first files

Paths are relative to the repo root. Logic first: each row names the smallest
file that owns the behaviour before the renderer. A KB figure marks a large
renderer - open it only when changing that rendering itself.

| Task | Start with |
|---|---|
| App startup / bootstrap order | `lib/main.dart`, `lib/app/bootstrap.dart` |
| Panchang values / one day | `features/panchang/domain/`, `services/panchang/panchang_service.dart` |
| Ayanamsa / school / ephemeris | `models/panchang_profile.dart`, `models/panchang_school.dart`, `services/panchang/ephemeris/` |
| Sunrise / sunset / moonrise / timings | `services/solar_events_service.dart`, `moon_events_service.dart`, `auspicious_timings.dart`, `inauspicious_timings.dart` |
| Festival matching / dates | `models/festival.dart`, `services/festival_matching_pipeline.dart` |
| Festival data | `assets/festivals.json` (+ `docs/FESTIVALS_QUICK_GUIDE.md`) |
| Calendar / today / selected date | `providers/calendar_provider.dart`, `features/calendar/` (`data/`, `domain/`, `providers/`, `widgets/`) |
| Home / hero / home cards | `features/hero/` (`domain/`, `providers/`, `widgets/`), `screens/home_*.dart`, `widgets/*card.dart` |
| Daily Wisdom / quote card | `features/quote/` (`domain/`, `providers/`, `widgets/`) |
| Schedule view | `features/schedule/` (`domain/`, `providers/`, `widgets/`) |
| Detail sheets | `features/sheets/`, `features/tithi_sheet/`, `features/event_detail/` (`domain/`, `providers/`, `widgets/`) |
| All Festivals / countdowns / upcoming | `features/countdown/`, `features/event_list/`, `features/festival_search/`, `screens/all_festivals_screen.dart` (27 KB) |
| Notifications | `services/notification_service.dart`, `core/notifications/` |
| Location / GPS / timezone | `services/location_service.dart`, `providers/location_provider.dart`, `core/location/` |
| Settings | `screens/settings_screen.dart`, `features/settings/` |
| Design tokens (colour, spacing, type, motion) | `theme/app_theme.dart`, `app_metrics.dart`, `app_typography.dart`, `app_motion.dart` |
| Localization | `lib/l10n/*.arb`, then `flutter gen-l10n` |
| Hive boxes / adapters / type IDs | `core/storage/`, `models/hive_type_ids.dart` |
| Android home-screen widgets | `services/home_widget.dart`, `features/home_widget/`, `android/app/src/main/kotlin/app/tithi/pro/widget/` |
| In-app update / sharing / Ask-AI | `services/app_update*`, `services/share*`, `features/ai/`, `services/ai_handoff_service.dart` |
| Eclipse / solar system / moon / weather | `services/eclipse_service.dart`, `planetary_view_service.dart`, `weather_service.dart`, `features/{eclipse,solar_system,moon,weather}/` |
| Sankalpa / Bengali / Hindu calendar | `models/sankalpa.dart`, `services/sankalpa_service.dart`, `services/bengali_calendar/`, `services/hindu_calendar_service.dart` |

## Common changes (multi-file touchpoints)

| Change | Touch |
|---|---|
| Add / fix a festival | `assets/festivals.json`, `docs/FESTIVALS_QUICK_GUIDE.md`, artwork in `assets/images/festival/`, `test/festival_data_test.dart` |
| Add a setting | `features/settings/widgets/<section>.dart`, provider in `lib/providers`, key in `core/storage/box_names.dart`, all four `.arb` files |
| Add a UI string | `lib/l10n/app_{en,hi,bn,sa}.arb`, then `flutter gen-l10n` |
| Add a home card | `features/<name>/`, `providers/home_cards_visibility_provider.dart`, `screens/home_screen.dart`, `screens/home_cards_screen.dart` |

## Validation

| Change | Run |
|---|---|
| Any Dart | `flutter analyze` + nearest `test/<subject>_test.dart` |
| Panchang maths | `test/panchang_data_test.dart`, `panchang_day_resolver_test.dart`, `panchang_golden_*` |
| Festival rules/data | `test/festival_data_test.dart`, `festivals_rule_test.dart`, `vriddhi_filter_test.dart`, `dominant_grace_test.dart`, `nakshatra_matching_test.dart` |
| Hive model | `build_runner` + the affected tests |
| Localization | `flutter gen-l10n` + the affected widget test |
| jyotish native | `packages/jyotish` tests with `SWISSEPH_LIB_PATH` |

Tests track behaviour, not diffs:

- Bug fix -> write the failing test first, then fix.
- New behaviour -> test it.
- Refactor -> add no new test, but the existing tests over the moved code must
  pass; if that path has none, add a characterization test *before* moving it.
- Formatting / docs / dependency bump -> no test, `flutter analyze` is enough.

## Hard rules

- No web: no `web/`, `kIsWeb`, or `dart.library.*` conditional imports.
- No `Hive.box()` or provider definitions in `lib/widgets` / `lib/screens`.
- Only `core/storage/hive_adapters.dart` registers Hive adapters.
- Never edit generated files: `*.g.dart`, `lib/l10n/app_localizations*.dart`.
- `models/panchang_data.dart` is a projection of `PanchangDay` - change the
  resolver, not the model.
- No hardcoded colours/radii/shadows: use `AppTheme`, `AppRadius`, `AppSpacing`.
- Append-only: `PanchangSchool` order, Hive type IDs, Hive model field order.
- Panchang cache identity = school + place grid (~1.1 km) + catalog generation +
  date. Do not widen it to date-only.
- Compatibility barrels are `export` shims only; add logic at the target.
- New providers go in `lib/providers` or `features/*/providers`.

## Conventions

- Imports: `dart:` -> `package:` -> relative. Widgets use
  `package:material_ui/material_ui.dart`, not `flutter/material.dart`.
- Expensive autoDispose providers: `core/async/keep_alive.dart`.
- Calendar-gated providers: `guarded()` / `showsCalendarSystem()`.
- Platform checks are runtime (`Platform.isAndroid`, `defaultTargetPlatform`);
  capability lives in the service, not the UI.
- Hive type IDs: `models/hive_type_ids.dart` (next free 7-9, 11+).
- Keep new files under ~500 lines; extract a helper instead of growing a
  `(large)` file. Split along seams (a state machine, pure computation, an
  independently testable unit), not by chopping one cohesive render tree.
  - Exceptions: single-purpose tables/registries (theme, generated, data) and
    cohesive state machines may exceed it.
  - Existing `(large)` files are grandfathered: split them when you touch
    them, not for their own sake.
  - Above ~800 lines, a split is always justified.
- Lint rules live in `analysis_options.yaml`.

## Changelog

A user-facing feature, setting, screen, sheet, reusable service/provider, or
behaviour change adds an entry to `changelogs.md` **in the same commit**.
Newest first under the current version heading; 3-6 bullets: the constraint a
maintainer must not break, then paths/Hive keys. Skip refactors, formatting,
tests/docs, dependency bumps, generated files.

## On-demand references

| When | Read |
|---|---|
| Need the full per-file map | `docs/AGENT_FILE_MAP.md` (open only your section) |
| Choosing or adding tests | `docs/AGENT_TESTING.md` |
| Festival data workflow | `docs/FESTIVALS_QUICK_GUIDE.md` |
| Festival rules, traps, full reference | `docs/FESTIVALS_Modification_GUIDE.md` |
| Festival artwork budget (800px / 200 KB) | `docs/FESTIVAL_ARTWORK_GUIDE.md` |
| Surya Siddhanta calibration | `docs/SURYA_SIDDHANTA_CALIBRATION.md` |
| Release / versioning | `docs/RELEASE_GUIDE.md` |
| jyotish FFI / native build | `packages/jyotish/AGENTS.md` |
| Why web stays deleted | `docs/web-removal/BASELINE.md` |
