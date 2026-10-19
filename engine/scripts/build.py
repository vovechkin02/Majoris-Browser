#!/usr/bin/env python3
"""Pinned custom CEF source build; never invoked implicitly by Meson."""
import argparse,ast,datetime,hashlib,json,os,pathlib,runpy,shutil,subprocess,sys,urllib.request
ENGINE=pathlib.Path(__file__).resolve().parents[1]
def run(command,cwd,env=None,timeout=None):
    print('+',subprocess.list2cmdline([str(x) for x in command]),flush=True)
    return subprocess.run([str(x) for x in command],cwd=cwd,env=env,check=True,timeout=timeout)
def head(path):return subprocess.check_output(['git','rev-parse','HEAD'],cwd=path,text=True).strip()
def digest(path):
    with path.open('rb') as stream:return hashlib.file_digest(stream,'sha256').hexdigest()

def verify_extension_sources(cef):
    # New patch-created files are untracked in the upstream checkout and are
    # therefore absent from git diff HEAD. Validate their bytes separately.
    result={}
    for original in sorted((ENGINE/'src').glob('*')):
        target=cef/'libcef/browser'/original.name
        if not target.is_file() or digest(target)!=digest(original):
            raise SystemExit('Custom extension source differs from selected patch: '+str(target))
        result[original.name]=digest(target)
    return result
def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--workspace',type=pathlib.Path,required=True)
    parser.add_argument('--manifest',type=pathlib.Path,default=ENGINE/'manifests/m152.json')
    parser.add_argument('--stage',choices=['acquire','patch','build','sdk'],required=True)
    parser.add_argument('--development-codecs',action='store_true',help='Separate development-only proprietary codec configuration; not distribution approval')
    parser.add_argument('--build-jobs',type=int,default=8,help='Explicit local compile jobs; recorded in workflow provenance')
    args=parser.parse_args();manifest=json.loads(args.manifest.read_text());workspace=args.workspace.resolve()
    for patch in manifest['patches']:
        path=(ENGINE/patch['path']).resolve()
        if not path.is_relative_to(ENGINE) or digest(path)!=patch['sha256']:raise SystemExit('Selected patch checksum/path mismatch: '+patch['path'])
    if not 1<=args.build_jobs<=256:raise SystemExit('--build-jobs must be between 1 and 256')
    if sys.platform!='linux' or str(workspace).startswith('/mnt/') or ' ' in str(workspace):raise SystemExit('Use an explicit native Linux workspace without spaces')
    workspace.mkdir(parents=True,exist_ok=True)
    filesystem=subprocess.check_output(['findmnt','-n','-o','FSTYPE','--target',str(workspace)],text=True).strip()
    if filesystem in ('tmpfs','ramfs','9p','drvfs'):raise SystemExit('Engine workspace must be on disk-backed native Linux storage, not '+filesystem)
    if shutil.disk_usage(workspace).free<100*1024**3:raise SystemExit('At least 100 GiB free disk space is required for source acquisition; allow 500 GiB for a full build')
    identity=workspace/'majoris-workspace.json'
    selected={'cef_commit':manifest['cef_commit'],'chromium_commit':manifest['chromium_commit'],'development_codecs':args.development_codecs}
    if identity.exists() and json.loads(identity.read_text())!=selected:raise SystemExit('Workspace belongs to a different engine configuration; choose a new workspace')
    identity.write_text(json.dumps(selected,indent=2)+'\n')
    environment=dict(os.environ,DEPOT_TOOLS_UPDATE='0',DEPOT_TOOLS_METRICS='0',GIT_TERMINAL_PROMPT='0',GIT_HTTP_LOW_SPEED_LIMIT='1000',GIT_HTTP_LOW_SPEED_TIME='60',CEF_USE_GN='1',CEF_ARCHIVE_FORMAT='tar.bz2',PYTHONUNBUFFERED='1',GN_OUT_CONFIGS='Release_GN_x64')
    gn=(ENGINE/'config/base.gn').read_text()
    if args.development_codecs:gn+='\n'+(ENGINE/'config/development-codecs.gn').read_text()
    environment['GN_DEFINES']=' '.join(line.strip() for line in gn.splitlines() if line.strip() and not line.lstrip().startswith('#'))
    depot=workspace/'depot_tools';tool=workspace/'automate-git.py'
    source=workspace/'chromium/src';cef=source/'cef'
    roots={'cef':cef,'chromium':source}
    if 'v8_commit' in manifest:roots['v8']=source/'v8'
    if args.stage=='acquire':
        if not tool.exists():
            with urllib.request.urlopen('https://raw.githubusercontent.com/chromiumembedded/cef/'+manifest['cef_commit']+'/tools/automate/automate-git.py',timeout=60) as response:tool.write_bytes(response.read())
        if digest(tool)!=manifest['automate_sha256']:raise SystemExit('Official automate-git.py digest mismatch')
        if not (depot/'.git').exists():
            depot.mkdir(exist_ok=True);run(['git','init'],depot)
            run(['git','remote','add','origin','https://chromium.googlesource.com/chromium/tools/depot_tools.git'],depot)
            run(['git','fetch','--depth=1','origin',manifest['depot_tools_commit']],depot,environment,300)
            run(['git','checkout','--detach','FETCH_HEAD'],depot)
        if head(depot)!=manifest['depot_tools_commit']:raise SystemExit('depot_tools revision mismatch')
    environment['PATH']=str(depot)+os.pathsep+environment['PATH']
    if not (depot/'python3_bin_reldir.txt').exists():
        run([depot/'ensure_bootstrap'],workspace,environment,600)
    # Keep the authenticated upstream script unchanged. Record our narrow
    # adaptations: bounded fetch/build concurrency and DEPS-pinned Siso.
    if not tool.exists() or digest(tool)!=manifest['automate_sha256']:raise SystemExit('Official workflow missing or checksum mismatch; run acquire first')
    original=tool.read_text()
    adapted=original.replace('gclient sync %s','gclient sync --jobs=4 %s')
    adapted=adapted.replace("command = 'autoninja '","command = 'autoninja -j%d '"%args.build_jobs)
    siso_line='          "\'siso_version\': \'latest\', "+\n'
    if siso_line not in adapted:raise SystemExit('Official Siso override context changed')
    adapted=adapted.replace(siso_line,'')
    workflow=workspace/('majoris-automate-git-'+hashlib.sha256(adapted.encode()).hexdigest()+'.py')
    if workflow.exists() and workflow.read_text()!=adapted:raise SystemExit('Immutable workflow content mismatch')
    if not workflow.exists():workflow.write_text(adapted)
    environment['PATH']=str(depot)+os.pathsep+environment['PATH']
    command=[sys.executable,str(workflow),'--download-dir='+str(workspace),'--depot-tools-dir='+str(depot),'--branch='+manifest['cef_branch'],'--checkout='+manifest['cef_commit'],'--chromium-checkout=refs/tags/'+manifest['chromium_version'],'--no-depot-tools-update','--no-debug-build','--x64-build']
    if args.stage=='acquire':
        (workspace/'majoris-acquired.json').unlink(missing_ok=True)
        run(command+['--no-build','--no-distrib','--no-chromium-history'],workspace,environment)
        # automate-git skips sync if the main checkout already exists, even
        # following an interrupted dependency fetch. Always finish it explicitly.
        config=workspace/'chromium/.gclient';text=config.read_text()
        config.write_text(text.replace("'siso_version': 'latest',",''))
        run(['gclient','sync','--force','--jobs=4','--nohooks','--no-history'],workspace/'chromium',environment)
        module=ast.parse((workspace/'chromium/.gclient_entries').read_text())
        entries=ast.literal_eval(module.body[0].value)
        for path,url in entries.items():
            if not isinstance(url,str) or '.git@' not in url:continue
            revision=url.rsplit('@',1)[1]
            if len(revision)==40 and head(workspace/'chromium'/path)!=revision:raise SystemExit('Dependency revision mismatch: '+path)
        run(['gclient','runhooks'],workspace/'chromium',environment)
        if head(source)!=manifest['chromium_commit'] or head(cef)!=manifest['cef_commit']:raise SystemExit('Acquired source revision mismatch')
        (workspace/'majoris-acquired.json').write_text(json.dumps({'source':selected,'workflow_sha256':digest(workflow)},indent=2)+'\n')
    else:
        if head(source)!=manifest['chromium_commit'] or head(cef)!=manifest['cef_commit']:raise SystemExit('Source revisions do not match the selected manifest')
        if not (workspace/'majoris-acquired.json').exists():raise SystemExit('Source dependencies were not fully acquired; run acquire')
        if any(head(root)!=manifest[name+'_commit'] for name,root in roots.items()):raise SystemExit('Selected dependency source revision mismatch')
        if args.stage=='patch':
            receipt=workspace/'majoris-patches.json'
            if receipt.exists() and any(entry not in manifest['patches'] for entry in json.loads(receipt.read_text())):
                raise SystemExit('Workspace contains a different patch set. Use a fresh workspace, or explicitly reverse and review the previous patches before removing their receipt. Patches are never silently omitted from provenance.')
            receipts=[]
            for patch in manifest['patches']:
                path=ENGINE/patch['path'];target=roots[patch['repository']]
                if digest(path)!=patch['sha256']:raise SystemExit('Patch checksum mismatch: '+str(path))
                forward=subprocess.run(['git','apply','--check',str(path)],cwd=target,capture_output=True)
                if forward.returncode==0:run(['git','apply',str(path)],target)
                elif subprocess.run(['git','apply','--reverse','--check',str(path)],cwd=target,capture_output=True).returncode!=0:raise SystemExit('Patch does not match this source: '+str(path)+'\n'+forward.stderr.decode())
                receipts.append(patch)
            (workspace/'majoris-patches.json').write_text(json.dumps(receipts,indent=2)+'\n')
        elif args.stage=='build':
            if not (workspace/'majoris-patches.json').exists():raise SystemExit('Run the patch stage first, including for an empty patch set')
            if json.loads((workspace/'majoris-patches.json').read_text())!=manifest['patches']:raise SystemExit('Patch receipts are stale')
            verify_extension_sources(cef)
            run(command+['--no-update','--force-build','--build-target=libcef','--minimal-distrib-only','--no-distrib-symbols','--no-distrib-docs','--build-log-file'],workspace,environment)
            diffs={}
            for name,root in roots.items():
                path=workspace/('majoris-'+name+'-source.diff')
                with path.open('wb') as output:subprocess.run(['git','diff','--binary','HEAD'],cwd=root,stdout=output,check=True)
                diffs[name]=digest(path)
            (workspace/'majoris-build.json').write_text(json.dumps({'manifest':manifest,'gn':environment['GN_DEFINES'],'workflow_sha256':digest(workflow),'source_diffs':diffs},indent=2)+'\n')
        else:
            extension_sources=verify_extension_sources(cef)
            expected={'manifest':manifest,'gn':environment['GN_DEFINES'],'workflow_sha256':digest(workflow)}
            if not (workspace/'majoris-build.json').exists():raise SystemExit('No successful build receipt')
            receipt=json.loads((workspace/'majoris-build.json').read_text())
            if any(receipt.get(key)!=value for key,value in expected.items()):raise SystemExit('No successful build receipt for this exact source, patch set and configuration')
            for name,root in roots.items():
                actual=hashlib.sha256(subprocess.check_output(['git','diff','--binary','HEAD'],cwd=root)).hexdigest()
                if actual!=receipt['source_diffs'][name]:raise SystemExit('Source changed after compilation: '+name)
            candidates=sorted((cef/'binary_distrib').glob('cef_binary_*linux64_minimal.tar.bz2'))
            if len(candidates)!=1:raise SystemExit('Expected one explicitly built Linux64 minimal SDK archive')
            archive=candidates[0];provenance={'schema':1,'source':manifest,'configuration':environment['GN_DEFINES'],'workflow_sha256':digest(workflow),'development_codecs':args.development_codecs,'archive':archive.name,'sha256':digest(archive),'built_at':datetime.datetime.now(datetime.timezone.utc).isoformat(),'runtime_verified':False,'redistribution_approved':False}
            run([sys.executable,ENGINE.parent/'scripts/bootstrap-cef.py','--destination',workspace/'sdk','--local-archive',archive,'--sha256',provenance['sha256']],workspace)
            sdk=workspace/'sdk/distribution'/archive.name.removesuffix('.tar.bz2')
            provenance['source_diffs']=receipt['source_diffs']
            provenance['extension_sources']=extension_sources
            clang=source/'third_party/llvm-build/Release+Asserts/bin/clang'
            provenance['toolchain']={'depot_tools_commit':manifest['depot_tools_commit'],
                'clang_version':subprocess.check_output([str(clang),'--version'],text=True).strip(),
                'clang_sha256':digest(clang),
                'sysroots_manifest_sha256':digest(source/'build/linux/sysroot_scripts/sysroots.json'),
                'wrapper_compiler':subprocess.check_output(['c++','--version'],text=True).splitlines()[0]}
            provenance['libcef_sha256']=digest(sdk/'Release/libcef.so')
            provenance['runtime_files']=runpy.run_path(str(ENGINE/'scripts/runtime-files.py'))['inventory'](sdk)
            shutil.copy2(ENGINE/'api/majoris_runtime.h',sdk/'include/majoris_runtime.h')
            (sdk/'majoris-runtime.json').write_text(json.dumps(provenance,indent=2)+'\n')
            (workspace/'majoris-runtime.json').write_text(json.dumps(provenance,indent=2)+'\n');print(json.dumps(provenance,indent=2))
if __name__=='__main__':main()
