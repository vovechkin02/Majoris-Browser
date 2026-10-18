"""Deterministic local clamd fixture. No malware, network or daemon install."""
import os,pathlib,socket,struct,subprocess,sys,tempfile,threading,time
with tempfile.TemporaryDirectory(prefix='majoris-scanner-') as temporary:
    root=pathlib.Path(temporary);server=socket.socket(socket.AF_UNIX);server.bind(str(root/'clamd.sock'));server.listen()
    for name in ('clean','detected','failed','slow','replace'):(root/name).write_bytes(name.encode())
    (root/'chunked').write_bytes(b'x'*150000)
    (root/'link').symlink_to(root/'clean');os.mkfifo(root/'fifo')
    with (root/'large').open('wb') as file:file.truncate(64*1024*1024+1)
    errors=[];scans=[]
    def receive(connection,count):
        data=b''
        while len(data)<count:
            part=connection.recv(count-len(data))
            if not part:raise EOFError()
            data+=part
        return data
    def handle(connection):
        try:
            with connection:
                command=b''
                while not command.endswith(b'\0'):command+=receive(connection,1)
                if command==b'zVERSIONCOMMANDS\0':connection.sendall(b'ClamAV fixture/1/Sun Oct 18 10:00:00 2026 COMMANDS: INSTREAM VERSIONCOMMANDS\0');return
                assert command==b'zINSTREAM\0',command
                data=b''
                while True:
                    count=struct.unpack('!I',receive(connection,4))[0]
                    if not count:break
                    assert count<=65536;data+=receive(connection,count)
                scans.append(data)
                if data==b'replace':(root/'replace').unlink();(root/'replace').write_bytes(b'replace')
                if data==b'slow':time.sleep(.3)
                answer=b'stream: Fixture-Test FOUND' if data==b'detected' else b'stream: Scan failed ERROR' if data==b'failed' else b'stream: OK'
                connection.sendall(answer+b'\0')
        except (BrokenPipeError,ConnectionResetError,EOFError):pass
        except Exception as error:errors.append(str(error))
    def serve():
        while True:
            try:connection,_=server.accept()
            except OSError:return
            threading.Thread(target=handle,args=(connection,),daemon=True).start()
    threading.Thread(target=serve,daemon=True).start()
    subprocess.run([sys.argv[1],temporary],check=True,timeout=15)
    server.close();assert not errors,errors;assert scans==[b'clean',b'detected',b'failed',b'x'*150000,b'replace',b'slow',b'slow',b'clean'],[len(item) for item in scans]
