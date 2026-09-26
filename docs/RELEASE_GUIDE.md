# Release Guide

Everything you need to remember when cutting a build of Tithi, with a
checklist to run before (and after) every release.

The in-app updater is the reason most of these rules exist. It talks to
the GitHub Releases API, so how you tag and name your assets directly
determines whether users can update — and whether the update they get is
the one you intended.

---

## How the updater decides what to offer

Worth knowing once, because every rule below follows from it:

1. The app calls `GET /repos/1arunjyoti/Tithi-App/releases/latest`.
   That endpoint returns only the **latest published, non-draft,
   non-prerelease** release. Drafts and pre-releases are invisible to it.
2. It reads the tag (`v0.6.0+6` → version `0.6.0+6`) and compares it with
   the installed app's `versionName` + `versionCode`.
3. An update is offered only when **both** are true:
   - the release's `+N` build number is **strictly higher**, and
   - its `major.minor.patch` is not older.
4. The build number is Android's `versionCode`. Android refuses to install
   an APK whose `versionCode` is not higher than the installed one, so
   anything else would end in a failed install.
5. It downloads the first asset ending in `.apk`, preferring one named
   `*-release.apk`, then verifies the size and GitHub's published
   SHA-256 before handing it to the installer.

Consequences: **the build number must always increase**, version names
must never go backwards, and the release asset must be the real release
APK.

---

## Before every release

### Version and code

- [ ] `pubspec.yaml` `version:` uses `X.Y.Z+N`
- [ ] `+N` is **higher than every previously published release**
- [ ] `+N` is higher than the `versionCode` already on Google Play
      (if you ship both — they must share one rising counter)
- [ ] The version **name** (`X.Y.Z`) has not gone backwards versus any
      published release
- [ ] `X.Y.Z` changed if there are user-visible changes; a same-name
      rebuild (`0.6.0+5` → `0.6.0+6`) is fine for hotfixes

### Pre-flight

- [ ] `flutter analyze` — no new issues
- [ ] `flutter test` — all green
- [ ] Release signing configured: `android/key.properties` exists, or
      `TITHI_RELEASE_STORE_FILE` / `_STORE_PASSWORD` / `_KEY_ALIAS` /
      `_KEY_PASSWORD` are set
- [ ] Working on the commit you intend to ship (`git status` clean)
- [ ] Repository is **public**, or `UPDATE_REPO` is baked in via
      `--dart-define=UPDATE_REPO=owner/repo` (see below)

### Build

- [ ] Build with the helper script — it bumps `+N` and prints the exact
      output path:

      ```powershell
      .\build_release.ps1                 # APK, bumps build number
      .\build_release.ps1 -Target Both    # APK + AAB for Play
      .\build_release.ps1 -NoBump         # keep the current build number
      ```

- [ ] APK is at
      `build/app/outputs/flutter-apk/tithi-X.Y.Z+N-release.apk`
- [ ] Install that APK on a real device and smoke-test it

### Publish

- [ ] Create the GitHub release with tag **`vX.Y.Z+N`** — exactly
      matching `pubspec.yaml`
- [ ] Release is **published**, not left as a draft
- [ ] Release is **not** marked as a pre-release (unless you intend
      nobody to receive it yet)
- [ ] Attach the asset named exactly
      `tithi-X.Y.Z+N-release.apk`
- [ ] Never reuse an existing tag for different bits. If a release is
      wrong, delete the whole release (tag included) and cut a new build
      number — users who already installed it have consumed that
      `versionCode`
- [ ] Release notes written in the release body, as **plain text**.
      Markdown (`#`, `-`, links) is shown raw in the app; keep it simple
- [ ] Only the intended APK is attached. If a `-release.apk` is missing,
      the app will happily install some other `.apk` you uploaded

### After publishing

- [ ] Open the release page and confirm the asset finished uploading
      (GitHub shows a digest once complete)
- [ ] On a device running the **previous** release: About → Check for
      updates → the new version is offered
- [ ] Download → progress bar completes → Install opens the system
      installer → the app updates and reports the new version after
      restart
- [ ] Grant "install unknown apps" when prompted; the app walks you to
      the right settings screen and the APK does not need re-downloading

---

## Versioning rules, in one place

| Rule | Why |
| --- | --- |
| `+N` must always increase | Android's `versionCode` gate; also how the app detects updates |
| Never reset `+N` to 1 | A release tagged `v0.6.0+1` after `0.5.0+5` is **never offered** (build 1 is not higher than 5) |
| Version name must not go backwards | `/releases/latest` returns the most *recently published* release. Publishing `0.5.1+7` after `0.6.0+6` leaves everyone on 0.6.0 stranded with no future updates |
| Tag must include `+N` | The build number is parsed out of the tag |
| Asset name must end `-release.apk` | Preferred over other `.apk` assets (avoids installing a staging/debug build) |
| One signing key, forever | A differently-signed APK fails with `INSTALL_FAILED_UPDATE_INCOMPATIBLE` |

`build_release.ps1` handles the bump for you, which is the easiest way
to keep `+N` monotonic.

---

## Configuring the update source

Defaults to `1arunjyoti/Tithi-App`, compiled into
`AppUpdateConfig` (`lib/services/app_update_service.dart`). To point a
build somewhere else without a code change:

```powershell
.\build_release.ps1 -FlutterArgs @('--dart-define=UPDATE_REPO=owner/repo')
```

If you ever rename or transfer the repository, either ship a build with
the new `UPDATE_REPO` or every install silently stops finding updates
(the app reports the repository could not be found).

The repository must be **public**. A private repo's releases return 404
to an unauthenticated client. If the code must stay private, publish the
APKs to a separate public releases repo and point `UPDATE_REPO` at it.

---

## Google Play notes

- `REQUEST_INSTALL_PACKAGES` is a **Play-restricted permission**. It is
  fine for FOSS/sideload distribution, but publishing on Play requires a
  declaration and justification, and can trigger policy review.
- Keep the Play `versionCode` and the GitHub build number on the same
  rising counter, otherwise Play users can never self-update.
- Play installs use the Play updater (`app-update` dependency), not this
  one, so the GitHub release is only a fallback for them.

---

## Rollback

You cannot push a lower build number to devices that already installed a
higher one — Android blocks it. So a rollback means a **forward** fix:

1. Fix the problem.
2. Bump `+N` (e.g. `0.6.1+7`).
3. Publish a new release.

The only way to serve an older build is to have users uninstall first,
which loses their data.

---

## Troubleshooting

| Symptom | Likely cause |
| --- | --- |
| "You're up to date" but a release exists | Release is a draft, a pre-release, or not the most recently published one. Also check the tag matches `pubspec.yaml` |
| "You're up to date" on a build you expect to be older | `+N` was reset or is not higher than the installed build |
| Update never appears after publishing | Tag lacks `+N`, or the build number is not higher than the installed one |
| Install fails / "app not installed" | Different signing key, or a build number lower than the installed one |
| "This release has no APK attached" | No `.apk` asset on the release |
| Installs the wrong APK | No `*-release.apk` on the release; a staging or debug `.apk` was attached instead |
| Progress bar freezes | Connection stalled with no data for 60s; the download aborts and can be retried |
| "GitHub is temporarily rate limiting" | Unauthenticated API limit is 60/hour per IP, and carrier NAT shares one IP across many users. Wait a few minutes |
| "The update repository could not be found" | Repo renamed, moved, or made private |
| "failed its integrity check" | Download was corrupted or the asset was re-uploaded under the same name; retry |
| Nothing happens when tapping Check twice | Intentional: repeat checks are throttled for 2 minutes. The refresh icon on the About card always forces a fresh check |
| Cancelled download leaves no file | Intentional: the partial file is deleted so it can never be mistaken for a complete download |

---

## Reference

- Updater service: `lib/services/app_update_service.dart`
- State machine: `lib/providers/app_update_provider.dart`
- UI: `lib/features/settings/widgets/app_update_settings.dart`
- File + installer layer: `lib/services/app_update/`
- Native installer: `android/app/src/main/kotlin/app/tithi/pro/MainActivity.kt`
- Release build: `build_release.ps1`, `android/app/build.gradle.kts`
- Update tests: `test/app_update_service_test.dart`,
  `test/app_update_notifier_test.dart`, `test/app_update_card_test.dart`,
  `test/app_update_file_test.dart`
