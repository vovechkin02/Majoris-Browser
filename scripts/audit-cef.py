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
    if provenance.exists():
        branch=report['pin']['cef_branch']
        if not branch.isdigit():raise SystemExit('Invalid pinned branch')
        request=urllib.request.Request('https://api.github.com/repos/chromiumembedded/cef/commits?sha='+branch+'&per_page=10',headers={'User-Agent':'Majoris-engine-audit'})
        with urllib.request.urlopen(request,timeout=30) as response:cef_log=json.load(response)
        report['current_cef_branch_log']=[{'commit':item['sha'],'time':item['commit']['committer']['date'],'subject':item['commit']['message'].split('\n')[0]} for item in cef_log]
        report['cef_branch_head_matches_pin']=bool(cef_log) and cef_log[0]['sha']==report['pin']['cef_commit']
        url='https://chromium.googlesource.com/chromium/src/+log/refs/branch-heads/'+branch+'?format=JSON&n=12'
        with urllib.request.urlopen(url,timeout=30) as response:log=json.loads(response.read().decode().split('\n',1)[1])
        report['current_chromium_branch_log']=[{'commit':item['commit'],'time':item['committer']['time'],'subject':item['message'].split('\n')[0]} for item in log['log']]
        report['branch_head_matches_pin']=bool(log['log']) and log['log'][0]['commit']==report['pin']['chromium_commit']
        report['branch_log_note']='A newer branch commit requires review; it is not automatically selected or approved.'
        covered={item['commit'] for item in report['pin'].get('maintenance_backports',[])}
        pending=[];base_found=False;excluded=[]
        for item in report['current_chromium_branch_log']:
            if item['commit']==report['pin']['chromium_commit']:base_found=True;break
            if item['subject'].startswith('Incrementing VERSION') or 'infra:' in item['subject']:excluded.append(item)
            elif item['commit'] not in covered:pending.append(item)
        report['maintenance_review']={'base_found_in_recent_log':base_found,'uncovered_commits':pending,'excluded_version_or_infrastructure_commits':excluded,'recorded_backports':sorted(covered),'approval_granted':False}
print(json.dumps(report,indent=2))
