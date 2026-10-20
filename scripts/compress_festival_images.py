"""Compress festival artwork to the project budget: WebP / <=800px / <=200 KB.

Workflow: drop the source image into ``assets/images/festival/``, then run
from the repo root::

    python scripts/compress_festival_images.py                     # whole folder
    python scripts/compress_festival_images.py dussehra.jpg        # just this one
    python scripts/compress_festival_images.py --dry-run           # preview only

The script is idempotent -- a file that is already WebP, <=800px and <=200 KB
is never touched, so re-running it after adding one picture re-encodes only
that picture. Pass names to work on a subset; the converted name works too
(``dussehra.webp`` finds the not-yet-converted ``dussehra.jpg``). ``--force``
is the explicit opt-in to re-encode a file that already complies (lossy
generations stack, so this is never the default).

When a source converts to a new extension (e.g. ``.jpeg`` -> ``.webp``),
matching ``visuals.image`` paths in ``assets/festivals.json`` are updated with
a surgical string replace (no JSON reformatting), and the original file is
removed only after the WebP output verifies. A brand-new picture therefore has
two routes: point ``visuals.image`` at the source name and let the script
rewrite it, or convert first and reference the ``.webp`` name.

Limits (agreed 2026-09): max 800px on the longest side, max 200 KB per
file, WebP at quality 80. If the output still exceeds 200 KB, quality
steps down (75/70/65/60) and then dimensions shrink 10% at a time until
the file fits -- so the script always converges instead of just warning.

Requires Pillow (same dependency as pad_image.py / remove_bg.py)::

    pip install pillow
"""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

try:
    from PIL import Image, ImageOps
except ImportError:  # pragma: no cover - environment issue, not logic
    print("Error: Pillow is not installed. Run: pip install pillow")
    sys.exit(2)

REPO_ROOT = Path(__file__).resolve().parent.parent
FESTIVAL_DIR = REPO_ROOT / "assets" / "images" / "festival"
FESTIVALS_JSON = REPO_ROOT / "assets" / "festivals.json"

MAX_SIDE_PX = 800
MAX_BYTES = 200 * 1024
DEFAULT_QUALITY = 80
MIN_QUALITY = 60
QUALITY_STEP = 5
SOURCE_EXTENSIONS = {".jpg", ".jpeg", ".png", ".webp"}


def _encode(img: Image.Image, dest: Path, quality: int) -> None:
    """Save *img* as WebP to *dest* (supports RGBA transparency)."""
    save_img = img
    if img.mode in ("P", "LA"):
        save_img = img.convert("RGBA")
    save_img.save(dest, "WEBP", quality=quality, method=6)


def _fit_within_budget(img: Image.Image, dest: Path) -> tuple[int, int]:
    """Encode *img*, lowering quality then size until <= MAX_BYTES.

    Returns the (quality, longest_side) used. Always converges because
    shrinking is unbounded while quality floors at MIN_QUALITY.
    """
    quality = DEFAULT_QUALITY
    working = img
    while True:
        _encode(working, dest, quality)
        if dest.stat().st_size <= MAX_BYTES:
            longest = max(working.size)
            return quality, longest
        if quality > MIN_QUALITY:
            quality = max(MIN_QUALITY, quality - QUALITY_STEP)
            continue
        # Quality floor reached: shrink 10% and retry from default quality.
        w, h = working.size
        working = working.resize(
            (max(1, int(w * 0.9)), max(1, int(h * 0.9))), Image.LANCZOS
        )
        quality = DEFAULT_QUALITY


def _load_normalized(path: Path) -> Image.Image:
    """Open *path* with EXIF orientation applied."""
    with Image.open(path) as raw:
        img = ImageOps.exif_transpose(raw)
        # Detach from the file handle so the source can be replaced/removed.
        return img.copy() if hasattr(img, "copy") else img


def compress_one(
    path: Path, dry_run: bool = False, force: bool = False
) -> str | None:
    """Compress *path* in place (as .webp). Returns new name or None if skipped.

    Returns the new file name when the file was (or, for dry-run, would be)
    written, including the no-rename re-encode case. Returns None when the
    file already complies and was skipped -- that is the guard that keeps a
    previously compressed picture from being re-encoded a second time, unless
    [force] asks for it explicitly.
    """
    img = _load_normalized(path)
    w, h = img.size
    longest = max(w, h)
    size = path.stat().st_size
    target = path.with_suffix(".webp")
    already_webp = path.suffix.lower() == ".webp"

    if already_webp and longest <= MAX_SIDE_PX and size <= MAX_BYTES and not force:
        # Verify it really decodes as WebP before skipping.
        with Image.open(path) as check:
            check.verify()
        print(f"SKIP  {path.name} ({size // 1024} KB, {w}x{h}) already within budget")
        return None

    if longest > MAX_SIDE_PX:
        scale = MAX_SIDE_PX / longest
        img = img.resize((int(w * scale), int(h * scale)), Image.LANCZOS)

    if dry_run:
        print(f"WOULD  {path.name} -> {target.name} ({size // 1024} KB, {w}x{h})")
        return target.name

    tmp = target.with_suffix(".tmp.webp")
    quality, final_side = _fit_within_budget(img, tmp)
    # Verify the output decodes before replacing anything.
    with Image.open(tmp) as check:
        check.load()
    out_size = tmp.stat().st_size
    tmp.replace(target)
    if target != path:
        path.unlink()
        _retarget_references(path.name, target.name)
    action = "CONVERT" if target != path else "RE-ENCODE"
    print(
        f"{action} {path.name} -> {target.name} "
        f"({size // 1024} KB -> {out_size // 1024} KB, "
        f"q{quality}, longest {final_side}px)"
    )
    return target.name


def _retarget_references(old_name: str, new_name: str) -> int:
    """Point festivals.json image paths at *new_name*; returns replace count."""
    old_ref = f"assets/images/festival/{old_name}"
    new_ref = f"assets/images/festival/{new_name}"
    text = FESTIVALS_JSON.read_text(encoding="utf-8")
    count = text.count(old_ref)
    if count:
        FESTIVALS_JSON.write_text(text.replace(old_ref, new_ref), encoding="utf-8")
        print(f"  updated {count} reference(s) in assets/festivals.json")
    return count


def _scan_sources() -> list[Path]:
    """Candidate sources in the festival dir (stale temp files excluded).

    ``*.tmp.webp`` is the script's own in-flight name (``_fit_within_budget``
    writes it before replacing the target). One surviving means an interrupted
    run, so it is reported by ``main`` and skipped rather than compressed.
    """
    return sorted(
        p for p in FESTIVAL_DIR.iterdir()
        if p.is_file()
        and p.suffix.lower() in SOURCE_EXTENSIONS
        and not p.name.endswith(".tmp.webp")
    )


def _resolve_inputs(names: list[str]) -> list[Path]:
    """Resolve CLI image arguments to files inside the festival dir.

    Each argument may be a bare file name, a repo-relative path, or the
    post-conversion name (``dussehra.webp`` finds ``dussehra.jpg``), so the
    command stays valid before and after a conversion.
    """
    resolved: list[Path] = []
    for raw in names:
        candidate = Path(raw)
        candidates = [
            candidate,
            (FESTIVAL_DIR / candidate.name),
            (REPO_ROOT / candidate),
        ]
        match = next((p for p in candidates if p.is_file()), None)
        if match is None:
            # Same stem, any supported source extension: the .webp name that
            # does not exist yet (or the .jpg that was already converted).
            same_stem = sorted(
                p for p in FESTIVAL_DIR.glob(f"{candidate.stem}.*")
                if p.is_file() and p.suffix.lower() in SOURCE_EXTENSIONS
            )
            if len(same_stem) == 1:
                match = same_stem[0]
        if match is None:
            raise FileNotFoundError(
                f"no image named '{raw}' in {FESTIVAL_DIR}"
            )
        if match.resolve().parent != FESTIVAL_DIR.resolve():
            raise FileNotFoundError(
                f"'{raw}' is outside {FESTIVAL_DIR}"
            )
        resolved.append(match)
    return resolved


def main() -> int:
    parser = argparse.ArgumentParser(
        description=(
            "Compress festival artwork to the project budget: "
            "WebP / <=800px / <=200 KB."
        ),
        epilog=(
            "Examples:\n"
            "  python scripts/compress_festival_images.py\n"
            "  python scripts/compress_festival_images.py dussehra.jpg\n"
            "  python scripts/compress_festival_images.py --dry-run\n\n"
            "Files that already comply are never re-encoded, so adding one "
            "picture only compresses that picture."
        ),
        formatter_class=argparse.RawDescriptionHelpFormatter,
    )
    parser.add_argument(
        "images",
        nargs="*",
        metavar="IMAGE",
        help=(
            "Compress only these images. Default: every image in "
            "assets/images/festival/ (already-compliant ones are still skipped)."
        ),
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Report what would change without writing files.",
    )
    parser.add_argument(
        "--force",
        action="store_true",
        help=(
            "Re-encode even when the file already complies "
            "(another lossy generation -- use deliberately)."
        ),
    )
    args = parser.parse_args()

    if not FESTIVAL_DIR.is_dir():
        print(f"Error: {FESTIVAL_DIR} not found. Run from the repo root.")
        return 2

    for path in sorted(FESTIVAL_DIR.glob("*.tmp.webp")):
        print(f"WARN  {path.name} looks like an interrupted run; skipping it")

    if args.images:
        try:
            files = _resolve_inputs(args.images)
        except FileNotFoundError as e:
            print(f"Error: {e}")
            return 2
    else:
        files = _scan_sources()
    if not files:
        print(f"No images found in {FESTIVAL_DIR}. Nothing to do.")
        return 0

    changed = 0
    for path in files:
        try:
            written = compress_one(path, dry_run=args.dry_run, force=args.force)
            if written is not None:
                changed += 1
        except Exception as e:  # noqa: BLE001 - report per-file, keep going
            print(f"ERROR {path.name}: {e}")
            return 1

    verb = "would change" if args.dry_run else "changed"
    print(f"\nDone: {changed}/{len(files)} file(s) {verb}. Budget: WebP, <={MAX_SIDE_PX}px, <={MAX_BYTES // 1024} KB.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
