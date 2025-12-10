#!/usr/bin/env python3
"""
Run `setup_seed_configs.sh` inside a disposable staging copy of `media/`.

This script:
- creates a timestamped staging directory (or uses `--staging-dir`)
- copies the entire `media/` tree into the staging dir
- runs `media/scripts/setup_seed_configs.sh` inside the staging tree
- prints a short summary of files created/changed under `staging/media/.config`

This is safe: it never writes to the repo's `media/.config`.
"""
import shutil
import subprocess
from pathlib import Path
import tempfile
import argparse
import datetime
import sys


def run(staging_dir: Path, media_dir: Path):
    # Copy media/ -> staging_dir/media
    target = staging_dir / 'media'
    print(f"Creating minimal staging copy: {target}")
    if target.exists():
        print("Staging target exists, removing...")
        shutil.rmtree(target)
    target.mkdir(parents=True)

    # Copy scripts directory entirely
    src_scripts = media_dir / 'scripts'
    if src_scripts.exists():
        shutil.copytree(src_scripts, target / 'scripts')

    # Copy .config if it exists (credentials etc.)
    src_cfg = media_dir / '.config'
    if src_cfg.exists():
        shutil.copytree(src_cfg, target / '.config')

    # Copy .env if present
    src_env = media_dir / '.env'
    if src_env.exists():
        shutil.copy2(src_env, target / '.env')

    # Copy each service's config.xml only (avoid sockets / volumes)
    services = ['sonarr', 'radarr', 'lidarr', 'prowlarr', 'bazarr', 'qbittorrent', 'nzbget', 'jellyfin']
    for svc in services:
        src = media_dir / svc / 'config.xml'
        if src.exists():
            dst_dir = target / svc
            dst_dir.mkdir(parents=True, exist_ok=True)
            shutil.copy2(src, dst_dir / 'config.xml')

    script = target / 'scripts' / 'setup_seed_configs.sh'
    if not script.exists():
        print(f"Error: setup script not found at {script}")
        return 2

    # Ensure script is executable
    script.chmod(0o755)

    env = dict(**{k: v for k, v in subprocess.os.environ.items()})

    print(f"Running setup script in staging: {script}")
    proc = subprocess.run([str(script)], cwd=str(target / 'scripts'), env=env, capture_output=True, text=True)
    print("--- STDOUT ---")
    print(proc.stdout)
    print("--- STDERR ---")
    print(proc.stderr, file=sys.stderr)

    # Summarize staging .config
    cfg = target / '.config'
    print("\nStaging .config summary:")
    if not cfg.exists():
        print("  (no .config generated)")
        return proc.returncode

    for service in ['sonarr', 'radarr', 'lidarr', 'prowlarr', 'bazarr', 'qbittorrent', 'nzbget']:
        p = cfg / service / 'config.xml'
        if p.exists():
            print(f"  - {service}: {p} (size={p.stat().st_size})")
        else:
            # some services use different filenames (qbittorrent uses qBittorrent.conf)
            alt = cfg / service
            if alt.exists():
                print(f"  - {service}: directory exists: {alt}")
    return proc.returncode


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--staging-dir', type=Path, help='Path to staging dir (optional)')
    args = parser.parse_args()

    media_dir = Path(__file__).resolve().parents[2] / 'media'
    if not media_dir.exists():
        print(f"Error: media directory not found at {media_dir}")
        sys.exit(1)

    if args.staging_dir:
        staging = args.staging_dir.resolve()
        staging.mkdir(parents=True, exist_ok=True)
    else:
        ts = datetime.datetime.now().strftime('%Y%m%dT%H%M%S')
        staging = Path(tempfile.gettempdir()) / f'media_seed_staging_{ts}'
        staging.mkdir(parents=True, exist_ok=True)

    rc = run(staging, media_dir)
    print(f"Staging run complete. staging dir: {staging}")
    print("You can inspect the staging copy and then delete it when finished.")
    sys.exit(rc)


if __name__ == '__main__':
    main()
