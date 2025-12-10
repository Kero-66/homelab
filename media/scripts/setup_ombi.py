#!/usr/bin/env python3
"""
Ombi Complete Setup Script
Automatically configures Ombi for manga requests through Sonarr
"""

import requests
import json
import time
import sys
import os

# Colors
RED = '\033[0;31m'
GREEN = '\033[0;32m'
YELLOW = '\033[1;33m'
NC = '\033[0m'

# Configuration
OMBI_URL = "http://localhost:8000"
JELLYFIN_HOST = "jellyfin"
JELLYFIN_PORT = 8096
JELLYFIN_API_KEY = os.environ.get("JELLYFIN_API_KEY", "")
SONARR_HOST = "sonarr"
SONARR_PORT = 8989
SONARR_API_KEY = os.environ.get("SONARR_API_KEY", "")
SONARR_ROOT_PATH = "/data/manga"

def print_status(msg):
    print(f"{YELLOW}{msg}{NC}")

def print_success(msg):
    print(f"{GREEN}✓ {msg}{NC}")

def print_error(msg):
    print(f"{RED}✗ {msg}{NC}")
    sys.exit(1)

def wait_for_ombi():
    """Wait for Ombi to be ready"""
    print_status("Waiting for Ombi to be ready...")
    for i in range(60):
        try:
            resp = requests.get(f"{OMBI_URL}/api/v1/status", timeout=2)
            if resp.status_code == 200:
                print_success("Ombi is ready!")
                return
        except:
            pass
        
        if i % 10 == 0 and i > 0:
            print(f"  Still waiting... ({i}s)")
        time.sleep(1)
    
    print_error("Ombi failed to start after 60 seconds")

def configure_jellyfin():
    """Configure Jellyfin as media server"""
    print_status("Step 1: Configuring Jellyfin...")
    
    payload = {
        "enabled": True,
        "hostname": JELLYFIN_HOST,
        "port": JELLYFIN_PORT,
        "useSsl": False,
        "apiKey": JELLYFIN_API_KEY,
        "urlBase": "",
        "externalHostname": "",
        "enableEpisodeSearching": False
    }
    
    try:
        resp = requests.post(
            f"{OMBI_URL}/api/v1/settings/jellyfin",
            json=payload,
            headers={"Content-Type": "application/json"},
            timeout=10
        )
        if resp.status_code in [200, 201, 204]:
            print_success("Jellyfin configured")
            return True
        else:
            print_error(f"Failed to configure Jellyfin: {resp.status_code} - {resp.text}")
    except Exception as e:
        print_error(f"Error configuring Jellyfin: {str(e)}")

def configure_sonarr():
    """Configure Sonarr for manga"""
    print_status("Step 2: Configuring Sonarr for manga...")
    
    # Get quality profiles from Sonarr first
    try:
        resp = requests.get(
            f"http://{SONARR_HOST}:{SONARR_PORT}/api/v3/qualityProfile",
            headers={"X-Api-Key": SONARR_API_KEY},
            timeout=10
        )
        profiles = resp.json()
        quality_id = profiles[0].get('id', 1) if profiles else 1
        print(f"  Using quality profile ID: {quality_id}")
    except Exception as e:
        print(f"  Warning: Could not fetch quality profiles: {str(e)}")
        quality_id = 1
    
    payload = [{
        "name": "Sonarr - Manga",
        "hostname": SONARR_HOST,
        "port": SONARR_PORT,
        "useSsl": False,
        "apiKey": SONARR_API_KEY,
        "urlBase": "",
        "qualityProfile": str(quality_id),
        "qualityProfileAnime": str(quality_id),
        "seasonFolders": False,
        "rootPath": SONARR_ROOT_PATH,
        "rootPathAnime": SONARR_ROOT_PATH,
        "enabled": True,
        "isDefault": True
    }]
    
    try:
        resp = requests.post(
            f"{OMBI_URL}/api/v1/settings/sonarr",
            json=payload,
            headers={"Content-Type": "application/json"},
            timeout=10
        )
        if resp.status_code in [200, 201, 204]:
            print_success("Sonarr configured for manga")
            print(f"  Hostname: {SONARR_HOST}")
            print(f"  Port: {SONARR_PORT}")
            print(f"  Root Path: {SONARR_ROOT_PATH}")
            print(f"  Season Folders: Disabled")
            return True
        else:
            print_error(f"Failed to configure Sonarr: {resp.status_code} - {resp.text}")
    except Exception as e:
        print_error(f"Error configuring Sonarr: {str(e)}")

def main():
    print(f"\n{YELLOW}=== Ombi Complete Automatic Setup ==={NC}\n")
    
    wait_for_ombi()
    configure_jellyfin()
    configure_sonarr()
    
    print(f"\n{YELLOW}=== Setup Complete! ==={NC}")
    print(f"\n{GREEN}Your manga request system is ready!{NC}")
    print(f"\nYou can now:")
    print(f"  1. Open Ombi at {OMBI_URL}")
    print(f"  2. Search for manga titles")
    print(f"  3. Click 'Request' to add them to Sonarr")
    print(f"  4. Sonarr automatically downloads from Nyaa.si")
    print(f"  5. Files appear in {SONARR_ROOT_PATH}/")
    print()

if __name__ == "__main__":
    main()
