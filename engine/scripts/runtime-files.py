"""Exact SDK inputs installed by native/cef/meson.build."""
import hashlib
import pathlib

LIBRARIES = ('libcef.so', 'chrome-sandbox', 'libvk_swiftshader.so',
             'libvulkan.so.1', 'v8_context_snapshot.bin', 'vk_swiftshader_icd.json')


def digest(path):
    with path.open('rb') as stream:
        return hashlib.file_digest(stream, 'sha256').hexdigest()


def installed_path(name):
    path = pathlib.PurePosixPath(name)
    if path.is_absolute() or '..' in path.parts:
        raise ValueError('Invalid SDK inventory path')
    if name == 'LICENSE.txt':
        return 'usr/share/licenses/majoris-browser/CEF-LICENSE.txt'
    if name == 'CREDITS.html':
        return 'usr/share/licenses/majoris-browser/CREDITS.html'
    if path.parts[0] not in ('Release', 'Resources'):
        raise ValueError('Unexpected SDK inventory input')
    return 'usr/lib/x86_64-linux-gnu/majoris-browser/cef/' + '/'.join(path.parts[1:])


def inventory(sdk):
    sdk = pathlib.Path(sdk).resolve()
    for directory in ('Release', 'Resources'):
        if (sdk / directory).is_symlink() or not (sdk / directory).is_dir():
            raise ValueError('Missing or symlinked SDK runtime directory')
    names = ['Release/' + name for name in LIBRARIES] + ['LICENSE.txt', 'CREDITS.html']
    for path in (sdk / 'Resources').rglob('*'):
        if path.is_symlink():
            raise ValueError('Symlinked SDK resource')
        if path.is_file():
            names.append(path.relative_to(sdk).as_posix())
    if 'Resources/icudtl.dat' not in names or 'Resources/resources.pak' not in names:
        raise ValueError('Missing mandatory SDK resources')
    result = {}
    for name in names:
        path = sdk / name
        if path.is_symlink() or not path.is_file():
            raise ValueError('Missing or symlinked SDK input: ' + name)
        result[name] = digest(path)
    return result


def verify(sdk, metadata, required=False):
    expected = metadata.get('runtime_files')
    if expected is None and not required:
        return  # Historical development SDK; cannot qualify a release record.
    if not isinstance(expected, dict) or expected != inventory(sdk):
        raise ValueError('SDK runtime/resources/notices differ from build inventory')
