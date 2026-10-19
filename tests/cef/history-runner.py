import collections,http.server,json,os,pathlib,signal,subprocess,sys,tempfile,threading,time
counts=collections.Counter()
class Handler(http.server.BaseHTTPRequestHandler):
    def do_GET(self):
        if self.path=='/counts':body=json.dumps(counts).encode();kind='application/json'
        else:
            if self.path in ('/a','/b','/c'):counts[self.path]+=1
            body=('<!doctype html><title>History '+self.path+'</title><h1>History fixture</h1>').encode();kind='text/html'
        self.send_response(200);self.send_header('Content-Type',kind);self.send_header('Content-Length',str(len(body)));self.end_headers();self.wfile.write(body)
    def log_message(self,*args):pass
server=http.server.ThreadingHTTPServer(('127.0.0.1',0),Handler)
threading.Thread(target=server.serve_forever,daemon=True).start()
try:
    with tempfile.TemporaryDirectory(prefix='majoris-history-') as root:subprocess.run(sys.argv[1:4]+[root,f'http://127.0.0.1:{server.server_port}'],check=True,timeout=40)
    counts.clear()
    with tempfile.TemporaryDirectory(prefix='majoris-history-crash-') as root:
        command=sys.argv[1:4]+[root,f'http://127.0.0.1:{server.server_port}']
        process=subprocess.Popen(command+['crash-seed'],start_new_session=True)
        try:
            deadline=time.monotonic()+15
            while not (pathlib.Path(root)/'crash-ready').exists():
                assert process.poll() is None and time.monotonic()<deadline,'Crash checkpoint was not persisted'
                time.sleep(.05)
            # Kill only this disposable fixture's own process group, including
            # its CEF children. Do not run a clean browser shutdown first.
            os.killpg(process.pid,signal.SIGKILL);process.wait(timeout=5)
            subprocess.run(command+['recover'],check=True,timeout=40)
            print('Abrupt process-group death and persistent-profile history recovery: PASS',flush=True)
        finally:
            if process.poll() is None:os.killpg(process.pid,signal.SIGKILL);process.wait(timeout=5)
finally:server.shutdown();server.server_close()
