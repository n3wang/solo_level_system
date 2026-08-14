#!/usr/bin/env python3
"""Download D&D 5e monster manual images from aidedd.org into
assets/images/icon/dnd5e/, matched by unique_id from assets/data/dnd5e.csv.

aidedd.org doesn't expose predictable image filenames (many stat blocks
share a single illustration - e.g. every age category of black dragon uses
images/black-dragon.jpg - and plenty of mundane beasts have no dedicated
illustration at all). So for each unique_id this script:

  1. Fetches https://www.aidedd.org/dnd/monstres.php?vo=<unique_id>
  2. Extracts the real image URL from the page's <div class='picture'> block
  3. Downloads that image to assets/images/icon/dnd5e/<unique_id>.jpg

Creatures with no picture on the source page are recorded as "no image"
rather than treated as a download failure.

Usage:
    python3 scripts/download_dnd5e_images.py [--force] [--delay 0.4]
"""
import argparse
import csv
import re
import time
import urllib.error
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
CSV_PATH = ROOT / "assets" / "data" / "dnd5e.csv"
OUT_DIR = ROOT / "assets" / "images" / "icon" / "dnd5e"
PAGE_URL = "https://www.aidedd.org/dnd/monstres.php?vo={}"
HEADERS = {
    "User-Agent": (
        "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) "
        "AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0 Safari/537.36"
    )
}
PICTURE_RE = re.compile(r"<div class='picture'><img src='([^']+)'")


def fetch(url: str, timeout: float) -> bytes:
    req = urllib.request.Request(url, headers=HEADERS)
    with urllib.request.urlopen(req, timeout=timeout) as resp:
        return resp.read()


def find_image_url(unique_id: str, timeout: float) -> str | None:
    html = fetch(PAGE_URL.format(unique_id), timeout).decode("utf-8", "ignore")
    match = PICTURE_RE.search(html)
    return match.group(1) if match else None


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--force", action="store_true", help="Re-download files that already exist")
    parser.add_argument("--delay", type=float, default=0.4, help="Seconds to wait between requests")
    parser.add_argument("--timeout", type=float, default=15.0, help="Per-request timeout in seconds")
    args = parser.parse_args()

    OUT_DIR.mkdir(parents=True, exist_ok=True)

    with CSV_PATH.open(newline="", encoding="utf-8") as f:
        rows = list(csv.DictReader(f))

    total = len(rows)
    downloaded = 0
    skipped = 0
    no_image = []
    failed = []

    for i, row in enumerate(rows, start=1):
        unique_id = row["unique_id"]
        dest = OUT_DIR / f"{unique_id}.jpg"

        if dest.exists() and not args.force:
            skipped += 1
            continue

        try:
            image_url = find_image_url(unique_id, args.timeout)
            if image_url is None:
                no_image.append(unique_id)
                print(f"[{i}/{total}] NONE  {unique_id} (no illustration on source page)")
                time.sleep(args.delay)
                continue

            dest.write_bytes(fetch(image_url, args.timeout))
            downloaded += 1
            print(f"[{i}/{total}] OK    {unique_id} <- {image_url.rsplit('/', 1)[-1]}")
        except urllib.error.HTTPError as e:
            failed.append((unique_id, f"HTTP {e.code}"))
            print(f"[{i}/{total}] FAIL  {unique_id} (HTTP {e.code})")
        except (urllib.error.URLError, TimeoutError, OSError) as e:
            failed.append((unique_id, str(e)))
            print(f"[{i}/{total}] FAIL  {unique_id} ({e})")

        time.sleep(args.delay)

    print()
    print(
        f"Done. downloaded={downloaded} skipped(existing)={skipped} "
        f"no_image={len(no_image)} failed={len(failed)} total={total}"
    )

    if no_image:
        report_path = ROOT / "scripts" / "dnd5e_no_image.txt"
        report_path.write_text("\n".join(no_image) + "\n", encoding="utf-8")
        print(f"No-image list written to {report_path}")

    if failed:
        report_path = ROOT / "scripts" / "dnd5e_download_failures.txt"
        with report_path.open("w", encoding="utf-8") as f:
            for unique_id, reason in failed:
                f.write(f"{unique_id}\t{reason}\n")
        print(f"Failure list written to {report_path}")


if __name__ == "__main__":
    main()
