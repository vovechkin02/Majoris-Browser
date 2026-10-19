# Custom engine integration — 19 October 2026

The application remains Vala/GTK4/libadwaita with the existing C++ CEF bridge.
`engine/` adds a pinned CEF 7977 / Chromium 152.0.7977.169 source build. Its
versioned C extension symbols are discovered from the loaded libcef.so;
standard SDKs expose no such symbols and preserve their existing fallbacks.
See [engine internals and provenance](../engine/README.md) and
[patch maintenance](../engine/PATCH-MAINTENANCE.md).

PiP retains Chromium's native manager, video controller, surface and Views
overlay. The Linux overlay receives the launcher's browser/app desktop identity.
The media menu uses a generation-bound hit-tested video; navigation, renderer
failure and close invalidate stale actions. The global action accepts one
unambiguous playing video. No GTK imitation video window or external player is
used.

CEF OSR uses tree-only AX mode. A bounded WebContents-owned cache of the actual
engine updates validates node existence and document/frame/browser ownership;
it does not assume Chromium's native accessibility manager exists. GTK AX model
widgets expose public widget actions and GtkEditable requests. Reads remain
authoritative AX text; no synthetic entry buffer is exposed. Protected text
permits focus but denies reads/writes and default actions. The local Vala
interface binding describes GtkEditable's actual public C vtable, avoiding the
distro binding's nonexistent virtual set_text member.

GTK 4.18's [AT-SPI Text implementation](https://github.com/GNOME/gtk/blob/gtk-4-18/gtk/a11y/gtkatspitext.c)
returns `G_DBUS_ERROR_NOT_SUPPORTED` for `GtkAccessibleText` SetCaretOffset
(lines 92–95) and Add/Remove/SetSelection (343–354). Its older GtkEditable
Text fallback requires an actual GtkText delegate for Pango layout/boundary
queries; a model-only editable has none. Replacing the authoritative AX text
with a synthetic GtkText buffer would compromise the current text model.
Majoris therefore exposes native focus, value editing and a select-all action,
while direct arbitrary AT-SPI Text selection/caret setters remain an upstream
GTK integration dependency. Chromium's validated selection ABI is implemented.

Normal browser session snapshots can include bounded, versioned serialized
Chromium navigation entries. Restore occurs before initial navigation, into an
unused controller. It validates exact runtime/profile identity and refuses POST
bodies, file references, unsafe URLs and malformed or oversized data. Only the
selected restored entry loads; earlier URLs are not replayed. A 16 MiB aggregate
history budget preserves URL snapshots for excess tabs. Private views and
installed-app scopes do not capture or restore this state.

Task metrics reuse CEF's observer lifecycle and Chromium task IDs. Custom
runtimes additionally provide real PID, network bytes/second and root-task ID.
The UI distinguishes per-task network from shared process CPU/memory; a root
task is not presented as a complete operating-system process hierarchy.

## Earlier standard-SDK records

# Architecture and engine contract

Current additions retain the existing service boundaries. DownloadSecurityProvider has NoDownloadScanner and ClamdDownloadScanner implementations; no remote scanner is shipped. A configured clamd Unix socket is queried with VERSIONCOMMANDS and receives bounded INSTREAM chunks through a worker thread, not a shell command. One scan per process, 64 MiB input and a 30-second total deadline bound client work. Cancellation interrupts socket I/O; symlinks/special files and changed/replaced files are rejected. The daemon controls archive/engine limits; these must be configured by the operator. Daemon version/date and reported age are displayed, with unknown freshness when unavailable. Files are never deleted or executed. The download service persists scanning/verdict states, blocks opening pending/detected files, cancels removed/private-expired work, and invalidates old clean/pending assessments on restart. Private metadata remains memory-only.

The same WebRiskProvider now supports a separately configured authorised managed HTTPS endpoint with per-installation bearer credentials in a distinct Secret Service item. Its request/verdict contract is documented in security-maintenance.md. No backend is deployed and no shared Cloud key is embedded. Direct Web Risk remains an advanced account-owner option. Both routes require informed full-URL consent including private/app/authentication URLs. Settings observes Not Configured, Unavailable, Active, Temporarily Unavailable and Service Error. Active follows a valid response, expires after 60 seconds without confirmation, and never means a safety guarantee. Invalid enabled managed configuration fails closed without silently falling back to Google.

The security service retains its asynchronous ThreatProvider and bounded context-owned memory cache. Hash-only adapters keep the existing origin/path hash contract. The opt-in WebRiskProvider overrides URL lookup and cache-key generation: it sends the complete HTTP(S) URL, including query but excluding fragment, only after explicit full-URL consent. Embedded credentials and overlong URLs are rejected. The exact transmitted destination is SHA-256 hashed for cache keys, so different queries cannot reuse a verdict. No key, URL or verdict is persisted by the provider. It has a fixed Google HTTPS endpoint, no redirect following, default TLS validation, a 64 KiB response limit, three-second service/session deadlines, one-second process-local check reservations with cancellable queueing bounded to 1.5 seconds and bounded 60–600 second Retry-After backoff on 429/503. Requests are not automatically retried. No-match responses are not cached; matched responses use the earlier of provider expiry and 60 seconds. Provider attribution survives cache copies.

ThreatProviderSecret stores the API key in a separate libsecret schema, not website credentials, SQLite, GSettings, command lines or request URLs. Settings opens the native provider configuration dialog; account authorisation and consent cover Browser, private windows and installed apps. Configuration applies after all affected processes restart. Missing/locked credentials, invalid JSON, unexpected types, TLS errors, rate limits, provider failures and cancellation never become a no-known-threat verdict. Unconfigured defaults make no provider requests. Native warnings qualify possible risk, include Google advisory attribution for Web Risk results, and offer no permanent bypass. Obsolete cancelled checks cannot present warnings for a later navigation.

When explicitly enabled by a configured service, CEF main-frame resource loads (including redirect destinations) use RV_CONTINUE_ASYNC and the native request/reply bridge. The GTK loop queries asynchronously; only NO_KNOWN_THREAT continues. Known threats show a native hostname/category/details warning; unknown/failure/timeout cancels without a safety claim or permanent exception. Native requests have a five-second fail-closed deadline; service checks have a three-second deadline and cancellation. New navigation/close cancels pending checks. No POST is replayed. New tabs/windows and app-owned popups attach the same gate; out-of-scope app destinations retain normal Browser routing. Cache keys include profile/private-session ownership, only provider-authorised TTLs up to 60 seconds are used, and closure clears that context. Nothing is persisted to SQLite.

New web apps store scope_source (manifest/inferred/confirmed); older JSON loads as legacy without automatic narrowing or new IDs. Manifest scopes remain website-defined. Fallback uses the selected directory, or a proposed first path section for a document URL; installation displays icon/name/start URL/section and requires confirmation, with fallback editing. Settings can change a closed app's section under its profile lease. Origin/port/path boundaries and dot/encoded-separator rejection agree in Vala and native policy. No provider-specific Google-company exception is introduced.

DownloadService registers every engine with an in-memory private-session key (empty for persistent contexts). Records carry a profile and ephemeral session owner; listing, retry, pause/resume/cancel, remove and clear-completed enforce that owner. Independent private windows have independent contexts. Transferred tabs and opener-created windows retain the original key. Closing a hosting page cancels its active transfers; completed metadata survives while another view owns that session, then disappears at the last close. Cleanup never deletes downloaded files. Private keys never enter serialized metadata.

Without a configured local scanner, downloads report security as not assessed. Suffix/executable-bit cautions control confirmation before opening; they are not malware verdicts. Native CEF reasons distinguish interruption, security/policy blocking and failed security checks. Completed downloads never execute automatically.

Username-first capture requires trusted activated semantic submissions in valid HTTPS isolated worlds. Native memory retains a bounded username for 60 seconds, tied to origin/frame, and consumes it only for a later password submission. Origin change/closure wipe it. Autofill can fill a visible username step without submitting or placing a password in a non-password field. Existing success qualification and never-save/origin checks still apply.

Non-atomic editable AX text comes from actual serialized staticText/lineBreak descendants. Parent linking precedes text publication so protected ancestors suppress descendant text. Unsupported transforms remain unknown; supported fractional rectangles round outward.

The GTK/Vala layer owns windows and product UI. `BrowserSurface` isolates the GTK product from the rendering implementation. `OffscreenBrowserSurface` transfers BGRA frames to GDK memory textures and forwards input to CEF. Native window hosting is not implemented yet; no X11 window handle enters the Vala application.

`libmajoris-cef` exposes a GObject-based C ABI and a Vala VAPI. Only `mc_*` symbols are exported: Chromium and wrapper C++ implementation symbols must not interpose on each other. Hosts link libcef directly (retained with `--no-as-needed`) so Chromium's libc interposition can resolve symbols in the correct order.

The dedicated subprocess's tiny `main` uses CEF's `NO_STACK_PROTECTOR` annotation, matching `CefExecuteProcess`: Chromium resets stack canaries after zygote forks, so checking the caller's old canary on return is invalid. Debian hardening remains enabled elsewhere. Package verification rejects subprocess stack-canary diagnostics even if the parent fixture returns success.

CEF 152.0.14 (`g8a0b5b9`), Chromium 152.0.7977.167, Linux x86-64, is the initial pinned SDK. This pin requires security maintenance; version selection alone is not evidence of future security support. No Chromium/CEF patches are applied. The bootstrap verifies upstream's published SHA-1 digest over HTTPS; upstream does not publish a modern signed digest in this build record.

Chrome bootstrap creates Alloy-style offscreen browser instances. First-run Chrome UI is disabled through standard startup switches. The tested integration uses CEF's multithreaded Linux message loop. No periodic engine polling runs. CEF UI work is posted with CefPostTask; callbacks enter GTK through attached GLib sources. Sources are attached explicitly because g_main_context_invoke may execute immediately on an acquiring worker thread.

Frames have a latest-frame mailbox; normal frames avoid an extra composition copy. CEF select/menu popup surfaces are composited over the view. Fractional scale and widget size inform CEF. Input uses one GTK IM commit path, UTF-16 composition ranges and CEF caret bounds. Incoming text and local-file drops use CEF's drag target API. Outgoing drag-and-drop and a complete OSR accessibility adapter remain unfinished.

User tab/window closing requests non-forced CEF closure and keeps GTK alive for beforeunload consent. Cancellation retains the page; accepted closes wait for OnBeforeClose. Forced closure is reserved for disposal/error/test cleanup. Runtime shutdown continues the main context until every browser has emitted OnBeforeClose, then calls CefShutdown on the initializing thread. SQLite jobs drain before application exit. A per-runtime filesystem lease stays outside the profile directory; destructive clearing requires the same exclusive lease. Parent traversal and recursive deletion use directory descriptors with no-follow checks. Symlinked profile parents are refused. All app profiles remain under one controlled XDG parent, but each separate app process has its own CEF root to avoid ProcessSingleton conflicts.

CEF Chrome profiles support the runtime root itself or immediate child directories. Production apps use the root itself; the cookie regression uses sibling immediate children in one test runtime. Nested profiles must not silently fall back to off-the-record storage. Profile layout and data deletion must be requalified on any engine upgrade.

SQLite migrations use user_version and transactions. Store instances are confined to a single storage worker. Results return through GLib idle callbacks. Large profile deletion runs off the GTK thread. Secrets use libsecret; saved credentials are keyed by profile, origin and username. Filling checks the current main-frame HTTPS origin again immediately before injecting values, and does not submit forms.

Schema migrations now cover bookmark folders and bar order, generation-guarded multi-window snapshots, download metadata, permission expiry, password exceptions and non-secret address profiles. Private windows are excluded from persistent browsing records. Quit snapshots all normal windows before closing any of them. Progress metadata is coalesced and flushed on shutdown.

Permission policy loads before view creation and is applied to Chromium content settings before HTTP frame navigation. Remember/reset operations update both SQLite and attached live engines, including cached grants. Browser settings ask running app processes to reload through their existing GApplication D-Bus action without starting stopped apps. Private views omit persisted decisions. Once-only origins are reset on navigation/close; Not Now dismisses the request without storing a block. Cross-process reload and physical-device behavior still require desktop qualification.

The credential observer runs in certificate-valid HTTPS CDP isolated worlds for the main frame and matching-origin child frames. Trusted form/button events capture bounded candidates. Matching successful same-frame credential POST/PUT/PATCH responses plus disappearance of the password field qualify supported asynchronous flows; cross-document success has separate generation checks. Failed responses cancel candidates. Binding/context IDs and origins are rechecked in native code; no page-world native API is exposed. Address offers require trusted field focus and explicit GTK selection. Secret Service remains the only password store, and the final save rechecks current origin and never-save policy after asynchronous storage access.

Site-cookie clearing uses the active target Network agent to enumerate and delete exact name/domain/path/partition-key cookies. It selects host and matching parent-domain cookies at every path, and only the selected libpsl-derived schemeful top-level partition. Opaque or unmatched partitions are preserved. Storage clearing obtains the current main-frame storage key from Storage.getStorageKeyForFrame and passes it unchanged to clearDataForStorageKey. It rechecks navigation before dispatch. CEF ClearHttpCache is whole-request-context; exact-origin HTTP-cache deletion is not claimed. Closed-profile clearing is the explicit full-data fallback. No live Chromium files are edited.

Allowed popups retain a real Chromium browser, opener and originating RequestContext. Candidate/active app flows can accept callbacks without an immediate gesture when Chromium permits them, including explicit per-origin popup grants. Unsolicited unrelated requests remain blocked. App-owned authentication transactions share a bounded grant between opener and child; cancellation, completion, replacement and a monotonic expiry revoke it. New intermediate redirect origins require GTK consent. The popup signal hands the new view to GTK before its queued events; abort callbacks release pending lifecycle references.

Web-app scope checks use parsed origins and path boundaries. Authentication candidates require a bounded, in-scope return URI without user information/fragments; authorization-code candidates require client ID and unique, sufficiently long state. Approved callback path, required query fields and returned state are checked. Generic code endpoints and recognized legacy provider return flows are supported. No provider restrictions or third-party embedded-agent policies are bypassed.

Web notifications use Chromium's real notification implementation and Linux desktop D-Bus backend, including click and close delivery. Each process sets its generated desktop entry and resource-bundle display name before engine startup. This preserves web/service-worker semantics rather than replacing `Notification` with a JavaScript shim. A closed app has no running engine and no background push broker. Desktop icon presentation still needs Majoris/GNOME qualification.

CEF print callbacks route toolbar, JavaScript and PDF-viewer requests to GTK setup. Accepted setup cancels Chromium native printer-driver submission: a real runtime fixture exposed a trap in its print-backend service. The bridge instead generates a bounded PDF through Page.printToPDF using the selected paper/orientation, writes a private temporary file, and asks GTK PrintDialog.print_file to submit it. Completion/cancellation cleans the file and resets setup. Ranges/copies belong to GTK submission, not a second PDF filtering pass. Submitted means accepted by the print backend, not physically printed. PDF export and MHTML saving retain GTK file choosers. PiP is disabled because Alloy explicitly rejects windowless PiP.

The supplied Brave archive was inspected as a lifecycle/architecture reference, including browser/brave_browser_main_parts.cc and browser/brave_browser_process_impl.cc. No Brave code, UI or services were copied. Public CEF APIs supply the engine integration.

Upstream references: [CEF general usage](https://github.com/chromiumembedded/cef/blob/master/docs/general_usage.md), [automated binary distributions](https://cef-builds.spotifycdn.com/index.html), and [Chrome request-context profile handling](https://github.com/chromiumembedded/cef/blob/master/libcef/browser/chrome/chrome_browser_context.cc).

Future extension, tracking-prevention and sync adapters belong behind application services; none may expose arbitrary native capabilities to web content. Native Wayland hosting can replace the surface without changing BrowserWindow or WebAppWindow.


Shutdown intent is a generation-bound ExitOperation. A pending clear becomes approved only after all requested Browser windows finish closing; cancellation or a new window invalidates it. Shutdown drains jobs and CEF before consuming approved destructive intent once. Merely setting a clear flag never authorizes deletion.

Schema v5 adds app_uninstall_jobs. Integration files are reversibly staged, unpinning is checked, and unregistration plus the original keep/delete choice commits atomically. Irreversible profile deletion runs last under the app lease. Failed committed cleanup retains a retry job; reinstall is refused until cleanup finishes.

The OSR surface exposes real CEF accessibility updates through GTK Accessible and AccessibleText virtual nodes. Tree IDs qualify node IDs across frames; protected values are suppressed. Names, roles, states, text, caret/selection/focus, live updates and supported geometry reach AT-SPI. Location patches update bounds without rebuilding a synthetic DOM tree. Direct AX actions/selection editing have no pinned public CEF dispatch API; unsupported transformed/frame/character geometry returns unknown. No coordinate-click accessibility actions are invented.

GTK4 drag controllers and Gdk.Drag carry CEF source formats and engine drop-target operations. Private bounded image files have a five-minute receiver grace period. Raw input preserves application accelerators, one IM commit path, UTF-16 offsets, focus cancellation, pointer leave and surface scale. Real X11 pointer/key/clipboard fixtures qualify these paths; native Wayland is a separate gate.

Task Manager retains its CEF observer while open, rather than rebuilding it every refresh. This permits asynchronous measurements and termination to complete. It exposes task IDs/types, process-wide CPU, memory/GPU metrics, aggregate flags and current-page association. Zero/negative memory is conservatively unavailable. No PID, network or explicit-parent fields are fabricated.
