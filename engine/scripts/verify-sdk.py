#!/usr/bin/env python3
"""Reject unapproved proprietary-codec engine redistribution by default."""
import argparse,hashlib,json,os,pathlib,runpy,subprocess,sys
parser=argparse.ArgumentParser(description=__doc__)
parser.add_argument('--sdk',type=pathlib.Path,required=True)
parser.add_argument('--for-package',action='store_true')
args=parser.parse_args();path=args.sdk/'majoris-runtime.json'
channel=os.environ.get('MAJORIS_RELEASE_CHANNEL','development')
if channel not in ('development','release-candidate','production'):raise SystemExit('Unknown release channel')
if args.for_package and channel!='development':
    if os.environ.get('MAJORIS_DEVELOPMENT_ENGINE')=='1':raise SystemExit('Development opt-in is forbidden for release candidates and production')
    record=os.environ.get('MAJORIS_RELEASE_RECORD')
    if not record or not path.exists():raise SystemExit('Release channel requires an explicit custom-runtime approval record')
    subprocess.run([sys.executable,str(pathlib.Path(__file__).with_name('release-record.py')),'verify','--sdk',str(args.sdk),'--record',record,'--channel',channel],check=True)
if path.exists():
    data=json.loads(path.read_text())
    if data.get('schema')!=1 or not isinstance(data.get('development_codecs'),bool):raise SystemExit('Unsupported custom SDK provenance')
    runpy.run_path(str(pathlib.Path(__file__).with_name('runtime-files.py')))['verify'](args.sdk,data,required=channel!='development')
    library=args.sdk/'Release/libcef.so'
    if not library.exists():raise SystemExit('Custom SDK libcef.so is missing')
    with library.open('rb') as stream:actual=hashlib.file_digest(stream,'sha256').hexdigest()
    if actual!=data.get('libcef_sha256'):raise SystemExit('Custom SDK library digest does not match build provenance')
    unqualified=not data.get('runtime_verified') or not data.get('source',{}).get('security_qualified')
    restricted_codecs=data['development_codecs'] and not data.get('redistribution_approved')
    if args.for_package and channel=='development' and (unqualified or restricted_codecs):
        if os.environ.get('MAJORIS_DEVELOPMENT_ENGINE')!='1':raise SystemExit('Custom SDK lacks runtime/security qualification or codec redistribution approval. Explicit local development packaging requires MAJORIS_DEVELOPMENT_ENGINE=1; it does not qualify the engine or grant distribution rights.')
        print('DEVELOPMENT ONLY: engine qualification/redistribution approval remains incomplete')
    print('Custom source revision:',data['source']['chromium_commit'])
else:print('Standard CEF SDK; custom engine features are detected at runtime')
