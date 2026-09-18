"""Compress festival artwork to the project budget: WebP / <=800px / <=200 KB.

Workflow: drop the source image into ``assets/images/festival/``, then run
from the repo root::

    python scripts/compress_festival_images.py

The script is idempotent -- files that already comply are skipped. When a
source converts to a new extension (e.g. ``.jpeg`` -> ``.webp``), matching
``visuals.image`` paths in ``assets/festivals.json`` are updated with a
surgical string replace (no JSON reformatting), and the original file is
removed only after the WebP output verifies.

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


def compress_one(path: Path, dry_run: bool = False) -> str | None:
    """Compress *path* in place (as .webp). Returns new name or None if skipped.

    Returns the new file name when the file was (or, for dry-run, would be)
    written, including the no-rename re-encode case. Returns None when the
    file already complies and was skipped.
    """
    img = _load_normalized(path)
    w, h = img.size
    longest = max(w, h)
    size = path.stat().st_size
    target = path.with_suffix(".webp")
    already_webp = path.suffix.lower() == ".webp"

    if already_webp and longest <= MAX_SIDE_PX and size <= MAX_BYTES:
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


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Report what would change without writing files.",
    )
    args = parser.parse_args()

    if not FESTIVAL_DIR.is_dir():
        print(f"Error: {FESTIVAL_DIR} not found. Run from the repo root.")
        return 2

    files = sorted(
        p for p in FESTIVAL_DIR.iterdir()
        if p.is_file() and p.suffix.lower() in SOURCE_EXTENSIONS
    )
    if not files:
        print(f"No images found in {FESTIVAL_DIR}. Nothing to do.")
        return 0

    changed = 0
    for path in files:
        try:
            if compress_one(path, dry_run=args.dry_run) is not None:
                changed += 1
        except Exception as e:  # noqa: BLE001 - report per-file, keep going
            print(f"ERROR {path.name}: {e}")
            return 1

    verb = "would change" if args.dry_run else "changed"
    print(f"\nDone: {changed}/{len(files)} file(s) {verb}. Budget: WebP, <={MAX_SIDE_PX}px, <={MAX_BYTES // 1024} KB.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
