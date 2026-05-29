#!/usr/bin/env python3
"""
subtitle_fallback.py

On-demand subtitle fallback for when Bazarr's AniDB mapping fails (show not yet
in anime-lists). Queries Bazarr for missing English subs, searches AnimeTosho
by series title + episode number, downloads English subtitle attachments and
places them as external .en.srt files next to the MKV.

Run on TrueNAS (Python 3.11 native) or inside arr-stack Docker network.

Environment variables (required):
    BAZARR_KEY      Bazarr API key
    SONARR_KEY      Sonarr API key
    JELLYFIN_KEY    Jellyfin API key (optional — triggers library refresh)

    BAZARR_BASE     default: http://bazarr:6767/bazarr/api  (in-network)
    SONARR_BASE     default: http://sonarr:8989             (in-network)
    JELLYFIN_BASE   default: http://jellyfin:8096           (in-network)

    # Path translation: Sonarr returns container paths, script writes to host paths
    SONARR_PATH_PREFIX   default: /data         (what Sonarr sees)
    HOST_PATH_PREFIX     default: /mnt/Data/media  (actual host path)

Usage:
    # All series with missing English subs:
    python3 subtitle_fallback.py

    # One series (use Sonarr series ID):
    python3 subtitle_fallback.py --series-id 107

    # Preview without writing files:
    python3 subtitle_fallback.py --dry-run

Run pattern (from workstation, with keys from Infisical):
    scp subtitle_fallback.py kero66@192.168.20.22:/tmp/sub_fallback.py
    ssh kero66@192.168.20.22 \\
      "BAZARR_KEY='...' SONARR_KEY='...' JELLYFIN_KEY='...' \\
       BAZARR_BASE=http://localhost:6767/bazarr/api \\
       SONARR_BASE=http://localhost:8989 \\
       JELLYFIN_BASE=http://localhost:8096 \\
       SONARR_PATH_PREFIX=/data \\
       HOST_PATH_PREFIX=/mnt/Data/media \\
       python3 /tmp/sub_fallback.py && rm /tmp/sub_fallback.py"
"""

import argparse
import json
import lzma
import os
import re
import sys
import urllib.parse
import urllib.request
from pathlib import Path
from typing import Optional

BAZARR_BASE = os.environ.get("BAZARR_BASE", "http://bazarr:6767/bazarr/api")
SONARR_BASE = os.environ.get("SONARR_BASE", "http://sonarr:8989")
JELLYFIN_BASE = os.environ.get("JELLYFIN_BASE", "http://jellyfin:8096")
SONARR_PATH_PREFIX = os.environ.get("SONARR_PATH_PREFIX", "/data")
HOST_PATH_PREFIX = os.environ.get("HOST_PATH_PREFIX", "/mnt/Data/media")

BAZARR_KEY = os.environ.get("BAZARR_KEY", "")
SONARR_KEY = os.environ.get("SONARR_KEY", "")
JELLYFIN_KEY = os.environ.get("JELLYFIN_KEY", "")


def _get(url: str, headers: dict = None) -> object:
    req = urllib.request.Request(url, headers=headers or {})
    with urllib.request.urlopen(req, timeout=20) as r:
        return json.loads(r.read())


def _fetch_bytes(url: str) -> bytes:
    req = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0"})
    with urllib.request.urlopen(req, timeout=30) as r:
        return r.read()


def _fetch_html(url: str) -> str:
    return _fetch_bytes(url).decode("utf-8", errors="replace")


def _post(url: str, headers: dict = None) -> int:
    req = urllib.request.Request(url, method="POST", headers=headers or {})
    with urllib.request.urlopen(req, timeout=10) as r:
        return r.status


def host_path(sonarr_path: str) -> str:
    """Translate Sonarr container path → TrueNAS host path."""
    if sonarr_path.startswith(SONARR_PATH_PREFIX):
        return HOST_PATH_PREFIX + sonarr_path[len(SONARR_PATH_PREFIX):]
    return sonarr_path


def bazarr_wanted(series_id: Optional[int] = None) -> list[dict]:
    data = _get(
        f"{BAZARR_BASE}/episodes/wanted?start=0&length=500",
        {"X-API-KEY": BAZARR_KEY},
    )
    episodes = data.get("data", [])
    if series_id:
        episodes = [e for e in episodes if e.get("sonarrSeriesId") == series_id]
    return episodes


def sonarr_episode_files(series_id: int) -> dict[int, dict]:
    """Return map of episodeFileId → file record."""
    files = _get(f"{SONARR_BASE}/api/v3/episodefile?seriesId={series_id}&apikey={SONARR_KEY}")
    return {f["id"]: f for f in files}


def sonarr_episodes(series_id: int) -> list[dict]:
    return _get(f"{SONARR_BASE}/api/v3/episode?seriesId={series_id}&apikey={SONARR_KEY}")


def animetosho_search(query: str) -> list[dict]:
    q = urllib.parse.quote(query)
    try:
        return _get(f"https://feed.animetosho.org/json?q={q}") or []
    except Exception:
        return []


def animetosho_eng_srt_urls(page_url: str) -> list[str]:
    """Scrape AnimeTosho release page for English .srt.xz attachment URLs."""
    try:
        html = _fetch_html(page_url)
    except Exception:
        return []
    return re.findall(
        r'https://animetosho\.org/storage/attach/[^"\']+\.eng\.srt\.xz',
        html,
    )


def find_eng_sub_url(series_title: str, episode_num: int) -> Optional[str]:
    """Search AnimeTosho for English subtitle attachment for this episode."""
    queries = [
        f"{series_title} S01E{episode_num:02d}",
        f"{series_title} E{episode_num:02d}",
    ]
    for query in queries:
        for result in animetosho_search(query):
            page_url = result.get("link", "")
            if not page_url:
                continue
            urls = animetosho_eng_srt_urls(page_url)
            if urls:
                return urls[0]
    return None


def main():
    if not BAZARR_KEY or not SONARR_KEY:
        print("ERROR: BAZARR_KEY and SONARR_KEY must be set.", file=sys.stderr)
        sys.exit(1)

    parser = argparse.ArgumentParser()
    parser.add_argument("--series-id", type=int, help="Target one Sonarr series ID")
    parser.add_argument("--dry-run", action="store_true", help="Preview without writing files")
    args = parser.parse_args()

    wanted = bazarr_wanted(args.series_id)
    if not wanted:
        print("No missing English subtitles in Bazarr.")
        return

    print(f"{len(wanted)} episode(s) missing English subs.\n")

    # Group by series
    by_series: dict[int, list[dict]] = {}
    for ep in wanted:
        by_series.setdefault(ep["sonarrSeriesId"], []).append(ep)

    downloaded = skipped = failed = 0

    for series_id, episodes in by_series.items():
        try:
            ep_files = sonarr_episode_files(series_id)
            sonarr_eps = sonarr_episodes(series_id)
        except Exception as exc:
            print(f"[ERROR] Sonarr fetch failed for series {series_id}: {exc}")
            failed += len(episodes)
            continue

        # Map episode number → file path
        ep_num_to_path: dict[int, str] = {}
        for ep in sonarr_eps:
            fid = ep.get("episodeFileId")
            if fid and fid in ep_files:
                ep_num_to_path[ep["episodeNumber"]] = ep_files[fid]["path"]

        series_title = episodes[0].get("seriesTitle", f"series-{series_id}")
        print(f"=== {series_title} ===")

        def parse_ep_num(ep: dict) -> int:
            # episode_number is "Sx{ep}" e.g. "1x26"
            raw = ep.get("episode_number", "0x0")
            try:
                return int(raw.split("x")[-1])
            except (ValueError, IndexError):
                return 0

        for ep in sorted(episodes, key=parse_ep_num):
            ep_num = parse_ep_num(ep)
            sonarr_path = ep_num_to_path.get(ep_num)

            if not sonarr_path:
                print(f"  E{ep_num:02d}: no file on disk — skip")
                skipped += 1
                continue

            mkv_host = host_path(sonarr_path)
            sub_host = re.sub(r"\.mkv$", ".en.srt", mkv_host, flags=re.IGNORECASE)

            if Path(sub_host).exists():
                print(f"  E{ep_num:02d}: .en.srt already exists — skip")
                skipped += 1
                continue

            print(f"  E{ep_num:02d}: searching AnimeTosho...", end=" ", flush=True)
            url = find_eng_sub_url(series_title, ep_num)

            if not url:
                print("not found")
                failed += 1
                continue

            if args.dry_run:
                print(f"[dry-run] would download {url}")
                downloaded += 1
                continue

            try:
                srt_bytes = lzma.decompress(_fetch_bytes(url))
                Path(sub_host).write_bytes(srt_bytes)
                print(f"OK ({len(srt_bytes):,} bytes)")
                downloaded += 1
            except Exception as exc:
                print(f"FAILED: {exc}")
                failed += 1

        print()

    print(f"downloaded={downloaded} skipped={skipped} failed={failed}")

    if downloaded and not args.dry_run and JELLYFIN_KEY:
        try:
            _post(f"{JELLYFIN_BASE}/Library/Refresh", {"X-Emby-Token": JELLYFIN_KEY})
            print("Jellyfin library refresh triggered.")
        except Exception:
            pass


if __name__ == "__main__":
    main()
