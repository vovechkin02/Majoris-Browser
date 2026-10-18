# Release gate

Run the full Meson suite on Debian 13 with an explicitly bootstrapped SDK. Use a fresh source copy to exclude accidental generated-file dependencies:

```sh
python3 scripts/verify-clean.py --cef-root /absolute/path/to/cef-sdk
```

The suite exercises domain persistence/migrations/import, downloads, renderer permission persistence/revocation/reset, cookies and storage isolation, beforeunload cancellation/acceptance, trusted HTTPS credentials with a disposable Secret Service, native desktop notifications, and concurrent GTK Browser/app lifecycle. Check the test list: missing optional desktop/keyring prerequisites must not silently qualify a release with fewer suites.

Build a Debian binary package using `packaging/debian` as the source package's `debian` directory and an absolute `CEF_ROOT`. Inspect archive ownership/modes, especially the root-owned mode-4755 sandbox helper, runtime libraries, subprocess, schemas, desktop metadata, PolicyKit action and notices. Extract to a disposable staging directory and run the GTK smoke workflow using that executable, helper and runtime. A relocated staging prefix may need LD_LIBRARY_PATH; this does not qualify real system installation.

`python3 scripts/verify-package.py --cef-root /absolute/path/to/cef-sdk` automates a fresh Debian build with its tests in a temporary native Linux source directory and copies the resulting artifacts into a new ignored workspace directory. On WSL, `/tmp` must be on the Linux filesystem: Windows-mounted staging trees can report mode 0777 despite chmod and are rejected by dpkg. Do not relax dpkg's permission checks to work around that filesystem behavior.

Run `python3 scripts/verify-deb.py /absolute/path/to/majoris-browser_VERSION_amd64.deb` to check archive ownership, sandbox mode, required resources/notices, installed search paths and the extracted GTK/CEF runtime. This script requires readelf, Xvfb and dbus-run-session. It uses a disposable Linux staging directory and relocates library lookup only for that check.

Repeat on native Wayland and X11 environments, and under upstream Adwaita as well as Majoris Theme. Verify installation/upgrade, runtime lookup without SDK paths, subprocess execution, CEF notices, desktop MIME associations and sandbox configuration. Follow `security-maintenance.md` for engine update qualification.

The supplied task's manual scenario remains mandatory and unexecuted: install Google Sheets, pin it, close Browser, launch Sheets from the dock, authenticate, restart Sheets, clear an independent normal Browser session, and confirm Sheets remains signed in. Verify external links open Browser, dock/Alt+Tab identities differ, Browser closure leaves Sheets running, and clearing closed-app Sheets data leaves Browser data unchanged. Repeat DevTools, context menus, file selection and permission UI checks. On 18 October 2026 the user confirmed that a Majoris desktop is unavailable; authenticated Sheets, dock identity and native Wayland checks must remain marked unverified.

Use a consenting human's account for authentication; never embed credentials in tests or fixtures. Deterministic fixtures live in tests/fixtures and run through a loopback-only test HTTP server. Check localStorage, IndexedDB, Cache Storage, service-worker storage and HTTP cache in addition to cookies before qualifying the full data-clearing feature.

Reject release while any release-blocking item in implementation-status.md remains unresolved. Record actual results and engine/platform versions rather than treating a checked-in checklist as evidence of manual verification.

The final suite has 20 required groups; scripts/verify-package.py enforces the exact set. GTK 4.18, libpsl and AT-SPI/XTest test prerequisites are required. Public OSR AX action dispatch, PiP and absent task PID/network fields must remain explicitly qualified as described in implementation-status.md. X11 WM_CLASS fixture success does not qualify the Majoris dock or Wayland app identity.
