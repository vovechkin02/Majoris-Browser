import http.server
import pathlib
import subprocess
import sys
import tempfile
import threading
import time
class Handler(http.server.BaseHTTPRequestHandler):
    def do_GET(self):
        self.send_response(200)
        self.send_header('Content-Type','application/octet-stream')
        self.send_header('Content-Disposition','attachment; filename="fixture.bin"')
        self.send_header('Content-Length',str(2*1024*1024))
        self.end_headers()
        try:
            for _ in range(128):
                self.wfile.write(b'x'*16384);self.wfile.flush();time.sleep(0.01)
        except (BrokenPipeError,ConnectionResetError):
            pass
server=http.server.ThreadingHTTPServer(('127.0.0.1',0),Handler)
threading.Thread(target=server.serve_forever,daemon=True).start()
with tempfile.TemporaryDirectory(prefix='majoris-download-test-') as root:
    subprocess.run([*sys.argv[1:],root,f'http://127.0.0.1:{server.server_port}/download'],check=True,timeout=35)
server.shutdown()
