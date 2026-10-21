# Web Removal — Phase 0 Baseline

Recorded 2026-10-21 on branch `chore/remove-web`, tag `pre-web-removal`.

Every later phase must match these numbers. Any deviation is a regression introduced
by the change, not pre-existing noise.

## Analyze baseline

Command: `flutter analyze`

**Result: 8 issues (1 warning, 7 info) — exits non-zero.**

| Severity | File | Rule |
|---|---|---|
| warning | `integration_test/adhika_probe_test.dart:11` | `unused_import` — `package:tithi/services/panchang_service.dart` |
| info | `integration_test/adhika_probe_test.dart:42,43,48,49` | `avoid_redundant_argument_values` |
| info | `test/auspicious_timings_test.dart:124` | `avoid_redundant_argument_values` |
| info | `test/event_list_cache_test.dart:13` | `avoid_redundant_argument_values` |
| info | `test/panchang_ui_cache_test.dart:10` | `avoid_redundant_argument_values` |

All 8 are pre-existing and confined to `test/` and `integration_test/`.
Note that the single warning is itself a dead import of the panchang barrel — Phase 1
may remove it as a side effect, in which case the expected count drops to 7.

## Test baseline

Command: `flutter test --reporter compact`

**Result: 472 passed, 2 failed.**

### Pre-existing failure 1 — needs a real device

`test/festivals_rule_test.dart` → `Panchang Service - Festivals Rule Tests (setUpAll)`

```
MissingPluginException(No implementation found for method
getApplicationDocumentsDirectory on channel plugins.flutter.io/path_provider)
```

This is the only in-suite test that reaches the Swiss Ephemeris path. It cannot run on
the host VM because `path_provider` has no desktop test implementation. The FFI path is
therefore **unverifiable by `flutter test` on this machine** — it must be gated on a
device or emulator:

```
flutter test integration_test/festivals_rule_test.dart -d <device>
```

Not caused by web code. Do not attempt to fix during removal.

### Pre-existing failure 2 — stale assertion

`test/shloka_test.dart` → `Shloka Share Text Tests expanded share includes English by default`

```
Expected: contains '#karma'
Actual:   'Sanskrit\n\ntranslit\n\nEnglish\n\n— Gita 2.47\n\nShared via Tithi App'
```

`test/shloka_test.dart:195-196` expects `#karma` and `#wisdom` hashtags that no longer
exist anywhere in `lib/`. The share-text builder dropped them; the test was not updated.
Unrelated to web. Do not fix during removal.

## Hosting findings

Correction to the earlier assumption that the Flutter web build was deployed: it is not.

| Host | Status | What it is |
|---|---|---|
| `tithiapp.netlify.app` | **Live** (13.215.239.219, 52.74.6.109) | A **hand-built marketing site**, independent of this repo. Landing page, features, "Download Free (Android)", Privacy Policy, Terms of Use, Blog. Not a Flutter build. |
| `app.tithi.pro` | **No DNS** | Referenced only as an identifier string inside the Nominatim User-Agent. Not an active host. |
| `tithi.pro` | **No DNS** | — |

**The Flutter `web/` target has no known live deployment.** Deleting it removes no
deployed artifact.

### Do not take down `tithiapp.netlify.app`

It is load-bearing for the Android app, from 12 references in `lib/`:

| Reference | Purpose |
|---|---|
| `lib/screens/about_screen.dart:18` | In-app privacy policy URL `/privacy` |
| `lib/widgets/app_drawer.dart:262` + `shareAppMessage` in 4 ARBs | Share text "Download now: …" |
| `lib/services/location_service.dart:166` | Nominatim `User-Agent` contact URL |
| `lib/screens/location_picker_screen.dart:46` | Same `User-Agent` on the map tile request |

Consequences if the site ever goes down: the Play Store privacy-policy link breaks,
share messages point at a dead page, and Nominatim may rate-limit or block the app for
an invalid contact URL. Removing the Flutter web target does **not** affect the site —
but this is why the site must outlive the removal.

## What is reproducible in `web/`

All 15 files were generated output:

- Icons → `flutter_launcher_icons.yaml` (`web: generate: true` at the time, source
  `assets/icons/logo_transparent.png`)
- Splash → stale `web/splash/img/*` output; the current `flutter_native_splash.yaml`
  generates no web assets, so these will not come back on their own
- `index.html`, `manifest.json` → `flutter create . --platforms=web` defaults, plus the
  custom SEO/Open Graph meta block preserved in
  [`web-index-meta.md`](web-index-meta.md)

Nothing else in `web/` is hand-authored.

## Phase gate

Each subsequent phase must satisfy all three:

1. `flutter analyze` → 8 issues (or 7 if the dead import goes), same rules, same files.
2. `flutter test` → 472 passed, 2 failed, and the 2 failures are the same two above.
3. `flutter build apk --debug` → succeeds.

Domain phases (1-2) additionally require the on-device festival test above.

## Outcome

All seven phases landed on `chore/remove-web`; every gate held at baseline.

| Phase | Commit | Scope |
|---|---|---|
| 0 | `75327c5` | baseline + preserved web metadata |
| 1 | `1ff1c93`, `88ad6e3` | delete approximate web panchang, rename native → sole service |
| 2 | `9c17629`, `772fa22` | delete approximate web Bengali calendar, rename native → sole service |
| 3 | `7d504da` | delete 7 web-only stubs + 6 barrels |
| 4 | `ba9f26f` | remove all 21 `kIsWeb` branches (14 files) |
| 5 | `00a7e9d` | delete `web/` + config entries |
| 6 | `docs: remove web references` | docs and comments (this commit) |

Final state: no `web/` directory, no `kIsWeb` reference anywhere in the repo, no
conditional-export stubs, and the marketing site at `tithiapp.netlify.app` untouched.
`git tag pre-web-removal` (`b925e0f`) still restores the pre-removal tree.
