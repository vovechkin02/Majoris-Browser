# Completion matrix

Updated 18 October 2026. This remains a development build. The complete supplied specification is not yet satisfied. Implemented code and executed verification are distinguished below.

| Area | Implemented paths | Evidence / remaining work |
|---|---|---|
| Architecture | Existing GTK4/Vala/libadwaita, C ABI/VAPI, CEF subprocess and SQLite worker preserved | Full build and real GTK/CEF tests; pinned CEF 152.0.14 / Chromium 152.0.7977.167, Linux x86-64. |
| Scoped clearing | Host/domain cookies at all paths; origin storage through CDP; separate closed-profile clearing | Real Secure/HttpOnly/domain cookie and localStorage/IndexedDB/Cache Storage/service-worker/cache isolation tests. CHIPS/storage-key qualification and exact-origin HTTP-cache clearing remain incomplete; closed-profile clearing is the explicit full-data fallback. |
| Installation | Registry and validated icon precede atomic launcher publication; rollback; duplicate ID rejection | Domain rollback and GTK manifest/PNG installation tests. Process-kill fault injection at each publication step remains untested. |
| Tabs/navigation | Reorder, pin, duplicate, reopen, transfer, close others/right, tab search, favicon, loading/stop, Home and history controls | GTK/CEF tests. WebAudio-only audibility and all tab gestures remain unqualified. |
| Omnibox | Local history/bookmark/open-tab suggestions, keyboard selection, paste actions, opt-in bounded HTTPS suggestions | Builds and smoke coverage. Dedicated keyboard/provider tests remain incomplete. |
| Bookmarks | CRUD, folders, HTML round trip, Chromium JSON import, bar/dropdowns/context menus, persisted drag order, scrolling overflow | Domain folder/order/import tests. Drag gestures still need desktop visual QA. |
| Downloads | UUID history; source/path/time/bytes/status/error; pause/resume/cancel/retry/remove/open/show; destination settings; close handling | Real streaming download/control/persistence test. CEF does not expose a complete Safe Browsing danger verdict; none is fabricated. |
| Sessions | Generation-guarded normal-window snapshots; active/pinned/ordered tabs, geometry, selected window, clean marker/crash prompt and startup modes | Domain stale-write test; GTK two-window/private-exclusion snapshot test. Serialized Chromium navigation-stack import is not available through the public CEF history API. |
| Credentials | Isolated HTTPS main-frame observer; trusted form submission; conservative navigation outcome; consented save/update/never/not-now; multiple-login selection and origin-checked fill | Real trusted HTTPS and disposable Secret Service test checks profile isolation, wrong-origin refusal, hidden binding, fill and submission/outcome. Generic SPA/iframe login detection remains incomplete. |
| Password settings | Search/delete/update; PolicyKit-gated reveal; never-save exceptions | Secret Service tested. PolicyKit interaction requires a desktop authentication agent and remains manually unverified. |
| Address autofill | Non-secret profiles and explicit fill of current HTTPS autocomplete fields | Persistence tested; address-form interoperability/UI selection need manual QA. No payment-card storage. |
| Permissions | Profile/origin/type ask/allow/block; expiry/reset; once/always prompts; preload and live Chromium content-setting synchronization; running-app reload action | Domain isolation/expiry and real renderer persisted allow/app deny, live revocation and reset tests. Cross-process reload, physical devices, geolocation provider and every callback remain unqualified. Desktop capture is denied without a source chooser. |
| Security/settings | Real TLS/certificate/mixed-content status; third-party-cookie/HTTPS preferences; system/custom proxy; acceleration restart setting | Runtime preference acceptance tested. Live blocking/upgrades/proxy auth and certificate UX need broader tests. |
| App metadata/identity | Manifest scope/start/icons/theme, CEF image decoding, favicon/generated fallback, unique desktop/GApplication identity | Actual PNG/manifest and separate-process GTK tests. Majoris dock/Alt+Tab/icon presentation remain manual gates. |
| App management | Open, rename, icon update, asynchronous profile size, permissions, pin/unpin, clear, uninstall with/without data | Install/clear/lease foundations tested. Management UI and all rollback paths need further coverage. |
| App lifecycle | Independent process/root; Browser shutdown leaves app running; deferred tab/window closes honor beforeunload consent | Concurrent GTK Browser/app acceptance test and real unsaved-page Stay/Leave regression. Multi-tab cancellation UX needs further desktop qualification. |
| Popups/auth | Genuine Chromium opener/context; app-scoped windows/external routing; bounded consented auth origin; generic validated code flow; cancellation | Real popup opener/storage and policy tests. Live Google/Microsoft/Spotify restrictions and authenticated Sheets remain unverified. |
| Notifications | Genuine Chromium web API and desktop D-Bus display/click/close; app desktop-entry and display-name attribution | Desktop-protocol test. Majoris icon/window focus and service-worker workflows need further qualification. No closed-app background push broker. |
| GTK dialogs/menus | JS defaults, HTTP auth, file modes/filters, download chooser, page/link/media/edit menus, app menus | GTK smoke and native callbacks. Complete clipboard, spellcheck, all contexts and cancellation coverage remain unfinished. |
| OSR | One IM commit path, UTF-16 preedit/caret, fractional scale, incoming file/text drops, in-content errors/crashes, reduced frame copying | Real rendering and Japanese/emoji input test. Outgoing drag/drop, actual hardware-input coverage and a complete web accessibility/AT-SPI adapter remain unfinished. |
| Page/media actions | Native CEF print callbacks to GTK; PDF and MHTML export; PiP request | Actual PDF/MHTML test. Printer/PDF-viewer/JS-print UI, PiP, codecs, WebRTC and DRM need target qualification. No DRM keys or provider bypasses. |
| Task Manager | Real task types/CPU/memory, sorting and termination | GTK smoke. Public CEF task info lacks PID/network fields; UI explicitly says unavailable. |
| Browser identity | Linked-engine UA and Majoris UA/Client Hints branding; runtime version | Real renderer UA/UA-CH test. HTTP-header/high-entropy coverage should be broadened. |
| First run/import | Search/default choice, skip/import, HTML/Chromium JSON, closed Chromium/Firefox history snapshots | Source-import regression verifies unchanged source bytes and refuses active WAL. Secure password import is unavailable. |
| Packaging | Meson/runtime installation, Debian metadata, test dependencies, hardened subprocess entry, sandbox permissions and reproducible verification scripts | Fresh-source and hardened Debian builds passed all 10 suites. Archive ownership/modes/resources/search paths and extracted-package GTK/CEF smoke passed. Real Majoris/Debian system installation/upgrade remain release gates. |

## Unresolved gates

The accessibility adapter, outgoing drag/drop and some input/menu/credential workflows are unfinished engineering work, not claimed upstream impossibilities. They must be completed before release.

SDK limitations are narrower: task info lacks PID/network metrics, history lacks serialized stack import, and download items lack a complete danger-verdict API. Partitioned storage needs further qualification. Unsupported selective clearing must use the explicit closed-profile fallback rather than deleting live files.

The mandatory Sheets scenario requires a consenting user on Majoris: install/pin, authenticate, restart, close Browser, clear Browser data, confirm Sheets stays signed in, and verify external navigation and desktop identity. The user confirmed that a Majoris desktop is unavailable; Sheets sign-in, dock identity and native Wayland checks are recorded as unverified. No live account credentials have been used. Fixtures do not certify this scenario.

Excluded Brave services, cloud sync, AI, tree tabs, extension-store integration and custom DevTools were not added.
