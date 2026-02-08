#!/bin/bash

# FileFlows YouTube Download Script
# Usage: ./fileflows_youtube_download.sh "https://youtube.com/watch?v=..."

FILEFLOWS_URL="${FILEFLOWS_URL:-http://localhost:19200}"
FLOW_UID="b86ac2bd-e89c-4861-8926-f66ba7a25887"

if [ -z "$1" ]; then
    echo "Usage: $0 <YouTube_URL>"
    echo "Example: $0 \"https://www.youtube.com/watch?v=dQw4w9WgXcQ\""
    exit 1
fi

URL="$1"

echo "Sending YouTube URL to FileFlows: $URL"
echo "Flow UID: $FLOW_UID"

curl -s -X POST "${FILEFLOWS_URL}/api/library-file/manually-add" \
  -H "Content-Type: application/json" \
  -d "{
    \"FlowUid\": \"${FLOW_UID}\",
    \"Files\": [\"${URL}\"],
    \"CustomVariables\": {}
  }"

echo ""
echo "Request sent. Check FileFlows dashboard for processing status."
