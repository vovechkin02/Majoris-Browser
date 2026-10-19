# Release hardening — revision 0.1.0-8

Reviewed Git revision: `27611aa41c806398fb0560aded3853a2a9ba53ec`.
Application version remains 0.1.0; Debian development revision is 0.1.0-8.
This document supersedes historical matrices. No production approval, legal
authorisation, live backend deployment or target-desktop result is invented.

## Engine and security

The existing CEF 152.0.14 / branch 7977 implementation is retained. Base Chromium
is 152.0.7977.169, commit `92a6f15143569cf59b340472d0b5030465d95722`;
CEF commit is `8a0b5b99fd4aac7e353f847685be05577298970c`.
The 19 October read-only audit refreshed the official CEF publisher index and
[M152 maintenance branch](https://chromium.googlesource.com/chromium/src/+log/refs/branch-heads/7977).
The latest published Extended Stable advisory reviewed remains
[15 October .169](https://chromereleases.googleblog.com/2026/10/extended-stable-update-for-desktop_01598036246.html),
but branch source contains newer fixes. The earlier unbackported .169 runtime
is therefore not a sufficient production approval baseline.

`engine/manifests/m152-security-candidate.json` records exact upstream
maintenance backports, with checksums and original commit metadata. They cover
all non-infrastructure, non-version-number changes after the pinned base in the
reviewed branch log, through `216ce10d728819de5e749383e64f8ad05be8fb61`:

| Upstream commit | Change and applicability |
| --- | --- |
| 4c1a22f32421 | Re-entrant tab-drag lifetime guard; Chrome tab UI is not Majoris OSR UI, retained for complete maintenance coverage |
| e7c08dce2f5d | CacheStorage side-data/code-cache capability remote; shared storage infrastructure |
| 941d83b5c799 | Restore GL context/surface after WrappedSkImageBacking MakeCurrent; shared GPU infrastructure |
| 65d30132e95a | Obtain canvas/state after style resolution; shared Blink re-entrancy/lifetime fix |
| cf67ca600794 | Validate serialized FSA root/relative paths before transfer-token creation; shared content permission/path boundary |
| df33b44103b2 | AppWindow lifetime UAF fixes; Chrome AppWindow is not Majoris installed-web-app architecture, retained nevertheless |
| 216ce10d7288 | Reading-mode distilled-content HTML options; Chrome side panel is not Majoris UI, retained nevertheless |

The excluded `41f19b594e66c1bf7459b1dcf15cf419a32ad859` only increments the
upstream version to .170; `4653b241fa939659e78128901b6e90a286feb16f` changes
infrastructure builders. No unpublished official .170 release is claimed.
The candidate is `.169` plus the explicitly recorded maintenance patches.
A separate review of the current Linux Stable advisory found five additional
CVE entries beyond the Extended advisory. The candidate now includes five
additional patches covering these shared-code fixes:

| CVE | Source assessment and action |
| --- | --- |
| CVE-2026-110914 / Workers | Combine upstream `fbb64b8bbf07` null-safe worker access and `e98f6e2e4f23` CSP-sandbox handle removal; adapt only M152 include/test-tail context |
| CVE-2026-110917 / SVG | Exact upstream `66e6798303a4` iterator relookup after resource-cycle reentrancy |
| CVE-2026-110915 / Compositing | Backport `4d2451fed3a8` 64-bit shader IDs and split uint32 serialization; add the absent M152 writer overload rather than copying M155's unsafe direct uint64 writer |
| CVE-2026-110920 / V8 | Exact upstream `f308dfd569db` generator creation write/deoptimization flags and frame state; pinned V8 `e51a6bf02e52f3dec9fee502db2594c0f5f51b37` has the affected eliminatable operator |
| CVE-2026-110916 / Desktop | Exact upstream `6911bb69b1cf` / review `8446599` rejects invalid/non-HTTP Calendar event and attachment URLs. Conservatively included because the browser context permits internal schemes, despite Majoris not exposing the normal Calendar UI |

The primary [15 October Linux Stable advisory](https://chromereleases.googleblog.com/2026/10/stable-channel-update-for-desktop_01886704284.html)
and linked upstream commit/Chrome CNA records informed this review. The earlier
seven-backport and fifteen-patch candidates were stopped before qualification;
neither is presented as current security-complete. All sixteen final patches passed exact applicability,
reversal and corruption rejection. V8 dependency HEAD and source diff are now
separately checked and recorded, as it is a nested Git repository.

Original Majoris patches, sandbox, TLS/origin/permission boundaries, CFI and
ThinLTO are preserved. No production bypass switches or automatic update path
are added. The final candidate compiled and linked, passed all three upstream V8
regressions, clean 30/30 application groups and Debian 30/30, followed by
archive/inventory/extracted-runtime verification. Exact hashes and retained
evidence are in verification-results.md. These local passes grant no approval.

The existing audit now records current Chromium and CEF branch commits and
uncovered deltas. CEF branch 7977 currently matches pinned commit
`8a0b5b99fd4aac7e353f847685be05577298970c`; no additional CEF maintenance
change was found in that branch review.
Repeat this review at release time. New uncovered applicable fixes block release.
Use the existing build driver with `--manifest` for the candidate; no second
engine updater or background production download is introduced.

## Implemented repository changes

Scanner availability uses bounded real VERSIONCOMMANDS/INSTREAM capability
probes, independently of scanner-object existence. Downloads displays not
configured/not found/inactive/unavailable/available/outdated states and a manual
health check; it refreshes health while open. Scan is absent until operational
health; Scanning offers Cancel and blocks Open. Every scan rechecks health.
Unavailable scans retain records, and pending state starts before the async
health check. Shutdown cancels probes/scans and suppresses late writes.

The default file limit remains 64 MiB, configurable in Settings from 1–1024 MiB.
The operator must keep it within daemon stream/file/scan/time policy. INSTREAM
does not expose all daemon resource settings. Configure HeuristicAlerts and
AlertExceedsMax so skipped/limited scans cannot silently become clean results;
limit-exceeded heuristic replies are reported as incomplete assessments rather
than clean or proven malware. Symlink, special-file, replacement, modification,
protocol, timeout and cancellation protections remain. No user files are deleted.
Database dates are advisory; more than seven reported days is a warning, and
unknown dates remain unknown, not current-signature proof.

`services/threat-protection/` is a separate optional deployment component using
the existing Browser contract. It supplies token authentication/revocation,
bounded quotas/concurrency, input validation, fixed-provider HTTPS lookup,
normalised verdicts, failure/backoff handling and recent-success health.
URLs/tokens are not logged or persistently cached. It is not deployed and
refuses default configuration without operator provider-use authorisation.
Read its README for TLS, provisioning/rotation, monitoring, licensing/privacy
and multi-replica quota requirements. Browser consent remains endpoint-bound;
Disabled, Not Configured, Active, Temporarily Unavailable and Service Error are
distinct from merely having an adapter installed. An unavailable credential
store reports Temporarily Unavailable; a confirmed absent key reports Not
Configured. Disabled adapters do not imply active protection.

The native bridge rejects lower Chromium profile versions and invalid/symlinked
version markers before CEF starts; it preserves profiles instead of resetting
them. Chromium's own Last Version marker protects older profiles where present.
Existing browser/app identities, scopes and SQLite schema remain unchanged.
The OS must prevent rollback to pre-guard binaries: they cannot retroactively
enforce this marker. Equal-version maintenance fixes do not imply a new profile
format or supported rollback to an older security baseline.
GTK's actual display backend selects CEF Ozone X11 or Wayland. Fractional scale
is retained at initial readiness; touchpad surface deltas and wheel ticks are
handled separately with fractional accumulation. Monitor geometry comes from
GDK, with enter/leave monitor updates. GTK does not provide arbitrary global
Wayland window coordinates/work-area policy; none is fabricated or bypassed.

## Release records and redistribution

`engine/scripts/release-record.py draft --sdk SDK --record RECORD` creates a
separate unapproved development record; it never overwrites a record or grants
approval. The identity binds application source hash/revision, root licence/checkout rules, CEF/Chromium
commits, patch hashes, GN configuration, toolchain and runtime/provenance hashes.
The SDK also inventories every packaged runtime library, snapshot, resource and
notice. Verification rejects changed, missing or unexpected SDK resources; the
extracted-package verifier checks installed bytes against that inventory. Legacy
development SDKs without it cannot qualify a release record.
SDK generation now records actual Clang version/binary hash, sysroot manifest
hash and wrapper compiler. Explicit reviewers, recent security assessment and
hashed runtime evidence, redistribution authorisation and production approval
must be supplied by accountable authorised maintainers. Evidence paths in
the review record are absolute paths on the qualification host; moving evidence
requires updating its location while retaining and rechecking the content hash. The tool checks record
integrity and required entries; it is not a legal entitlement oracle or signature
authority. Reviewers must assess the underlying evidence and authorisation.

Packaging channels are development (default), release-candidate and production.
Set `MAJORIS_RELEASE_CHANNEL` and `MAJORIS_RELEASE_RECORD` for non-development
packaging. Both Debian and Meson enforce the checks. A development opt-in is
forbidden in release-candidate/production channels. Approved-channel packages
include the separate `majoris-release.json`; build provenance is not edited.
Development test success never automatically promotes the artifact.

`engine/releases-license-inventory.json` and the reproducible inventory script
identify generated complete Chromium third-party notices, exact FFmpeg source,
selected decoder/GPL/nonfree flags and notice hashes. See
[codec-runtime.md](codec-runtime.md) for the authorised legal review checklist.
Codec/software copyright licences do not establish applicable patent rights.
No codec/CDM binary is copied from Brave, Chrome or Edge. Redistribution remains
unapproved. EME availability alone does not mean Widevine support; no authorised
CDM was provided, so optional Widevine remains unavailable.

## Target and operator requirements

Use [the target-desktop plan](target-desktop-qualification.md) for actual Debian
installation/upgrade/removal, GNOME Wayland, dock/Alt+Tab/PiP, mixed monitors,
IME, Orca, physical media output and authorised Google Sheets isolation checks.
The desktop/accounts remain unavailable by the user's confirmation. Local
fixtures do not verify Sheets sign-in or native Wayland. Operator deployment
of Web Risk and clamd/freshclam, provider entitlement/billing/privacy review,
codec redistribution authorisation and signed OS release approval are external.
The ISO builder is not in this workspace; no unrelated project was modified.

## Verified development artifacts

The candidate is built from the exact reviewed base plus sixteen patches:
four original Majoris patches and twelve patches covering thirteen upstream
maintenance/security commits. The fresh audit reports no uncovered commits in
the reviewed branch delta and matches the current CEF branch pin. Wayland is
actually compiled in (`ozone_platform_wayland=true`); compositor qualification
remains separate.

Clean application tests: **30/30**. Debian package tests: **30/30**. Archive
ownership/sandbox mode, all 232 SDK input hashes, installed search paths and
extracted GTK/CEF smoke: **PASS**. Direct upstream V8 regressions: **3/3**.
The standard compatibility run passed 30/30; the final scanner/provider changes
also passed focused checks and the complete candidate/package suites.

The development package is `build-packages-hardening-8/majoris-browser_0.1.0-8_amd64.deb`
(264,025,692 bytes), SHA-256
`217cb436b1b2ede520e7500a55c74d204aaf60686042bf83a73afc8b1452636c`.
libcef.so SHA-256:
`d098dd129d1cbfe0b1fb0f7e4b86cfb6b52ccccf8965557591beb9c188174388`.
SDK archive SHA-256:
`fba0c1a1ba992995cc2bb66a4d38856866fdcaf586fbc8ffc5969e93179692ba`.
The Debian buildinfo records GCC 14.2, libc6 2.41-12+deb13u4 and the exact build
dependencies. Native apt installation/upgrade/removal on Majoris is unverified.

The previous working SDK is retained in the native workspace at
`sdk-before-hardening-0.1.0-8`; the earlier-runtime source package is separately
labelled in `build-packages-hardening-source-8`. Neither is silently relabelled
as the final candidate. Read the full evidence and preserved failure/correction
history in [verification-results.md](verification-results.md).

## Current readiness matrix

Classification applies to the stated scope; local fixture/decoding passes do
not establish target-desktop operation, a deployed service or legal authority.

| Component | Classification | Implemented | Verified | Remaining blocker |
| --- | --- | --- | --- | --- |
| Custom Chromium runtime | Complete and verified | Existing engine plus exact maintenance fixes | Build, SDK inventory, clean 30/30 and Debian 30/30 | Formal release approval is separate |
| Chromium security | Implemented but verification pending | Current advisory audit and sixteen-patch candidate | Source checks, CFI/ThinLTO, sandbox/TLS/origin/isolation regressions, V8 3/3 | Authorised security/release assessment; recheck advisories at release |
| H.264 | Complete and verified | Native custom pipeline | Actual browser/app decoded frames | Redistribution and physical/hardware output qualification |
| AAC | Complete and verified | Native custom pipeline | Actual browser/app decoded samples and MP4 | Same separate redistribution/output gates |
| Picture-in-Picture | Implemented but verification pending | Native Chromium overlay | X11 pixels, browser/app/private identity and lifecycle | Native Wayland/compositor/dock qualification |
| Codec redistribution | External dependency | Exact technical inventory and fail-closed release gate | Notices/configuration/hash inventory; unapproved channel rejection | Authorised software/patent/legal decision |
| Managed threat protection | External dependency | Client and separate deployment component | Deterministic client/backend fixtures; consent/auth/quotas/errors | Entitled live deployment, credentials, billing/privacy/operations |
| ClamAV scanning | Complete and verified | Live health, limits, safety, cancellation/shutdown | Protocol fixtures and disposable real clamd 1.4.3 | Optional OS daemon, safe limits and maintained official signatures |
| Download UI | Complete and verified | Live-availability Scan, Cancel and actual results | Real GTK Scan/Cancel/stale/unavailable fixtures | Target theme/desktop qualification |
| Widevine | Intentionally excluded | Honest unsupported state | No DRM support claimed | Optional vendor authorisation, CDM and real service qualification |
| Accessibility | Upstream limitation | Native actions/editing/selection preserved | AX/AT-SPI, Unicode and protected-value checks | GTK 4.18 direct Text setters; actual Orca environment |
| Web-app isolation | Complete and verified | Stable IDs and independent profiles | Browser/app/private lifecycle, storage, credentials and clearing fixtures | Real provider/desktop checks are separate |
| Google Sheets | External dependency | Standalone-app architecture | Local session/isolation fixtures | Authorised account and target desktop; actual sign-in/session test |
| Wayland | Implemented but verification pending | Actual backend, scale, scroll and monitor integration | Compiled Wayland support, source review and X11 regressions | Native GNOME Wayland, IME and mixed-scale monitors |
| Dock integration | Implemented but verification pending | Stable browser/app/PiP desktop IDs | X11 identity fixtures | Actual Majoris dock/Alt+Tab and Wayland app_id |
| Debian packaging | Implemented but verification pending | Explicit channels, resource provenance, upgrade guard | Development build 30/30, archive/hash and extracted smoke | Native fresh install, upgrade/downgrade/removal qualification |
| Production release | External dependency | Explicit approval path; no automatic promotion | Unapproved production/RC and test-skipping paths rejected | Security/redistribution/release approvals and required target qualification |
