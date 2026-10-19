import subprocess,sys,tempfile
with tempfile.TemporaryDirectory(prefix='majoris-download-ui-') as root:
    subprocess.run([sys.argv[1],root],check=True,timeout=15)
