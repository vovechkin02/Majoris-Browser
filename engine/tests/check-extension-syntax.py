#!/usr/bin/env python3
"""Check extension sources with generated target flags, without touching objects.

Run after GN generation and generated headers exist. This is an early compiler
check, never a substitute for linking or Majoris runtime qualification.
"""
import argparse,pathlib,shlex,subprocess
parser=argparse.ArgumentParser(description=__doc__)
parser.add_argument('--workspace',type=pathlib.Path,required=True)
args=parser.parse_args();engine=pathlib.Path(__file__).resolve().parents[1]
build=args.workspace/'chromium/src/out/Release_GN_x64'
for stem in ('majoris_runtime','majoris_history'):
    target='obj/cef/libcef_static/'+stem+'.o'
    line=subprocess.check_output(['ninja','-t','commands','-s',target],cwd=build,text=True).strip()
    if '\n' in line:raise SystemExit('Expected a single compile command')
    tokens=shlex.split(line);command=[];index=0
    while index<len(tokens):
        value=tokens[index];index+=1
        if value in ('-o','-MF','-MT','-MQ'):index+=1;continue
        if value in ('-MMD','-MD','-MP','-c'):continue
        if value.endswith('/'+stem+'.cc'):value=str(engine/'src'/(stem+'.cc'))
        command.append(value)
    subprocess.run(command+['-fsyntax-only'],cwd=build,check=True)
    print(stem+': exact Chromium release compiler/flags syntax PASS',flush=True)
