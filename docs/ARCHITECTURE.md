# Architecture

CMMR should be modular enough to grow into a serious editor without pretending we already know the final engine.

## Core rule

**Editor state is product data. Processing engines are adapters.**

The UI must not directly construct FFmpeg command strings or depend on engine-specific classes.

Target dependency direction:

```
Flutter UI
   |
Editor/application layer
   |
Project + timeline + effect domain model
   |
Capabilities / Preview / Export / Import interfaces
   |
+------------------+-------------------+------------------+
| FFmpeg adapter   | Android Media3    | future engines   |
|                  | adapter           |                  |
+------------------+-------------------+------------------+
```

## Domain model

The project model should eventually represent concepts such as:

- Project
- Track
- Clip
- MediaAsset
- TimeRange
- Transform
- Crop
- Effect
- Audio settings
- ExportPreset

These are plain product concepts. They should be serializable and testable without a device or codec library.

## Processing boundaries

### Media probe

Responsibilities:
- streams,
- duration,
- dimensions,
- rotation,
- codec/container,
- frame rate/timebase,
- HDR metadata,
- keyframes/capabilities.

### Preview

Responsibilities:
- playback,
- seek,
- preview transforms/effects,
- timeline position.

Preview is latency-sensitive and may use a different implementation from final export.

### Export

Responsibilities:
- validate project,
- choose optimal path,
- remux/stream-copy when possible,
- hardware transcode where appropriate,
- fall back safely,
- background jobs,
- progress/cancel/error details.

### Media sources

Responsibilities:
- local picker,
- device media,
- URL import,
- optional external providers.

External service logic must not leak into the editor model.

## Engine strategy

### FFmpeg

Excellent for:
- demux/mux,
- transcoding,
- filters,
- probing,
- remuxing,
- Smart Cut primitives,
- broad format compatibility.

Do not force real-time UI preview through FFmpeg if another engine gives better latency or hardware integration.

### Android Media3

Worth evaluating for:
- Android-native hardware codecs,
- preview/export symmetry,
- multiple media items,
- audio/video compositions,
- GPU/OpenGL effects,
- HDR handling.

The domain model should allow us to adopt Media3 selectively without rewriting the UI.

### Rust

Rust is justified when CMMR owns a substantial reusable subsystem that benefits from native performance/safety, for example:
- project/render graph engine,
- custom parser,
- effect/compositor engine,
- cross-platform processing core.

Do not insert Rust merely between Dart and FFmpeg.

## Modularity

Code modules should align with capabilities, not arbitrary "utils":

```
lib/
  app/
  editor/
  project/
  timeline/
  media/
    probe/
    preview/
    export/
    sources/
  features/
    trim/
    crop/
    audio/
    photo/
```

This is a direction, not a requirement to create empty directories now.

## Performance rules

- Prefer non-destructive edit state.
- Avoid decoding media when remux/sample-copy is sufficient.
- Prefer hardware codec paths after capability checks.
- Avoid repeated full-file probing.
- Cache thumbnails/waveforms with invalidation.
- Never block the UI isolate with CPU-heavy work.
- Measure startup, seek latency, export speed, memory, temperature and APK size before claiming an optimization.
- Keep large models/assets optional and downloadable when possible.

## Change policy

Architecture is reversible by design.

If a backend becomes a bottleneck:
1. measure it,
2. isolate the boundary,
3. replace the adapter,
4. preserve project semantics and tests.

Do not preserve a poor choice merely because it was the first implementation.
