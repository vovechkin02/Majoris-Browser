# Release gate

Run the full Meson suite on Debian 13 with a freshly bootstrapped SDK. Repeat on native Wayland and X11 environments, and under upstream Adwaita as well as Majoris Theme. Verify installation from a staging directory, runtime lookup without SDK paths, subprocess execution, CEF notices, desktop MIME associations and sandbox configuration.

The supplied task's manual scenario remains mandatory and unexecuted: install Google Sheets, pin it, close Browser, launch Sheets from the dock, authenticate, restart Sheets, clear an independent normal Browser session, and confirm Sheets remains signed in. Verify external links open Browser, dock/Alt+Tab identities differ, Browser closure leaves Sheets running, and clearing closed-app Sheets data leaves Browser data unchanged. Repeat DevTools, context menus, file selection and permission UI checks.

Use a consenting human's account for authentication; never embed credentials in tests or fixtures. Deterministic fixtures live in tests/fixtures and run through a loopback-only test HTTP server. Check localStorage, IndexedDB, Cache Storage, service-worker storage and HTTP cache in addition to cookies before qualifying the full data-clearing feature.

Reject release while any release-blocking item in implementation-status.md remains unresolved. Record actual results and engine/platform versions rather than treating a checked-in checklist as evidence of manual verification.
