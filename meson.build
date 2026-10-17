project('majoris-browser', ['c', 'cpp', 'vala'], version: '0.1.0', meson_version: '>=1.0', default_options: ['cpp_std=c++20', 'warning_level=2'])
gnome = import('gnome')
i18n = import('i18n')
glib = dependency('glib-2.0', version: '>=2.76')
gio = dependency('gio-2.0')
sqlite = dependency('sqlite3')
gee = dependency('gee-0.8')
json = dependency('json-glib-1.0')
domain_sources = files('src/core/url-resolver.vala', 'src/profiles/profile-paths.vala', 'src/services/store.vala', 'src/webapps/navigation-policy.vala', 'src/webapps/authentication-policy.vala', 'src/webapps/manifest-discovery.vala', 'src/webapps/web-app.vala', 'src/tabs/tab-model.vala')
domain_deps = [glib, gio, sqlite, gee, json]
subdir('tests')
if not get_option('domain_only')
  gtk = dependency('gtk4', version: '>=4.12')
  adw = dependency('libadwaita-1', version: '>=1.5')
  subdir('native/cef')
  isolation_test = executable('cef-isolation-test', 'tests/cef/isolation.vala', 'native/cef/vala/majoris-cef.vapi', dependencies: [gio, cef_dep])
  python = find_program('python3')
  dbus_session = find_program('dbus-run-session', required: false)
  isolation_args = [meson.project_build_root() / 'native/cef/majoris-browser-cef-subprocess', cef_root / 'Release']
  if dbus_session.found()
    test('cef-cookie-isolation', dbus_session, args: ['--', python.full_path(), meson.project_source_root() / 'tests/cef/isolation-runner.py', isolation_test.full_path()] + isolation_args, env: ['MAJORIS_CEF_TEST_HEADLESS=1'], timeout: 100)
  else
    test('cef-cookie-isolation', python, args: [meson.project_source_root() / 'tests/cef/isolation-runner.py', isolation_test.full_path()] + isolation_args, env: ['MAJORIS_CEF_TEST_HEADLESS=1'], timeout: 100)
  endif
  subdir('data')
  subdir('src')
  subdir('po')
endif
