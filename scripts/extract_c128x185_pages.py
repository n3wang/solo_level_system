#!/usr/bin/env python3
"""Extract c128x185 card images from a PDF using cards_128x185.csv page tokens.

Page number column rules:
  - `258`  → extract PDF page 258, save as 258.png (no rotation)
  - `258r` → extract PDF page 258, rotate 90° clockwise, save as 258.png

The trailing `r` is an orientation flag only; the output filename always uses
the numeric page id so the Flutter seed path `c128x185/{n}.png` stays stable.

Examples:
  python3 scripts/extract_c128x185_pages.py book.pdf
  python3 scripts/extract_c128x185_pages.py book.pdf --only 258r 259r
  python3 scripts/extract_c128x185_pages.py book.pdf --dry-run
"""

from __future__ import annotations

import argparse
import csv
import re
import sys
from pathlib import Path

PAGE_TOKEN_RE = re.compile(r"^(\d+)\s*([rR])?$")
ANY_DIGITS_RE = re.compile(r"\d+")
ANY_R_RE = re.compile(r"[rR]")


def parse_page_token(raw: str) -> tuple[int | None, int]:
    """Return (page_number, rotate_degrees). `r` suffix → 90° CW."""
    token = (raw or "").strip()
    if not token:
        return None, 0

    match = PAGE_TOKEN_RE.match(token)
    if match:
        return int(match.group(1)), (90 if match.group(2) else 0)

    digits = ANY_DIGITS_RE.search(token)
    if not digits:
        return None, 0
    return int(digits.group(0)), (90 if ANY_R_RE.search(token) else 0)


def orientation_degrees(raw: str) -> int:
    value = (raw or "").strip().lower()
    if not value:
        return 0
    if value in {"r", "rotate", "rotated"}:
        return 90
    try:
        return int(value)
    except ValueError:
        return 0


def load_jobs(csv_path: Path) -> list[tuple[int, int, str]]:
    """[(page, rotate_degrees, name), ...] from the decks CSV."""
    jobs: list[tuple[int, int, str]] = []
    with csv_path.open(newline="", encoding="utf-8", errors="replace") as fh:
        reader = csv.DictReader(fh)
        for row in reader:
            name = (row.get("name") or "").strip()
            page, rotate = parse_page_token(row.get("number") or "")
            if page is None:
                continue
            if rotate == 0:
                rotate = orientation_degrees(row.get("orientation") or "")
            jobs.append((page, rotate, name))
    return jobs


def extract(
    pdf_path: Path,
    out_dir: Path,
    csv_path: Path,
    *,
    only: set[str] | None,
    dry_run: bool,
    dpi: int,
) -> int:
    try:
        import fitz  # PyMuPDF
    except ImportError:
        print(
            "PyMuPDF is required: pip install pymupdf",
            file=sys.stderr,
        )
        return 2

    jobs = load_jobs(csv_path)
    if only:
        filtered: list[tuple[int, int, str]] = []
        for page, rotate, name in jobs:
            token = f"{page}{'r' if rotate else ''}"
            if token in only or str(page) in only:
                filtered.append((page, rotate, name))
        jobs = filtered

    if not jobs:
        print("No matching page tokens found.")
        return 1

    out_dir.mkdir(parents=True, exist_ok=True)
    doc = fitz.open(pdf_path)
    written = 0
    for page, rotate, name in jobs:
        # CSV / books often use 1-based printed page numbers.
        index = page - 1
        if index < 0 or index >= doc.page_count:
            print(f"SKIP {page}: out of range (pdf has {doc.page_count} pages) — {name}")
            continue
        out_path = out_dir / f"{page}.png"
        flag = f" rotate={rotate}" if rotate else ""
        print(f"{'DRY ' if dry_run else ''}{page}{flag} → {out_path.name}  ({name})")
        if dry_run:
            continue
        pix = doc.load_page(index).get_pixmap(dpi=dpi, alpha=False)
        if rotate:
            # Pillow keeps rotation simple and matches CW degrees.
            from PIL import Image
            import io

            img = Image.open(io.BytesIO(pix.tobytes("png")))
            img = img.rotate(-rotate, expand=True)  # PIL is CCW-positive
            img.save(out_path)
        else:
            pix.save(out_path.as_posix())
        written += 1

    doc.close()
    print(f"Done. Wrote {written} image(s) to {out_dir}")
    return 0


def main() -> int:
    root = Path(__file__).resolve().parents[1]
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("pdf", type=Path, help="Source PDF")
    parser.add_argument(
        "--csv",
        type=Path,
        default=root / "assets/data/cards_128x185.csv",
        help="Deck CSV with number tokens",
    )
    parser.add_argument(
        "--out",
        type=Path,
        default=root / "assets/images/icon/c128x185",
        help="Output directory for {page}.png",
    )
    parser.add_argument(
        "--only",
        nargs="*",
        default=None,
        help="Optional page tokens to extract, e.g. 258r 259r",
    )
    parser.add_argument("--dpi", type=int, default=150)
    parser.add_argument("--dry-run", action="store_true")
    args = parser.parse_args()

    only = set(args.only) if args.only else None
    return extract(
        args.pdf,
        args.out,
        args.csv,
        only=only,
        dry_run=args.dry_run,
        dpi=args.dpi,
    )


if __name__ == "__main__":
    raise SystemExit(main())
