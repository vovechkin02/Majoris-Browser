#!/usr/bin/env python3
"""Regenerate reviewed patches from the exact pinned upstream source snapshots.

Snapshot directory is explicit; this script does not download or modify upstream.
"""
import argparse,difflib,hashlib,json,pathlib
parser=argparse.ArgumentParser(description=__doc__)
parser.add_argument('--snapshots',type=pathlib.Path,required=True)
args=parser.parse_args()
engine=pathlib.Path(__file__).resolve().parents[1]
patches=[]
def patch(name,repository,files):
    output=''
    for path,old,new in files:
        output+=''.join(difflib.unified_diff(old.splitlines(True),new.splitlines(True),fromfile='a/'+path if old else '/dev/null',tofile='b/'+path))
    target=engine/'patches'/name;target.parent.mkdir(exist_ok=True);target.write_text(output)
    patches.append({'path':'patches/'+name,'repository':repository,'sha256':hashlib.sha256(target.read_bytes()).hexdigest()})
def read(name):return (args.snapshots/name).read_text()
old=read('cef-alloy.cc')
new=old.replace('  // Not currently supported with OSR.\n  return !IsWindowless();','''#if BUILDFLAG(IS_LINUX)
  // The native Chromium overlay owns its compositor and video surface. It must
  // not use the OSR GTK widget as its native parent. Headless has no window.
  const auto* command = base::CommandLine::ForCurrentProcess();
  return command->GetSwitchValueASCII("ozone-platform") != "headless";
#else
  return !IsWindowless();
#endif''')
if new==old:raise SystemExit('CEF PiP patch context changed')
build=read('cef-BUILD.gn');updated=build.replace('    "libcef/browser/alloy/alloy_browser_host_impl.cc",','    "libcef/browser/majoris_history.cc",\n    "libcef/browser/majoris_runtime.cc",\n    "libcef/browser/majoris_runtime_internal.h",\n    "libcef/browser/alloy/alloy_browser_host_impl.cc",',1)
updated=updated.replace('    "//components/proxy_config",','    "//components/proxy_config",\n    "//components/sessions",',1)
if updated==build:raise SystemExit('CEF build patch context changed')
patch('0001-cef-linux-native-pip.patch','cef',[
 ('libcef/browser/alloy/alloy_browser_host_impl.cc',old,new),
 ('BUILD.gn',build,updated),('libcef/browser/majoris_runtime.cc','',(engine/'src/majoris_runtime.cc').read_text()),
 ('libcef/browser/majoris_runtime_internal.h','',(engine/'src/majoris_runtime_internal.h').read_text()),
 ('libcef/browser/majoris_history.cc','',(engine/'src/majoris_history.cc').read_text())])
path='chrome/browser/ui/views/overlay/video_overlay_window_views.cc'
old=read(path.replace('/','__'))
new=old.replace('#include <memory>','#include <cstdlib>\n#include <memory>',1)
anchor='  overlay_window->Init(std::move(params));'
replacement='''#if BUILDFLAG(IS_LINUX)
  // Majoris runs installed applications in separate processes. CHROME_DESKTOP
  // is assigned by its trusted launcher before CEF starts, never by web content.
  // Keep the native Chromium video surface/controller and use that process's
  // desktop identity for both X11 and Wayland (Brave's overlay is the reference).
  if (const char* desktop = std::getenv("CHROME_DESKTOP")) {
    std::string identity(desktop);
    if (identity.ends_with(".desktop")) identity.resize(identity.size() - 8);
    if (!identity.empty() && identity.size() <= 255 &&
        identity.find_first_not_of(
            "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789._-") ==
            std::string::npos) {
      params.wm_class_name = identity;
      params.wm_class_class = identity;
      params.wayland_app_id = identity;
    }
  }
#endif
  overlay_window->Init(std::move(params));'''
if anchor not in new:raise SystemExit('Chromium overlay patch context changed')
new=new.replace(anchor,replacement,1)
patch('0002-chromium-pip-desktop-identity.patch','chromium',[(path,old,new)])
old=read('cef-task-manager.cc')
new=old.replace('         task_manager::REFRESH_TYPE_MEMORY_FOOTPRINT;','         task_manager::REFRESH_TYPE_MEMORY_FOOTPRINT |\n         task_manager::REFRESH_TYPE_NETWORK_USAGE;')
if old==new:raise SystemExit('CEF task sampling patch context changed')
patch('0003-cef-network-task-sampling.patch','cef',[('libcef/browser/task_manager_impl.cc',old,new)])
old=read('cef-osr-platform.cc')
new=old.replace('#include "cef/libcef/browser/osr/browser_platform_delegate_osr.h"','#include "cef/libcef/browser/osr/browser_platform_delegate_osr.h"\n#include "cef/libcef/browser/majoris_runtime_internal.h"',1)
anchor='    const ui::AXUpdatesAndEvents& details) {\n'
if anchor not in new or new==old:raise SystemExit('CEF OSR AX update hook changed')
new=new.replace(anchor,anchor+'  MajorisRecordAXUpdate(browser_->GetWebContents(), details);\n',1)
patch('0004-cef-osr-ax-validation.patch','cef',[('libcef/browser/osr/browser_platform_delegate_osr.cc',old,new)])
manifest=engine/'manifests/m152.json';data=json.loads(manifest.read_text());data['patches']=patches;manifest.write_text(json.dumps(data,indent=2)+'\n')
