#!/usr/bin/env python3
"""Technical inventory for an authorised redistribution review; no licence grant."""
import argparse,hashlib,json,pathlib,re,subprocess
parser=argparse.ArgumentParser(description=__doc__)
parser.add_argument('--sdk',type=pathlib.Path,required=True);parser.add_argument('--chromium-source',type=pathlib.Path,required=True);parser.add_argument('--output',type=pathlib.Path,required=True)
args=parser.parse_args();metadata=json.loads((args.sdk/'majoris-runtime.json').read_text());source=args.chromium_source
with (args.sdk/'Release/libcef.so').open('rb') as stream:
    if hashlib.file_digest(stream,'sha256').hexdigest()!=metadata['libcef_sha256']:raise SystemExit('Runtime does not match provenance')
if subprocess.check_output(['git','rev-parse','HEAD'],cwd=source,text=True).strip()!=metadata['source']['chromium_commit']:raise SystemExit('Source does not match the runtime')
roots={'chromium':source,'cef':source/'cef','v8':source/'v8'}
if 'v8_commit' in metadata['source'] and subprocess.check_output(['git','rev-parse','HEAD'],cwd=roots['v8'],text=True).strip()!=metadata['source']['v8_commit']:raise SystemExit('V8 does not match the runtime')
for name,expected in metadata.get('source_diffs',{}).items():
    if name not in roots or hashlib.sha256(subprocess.check_output(['git','diff','--binary','HEAD'],cwd=roots[name])).hexdigest()!=expected:raise SystemExit('Source differs from compiled provenance: '+name)
for name,expected in metadata.get('extension_sources',{}).items():
    path=source/'cef/libcef/browser'/name
    if pathlib.PurePosixPath(name).name!=name or hashlib.sha256(path.read_bytes()).hexdigest()!=expected:raise SystemExit('Extension source differs from compiled provenance')
def entry(path):
    return {'path':str(path.resolve()),'sha256':hashlib.sha256(path.read_bytes()).hexdigest()}
ffmpeg=source/'third_party/ffmpeg'
branding='Chrome' if 'ffmpeg_branding="Chrome"' in metadata['configuration'] else 'Chromium'
configuration=ffmpeg/'chromium/config'/branding/'linux/x64'
project=pathlib.Path(__file__).resolve().parents[2]
inputs=[project/'LICENSE',project/'engine/LICENSE',project/'packaging/debian/copyright',args.sdk/'LICENSE.txt',args.sdk/'CREDITS.html',source/'LICENSE',ffmpeg/'README.chromium',ffmpeg/'CREDITS.chromium',configuration/'config.h',configuration/'config_components.h']
flags=dict(re.findall(r'^#define (CONFIG_(?:H264_DECODER|AAC_DECODER|LIBX264|GPL|NONFREE)) ([01])$',(configuration/'config.h').read_text()+'\n'+(configuration/'config_components.h').read_text(),re.M))
result={'schema':1,'runtime_sha256':metadata['libcef_sha256'],'chromium_commit':metadata['source']['chromium_commit'],
        'v8_commit':subprocess.check_output(['git','rev-parse','HEAD'],cwd=source/'v8',text=True).strip(),
        'maintenance_backports':metadata['source'].get('maintenance_backports',[]),
        'ffmpeg_commit':subprocess.check_output(['git','rev-parse','HEAD'],cwd=ffmpeg,text=True).strip(),
        'complete_generated_third_party_inventory':entry(args.sdk/'CREDITS.html'),
        'notices_and_source_metadata':[entry(path) for path in inputs],
        'configuration':metadata['configuration'],'ffmpeg_branding':branding,'selected_configuration_flags':flags,'redistribution_approved':False,
        'project_licences':{'browser':'GPL-3.0-or-later','majoris_engine_extensions':'BSD-3-Clause','runtime':'CEF/Chromium and separately licensed components; see complete generated notices','system_dependencies':'See Debian package Depends and buildinfo; each linked system package retains its own copyright/source obligations'},
        'review_required':['CEF/Chromium BSD-style notices and full generated third-party notices','FFmpeg per-file BSD-2-Clause/BSD-3-Clause/ISC/LGPL-2.1/MIT obligations from pinned CREDITS.chromium','LGPL source/modifications/relinking and distribution obligations for the exact Chromium FFmpeg configuration','H.264 and AAC patent/licensing applicability by jurisdiction, distribution model and device/product; software notices do not grant patent rights','Operator legal authorisation, attribution and required source offers before codec redistribution','Widevine excluded: no authorised CDM binary or redistribution grant supplied']}
args.output.write_text(json.dumps(result,indent=2)+'\n')
