# Engine security assessment

Source: main `ff562f916110e9744d6d09b20c95984a2b5c92c7`, verified against origin/main before modification. The selected SDK remains CEF 152.0.14 / Chromium 152.0.7977.167. `scripts/audit-cef.py --cef-root .cef --online` records actual header/archive provenance and the official Linux publisher index without installing anything. The captured record is `build/remaining-engine-audit.json`.

The publisher still offers `.167` as the newest Linux M152 stable SDK. Newer M156 entries are beta; M154 is legacy according to the supported-branch policy. M150 LTC is an older-major candidate, not a demonstrated backport solution for these fixes; downgrading live Chromium profiles is not a safe automatic mitigation. No suitable fixed production SDK was established in this review, so the pin is unchanged rather than replaced with a larger version number.

The [15 October Extended Stable advisory](https://chromereleases.googleblog.com/2026/10/extended-stable-update-for-desktop_01598036246.html) identifies ten fixes in 152.0.7977.169. Its distribution statement names Windows/Mac. That alone neither proves nor disproves Linux/CEF applicability. Authoritative Chrome CNA records were retrieved through the [CVE Program API](https://cveawg.mitre.org/api/cve/CVE-2026-110151), saved in `build/remaining-cve-assessment.json`. They identify components and a Windows-specific case, but no verified patch/backport record for this SDK. The position remains **unresolved**, not fixed or dismissed:

| Advisory identifier | Severity reported | Linux / embedded applicability | Verified backport to this SDK |
|---|---|---|---|
| CVE-2026-110151 | Critical | Media; no platform restriction in CNA; potentially relevant to Linux embedding | None established |
| CVE-2026-110922 | Critical | Prerender; upstream Alloy disables prerender, but exact-pin reachability/backport unqualified | None established |
| CVE-2026-110144 | High | CNA explicitly Windows Mojo; outside this Linux package's platform | Not claimed; Linux platform exclusion |
| CVE-2026-110159 | High | Updater; no Google/Chrome updater executable is shipped in this package; component-level assessment remains separate | None established |
| CVE-2026-110166 | High | Animation; platform-unspecified, potentially relevant | None established |
| CVE-2026-110172 | High | Media; platform-unspecified, potentially relevant | None established |
| CVE-2026-110913 | High | DOM; platform-unspecified, potentially relevant | None established |
| CVE-2026-110918 | High | Core; platform-unspecified, potentially relevant | None established |
| CVE-2026-110919 | High | V8; platform-unspecified, potentially relevant | None established |
| CVE-2026-110921 | High | V8; platform-unspecified, potentially relevant | None established |

These are component/platform inferences from the CNA records, not exploit reproduction or proof that all shared-code issues affect this exact build. CNA version ranges refer to the main release branch; the Extended Stable advisory is the evidence for the M152 fix delta. Disabling proprietary codecs does not establish that all Media issues are unreachable. Upstream [Alloy prerender policy](https://github.com/chromiumembedded/cef/blob/master/libcef/browser/alloy/alloy_browser_host_impl.cc) reduces one feature's reachability, but is not represented as a verified backport or blanket mitigation.

Sandboxing, seccomp/no-new-privileges, denied TLS errors, scoped permissions and isolated profiles remain enforced and regression-tested. They are defence layers, not proof that these flaws are mitigated. A reputation provider would not repair a vulnerable engine. Disabling JavaScript or weakening isolation is not adopted as a substitute for a browser security update.

Production distribution remains blocked until a maintainer obtains a fixed supported SDK or authoritative component/platform/backport evidence sufficient to resolve every applicable fix. Then update both publisher integrity data and independent SHA-256, rebuild the wrapper, rerun all 23 suites and package/runtime checks, and perform target-desktop qualification. Do not infer release approval from a successful development package.
