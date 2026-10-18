import functools
import http.server
import subprocess
import sys
import tempfile
import threading
import os
binary,helper,resources,fixtures=sys.argv[1:5]
page=sys.argv[5] if len(sys.argv)>5 else 'storage.html'
class Handler(http.server.SimpleHTTPRequestHandler):
    def translate_path(self,path):
        if path.startswith('/licensed-fixtures/') and os.environ.get('MAJORIS_MEDIA_FIXTURES'):
            import pathlib
            name=path.split('/')[-1]
            if name in ('h264.mp4','aac.m4a','h264-aac.mp4'):return str(pathlib.Path(os.environ['MAJORIS_MEDIA_FIXTURES'])/name)
        return super().translate_path(path)
server=http.server.ThreadingHTTPServer(('127.0.0.1',0),functools.partial(Handler,directory=fixtures))
threading.Thread(target=server.serve_forever,daemon=True).start()
with tempfile.TemporaryDirectory(prefix='majoris-permission-test-') as root:
    subprocess.run([binary,helper,resources,root,f'http://127.0.0.1:{server.server_port}/{page}'],check=True,timeout=30)
server.shutdown()
