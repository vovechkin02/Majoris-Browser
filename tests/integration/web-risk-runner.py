"""Only disposable local HTTPS and Secret Service; never contacts a provider."""
import http.server,json,os,pathlib,ssl,subprocess,sys,tempfile,threading,time,urllib.parse
with tempfile.TemporaryDirectory(prefix='majoris-web-risk-') as temporary:
    root=pathlib.Path(temporary)
    env=dict(os.environ,HOME=temporary,XDG_DATA_HOME=str(root/'data'),XDG_CONFIG_HOME=str(root/'config'),XDG_CACHE_HOME=str(root/'cache'))
    cert,key=root/'cert.pem',root/'key.pem'
    subprocess.run(['openssl','req','-x509','-newkey','rsa:2048','-nodes','-keyout',str(key),'-out',str(cert),'-days','1','-subj','/CN=localhost','-addext','subjectAltName=DNS:localhost','-addext','basicConstraints=critical,CA:TRUE'],check=True,stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL)
    subprocess.run(['gnome-keyring-daemon','--unlock','--components=secrets'],input=b'fixture-password',check=True,env=env,stdout=subprocess.DEVNULL)
    unrelated=root/'unrelated.pem'
    subprocess.run(['openssl','req','-x509','-newkey','rsa:2048','-nodes','-keyout',str(root/'unrelated.key'),'-out',str(unrelated),'-days','1','-subj','/CN=unrelated'],check=True,stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL)
    requests=[]; failures=[]
    class Handler(http.server.BaseHTTPRequestHandler):
        def log_message(self,*args):pass # Never log destination query strings or keys.
        def do_GET(self):
            try:
                parsed=urllib.parse.urlsplit(self.path)
                assert parsed.path=='/v1/uris:search','Redirect followed'
                query=urllib.parse.parse_qs(parsed.query)
                assert query['threatTypes']==['MALWARE','SOCIAL_ENGINEERING','UNWANTED_SOFTWARE']
                if self.headers.get('Authorization') is not None:
                    assert self.headers['Authorization']=='Bearer fixture-installation-token'
                    assert self.headers.get('X-Goog-Api-Key') is None
                else:assert self.headers['X-Goog-Api-Key']=='fixture-key-not-a-real-credential'
                assert 'key' not in query
                target=query['uri'][0];assert '#' not in target
                name=urllib.parse.urlsplit(target).path.strip('/');requests.append(name)
                assert name not in ('limited','missing-key','disabled')
                status=200;body=b'{}'
                if name in ('malware','phishing','unwanted'):
                    kind={'malware':'MALWARE','phishing':'SOCIAL_ENGINEERING','unwanted':'UNWANTED_SOFTWARE'}[name]
                    body=json.dumps({'threat':{'threatTypes':[kind],'expireTime':'2099-01-01T00:00:00Z'}}).encode()
                elif name=='malformed':body=b'not json'
                elif name=='wrong-type':body=b'{"threat":{"threatTypes":4}}'
                elif name=='unknown-type':body=b'{"threat":{"threatTypes":["FUTURE_TYPE"]}}'
                elif name=='redirect':status=302
                elif name=='unauthorised':status=403
                elif name=='quota':status=429
                elif name=='unavailable':status=503
                elif name=='oversize':body=b' '*65537
                elif name=='nul':body=b'{}\0invalid'
                elif name=='timeout':time.sleep(.5)
                self.send_response(status)
                if status==302:self.send_header('Location','https://localhost:'+str(self.server.server_port)+'/must-not-follow')
                self.send_header('Content-Length',str(len(body)));self.end_headers();self.wfile.write(body)
            except (BrokenPipeError,ConnectionResetError,ssl.SSLError):pass
            except Exception as error:failures.append(str(error));self.close_connection=True
    server=http.server.ThreadingHTTPServer(('127.0.0.1',0),Handler)
    context=ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER);context.load_cert_chain(cert,key);server.socket=context.wrap_socket(server.socket,server_side=True)
    threading.Thread(target=server.serve_forever,daemon=True).start()
    untrusted=http.server.ThreadingHTTPServer(('127.0.0.1',0),Handler)
    bad_context=ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER);bad_context.load_cert_chain(unrelated,root/'unrelated.key');untrusted.socket=bad_context.wrap_socket(untrusted.socket,server_side=True)
    threading.Thread(target=untrusted.serve_forever,daemon=True).start()
    subprocess.run([sys.argv[1],f'https://localhost:{server.server_port}/v1/uris:search',str(cert),f'https://localhost:{untrusted.server_port}/v1/uris:search'],env=env,check=True,timeout=20)
    server.shutdown();untrusted.shutdown();assert not failures,failures
    assert len(requests)==21,requests
