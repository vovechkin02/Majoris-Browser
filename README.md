# Majoris Browser

The final security pass adds an opt-in Google Web Risk Lookup adapter, Secret Service key configuration, full-URL consent, bounded HTTPS checks and native Google-attributed warnings. It is disabled until an authorised account/key and URL-sharing consent are supplied; live service qualification remains external. Download content scanning is absent. See [provider setup and privacy](docs/security-maintenance.md#google-web-risk-configuration).

The remaining-feature pass adds an asynchronous, profile-scoped threat-provider framework (live protection **disabled** without an authorised adapter), real redirect blocking with a local fixture, download assessment states, narrower inferred app sections and scope confirmation/review. Legacy installations retain their saved scope, identity and profile until the user reviews them. Media tests now decode original synthetic VP8/VP9/Opus WebM in Browser/app contexts. H.264/AAC and Widevine remain externally blocked; see [qualified media integration](docs/codec-runtime.md). The [engine assessment](docs/security-assessment.md) keeps the unresolved security delta explicit.

The latest hardening pass isolates private download visibility and controls by session, adds explicit unassessed-download cautions, supports trusted username-first login steps, and improves editable/protected AX text. Local fixtures cover two installed application identities, WebAssembly, secure WebSockets, local WebRTC and sandbox/TLS boundaries. The bundled SDK reports VP8/VP9/Opus capability; H.264/AAC and Widevine are unavailable in the tested build. HTTP/2/3, physical camera/microphone and commercial provider compatibility remain unqualified. See the [feature matrix](docs/implementation-status.md) and [verification record](docs/verification-results.md).

GTK4/libadwaita browser and isolated web-application runtime, written primarily in Vala with a C++ CEF bridge. Application identity: `com.majoris.browser`; executable: `majoris-browser`.

**Development implementation, not a release-complete daily-driver browser.** See [implementation status](docs/implementation-status.md) for unfinished requirements and verification limits. Passing the current tests does not establish completion of the supplied product specification.

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

Meson registers domain tests and real CEF suites for cookies/storage isolation, downloads, persisted/live permissions, beforeunload consent, credentials and native notifications. The GTK smoke suite loads a local fixture, installs its manifest app through the GTK dialog, verifies its registry/desktop entry, opens settings/history/downloads/Task Manager, and runs Browser and its installed app concurrently. It asserts rendered frames and independent lifetime. Most engine fixtures use Ozone headless while retaining the sandbox. Native print/media and GTK input/accessibility fixtures use isolated X11 displays and disposable profiles. The suite now includes 24 required groups, including real AT-SPI, pointer/key/clipboard, partitioned cookies, modern credentials and failure-safe lifecycle tests.

The required Google Sheets/account/dock verification on a Majoris desktop has **not** been performed. Wayland interaction, PolicyKit reveal, native print/file dialogs and real OAuth providers still require manual qualification. Credential tests use a disposable unlocked keyring and a locally trusted HTTPS fixture. Other disposable fixtures use Chromium's basic cookie-encryption backend to avoid interactive desktop unlock prompts; this does not change production defaults or disable sandboxing. No live account credentials were used.

Run `python3 scripts/verify-clean.py --cef-root "$CEF_ROOT"` for a new source-copy build without generated files. The pinned SDK remains an external dependency. See the [completion matrix](docs/implementation-status.md) for implemented paths, limitations and remaining release work.

Run `python3 scripts/verify-package.py --cef-root "$CEF_ROOT"` on Debian to build/test packages in a temporary native Linux directory and copy artifacts back into the workspace. This also avoids Windows-mounted staging permission issues under WSL. System installation and target desktop checks remain separate release gates.

See [architecture](docs/architecture.md), [recorded test results](docs/verification-results.md), [release verification](docs/release-verification.md), [engine security maintenance](docs/security-maintenance.md), and [status](docs/implementation-status.md).
