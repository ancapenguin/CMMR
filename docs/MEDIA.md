# Media Direction

CMMR's first real app is evolving from a simple cutter into a lightweight local-first media editor. This document records direction, not a commitment to build every feature immediately.

## Product model

Use one app, not separate APKs for photo and video editing.

A media item opens directly into the relevant editor:
- video -> video editor,
- photo -> photo editor.

A one-video edit should remain fast and simple. Multi-clip editing should grow naturally from the same editor by adding clips to the timeline rather than forcing the user to choose between "Cut" and "Edit" up front.

## Video processing modes

### Exact
Default.

Cut exactly at the requested frame. Re-encode when required.

### Fast lossless
Optional.

Use stream copy when possible:
- no quality loss,
- extremely fast,
- cut start may align to a codec keyframe rather than the exact requested frame.

Never present this as frame-accurate.

### Smart cut
Planned.

LosslessCut-style boundary-only re-encode:
1. probe the next keyframe after the requested start,
2. re-encode only the prefix from the requested start to that keyframe,
3. stream-copy the remaining segment,
4. concatenate compatible parts.

Do not fake Smart Cut with a normal stream-copy command. It needs codec/timebase/stream compatibility checks and real-device validation.

## Crop

Spatial crop and temporal trim are independent operations.

Crop presets should lock their aspect ratio while resizing:
- free,
- original,
- 1:1,
- 4:5,
- 3:4,
- 9:16,
- 16:9,
- 4:3.

## Formats and codecs

Treat container and codec support separately.

Direction:
- MP4: first-class input/output,
- MKV: support as a general input/container target when the underlying stack handles it reliably,
- H.264: compatibility default,
- H.265/HEVC: optional where device support is reliable,
- AV1 decode: desirable,
- AV1 encode: optional and capability-gated.

Default UI should say "Auto" rather than forcing ordinary users to understand codecs. Advanced settings may expose codec/container choices later.

Do not claim a format/codec as supported until it is tested on a real device with actual sample files.

## FFmpeg strategy

Prefer the smallest FFmpeg build that still covers the product's real format requirements.

If ready-made package variants force a bad tradeoff between APK size and codec coverage, consider a custom FFmpeg build later.

Rust is not added merely to wrap FFmpeg. Revisit Rust only if CMMR owns measurable native work that benefits from it.

## Background export

Long video/photo exports should eventually survive leaving the editor.

Target UX:
- export becomes a queued job,
- progress is visible in-app and from an Android notification,
- the user may leave the editor while export continues,
- completed jobs surface a clear success/failure result,
- cancellation is supported.

Implement this only after foreground export is reliable.

## App size

APK size is a budget, not a vanity metric.

Guideline:
- a simple cutter should stay lean,
- a broader offline media editor may justify more native codec weight,
- every major native dependency should earn its size with real capability.

Measure release ARM64 size and inspect size breakdowns before making optimization decisions.
