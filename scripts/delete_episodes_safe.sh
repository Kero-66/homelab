#!/usr/bin/env bash
set -eo pipefail

# Safe Sonarr episodefile deletion script
# Reads API key from repository credentials and deletes by episodefile id
CREDS="/mnt/library/repos/homelab/media/.config/.credentials"
if [ ! -f "$CREDS" ]; then
  echo "Credentials file not found: $CREDS" >&2
  exit 1
fi

API_KEY=$(grep -Ei 'sonarr' "$CREDS" | head -n1 | sed -E 's/^[^=]*=//; s/^"|"$//g')
API_KEY=${API_KEY:-}
if [ -z "$API_KEY" ]; then
  echo "No Sonarr API key found in $CREDS" >&2
  exit 1
fi

BASE="http://localhost:8989/sonarr/api/v3"
IDS=(119 120 122 123 175)

for id in "${IDS[@]}"; do
  echo "=== Processing episodefile id=$id ==="
  ep_json=$(curl -s -H "X-Api-Key: $API_KEY" "$BASE/episodefile/$id") || true
  path=$(echo "$ep_json" | jq -r '.path // empty')
  echo "Path: ${path:-<none>}"
  echo "Attempting API DELETE (deleteFiles=true) for episodefile/$id"
  status=$(curl -s -o /tmp/sonarr_del_response.json -w "%{http_code}" -X DELETE -H "X-Api-Key: $API_KEY" "$BASE/episodefile/$id?deleteFiles=true" ) || true
  echo "HTTP status: $status"
  if [[ "$status" =~ ^(200|204|202)$ ]]; then
    echo "Deleted via Sonarr API: id=$id"
    continue
  fi
  echo "API did not delete file (status $status). Trying to remove file from disk: $path"
  if [ -n "$path" ] && [ -f "$path" ]; then
    rm -v -- "$path" || echo "rm failed for $path"
  else
    echo "File not found on disk or path empty: $path"
  fi
  echo "Now attempting to delete episodefile record from Sonarr without deleteFiles param."
  curl -s -X DELETE -H "X-Api-Key: $API_KEY" "$BASE/episodefile/$id" | jq -c '.' || echo "DELETE record attempted for id $id"
done

echo "\nFinal check: Remaining English-marked episodefiles (if any):"
curl -s -H "X-Api-Key: $API_KEY" "$BASE/episodefile?seriesId=12" | jq '[.[] | {id:.id,path:.path} | select((.path//"") | test("English|Dub";"i"))]'
