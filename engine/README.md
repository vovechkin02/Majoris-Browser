> **Current release-hardening record (0.1.0-8):** [../docs/release-hardening.md](../docs/release-hardening.md). Reviewed source: `27611aa41c806398fb0560aded3853a2a9ba53ec`. The security candidate retains four Majoris patches and adds twelve patches covering thirteen upstream maintenance/security commits. The candidate build, clean 30/30, Debian 30/30 and extracted-runtime verification passed locally. Production, redistribution and native-desktop approval remain pending. Earlier dated completion claims below are historical and do not qualify this candidate.

## Current security candidate workflow

Use `--manifest engine/manifests/m152-security-candidate.json` for **every** stage
(acquire, patch, build, sdk), with the same `--development-codecs` and
`--build-jobs 16` configuration. Use a new native, disk-backed Linux workspace
for a different branch or incompatible patch set. The candidate retains the
four original Majoris patches and adds twelve patches covering thirteen upstream
maintenance/security commits, including the separately pinned V8 dependency.
It is Chromium .169 plus recorded backports, not an official .170 release.

The driver validates every selected patch hash and refuses to silently drop
applied patches from the workspace receipt. Workflow adaptations use immutable
content-addressed filenames. If explicitly reversing a patch set, review and
verify the resulting source before discarding its receipt; normal updates use
a fresh workspace. Never reuse a success receipt after changing source/config.

After building and preparing the SDK, run the existing online audit, the exact
patch applicability/corruption tests with `--manifest`, the clean 30-group app
suite with real media fixtures, and the Debian build/extracted-package verifier.
Regenerate `license-inventory.py` against the matching source and SDK. Create a
separate draft through `release-record.py`; compilation never grants approval.
Read [release hardening](../docs/release-hardening.md) for channel gates and
[desktop qualification](../docs/target-desktop-qualification.md) for target tests.
Recheck advisories and branch deltas at release time, with a dated authorised
security review. New applicable uncovered fixes block distribution. Production
installations do not download or promote unqualified engine revisions.

## Historical baseline workflow

# Majoris custom CEF runtime

This is a source-build integration, separate from the standard SDK bootstrap.
The manifest pins CEF 7977 and the complete Chromium 152.0.7977.169 security
maintenance revision. It does not cherry-pick a guessed subset of fixes.
Source selection does not qualify the resulting binary for release.

Use native, disk-backed Linux storage. `/tmp` on this development machine is a
16 GiB tmpfs and cannot hold Chromium. Allow approximately 500 GiB free disk
space for a complete release build. The driver rejects RAM-backed storage and
Windows-mounted workspaces, pins depot_tools and authenticates automate-git.py
with SHA-256. Chromium DEPS pins compiler, Rust, sysroot and Siso dependencies.
Network access is needed for the upstream Git/CIPD/GCS downloads.

```sh
python3 engine/scripts/build.py --workspace /home/administrator/majoris-engine-m152-codecs --stage acquire --development-codecs --build-jobs 12
python3 engine/scripts/build.py --workspace /home/administrator/majoris-engine-m152-codecs --stage patch --development-codecs --build-jobs 12
python3 engine/scripts/build.py --workspace /home/administrator/majoris-engine-m152-codecs --stage build --development-codecs --build-jobs 12
python3 engine/scripts/build.py --workspace /home/administrator/majoris-engine-m152-codecs --stage sdk --development-codecs --build-jobs 12
```

For an open-codec build, omit `--development-codecs` throughout and use a
different workspace. Codec mode is part of workspace identity. No stage runs
implicitly during Meson configuration. A failed command stops the pipeline.
Acquisition always completes dependency sync and hooks after an interrupted
download; an existing main Git checkout alone is insufficient.

The supported CEF workflow is retained. The recorded workflow adapter limits
dependency sync to four jobs and compilation to the explicit `--build-jobs`
count (default eight), and removes CEF automate's
floating `siso_version=latest` override so Chromium DEPS controls Siso. Release
CFI and ThinLTO remain enabled. PGO is disabled for the development build, which
does not download training profiles. No sandbox or web security bypass is used.
The supported `--build-target=libcef --minimal-distrib-only` workflow builds the
runtime and Linux sandbox helper without CEF's unrelated GTK3 sample client.

The SDK stage requires a successful build receipt for the exact manifest,
patches, workflow digest and GN flags. It hashes the SDK archive and reuses
`scripts/bootstrap-cef.py --local-archive ... --sha256 ...` to extract resources
and build the CEF wrapper. Pass that prepared SDK to existing Meson and Debian
workflows using `-Dcef_root=...` or `CEF_ROOT=...` respectively. Its
`majoris-runtime.json` is installed beside libcef.so. Codec development packages
require `MAJORIS_DEVELOPMENT_ENGINE=1` while runtime/security qualification or
codec redistribution approval is incomplete. This setting establishes neither
qualification nor distribution rights, including for open-codec builds.

## Patch ownership and reference

The supplied Brave archive identifies commit
`dcbdb34da3fd9339b39428b370ed4cc07a18580a`, Brave 1.99.9, Chromium
155.0.8059.30. It is a reference, not a compatible drop-in CEF source tree.
The following files were inspected directly from that archive:

* `docs/best-practices/chromium-src-overrides.md`: isolate small modifications.
* `build/args/blink_platform_defaults.gni`, lines 12–13: native proprietary
  codecs and Chrome FFmpeg branding. Majoris enables these only in its explicit
  development codec configuration, without external decoders or UA spoofing.
* `browser/ui/views/overlay/brave_video_overlay_window_views.{cc,h}`:
  Chromium's native overlay with Linux WM_CLASS and Wayland application ID.
* `chromium_src/chrome/browser/ui/views/overlay/video_overlay_window_views.cc`
  and `patches/chrome-browser-ui-views-overlay-video_overlay_window_views.cc.patch`:
  targeted factory customization, without replacing the video/controller stack.

Brave reference files retain their MPL-2.0 notices in the supplied archive.
Majoris implements the small adaptations independently; it does not copy
Brave's UI, Leo controls, profiles, services or telemetry.

| Patch | Purpose and source | Assumptions and regression checks |
| --- | --- | --- |
| 0001 | CEF `alloy_browser_host_impl.cc`, `BUILD.gn`, new `majoris_runtime.cc` and `majoris_history.cc`: native Linux video PiP and versioned extension ABI | Pinned CEF/Chromium; real display, headless refused; native surface/controller lifecycle; AX tree/frame/document ownership; standard SDK has no extension symbols |
| 0002 | Chromium `video_overlay_window_views.cc`: Linux overlay identity | Process launcher supplies trusted CHROME_DESKTOP; installed apps run separately; X11 WM_CLASS and Wayland app_id must be checked with browser/app IDs |
| 0003 | CEF `task_manager_impl.cc`: enable native network sampling | Reuse the existing CEF observer; live task IDs, real PID/rate/root IDs; no guessed process hierarchy |
| 0004 | CEF `osr_platform_delegate.cc`: retain authoritative AX updates for validated actions | Per-WebContents and document-scoped bounded AX cache; live frame/tree/document/node validation before dispatch |

PiP uses Chromium's existing `PictureInPictureWindowManager`,
`VideoPictureInPictureWindowController` and `VideoOverlayWindowViews`, including
native resize, drag, close and surface lifetime. The GTK media menu resolves its
hit-tested video rather than choosing the first element. The global action
accepts one unambiguous playing video. Runtime support comes from the loaded
versioned extension symbol, not application build flags or codec declarations.
The .169 custom runtime passed native X11 lifecycle/pixel/identity tests in
browser, installed-app and private contexts; target Wayland/dock checks remain
unverified. See the application verification records for exact SDK hashes.

AX operations use Chromium `AccessibilityPerformAction`, with a browser-owned
active live frame, safely parsed tree ID, document token and extant node.
Protected fields permit focus only. Only default action, focus, bounded value and
same-node selection are accepted. A dispatch result is not page acceptance.
The bridge carries document tokens in AX updates. GTK exposes public widget
actions and EditableText operations backed by Chromium actions. GTK 4.18 does
not implement direct AT-SPI Text selection setters; the exposed select-all
action dispatches native selection. Real Orca qualification remains pending.

## Upgrade and qualification

Update the manifest only after reviewing the CEF compatibility commit and the
complete Chromium maintenance release. Fetch the exact affected upstream files,
then run `engine/scripts/prepare-patches.py --snapshots DIRECTORY` to regenerate
patches and SHA-256 entries. Review every diff; never accept an automatic fuzzy
patch. The normal patch stage checks checksums and `git apply --check`, permits
an already-applied exact patch, and otherwise fails. After any source or GN
change, rebuild and regenerate SDK provenance; old build receipts are rejected.

Run the 27 application suites against both SDKs, then Debian package
and extracted-package checks. The platform suite must reject a failed PiP
operation when the runtime advertises support and must continue task/security
checks after successful PiP entry/exit. Media qualification requires actual
H.264 video frames, AAC audio samples and combined MP4 playback in browser and
installed-app contexts; MIME support is insufficient. Test PiP close, source
navigation, source/tab/window destruction, renderer crash, private sessions,
fullscreen and a second video/app, in addition to entry/exit and native identity.
For the development codec build, set `MAJORIS_EXPECT_PROPRIETARY_CODECS=1`
alongside `MAJORIS_MEDIA_FIXTURES` so missing decoders also fail qualification.

Do not mark `security_qualified`, `runtime_verified` or
`redistribution_approved` true merely because compilation succeeds. Record
codec fixture provenance and runtime logs, examine all security updates, and
complete target Wayland, dock, Orca and real-account web-app checks. The user
has confirmed the target desktop is unavailable; those checks remain unverified.
Full navigation-entry persistence uses Chromium's navigation controller with
bounded serialized navigation entries and PageState. Private, unsafe POST/file
state, incompatible versions and profile mismatches fall back to URL snapshots.
Only the selected entry is loaded during restoration.

The application verification records contain fresh standard/custom 27/27,
Debian 27/27 and extracted-package results, plus abrupt-crash history tests.
SDK metadata is immutable build-time provenance; local test results are
recorded separately and do not promote its approval fields automatically.
