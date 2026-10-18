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
import base64
import hashlib

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
    # A separate, deliberately untrusted TLS endpoint; never add it to NSS.
    bad_cert,bad_key=root/'untrusted.pem',root/'untrusted.key'
    subprocess.run(['openssl','req','-x509','-newkey','rsa:2048','-nodes','-keyout',str(bad_key),'-out',str(bad_cert),'-days','1','-subj','/CN=untrusted.invalid'],check=True,stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL)
    untrusted=http.server.ThreadingHTTPServer(('127.0.0.1',0),functools.partial(http.server.SimpleHTTPRequestHandler,directory=fixtures))
    bad_context=ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER);bad_context.load_cert_chain(bad_cert,bad_key);untrusted.socket=bad_context.wrap_socket(untrusted.socket,server_side=True)
    threading.Thread(target=untrusted.serve_forever,daemon=True).start()
    class Handler(http.server.SimpleHTTPRequestHandler):
        def do_GET(self):
            path=urllib.parse.urlsplit(self.path)
            if path.path=='/fixture-security':
                body=f'https://127.0.0.1:{untrusted.server_port}/login.html'.encode()
                self.send_response(200);self.send_header('Content-Length',str(len(body)));self.end_headers();self.wfile.write(body);return
            if path.path=='/fixture-socket':
                accept=base64.b64encode(hashlib.sha1((self.headers['Sec-WebSocket-Key']+'258EAFA5-E914-47DA-95CA-C5AB0DC85B11').encode()).digest()).decode()
                self.send_response(101);self.send_header('Upgrade','websocket');self.send_header('Connection','Upgrade');self.send_header('Sec-WebSocket-Accept',accept);self.end_headers()
                self.connection.settimeout(6)
                header=self.rfile.read(2);assert len(header)==2 and header[0]==0x81 and header[1]&0x80
                length=header[1]&127;assert length<126
                mask=self.rfile.read(4);payload=self.rfile.read(length);assert len(mask)==4 and len(payload)==length
                body=bytes(byte^mask[index%4] for index,byte in enumerate(payload))
                self.wfile.write(bytes([0x81,len(body)])+body);self.wfile.flush();self.close_connection=True;return
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
    proc=subprocess.Popen([binary,helper,resources,str(root/'contexts'),f'https://localhost:{server.server_port}/{page}'],env=env)
    sandboxed=False;deadline=__import__('time').monotonic()+70
    def descendants(pid):
        try:children=(pathlib.Path('/proc')/str(pid)/'task'/str(pid)/'children').read_text().split()
        except (OSError,ValueError):return
        for child in children:
            yield child
            yield from descendants(child)
    while proc.poll() is None:
        if page=='media.html':
            for child in descendants(proc.pid):
                try:
                    command=(pathlib.Path('/proc')/child/'cmdline').read_bytes().replace(b'\0',b' ')
                    assert b'--no-sandbox' not in command and b'--disable-web-security' not in command
                    if b'--type=renderer' in command:
                        status=(pathlib.Path('/proc')/child/'status').read_text()
                        if 'Seccomp:\t2' in status and 'NoNewPrivs:\t1' in status:sandboxed=True
                except OSError:pass
        if __import__('time').monotonic()>deadline:proc.kill();raise TimeoutError('CEF fixture timed out')
        __import__('time').sleep(.05)
    assert proc.returncode==0,proc.returncode
    if page=='media.html':
        assert sandboxed,'No renderer with seccomp filtering and no-new-privileges was observed'
        print('Observed Chromium renderer: seccomp filtering and no-new-privileges enabled; no unsafe switches: PASS')
    untrusted.shutdown()
    server.shutdown()
