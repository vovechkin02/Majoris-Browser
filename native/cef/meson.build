cef_root = get_option('cef_root')
if cef_root == ''
  error('CEF SDK required: run scripts/bootstrap-cef.py explicitly, then pass -Dcef_root=/absolute/path; use -Ddomain_only=true for headless domain tests')
endif
cpp = meson.get_compiler('cpp')
cef_lib = cpp.find_library('cef', dirs: cef_root / 'Release')
wrapper_lib = cpp.find_library('cef_dll_wrapper', dirs: cef_root / 'build/libcef_dll_wrapper')
cef_inc = include_directories('include')
cef_runtime_dir = get_option('prefix') / get_option('libdir') / 'majoris-browser/cef'
cef_helper = get_option('prefix') / get_option('libexecdir') / 'majoris-browser-cef-subprocess'
cef_bridge = shared_library('majoris-cef', ['src/bridge.cpp', 'src/profile-data.cpp'], include_directories: cef_inc,
  link_args: ['-Wl,--version-script=' + meson.current_source_dir() / 'majoris-cef.map'],
  link_depends: files('majoris-cef.map'),
  dependencies: [gio, dependency('gobject-2.0'), dependency('libpsl'), cef_lib, wrapper_lib, dependency('threads')],
  cpp_args: ['-I' + cef_root, '-DMAJORIS_VERSION="' + meson.project_version() + '"', '-Wno-unused-parameter'], install: true, install_dir: get_option('libdir') / 'majoris-browser',
  build_rpath: cef_root / 'Release', install_rpath: cef_runtime_dir)
executable('majoris-browser-cef-subprocess', 'subprocess/main.cpp', include_directories: cef_inc,
  cpp_args: ['-I' + cef_root],
  dependencies: [cef_lib, wrapper_lib, dependency('threads')], install: true,
  install_dir: get_option('libexecdir'), build_rpath: cef_root / 'Release', install_rpath: cef_runtime_dir)
cef_dep = declare_dependency(link_with: cef_bridge, dependencies: cef_lib, link_args: ['-Wl,--no-as-needed'], include_directories: include_directories('include'))
install_subdir(cef_root / 'Resources', install_dir: cef_runtime_dir, strip_directory: true)
foreach f : ['libcef.so', 'chrome-sandbox', 'libvk_swiftshader.so', 'libvulkan.so.1', 'v8_context_snapshot.bin', 'vk_swiftshader_icd.json']
  install_data(cef_root / 'Release' / f, install_dir: cef_runtime_dir)
endforeach
install_data(cef_root / 'LICENSE.txt', install_dir: get_option('datadir') / 'licenses/majoris-browser', rename: 'CEF-LICENSE.txt')
install_data(cef_root / 'CREDITS.html', install_dir: get_option('datadir') / 'licenses/majoris-browser')
