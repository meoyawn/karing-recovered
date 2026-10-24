#!/usr/bin/env python3
"""Apply recovered sources to the pinned public tag; optionally build debug."""

import argparse
import hashlib
import json
from pathlib import Path
import shutil
import subprocess
import sys


ROOT = Path(__file__).resolve().parents[1]


def run(arguments, cwd=None, capture=False):
    return subprocess.run(
        arguments, cwd=cwd, check=True, text=True,
        stdout=subprocess.PIPE if capture else None,
    )


def verify_overlay(manifest):
    for item in manifest['overlay_files']:
        source = ROOT / 'overlay' / item['path']
        if hashlib.sha256(source.read_bytes()).hexdigest() != item['sha256']:
            raise SystemExit('Overlay differs from its manifest: ' + item['path'])


def verify_prepared(destination, manifest):
    for item in manifest['overlay_files']:
        target = destination / item['path']
        if not target.is_file() or hashlib.sha256(target.read_bytes()).hexdigest() != item['sha256']:
            raise SystemExit('Prepared source has changed; choose another --destination: ' + str(target))
    run(['git', 'apply', '--reverse', '--check', str(ROOT / manifest['patch'])], cwd=destination)


def prepare(destination, manifest):
    marker = destination / '.karing-recovered.json'
    manifest_hash = hashlib.sha256((ROOT / 'upstream.json').read_bytes()).hexdigest()
    verify_overlay(manifest)
    if not destination.exists():
        destination.parent.mkdir(parents=True, exist_ok=True)
        run([
            'git', 'clone', '--depth', '1', '--single-branch', '--branch',
            manifest['tag'], manifest['repository'], str(destination),
        ])
    if not (destination / '.git').exists():
        raise SystemExit('Destination is not a Git checkout: ' + str(destination))
    revision = run(['git', 'rev-parse', 'HEAD'], cwd=destination, capture=True).stdout.strip()
    if revision != manifest['commit']:
        raise SystemExit('Destination is not the pinned upstream revision: ' + revision)
    if marker.exists():
        previous = json.loads(marker.read_text())
        if previous.get('manifest_sha256') != manifest_hash:
            raise SystemExit('Destination uses another overlay; choose another --destination.')
        verify_prepared(destination, manifest)
        return
    if run(['git', 'status', '--porcelain'], cwd=destination, capture=True).stdout.strip():
        raise SystemExit('Destination has existing changes; choose another --destination.')
    patch = str(ROOT / manifest['patch'])
    run(['git', 'apply', '--check', patch], cwd=destination)
    run(['git', 'apply', patch], cwd=destination)
    for item in manifest['overlay_files']:
        target = destination / item['path']
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(ROOT / 'overlay' / item['path'], target)
    verify_prepared(destination, manifest)
    marker.write_text(json.dumps({
        'manifest_sha256': manifest_hash,
        'upstream_commit': manifest['commit'],
    }, indent=2) + '\n')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--destination', type=Path, default=ROOT / 'work/karing')
    parser.add_argument('--build', action='store_true', help='Build the prepared Linux debug app.')
    args = parser.parse_args()
    destination = args.destination.expanduser().resolve()
    manifest = json.loads((ROOT / 'upstream.json').read_text())
    prepare(destination, manifest)
    print('Prepared recovered source:', destination, flush=True)
    if args.build:
        run([sys.executable, str(destination / 'scripts/build_linux.py')], cwd=destination)
    else:
        print('Build with:', sys.executable, destination / 'scripts/build_linux.py')


if __name__ == '__main__':
    main()
