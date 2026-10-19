> **Current release-hardening record (0.1.0-8):** [release-hardening.md](release-hardening.md). Reviewed source: `27611aa41c806398fb0560aded3853a2a9ba53ec`. The security candidate retains four Majoris patches and adds twelve patches covering thirteen upstream maintenance/security commits. The candidate build, clean 30/30, Debian 30/30 and extracted-runtime verification passed locally. Production, redistribution and native-desktop approval remain pending. Earlier dated completion claims below are historical and do not qualify this candidate.

## Current candidate decoding result

The sixteen-patch candidate passed actual H.264, AAC and combined MP4 decoding
in browser and installed-app contexts, alongside VP8/VP9/Opus/WebM, in both the
clean 30/30 and Debian 30/30 suites. Its SDK/library/package hashes and exact
logs are in [verification results](verification-results.md). Software decoding
does not establish physical output, hardware acceleration, DRM or redistribution
rights; those remain distinct qualifications.

## Current redistribution review inputs

The exact generated `CREDITS.html` in the selected SDK is the complete runtime
third-party notice inventory; `engine/releases-license-inventory.json` records
its hash alongside CEF/Chromium notices, pinned FFmpeg source and the selected
configuration flags. Regenerate this inventory for every newly built runtime.
The Browser is GPL-3.0-or-later, the Majoris engine extensions are BSD-3-Clause,
and Chromium/CEF contain separately licensed components. Debian's copyright
file preserves those distinctions and installs the full SDK notices. Debian
buildinfo records the build environment; system shared-library dependencies
retain their own Debian copyright/source obligations.

Authorised counsel/release maintainers must inspect the pinned FFmpeg per-file
licences (BSD-2-Clause, BSD-3-Clause, ISC, LGPL-2.1 and MIT), generated component
selection, modifications and corresponding source. They must determine notices,
source availability/offers, permitted linking/relinking and modification duties
for the actual artifact. `CONFIG_GPL=0` and `CONFIG_NONFREE=0` are technical
configuration observations, not a blanket licence conclusion. H.264/AAC patents
require a separate jurisdiction/product/distribution decision; a software licence,
Brave's shipping configuration or passing playback tests supplies no patent grant.
See [FFmpeg's legal guidance](https://ffmpeg.org/legal.html).

The inventory and release record deliberately leave redistribution approval
false. Production/RC channels require an accountable reviewer's explicit
redistribution reference and bound source/runtime identity. No Widevine binary
is supplied. Supporting EME does not establish a usable CDM: an authorised vendor
agreement, matching Linux CDM, supported update mechanism and real service test
are external prerequisites. See [Widevine documentation](https://developers.google.com/widevine/drm/overview).

## Historical runtime records

# Custom native codec runtime — 19 October 2026

The custom source pipeline now builds CEF branch 7977 on the complete Chromium
152.0.7977.169 revision. `engine/config/development-codecs.gn` enables
`proprietary_codecs=true` and `ffmpeg_branding="Chrome"`, matching the inspected
Brave native-media configuration. This is an explicit development build,
separate from approval to redistribute a codec-enabled runtime. No external
player/decoder process or user-agent workaround is added to Majoris.

Build and prepare the SDK using [the engine guide](../engine/README.md). Supply
it through the existing `cef_root`/`CEF_ROOT` path. The SDK carries source/patch,
configuration and binary digests. Debian packaging rejects an unapproved codec
runtime unless `MAJORIS_DEVELOPMENT_ENGINE=1` explicitly selects development
packaging. That setting does not establish distribution rights.

`engine/tests/generate-media-fixtures.py` creates original synthetic H.264 MP4,
AAC M4A and combined H.264/AAC MP4, with CC0 fixture provenance and SHA-256.
FFmpeg is used only to generate those tests; it is not an application playback
backend. Set `MAJORIS_MEDIA_FIXTURES` to their directory when running the
existing real-decoding media suite against the custom SDK. The assertions
require advancing decoded video frames and nonzero audio samples, in browser
and installed-app contexts. Compilation, MIME support and flags are not passes.
Set `MAJORIS_EXPECT_PROPRIETARY_CODECS=1` to require the configured decoders.

The final custom engine passed real H.264, AAC and combined MP4 playback in both
contexts, alongside VP8/VP9/Opus, in the full 27/27 runtime regression run.
Archive/libcef hashes and logs are in [verification results](verification-results.md).
Physical audio output, hardware decoding and codec redistribution remain
unverified/unapproved. The standard SDK still reports H.264/AAC unavailable.
Widevine remains a separate vendor/runtime
and service dependency; it is neither provided nor claimed by this work.
Earlier SDK-specific qualification records below remain historical.

## Earlier standard-SDK records

# Qualified media runtime integration

Current pass, main 82684a8: the pinned SDK and codec licensing situation are unchanged. The existing qualification route is retained; no authorised H.264/AAC runtime or vendor CDM was supplied. VP8/VP9/Opus Browser/app decoding remains mandatory. The platform fixture now explicitly asserts real HTML video fullscreen entry and exit. Native Wayland/fullscreen geometry, hardware decoding, physical audio and real DRM services remain separate unverified gates. A custom security-fixed runtime must first be built and qualified through the existing cef_root/clean/package flow; codec GN flags still require independent redistribution approval.

Default CEF binaries omit proprietary H.264/AAC support. Chromium's bundled FFmpeg configuration and codec feature gates determine demux/decoder support; installing system FFmpeg or enabling hardware acceleration does not replace those gates. See [Chromium media](https://www.chromium.org/audio-video/) and [Google's CEF codec build instructions](https://support.google.com/webdesigner/answer/10043691?hl=en). The latter explicitly identifies additional licensing obligations. No authorised codec-enabled binary or redistribution entitlement was supplied for Majoris, so none is shipped.

`packaging/cef/codec-runtime.gn.example` is an inactive maintainer template. After legal/redistribution review, build the selected supported CEF branch with its documented automated build and those GN settings; retain its full configuration, source commits, archive SHA-256, provenance, codec/patent review and notices. Build the wrapper against that exact SDK. Pass its absolute directory through the existing `-Dcef_root`, `verify-clean.py --cef-root` and `verify-package.py --cef-root` workflows. Bootstrap's default pin is not silently changed to an unreviewed third-party binary. No Chromium fork, external player, system-FFmpeg substitution or support-response override is introduced.

`cef-media-playback` generates original synthetic VP8/VP9 and Opus WebM locally with MediaRecorder, then decodes them through HTML media. It checks decoded video frames, advancing playback and nonzero decoded Opus samples through an analyser, in independent Browser and installed-app contexts. This verifies software media operation, not hardware acceleration or physical speaker output.

A runtime advertising H.264/AAC must also pass real playback before qualification. Set `MAJORIS_MEDIA_FIXTURES` to a local directory containing original/licensed `h264.mp4` (video only), `aac.m4a` (audio only) and `h264-aac.mp4` (combined). Fixtures must exceed 0.3 seconds, have 160x90 video and audible nonzero audio. The HTTP runner exposes only these fixed names; no files are uploaded to an external service. Missing assets or decode errors fail a codec-capable runtime's test. Unsupported decoders report a blocked result rather than successful playback. Record asset licences and generation commands with the qualification record. Neither these assets nor codec binaries are automatically downloaded.

Widevine remains unavailable and optional. CEF/Chromium have EME/library-CDM integration, but an EME API is not a licensed CDM. No vendor CDM, redistribution permission or service qualification was supplied; none is copied from another browser. Upstream [CEF's GN configuration](https://github.com/chromiumembedded/cef/blob/master/tools/gn_args.py) and [VMP issue](https://github.com/chromiumembedded/cef/issues/3404) also distinguish CDM support from provider/service acceptance. DRM sites, HD/secure playback and provider-specific licensing remain unverified.


Rechecked for main 97812b08 on 18 October 2026: the selected official SDK and its media API are unchanged. The existing integration path remains the supported route; no authorised codec-capable runtime, codec assets or Widevine vendor materials have been supplied. Production qualification requires a fixed supported engine first, then the licensed runtime/notices, actual H.264/AAC and combined playback in both contexts, and a separate vendor-approved DRM/service test. VP8/VP9/Opus decoding and the current unavailable results are rerun in the full suite; they are not proprietary-codec or DRM passes.
