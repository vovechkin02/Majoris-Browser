#!/usr/bin/env python3
"""Inspect an amd64 Debian archive and smoke-test its extracted runtime."""
import argparse
import hashlib
import json
import os
import pathlib
import runpy
import subprocess
import tarfile
import tempfile

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('package', type=pathlib.Path)
args = parser.parse_args()
package = args.package.resolve()
repo = pathlib.Path(__file__).resolve().parents[1]
required = {
    'usr/bin/majoris-browser',
    'usr/libexec/majoris-browser-cef-subprocess',
    'usr/lib/x86_64-linux-gnu/majoris-browser/libmajoris-cef.so',
    'usr/lib/x86_64-linux-gnu/majoris-browser/cef/libcef.so',
    'usr/lib/x86_64-linux-gnu/majoris-browser/cef/chrome-sandbox',
    'usr/lib/x86_64-linux-gnu/majoris-browser/cef/icudtl.dat',
    'usr/lib/x86_64-linux-gnu/majoris-browser/cef/resources.pak',
    'usr/lib/x86_64-linux-gnu/majoris-browser/cef/locales/en-US.pak',
    'usr/share/applications/com.majoris.browser.desktop',
    'usr/share/glib-2.0/schemas/com.majoris.browser.gschema.xml',
    'usr/share/polkit-1/actions/com.majoris.browser.policy',
    'usr/share/licenses/majoris-browser/CEF-LICENSE.txt',
    'usr/share/licenses/majoris-browser/CREDITS.html',
}
errors = []
with subprocess.Popen(['dpkg-deb', '--fsys-tarfile', str(package)], stdout=subprocess.PIPE) as process:
    with tarfile.open(fileobj=process.stdout, mode='r|') as archive:
        for entry in archive:
            name = entry.name.removeprefix('./')
            if entry.uid != 0 or entry.gid != 0:
                errors.append('Archive contains non-root-owned entry: ' + name)
            if (entry.isfile() or entry.isdir()) and entry.mode & 0o002:
                errors.append('Archive contains a world-writable entry: ' + name)
            if name.endswith('/cef/chrome-sandbox') and entry.mode != 0o4755:
                errors.append('Sandbox helper must have mode 4755')
            required.discard(name)
    if process.wait() != 0 or required:
        raise SystemExit('Invalid archive or missing runtime files: ' + ', '.join(sorted(required)))
if errors:
    raise SystemExit('\n'.join(errors))
with tempfile.TemporaryDirectory(prefix='majoris-deb-runtime-', dir='/tmp') as temp:
    stage = pathlib.Path(temp)
    subprocess.run(['dpkg-deb', '--extract', str(package), str(stage)], check=True)
    binary = stage / 'usr/bin/majoris-browser'
    helper = stage / 'usr/libexec/majoris-browser-cef-subprocess'
    library = stage / 'usr/lib/x86_64-linux-gnu/majoris-browser'
    runtime = library / 'cef'
    provenance = runtime / 'majoris-runtime.json'
    if provenance.exists():
        metadata = json.loads(provenance.read_text())
        if metadata.get('schema') != 1 or hashlib.file_digest(
                (runtime / 'libcef.so').open('rb'), 'sha256').hexdigest() != metadata.get('libcef_sha256'):
            raise SystemExit('Installed custom engine provenance does not match libcef.so')
        runtime_files=runpy.run_path(str(repo/'engine/scripts/runtime-files.py'))
        for name,expected in metadata.get('runtime_files',{}).items():
            target=stage/runtime_files['installed_path'](name)
            if target.is_symlink() or not target.is_file() or runtime_files['digest'](target)!=expected:
                raise SystemExit('Installed runtime input differs from inventory: '+name)
        if not (stage / 'usr/share/licenses/majoris-browser/Majoris-engine-LICENSE.txt').is_file():
            raise SystemExit('Installed custom engine licence is missing')
    for executable in (binary, helper, library / 'libmajoris-cef.so'):
        dynamic = subprocess.check_output(['readelf', '-d', str(executable)], text=True)
        for line in dynamic.splitlines():
            if ('RPATH' in line or 'RUNPATH' in line) and ('.cef' in line or '/tmp/' in line or '/mnt/' in line):
                raise SystemExit('Installed runtime retains a build/SDK search path: ' + line)
    environment = dict(os.environ, LD_LIBRARY_PATH=str(library) + ':' + str(runtime))
    result = subprocess.run(['xvfb-run', '-a', 'dbus-run-session', '--', 'python3',
                    str(repo / 'tests/integration/smoke.py'), str(binary),
                    str(helper), str(runtime), str(repo)], env=environment,
                   stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                   text=True, timeout=75)
    print(result.stdout, end='')
    if result.returncode or 'stack smashing detected' in result.stdout:
        raise SystemExit('Extracted runtime smoke failed or emitted a subprocess canary failure')
print('Archive ownership, sandbox mode, resources, installed search paths and extracted GTK/CEF smoke: PASS')
