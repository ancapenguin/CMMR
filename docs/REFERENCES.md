# Open-source Reference Projects

These projects are references to study, not dependencies that CMMR must adopt.

## LosslessCut

Why inspect it:
- FFmpeg-focused lossless editing,
- keyframe behavior,
- experimental Smart Cut,
- stream/metadata handling,
- many real-world container/codec edge cases.

Most relevant to CMMR now.

## FFmpeg

The processing toolbox underneath a large part of the media ecosystem.

Study:
- ffprobe,
- demux/mux,
- trim/select/concat,
- filter graphs,
- hardware acceleration,
- stream copy,
- timestamps/timebases,
- metadata/subtitles.

## MLT Framework

A mature open-source non-linear editing engine used by editors including Shotcut and Kdenlive.

Study:
- multitrack composition model,
- producer/consumer/filter abstractions,
- plugin architecture,
- timeline semantics,
- effect processing.

Do not adopt MLT on mobile without first validating footprint, Android integration, preview latency and maintenance cost.

## Kdenlive

Study:
- mature non-linear editing UX,
- nested timelines,
- proxy workflows,
- effects,
- subtitles,
- project recovery.

Its desktop UX is not a mobile template; its engineering edge cases are valuable.

## Shotcut

Study:
- MLT-based architecture,
- broad format handling,
- native timeline editing,
- filters/effects,
- hardware/export behavior.

## OpenCut

The current rewrite is particularly interesting because its direction overlaps with ours:
- editor API,
- plugin-first architecture,
- Rust core,
- headless mode,
- MCP/agent control,
- web/desktop/mobile ambitions.

Study the boundaries and mistakes; do not copy its architecture blindly.

## Android Media3 Transformer / Composition

Not an app, but an important platform reference.

Study:
- EditedMediaItem,
- Composition,
- CompositionPlayer,
- Transformer,
- audio/video sequences,
- effects,
- HDR,
- hardware-oriented Android paths.

## yt-dlp

Potential optional import-provider engine.

Study:
- extractor architecture,
- format selection,
- service churn,
- metadata,
- subtitle/audio/video stream handling.

The project changes frequently because upstream sites change frequently. Keep it isolated from editor fundamentals.

## Seal

Android GUI around yt-dlp.

Study:
- Android packaging of yt-dlp,
- update mechanics,
- download jobs,
- format/audio selection,
- background behavior.

Do not copy branding or code without respecting GPL/trademark obligations.

## NewPipe / NewPipe Extractor

Useful reference for a service-extractor architecture that does not require proprietary client libraries.

Study:
- separation between extraction and UI,
- search/browse/playback flows,
- service-specific adapters.

## Research rule

Before implementing a difficult media subsystem, check whether these projects already solved:
- timestamp edge cases,
- VFR handling,
- keyframe cuts,
- stream compatibility,
- multi-track semantics,
- background jobs,
- cache/proxy behavior,
- hardware codec quirks.

Document the lesson, not just the link.
