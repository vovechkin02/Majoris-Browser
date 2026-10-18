import functools
import http.server
import subprocess
import sys
import tempfile
import threading
binary,helper,resources,fixtures=sys.argv[1:5]
page=sys.argv[5] if len(sys.argv)>5 else 'storage.html'
server=http.server.ThreadingHTTPServer(('127.0.0.1',0),functools.partial(http.server.SimpleHTTPRequestHandler,directory=fixtures))
threading.Thread(target=server.serve_forever,daemon=True).start()
with tempfile.TemporaryDirectory(prefix='majoris-permission-test-') as root:
    subprocess.run([binary,helper,resources,root,f'http://127.0.0.1:{server.server_port}/{page}'],check=True,timeout=30)
server.shutdown()
