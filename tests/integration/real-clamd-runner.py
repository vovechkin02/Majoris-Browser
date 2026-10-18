"""Explicit optional real-clamd qualification; never installs or persists a daemon."""
import argparse,hashlib,os,pathlib,subprocess,tempfile,time
parser=argparse.ArgumentParser(description=__doc__)
parser.add_argument('--clamd',type=pathlib.Path,required=True)
parser.add_argument('--binary',type=pathlib.Path,required=True)
parser.add_argument('--library-directory',type=pathlib.Path)
args=parser.parse_args();env=dict(os.environ)
if args.library_directory:env['LD_LIBRARY_PATH']=str(args.library_directory.resolve())
with tempfile.TemporaryDirectory(prefix='majoris-real-clamd-') as temporary:
    root=pathlib.Path(temporary);database=root/'database';database.mkdir()
    data=b'Majoris harmless antivirus integration fixture. Not malware.\n'
    (database/'test.hdb').write_text(f'{hashlib.md5(data).hexdigest()}:{len(data)}:Majoris.Harmless.Test.Signature\n')
    (root/'clean').write_bytes(b'Clean original browser fixture\n');(root/'detected').write_bytes(data)
    conf=root/'clamd.conf';conf.write_text(f'Foreground yes\nLocalSocket {root}/clamd.sock\nDatabaseDirectory {database}\nPidFile {root}/clamd.pid\nLogFile {root}/clamd.log\nMaxThreads 2\nMaxQueue 4\nStreamMaxLength 64M\nMaxScanTime 10000\n')
    daemon=subprocess.Popen([str(args.clamd.resolve()),'-c',str(conf)],env=env,stdout=subprocess.PIPE,stderr=subprocess.STDOUT)
    try:
        deadline=time.monotonic()+15
        while not (root/'clamd.sock').exists():
            if daemon.poll() is not None:raise RuntimeError(daemon.stdout.read().decode())
            if time.monotonic()>deadline:raise TimeoutError('Disposable clamd did not start')
            time.sleep(.05)
        subprocess.run([str(args.binary.resolve()),temporary,'--real'],check=True,timeout=15)
        print(subprocess.check_output([str(args.clamd.resolve()),'-c',str(conf),'--version'],env=env,text=True).strip())
    finally:
        daemon.terminate()
        try:daemon.wait(timeout=5)
        except subprocess.TimeoutExpired:daemon.kill();daemon.wait()
    print('Harmless custom test database only; production signature coverage/freshness unqualified. Daemon terminated; no system installation/service changes.')
