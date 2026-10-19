#!/usr/bin/env python3
"""Generate original synthetic local fixtures; FFmpeg is a test tool only."""
import argparse,pathlib,subprocess,hashlib,json
parser=argparse.ArgumentParser(description=__doc__)
parser.add_argument('--ffmpeg',required=True)
parser.add_argument('--output',type=pathlib.Path,required=True)
args=parser.parse_args();args.output.mkdir(parents=True,exist_ok=True)
base=[args.ffmpeg,'-nostdin','-hide_banner','-loglevel','error','-y']
video=['-f','lavfi','-i','testsrc2=size=160x90:rate=25:duration=2']
audio=['-f','lavfi','-i','sine=frequency=440:sample_rate=48000:duration=2']
for name,inputs,encoding in [
 ('h264.mp4',video,['-c:v','libx264','-pix_fmt','yuv420p','-an']),
 ('aac.m4a',audio,['-c:a','aac','-vn']),
 ('h264-aac.mp4',video+audio,['-c:v','libx264','-pix_fmt','yuv420p','-c:a','aac','-shortest']),
]:
    subprocess.run(base+inputs+encoding+[str(args.output/name)],check=True)
manifest={'source':'Original FFmpeg lavfi testsrc2 and sine generators; no third-party recordings','license':'CC0-1.0 dedication by Majoris Browser contributors','files':{name:hashlib.sha256((args.output/name).read_bytes()).hexdigest() for name in ['h264.mp4','aac.m4a','h264-aac.mp4']}}
(args.output/'provenance.json').write_text(json.dumps(manifest,indent=2)+'\n')
print(json.dumps(manifest,indent=2))
