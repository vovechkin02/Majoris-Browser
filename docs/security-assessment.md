# Engine security assessment

Source: main `82684a8c265def0cd06d34d75272cb8e5076ce99`, verified against origin/main before modification. The selected SDK remains CEF 152.0.14 / Chromium 152.0.7977.167. `scripts/audit-cef.py --cef-root .cef --online` records actual header/archive provenance and the official Linux publisher index without installing anything. The captured record is `build/production-engine-audit.json`.

Refreshed on 18 October 2026 at 09:28 UTC, with both archive digests matching the pin. The publisher still offers `.167` as the newest Linux M152 stable SDK. Newer M156 entries are beta; M154 is legacy according to the supported-branch policy. M150 LTC is an older-major candidate, not a demonstrated backport solution for these fixes; downgrading live Chromium profiles is not a safe automatic mitigation. No suitable fixed production SDK was established in this review, so the pin is unchanged rather than replaced with a larger version number.

The [15 October Extended Stable advisory](https://chromereleases.googleblog.com/2026/10/extended-stable-update-for-desktop_01598036246.html) identifies ten fixes in 152.0.7977.169. Its distribution statement names Windows/Mac. That alone neither proves nor disproves Linux/CEF applicability. Authoritative Chrome CNA records were retrieved through the [CVE Program API](https://cveawg.mitre.org/api/cve/CVE-2026-110151), saved in `build/production-cve-assessment.json`. They identify components and a Windows-specific case, but no verified backport into the shipped SDK; the new patch mapping below identifies authoritative fixes after its pin. The position remains **unresolved**, not fixed or dismissed:

| CVE | Severity / component | CNA main-branch fixed version | Current CEF Chromium | Linux applicability | CEF applicability | Verified backport | Mitigation / status |
|---|---|---|---|---|---|---|---|
| CVE-2026-110151 | Critical / Media | 155.0.8059.79 | 152.0.7977.167 | Potential shared Linux code | Potential OSR media reachability | None established | Unresolved; no verified mitigation for potentially shared code |
| CVE-2026-110922 | Critical / Prerender | 155.0.8059.84 | 152.0.7977.167 | Platform unspecified | Exact pinned Alloy source disables prerender; shared navigation patch still relevant to review | None established | Unresolved; no verified mitigation for potentially shared code |
| CVE-2026-110144 | High / Mojo | 155.0.8059.79 | 152.0.7977.167 | CNA explicitly Windows | Outside Linux package platform | None established | Platform exclusion; no verified mitigation for potentially shared code |
| CVE-2026-110159 | High / Updater | 155.0.8059.79 | 152.0.7977.167 | Local updater component | No Google Updater executable shipped | None established | Component exclusion; shared-code review remains; no verified mitigation for potentially shared code |
| CVE-2026-110166 | High / Animation | 155.0.8059.79 | 152.0.7977.167 | Potential shared Linux code | Potential Blink reachability | None established | Unresolved; no verified mitigation for potentially shared code |
| CVE-2026-110172 | High / Media | 155.0.8059.79 | 152.0.7977.167 | Potential shared Linux code | Potential OSR media reachability | None established | Unresolved; no verified mitigation for potentially shared code |
| CVE-2026-110913 | High / DOM | 155.0.8059.84 | 152.0.7977.167 | Potential shared Linux code | Potential Blink reachability | None established | Unresolved; no verified mitigation for potentially shared code |
| CVE-2026-110918 | High / Core | 155.0.8059.84 | 152.0.7977.167 | Potential shared Linux code | Potential renderer reachability | None established | Unresolved; no verified mitigation for potentially shared code |
| CVE-2026-110919 | High / V8 | 155.0.8059.84 | 152.0.7977.167 | Potential shared Linux code | Potential JavaScript reachability | None established | Unresolved; no verified mitigation for potentially shared code |
| CVE-2026-110921 | High / V8 | 155.0.8059.84 | 152.0.7977.167 | Potential shared Linux code | Potential JavaScript reachability | None established | Unresolved; no verified mitigation for potentially shared code |

These are component/platform inferences from the CNA records, not exploit reproduction or proof that all shared-code issues affect this exact build. CNA version ranges refer to the main release branch; the Extended Stable advisory is the evidence for the M152 fix delta. Disabling proprietary codecs does not establish that all Media issues are unreachable. Upstream [Alloy prerender policy](https://github.com/chromiumembedded/cef/blob/master/libcef/browser/alloy/alloy_browser_host_impl.cc) reduces one feature's reachability, but is not represented as a verified backport or blanket mitigation.

Sandboxing, seccomp/no-new-privileges, denied TLS errors, scoped permissions and isolated profiles remain enforced and regression-tested. They are defence layers, not proof that these flaws are mitigated. A reputation provider would not repair a vulnerable engine. Disabling JavaScript or weakening isolation is not adopted as a substitute for a browser security update.

Production distribution remains blocked until a maintainer obtains a fixed supported SDK or authoritative component/platform/backport evidence sufficient to resolve every applicable fix. Then update both publisher integrity data and independent SHA-256, rebuild the wrapper, rerun all 25 suites and package/runtime checks, and perform target-desktop qualification. Do not infer release approval from a successful development package.


## Current source/patch qualification (main 82684a8)

The exact SDK source at CEF 8a0b5b99fd4aac7e353f847685be05577298970c was retrieved (build/production-source-1.txt), not inferred from master. `IsPictureInPictureSupported` returns false for windowless views, and `IsPrerender2Supported` returns kPreloadingDisabled. The latter reduces exposure but does not prove the shared BeginNavigation fix irrelevant. The original public headers still provide AX tree/location callbacks rather than node-action dispatch, navigation enumeration rather than serialized history import, and no trustworthy PID/network/parent task metrics. No unsupported behavior is emulated.

The authoritative [Chromium .167→.169 Gitiles log](https://chromium.googlesource.com/chromium/src/+log/152.0.7977.167..152.0.7977.169) was retrieved in full: 12 commits, no continuation. Metadata, patches and V8 dependency rolls are retained in build/production-security-commits.json, production-patch-evidence.json and production-v8-evidence.json. Issue-number matches connect these upstream M152 fixes to the advisory; they are not evidence that the pinned .167 binary contains them.

| CVE | Advisory issue | Authoritative M152 fix / dependency |
|---|---|---|
| CVE-2026-110151 | 570638834 | 8f6b08ed92cf26ea7c6b877fa7e03033e091acc8; media pipeline and Blink WebMediaPlayer shutdown |
| CVE-2026-110922 | 568719351 | 25c50eee95a76ca35a2db5760f16279400472bfb; shared navigation self-deletion guard |
| CVE-2026-110144 | 565252396 | 007113ee58660d0702a994b225649ea2ca120256; Mojo/updater trust validation, Windows-specific CNA applicability |
| CVE-2026-110159 | 564573066 | Same 007113ee58 patch; updater plus shared named-Mojo code; packaged updater absent, not a blanket shared-code exclusion |
| CVE-2026-110166 | 566496747 | 53e5354f38702e4f06951ca1184e813e7742fca1; Blink animation interpolation |
| CVE-2026-110172 | 568719352 | c46b9381b0d9dc18f8a5c00b4d6d9d5b9c5c3392; Blink WebMediaPlayer callback cancellation |
| CVE-2026-110913 | 567638392 | 2c141ff11a42d4dd74d00d7181ed88f49e5e8975; Blink DOM identifier lifetime |
| CVE-2026-110918 | 568937999 | 14eacc365cc2d2bdb15f8b2a4f4850d697823cbe; content TextInputManager lifetime |
| CVE-2026-110919 | 568831769 | V8 027c77f80106eebd534966532da12df501155ab6, rolled by Chromium 72af4a3518a8e57de2c65da5e45f13b68a78b4e5 |
| CVE-2026-110921 | 569286602 | V8 7a76911801b8648e1c85312fccff6bb6211666e7, rolled by Chromium 73cff6ea543eb7d6286bb4afeac6de9b412db32b |

Media, animation, DOM and content patches change shared renderer/content sources and are not limited to proprietary codecs. The combined Mojo/updater patch includes Linux/Mac stubs and Windows trust/handle guards; the Windows-specific CNA is useful evidence for 110144, while 110159 still requires careful component/reachability assessment. The V8 deserializer and Maglev fixes are platform-independent code paths potentially used by this embedder. These findings strengthen the release blocker; no exploit reproduction or complete vulnerability reachability proof is claimed.

## Maintained custom-runtime feasibility

The exact official automate-git.py was inspected (build/production-custom-automate.txt): it supports explicit `--branch`, `--checkout` and `--chromium-checkout` overrides. Branch 7977 advertises the same CEF commit as the SDK. The .169 tag's DEPS and maintenance log were retrieved through Gitiles, including both V8 rolls. A Git transport probe for the Chromium tag stalled and was stopped; HTTP source retrieval does not qualify a complete build checkout. This environment has approximately 953 GiB scratch capacity, 30 GiB RAM plus 8 GiB swap and 16 logical CPUs, so source compilation is technically plausible. No custom CEF SDK was built or qualified in this pass.

A maintainable candidate would use the supported CEF M152 branch with the complete upstream Chromium 152.0.7977.169 maintenance tag (including DEPS/V8), through the inspected official tool's checkout override, rather than copying selected patch hunks or binary-patching libcef. Before adopting it, an accountable engine maintainer/build operator must qualify the full checkout, CEF compatibility patches and matching generated headers, subprocess/wrapper, reproducible archive/SHA-256/notices, platform sandbox and all 25 suites through the existing cef_root/clean/package workflow. The default bootstrap must only be repinned to that actual qualified artifact; a build command or available hardware is not an integrated secure runtime. Ongoing supported branch/security-response ownership remains required. A one-off unqualified source build would not resolve that maintenance requirement.

The precise remaining gap is therefore an actual maintained, built and qualified Linux CEF runtime containing these upstream fixes (or authoritative per-component exclusions), not lack of known upstream patch identities. The current official supported M152 artifact remains .167. The current pin is retained as development-only, and production approval stays blocked. Licensed H.264/AAC settings and vendor DRM remain independent requirements, not automatic consequences of a security rebuild.

Final publisher recheck: 19 October 2026 at 06:54 AEDT (18 October 19:54 UTC), recorded in build/production-engine-audit-release.json, still lists the same M152 .167 supported artifact. No new fixed qualified SDK became available during verification.
