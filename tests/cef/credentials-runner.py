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

binary, helper, resources, fixtures = sys.argv[1:]
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
        def do_POST(self):
            self.rfile.read(int(self.headers.get('Content-Length',0)))
            self.send_response(200);self.end_headers();self.wfile.write(b'Signed in fixture')
    server=http.server.ThreadingHTTPServer(('127.0.0.1',0),functools.partial(Handler,directory=fixtures))
    context=ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER);context.load_cert_chain(cert,key);server.socket=context.wrap_socket(server.socket,server_side=True)
    threading.Thread(target=server.serve_forever,daemon=True).start()
    (root/'contexts').mkdir()
    subprocess.run([binary,helper,resources,str(root/'contexts'),f'https://localhost:{server.server_port}/login.html'],check=True,env=env,timeout=35)
    server.shutdown()
