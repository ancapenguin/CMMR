# Real-device Test Matrix

CMMR media features are not considered working because CI compiles them. CI catches code/build failures; media behavior must be validated on real phones.

## Every meaningful editor build

Check:
- app launches,
- video picker works,
- selected video previews correctly,
- play/pause and seeking work,
- trim handles are easy to grab,
- crop box moves from its full interior,
- crop corners are easy to grab,
- locked aspect ratios stay locked,
- freeform crop remains free,
- exact export saves successfully,
- fast export saves successfully,
- saved video appears in the gallery,
- audio is retained,
- orientation is correct,
- output duration/crop roughly matches the UI selection.

## Format samples

Maintain a small local sample set covering at least:
- MP4 + H.264 + AAC,
- MP4 + H.265/HEVC when available,
- MKV + H.264,
- MKV + another common audio codec,
- AV1 input once AV1 support is intentionally enabled,
- portrait and landscape,
- short and longer clips,
- variable-frame-rate phone video if available.

A format is "supported" only after successful open + preview + export testing.

## Smart Cut

When implemented, specifically test:
- cut exactly on a keyframe,
- cut immediately after a keyframe,
- cut near the next keyframe,
- very short segments between keyframes,
- audio/video sync,
- first-frame correctness,
- no duplicated/missing boundary frames,
- H.264 first,
- HEVC separately.

## Background export

When implemented:
- start export and background the app,
- lock the screen,
- reopen the app,
- cancel a job,
- kill/restart the UI process where reasonable,
- verify notification progress,
- verify final gallery result,
- test low storage / permission failure.

## Size/performance

For release ARM64 builds record:
- APK size,
- install size when convenient,
- export time for one fixed sample,
- peak heat/battery behavior subjectively,
- exact vs fast vs smart timing once all modes exist.

Do not optimize based on debug builds.
