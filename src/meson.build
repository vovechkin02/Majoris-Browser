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
  'ui/page-actions.vala',
  'credentials/credential-store.vala', 'credentials/credential-dialog.vala',
  'credentials/credential-controller.vala',
  'credentials/credential-manager.vala',
  'credentials/address-dialog.vala',
  'sessions/session-service.vala',
  'permissions/permission-service.vala',
  'permissions/policy-dialog.vala',
  'navigation/omnibox.vala',
  'downloads/download-record.vala', 'downloads/downloads-dialog.vala',
  'downloads/download-service.vala',
  'bookmarks/bookmarks-dialog.vala',
  'webapps/web-app-manager.vala',
  'settings/import-dialog.vala',
  'services/store-worker.vala', 'services/profile-cleaner.vala', 'integration/shell-integration.vala', 'settings/preferences-window.vala', resources,
  dependencies: domain_deps + [gtk, adw, cef_dep, dependency('gio-unix-2.0'), dependency('libsecret-1'), dependency('libsoup-3.0'), dependency('gdk-pixbuf-2.0')],
  vala_args: ['--target-glib=2.76'], c_args: ['-DGETTEXT_PACKAGE="majoris-browser"'],
  install: true, install_rpath: get_option('prefix') / get_option('libdir') / 'majoris-browser' + ':' + cef_runtime_dir)
xvfb = find_program('xvfb-run', required: false)
if xvfb.found() and dbus_session.found()
  python = find_program('python3')
  if run_command(python,'-c','import gi',check:false).returncode()==0
    test('cef-native-notifications',dbus_session,args:['--',xvfb.full_path(),'-a',python.full_path(),meson.project_source_root()/'tests/cef/notifications-probe.py',notification_probe.full_path(),meson.project_build_root()/'native/cef/majoris-browser-cef-subprocess',cef_root/'Release',meson.project_source_root()/'tests/fixtures'],timeout:35,is_parallel:false)
  endif
  test('gtk-smoke', dbus_session, args: ['--', xvfb.full_path(), '-a', python.full_path(), meson.project_source_root() / 'tests/integration/smoke.py', browser_exe.full_path(), meson.project_build_root() / 'native/cef/majoris-browser-cef-subprocess', cef_root / 'Release', meson.project_source_root()], timeout: 80,is_parallel:false)
endif
