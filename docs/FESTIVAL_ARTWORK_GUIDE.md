# Festival Artwork Guide

How to add a festival picture to the app: compress it with
`scripts/compress_festival_images.py`, point `visuals.image` at it, and let
the asset test confirm it.

Artwork shows up in the home hero card (the picture on the right of the moon
row). Long-pressing it opens a floating window with pinch/double-tap zoom. When
several illustrated festivals share a day the pictures stack into a deck — it
cycles by itself until you swipe or long-press it, and swiping it sideways flips
through them immediately — and the window becomes a swipeable gallery.

---

## Quick start

```bash
# 1. Drop the source image into the artwork folder
#    (jpg, jpeg, png or webp all work)
#    assets/images/festival/

# 2. Preview what the script would do (nothing is written)
python scripts/compress_festival_images.py --dry-run

# 3. Compress — the whole folder, or just the picture you added
python scripts/compress_festival_images.py
python scripts/compress_festival_images.py dussehra.jpg
```

Run from the repo root. The script needs Pillow, same dependency as
`pad_image.py` / `remove_bg.py`: `pip install pillow`.

A typical `--dry-run` on a folder that already holds shipped artwork:

```
SKIP  durga_puja.webp (130 KB, 640x800) already within budget
WOULD  dussehra.jpg -> dussehra.webp (225 KB, 1000x558)
SKIP  shri_ganesh.webp (136 KB, 600x800) already within budget

Done: 1/3 file(s) would change. Budget: WebP, <=800px, <=200 KB.
```

## The budget

| Limit            | Value                                  |
| ---------------- | -------------------------------------- |
| Format           | WebP                                   |
| Longest side     | <= 800 px                              |
| File size        | <= 200 KB                              |
| Quality          | 80, stepping down 75/70/65/60          |
| If still too big | dimensions shrink 10% at a time        |

The encode loop always converges: quality floors at 60, then the picture is
resized until it fits. `test/festival_image_assets_test.dart` enforces the
same numbers, so an unchecked file fails `flutter test`.

Aim for roughly portrait art (the shipped files are 640x800 and 600x800). The
card slot is only ~76-110 pt wide and crops with `BoxFit.cover`, so the
subject should sit near the centre.

## It only compresses what needs compressing

The script is idempotent. A file that is already **WebP + <=800 px +
<=200 KB** is reported as `SKIP` and left byte-for-byte untouched, so
re-running it never adds another lossy generation to pictures a previous run
produced.

That check is "does it comply *now*", not "have we seen this file before",
which keeps it correct when a picture is replanted or the budget changes.

Two ways to narrow it further:

```bash
# Compress only these files (a bare name, a repo path, or the converted name)
python scripts/compress_festival_images.py dussehra.jpg ganesh.png

# Re-encode even when the file already complies — explicit opt-in only,
# because it loses quality. Never needed for a normal add.
python scripts/compress_festival_images.py --force shri_ganesh.webp
```

Name resolution accepts the **converted** name too: `dussehra.webp` finds the
not-yet-converted `dussehra.jpg`, so a script or habit keeps working before
and after a conversion. Unknown names and files outside
`assets/images/festival/` exit with code 2 and a clear message instead of
silently doing nothing.

## Adding a new picture end to end

The `.jpg`/`.png` source is renamed to `.webp`, so `festivals.json` has to end
up pointing at the new name. Pick either route.

### Route A — reference the source, let the script rewrite it

1. In `assets/festivals.json`, set the entry's artwork to the file you are
   about to add:

   ```json
   "visuals": { "image": "assets/images/festival/dussehra.jpg", "theme_color": "" }
   ```

2. Run `python scripts/compress_festival_images.py dussehra.jpg`. The script
   converts the file, rewrites every matching `visuals.image` string to
   `.webp`, and deletes the `.jpg` only after the WebP output verifies.

### Route B — convert first, reference the result

1. Run `python scripts/compress_festival_images.py dussehra.jpg` (produces
   `dussehra.webp` and removes the `.jpg`).
2. Point `visuals.image` at the new name yourself:

   ```json
   "visuals": { "image": "assets/images/festival/dussehra.webp", "theme_color": "" }
   ```

Either way, leave `theme_color` empty — the event sheet always uses the app
primary colour.

## What the script does, step by step

1. Opens the file and applies EXIF orientation (`ImageOps.exif_transpose`), so
   phone photos are not sideways.
2. **Skip check** — already WebP, <=800 px and <=200 KB: print `SKIP`, stop.
   (Bypassed only by `--force`.)
3. Downscales to 800 px on the longest side with Lanczos when needed.
4. Encodes to WebP at quality 80, walking quality down to 60, then shrinking
   10% at a time until the file is <=200 KB.
5. Writes to a `*.tmp.webp` sibling, re-opens it to confirm it decodes, and
   only then replaces the target — a failed run never leaves a broken asset.
6. Deletes the original when the extension changed, after rewriting
   `assets/festivals.json` with a plain string replace (no JSON reformatting,
   so the diff stays surgical).
7. Prints `CONVERT` (renamed), `RE-ENCODE` (same name, was over budget) or
   `SKIP` for every file, plus a summary count.

If a run is interrupted after step 5, a `*.tmp.webp` can survive. The next run
prints `WARN ... looks like an interrupted run; skipping it` and ignores it,
because that file is the script's own in-flight name rather than a source.

## Verify

```bash
python scripts/compress_festival_images.py --dry-run   # every line should say SKIP
flutter test test/festival_image_assets_test.dart
```

The test checks five things:

| Check                          | Fails when                                                           |
| ------------------------------ | -------------------------------------------------------------------- |
| Referenced images exist        | `visuals.image` points at a missing file                             |
| Festival images use `.webp`    | a `.jpg`/`.png` reference survives                                   |
| <= 200 KB each                 | a file was not compressed                                            |
| <= 800 px longest side         | a file was resized by hand or skipped                                |
| No orphan images in the folder | a file sits in `assets/images/festival/` that no festival references |

`pubspec.yaml` bundles the whole folder, so the orphan check is what catches a
half-finished add: the picture is converted but nothing points at it yet, and
its bytes would still ship in the APK/IPA.

## Troubleshooting

| Symptom                                                    | Cause                                                         | Fix                                                                    |
| ---------------------------------------------------------- | ------------------------------------------------------------- | ---------------------------------------------------------------------- |
| `no orphan images ship unreferenced` names your file       | picture converted (or dropped in) but `visuals.image` is `""` | set `visuals.image` to the `.webp` path, see routes above              |
| `Error: no image named 'x.jpg' in ...`                     | typo, wrong extension, or already converted                   | run with no arguments to list what is there, or use the `.webp` name   |
| `Error: 'x' is outside assets/images/festival/`            | you passed a path elsewhere in the repo                       | move the source into `assets/images/festival/` first                   |
| The same picture appears compressed twice in the log       | `--force` was used, or the file is still over budget          | drop `--force`; an over-budget file legitimately gets re-encoded       |
| `WARN ... looks like an interrupted run`                   | a previous run stopped before replacing the target            | delete the `*.tmp.webp` file; then re-run                              |
| Conversion succeeds but the hero still shows no picture    | the festival entry is not matched for that date               | check `panchang_rules` first; artwork only renders on matched days     |

## App-side notes

- The hero reads `HeroContent.artworks`, built by `heroArtworks()` in
  `lib/features/hero/domain/hero_content.dart`: every illustrated festival for
  the day, ranked by `displayPriority`, with duplicate image paths collapsed
  (the five Durga Puja days share one file, which must not read as a deck of
  identical pictures).
- One artwork renders as the plain slot (`HeroFestivalImage`). Two or more
  stack the headline picture in front with dimmed edges behind and a `1/2`
  position pill, inside exactly the same footprint so the text column never
  reflows.
- Swiping the deck sideways rotates it — the front picture restacks at the
  back — so every picture on the day can be seen without opening anything.
  A tap still opens the detail sheet, exactly as on a single picture.
- A deck also turns by itself every 10 s (`_autoRotateInterval` in
  `paksha_hero_card.dart`), so a multi-picture day reveals all of its artwork.
  An idle turn is a slow cross-dissolve (1.2 s, `_autoTurnDuration`) that
  settles up from slightly smaller; a swipe you make yourself swaps in
  220 ms (`_swipeTurnDuration`) so it still feels direct.
- The idle motion stops for good on the first swipe or long press — that is the
  pause control WCAG 2.2.2 asks for — and never starts under Reduce Motion,
  while a screen reader is running, while a sheet or dialog covers the card, or
  while the app is in the background. A tap, or a scroll that merely starts on
  the picture, does not count: neither says anything about the deck.
- It also yields to the page: the deck follows the enclosing `Scrollable`'s
  `isScrollingNotifier`, so a drag or fling stops the timer on its first frame
  and a fresh countdown starts once the page settles. If the card is scrolled
  out of the viewport when that settle happens, the timer is cancelled
  outright — the picture stays where it is until the card is back on screen.
  A running turn therefore never shares frames with a fling, and nothing
  cross-fades for an empty viewport.
- Thumbnails decode at the size they are drawn (`cacheWidth` from the slot
  width × device pixel ratio), not at the asset's full 600×800, so a three-picture
  deck costs a few hundred KB instead of several MB. The gallery still decodes
  at full size, because that is where the picture is actually looked at.
- Long-press opens the gallery (`lib/features/hero/widgets/artwork_window.dart`)
  on the picture currently in front; paging is frozen while a picture is
  zoomed so a pan moves the picture, not the page.
- The card stays cheap to paint, because Impeller replays its display list on
  every frame the home screen composites — a slow hero slows the sheet, the
  drawer and the page along with it. Concretely: the film grain is a small
  noise texture baked once and drawn as one tiled quad (`HeroGrainPainter`),
  never one `drawRect` per speck; the card paints in ~50 ops regardless of
  size. `test/hero_grain_painter_test.dart` fails if the grain ever goes back
  to per-speck drawing. Keep it that way when adding surface finish: prefer a
  cached image/shader over per-frame loops.
