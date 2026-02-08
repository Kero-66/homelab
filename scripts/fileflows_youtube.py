#!/usr/bin/env python3
"""
FileFlows YouTube Downloader - Python wrapper
Usage: python fileflows_youtube.py "https://youtube.com/watch?v=..."
"""

import requests
import json
import sys
import os

FILEFLOWS_URL = os.environ.get("FILEFLOWS_URL", "http://localhost:19200")
FLOW_UID = "b86ac2bd-e89c-4861-8926-f66ba7a25887"


def download_youtube(url: str) -> dict:
    """Send YouTube URL to FileFlows for processing."""
    endpoint = f"{FILEFLOWS_URL}/api/library-file/manually-add"

    payload = {
        "FlowUid": FLOW_UID,
        "Files": [url],
        "CustomVariables": {}
    }

    response = requests.post(endpoint, json=payload)
    response.raise_for_status()
    return response.json()


def get_library_files():
    """Get list of library files to check status."""
    endpoint = f"{FILEFLOWS_URL}/api/library-file/list-all"
    response = requests.get(endpoint)
    response.raise_for_status()
    return response.json()


def main():
    if len(sys.argv) < 2:
        print("Usage: python fileflows_youtube.py <YouTube_URL>")
        print(f"Example: python fileflows_youtube.py \"https://www.youtube.com/watch?v=dQw4w9WgXcQ\"")
        sys.exit(1)

    url = sys.argv[1]
    print(f"Sending to FileFlows: {url}")

    try:
        result = download_youtube(url)
        print(f"Response: {result}")
        print("\nCheck FileFlows dashboard for processing status.")
    except requests.exceptions.RequestException as e:
        print(f"Error: {e}")
        sys.exit(1)


if __name__ == "__main__":
    main()
