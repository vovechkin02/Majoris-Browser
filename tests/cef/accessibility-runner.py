import functools
import http.server
import pathlib
import subprocess
import sys
import tempfile
import threading
binary, helper, resources, fixtures = sys.argv[1:5]
server=http.server.ThreadingHTTPServer(('127.0.0.1',0),functools.partial(http.server.SimpleHTTPRequestHandler,directory=fixtures))
threading.Thread(target=server.serve_forever,daemon=True).start()
with tempfile.TemporaryDirectory(prefix='majoris-accessibility-') as root:
    output=pathlib.Path(sys.argv[5]) if len(sys.argv)>5 else pathlib.Path(root)/'tree.json'
    subprocess.run([binary,helper,resources,root,f'http://127.0.0.1:{server.server_port}/accessibility.html',str(output)],check=True,timeout=25)
server.shutdown()
