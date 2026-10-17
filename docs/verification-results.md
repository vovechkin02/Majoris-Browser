# Verification results — 18 October 2026

Environment: Debian 13 under WSL on Windows; Vala 0.56.18, GTK 4.18.6, libadwaita 1.7.6, Meson 1.7.0 and GCC 14.2.0. Engine: CEF 152.0.14+g8a0b5b9 / Chromium 152.0.7977.167, Linux x86-64. Chromium sandboxing remained enabled. These are development verification results, not release approval.

A fresh source copy was configured and compiled with `scripts/verify-clean.py`, excluding generated files, the external SDK and the user's ZIP artifact. After the final deletion-root checks and asynchronous-close guard, the complete suite was rerun against that source copy: **10 suites passed, 0 failed, 0 skipped**.

| Suite | Executed evidence |
|---|---|
| domain | URL/scope/auth policy, SQLite migrations/persistence/private exclusion, session generations, bookmark HTML/folders/order, installer rollback and read-only source import |
| cef-close | Trusted page edit registers beforeunload; refusing close preserves an evaluable page; accepting a later close emits engine completion |
| cef-permissions | Persisted browser allow versus app deny in real Notification.permission; live revocation and reset propagate to Chromium |
| cef-downloads | Real streaming file transfer, pause/resume/cancel and persistent UUID download metadata |
| cef-site-cookies | Secure/HttpOnly, parent-domain and non-root-path matching cookies clear; unrelated cookies and app context survive |
| cef-storage-isolation | localStorage, IndexedDB, Cache Storage, service worker and HTTP-cache isolation across clearing/restarts; Unicode input, UA/Client Hints, applied settings, PDF/MHTML output and genuine popup opener/context |
| cef-credentials | Locally trusted HTTPS, disposable Secret Service, multiple logins/profile isolation, wrong-origin refusal, isolated binding, fill and trusted submission/navigation outcome |
| cef-cookie-isolation | Persistent/private contexts, restart persistence, exclusive profile lease, sibling preservation, refusal of symlink roots/parents and dot/parent-dot roots |
| cef-native-notifications | Real web Notification through desktop D-Bus, app display name/desktop-entry hint, click callback and CloseNotification |
| gtk-smoke | Rendered GTK/CEF pages, actual manifest/PNG app installation, settings/history/downloads/Task Manager, two-window snapshot/private exclusion and Browser/app concurrent independent lifetime |

Before the final complete run, credential, notification and close fixtures each passed three consecutive repeated runs after their timing fixes. AppStream validation (`appstreamcli validate --no-net`) and strict GSettings schema validation passed. Domain-only building also passed during this implementation.

Logs are ignored development artifacts: `build/release-tests.log` contains the final complete summary; `build-final-verification/output/meson-logs/testlog.txt` contains individual test output. `build/clean-final.log`, `build/clean-final-recheck.log`, `build/clean-close-recheck.log`, `build/credential-recheck.log`, `build/notification-recheck.log` and `build/close-repeat.log` record earlier fresh-build and targeted verification. Source-copy runtime files match the corresponding working source; later documentation edits do not affect these binaries.

The final native-Linux-filesystem Debian build also passed **all 10 suites**, using Debian hardening flags. `scripts/verify-package.py` checked the exact required suite set, successful results and absence of subprocess stack-canary failures. Artifacts are in `build-packages-release-check/`: `majoris-browser_0.1.0-1_amd64.deb`, its debug-symbol package, `.buildinfo`, `.changes` and `SHA256SUMS`. The full verbose build/test record is `build/package-release-check.log`.

`scripts/verify-deb.py` passed archive inspection and an extracted-runtime smoke test. It checked root ownership, absence of world-writable regular files/directories, mode 4755 for chrome-sandbox, the bridge/subprocess/CEF resources, desktop/schema/PolicyKit files, CEF notices, and installed ELF search paths without SDK/build locations. The extracted executable and helper loaded only relocated packaged libraries for the concurrent Browser/app GTK test. See `build/deb-runtime-verification.log`. This was extraction/staging, not system installation or upgrade.

Earlier attempts are superseded: Windows-mounted staging reported mode 0777 and was correctly refused by dpkg; a native hardened build exposed the helper entry-point canary problem, fixed with CEF's NO_STACK_PROTECTOR annotation on that tiny entry point. The optimized notification fixture now waits for acknowledgement of an actual pointer click rather than assuming compositor hit-test readiness from rAF alone. Hardened storage/popup and notification tests then each passed three repeats (`build/hardened-fixtures.log`) before the final successful package run. The older `build-packages-final/` artifact predates that helper fix and is marked superseded. The rapid beforeunload fixture can emit CEF's windowless default-dialog diagnostic while its explicit cancellation/acceptance assertions pass; this does not qualify all desktop dialog UX.

The user confirmed that no Majoris desktop is available. Authenticated Google Sheets, Majoris dock/Alt+Tab identity and native Wayland checks remain **unverified**. No live account credentials were used. Xvfb/loopback fixtures do not qualify those scenarios. Physical-device permissions, PolicyKit UI, real printer/PiP/DRM behavior, provider OAuth compatibility and real system package installation/upgrade remain unverified.

The complete supplied specification remains unfinished. See `implementation-status.md` for engineering gaps, including the complete accessibility adapter, outgoing drag/drop and remaining menu/input/credential workflows. Passing tests cover the listed fixtures, not all browser behavior.
