import subprocess
import sys
import tempfile
with tempfile.TemporaryDirectory(prefix='majoris-site-cookies-') as root:
    subprocess.run([*sys.argv[1:],root],check=True,timeout=30)
