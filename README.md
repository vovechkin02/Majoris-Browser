> **Current release-hardening record (0.1.0-8):** [docs/release-hardening.md](docs/release-hardening.md). Reviewed source: `27611aa41c806398fb0560aded3853a2a9ba53ec`. The security candidate retains four Majoris patches and adds twelve patches covering thirteen upstream maintenance/security commits. The candidate build, clean 30/30, Debian 30/30 and extracted-runtime verification passed locally. Production, redistribution and native-desktop approval remain pending. Earlier dated completion claims below are historical and do not qualify this candidate.

# Majoris Browser

Majoris now includes a pinned custom CEF/Chromium source-build pipeline, native codec development configuration, Chromium-backed PiP, validated AX action transport, native navigation-entry restoration and extended task metrics. The custom target is Chromium 152.0.7977.169 with CEF branch 7977; compilation and runtime qualification are recorded separately. See the [engine build guide](engine/README.md), [patch maintenance guide](engine/PATCH-MAINTENANCE.md) and [current implementation matrix](docs/implementation-status.md).

The standard CEF SDK remains an explicit fallback. Custom features are detected from the loaded runtime, and unavailable functionality stays disabled. The required regression set contains 30 groups, including native PiP, history, scanner UI, managed-backend fixtures and release-policy checks. Optional local clamd scanning and opt-in Web Risk adapters remain available; no production signatures, threat-service account, Widevine CDM or codec redistribution approval is bundled. See [security configuration](docs/security-maintenance.md) and [codec qualification](docs/codec-runtime.md).

GTK4/libadwaita browser and isolated web-application runtime, written primarily in Vala with a C++ CEF bridge. Application identity: `com.majoris.browser`; executable: `majoris-browser`.

**Development implementation, not a release-complete daily-driver browser.** See [implementation status](docs/implementation-status.md) for unfinished requirements and verification limits. Passing the current tests does not establish completion of the supplied product specification.

## Current hardening release (0.1.0-8)

Scanner controls now follow live clamd health, with signature-age warnings,
configurable bounded streams, cancellation and shutdown safety. The optional
[operator backend](services/threat-protection/README.md) implements the existing
managed Web Risk contract; it is separate from Browser and has not been deployed.
Installed apps keep independent profiles, and newer-engine profiles refuse
unsafe downgrade attempts without resetting user data.

The security candidate retains native codecs, PiP, AX actions, history and task
metrics while adding reviewed Chromium/V8 maintenance fixes. Its exact pins,
patches, verification and external release blockers are in the
[current release record](docs/release-hardening.md). The standard .167 SDK below
is for compatibility/development testing and is not security-approved for release.
Development, release-candidate and production packaging have explicit gates;
passing tests never grants security, codec redistribution or production approval.

## Build on Debian 13

Install `build-essential valac libgtk-4-dev libadwaita-1-dev libglib2.0-dev libgee-0.8-dev libjson-glib-dev libsqlite3-dev libsecret-1-dev libsoup-3.0-dev libxml2-dev libpsl-dev libgdk-pixbuf-2.0-dev meson ninja-build gettext cmake python3`. GTK 4.18+ and libadwaita 1.5+ are required. For all integration tests, also install `xvfb xauth dbus-daemon python3-gi gir1.2-atspi-2.0 at-spi2-core libxtst6 libnss3-tools gnome-keyring`.

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

Install a website with **Install as App…**. Same-origin manifest name, start URL and scope are used when available, otherwise the dialog proposes a path section for confirmation. Each generated desktop entry launches `majoris-browser --app=<id>` with its own GTK application identity and process. Closing Browser does not close app processes. GNOME favourites integration is behind `ShellIntegration`.

Site Information clears associated host/domain cookies using exact partition keys, and main-frame site storage using a storage key returned by Chromium. Shared domain cookies can also be used by sibling hosts; other origins' storage is preserved. Full Browser clearing shuts down its engine before deleting only its profile. App-data clearing and uninstall hold that app's exclusive profile lock, refuse running apps and reject symlinked profile roots or parents. Uninstall offers retaining or removing site data.

Private windows use in-memory CEF contexts shared among their tabs, omitted from history/session/download persistence. Supported HTTPS login forms use an isolated renderer observer, consented save/update prompts and Secret Service storage. Autofill checks the current main-frame origin. Password reveal requires PolicyKit authentication. No password is stored in SQLite or GSettings. Supported async/formless/password-change and same-origin-frame flows are tested; arbitrary SPA success inference and secure password import are not claimed.

## Verification

Meson registers domain tests and real CEF suites for cookies/storage isolation, downloads, persisted/live permissions, beforeunload consent, credentials and native notifications. The GTK smoke suite loads a local fixture, installs its manifest app through the GTK dialog, verifies its registry/desktop entry, opens settings/history/downloads/Task Manager, and runs Browser and its installed app concurrently. It asserts rendered frames and independent lifetime. Most engine fixtures use Ozone headless while retaining the sandbox. Native print/media and GTK input/accessibility fixtures use isolated X11 displays and disposable profiles. The suite now includes 25 required groups, including real AT-SPI, pointer/key/clipboard, partitioned cookies, modern credentials and failure-safe lifecycle tests.

The required Google Sheets/account/dock verification on a Majoris desktop has **not** been performed. Wayland interaction, PolicyKit reveal, native print/file dialogs and real OAuth providers still require manual qualification. Credential tests use a disposable unlocked keyring and a locally trusted HTTPS fixture. Other disposable fixtures use Chromium's basic cookie-encryption backend to avoid interactive desktop unlock prompts; this does not change production defaults or disable sandboxing. No live account credentials were used.

Run `python3 scripts/verify-clean.py --cef-root "$CEF_ROOT"` for a new source-copy build without generated files. The pinned SDK remains an external dependency. See the [completion matrix](docs/implementation-status.md) for implemented paths, limitations and remaining release work.

Run `python3 scripts/verify-package.py --cef-root "$CEF_ROOT"` on Debian to build/test packages in a temporary native Linux directory and copy artifacts back into the workspace. This also avoids Windows-mounted staging permission issues under WSL. System installation and target desktop checks remain separate release gates.

See [architecture](docs/architecture.md), [recorded test results](docs/verification-results.md), [release verification](docs/release-verification.md), [engine security maintenance](docs/security-maintenance.md), and [status](docs/implementation-status.md).
