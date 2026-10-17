# Architecture and engine contract

The GTK/Vala layer owns windows and product UI. `BrowserSurface` isolates the GTK product from the rendering implementation. `OffscreenBrowserSurface` transfers BGRA frames to GDK memory textures and forwards input to CEF. Native window hosting is not implemented yet; no X11 window handle enters the Vala application.

`libmajoris-cef` exposes a GObject-based C ABI and a Vala VAPI. Only `mc_*` symbols are exported: Chromium and wrapper C++ implementation symbols must not interpose on each other. Hosts link libcef directly (retained with `--no-as-needed`) so Chromium's libc interposition can resolve symbols in the correct order.

CEF 152.0.14 (`g8a0b5b9`), Chromium 152.0.7977.167, Linux x86-64, is the initial pinned SDK. This pin requires security maintenance; version selection alone is not evidence of future security support. No Chromium/CEF patches are applied. The bootstrap verifies upstream's published SHA-1 digest over HTTPS; upstream does not publish a modern signed digest in this build record.

Chrome bootstrap creates Alloy-style offscreen browser instances. First-run Chrome UI is disabled through standard startup switches. The tested integration uses CEF's multithreaded Linux message loop. No periodic engine polling runs. CEF UI work is posted with CefPostTask; callbacks enter GTK through attached GLib sources. Sources are attached explicitly because g_main_context_invoke may execute immediately on an acquiring worker thread.

Frames have a bounded latest-frame mailbox. Popup surfaces are composited with the view. Widget resize and scale changes inform CEF. Input controllers forward pointer, wheel, focus, keys and IM commits. Fullscreen, cursors and tooltips cross the event boundary. Advanced IME preedit, drag/drop and accessibility are not yet complete.

Closing a view requests CEF closure. Runtime shutdown continues the main context until every browser has emitted OnBeforeClose, then calls CefShutdown on the initializing thread. SQLite jobs drain before application exit. A per-runtime filesystem lease stays outside the profile directory; destructive clearing requires the same exclusive lease. All app profiles remain under one controlled XDG parent, but each separate app process has its own CEF root to avoid ProcessSingleton conflicts.

CEF Chrome profiles support the runtime root itself or immediate child directories. Production apps use the root itself; the cookie regression uses sibling immediate children in one test runtime. Nested profiles must not silently fall back to off-the-record storage. Profile layout and data deletion must be requalified on any engine upgrade.

SQLite migrations use user_version and transactions. Store instances are confined to a single storage worker. Results return through GLib idle callbacks. Large profile deletion runs off the GTK thread. Secrets use libsecret; saved credentials are keyed by profile, origin and username. Filling checks the current main-frame HTTPS origin again immediately before injecting values, and does not submit forms.

Web-app scope checks use parsed origins and path boundaries. Recognized authentication candidates require an in-scope return URL; OAuth candidates also require client ID and state. GTK consent grants one exact HTTPS provider origin for at most 120 seconds. Returning to app scope revokes it. This deliberately conservative policy needs provider-specific manual testing and does not recognize every OAuth workflow.

The supplied Brave archive was inspected as a lifecycle/architecture reference, including browser/brave_browser_main_parts.cc and browser/brave_browser_process_impl.cc. No Brave code, UI or services were copied. Public CEF APIs supply the engine integration.

Upstream references: [CEF general usage](https://github.com/chromiumembedded/cef/blob/master/docs/general_usage.md), [automated binary distributions](https://cef-builds.spotifycdn.com/index.html), and [Chrome request-context profile handling](https://github.com/chromiumembedded/cef/blob/master/libcef/browser/chrome/chrome_browser_context.cc).

Future extension, notification, tracking-prevention and sync adapters belong behind application services; none may expose arbitrary native capabilities to web content. Native Wayland hosting can replace the surface without changing BrowserWindow or WebAppWindow.
