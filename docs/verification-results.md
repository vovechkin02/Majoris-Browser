# Verification results — 17 October 2026

Environment: Debian 13 under WSL, Vala 0.56.18, GTK 4.18.6, libadwaita 1.7.6, Meson 1.7.0, GCC 14.2.0. Engine: pinned CEF 152.0.14 / Chromium 152.0.7977.167. Chromium sandboxing remained enabled.

Executed successfully:

1. Full Meson configure and compilation of Browser, native bridge and subprocess helper.
2. Domain suite: URL resolution, app scope, bounded authentication candidates, manifest validation, SQLite persistence/private exclusion/session storage, future-version rejection, profile paths, registry identity and tab ordering/reopening.
3. Real CEF suite: cookies in independent contexts; normal-cookie clearing preserves the app cookie; app-cookie persistence across engine restarts; closed-profile deletion preserves its sibling; running-profile deletion is rejected; symlink-root deletion is rejected; private context does not create a persistent context directory.
4. GTK smoke suite with disposable XDG storage and a loopback fixture server: load/render a page; install its manifest app through GTK; validate registry metadata and generated desktop entry; open preferences/history/downloads/Task Manager; close Browser cleanly; launch/render/close the installed app as a separate process.
5. Staged Meson installation into build/stage, followed by the same GTK/CEF smoke workflow using the staged executable, helper and bundled libraries. LD_LIBRARY_PATH was used only to relocate the staged prefix; installation into the real system prefix was not performed.

Final Meson result: **3 suites passed, 0 failed**. Detailed transient logs are in build/test.log, build/meson-logs/testlog.txt, build/install.log and build/staged-smoke.log. Build/SDK/staging outputs are ignored by Git.

Not verified: authenticated Google Sheets, actual Majoris dock and Alt+Tab grouping, native Wayland desktop interaction, live Secret Service save/fill interoperability, full permission/device APIs, every web-storage type, complete menu/print/file-dialog visual behaviour, or a real Debian package installation. See implementation-status.md; these results do not close the release gate.
