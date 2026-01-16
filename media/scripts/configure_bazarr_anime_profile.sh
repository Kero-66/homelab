#!/bin/bash
# configure_bazarr_anime_profile.sh
# Automates the creation of an Anime-optimized Language Profile in Bazarr
# and enables tagging synchronization from Sonarr/Radarr.

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MEDIA_DIR="$(dirname "$SCRIPT_DIR")"
source "$MEDIA_DIR/.config/.credentials"

BAZARR_HOST="http://localhost:6767/bazarr"
HEADERS=(-H "X-API-KEY: $BAZARR_API_KEY" -H "Content-Type: application/json")

echo "🎌 Configuring Bazarr Anime Language Profile..."

# 1. Enable Languages
echo "Enabling English and Japanese languages..."
# English is usually enabled by default, but let's be sure.
# Bazarr API for enabling languages is via PATCH /api/system/languages
curl -s -X PATCH "${HEADERS[@]}" -d '{"enabled": true}' "$BAZARR_HOST/api/system/languages/en" > /dev/null
curl -s -X PATCH "${HEADERS[@]}" -d '{"enabled": true}' "$BAZARR_HOST/api/system/languages/ja" > /dev/null

# 2. Check if Anime profile exists
EXISTING_PROFILE=$(curl -s "${HEADERS[@]}" "$BAZARR_HOST/api/system/languages/profiles" | jq -r '.[] | select(.name=="Anime") | .profileId')

if [ -n "$EXISTING_PROFILE" ]; then
    echo "✓ Anime Language Profile already exists (ID: $EXISTING_PROFILE)"
else
    echo "Creating Anime Language Profile..."
    # Create profile with English (Forced) and English (Normal)
    # The items array defines the languages.
    curl -s -X POST "${HEADERS[@]}" \
        -d '{
            "name": "Anime",
            "cutoff": 1,
            "items": [
                {
                    "language": "en",
                    "forced": "True",
                    "hi": "False",
                    "audio_exclude": "False"
                },
                {
                    "language": "en",
                    "forced": "False",
                    "hi": "False",
                    "audio_exclude": "False"
                }
            ]
        }' "$BAZARR_HOST/api/system/languages/profiles" > /dev/null
    echo "✓ Anime Language Profile created."
fi

# 3. Enable Tagging in Settings
echo "Enabling Tag-based profile synchronization..."
# We need to get current general settings, update them, and post back
SETTINGS=$(curl -s "${HEADERS[@]}" "$BAZARR_HOST/api/system/settings")
UPDATED_SETTINGS=$(echo "$SETTINGS" | jq '.general.movie_tag_enabled = true | .general.serie_tag_enabled = true')
curl -s -X POST "${HEADERS[@]}" -d "$UPDATED_SETTINGS" "$BAZARR_HOST/api/system/settings" > /dev/null
echo "✓ Tagging enabled in settings."

echo ""
echo "Next steps in Bazarr UI:"
echo "1. Go to Settings -> Languages"
echo "2. Map your 'anime' tag from Radarr/Sonarr to the 'Anime' profile"
echo "──────────────────────────────────────────────────────────"
