# Engine security maintenance

Majoris Browser and its distributing OS/package maintainer must maintain the bundled CEF engine. The current development pin is not a promise of ongoing security support. Do not release an engine pin merely because compilation and fixtures pass.

For each release, the maintainer must review upstream Chromium and CEF security advisories and available supported CEF builds, select an appropriate fixed engine, and record the exact CEF/Chromium versions and review date in the release verification results. Known applicable security fixes block release until incorporated or a documented mitigation is reviewed. This repository has no automated engine updater or established response-time service agreement.

An engine upgrade changes the explicit pin and digest in `scripts/bootstrap-cef.py`. Meson must not download a replacement silently. The bootstrap checks the publisher's pinned SHA-1 over HTTPS for corruption; this is not a modern cryptographic publisher signature. Record the upstream artifact provenance and any stronger verification available for the replacement. Never weaken sandbox, TLS, origin checks or site isolation to accommodate a new SDK.

Build the wrapper against the selected SDK and requalify C ABI/VAPI calls, subprocess/resource discovery, sandbox operation, persistent versus private contexts, profile leases/deletion, cookies and all storage tests. Run the complete fresh-source suite, package/staged-runtime checks, native Wayland/X11 input and accessibility checks, and the consenting-user Sheets isolation scenario. Update notices and redistribution materials with the shipped SDK. Keep release artifacts tied to their source revision and engine provenance.

Security-sensitive regressions must be fixed and retested before distribution. A passing test suite is evidence for its fixtures and environment, not proof of complete browser security or provider compatibility.
