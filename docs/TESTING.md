# Testing Strategy

CMMR media code needs several different test layers. Compilation alone is not proof that an editor works.

## 1. Unit tests — cheapest and most important

Keep domain math pure enough to test without Flutter or FFmpeg.

Examples:
- time/range normalization,
- crop coordinate conversion,
- aspect-ratio locking,
- timeline mapping pixels <-> timestamps,
- Smart Cut planning,
- keyframe selection,
- export strategy selection,
- codec/container capability decisions,
- project serialization,
- undo/redo transactions,
- command/plan generation.

Use table-driven and boundary-heavy tests. For geometry/time math, add randomized invariant tests where useful.

## 2. Widget tests

Use Flutter widget tests for interaction contracts:

- trim handle drag changes the expected range,
- crop preset stays locked while resizing,
- large invisible hit targets remain interactive,
- active tool switches without losing state,
- Save/Export is disabled/enabled correctly,
- error/progress states render correctly,
- editor layout survives common phone sizes and orientation changes.

Golden tests can catch accidental visual regressions for a small set of stable editor states. Do not golden-test every pixel of animated/video content.

## 3. Integration tests

Run the real app on emulator/device for flows such as:

- open media,
- manipulate timeline,
- export,
- reopen project,
- background/resume,
- permission handling.

Flutter's integration_test package can run on emulators, physical devices, and device farms.

## 4. Media contract tests

Maintain tiny, legally redistributable media fixtures.

Suggested matrix:
- MP4/H.264/AAC,
- MP4/HEVC,
- MKV/H.264,
- WebM/VP9/Opus,
- AV1 sample,
- portrait rotation metadata,
- VFR sample,
- no-audio sample,
- audio-only sample.

For each supported path, verify with ffprobe or equivalent:
- output exists,
- duration tolerance,
- expected dimensions,
- expected streams/codecs,
- audio retained/removed as intended,
- rotation,
- timestamps,
- first/last frame behavior where important.

## 5. Smart Cut regression suite

Smart Cut needs dedicated fixtures around keyframes:

- exact keyframe,
- just after keyframe,
- just before next keyframe,
- cut shorter than one GOP,
- B-frames,
- VFR,
- audio sync.

Validate:
- first intended frame,
- no duplicated/missing junction frames,
- A/V sync,
- output decodes fully,
- copied/re-encoded sections join correctly.

## 6. Real-device tests

Hardware behavior cannot be completely virtualized.

On meaningful releases check:
- actual phone decoder support,
- MediaCodec encoder support,
- thermal behavior,
- background export,
- notification progress,
- gallery/storage behavior,
- long files,
- low storage,
- screen lock/app background.

## CI policy

Every PR:
- format,
- analyze,
- unit tests,
- widget tests.

APK build:
- manual, release/tag, or explicit validation checkpoint; not every tiny push.

Integration/media suite:
- manual/nightly/release depending on runtime cost.

Golden tests:
- PR when UI changes.

Real-device matrix:
- release candidate / major media-engine changes.

A feature is done only when the test layer appropriate to its risk passes.
