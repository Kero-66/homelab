import requests
import json

SONARR_URL = "http://localhost:8989/sonarr"
SONARR_API_KEY = "5edb7c425d261a150c78395e3ed21536"
RADARR_URL = "http://localhost:7878/radarr"
RADARR_API_KEY = "dd4febe42d166d2c820783d4e6ee7cef"

def get_profiles(url, api_key):
    r = requests.get(f"{url}/api/v3/qualityprofile", headers={"X-Api-Key": api_key})
    return r.json()

def delete_profile(url, api_key, profile_id):
    r = requests.delete(f"{url}/api/v3/qualityprofile/{profile_id}", headers={"X-Api-Key": api_key})
    return r.status_code

print("--- SONARR PROFILES ---")
sonarr_profiles = get_profiles(SONARR_URL, SONARR_API_KEY)
for p in sonarr_profiles:
    print(f"ID: {p['id']}, Name: {p['name']}")

print("\n--- RADARR PROFILES ---")
radarr_profiles = get_profiles(RADARR_URL, RADARR_API_KEY)
for p in radarr_profiles:
    print(f"ID: {p['id']}, Name: {p['name']}")

# Attempt deletions of 2-12
print("\n--- ATTEMPTING DELETIONS ---")
for id in range(2, 13):
    status = delete_profile(SONARR_URL, SONARR_API_KEY, id)
    if status == 200:
        print(f"Deleted Sonarr ID {id}")
    elif status != 404:
        print(f"Failed Sonarr ID {id} (Status: {status})")

for id in range(2, 13):
    status = delete_profile(RADARR_URL, RADARR_API_KEY, id)
    if status == 200:
        print(f"Deleted Radarr ID {id}")
    elif status != 404:
        print(f"Failed Radarr ID {id} (Status: {status})")

def reassign_radarr(old_id, new_id):
    r = requests.get(f"{RADARR_URL}/api/v3/movie", headers={"X-Api-Key": RADARR_API_KEY})
    movies = r.json()
    ids = [m['id'] for m in movies if m.get('qualityProfileId') == old_id]
    if not ids:
        print(f"No movies found for Radarr ID {old_id}")
        return
    payload = {"movieIds": ids, "qualityProfileId": new_id}
    requests.put(f"{RADARR_URL}/api/v3/movie/editor", headers={"X-Api-Key": RADARR_API_KEY}, json=payload)
    print(f"Reassigned {len(ids)} movies from {old_id} to {new_id}")

print("\n--- REASSIGNING RADARR ---")
reassign_radarr(6, 13)
reassign_radarr(8, 14)

print("\n--- RETRYING DELETIONS ---")
print(f"Status 6: {delete_profile(RADARR_URL, RADARR_API_KEY, 6)}")
print(f"Status 8: {delete_profile(RADARR_URL, RADARR_API_KEY, 8)}")
