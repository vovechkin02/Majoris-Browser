import pathlib
import subprocess
import sys
import tempfile

binary, helper, resources = sys.argv[1:]
with tempfile.TemporaryDirectory(prefix='majoris-contexts-') as root:
    base=pathlib.Path(root)
    subprocess.run([binary, helper, resources, root, 'create'], check=True, timeout=45)
    subprocess.run([binary, helper, resources, str(base / 'browser'), 'clear'], check=True)
    assert not (base / 'browser').exists()
    assert (base / 'fixture').is_dir()
    subprocess.run([binary, helper, resources, root, 'restore'], check=True, timeout=45)
    (base / 'link').symlink_to(base / 'fixture', target_is_directory=True)
    assert subprocess.run([binary, helper, resources, str(base / 'link'), 'clear']).returncode != 0
    assert (base / 'fixture').is_dir()
    subprocess.run([binary, helper, resources, str(base / 'fixture'), 'clear'], check=True)
    assert not (base / 'fixture').exists()
    assert (base / 'browser').is_dir()
    private=base / 'private-case'
    private.mkdir()
    subprocess.run([binary, helper, resources, str(private), 'private'], check=True, timeout=45)
    assert not (private / 'browser').exists()
