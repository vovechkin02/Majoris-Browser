#!/usr/bin/env python3
"""Explicit, pinned Linux64 CEF SDK bootstrap. Never run during Meson configure."""
import argparse
import hashlib
import pathlib
import shutil
import subprocess
import tarfile
import urllib.request

VERSION = '152.0.14+g8a0b5b9+chromium-152.0.7977.167'
NAME = f'cef_binary_{VERSION}_linux64_minimal.tar.bz2'
# Publisher currently supplies SHA-1. This verifies corruption against a pinned
# digest; it is not a claim that SHA-1 is a modern signature mechanism.
SHA1 = '007ef6e820f2391d63845329e4ca186eec847905'
# Independently pinned repository digest of the qualified archive. This adds
# collision-resistant integrity checking, not a publisher signature.
SHA256 = '25cf8c95532060fda22c2f85de2e71ba0e0166d344e6741e0062935653efa94f'

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--destination', type=pathlib.Path, default=pathlib.Path('.cef'))
    args = parser.parse_args()
    dest = args.destination.resolve()
    dest.mkdir(parents=True, exist_ok=True)
    archive = dest / 'sdk.tar.bz2'
    if not archive.exists():
        partial = archive.with_suffix('.partial')
        print(f'Downloading pinned CEF SDK (~321 MB) to {dest}', flush=True)
        urllib.request.urlretrieve('https://cef-builds.spotifycdn.com/' + NAME, partial)
        partial.rename(archive)
    digest = hashlib.sha1()
    strong_digest = hashlib.sha256()
    with archive.open('rb') as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b''):
            digest.update(chunk)
            strong_digest.update(chunk)
    if digest.hexdigest() != SHA1 or strong_digest.hexdigest() != SHA256:
        raise SystemExit('CEF checksum mismatch: remove sdk.tar.bz2 and retry')
    with tarfile.open(archive) as tar:
        # Extract the verified distribution beneath its own directory first.
        tar.extractall(dest / 'distribution', filter='data')
    sdk = dest / 'distribution' / NAME.removesuffix('.tar.bz2')
    # Chromium resolves ICU relative to libcef.so, independent of resources_dir_path.
    shutil.copytree(sdk / 'Resources', sdk / 'Release', dirs_exist_ok=True)
    subprocess.run(['cmake', '-S', str(sdk), '-B', str(sdk / 'build'),
                    '-DCMAKE_BUILD_TYPE=Release', '-DUSE_SANDBOX=OFF'], check=True)
    # USE_SANDBOX is CEF's optional static Windows/macOS sandbox wrapper switch;
    # Linux renderer sandboxing remains enabled. Never pass --no-sandbox.
    subprocess.run(['cmake', '--build', str(sdk / 'build'), '--target', 'libcef_dll_wrapper', '-j4'], check=True)
    print(f'meson setup build -Dcef_root={sdk}')

if __name__ == '__main__':
    main()
