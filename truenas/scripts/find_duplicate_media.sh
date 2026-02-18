#!/bin/bash
# Script to identify and remove duplicate files in TrueNAS media folders
# Run this directly on TrueNAS

MEDIA_ROOT="/mnt/Data/media"
SHOWS_DIR="$MEDIA_ROOT/shows"
RECYCLE_DIR="$MEDIA_ROOT/.recycle"

echo "=== Checking for .recycle folder ==="
if [ -d "$RECYCLE_DIR" ]; then
    echo "Found .recycle folder"
    du -sh "$RECYCLE_DIR"
else
    echo "No .recycle folder found at $RECYCLE_DIR"
fi

echo ""
echo "=== Checking for shows folder ==="
if [ -d "$SHOWS_DIR" ]; then
    echo "Found shows folder"
    du -sh "$SHOWS_DIR"
else
    echo "No shows folder found at $SHOWS_DIR"
    echo "Looking for shows folder..."
    find "$MEDIA_ROOT" -type d -name "shows" 2>/dev/null
fi

echo ""
echo "=== Finding potential duplicate files ==="
echo "This will look for files that exist in both shows and .recycle folders"

if [ -d "$RECYCLE_DIR" ] && [ -d "$SHOWS_DIR" ]; then
    echo ""
    echo "Scanning .recycle folder for video files..."
    find "$RECYCLE_DIR" -type f \( -name "*.mkv" -o -name "*.mp4" -o -name "*.avi" \) 2>/dev/null | while read -r recycle_file; do
        # Get just the filename
        filename=$(basename "$recycle_file")
        # Check if this file exists in shows
        if find "$SHOWS_DIR" -type f -name "$filename" 2>/dev/null | grep -q .; then
            echo "DUPLICATE: $filename"
            echo "  Recycle: $recycle_file"
            shows_file=$(find "$SHOWS_DIR" -type f -name "$filename" 2>/dev/null | head -1)
            echo "  Shows:   $shows_file"
            
            # Compare file sizes
            recycle_size=$(stat -f%z "$recycle_file" 2>/dev/null || stat -c%s "$recycle_file" 2>/dev/null)
            shows_size=$(stat -f%z "$shows_file" 2>/dev/null || stat -c%s "$shows_file" 2>/dev/null)
            
            if [ "$recycle_size" -eq "$shows_size" ]; then
                echo "  Size: Both files are $recycle_size bytes (SAME SIZE)"
            else
                echo "  Size: Recycle=$recycle_size, Shows=$shows_size (DIFFERENT)"
            fi
        fi
    done
fi

echo ""
echo "=== Summary ==="
echo "Review the duplicates above. To remove them, run:"
echo "  find /mnt/Data/media/.recycle -type f -name 'FILENAME' -delete"
