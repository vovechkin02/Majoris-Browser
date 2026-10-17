import functools
import http.server
import pathlib
import subprocess
import sys
import tempfile
import threading

binary, clearer, helper, resources, fixtures = sys.argv[1:]
class Handler(http.server.SimpleHTTPRequestHandler):
    sequence=0
    def do_GET(self):
        if self.path=='/cache-probe':
            Handler.sequence+=1
            body=str(Handler.sequence).encode()
            self.send_response(200)
            self.send_header('Cache-Control','public, max-age=3600')
            self.send_header('Content-Length',str(len(body)))
            self.end_headers()
            self.wfile.write(body)
        else:
            super().do_GET()
server=http.server.ThreadingHTTPServer(('127.0.0.1',0),functools.partial(Handler,directory=fixtures))
threading.Thread(target=server.serve_forever,daemon=True).start()
with tempfile.TemporaryDirectory(prefix='majoris-storage-') as temp:
    root=pathlib.Path(temp)/'contexts'
    root.mkdir()
    url=f'http://127.0.0.1:{server.server_port}/storage.html'
    subprocess.run([binary,helper,resources,str(root),url,'create'],check=True,timeout=45)
    subprocess.run([clearer,helper,resources,str(root/'browser'),'clear'],check=True)
    subprocess.run([binary,helper,resources,str(root),url,'restore'],check=True,timeout=45)
server.shutdown()
