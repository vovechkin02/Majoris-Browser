"""Real trusted HTTPS renderer + disposable NSS trust and Secret Service."""
import functools
import http.server
import os
import pathlib
import ssl
import subprocess
import sys
import tempfile
import threading
import urllib.parse

binary, helper, resources, fixtures = sys.argv[1:5]
page=sys.argv[5] if len(sys.argv)>5 else 'login.html'
with tempfile.TemporaryDirectory(prefix='majoris-credentials-') as temp:
    root = pathlib.Path(temp)
    env = dict(os.environ, HOME=temp, XDG_DATA_HOME=str(root/'data'), XDG_CONFIG_HOME=str(root/'config'), XDG_CACHE_HOME=str(root/'cache'))
    cert, key = root/'cert.pem', root/'key.pem'
    subprocess.run(['openssl','req','-x509','-newkey','rsa:2048','-nodes','-keyout',str(key),'-out',str(cert),'-days','1','-subj','/CN=localhost','-addext','subjectAltName=DNS:localhost,IP:127.0.0.1','-addext','basicConstraints=critical,CA:TRUE'],check=True,stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL)
    for relative in ('.pki/nssdb','.local/share/pki/nssdb'):
        db=root/relative
        db.mkdir(parents=True)
        subprocess.run(['certutil','-N','-d','sql:'+str(db),'--empty-password'],check=True,env=env)
        subprocess.run(['certutil','-A','-d','sql:'+str(db),'-n','Majoris disposable fixture','-t','C,,','-i',str(cert)],check=True,env=env)
    subprocess.run(['gnome-keyring-daemon','--unlock','--components=secrets'],input=b'fixture-only-password',check=True,env=env,stdout=subprocess.DEVNULL)
    class Handler(http.server.SimpleHTTPRequestHandler):
        def do_GET(self):
            path=urllib.parse.urlsplit(self.path)
            identity={k.lower():v for k,v in self.headers.items() if k.lower() in ('user-agent','sec-ch-ua','sec-ch-ua-platform','sec-ch-ua-mobile')}
            if path.path=='/media.html' and not hasattr(self.server,'initial_identity'):
                self.server.initial_identity=identity
            if path.path=='/fixture-headers':
                import json
                body=json.dumps({'initial':getattr(self.server,'initial_identity',{}),'current':identity}).encode()
                self.send_response(200);self.send_header('Content-Type','application/json');self.send_header('Content-Length',str(len(body)));self.end_headers();self.wfile.write(body);return
            if path.path=='/oauth/authorize':
                self.send_response(302);self.send_header('Location',f'https://localhost:{self.server.server_port}/idp/step');self.end_headers();return
            if path.path.startswith('/auth-app/') or path.path=='/idp/step':
                body=b'<!doctype html><title>Authentication fixture</title><p>Authentication fixture</p>'
                self.send_response(200);self.send_header('Content-Type','text/html');self.send_header('Content-Length',str(len(body)));self.end_headers();self.wfile.write(body);return
            super().do_GET()
        def do_POST(self):
            self.rfile.read(int(self.headers.get('Content-Length',0)))
            api=self.path.startswith('/api/')
            body=b'{"ok":true}' if api else b'Signed in fixture'
            self.send_response(401 if self.path.endswith('-fail') else 200);self.send_header('Content-Type','application/json' if api else 'text/html');self.send_header('Content-Length',str(len(body)));self.end_headers();self.wfile.write(body)
    server=http.server.ThreadingHTTPServer(('127.0.0.1',0),functools.partial(Handler,directory=fixtures))
    context=ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER);context.load_cert_chain(cert,key);server.socket=context.wrap_socket(server.socket,server_side=True)
    threading.Thread(target=server.serve_forever,daemon=True).start()
    (root/'contexts').mkdir()
    subprocess.run([binary,helper,resources,str(root/'contexts'),f'https://localhost:{server.server_port}/{page}'],check=True,env=env,timeout=70)
    server.shutdown()
