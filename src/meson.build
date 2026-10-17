conf = configuration_data()
conf.set_quoted('VERSION', meson.project_version())
conf.set_quoted('CEF_HELPER', cef_helper)
conf.set_quoted('CEF_RESOURCES', cef_runtime_dir)
conf.set_quoted('LOCALEDIR', get_option('prefix') / get_option('localedir'))
configure_file(output: 'config.h', configuration: conf)
config_vapi = files('config.vapi')
browser_exe = executable('majoris-browser', domain_sources, config_vapi,
  '../native/cef/vala/majoris-cef.vapi',
  'application.vala', 'browser-window.vala', 'web-app-window.vala',
  'ui/browser-surface.vala', 'ui/engine-dialogs.vala', 'ui/task-manager.vala',
  'credentials/credential-store.vala', 'credentials/credential-dialog.vala',
  'services/store-worker.vala', 'services/profile-cleaner.vala', 'integration/shell-integration.vala', 'settings/preferences-window.vala', resources,
  dependencies: domain_deps + [gtk, adw, cef_dep, dependency('gio-unix-2.0'), dependency('libsecret-1')],
  vala_args: ['--target-glib=2.76'], c_args: ['-DGETTEXT_PACKAGE="majoris-browser"'],
  install: true, install_rpath: get_option('prefix') / get_option('libdir') / 'majoris-browser' + ':' + cef_runtime_dir)
xvfb = find_program('xvfb-run', required: false)
if xvfb.found() and dbus_session.found()
  python = find_program('python3')
  test('gtk-smoke', dbus_session, args: ['--', xvfb.full_path(), '-a', python.full_path(), meson.project_source_root() / 'tests/integration/smoke.py', browser_exe.full_path(), meson.project_build_root() / 'native/cef/majoris-browser-cef-subprocess', cef_root / 'Release', meson.project_source_root()], timeout: 80)
endif
