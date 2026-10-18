import http.server,subprocess,sys,tempfile,threading
paths=[]
class Handler(http.server.BaseHTTPRequestHandler):
    def do_GET(self):
        paths.append(self.path)
        if self.path=='/redirect':self.send_response(302);self.send_header('Location','/bad');self.end_headers();return
        body=b'<title>BAD</title>' if self.path=='/bad' else b'<title>Allowed fixture</title>'
        self.send_response(200);self.send_header('Content-Length',str(len(body)));self.end_headers();self.wfile.write(body)
server=http.server.ThreadingHTTPServer(('127.0.0.1',0),Handler)
threading.Thread(target=server.serve_forever,daemon=True).start()
with tempfile.TemporaryDirectory(prefix='majoris-threat-') as root:
    subprocess.run([*sys.argv[1:],root,f'http://127.0.0.1:{server.server_port}'],check=True,timeout=20)
assert '/good' in paths and '/redirect' in paths and '/bad' not in paths,paths
server.shutdown()
