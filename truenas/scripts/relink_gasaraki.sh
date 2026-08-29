#!/usr/bin/env bash
set -euo pipefail

TORRENT_DIR="/mnt/Data/Servarr/downloads/qbittorrent/completed/[xPearse] Gasaraki [English Sub] [Dual-Audio] [480p]"
LIB_DIR="/mnt/Data/Servarr/shows/Gasaraki () [tvdbid-72726]/Season 01"

declare -A EP_TITLE=(
  [02]="002 - Opening Movements" [03]="003 - Tantric Circle" [04]="004 - Mirage"
  [05]="005 - The Touching" [06]="006 - The Puppet" [07]="007 - Return"
  [08]="008 - Harsh Worlds" [09]="009 - Storehouse" [10]="010 - Kugai"
  [11]="011 - Ties" [12]="012 - Unravel" [13]="013 - Disembark"
  [14]="014 - Companions" [15]="015 - The Threshold" [16]="016 - Karma"
  [17]="017 - Chaos" [18]="018 - Rear Window" [19]="019 - Wails"
  [20]="020 - Upheaval" [21]="021 - Run" [22]="022 - Personification"
  [23]="023 - Eternal" [24]="024 - Punctuation" [25]="025 - Gasara"
)

for ep in "${!EP_TITLE[@]}"; do
  src="$LIB_DIR/Gasaraki - S01E${ep} - ${EP_TITLE[$ep]} SDTV x264 AC3 2.0 [JA+EN] -xPearse [tvdbid-72726].mkv"
  dst="$TORRENT_DIR/[xPearse] Gasaraki - Episode ${ep} [English Sub] [Dual-Audio] [480p].mkv"
  if [ ! -f "$src" ]; then
    echo "MISSING SRC: $src"
    continue
  fi
  if [ -f "$dst" ]; then
    echo "ALREADY EXISTS: $dst"
    continue
  fi
  ln "$src" "$dst"
  echo "LINKED: E$ep"
done

echo "--- link counts ---"
for ep in "${!EP_TITLE[@]}"; do
  src="$LIB_DIR/Gasaraki - S01E${ep} - ${EP_TITLE[$ep]} SDTV x264 AC3 2.0 [JA+EN] -xPearse [tvdbid-72726].mkv"
  stat -c '%h %n' "$src" 2>/dev/null || true
done
