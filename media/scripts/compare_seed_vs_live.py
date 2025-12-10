#!/usr/bin/env python3
"""
Compare seeded config files under media/.config/* with live configs under media/*/config.xml.
Reports differences for selected keys and can optionally overwrite seeds with live values.
"""
import xml.etree.ElementTree as ET
from pathlib import Path
import argparse
import shutil
import datetime

SERVICES = ["sonarr", "radarr", "lidarr", "prowlarr", "bazarr"]
KEYS = [
    'BindAddress', 'Port', 'SslPort', 'EnableSsl', 'LaunchBrowser', 'ApiKey',
    'AuthenticationMethod', 'AuthenticationRequired', 'BasicAuthUsername', 'BasicAuthPassword',
    'UrlBase', 'InstanceName', 'UpdateMechanism', 'LogLevel'
]

BASE = Path(__file__).resolve().parents[1]
SEED_DIR = BASE / '.config'
LIVE_DIR = BASE


def read_xml(path: Path):
    if not path.exists():
        return {}
    try:
        tree = ET.parse(path)
        root = tree.getroot()
    except Exception as e:
        return {'__error__': f'parse_error: {e}'}
    data = {}
    for k in KEYS:
        el = root.find(k)
        data[k] = el.text.strip() if (el is not None and el.text is not None) else None
    return data


def compare(service: str):
    seed_path = SEED_DIR / service / 'config.xml'
    live_path = LIVE_DIR / service / 'config.xml'
    seed = read_xml(seed_path)
    live = read_xml(live_path)
    if not seed and not live:
        return None
    return {'service': service, 'seed_path': str(seed_path), 'live_path': str(live_path), 'seed': seed, 'live': live}


def show_report(results):
    for r in results:
        if r is None:
            continue
        service = r['service']
        print(f"=== {service.upper()} ===")
        seed_err = r['seed'].get('__error__')
        live_err = r['live'].get('__error__')
        if seed_err:
            print(f"  Seed parse error: {seed_err}")
        if live_err:
            print(f"  Live parse error: {live_err}")
        for k in KEYS:
            s = r['seed'].get(k)
            l = r['live'].get(k)
            if s != l:
                print(f"  - {k}: SEED={repr(s)}  LIVE={repr(l)}")
        print("")


def sync_seeds(results, backup=True, dry_run=False, backup_dir=None):
    for r in results:
        if r is None:
            continue
        service = r['service']
        seed_path = Path(r['seed_path'])
        live_path = Path(r['live_path'])
        if not live_path.exists():
            print(f"Skipping {service}: live config not found: {live_path}")
            continue
        # make seed dir
        seed_dir = seed_path.parent
        seed_dir.mkdir(parents=True, exist_ok=True)
        # backup existing seed using a timestamped copy to avoid overwriting older backups
        if seed_path.exists() and backup:
            ts = datetime.datetime.now().strftime('%Y%m%dT%H%M%S')
            if backup_dir:
                dest = Path(backup_dir) / service
                bak = dest / (seed_path.name + f'.{ts}.bak')
                if dry_run:
                    print(f"Would back up {seed_path} -> {bak}")
                else:
                    dest.mkdir(parents=True, exist_ok=True)
                    shutil.copy2(seed_path, bak)
                    print(f"Backed up {seed_path} -> {bak}")
            else:
                bak = seed_path.with_name(seed_path.name + f'.{ts}.bak')
                if dry_run:
                    print(f"Would back up {seed_path} -> {bak}")
                else:
                    shutil.copy2(seed_path, bak)
                    print(f"Backed up {seed_path} -> {bak}")
        # copy live to seed
        if dry_run:
            print(f"Would update seed for {service}: {seed_path} (from {live_path})")
        else:
            content = live_path.read_text()
            seed_path.write_text(content)
            print(f"Updated seed for {service}: {seed_path}")


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--services', nargs='*', default=SERVICES)
    parser.add_argument('--sync', action='store_true', help='Overwrite seeds with live configs')
    parser.add_argument('--no-backup', action='store_true', help='Do not backup existing seed files')
    parser.add_argument('--dry-run', action='store_true', help='When used with --sync: show actions without writing files')
    parser.add_argument('--backup-dir', help='Directory to store timestamped backups (optional)')
    args = parser.parse_args()
    results = []
    for s in args.services:
        results.append(compare(s))
    show_report(results)
    if args.sync:
        sync_seeds(results, backup=not args.no_backup, dry_run=args.dry_run, backup_dir=args.backup_dir)

if __name__ == '__main__':
    main()
