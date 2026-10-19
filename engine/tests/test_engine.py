#!/usr/bin/env python3
"""Patch applicability and development-redistribution boundary regression tests."""
import argparse,hashlib,importlib.util,json,os,pathlib,shutil,subprocess,tempfile
engine=pathlib.Path(__file__).resolve().parents[1]
parser=argparse.ArgumentParser(description=__doc__)
parser.add_argument('--workspace',type=pathlib.Path,required=True)
parser.add_argument('--manifest',type=pathlib.Path,default=engine/'manifests/m152.json')
args=parser.parse_args();manifest=json.loads(args.manifest.read_text())
roots={'cef':args.workspace/'chromium/src/cef','chromium':args.workspace/'chromium/src'}
if 'v8_commit' in manifest:roots['v8']=args.workspace/'chromium/src/v8'
spec=importlib.util.spec_from_file_location('majoris_build',engine/'scripts/build.py')
driver=importlib.util.module_from_spec(spec);spec.loader.exec_module(driver)
with tempfile.TemporaryDirectory(prefix='majoris-source-provenance-') as folder:
    cef=pathlib.Path(folder);target=cef/'libcef/browser';target.mkdir(parents=True)
    for original in (engine/'src').glob('*'):shutil.copy2(original,target/original.name)
    assert driver.verify_extension_sources(cef)
    (target/'majoris_runtime.cc').write_text('altered untracked source')
    try:driver.verify_extension_sources(cef)
    except SystemExit:pass
    else:raise AssertionError('Changed untracked extension source was accepted')
    print('Untracked extension source provenance rejects changed bytes: PASS')
for name,root in roots.items():
    actual=subprocess.check_output(['git','rev-parse','HEAD'],cwd=root,text=True).strip()
    assert actual==manifest[name+'_commit'],(name,actual)
for entry in manifest['patches']:
    patch=engine/entry['path']
    assert hashlib.sha256(patch.read_bytes()).hexdigest()==entry['sha256']
    root=roots[entry['repository']]
    check=subprocess.run(['git','apply','--check',str(patch)],cwd=root,capture_output=True)
    if check.returncode:
        subprocess.run(['git','apply','--reverse','--check',str(patch)],cwd=root,check=True)
    # Apply the patch to pristine pinned files in a disposable repository;
    # corrupted patch data must not become an accepted build input.
    with tempfile.TemporaryDirectory(prefix='majoris-engine-patch-') as folder:
        target=pathlib.Path(folder);subprocess.run(['git','init','-q'],cwd=target,check=True)
        for line in patch.read_text().splitlines():
            if not line.startswith('--- a/'):continue
            path=line[6:];output=target/path;output.parent.mkdir(parents=True,exist_ok=True)
            output.write_bytes(subprocess.check_output(['git','show','HEAD:'+path],cwd=root))
        subprocess.run(['git','apply','--check',str(patch)],cwd=target,check=True)
        subprocess.run(['git','apply',str(patch)],cwd=target,check=True)
        subprocess.run(['git','apply','--reverse','--check',str(patch)],cwd=target,check=True)
        bad=target/'corrupt.patch';bad.write_text(patch.read_text().replace('@@','@broken@',1))
        assert subprocess.run(['git','apply','--check',str(bad)],cwd=target,capture_output=True).returncode!=0
    print(entry['path']+': exact upstream applicability and corruption rejection PASS')
with tempfile.TemporaryDirectory(prefix='majoris-engine-sdk-') as folder:
    sdk=pathlib.Path(folder);(sdk/'Release').mkdir();(sdk/'Release/libcef.so').write_bytes(b'unit-fixture-not-a-runtime')
    data={'schema':1,'development_codecs':True,'redistribution_approved':False,'source':manifest,'libcef_sha256':hashlib.sha256(b'unit-fixture-not-a-runtime').hexdigest()}
    path=sdk/'majoris-runtime.json';path.write_text(json.dumps(data));before=path.read_bytes()
    command=['python3',str(engine/'scripts/verify-sdk.py'),'--sdk',folder,'--for-package']
    environment=dict(os.environ);environment.pop('MAJORIS_DEVELOPMENT_ENGINE',None)
    assert subprocess.run(command,env=environment,capture_output=True).returncode!=0
    environment['MAJORIS_DEVELOPMENT_ENGINE']='1';subprocess.run(command,env=environment,check=True)
    assert path.read_bytes()==before
    data['development_codecs']=False;path.write_text(json.dumps(data))
    assert subprocess.run(command,env={key:value for key,value in environment.items() if key!='MAJORIS_DEVELOPMENT_ENGINE'},capture_output=True).returncode!=0
    subprocess.run(command,env=environment,check=True)
    print('Open-codec SDK without runtime/security qualification also requires development opt-in: PASS')
    (sdk/'Release/libcef.so').write_bytes(b'corrupted')
    assert subprocess.run(command,env=environment,capture_output=True).returncode!=0
    print('Development package opt-in does not grant redistribution approval: PASS')
