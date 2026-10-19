#!/usr/bin/env python3
"""Read-only SDK provenance/availability report; never installs or approves CEF."""
import argparse,datetime,hashlib,json,pathlib,re,runpy,urllib.request
parser=argparse.ArgumentParser(description=__doc__)
parser.add_argument('--cef-root',type=pathlib.Path,required=True)
parser.add_argument('--online',action='store_true',help='Explicitly inspect the official publisher index')
args=parser.parse_args()
pin=runpy.run_path(str(pathlib.Path(__file__).with_name('bootstrap-cef.py')))
header=(args.cef_root/'include/cef_version.h').read_text()
report={'checked_at':datetime.datetime.now(datetime.timezone.utc).isoformat(),'pin':pin['VERSION'],'runtime':re.search(r'#define CEF_VERSION "([^"]+)"',header)[1],'publisher_sha1':pin['SHA1'],'repository_sha256':pin['SHA256'],'release_approved':False}
provenance=args.cef_root/'majoris-runtime.json'
if provenance.exists():
    data=json.loads(provenance.read_text())
    report.update(runtime_kind='majoris-source-build',pin=data['source'],build_provenance=data,publisher_sha1=None,repository_sha256=data['sha256'])
    with (args.cef_root/'Release/libcef.so').open('rb') as stream:actual=hashlib.file_digest(stream,'sha256').hexdigest()
    report['libcef_sha256']=actual
    report['library_matches_build']=actual==data.get('libcef_sha256')
    report['chromium_matches_manifest']=('chromium-'+data['source']['chromium_version']) in report['runtime']
archive=args.cef_root/'sdk.tar.bz2'
if archive.exists():
    with archive.open('rb') as stream:report['archive_sha256']=hashlib.file_digest(stream,'sha256').hexdigest()
    report['archive_matches_pin']=report['archive_sha256']==report['repository_sha256']
if args.online:
    with urllib.request.urlopen('https://cef-builds.spotifycdn.com/index.json',timeout=30) as response:data=json.load(response)
    report['available_linux64']=[{key:item[key] for key in ('cef_version','chromium_version','channel')} for item in data['linux64']['versions'][:8]]
print(json.dumps(report,indent=2))
