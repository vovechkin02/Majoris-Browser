#!/usr/bin/env python3
"""Build Debian packages from current source on a native Linux filesystem."""
import argparse
import json
import os
import pathlib
import shutil
import subprocess
import tempfile
import time

repo = pathlib.Path(__file__).resolve().parents[1]
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--cef-root', type=pathlib.Path, required=True)
parser.add_argument('--output-directory', type=pathlib.Path,
                    default=repo / ('build-packages-' + str(time.time_ns())))
args = parser.parse_args()
output = args.output_directory.resolve()
if not output.is_relative_to(repo) or output == repo or output.exists():
    raise SystemExit('Choose a new output directory inside this repository')
paths = subprocess.check_output(
    ['git', 'ls-files', '-z', '--cached', '--others', '--exclude-standard'],
    cwd=repo).decode().split('\0')
environment = dict(os.environ, CEF_ROOT=str(args.cef_root.resolve()))
if 'nocheck' in environment.get('DEB_BUILD_OPTIONS', '').split():
    raise SystemExit('Package verification requires tests; remove DEB_BUILD_OPTIONS=nocheck')
# /tmp must be a native Linux filesystem. Windows-mounted source trees may
# report mode 0777 even after chmod, which dpkg correctly refuses for DEBIAN.
with tempfile.TemporaryDirectory(prefix='majoris-package-', dir='/tmp') as temp:
    root = pathlib.Path(temp)
    source = root / 'source'
    source.mkdir()
    for name in dict.fromkeys(paths):
        original = repo / name
        if not name or name.endswith('.zip') or not original.is_file() or original.is_symlink():
            continue
        target = source / name
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(original, target)
        target.chmod(0o644)
    shutil.copytree(source / 'packaging/debian', source / 'debian')
    rules = source / 'debian/rules'
    rules.write_text(rules.read_text())
    rules.chmod(0o755)
    subprocess.run(['dpkg-buildpackage', '-b', '-uc', '-us'], cwd=source,
                   env=environment, check=True)
    logs = source / 'obj-x86_64-linux-gnu/meson-logs'
    expected = {'download-scanner', 'domain', 'threat-protection', 'web-risk-provider', 'cef-threat-navigation', 'cef-media-playback', 'cef-close', 'cef-permissions', 'cef-downloads',
                'cef-site-cookies', 'cef-storage-isolation', 'cef-credentials',
                'cef-cookie-isolation', 'cef-native-notifications', 'gtk-smoke',
                'cef-exit', 'app-uninstall', 'cef-modern-credentials', 'gtk-drag',
                'cef-accessibility', 'gtk-accessibility', 'cef-authentication',
                'cef-platform', 'cef-context-menus', 'cef-printing'}
    results = [json.loads(line) for line in (logs / 'testlog.json').read_text().splitlines()]
    if {result['name'] for result in results} != expected or any(
            result['result'] != 'OK' for result in results):
        raise SystemExit('The complete required package test suite did not pass')
    if 'stack smashing detected' in (logs / 'testlog.txt').read_text():
        raise SystemExit('Subprocess stack-canary failure appeared in package test output')
    output.mkdir()
    for pattern in ('*.deb', '*.buildinfo', '*.changes'):
        for artifact in root.glob(pattern):
            shutil.copy2(artifact, output / artifact.name)
    print('Verified package build artifacts:', output, flush=True)
