#!/usr/bin/env python3
"""Build current source in a new, generated-file-free source directory."""
import argparse
import pathlib
import shutil
import subprocess
import time

repo=pathlib.Path(__file__).resolve().parents[1]
parser=argparse.ArgumentParser(description=__doc__)
parser.add_argument('--cef-root',type=pathlib.Path,required=True)
parser.add_argument('--destination',type=pathlib.Path,default=repo/('build-clean-'+str(time.time_ns())))
args=parser.parse_args()
destination=args.destination.resolve()
if not destination.is_relative_to(repo) or destination==repo or destination.exists():
    raise SystemExit('Choose a new verification directory inside this repository')
source=destination/'source'
source.mkdir(parents=True)
paths=subprocess.check_output(['git','ls-files','-z','--cached','--others','--exclude-standard'],cwd=repo).decode().split('\0')
for name in dict.fromkeys(paths):
    if not name or name.endswith('.zip'):
        continue
    original=repo/name
    if not original.is_file() or original.is_symlink():
        continue
    target=source/name
    target.parent.mkdir(parents=True,exist_ok=True)
    shutil.copy2(original,target)
build=destination/'output'
subprocess.run(['meson','setup',str(build),str(source),'-Dcef_root='+str(args.cef_root.resolve()),'--prefix=/usr'],check=True)
subprocess.run(['meson','compile','-C',str(build)],check=True)
subprocess.run(['meson','test','-C',str(build),'--print-errorlogs'],check=True)
