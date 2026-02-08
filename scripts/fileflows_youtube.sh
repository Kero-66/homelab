#!/bin/bash

# FileFlows YouTube Downloader - Direct API Script
# This bypasses the broken flow system and directly uses FileFlows yt-dlp

usage() {
    echo "Usage: $0 <YouTube_URL>"
    echo "Example: $0 \"https://www.youtube.com/watch?v=VIDEO_ID\""
    exit 1
}

if [ -z "$1" ]; then
    usage
fi

URL="$1"

echo "========================================"
echo "YouTube Downloader"
echo "========================================"
echo "URL: $URL"
echo "========================================"

# Get video info first
echo "Getting video info..."
INFO=$(docker exec fileflows yt-dlp --js-runtimes node --no-playlist --dump-json "$URL" 2>/dev/null)

# Extract title
TITLE=$(echo "$INFO" | python3 -c "import sys, json; data = json.load(sys.stdin); print(data.get('title', 'video').replace('/', '_').replace('\\n', ' ').replace('\\r', '')[:50])")

if [ -z "$TITLE" ]; then
    TITLE="video_"$(date +%s)
fi

SAFE_TITLE=$(echo "$TITLE" | sed 's/[^a-z0-9_\-]/_/g' | cut -c1-80)
OUTPUT_PATH="/data/youtube/$SAFE_TITLE.mkv"

echo "Title: $TITLE"
echo "Output: $OUTPUT_PATH"

# Download video
echo "Downloading..."
docker exec fileflows yt-dlp \
    --js-runtimes node \
    --no-playlist \
    -o "$OUTPUT_PATH" \
    --merge-output-format mkv \
    "$URL" >/dev/null 2>&1

# Check result
if [ $? -eq 0 ]; then
    echo "Success! Downloaded to: $OUTPUT_PATH"
    ls -lh "$OUTPUT_PATH" 2>/dev/null
else
    echo "Download failed"
    exit 1
fi
