#!/usr/bin/env python3
"""Build the reconstructed v1.2.25.2802 Linux desktop app without sudo."""

import concurrent.futures
import hashlib
import os
from pathlib import Path
import shlex
import shutil
import subprocess
import urllib.request


ROOT = Path(__file__).resolve().parents[1]
TOOLCHAIN = ROOT / '.dart_tool/linux-toolchain'
PACKAGES = [
    'ninja-build', 'libgtk-3-dev', 'libsecret-1-dev',
    'libayatana-appindicator3-dev', 'libkeybinder-3.0-dev',
    'libxdo-dev', 'libcurl4-openssl-dev', 'libnotify-dev',
]
MODULES = ['gtk+-3.0', 'libsecret-1', 'ayatana-appindicator3-0.1',
           'keybinder-3.0', 'libcurl', 'libnotify']


def run(command, env=None, **kwargs):
    print('+', shlex.join(str(value) for value in command), flush=True)
    return subprocess.run(command, cwd=ROOT, env=env, check=True, **kwargs)


def local_environment():
    env = os.environ.copy()
    (ROOT / '.dart_tool/tmp').mkdir(parents=True, exist_ok=True)
    env['TMPDIR'] = str(ROOT / '.dart_tool/tmp')
    if TOOLCHAIN.is_dir():
        # Runtime packages may already be installed on the host. Their local
        # development symlinks must resolve there instead of selecting static
        # archives with incomplete transitive link dependencies.
        for library in (TOOLCHAIN / 'usr/lib/x86_64-linux-gnu').glob('*.so*'):
            if library.is_symlink() and not library.exists():
                name = Path(os.readlink(library)).name
                for directory in ['/usr/lib/x86_64-linux-gnu', '/lib/x86_64-linux-gnu']:
                    target = Path(directory) / name
                    if target.exists():
                        library.unlink()
                        library.symlink_to(target)
                        break
        env['PATH'] = str(TOOLCHAIN / 'usr/bin') + ':' + env['PATH']
        env['PKG_CONFIG_PATH'] = ':'.join([
            str(TOOLCHAIN / 'usr/lib/x86_64-linux-gnu/pkgconfig'),
            str(TOOLCHAIN / 'usr/share/pkgconfig'),
            env.get('PKG_CONFIG_PATH', ''),
        ])
        env['LD_LIBRARY_PATH'] = ':'.join([
            str(TOOLCHAIN / 'usr/lib/x86_64-linux-gnu'),
            env.get('LD_LIBRARY_PATH', ''),
        ])
    return env


def prepare_toolchain():
    env = local_environment()
    ready = shutil.which('ninja', path=env['PATH']) and subprocess.run(
        ['pkg-config', '--exists', *MODULES], env=env, check=False,
    ).returncode == 0
    if ready:
        return env
    if not shutil.which('apt-get') or not shutil.which('dpkg-deb'):
        raise SystemExit('Install Ninja and GTK/libsecret/AppIndicator/keybinder/curl development packages.')
    result = run([
        'apt-get', '--print-uris', '--yes', '--download-only',
        '--no-install-recommends', '-o', 'Debug::NoLocking=1',
        'install', *PACKAGES,
    ], capture_output=True, text=True)
    packages = [shlex.split(line) for line in result.stdout.splitlines()
                if line.startswith("'https://") or line.startswith("'http://")]
    archive_dir = TOOLCHAIN / 'archives'
    archive_dir.mkdir(parents=True, exist_ok=True)

    def download(package):
        url, filename, size, checksum = package
        destination = archive_dir / filename
        if not destination.exists():
            with urllib.request.urlopen(url, timeout=120) as source:
                destination.write_bytes(source.read())
        data = destination.read_bytes()
        algorithm, expected = checksum.split(':', 1)
        actual = hashlib.new(algorithm.lower().replace('sum', ''), data).hexdigest()
        if len(data) != int(size) or actual != expected:
            raise RuntimeError('Package checksum mismatch: ' + filename)
        return destination

    print(f'Preparing {len(packages)} native packages locally.', flush=True)
    with concurrent.futures.ThreadPoolExecutor(max_workers=6) as pool:
        for archive in pool.map(download, packages):
            run(['dpkg-deb', '-x', str(archive), str(TOOLCHAIN)],
                stdout=subprocess.DEVNULL)
            archive.unlink()
    for pc in TOOLCHAIN.glob('usr/**/pkgconfig/*.pc'):
        content = pc.read_text()
        if str(TOOLCHAIN) not in content:
            pc.write_text(content.replace('/usr', str(TOOLCHAIN / 'usr')))
    return local_environment()


def main():
    for required in ['flutter', 'go', 'clang++', 'cmake', 'pkg-config', 'git']:
        if not shutil.which(required):
            raise SystemExit('Required build tool is missing: ' + required)
    env = prepare_toolchain()
    if not (ROOT / 'bind/linux/core/karingService').is_file():
        run(['bash', str(ROOT / 'native/linux-core/build.sh')], env=env)
    run(['flutter', 'pub', 'get'], env=env)
    run([
        'flutter', 'build', 'linux', '--debug', '--no-pub',
        '--build-name', '1.2.25', '--build-number', '2802',
    ], env=env)
    bundle = ROOT / 'build/linux/x64/debug/bundle'
    print('Built:', bundle / 'karing')


if __name__ == '__main__':
    main()
