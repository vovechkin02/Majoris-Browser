# Implementation status

This repository does not yet fulfill every requirement of the supplied task. It must not be marketed or packaged as a release-ready browser based on the current smoke tests.

Implemented paths include:

- Meson build, Vala/GTK4/libadwaita application, CEF C ABI/VAPI, dedicated subprocess, runtime resource staging and license notices.
- Actual Chromium navigation/rendering, multiple reorderable/pinned tabs, reopen, duplicate, navigation and common keyboard actions.
- Structured bookmarks/history/session/app registry stores, migration/version guard, transactions and a storage worker.
- Private in-memory contexts, private history/session exclusion and shared private context per window.
- Ordinary website installation, same-origin manifest discovery/fetch and name/start URL/scope validation, stable app IDs, desktop entries, separate GTK identities and process lifetimes.
- Scope-aware external navigation, temporary user-approved recognized authentication origins, GNOME dock pin integration and app uninstall retaining data.
- Full normal-profile clearing after shutdown, independent closed-app profile clearing, exclusive profile leases and symlink-root refusal.
- GTK JavaScript/permission/file/download destination dialogs, native context menu actions, download progress/open/pause/resume/cancel, find/zoom/fullscreen/print/DevTools.
- Secret Service save/update/delete and explicit current-site username/password fill. This is not yet an automatic password manager.
- CEF Task Manager task types, CPU/memory metrics and task termination; GTK settings and native history/bookmarks/downloads views.

Release-blocking unfinished work:

1. The mandatory authenticated Google Sheets/Majoris dock scenario has not been manually verified. Provider-specific OAuth redirect chains, popup opener behaviour and independently launched app data need qualification on the target desktop.
2. The surface is OSR-only. Native high-performance embedding, complete Wayland/HiDPI qualification, IME preedit/composition ranges, drag/drop, custom cursors and a CEF accessibility-tree adapter remain unfinished. GTK accessibility covers only the native controls today.
3. Automatic form detection, save/update prompting, never-save policy, authenticated credential enumeration/view, address autofill and secure browser-password importing remain unfinished. The implemented manual credential dialog depends on an available Secret Service.
4. Persistent per-origin permissions, explicit camera/microphone/geolocation handling across all CEF permission callbacks, certificate details, site-specific data inspection, third-party-cookie preferences and full GTK HTTP authentication/print integration need completion. Permission prompts currently use a numeric CEF permission mask; default engine denials remain in place for unsupported callbacks.
5. Session snapshots currently track the last window rather than a complete multi-window session generation. Navigation stacks, atomic crash-generation bookkeeping, active/pinned/reorder change coverage and configured startup-page lists need completion.
6. Omnibox local/open-tab/remote suggestions, paste actions, tab search, favicons/audio indicators, bookmark folders/editing/bar and first-run/import workflows are incomplete.
7. App icons are generic. Manifest icon selection/download/validation, theme metadata, allowed-origin metadata, notification identity/click activation, unpin UI and uninstall-with-data-removal choice remain unfinished.
8. Download retry, persistent metadata, dangerous/incomplete-state handling, accurate speed/time reporting and complete context-sensitive GTK menus (images, selections, spellchecking) need completion. Print/source/DevTools rely on CEF engine support and need target-platform visual verification. Picture-in-picture and Save Page are not implemented.
9. Settings currently expose a subset of specified categories. UA Client Hints branding is not overridden. Task Manager lacks PID/network columns because the selected CEF task-info structure does not expose them directly.
10. Packaging needs installation QA on real Debian/Majoris, security update ownership, sandbox policy review, translations/catalog installation and full AppStream validation.

Tests cover the implemented paths, not every item in the specification. The tests do not certify all site data types, real provider sign-in, Wayland desktop grouping, all permissions or password-manager security. No test disables sandboxing or web security. Extension compatibility, cloud sync and the explicitly excluded Brave features are intentionally outside scope.
