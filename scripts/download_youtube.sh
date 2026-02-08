#!/bin/bash

# Direct YouTube Download Script using yt-dlp with Node.js
# Usage: ./download_youtube.sh "https://youtube.com/watch?v=..."

set -e

DATA_DIR="${DATA_DIR:-/data}"
OUTPUT_DIR="${DATA_DIR}/youtube"
TEMP_DIR="${DATA_DIR}/temp/fileflows"

# Ensure directories exist
mkdir -p "$OUTPUT_DIR"
mkdir -p "$TEMP_DIR"

FFMPEG_PATH="/usr/local/bin/ffmpeg"
YTDLP_PATH="/usr/local/bin/yt-dlp"

if [ -z "$1" ]; then
    echo "Usage: $0 <YouTube_URL> [output_filename]"
    echo "Example: $0 \"https://www.youtube.com/watch?v=dQw4w9WgXcQ\""
    exit 1
fi

URL="$1"
FILENAME="${2:-}"

echo "========================================"
echo "YouTube Download Script"
echo "========================================"
echo "URL: $URL"
echo "Output Directory: $OUTPUT_DIR"
echo "Temp Directory: $TEMP_DIR"
echo "========================================"

# Get video info first
echo "Fetching video info..."
INFO=$("$YTDLP_PATH" --js-runtimes node --no-playlist --dump-json "$URL" 2>&1)

if [ $? -ne 0 ]; then
    echo "Error fetching video info:"
    echo "$INFO"
    exit 1
fi

# Extract title
TITLE=$(echo "$INFO" | python3 -c "import sys, json; print(json.load(sys.stdin).get('title', 'video').replace('/', '_'))")

if [ -z "$FILENAME" ]; then
    FILENAME="${TITLE}.mkv"
fi

OUTPUT_FILE="$OUTPUT_DIR/$FILENAME"
TEMP_FILE="$TEMP_DIR/$FILENAME"

echo "Video Title: $TITLE"
echo "Output File: $OUTPUT_FILE"
echo ""
echo "Starting download..."

# Download and transcode
"$YTDLP_PATH" \
    --js-runtimes node \
    -o "$TEMP_FILE" \
    --ffmpeg-location "$FFMPEG_PATH" \
    --embed-thumbnail \
    --convert-thumbnails webp \
    -t mkv \
    --no-playlist \
    "$URL"

if [ -f "$TEMP_FILE" ]; then
    SIZE=$(stat -f%z "$TEMP_FILE" 2>/dev/null || stat -c%s "$TEMP_FILE" 2>/dev/null || echo "unknown")
    echo ""
    echo "========================================"
    echo "Download complete!"
    echo "File: $TEMP_FILE"
    echo "Size: $SIZE bytes"
    echo "========================================"
    
    # Move to final location
    mv "$TEMP_FILE" "$OUTPUT_FILE"
    echo "Moved to: $OUTPUT_FILE"
else
    echo "Error: Downloaded file not found at $TEMP_FILE"
    exit 1
fi
