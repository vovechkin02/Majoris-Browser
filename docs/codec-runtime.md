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
