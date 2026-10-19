# Majoris GNOME/Wayland and system release qualification

Status: unverified. The user has confirmed the target desktop and authorised
provider accounts are unavailable. Xvfb, local OAuth fixtures and extracted
packages do not establish these results. Record date, operator, OS/compositor,
GPU/driver, monitors/scales, package/engine hashes and each actual outcome.

1. On disposable Debian 13/Majoris, install the development package with apt;
   check declared dependencies, first launch, profile permissions, schema
   registration, desktop/MIME entries and actual loaded libcef checksum.
2. Create browser bookmarks/history/settings and two installed apps. Upgrade
   from 0.1.0-7 to the candidate; verify SQLite migrations, stable desktop IDs,
   icons, scopes, separate cookies/storage/permissions and authenticated state.
   Ordinary removal must retain user profiles. Never test destructive purging
   against the operator's daily profile. A lower engine version must refuse
   the protected profile without erasing data; restore only a compatible backup.
   Binaries predating this guard cannot enforce its marker retroactively. The OS
   release policy must prevent rollback to those builds; such downgrades are
   unsupported. Equal-version maintenance backports do not change profile format.
3. Confirm GTK is GdkWaylandDisplay and CEF child command lines select Wayland,
   without sandbox/TLS/origin bypass switches. Check renderer seccomp/no-new-
   privileges. Compare X11 in a separate profile; do not downgrade a profile.
4. At 100%, 125%, 150%, 200% and across mixed-scale monitors, exercise Unicode,
   IME preedit/commit/cancel/candidate placement, dead keys, keyboard-only focus,
   smooth touchpad and wheel scrolling, clipboard, drag/drop, file uploads,
   resize/fullscreen, monitor changes, and light/dark Majoris Theme.
5. Enter native PiP in browser, app A, app B and private windows. Inspect Wayland
   app_id and match each desktop entry. Verify pixels, resize, focus, Alt+Tab,
   dock grouping, source navigation/close, renderer and GPU failure cleanup.
   Record compositor policy on stacking/activation; do not bypass it with hacks.
6. Install Google Sheets, inspect its icon/desktop entry, pin it, close Browser,
   launch from the dock, sign in using an authorised account, close/restart and
   verify session persistence. Clear only Browser cookies/data and confirm
   Sheets remains signed in. Unrelated external links must open Browser;
   approved authentication must remain app-owned. Repeat independent closure
   in both directions and simultaneous apps. Repeat real Excel/Outlook/provider
   compatibility only with authorisation; never record passwords or tokens.
7. With Orca, traverse headings/links/frames/forms/live regions; activate/focus,
   edit Unicode, verify dynamic node replacement and transformed bounds at
   fractional scales. Verify protected values never leak. Test native selection
   actions and document GTK 4.18's unsupported direct Text selection/caret
   setters accurately. No guessed-coordinate accessibility action is permitted.
8. On authorised hardware verify physical audio/video output separately from
   software decoding, and hardware decoding separately from codec/DRM support.
   Widevine stays unavailable without a permitted CDM, compatible supported
   integration and actual protected playback; it is optional for release.
9. Qualify the authorised threat backend and optional clamd deployment using
   harmless fixtures, provider failures, token rotation, stale signatures,
   stopped services, cancellation and shutdown. No live service is bundled.

Production remains blocked by unresolved engine security deltas, missing codec
redistribution authorisation and required unperformed target/install/upgrade
checks. Populate the separate release record with actual reviews and evidence;
do not promote a development artifact automatically.
