#!/usr/bin/env python3
"""Reject unapproved proprietary-codec engine redistribution by default."""
import argparse,hashlib,json,os,pathlib
parser=argparse.ArgumentParser(description=__doc__)
parser.add_argument('--sdk',type=pathlib.Path,required=True)
parser.add_argument('--for-package',action='store_true')
args=parser.parse_args();path=args.sdk/'majoris-runtime.json'
if path.exists():
    data=json.loads(path.read_text())
    if data.get('schema')!=1 or not isinstance(data.get('development_codecs'),bool):raise SystemExit('Unsupported custom SDK provenance')
    library=args.sdk/'Release/libcef.so'
    if not library.exists():raise SystemExit('Custom SDK libcef.so is missing')
    with library.open('rb') as stream:actual=hashlib.file_digest(stream,'sha256').hexdigest()
    if actual!=data.get('libcef_sha256'):raise SystemExit('Custom SDK library digest does not match build provenance')
    unqualified=not data.get('runtime_verified') or not data.get('source',{}).get('security_qualified')
    restricted_codecs=data['development_codecs'] and not data.get('redistribution_approved')
    if args.for_package and (unqualified or restricted_codecs):
        if os.environ.get('MAJORIS_DEVELOPMENT_ENGINE')!='1':raise SystemExit('Custom SDK lacks runtime/security qualification or codec redistribution approval. Explicit local development packaging requires MAJORIS_DEVELOPMENT_ENGINE=1; it does not qualify the engine or grant distribution rights.')
        print('DEVELOPMENT ONLY: engine qualification/redistribution approval remains incomplete')
    print('Custom source revision:',data['source']['chromium_commit'])
else:print('Standard CEF SDK; custom engine features are detected at runtime')
