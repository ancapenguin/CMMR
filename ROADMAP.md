# ROADMAP.md

CMMR is a local-first personal computing workshop. Media editing is the current focus and first serious vertical, not the final scope. The media target is not "a cutter with more buttons"; it is a lightweight, modular, open editor that can grow toward serious editing without inheriting CapCut-style bloat, server dependence, telemetry, or unnecessary product complexity.

The roadmap is capability-gated. A phase starts because the previous layer is stable enough to support it, not because a feature list says it is time.

## Product principles

- One app for media work; do not split photo/video into separate products without a strong reason.
- Flutter/Dart owns the app and editor UX.
- Processing engines sit behind narrow interfaces and may change.
- Media stays local by default.
- Prefer hardware acceleration and zero-copy/remux paths when they preserve correctness.
- Heavy capabilities should be modular and demand-driven.
- Do not expose implementation complexity to ordinary users.
- Never let an early technical choice become sacred. Replace an engine or boundary if profiling or product needs prove it wrong.

## Phase 0 — Foundation

Status: in progress.

- [x] Prove Android builds in CI.
- [x] Produce ABI-split release APKs.
- [x] Define agent/stack/UX/media rules.
- [x] Build the first real trim/crop vertical slice.
- [ ] Stabilize the editor on a real Android phone.
- [ ] Make CI fast enough that every code change can be checked without building an APK every time.
- [ ] Establish automated unit/widget tests for editor-domain logic and interactions.

Exit condition: basic video selection, preview, trim, crop and export are reliable on a real phone.

## Phase 1 — Editing core

Turn the prototype into a dependable single-asset editor.

- filmstrip timeline and accurate seeking,
- pinch-to-zoom timeline with adaptive time ruler/thumbnail density,
- sub-second precision and frame-step editing at high zoom,
- reliable crop/rotate/flip,
- aspect-ratio locks,
- exact trim,
- fast lossless trim,
- Smart Cut,
- undo/redo,
- project state separated from widgets,
- deterministic project serialization,
- capability/error reporting instead of generic FFmpeg failures.

Smart Cut should follow the proven hybrid model:
- encode only the boundary region needed for frame accuracy,
- stream-copy the compatible remainder,
- concatenate only when stream parameters allow it.

Exit condition: one video can be edited repeatedly without destructive state bugs, sync errors, or unclear export behavior.

## Phase 2 — Export engine and jobs

Make export a first-class subsystem.

- background export,
- persistent export queue,
- Android notification progress,
- cancellation,
- retry/recovery,
- storage checks,
- hardware encoder capability detection,
- output presets,
- inspectable export diagnostics,
- benchmark exact / fast / smart paths.

Export should be independent from the editor screen lifecycle.

Exit condition: long exports survive leaving the editor and fail predictably.

## Phase 3 — Media compatibility layer

Broaden format support deliberately.

Inputs to validate:
- MP4 / H.264 / AAC,
- HEVC,
- MKV,
- WebM,
- AV1,
- Opus,
- variable-frame-rate phone footage,
- HDR samples.

Outputs:
- Auto,
- H.264/AAC MP4 as the compatibility baseline,
- HEVC when supported,
- AV1 only when capability and performance justify it,
- MKV/WebM where they provide real value.

At this phase decide whether packaged FFmpeg variants are sufficient or a custom minimal FFmpeg build is justified.

Exit condition: supported formats are defined by a tested matrix, not assumptions.

## Phase 4 — Project/timeline model

Move from "one file with edits" to a real non-linear editing model.

- clips as project objects,
- multiple sequential clips,
- multiple audio tracks,
- split/delete/reorder,
- clip-local trim/crop/speed/volume,
- project-global settings,
- non-destructive edits,
- autosave/recovery,
- undo/redo transaction model.

The project model must not depend on FFmpeg command strings, Media3 classes, or Flutter widgets.

Exit condition: the same project can be previewed and exported through replaceable engine adapters.

## Phase 5 — Photo editor

Reuse the media/editor shell for still images.

Start with:
- crop,
- rotate/flip,
- perspective where practical,
- exposure/brightness,
- contrast,
- saturation,
- temperature/tint,
- highlights/shadows,
- sharpening,
- simple filters.

Photo support should reuse project/effect concepts rather than becoming a separate app.

## Phase 6 — Audio and music workflow

Make audio editing unusually good instead of treating it as an afterthought.

- extract audio from video,
- trim/fade/normalize,
- volume automation,
- ducking,
- waveform,
- background music tracks,
- voice-over recording,
- optional beat/BPM analysis later.

Add a Media Sources boundary so music can come from:
- local files,
- device audio library,
- URL/import providers,
- optional downloader/provider modules.

Do not hard-wire a scraping/downloader implementation into the editor core.

## Phase 7 — Media Sources and import providers

Explore external discovery/import as optional providers.

Candidates:
- yt-dlp-backed URL importing,
- service-specific extractor providers,
- local/network storage providers,
- open/licensed music catalogs.

Requirements:
- provider isolation,
- clear provenance/licensing metadata,
- failures do not break the editor,
- provider updates can move faster than the core app,
- no dependency on private APIs as a product-critical path.

Instagram/Meta music should not be assumed available: treat it as research until a stable, permitted integration exists.

## Phase 8 — Effects, graphics and advanced editing

Only after timeline/project/export foundations are strong:

- text,
- stickers/images,
- masks,
- keyframes,
- transitions,
- LUT/color tools,
- GPU effects,
- captions/subtitles,
- speech-to-text integration,
- picture-in-picture,
- speed ramps,
- motion/transform animation.

Prefer a preview/export architecture where the same effect model maps predictably to both paths.

## Phase 9 — Extensibility

If CMMR becomes large enough to justify it:

- effect/plugin API,
- import/export provider API,
- scripting/headless operations,
- agent/MCP control,
- reusable presets,
- optional downloaded assets/models.

Do not build a plugin system before there are multiple real extension use cases.

## Phase 10 — Distribution and updates

Trigger: real repeated usage makes manual installs annoying.

- real release signing,
- stable/preview channels,
- background update checks,
- changelog,
- update integrity verification,
- rollback/failure handling.

## Non-goals

- mandatory accounts,
- server-side video processing by default,
- analytics as a prerequisite for core features,
- advertisements,
- cloud lock-in,
- adding frameworks/languages for novelty,
- copying CapCut's feature count while copying its complexity.
