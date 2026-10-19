> **Current release-hardening record (0.1.0-8):** [release-hardening.md](release-hardening.md). Reviewed source: `27611aa41c806398fb0560aded3853a2a9ba53ec`. The security candidate retains four Majoris patches and adds twelve patches covering thirteen upstream maintenance/security commits. The candidate build, clean 30/30, Debian 30/30 and extracted-runtime verification passed locally. Production, redistribution and native-desktop approval remain pending. Earlier dated completion claims below are historical and do not qualify this candidate.

## Sixteen-patch candidate build and direct security regressions

The complete candidate linked successfully with CFI/ThinLTO: final resumed
Ninja run **3275 steps, zero failures** (`security-candidate-16-build.log` and
native build-7977-release.log). SDK preparation succeeded with actual Clang,
sysroot/wrapper provenance and **232** runtime/resource/notice hashes.

- libcef.so SHA-256: `d098dd129d1cbfe0b1fb0f7e4b86cfb6b52ccccf8965557591beb9c188174388`
- Minimal archive SHA-256: `fba0c1a1ba992995cc2bb66a4d38856866fdcaf586fbc8ffc5969e93179692ba`
- Actual SDK/provenance mirror: `build-engine-reference/security-candidate-runtime.json`.

The pinned d8 runner built in ten steps. All three upstream V8
`regress-569659194-{1,2,3}.js` cases passed with the mjsunit harness and
`--allow-natives-syntax` in the isolated test runner only. No Browser flag was
added. `security-v8-regressions.log` records runner/input hashes and each result.
The refreshed official-source audit matches the runtime library/header and CEF
branch pin; the reviewed Chromium branch delta has **no uncovered commits**.
The base remains .169 with thirteen explicitly recorded upstream commits in
twelve additional patches, alongside four original Majoris patches. No official
.170 build is claimed.

The regenerated licensing inventory matches actual source diffs, separate V8
HEAD and extension source bytes. Selected FFmpeg flags: H264_DECODER=1,
AAC_DECODER=1, GPL=0, NONFREE=0, LIBX264=0. These are technical facts, not
redistribution/patent approval.

The final clean application run passed **30/30**, with no skips/timeouts and 30
unique OK records in `build-engine-reference/candidate-clean-test-logs/`.
The Debian build also passed **30/30**; its retained records are in
`build-packages-hardening-8/test-logs/`. Package verification passed archive
ownership, sandbox mode 4755, all 232 installed runtime/resource/notice hashes,
installed search paths and extracted GTK/CEF smoke (`hardening-candidate-deb.log`).
The package buildinfo records Debian amd64, GCC 14.2 and libc6
2.41-12+deb13u4. Native Majoris apt install/upgrade/removal remains unverified.
Actual compiled GN support is `ozone_platform_wayland=true`; this is not a
native Wayland/compositor test.

Development artifacts:

| Artifact | Bytes | SHA-256 |
| --- | ---: | --- |
| `build-packages-hardening-8/majoris-browser_0.1.0-8_amd64.deb` | 264025692 | `217cb436b1b2ede520e7500a55c74d204aaf60686042bf83a73afc8b1452636c` |
| `build-packages-hardening-8/majoris-browser-dbgsym_0.1.0-8_amd64.deb` | 3251020 | `62e875c49cdbf5dfdeefba82e5a00d2205ccc546ce5232f9e850459f2f3427bb` |

The `.buildinfo` and `.changes` are retained alongside these artifacts. They
are unsigned development outputs. `engine/releases/majoris-0.1.0-8-development.json`
is a separate unapproved review record; all security/runtime/redistribution/
production approval fields remain false. The as-built SDK provenance is
immutable. Source/build/runtime success does not grant redistribution or release
approval. The previous working SDK is separately preserved at
`/home/administrator/majoris-engine-m152-codecs/sdk-before-hardening-0.1.0-8`.

The current working-tree source identity is
`591169faaa20d2a2dc887d1128fc805d546c3062ad4895b271a935a21ddf9947`.
The review record binds it and discloses two final documentation-only changes
under engine/ after the clean snapshot. Runtime/build code and root Meson, licence
and checkout inputs match the verified snapshot. Release gates reject the real
unapproved record for both RC and production, reject development opt-in in
production, and reject RC packaging without a record (`final-release-gates.log`).
`build-packages-hardening-8/SHA256SUMS` and RELEASE-BLOCKED.txt accompany the
development artifacts. No approval was inferred from passing checks.

The following source-hardening attempts are retained as history and comparison
evidence; they do not supersede the final candidate results above.

## Earlier source-hardening checks (0.1.0-8, retained history)

Source reviewed: `27611aa41c806398fb0560aded3853a2a9ba53ec` plus the working
changes documented in release-hardening.md. At this earlier stage candidate
compilation/qualification remained pending; the final candidate evidence is
recorded above. No candidate binary pass was claimed from source-only checks.

The source-hardening Debian build against the preserved earlier codec SDK passed
**30/30** required groups. `build-packages-hardening-source-8/test-logs/` preserves
its full Meson evidence; `build-engine-reference/hardening-source-package.log`
contains the build output. Archive and extracted GTK/CEF verification also pass
(`hardening-source-deb.log`). This package contains the earlier .169 runtime,
not the final maintenance candidate, and is not the production release artifact.

The earlier in-tree 30-group attempt recorded 29 passes and one new malformed-URL
test error: Python's HTTP client rejected the invalid URL before sending it.
The test now sends that case over a raw socket; the backend's five cases and
the real Chromium monitor geometry check pass (2/2 focused groups). The subsequent
Debian suite passed all 30 groups. Failures are retained, not erased or counted
as successful runs. Disposable real clamd 1.4.3 clean/harmless-signature scanning
passed; no host service was installed. Release tests reject resource mixing,
unrecorded resources, changed evidence, library tampering and production bypass.

The first final standard-SDK run reached 29/30: AX assertions passed, but the
harness terminated its parent process before Chromium finished profile writes,
causing temporary-directory removal to fail. The harness now requests a graceful
surface close and waits for CEF shutdown before cleanup; failure cleanup uses
an isolated process group. The focused custom AX test passes. Subsequent standard
serial results after the readiness correction are recorded below. No accessibility assertion was removed.

A subsequent standard-SDK run exposed a separate context-menu fixture race:
Cut and immediate Runtime.evaluate travel asynchronously. The fixture now
waits up to two seconds for the actual input value to become empty, retaining
the same empty-value assertion. The focused custom context-menu test passes.
The full standard rerun's output is retained in `hardening-stock-corrected.log`.

The initial serial AX run also caught an incomplete initial tree: frame buttons
arrived before editable descendants. The harness now waits for every required
name/role before asserting properties. Five repeated standard AX runs passed;
the subsequent serial full run passed **30/30**, with 30 unique OK records in
`build-engine-reference/standard-final-test-logs/` and stdout in
`hardening-stock-verified.log`. Scanner capability parsing was then tightened to
require the exact INSTREAM token, with unsupported-command and GTK fixtures
passing 2/2. Disposable real clamd 1.4.3 health/clean/harmless-signature checks
also pass (`scanner-capability-real-clamd.log`). Candidate/package tests will
exercise this final scanner change again. No failures were hidden or assertions
removed to obtain these results.

## Historical verification records

# Verification results — 19 October 2026

## Custom engine pass — revision 0.1.0-7, local verification complete

Changes are based on main 98e6eb01872af16d5385e90e72c633362b32550e. CEF
7977 commit 8a0b5b99fd4aac7e353f847685be05577298970c and Chromium
152.0.7977.169 commit 92a6f15143569cf59b340472d0b5030465d95722 are
acquired in a dedicated native Linux workspace. Every pinned Git dependency is
verified after gclient sync. All 115 CEF upstream patches applied without a
failed hunk. Majoris patch applicability/reversal and corruption rejection pass.
Both extension source files pass the actual generated release compiler/flags
syntax check and compile to release objects. The supported minimal `libcef`
target linked successfully with CFI/ThinLTO. The first build stopped in CEF's
unrelated GTK3 sample client because its GTK headers were unavailable; using
the supported minimal-only runtime target reused compiled objects and avoided
that sample dependency. SDK and runtime qualification are recorded separately
below, alongside production release gates.

The prepared custom SDK is Chromium 152.0.7977.169. Its minimal archive SHA-256
is `87061e4b0b2167a601d3e5940756df04fb1603e0dbff6a59d7a16e8e1ec8a590`;
libcef.so SHA-256 is
`2fcd59cc438bbbfc7620f4a7bb6ff52d6752b454e0a0889ca549f75d6e0942fe`.
All seven Majoris extension symbols are exported. SDK provenance, actual source
diff digests and extension-file hashes are recorded in `majoris-runtime.json`;
`build-engine-reference/custom-sdk-final-audit.json` confirms the runtime header
version and library match. Build provenance alone does not certify runtime
behavior. Unqualified open-codec SDKs also require explicit development-package
opt-in; the opt-in does not mutate qualification or approval fields.

The first acquisition filled WSL's 16 GiB `/tmp` tmpfs, causing 11 later
application fixtures to fail. The source was moved to disk-backed Linux storage,
temporary space recovered, and the unchanged full standard suite passed 25/25.
The driver now rejects RAM-backed workspaces. Interrupted empty dependency
repositories were subsequently repaired with forced sync and exact revision
checks. Pinned depot_tools bootstrap and Chromium's pinned sysroot resolve the
initial Python/CUPS project-generation failures. Failed logs are retained.

Fresh standard-SDK build `build-clean-custom-engine-final` passed 25/25 before
the two new groups were added. Targeted history, AX/AT-SPI, native PiP fallback
and context-menu tests pass after the integrations. The AX fixture now waits
for its actual button tree before testing actions, avoiding an observed early
document-only snapshot race; its original deadlines remain. The new required
set is 27 groups. The full final standard/custom and package results below
come from actual execution, separately from these earlier targeted checks.

The first 27-group run passed 25 groups, with exit and permissions timing out.
Diagnostics reproduced a shutdown race: CEF could queue the last closed event
before decrementing the live-view count, leaving GTK blocked in shutdown with
no wakeup. The bridge now publishes the count first and wakes the GLib context.
Five repetitions each of exit and permissions then passed (10/10), with the
original deadlines and assertions. Logs: `stock-27.log`,
`stock-focused-rebuilt.log`, `exit-permissions-repeat.log`, and
`shutdown-fix-repeat.log`. The subsequent fresh build
`build-clean-engine-stock-final` passed all 27 groups, zero failures/skips,
including the corrected shutdown and strengthened media assertions. Its log is
`build-engine-reference/stock-final.log`.

Original synthetic H.264, AAC and combined MP4 fixtures were generated with a
disposable extracted Debian FFmpeg toolchain; no host package was installed.
Their CC0 provenance/digests are `build-engine-reference/media/provenance.json`.
The app never invokes FFmpeg for playback. Actual custom-runtime decoding is
verified by `custom-27.log`: H.264, AAC and combined MP4 playback all return
true in browser and installed-app contexts, alongside VP8/VP9/Opus. These
assertions require decoded frames and nonzero audio samples, with missing
proprietary decoders also failing the test.

That first custom run passed 25/27. History correctly exposed an integration
bug: Chromium's unused controller contains one initial placeholder, not zero
entries. The source guard now requires exactly that untouched initial entry
and no pending navigation. Native PiP's first trusted click raced layout in
the faster custom runtime; the fixture now waits for two actual animation
frames and explicitly focuses the surface. `pip-custom-focused.log` then
passes all three browser/app/private contexts, with advancing native pixels,
resize/close, WM_CLASS identity, navigation/crash/source cleanup and selected
second-video/stale-context checks. `ax-custom-required.log` passes required
custom activation, Unicode AT-SPI editing, native selection and protected write
refusal. These tests require actual custom AX metadata when capability is
advertised, preventing a silent fallback pass.

The final fresh custom build, `build-clean-engine-custom-final`, passed all
27 groups with zero failures/skips (`build-engine-reference/custom-final.log`).
It uses the corrected SDK/archive hashes above. Media, native PiP and required
AX/AT-SPI actions passed again on that exact binary. History additionally
verifies selected-entry restoration, back/forward, no URL replay, private
exclusion, profile/version mismatch and malformed serialized-entry fallback.

An additional abrupt-crash fixture persists a native checkpoint, SIGKILLs only
its disposable process group (including CEF children), and restores from the
same persistent profile without clean shutdown. Both custom and standard URL
fallback runs pass (`history-crash-runtime.log`, `history-crash-stock.log`).
The stricter task check requires custom renderer PID/network/root fields and
confirms the PID exists under `/proc`; its idle sample was PID 398, 0 bytes/s,
root task 6 (`task-metrics-runtime.log`), followed by the real task-kill test.

The custom Debian development package build passed all 27 required groups,
zero failures/skips (`custom-package.log`). The archive is
`build-packages-custom-engine-7/majoris-browser_0.1.0-7_amd64.deb`, 264002800
bytes, SHA-256
`f05869aa0381090c0a921b0a1ea07243ca996671a43b77a02dc1a3fed916a587`.
`custom-deb-verify.log` passes archive ownership, sandbox mode, resources,
installed search paths, custom libcef digest and Majoris engine license checks,
and actual extracted GTK/CEF browser/installed-app smoke. No system install was
performed. The additional crash fixture changed tests only after that package
source snapshot; application/engine sources and the verified binary are the
same. Runtime results are separate from immutable build-time approval fields;
development opt-in does not approve production distribution.

Current logs are under `build-engine-reference/`: `acquire-verified.log`,
`apply-final.log`, `extension-syntax.log`, `engine-build-final.log`,
`patch-tests.log`, `app-final.log`, `ax-fixture-test.log`, `editable-tests.log`
and `pip-tests.log`. The active upstream compilation log is in the dedicated
engine workspace. Final logs include `engine-history-build.log`,
`sdk-history-prepare.log`, `custom-final.log`, `custom-package.log`,
`custom-deb-verify.log` and `history-crash-runtime.log`. Reference archive
identity and file mapping are checked in
at `engine/manifests/brave-reference.json`; the current publisher audit is
`build-engine-reference/engine-audit-current.json`.

The target Majoris desktop/accounts are unavailable by the user's confirmation.
Wayland, actual dock grouping, Orca, Google Sheets/provider accounts and system
installation are unverified. Codec redistribution and production readiness are
not approved.

## Production-readiness pass — revision 0.1.0-6

Reviewed clean main 82684a8c265def0cd06d34d75272cb8e5076ce99, matched origin/main before modification. The selected runtime remains CEF 152.0.14 / Chromium 152.0.7977.167. Current audit: build/production-engine-audit.json; all ten CNA records: build/production-cve-assessment.json; exact CEF and Chromium maintenance source evidence and V8 mappings are recorded alongside the security assessment. Production is not approved.

Targeted download-scanner, real-download, Web Risk and platform regressions passed. Scanner tests cover clean/detected/unavailable/error, multi-chunk streaming, input bounds, symlink/FIFO refusal, path replacement during scan, deadline/cancellation/recovery and no file deletion. Production download-service tests cover pending/open guard, threat blocking, removal cancellation and no resurrection. A separate extracted Debian clamd 1.4.3 daemon reported clean and a harmless original test-signature match via the production adapter, then terminated; only a custom test database was used. No host packages/services were installed. Production signature coverage/freshness is not qualified.

Web Risk fixtures now verify managed bearer credentials isolated from direct keys, provider-bound consent (including mode/endpoint changes), explicit initial/active/auth-error/quota/timeout/missing-key states, expired cache and concurrent normal/app requests. No production endpoint or credentials were supplied. Fullscreen video entry/exit is now asserted rather than only printed. All previous native isolation, media, accessibility and GTK suites remain required. Final clean-source, Debian and extracted-runtime outcomes are appended after execution; no manual account/desktop/system-install passes are claimed.

Final clean snapshot: build-clean-production-qualified/source; output: build-clean-production-qualified/output. The initial fresh-source run completed compilation but reported a media-fixture timeout (24/25), retained in build/production-clean-qualified.log. With unchanged source and assertions, the isolated media test passed three consecutive runs (build/production-media-repeat.log), then the complete fresh-source suite passed **25/25**, no failures/skips/timeouts (build/production-clean-rerun.log). The transient timeout's cause is unproven; no timeout was increased, assertion removed or test skipped. Retain this reliability observation for further release qualification.

The final Debian source build passed the exact **25/25** required set (build/production-package-qualified.log). The checked-in optional real-clamd runner also passed against the final clean-built binary (build/production-real-clamd-final.log), using an extracted Debian daemon and a harmless custom signature only. Every current implementation file matches the tested snapshot; only final documentation prose changed afterward. AppStream/desktop metadata and git diff --check passed. Earlier build-packages-production-final/release directories are preliminary and superseded by build-packages-production-qualified.

Final archive verification and extracted GTK/CEF smoke passed (build/production-deb-runtime.log): ownership, mode-4755 sandbox helper, resources/notices, installed library paths, installed-app identities and storage restart. This is extraction/runtime qualification, not system installation/upgrade.

Retained development artifact: build-packages-production-qualified/majoris-browser_0.1.0-6_amd64.deb, **251,296,060 bytes**, SHA-256 **73fffb51489a271f5fc42477cb400e201d233b6339272c17288e5d2b4b181709**. The directory includes debug symbols, buildinfo/changes, SHA256SUMS, packaged-file RUNTIME-SHA256SUMS, clean source-input manifest/revision, engine/CVE/patch/V8 records, real-scanner and metadata evidence, and RELEASE-BLOCKED.txt. Both engine archive digests match the pins. The final publisher recheck still offers the same supported M152 artifact (build/production-engine-audit-release.json).

No live managed deployment/account, maintained official scanner-signature service, licensed H.264/AAC runtime, CDM, real Sheets/Excel/Outlook account, native Majoris/Wayland/Orca or system installation/upgrade was qualified. Optional upstream limits remain explicit. Production distribution is blocked.


## Final security and compatibility pass (revision 0.1.0-5)

Starting clean source 97812b08d82270f6d5ad4e343c69f5108622309c matched origin/main. The explicit CEF 152.0.14 / Chromium 152.0.7977.167 SDK, SHA-256 and official availability were rechecked in build/final-security-engine-audit.json. All ten authoritative CNA records were refreshed into build/final-security-cve-assessment.json. No suitable fixed supported replacement was established; production remains blocked.

The new required web-risk-provider test uses the actual adapter with disposable HTTPS and Secret Service. It covers key save/lookup/removal, malware/phishing/unwanted/no-match, malformed and future-type responses, embedded-NUL/64 KiB rejection, 403/429/503 failures, no redirects, a separate untrusted TLS endpoint, process rate limiting and queued recovery, cancellation/timeout, query-aware cache keys, fragment removal, embedded-credential refusal, cached attribution, disabled and missing-key states. No live API/key/account is used. Ordinary rapid redirects queue within a 1.5-second bound rather than failing immediately; cancellation removes the queued callback and provider backoff also applies to queued work.

Final source snapshot: build-clean-security-release/source, output: build-clean-security-release/output. All **24/24** required suites passed with zero failures, skips or timeouts (build/final-security-clean-release.log). The Debian build passed the same exact **24/24** gate (build/final-security-package-release.log). Archive ownership, root-owned mode-4755 sandbox helper, resources/notices, installed library paths and extracted GTK/CEF smoke passed (build/final-security-deb-runtime.log). AppStream/desktop metadata validation and git diff --check passed. Every implementation file was compared with the tested snapshot; only final documentation prose changed afterward.

Final artifacts are in build-packages-security-release/: majoris-browser_0.1.0-5_amd64.deb, **251,274,432 bytes**, SHA-256 **d1c2b6c3201694d125b154cad0291efbcf9d0f148cfc71ec5b1829eb6ccee35b**; debug package, buildinfo/changes, SHA256SUMS, source-input manifest/revision, refreshed engine/CVE records and RELEASE-BLOCKED notice. Both SDK archive digests match their pins. The preliminary build-packages-security-final directory is explicitly superseded; it predates the final queue/backoff changes. The final package remains a development artifact, not production approval.

The download enum appends no-known-file-threat without changing older stored integer values; roundtrip coverage verifies it, but no URL verdict assigns it to a file. Native cancelled-result handling suppresses stale warnings. Additional domain cases distinguish Sheets from Docs/Slides and Excel sections from Word/Outlook, preserving explicit root/custom/manifest/legacy behavior. Existing native popup/auth and app identity/storage suites remain mandatory.

Earlier revision-4 artifacts below are historical and do not contain this adapter. No system installation/upgrade, real Sheets account, Majoris dock, native Wayland, Orca, licensed H.264/AAC playback or Widevine service qualification has been performed. These remain explicit gates.

## Remaining-feature implementation (revision 0.1.0-4)

Starting source `ff562f916110e9744d6d09b20c95984a2b5c92c7` was clean and matched origin/main (`git ls-remote` through the Linux environment). New source preserves the architecture and all 20 previous suites, adding three required groups. Workspace and final fresh-source runs both passed **23/23**, no failures/skips (`build/remaining-all-tests.log`, `build/remaining-clean-final.log`). Final source is `build-clean-remaining-final/source`, build output `build-clean-remaining-final/output`.

The Debian build also passed the exact **23/23** gate (`build/remaining-package-final.log`). Artifacts are in `build-packages-remaining-final/`: main package `majoris-browser_0.1.0-4_amd64.deb` (251,282,540 bytes), debug symbols, buildinfo/changes, checksums, source-snapshot manifest, engine/CVE audit records and explicit RELEASE-BLOCKED notice. Main SHA-256: `38ad3ed3a134332f4f3104925f041b24adbf6fe2f5d480c7558fdeec52c51d92`.

Archive ownership, sandbox mode, runtime resources/notices, installed search paths and extracted GTK/CEF smoke passed (`build/remaining-deb-runtime.log`), including both installed-app identities and storage restarts. AppStream/desktop-file validation passed (`build/remaining-metadata.log`), and `git diff --check` passed. No system installation/upgrade was performed. Only documentation was updated after the final compiled source snapshot; prior revision-3 artifacts are superseded. This is a development qualification, not production release approval.

- `threat-protection`: deterministic local provider verdicts, no-known-threat versus unknown, configured outage, independent timeout, pre-cancelled/active cancellation, per-context cache/closure clearing and query/fragment minimisation. GLib cancellation initially exposed an unchecked async error; the async contract now propagates errors and callers refuse cancelled navigation.
- `cef-threat-navigation`: protection enabled at initial view construction; real allowed HTTP load followed by a redirect to a phishing fixture. Server records prove the dangerous destination was never fetched. No live paid/reputation service is used.
- `cef-media-playback`: original MediaRecorder-generated VP8/VP9/Opus WebM is decoded in separate Browser/app contexts. Both report advancing playback, decoded video frames and nonzero decoded Opus samples. H.264, AAC and combined MP4 report blocked because the current decoder is unavailable; no successful proprietary playback claim is made.
- Domain fixtures add section fallback, unrelated paths, dot/encoded separator/port rejection, preservation of valid wide manifest scope, old metadata/identity and SQLite scope_source persistence. GTK smoke exercises the expanded install dialog and both independent app identities/storage restarts. Download fixtures verify persisted malicious/policy assessments cannot be opened, while normal unassessed completion retains explicit caution.
- Platform runtime logs show HTML fullscreen enter/exit (1 then 0), while the pre-existing certificate/sandbox/Wasm/WSS/WebRTC/UA/permission/storage tests remain. Physical output, GPU decoding, hardware capture and actual target-desktop fullscreen/Wayland remain separate qualification.

Engine provenance/index is `build/remaining-engine-audit.json`; the available stable pin is unchanged. security-assessment.md enumerates the ten unresolved newer fixes, without assuming Windows/Mac advisory wording settles Linux applicability. codec-runtime.md records the inactive GN template, external authorised SDK path and mandatory playback assets for a future codec-capable build. No API key, paid provider, codec implementation or CDM is shipped. No account credentials or real Sheets sign-in were used.

## Latest hardening pass

Both fresh-source hardening builds passed 20/20 suites, with no failures or skips (`build/final-hardening-clean.log`, then the final source snapshot in `build/final-hardening-clean-final.log`). Targeted production-service/GTK checks also passed (`build/final-hardening-regressions.log`). Earlier revision-2 artifacts do not include this work.

Final source is `build-clean-hardening-final/source`, output `build-clean-hardening-final/output`. The native-Linux Debian build passed its exact 20/20 gate (`build/final-hardening-package.log`). The development artifacts in `build-packages-hardening-final/` include:

- `majoris-browser_0.1.0-3_amd64.deb`, 251,251,516 bytes; SHA-256 `44457ed07bc92d43da36cf45be3fd2be318dbd120da6d2df0f21f2cc95ea0644`.
- Debug symbols, `.buildinfo`, `.changes`, artifact `SHA256SUMS`, frozen-source `SOURCE-SHA256SUMS` and `SOURCE-REVISION.txt`. Base Git revision is `cfa4952b3e2112abdbfe92c4495fb393d67b7ca3` plus this uncommitted worktree implementation.

Archive ownership, mode-4755 sandbox, resources/notices, installed ELF lookup and extracted GTK/CEF tests passed (`build/final-hardening-deb-runtime.log`), including both application identities and storage restarts. Desktop-file/AppStream validation passed (`build/final-hardening-metadata.log`), as did `git diff --check`. No system installation or upgrade was performed. Only documentation of these results was added after the tested source snapshot.

**Release blocked:** the [15 October Chrome advisory](https://chromereleases.googleblog.com/2026/10/extended-stable-update-for-desktop_01598036246.html) announces newer `.169` security fixes. The CEF Linux publisher index checked in this pass still lists `.167` as its newest M152 stable artifact. Linux applicability/backports and a fixed production CEF SDK are unresolved; a beta or unsupported branch was not substituted. Read security-maintenance.md. The artifact is for development qualification, not approved distribution.

New executed assertions include normal/private streamed downloads with wrong-context cancel/remove/retry refusal, session-scoped clear-completed, last-private-view cleanup, persistent-record reload and retained file bytes; trusted username-first fill/submit followed by a password step with no visible username; actual non-atomic editable AX descendants, multiline Japanese/emoji text and suppressed protected values; two generated launchers/icons and concurrent distinct X11 identities, followed by separate app-process restarts and retained owner-specific storage.

The platform fixture performs real Wasm execution (42), a WSS frame exchange, local WebRTC data-channel negotiation/message delivery, contenteditable, foreign-frame SOP denial, file URL fetch denial and absence of the isolated native binding from page JavaScript. It then terminates the renderer and rejects a separate untrusted TLS endpoint, asserting certificate failure metadata. Its runner observes renderer `Seccomp: 2` and `NoNewPrivs: 1` and refuses unsafe sandbox/web-security switches. The actual capability report was:

```json
{"wasm":true,"websocket":true,"rtc":true,"fileDenied":true,"sop":true,"edit":true,"nativeHidden":true,"codecs":{"vp8":"probably","vp9":"probably","h264":"","opus":"probably","aac":""},"widevine":false}
```

Codec results are Chromium capability queries, not playback certification for arbitrary media. Running/suspended WebAudio and silent canvas-video playback are also exercised. H.264/AAC and Widevine are unavailable in this build; HTTP/2/3 negotiation, physical camera/microphone capture and provider media/DRM remain unverified. Existing storage/notification/drag suites cover workers, IndexedDB, Cache Storage, restart, notification delivery, actual clipboard/input and inbound local files. Native upload-dialog and full-screen desktop UX still require manual qualification.

No maintained URL reputation provider or download malware scanner is configured. Downloads show **not assessed**, software-opening confirmation is implemented, and CEF interruption/security-block/check-failure reasons remain distinct. Risk classification and scoped actions are automated; complete confirmation-dialog UX is not claimed tested. This, the unresolved upstream security delta, full AT interaction and the already-agreed native desktop/account gates prevent a production-ready claim.

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

The user confirmed no Majoris desktop is available. Authenticated Google Sheets/Microsoft, dock/Alt+Tab grouping, two apps on the native Majoris desktop, native Wayland/IME/scaling, Majoris Theme, full Orca/braille interaction, PolicyKit/locked-keyring UI, physical printer/backend/copies/ranges, PDF-viewer print UI and real system installation/upgrade remain unverified. Complex AX transforms/cross-frame character geometry and direct AX action/edit dispatch are not claimed. Audio activity is not sample-accurate silence detection. PiP is a verified CEF Alloy OSR limitation, not an untested promise.

See `implementation-status.md` for the complete implemented/tested, unverified, partial, upstream-limited and intentionally unimplemented matrix. Do not interpret fixture success as production readiness.

## Previous revision 0.1.0-2 build and package record (superseded by the latest hardening pass)

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
