# Custom engine release qualification — revision 0.1.0-7

Use [the source build guide](../engine/README.md) and
[patch maintenance guide](../engine/PATCH-MAINTENANCE.md). Qualify the prepared
custom SDK separately from the standard fallback. The exact required package
test set is now 27 groups, including `cef-history` and `cef-native-pip`.
`scripts/verify-package.py` rejects a missing, skipped or failing required group.

Required evidence includes a successful pinned engine build and SDK digest,
actual H.264/AAC/MP4 decode logs, native PiP pixels/identity/lifecycle, real
AX/AT-SPI actions and text editing, navigation selection/back/forward without URL
replay, private/cross-profile refusal, and task metrics/kill regressions. Run the
full Majoris suite, Debian package build and extracted-package smoke against
that exact SDK. Preserve failed attempts as well as final results.

This pass completed fresh standard 27/27, fresh custom 27/27 and Debian custom
27/27, followed by archive and extracted-runtime verification. Native media,
PiP, required AX/AT-SPI actions, history and real task metrics passed. Additional
abrupt-crash history recovery passed against both runtimes. See
[artifact hashes and exact logs](verification-results.md). The resulting
0.1.0-7 package is a development artifact; the external gates below still apply.

Custom SDK provenance is installed beside libcef.so. Packaging verifies that
the library digest matches it. An unqualified runtime/security build or unapproved codec build requires explicit
`MAJORIS_DEVELOPMENT_ENGINE=1` development packaging; this is not distribution
approval. Do not mark source/runtime/security/redistribution qualification true
merely because source patches apply or compilation completes.

The target Majoris desktop and accounts are unavailable, as confirmed by the
user. Native Wayland, actual dock grouping, Orca and real Google Sheets/provider
checks therefore remain unverified. No system installation/upgrade or approved
production codec distribution has been performed. Earlier package records below
refer to their stated standard SDK revisions, not the custom engine.

## Earlier standard-SDK records

# Release gate

The authoritative current gate is revision 0.1.0-6 with **25 required suites**, adding download-scanner while retaining all 24 earlier groups. Verify optional scanner configuration, socket permissions, official signature maintenance, size/time limits, pending/open restrictions, removal/private cancellation and harmless test signatures. Verify managed service entitlement, per-installation provisioning, operator abuse/privacy controls, live health/rotation and consent before enabling distribution defaults. No live deployment is supplied. See the authoritative matrix and current verification section; older package results remain historical.

Final results: unchanged clean-source rerun 25/25, Debian 25/25, real disposable clamd/harmless signature, archive/extracted GTK/CEF runtime and desktop metadata passed. The first clean media run timed out; three unchanged isolated repeats and the complete rerun passed. Retain the initial failure and its unproven cause in release evidence. No tests were weakened or skipped. The final artifact is in build-packages-production-qualified, with source/runtime checksums and RELEASE-BLOCKED.txt; this does not qualify system installation or production distribution.

Revision 0.1.0-5 passed the final fresh-source and Debian 24/24 gates, archive/extracted-runtime checks and desktop metadata validation. The retained development artifact and checksum are recorded in verification-results.md. This does not resolve the engine delta, authorised live-provider/media dependencies, actual system installation/upgrade or unavailable target-desktop/account qualification. The package's RELEASE-BLOCKED notice remains mandatory.

The required set is now **25 suites**. The additional web-risk-provider group exercises the actual adapter against disposable HTTPS and Secret Service, including secret storage/removal, bad TLS, redirect denial, bounded/error parsing, rate limiting/recovery and cancellation. New groups are threat-protection (deterministic provider/cache/timeout/cancellation/privacy), cef-threat-navigation (real allowed navigation and redirect block before destination fetch), and cef-media-playback (actual original WebM video/decoded Opus audio in Browser/app contexts). Existing domain/download tests also cover scope metadata/normalisation/migration and persisted assessment/open restrictions. verify-package.py enforces the exact expanded set.

For a codec-capable SDK, supply the local licensed assets described in codec-runtime.md; missing assets or decode failure must prevent qualification. Keep hardware acceleration, physical output and DRM separate from successful software playback. Review security-assessment.md before releasing any package. The Web Risk adapter is implemented and locally qualified; no authorised live account/key or qualified H.264/AAC runtime exists in this session. Real Sheets, native Wayland/dock/theme and Orca remain the already-agreed manual gates, not passing-X11 conclusions.

The latest pass adds release-critical download ownership checks. Confirm normal/app/private lists and every action stay in their own context, private metadata vanishes after the last session view closes, SQLite/restart contains no private record, and user files remain. Test software-opening confirmation with both risky and ordinary files; unknown safety must never appear as a safe verdict. The current build has no qualified live URL reputation account or production scanner/signature deployment; read security-maintenance.md before distribution.

Expanded fixtures cover trusted username-first steps, editable/protected/Unicode AT-SPI text, two distinct installed apps and their restarted storage, real Wasm/WSS/local WebRTC, invalid TLS, SOP/file-fetch denial and renderer seccomp/no-new-privileges. The SDK's VP8/VP9/Opus capability does not imply H.264/AAC or DRM. HTTP/2/3, hardware capture, physical printer/file-dialog UX, screen reader actions, native Wayland and target theme remain independent manual/infrastructure gates. Retain the exact feature matrix and capability report with each release.

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

The final suite has 25 required groups; scripts/verify-package.py enforces the exact set. GTK 4.18, libpsl and AT-SPI/XTest test prerequisites are required. Public OSR AX action dispatch, PiP and absent task PID/network fields must remain explicitly qualified as described in implementation-status.md. X11 WM_CLASS fixture success does not qualify the Majoris dock or Wayland app identity.
