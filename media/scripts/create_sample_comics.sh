#!/usr/bin/env bash
set -euo pipefail

# Create representative sample comic/ebook/webtoon files and (optionally)
# create Books/Comics/Webtoons libraries in Jellyfin and trigger a scan.
#
# Usage:
#   cd media && ./scripts/create_sample_comics.sh
# The script reads `media/.env` for `BOOKS_DIR`, `MANGA_DIR`, `WEBTOONS_DIR`,
# `PUID`/`PGID` and `JELLYFIN_API_KEY` (optional). If Jellyfin is reachable and
# `JELLYFIN_API_KEY` is present, it will create libraries and request a refresh.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$ROOT_DIR"

# load .env if present
if [[ -f .env ]]; then
  set -a; source .env; set +a
fi

: ${BOOKS_DIR:=${DATA_DIR:-/data}/books}
: ${MANGA_DIR:=${DATA_DIR:-/data}/manga}
: ${WEBTOONS_DIR:=${DATA_DIR:-/data}/webtoons}

mkdir -p "$BOOKS_DIR" "$MANGA_DIR" "$WEBTOONS_DIR"

echo "Using library dirs:"
echo "  BOOKS:    $BOOKS_DIR"
echo "  MANGA:    $MANGA_DIR"
echo "  WEBTOONS: $WEBTOONS_DIR"

TMPDIR=$(mktemp -d)
cleanup() { rm -rf "$TMPDIR"; }
trap cleanup EXIT

pushd "$TMPDIR" >/dev/null

download_if_missing() {
  local url=$1 dest=$2
  if [[ -f "$dest" ]]; then
    echo "  exists: $dest"
    return 0
  fi
  echo "  downloading: $dest"
  curl -sSL "$url" -o "$dest"
}

echo "Creating sample manga (.cbz)"
mkdir -p manga_pages
for i in $(seq -w 1 6); do
  download_if_missing "https://picsum.photos/seed/manga${i}/800/1200" "manga_pages/${i}.jpg"
done
cat > manga_pages/ComicInfo.xml <<'EOF'
<?xml version="1.0"?>
<ComicInfo>
  <Title>Sample Manga</Title>
  <Series>Sample Manga Series</Series>
  <Number>1</Number>
  <Writer>Test Author</Writer>
  <Summary>Test manga used for UI checks.</Summary>
  <Publisher>TestPub</Publisher>
</ComicInfo>
EOF
zip -r "$MANGA_DIR/sample_manga.cbz" manga_pages >/dev/null 2>&1

echo "Creating sample webtoon (.cbz - tall image)"
mkdir -p webtoon_pages
download_if_missing "https://picsum.photos/seed/webtoon/800/3000" "webtoon_pages/001.jpg"
zip -r "$WEBTOONS_DIR/sample_webtoon.cbz" webtoon_pages >/dev/null 2>&1

echo "Creating sample PDF"
download_if_missing "https://www.w3.org/WAI/ER/tests/xhtml/testfiles/resources/pdf/dummy.pdf" "$BOOKS_DIR/sample_comic.pdf"

echo "Creating sample EPUB"
EPUBDIR=epub_tmp
mkdir -p "$EPUBDIR/META-INF" "$EPUBDIR/OEBPS/Text"
printf "application/epub+zip" > "$EPUBDIR/mimetype"
cat > "$EPUBDIR/META-INF/container.xml" <<'EOF'
<?xml version="1.0"?>
<container version="1.0" xmlns="urn:oasis:names:tc:opendocument:xmlns:container">
  <rootfiles>
    <rootfile full-path="OEBPS/content.opf" media-type="application/oebps-package+xml"/>
  </rootfiles>
</container>
EOF
cat > "$EPUBDIR/OEBPS/Text/chapter1.xhtml" <<'EOF'
<?xml version="1.0" encoding="utf-8"?>
<html xmlns="http://www.w3.org/1999/xhtml">
  <head>
    <title>Sample EPUB</title>
  </head>
  <body>
    <h1>Sample EPUB</h1>
    <p>This is a tiny EPUB created for testing Jellyfin book support.</p>
  </body>
</html>
EOF
cat > "$EPUBDIR/OEBPS/content.opf" <<'EOF'
<?xml version="1.0" encoding="utf-8"?>
<package xmlns="http://www.idpf.org/2007/opf" unique-identifier="bookid" version="2.0">
  <metadata xmlns:dc="http://purl.org/dc/elements/1.1/">
    <dc:title>Sample EPUB</dc:title>
    <dc:language>en</dc:language>
    <dc:identifier id="bookid">sample-epub-1</dc:identifier>
  </metadata>
  <manifest>
    <item id="chapter1" href="Text/chapter1.xhtml" media-type="application/xhtml+xml"/>
  </manifest>
  <spine toc="ncx">
    <itemref idref="chapter1"/>
  </spine>
</package>
EOF
pushd "$EPUBDIR" >/dev/null
zip -X0 ../sample_epub.epub mimetype >/dev/null 2>&1
zip -r9 ../sample_epub.epub * -x mimetype >/dev/null 2>&1
popd >/dev/null
mv "$TMPDIR/sample_epub.epub" "$BOOKS_DIR/sample_epub.epub"

# Fix permissions if running with PUID/PGID
if [[ -n "${PUID:-}" && -n "${PGID:-}" ]]; then
  echo "Setting ownership to ${PUID}:${PGID} on the created files"
  chown -R "${PUID}:${PGID}" "$BOOKS_DIR" "$MANGA_DIR" "$WEBTOONS_DIR" || true
fi

echo "Files created. Summary:"
ls -l "$BOOKS_DIR" | sed -n '1,200p'
ls -l "$MANGA_DIR" | sed -n '1,200p'
ls -l "$WEBTOONS_DIR" | sed -n '1,200p'

# Attempt to configure Jellyfin libraries if reachable and API key provided
JELLYFIN_URL="http://localhost:8096"
ACCESS_TOKEN="${JELLYFIN_API_KEY:-}"

if [[ -z "${ACCESS_TOKEN:-}" ]]; then
  echo "No JELLYFIN_API_KEY found in .env; skipping Jellyfin library creation."
  exit 0
fi

if ! curl -s -H "X-Emby-Token: $ACCESS_TOKEN" "$JELLYFIN_URL/Library/VirtualFolders" >/dev/null 2>&1; then
  echo "Jellyfin not reachable at $JELLYFIN_URL; files created but libraries not configured."
  exit 0
fi

echo "Checking existing Jellyfin libraries..."
EXISTING=$(curl -s -H "X-Emby-Token: $ACCESS_TOKEN" "$JELLYFIN_URL/Library/VirtualFolders")

add_library_if_missing() {
  local NAME=$1 HOST_PATH=$2
  echo "Handling $NAME -> $HOST_PATH"
  # Quick check: does the JSON returned by Jellyfin contain a Path entry matching $HOST_PATH?
  if printf '%s' "$EXISTING" | grep -F -q "\"Path\":\"$HOST_PATH\""; then
    echo "  • $NAME library already configured for $HOST_PATH"
  else
    echo "  + Creating $NAME -> $HOST_PATH"
    read -r -d '' BODY <<JSON || true
{"LibraryOptions":{"EnablePhotos":true,"EnableRealtimeMonitor":true,"EnableChapterImageExtraction":false,"ExtractChapterImagesDuringLibraryScan":false,"PathInfos":[{"Path":"$HOST_PATH"}]}}
JSON
    curl -s -X POST "$JELLYFIN_URL/Library/VirtualFolders?collectionType=books&refreshLibrary=false&name=$(python3 -c 'import urllib.parse,sys;print(urllib.parse.quote("'$NAME'"))')" \
      -H "X-Emby-Token: $ACCESS_TOKEN" -H "Content-Type: application/json" -d "$BODY" >/dev/null || true
  fi
}

add_library_if_missing "Books" "/data/books"
add_library_if_missing "Comics" "/data/manga"
add_library_if_missing "Webtoons" "/data/webtoons"

echo "Triggering Jellyfin library refresh"
curl -s -X POST "$JELLYFIN_URL/Library/Refresh" -H "X-Emby-Token: $ACCESS_TOKEN" >/dev/null || true

echo "Done. Visit Jellyfin UI to verify the new libraries and sample content: http://localhost:8096"

exit 0
