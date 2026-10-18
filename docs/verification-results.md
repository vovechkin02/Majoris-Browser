# Verification results — 18 October 2026

Environment: Debian 13 under WSL on Windows; Vala 0.56.18, GTK 4.18.6, libadwaita 1.7.6, Meson 1.7.0, GCC 14.2.0 and libpsl 0.21.2. Engine: CEF 152.0.14+g8a0b5b9 / Chromium 152.0.7977.167, Linux x86-64. Sandboxing remained enabled. These are development results, not release approval.

The expanded workspace run passed **20 suites, 0 failures, 0 skipped** (`build/audit-final-tests.log`). Subsequent targeted checks also passed for retained Task Manager metrics/actual renderer termination (`build/audit-task.log`), dynamic AT-SPI geometry (`build/audit-geometry.log`) printing cancellation/PDF paper dimensions, and actual Browser/app WM_CLASS identity (`build/audit-identity.log`). Fresh-source and package verification use these final sources and the exact required set below.

| Suite | Actual executed assertions |
|---|---|
| domain | 17 cases: URL/scope/auth, migrations/private/session, tabs/audio state, installer publication rollback, bookmark formats/folders/order, unchanged read-only imports, Firefox places bookmarks, category/time clearing |
| cef-exit | Real two-view beforeunload denial cancels clear intent, pages/cookies remain, later ordinary operation and confirmed shutdown; Browser clearing preserves the app context and restart cookie |
| app-uninstall | Real SQLite/filesystem rollback on unpin failure, profile lease exclusion, keep data, persistent cleanup failure/reload/retry and refusal to reinstall while pending |
| cef-site-cookies | Secure/HttpOnly parent-domain and non-root-path cookies; own CHIPS partition removed, unrelated top-level partition and installed-app partition retained |
| cef-storage-isolation | Engine-issued storage-key clearing; localStorage, IndexedDB, Cache Storage, worker/cache isolation and restart; Unicode commit, settings, PDF/MHTML and real opener/context preservation |
| cef-cookie-isolation | Persistent/private profiles, restart, exclusive leases and safe descriptor-based deletion; siblings/symlink/dot/parent-dot cases |
| cef-close | Trusted beforeunload: denial retains an evaluable page; later acceptance emits engine completion |
| cef-permissions | Persisted Browser allow versus app deny; live revoke/reset reaches actual Chromium permission state |
| cef-downloads | Real streamed download, pause/resume/cancel, byte count and persisted stable metadata |
| cef-credentials | Disposable trusted TLS/Secret Service, multiple logins and context separation, secure same-origin fill, isolated binding and trusted submission/navigation |
| cef-modern-credentials | Dynamic async, formless, password change and matching-origin iframe; foreign frame exclusion, failed response refusal; address aliases/selects/password exclusion and Secret Service update |
| cef-authentication | Trusted local TLS provider, delayed popup after activation expiry with site popup permission, explicit intermediate-origin consent, real opener, exact return/state revocation, short expiry and unrelated-app refusal |
| cef-context-menus | Real page/link/image/input/iframe descriptors, valid PNG copy data, focused-frame cut, source content |
| cef-printing | Setup cancel/retry, selected Letter landscape MediaBox, rejected/accepted PDF job, JavaScript print and page closure while setup is pending; no real printer claim |
| cef-platform | Verified TLS status/dates/PEM, actual HTTP UA/Client Hints and high entropy data; running/suspended WebAudio, host mute and silent video; explicit OSR PiP refusal; retained task observer and actual renderer termination |
| cef-accessibility | Real Chromium document/control tree and native geometry-change payload |
| gtk-accessibility | Independent AT-SPI traversal of top document plus same/foreign-origin frames; roles, labels, checked state, UTF-8 text, dynamic content, focus/caret/selection and changed main-frame bounds |
| gtk-drag | Actual XTest pointer source/target gestures, cancellation, exported link/image and inbound local file; real key typing/deletion and bidirectional GTK/Chromium Japanese/emoji clipboard |
| cef-native-notifications | Actual Chromium notification through disposable D-Bus desktop service; branded desktop entry, click/close and originating page delivery |
| gtk-smoke | Real GTK/CEF frames, manifest install/dialog/icon/desktop/registry, Browser/settings/history/downloads/Task Manager, multiple Browser windows/private exclusion, independent app process and clean saved snapshot |

Tests use disposable profiles and loopback HTTP/TLS servers. Secret tests use a disposable unlocked keyring and locally generated NSS trust; no account credentials are used. Other fixtures may use Chromium's basic cookie-encryption backend only under a test environment flag. Real keyboard/drag/clipboard and native-print tests use isolated X11 displays; GTK surfaces explicitly choose X11 so XTest never targets a WSLg Wayland window accidentally.

Important defects discovered by runtime verification were corrected before qualification: CEF origin serialization differed from Window.origin; async credential response status could be an integer; the context PNG fixture had an invalid CRC; Vala nested string-expression ownership and accessible-text callback argument order required explicit handling; unattached AX nodes must not receive platform-focus publication; a transient CEF Task Manager observer stopped asynchronous work; and accepted native printer-driver setup trapped inside Chromium. The final print path generates the selected PDF and submits it through GTK instead. Earlier failing logs are diagnostic history, not passing evidence.

## Remaining qualification

The user confirmed no Majoris desktop is available. Authenticated Google Sheets/Microsoft, dock/Alt+Tab grouping, two distinct real installed apps, native Wayland/IME/scaling, Majoris Theme, full Orca/braille interaction, PolicyKit/locked-keyring UI, physical printer/backend/copies/ranges, PDF-viewer print UI and real system installation/upgrade remain unverified. Complex AX transforms/cross-frame character geometry and direct AX action/edit dispatch are not claimed. Audio activity is not sample-accurate silence detection. PiP is a verified CEF Alloy OSR limitation, not an untested promise.

See `implementation-status.md` for the complete implemented/tested, unverified, partial, upstream-limited and intentionally unimplemented matrix. Do not interpret fixture success as production readiness.

## Final build and package record

The final fresh-source directory is `build-clean-release-final/source`, with build output in `build-clean-release-final/output`. Its initial parallel run exposed a compositor-hit-test race in the authentication test's synthetic pointer trigger. After adding an acknowledged trusted-click wait, the auth fixture passed three consecutive runs (`build/release-auth-repeated.log`). The test source was refreshed and rebuilt in that clean directory, then **all 20 suites passed, 0 failed, 0 skipped** (`build/release-clean-final-tests.log`). Initial and subsequent TLS navigation UA/Client Hints assertions also passed (`build/release-headers.log`). This was a test synchronization fix; no production code changed after the final package source snapshot.

The final hardened Debian build passed the exact **20-suite** gate. Artifacts are in `build-packages-release-final/`:

- `majoris-browser_0.1.0-2_amd64.deb` (251,220,208 bytes).
- `majoris-browser-dbgsym_0.1.0-2_amd64.deb`, `.buildinfo`, `.changes` and `SHA256SUMS`.
- Main package SHA-256: `662cdf2c738b86b8cd776c07d6ecb7353fda5638b6dc86c5fddf867bfc8c5928`.

`build/release-package-final.log` records the fresh native-Linux source build, Debian hardening and full test results. Package verification requires GTK 4.18, libpsl and AT-SPI/XTest test prerequisites. The package remains version 0.1.0 with Debian revision 2; schema v5 adds durable uninstall cleanup jobs.

`scripts/verify-deb.py` passed against that final package (`build/release-deb-runtime.log`): root ownership, no world-writable archive entries, root-owned mode-4755 sandbox, complete resources/notices/desktop/schema/policy files, installed ELF lookup without SDK paths and an extracted-library GTK/CEF smoke run. The smoke run also verifies distinct Browser/app X11 WM_CLASS identities. Extraction is not system installation or upgrade. AppStream and desktop-file validation passed (`build/release-metadata.log`). `git diff --check` passed.

Earlier artifacts under `build-packages-audit-final` and prior release-check directories are superseded. The final artifact above includes the X11 program-identity correction. Debugging and temporary verification source/build directories remain ignored; the pre-existing ZIP deletion was not changed by this work.

## Source changes and corrected defects

The main changes are in `src/application.vala`, `src/sessions/exit-operation.vala`, Browser/app windows, `src/webapps/web-app-manager.vala` and `src/services/store.vala`; the native bridge and its additive C ABI/VAPI; credential/address controllers; shared context/certificate/data dialogs; GTK drag/drop and accessibility adapters; import/download metadata; and the Meson/Debian/test configuration. New native headers separate authentication policy, credential observation and public-suffix cookie selection.

Corrected defects include stale destructive exit intent after cancellation, cross-partition cookie ambiguity, non-atomic uninstall failure handling, no-gesture auth rejection and overbroad provider grants, app overflow/Browser-window leakage, missing async/formless/frame credential handling, failed-login capture, stopped-versus-muted conflation, incomplete native menu/certificate/data/import paths, missing OSR source drag and accessible content, native printer-driver crashes, transient Task Manager observers and Browser/app X11 identity reuse. Tested completion and remaining qualification are distinguished in the matrix rather than inferred from controls merely being present.
