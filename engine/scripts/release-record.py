#!/usr/bin/env python3
"""Separate release-candidate/production approval record; never grants approval."""
import argparse,datetime,hashlib,json,pathlib,runpy,subprocess

ROOT=pathlib.Path(__file__).resolve().parents[2]

def digest(path):
    with pathlib.Path(path).open('rb') as stream:return hashlib.file_digest(stream,'sha256').hexdigest()

def source_identity():
    names=[]
    for folder in ('src','native','data','scripts','packaging','engine','tests','services'):
        names.extend(str(p.relative_to(ROOT)).replace('\\','/') for p in (ROOT/folder).rglob('*') if p.is_file() and not p.is_symlink() and '__pycache__' not in p.parts and p.suffix!='.pyc' and not p.is_relative_to(ROOT/'engine/releases'))
    names+=['meson.build','meson_options.txt','LICENSE','.gitattributes']
    result=hashlib.sha256()
    for name in sorted(set(names)):
        if name:
            path=ROOT/name
            if path.is_file():result.update(name.encode()+b'\0'+bytes.fromhex(digest(path)))
    try:revision=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True,stderr=subprocess.DEVNULL).strip()
    except subprocess.CalledProcessError:revision=(ROOT/'.majoris-source-revision').read_text().strip()
    return {'git_revision':revision,'application_source_sha256':result.hexdigest()}

def identity(sdk):
    metadata=json.loads((sdk/'majoris-runtime.json').read_text())
    runpy.run_path(str(pathlib.Path(__file__).with_name('runtime-files.py')))['verify'](sdk,metadata,required=True)
    actual=digest(sdk/'Release/libcef.so')
    if actual!=metadata['libcef_sha256']:raise ValueError('Runtime differs from build provenance')
    return dict(source_identity(),libcef_sha256=actual,provenance_sha256=digest(sdk/'majoris-runtime.json'),
                cef_version=(sdk/'include/cef_version.h').read_text().split('#define CEF_VERSION "')[1].split('"')[0],
                engine_source=metadata['source'],configuration=metadata['configuration'],
                toolchain=metadata.get('toolchain',{'depot_tools_commit':metadata['source']['depot_tools_commit'],'workflow_sha256':metadata['workflow_sha256'],'dependencies':'Pinned Chromium DEPS; acquisition verifies all Git dependency HEADs'}))

def draft(sdk):
    return {'schema':1,'identity':identity(sdk),'channel':'development','created_at':datetime.datetime.now(datetime.timezone.utc).isoformat(),
            'security':{'approved':False,'reviewer':'','reviewed_at':'','assessment':None},
            'runtime':{'approved':False,'reviewer':'','evidence':[]},
            'redistribution':{'approved':False,'reviewer':'','authorisation_reference':''},
            'production':{'approved':False,'reviewer':'','authorisation_reference':''}}

def validate(record,sdk,channel):
    if channel not in ('release-candidate','production'):raise ValueError('Invalid release channel')
    if record.get('schema')!=1 or record.get('identity')!=identity(sdk):raise ValueError('Release record does not match this source and runtime')
    if record.get('channel')!=channel:raise ValueError('Release channel mismatch')
    for gate in ('security','runtime','redistribution')+(('production',) if channel=='production' else ()):
        value=record.get(gate,{})
        if value.get('approved') is not True or not value.get('reviewer','').strip():raise ValueError('Missing explicit '+gate+' approval')
    security=record['security'];date=datetime.datetime.fromisoformat(security['reviewed_at'].replace('Z','+00:00'))
    age=datetime.datetime.now(datetime.timezone.utc)-date
    if age.total_seconds()<0 or age>datetime.timedelta(days=7):raise ValueError('Security assessment must be reviewed within seven days of packaging')
    evidence=[security['assessment']]+record['runtime']['evidence']
    if len(evidence)<2:raise ValueError('Security and runtime evidence are required')
    for item in evidence:
        if not isinstance(item,dict) or digest(pathlib.Path(item['path']))!=item['sha256']:raise ValueError('Evidence is missing or changed')
    for gate in ('redistribution',)+(('production',) if channel=='production' else ()):
        if not record[gate].get('authorisation_reference','').strip():raise ValueError('Missing '+gate+' authorisation reference')

def main():
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('mode',choices=['draft','verify']);parser.add_argument('--sdk',type=pathlib.Path,required=True);parser.add_argument('--record',type=pathlib.Path,required=True);parser.add_argument('--channel',choices=['release-candidate','production'])
    args=parser.parse_args()
    if args.mode=='draft':
        # Never overwrite an operator's approval record.
        with args.record.open('x') as output:json.dump(draft(args.sdk),output,indent=2);output.write('\n')
    else:
        if not args.channel:parser.error('--channel is required for verification')
        validate(json.loads(args.record.read_text()),args.sdk,args.channel);print('Explicit release record matches source, runtime and evidence')

if __name__=='__main__':main()
