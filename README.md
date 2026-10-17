# Majoris Browser

GTK4/libadwaita browser and isolated web-application runtime, written primarily in Vala with a C++ CEF bridge. Application identity: `com.majoris.browser`; executable: `majoris-browser`.

**Development implementation, not a release-complete daily-driver browser.** See [implementation status](docs/implementation-status.md) for unfinished requirements and verification limits. Passing the current tests does not establish completion of the supplied product specification.

## Build on Debian 13

Install `build-essential valac libgtk-4-dev libadwaita-1-dev libglib2.0-dev libgee-0.8-dev libjson-glib-dev libsqlite3-dev libsecret-1-dev meson ninja-build gettext cmake python3`. For UI tests, also install `xvfb xauth dbus-daemon`.

CEF is an explicit dependency. Meson never downloads it. The bootstrap downloads a pinned ~321 MB Linux x86-64 SDK, verifies the publisher's pinned checksum, stages runtime resources, and builds its wrapper:

```sh
python3 scripts/bootstrap-cef.py
export CEF_ROOT="$PWD/.cef/distribution/cef_binary_152.0.14+g8a0b5b9+chromium-152.0.7977.167_linux64_minimal"
meson setup build -Dcef_root="$CEF_ROOT"
meson compile -C build
meson test -C build --print-errorlogs
sh scripts/run-dev.sh
```

For an SDK obtained separately, build its `libcef_dll_wrapper` CMake target in `<cef_root>/build`, and copy the contents of its `Resources/` directory into `Release/`. Chromium resolves ICU and some resources beside `libcef.so`; pointing `resources_dir_path` at another directory is insufficient. Missing material is checked before initialization.

Run only domain tests without GTK, CEF or a display:

```sh
meson setup build-domain -Ddomain_only=true
meson compile -C build-domain
meson test -C build-domain --print-errorlogs
```

Install with `meson install -C build`. Runtime files go under the configured libdir's `majoris-browser/cef/`, the bridge under `majoris-browser/`, and the subprocess helper under libexec. The SDK and build outputs are ignored by Git. Browser updates belong to OS packaging.

## Profiles and installed applications

Browser-owned SQLite data lives under `$XDG_DATA_HOME/majoris-browser/browser/`. The normal CEF runtime root is `cef/browser/`; each app uses `cef/webapps/<id>/` as its independent runtime root and request-context path. Chromium can create a `Default/` directory within these roots.

Install a website with **Install as App…**. Same-origin manifest name, start URL and scope are used when available, otherwise ordinary sites receive an origin scope. Each generated desktop entry launches `majoris-browser --app=<id>` with its own GTK application identity and process. Closing Browser does not close app processes. GNOME favourites integration is behind `ShellIntegration`.

Browser site-data clearing shuts down the normal engine before deleting only its profile. App-data clearing acquires that app's exclusive profile lock, refuses running apps, and never follows a symlinked profile root. Uninstall currently retains site data; the separate Clear Application Data control removes it.

Private windows use in-memory CEF contexts shared among their tabs, omitted from history/session persistence. Explicit password management uses Linux Secret Service and origin checks; passwords are never written to the Browser database or settings.

## Verification

Meson registers headless domain tests, a real CEF regression that verifies cookie isolation and persistence over process restarts, profile-clear/lock tests, and a GTK smoke suite that loads a local fixture, installs its manifest app through the GTK dialog, verifies its registry/desktop entry, opens settings/history/downloads/Task Manager, and separately launches the installed app. It asserts rendered frames, not just process startup. Engine tests use Ozone headless with software rendering while retaining the sandbox. GTK tests use Xvfb and disposable XDG homes.

The required Google Sheets/account/dock verification on a Majoris desktop has **not** been performed. Wayland interaction, native dialogs, credential interoperability and complex OAuth providers still require manual qualification. No live account credentials were used in development tests.

See [architecture](docs/architecture.md), [recorded test results](docs/verification-results.md), [release verification](docs/release-verification.md), and [status](docs/implementation-status.md).
