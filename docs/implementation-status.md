> **Current release-hardening record (0.1.0-8):** [release-hardening.md](release-hardening.md). Reviewed source: `27611aa41c806398fb0560aded3853a2a9ba53ec`. The security candidate retains four Majoris patches and adds twelve patches covering thirteen upstream maintenance/security commits. The candidate build, clean 30/30, Debian 30/30 and extracted-runtime verification passed locally. Production, redistribution and native-desktop approval remain pending. Earlier dated completion claims below are historical and do not qualify this candidate.

# Current implementation status — 0.1.0-8

The authoritative [17-component classification matrix](release-hardening.md#current-readiness-matrix)
separates implemented code, local verification, upstream limitations and external
release gates. Current source adds scanner health/UI/limits, the optional managed
backend, profile downgrade protection, Wayland backend/scale/scroll/monitor fixes,
exact runtime/resource inventories and explicit release channels. Architecture
and working native engine extensions are preserved. The security candidate now
contains sixteen patches with separate V8 provenance. The candidate build/SDK, clean 30/30 and Debian
30/30 pass, as do archive/inventory/extracted-runtime checks and three direct
V8 regressions. The standard-SDK serial suite also passed 30/30.
Target Wayland/dock/Orca/Sheets and actual system upgrades remain unverified.

## Historical completion matrices

# Completion matrix — 19 October 2026

## Custom engine qualification — revision 0.1.0-7

This matrix supersedes earlier SDK-only assessments. The custom .169 engine
and SDK are built. Fresh standard and custom runtime runs each pass 27/27;
actual codecs, native PiP, AX/AT-SPI actions and history restoration are verified.
Production release approval is separate from these local runtime results.
See [the engine guide](../engine/README.md), [patch maintenance](../engine/PATCH-MAINTENANCE.md)
and [verification records](verification-results.md).

| Feature | Classification | Verified | Remaining issue |
| --- | --- | --- | --- |
| Custom CEF build | Complete and tested | Pinned dependencies, checked patches, CFI/ThinLTO link, SDK/binary provenance; 27/27 custom | Release approval remains separate |
| Chromium security updates | Complete and tested | Complete .169 maintenance source, exact binary/header identity, sandbox/TLS/isolation regressions | Build-time approval flags remain false; production release is not approved |
| H.264 playback | Complete and tested | Actual decoded frames in browser and installed-app contexts | Redistribution approval, hardware decode/physical output unverified |
| AAC playback | Complete and tested | Actual nonzero audio samples in both contexts | Same redistribution/output gates |
| MP4 playback | Complete and tested | Combined H.264 video and AAC audio in both contexts | Same redistribution/output gates |
| Picture-in-Picture | Complete and tested | Native advancing pixels, resize/close, selected second video, stale refusal, navigation/crash/source cleanup; browser/app/private | Target compositor checks separate |
| Linux PiP application identity | Complete and tested | Browser/app WM_CLASS on X11 | Wayland app_id and actual dock grouping unverified |
| Accessibility actions | Upstream dependency | Real activation/focus, Unicode AT-SPI editing, native selection, protected/stale/malformed refusal | GTK 4.18 direct Text selection/caret setters unsupported; Orca unavailable; exact source evidence in architecture guide |
| Full navigation history | Complete and tested | Selected entry/back/forward, no URL replay, private/profile/version/malformed fallback | Bounded safe GET state; POST/file/unsafe state uses URL fallback |
| Extended Task Manager | Complete and tested | Live renderer PID verified in /proc, native network/root fields, refresh and task kill | Root task IDs are not a full OS process hierarchy |
| Browser compatibility | Complete and tested | 27/27 standard and custom local regression groups | Native target desktop checks separate |
| Web-app compatibility | External dependency | Isolated local app profiles, identities, storage/auth/routing, media/PiP/lifecycle regressions | Real Sheets/provider accounts and target desktop unavailable |
| Wayland compatibility | External dependency | Source identity integration; X11 regressions | Target Majoris desktop unavailable, confirmed by user |
| Debian packaging | Complete and tested | Custom development .deb; 27/27 package tests; archive/provenance/license and extracted GTK/CEF smoke pass | System installation/upgrade and production distribution unverified/unapproved |

Codec redistribution approval, Widevine, real accounts, maintained threat/scanner
services and unavailable target desktop checks remain separate external gates.

## Historical production-readiness matrix (main 82684a8)

The following matrix records the earlier standard-SDK pass. The custom-engine matrix above is authoritative for this task. Local fixtures do not qualify production accounts, maintained signature distribution, codec redistribution or unavailable target desktops.

| Feature | Implemented | Verified | Remaining limitation |
|---|---|---|---|
| Chromium security | Partially implemented: precise patch assessment | Pin, official index, exact CEF source and upstream maintenance/V8 patches | Security-fixed supported SDK/custom build not integrated or qualified; release blocked |
| Phishing protection | Managed/direct client complete | HTTPS, credentials, verdicts, cache expiry, concurrency and health fixtures | External dependency: authorised managed deployment/account/terms and live qualification |
| Malware URL protection | Same client integration | Same local error/privacy/gate tests | Same external service dependency; default disabled |
| Download malware scanning | Complete optional clamd integration | Protocol, lifecycle and real disposable clamd with harmless signature | Requires configured supported daemon and maintained production signatures; default disabled |
| H.264 | Prepared runtime path | Current decoder unavailable; VP8/VP9 regression | External licensed codec-capable fixed SDK and real playback qualification |
| AAC | Prepared runtime path | Current decoder unavailable; decoded Opus regression | Same external codec dependency |
| Widevine | Explicit unsupported state | Unavailable CDM result | Optional external vendor/DRM/service entitlement |
| Accessibility | Maximum supported existing AX bridge retained | Real AX/AT-SPI regression | Upstream node-action/edit API limitation; Orca/native desktop pending |
| Picture-in-Picture | Intentionally unavailable action | Exact source and runtime refusal | Upstream Alloy OSR limitation; optional |
| Session restoration | Existing URL/window/tab recovery retained | Lifecycle/session regression | Upstream full navigation-stack import absent |
| Task Manager | Supported metrics/termination retained | Actual runtime regression | Upstream PID/network/parent fields absent |
| Web-app runtime | Existing minimal isolated app windows retained | Installation, identity, storage, auth/routing and lifecycle fixtures | Real-provider/native-desktop qualification pending |
| Google Sheets | Implemented, verification pending | Local app/auth/isolation fixtures | Authorised account/Majoris desktop unavailable as already confirmed; also real Excel/Outlook unverified |
| Cookie isolation | Complete and verified | Real contexts/storage/restart/clearing | Real-account session check remains separate |
| Wayland | Implemented, verification pending | X11/input/clipboard/drag regression | Native Wayland/IME/dock/scaling/theme unavailable |
| Debian packaging | Implemented, verification pending | Revision 0.1.0-6: final clean rerun 25/25, Debian 25/25, archive/extracted runtime and metadata passed | Actual system installation/upgrade and Majoris desktop pending; production blocked |


## Final security and compatibility pass (main 97812b08)

This table supersedes earlier snapshots below. The architecture and earlier suites are retained. No live account, licensed media runtime, CDM or Majoris desktop was provided.

| Feature | Implementation status | Runtime verified | Remaining blocker |
|---|---|---|---|
| Chromium security updates | Incomplete | Exact SDK/archive and refreshed official index/CNA assessment | Supported fixed SDK or authoritative per-component/backport evidence; release blocked |
| Phishing protection | External dependency required | Actual Web Risk adapter with disposable HTTPS, Secret Service and native gate fixtures | Authorised account/key, current terms/privacy approval and live service qualification |
| Malware URL protection | External dependency required | Malware/unwanted/no-match mapping, error/timeout/cancel, TLS/redirect denial | Same live provider dependency; default disabled |
| Download reputation | External dependency required | Persisted assessments/open restrictions and real isolated downloads | File-content reputation/scanner absent; ordinary files remain not assessed |
| H.264 playback | External dependency required | Current runtime reports decoder unavailable; VP8/VP9 playback verified | Licensed codec-capable fixed SDK and real H.264/combined qualification |
| AAC playback | External dependency required | Current runtime reports decoder unavailable; decoded Opus verified | Licensed codec-capable fixed SDK and real AAC/combined qualification |
| Widevine DRM | External dependency required | Current runtime rejects unavailable CDM | Vendor entitlement/binary, integration and service/VMP qualification; optional |
| Web-app navigation scopes | Complete and verified | Sheets/Docs/Slides, Excel/Word/Outlook sections, root/custom/manifest/legacy domain fixtures; native auth/popup regressions | Real provider/desktop UX still requires manual qualification |
| Google Sheets compatibility | Implemented verification pending | Local OAuth, app lifetime, independent data and restarted fixture identities | Real account and Majoris desktop unavailable by user confirmation |
| Web-app profile isolation | Complete and verified | Real cookies/storage/cache, independent app launches/restarts and clear/uninstall | Real Sheets session verification remains separate |
| Web accessibility | Upstream limitation | Real AX/AT-SPI text, frame, focus, Unicode, protected/live geometry | Public OSR node-action/edit dispatch absent; Orca/native layout unverified |
| Picture-in-Picture | Upstream limitation | Actual unsupported result, entry omitted | Alloy OSR rejects PiP; optional |
| Session restoration | Upstream limitation | URL/window/tab/geometry recovery and private exclusion | No public serialized Chromium navigation-stack import |
| Task Manager | Upstream limitation | Supported metrics and termination | Public task PID/network/parent metrics absent |
| Wayland integration | Implemented verification pending | X11 input, drag, clipboard, Unicode and identity fixtures | Native Wayland, IME candidates, dock, scaling/theme unavailable |
| Debian packaging | Implemented verification pending | Revision 0.1.0-5: fresh-source 24/24, Debian 24/24, archive/extracted GTK/CEF and metadata passed | System installation/upgrade and target desktop gates; production release blocked |

Provider configuration is in security-maintenance.md; complete security triage is in security-assessment.md. Neither successful local fixtures nor a development Debian archive authorises production distribution.

## Remaining-feature pass (main ff562f9)

| Feature | Status | Verified | Remaining blockers |
|---|---|---|---|
| Chromium security updates | Formally assessed, unresolved | Publisher/header/archive report; existing sandbox/TLS tests | Ten upstream .169 fixes lack Linux/CEF applicability/backport proof; available M152 stable remains .167 |
| Phishing protection | Framework implemented; live service externally blocked | Local verdicts, cache ownership/TTL, timeout/cancel; real redirect cancelled before fetch | Authorised maintained provider, terms, privacy/update infrastructure |
| Malware URL protection | Framework implemented; live service externally blocked | Malware/unwanted-software/no-known-threat/unknown/outage cases | Same provider dependency; no operational blacklist or remote calls |
| Dangerous-download protection | Assessment model, persisted restrictions and software-opening caution | Metadata roundtrip/open guards; real downloads and private isolation | No content-scanning provider; ordinary files remain not assessed |
| H.264 | Blocked by qualified runtime/licensing | Actual runtime reports unavailable; codec-capable runtime must pass local playback assets | Authorised codec-capable SDK, licensing/notices and H.264 playback qualification |
| AAC | Blocked by qualified runtime/licensing | Actual runtime reports unavailable; open Opus decode/RMS verified | Authorised codec-capable SDK and AAC/combined-MP4 playback qualification |
| Widevine | Externally blocked, optional | EME request refuses unavailable CDM | Vendor entitlement/binary/service/VMP qualification; no browser CDM copied |
| Web-app navigation scopes | Implemented | Domain tests: section fallback, encoded/dot/port boundaries, manifest preservation, SQLite metadata/legacy survival; GTK install and native auth regressions | Existing broad legacy scopes require explicit review in Settings; complete section-edit UX needs native desktop qualification |
| Google Sheets compatibility | Implemented app architecture; provider runtime unverified | Independent contexts, local OAuth, two app identities/storage restarts | Authorised real account and Majoris desktop unavailable, as already confirmed |
| Accessibility | Supported transport preserved | Real AX/AT-SPI text/frame/focus/Unicode/protected/live geometry tests | Pinned OSR lacks public node-action/edit dispatch; Orca/native layout gates |
| Picture-in-Picture | Upstream-blocked, optional | Real unsupported result; entry omitted | Alloy OSR still rejects PiP; no engine upgrade in this pass |
| Session restoration | Implemented URL/window recovery | Existing snapshots/private exclusion/lifecycle | No supported serialized navigation-stack import; no replay workaround |
| Task Manager | Implemented supported metrics | Existing native metrics/termination tests | No trustworthy public PID/network/parent identifiers |
| Wayland integration | Implemented but native runtime unverified | X11 input/clipboard/drag and direct Unicode commit only | Native Wayland, IME candidate UI, scale/dock/theme environment unavailable |
| Debian packaging | Development revision 0.1.0-4 built | Fresh-source 23/23; Debian 23/23; archive/extracted-runtime/metadata passed | Security/provider/codec and manual gates prevent production approval |

This assessment supersedes prior pass counts/status where coverage changed. Source architecture and all existing tests are retained. Detailed engine triage is in security-assessment.md; runtime integration conditions are in codec-runtime.md.

## Final hardening qualification

| Feature | Implemented | Tested | Remaining limitations |
|---|---|---|---|
| Private download isolation | Yes, profile/session ownership in listing and actions | Real normal/private streaming, wrong-context controls, last-session-view cleanup, SQLite reload and file retention | Native download dialogs need desktop interaction qualification |
| Browser security | Sandbox/TLS/origin defaults, certificate denial, isolated bindings, scoped permissions/profiles | Renderer seccomp/no-new-privileges, invalid TLS, SOP, file-fetch denial, binding invisibility and isolation suites | No qualified URL reputation service; upstream .169 security delta versus latest CEF .167 is an unresolved release blocker |
| Download protection | Unassessed state, risky-file open confirmation, interruption/security-block distinctions | Real downloads, scope enforcement and executable/ordinary filename classification | No malware/reputation verdict; confirmation UI unverified; filename cautions are not maliciousness judgments |
| Password management | Secret Service, save/update/never-save, trusted username-first steps | Conventional/dynamic/formless/change/frame/failed/multi-step fixtures and multiple stored logins | Unknown SPA success uses explicit Site Password action; closed shadow DOM and complete chooser/PolicyKit/locked-keyring UX unverified |
| Accessibility | AX-to-AT-SPI trees/text/focus, non-atomic editable text, Unicode, protected descendants, fractional bounds | Independent AT-SPI: input, multiline, emoji, contenteditable, protected values, frames, live changes and geometry | No public pinned OSR AX action dispatch; complex transforms/frame/character geometry unknown; Orca/braille unverified |
| Picture-in-Picture | Explicit unsupported result; unavailable menu item removed | Real OSR refusal; upstream Alloy still rejects windowless PiP | Blocked upstream; no fake detached video |
| Session restore | Normal windows/tabs/URL/order/pin/active/geometry | Snapshot/private exclusion and GTK lifecycle | CEF exports entries but cannot import a serialized stack; no login/POST replay |
| Browser Task Manager | Native metrics/types/association/termination | Retained observer and actual renderer termination | No trusted public PID/network/parent mapping |
| Web-app installation | Minimal windows, generated launchers/icons, separate GTK identities | Two installed local fixtures concurrent with Browser, distinct X11 WM_CLASS | Majoris dock/pinning/Alt+Tab/theme unverified |
| Web-app storage isolation | Independent persistent contexts and profile leases | Cookies, CHIPS, localStorage, IndexedDB, Cache Storage, workers/cache, restart and clearing | Real authenticated Sheets persistence unverified |
| Web-app authentication | App-owned OAuth transactions, real opener/popup, consented origins | Local TLS provider: delayed popup, state/return, expiry, cross-app refusal | Real Google/Microsoft policies/accounts unverified; no bypass |
| Wayland integration | GDK OSR input/drag/IME/scale paths | X11 fixtures and direct Unicode CEF commit | No native Majoris desktop; Wayland/IME candidate UI/scaling/drag/dock are manual gates |
| Debian packaging | Revision 0.1.0-3, explicit SDK pin/checksums, hardened workflow | Fresh source 20/20; package 20/20; archive/extracted-runtime/metadata passed | Development artifact only: security/reputation and desktop gates block production qualification; system installation/upgrade unverified |

This table supersedes older qualification statements below where this pass expanded coverage. Unresolved release gates remain open.

This is a development build. Automated fixture results qualify the tested paths, not production readiness or third-party account compatibility. The user confirmed that a Majoris desktop is unavailable; the account, dock and native Wayland gates below remain unverified.

| Requirement | Status | Implementation and evidence / precise limit |
|---|---|---|
| Existing architecture and identity | Implemented and tested | Vala/GTK4/libadwaita, CEF OSR C ABI/VAPI, Meson, SQLite/GSettings/libsecret preserved. No Brave UI, services or architectural rewrite. |
| Cancelled clear-on-exit | Implemented and tested | Generation-bound pending/cancelled/approved/complete operation. Denied beforeunload invalidates destructive intent; only confirmed window closure followed by engine shutdown permits deletion. Real CEF cancellation, later browsing and independent app-cookie assertions. |
| Site cookies and CHIPS | Implemented and tested | Target-context Network.getAllCookies/deleteCookies, exact name/domain/path/partition key. Host/domain boundaries and all paths; libpsl schemeful site. Unrelated top-level partitions and app cookies survive. Opaque keys are preserved because they cannot be selected safely. |
| Site storage | Implemented and tested | Page frame ID → Storage.getStorageKeyForFrame → clearDataForStorageKey. No fabricated storage-key strings or default-browser-context cookie API. Current-origin rechecks reject navigation races. localStorage, IndexedDB, Cache Storage and service-worker isolation tested across restart. |
| Whole-profile independence | Implemented and tested | Browser clears only its closed CEF profile after shutdown; app clear/uninstall takes that app lease. Real persistence, locks, sibling preservation and symlink refusal tests. |
| Exact-origin HTTP cache / arbitrary storage partition enumeration | Blocked by pinned public API limits | No qualified exact-origin HTTP-cache deletion API is used. Live whole-context HTTP-cache clearing and explicit closed-profile full clearing are available. Site Information does not claim to clear other partitions or HTTP cache. |
| Failure-safe uninstall | Implemented and tested | Reversible integration staging before durable SQLite unregistration; v5 recovery job stores original keep/delete choice. Profile erasure last; failed cleanup can be retried, reinstall is refused while pending, running profiles are excluded. Actual filesystem/SQLite rollback/retry tests. |
| App navigation and popups | Implemented and tested | Parsed scope boundaries, real popup clients/opener and shared originating RequestContext. No-gesture candidate popup tested with explicit site popup permission after activation expiry. Chromium's own popup policy still applies. Unrelated unsolicited popups are refused. |
| Authentication transactions | Implemented and tested | App-owned transaction, initiator, return URI/state, approved exact origins, consented intermediate redirects, shared opener/child revocation and 120-second cap. Fixture tests return revocation, expiry and another app's refusal. No global provider-origin exemption. |
| Google/Microsoft/provider sign-in | Implemented but not runtime-verified | Conservative recognized/generic authorization-code handling is present. Provider policies are not bypassed. Real Sheets/Microsoft accounts and provider-specific redirects require a consenting target-desktop run. |
| Minimal app windows | Implemented and tested in fixture lifecycle | Titlebar/window controls and content; visible overflow removed. Ctrl+N creates another app window, private Browser windows are disabled in app processes, in-scope new-window actions retain app scope. Real dock/window-manager presentation remains unverified. |
| Credentials and addresses | Implemented and tested for supported forms | Isolated certificate-valid HTTPS worlds; dynamic, async/formless, password-change and same-origin iframe fixtures. Cross-origin frames and failed responses excluded. Native setters, input events, multiple logins, Secret Service update and address aliases/selects tested. Address offers require explicit GTK confirmation. |
| Save/never-save/reveal dialogs | Implemented but not fully runtime-verified | Save/update/never/not-now, final origin/policy rechecks, pending-secret expiry/wiping and PolicyKit reveal are present. Complete interactive dialog/locked-keyring/PolicyKit UX still needs desktop qualification. Arbitrary SPA/closed-shadow-root login-success inference is not claimed. |
| Audio state | Implemented and tested, with precision limit | Track-aware media events and running/suspended WebAudio contexts are separate from persistent host mute. Silent canvas video does not indicate audio; mute/suspend/unmute tested. Running WebAudio activity is not a PCM audibility meter: a connected silent/zero-gain graph can remain active. No audio-capture handler is installed that would suppress normal playback. |
| Context menus | Implemented and tested for core paths | Shared GTK menu builder uses actual context/edit/media flags. Native tests cover link/image/page/input/iframe contexts, real image PNG bytes, focused-frame cut and source. Spell suggestions and hit-tested media commands are implemented; their complete GTK interaction matrix remains unverified. |
| Certificate details | Implemented and tested for trusted TLS | CEF X509 subject, issuer, hostname, status, dates and PEM chain; GTK details dialog. Trusted TLS fixture validates dates/status/PEM. Invalid certificates remain denied; the full mismatch/expiry/mixed-content dialog matrix is unverified. |
| Granular browsing data | Implemented and tested | History/download-record ranges; independent all-time Browser permissions, addresses, cookies and HTTP cache. Active downloads, downloaded files, bookmarks, secrets and app profile records retained. SQLite category/time regression and real context-clearing fixtures. |
| Import | Implemented and tested | HTML, Chromium JSON, closed Chromium/Firefox history and Firefox places bookmarks. Bounded read-only snapshots, active WAL/journal refusal, safe URLs/folders and unchanged source bytes tested. Secure cross-browser password import is unavailable. |
| Outbound/inbound drag-and-drop | Implemented and tested on X11 | Actual XTest pointer gestures: link and image file export to GTK, cancellation, local file delivery into Chromium. Bounded formats/temporary files, source completion and full target enter/over/drop/leave lifecycle. Wayland drag protocol behavior remains unverified. |
| Keyboard and clipboard | Implemented and tested on X11 | Real key events type/edit input; bidirectional GTK/Chromium Japanese/emoji clipboard transfer. Registered application accelerators precede renderer forwarding. Mouse leave, focus escape and composition cancellation added. |
| IME, fractional scale and Wayland | Implemented but not fully runtime-verified | UTF-16 composition/selection conversion, one commit path, caret rectangles and GDK surface scale. Real CEF Japanese/emoji commit tested. Native IME candidate UI, surrounding-text interaction, fractional-output changes and native Wayland require target qualification. |
| Web accessibility | Partially implemented with verified public API limits | Real CEF AX nodes mapped into GTK/AT-SPI, including frame trees, roles/names/states, protected-text suppression, text boundaries/caret/selection/focus, live updates and main-tree geometry/location updates. Independent AT-SPI client verifies these. Complex transformed/cross-frame/character geometry returns unknown. CEF's public OSR AX interface supplies updates but no node-action or selection-edit method; direct AT-SPI actions/editing are not fabricated. Full Orca/braille behavior remains unverified. |
| Printing and export | Implemented and tested at engine boundary | Toolbar/JS print setup cancellation, retry, pending-page closure, selected Letter landscape PDF MediaBox, rejected/acknowledged jobs and reset. Accepted setup cancels CEF's crashing print-driver route, generates bounded PDF with CDP, then GTK PrintDialog submits the file. Physical printing, copies/ranges/backend errors and PDF-viewer UI require desktop/printer qualification. PDF/MHTML export remains tested. |
| Picture-in-Picture | Blocked by verified upstream limitation | CEF Alloy explicitly returns false for windowless PiP support. A live request remained pending; action is now disabled in Browser, omitted from context menus, and direct requests report unavailable immediately. No engine rewrite or fake detached video is supplied. |
| Task Manager | Implemented and tested for supported metrics | Retained CEF observer, correct task-type mapping, CPU/memory/GPU memory with unknown/aggregate handling, current-page association, sorting and supported termination. PID/network/explicit parent IDs are absent from CefTaskInfo; no guessed values. |
| Desktop identities, icons, notifications | Implemented and fixture-tested | Distinct X11 WM_CLASS values matching desktop entries, generated icons, process identity/resource name and native Chromium D-Bus web notifications. Browser/app concurrent lifetime and notification click/close tested. Two installed local apps and restarted storage are fixture-tested; dock pin/grouping, Alt+Tab and Majoris Theme presentation remain unverified on the real desktop. |
| UA and UA-CH | Implemented and tested | Linked engine version and Majoris brand in renderer UA, brands/high-entropy metadata and actual HTTP Client Hints headers. No provider bypass. |
| Packaging and fresh-source builds | Implemented and tested | Current clean source and hardened package: 23/23 suites; extracted runtime and metadata validation passed. GTK minimum 4.18, libpsl, AT-SPI and XTest prerequisites; revision 0.1.0-4; verifier requires all 23 suites. Native installation/upgrade remains manual. |
| Excluded product scope | Not implemented, as requested | Rewards/wallet/VPN/Tor/cloud sync/Chrome Web Store/AI/advanced farbling and a closed-app push daemon remain excluded. |

## API alternatives and release gates

The pinned headers and runtime are CEF 152.0.14+g8a0b5b9 / Chromium 152.0.7977.167. CefCookie lacks an exposed partition key, so the target's CDP Network agent supplies precise keys; libpsl computes schemeful sites. CEF does not expose serialized navigation-history import or a complete download danger verdict; no fake stack/danger status is shown. CefTaskInfo lacks PID/network/parent IDs. The accessibility handler is a read/update transport, not an action dispatcher.

Upstream's [Alloy implementation](https://github.com/chromiumembedded/cef/blob/master/libcef/browser/alloy/alloy_browser_host_impl.cc) explicitly disables PiP for OSR. [CEF issue 3328](https://github.com/chromiumembedded/cef/issues/3328) tracks that restriction. [GTK's AT-SPI text implementation](https://github.com/GNOME/gtk/blob/4.18.6/gtk/a11y/gtkatspitext.c) provides read operations but rejects several text-edit/selection operations; the adapter does not advertise coordinate-click substitutes. These are narrower limits than saying all web accessibility is impossible.

No production-readiness claim is made. Mandatory unverified gates are the consenting-user Sheets sign-in/restart/Browser-clear scenario, Majoris dock/identity/theme, native Wayland/IME/scaling, complete assistive-technology interaction, provider compatibility, printer/backend UI and real Debian installation/upgrade. No live account credentials have been used.
