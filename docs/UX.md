# Editor UX Rules

The media itself is the primary content. Controls exist around it; the media must not feel like a preview card inside a settings page.

## Layout

For video:
1. app bar / compact actions,
2. large video canvas,
3. timeline,
4. active editing tool controls.

Avoid long scrolling forms while the user is manipulating video or crop geometry.

## Direct manipulation

Gestures inside the media canvas must win over page scrolling.

Crop:
- dragging anywhere inside the crop rectangle moves it,
- visible corner marks may be small,
- actual touch targets must be large,
- crop preset ratios remain locked while resizing,
- freeform mode removes the ratio constraint,
- show a rule-of-thirds grid while crop editing is active.

Timeline:
- show frame thumbnails when available,
- in/out handles must have large invisible hit targets,
- tapping/dragging the filmstrip seeks,
- the playhead must remain visually distinct from trim handles,
- support pinch-to-zoom on the timeline,
- zoom changes temporal scale, not the underlying edit,
- allow zooming far enough to make sub-second and eventually frame-level edits practical,
- keep the playhead anchored under the fingers/center while zooming so the user does not lose context,
- adapt thumbnail density and time ruler labels to the zoom level,
- avoid generating full-resolution thumbnails for every frame; use level-of-detail/cached thumbnails,
- provide sensible min/max zoom bounds and preserve zoom while switching editing tools.

At coarse zoom, show minutes/seconds and sparse thumbnails.
At fine zoom, show fractions of a second / frame-oriented granularity and denser thumbnails.

The timeline must feel like an editor timeline, not a RangeSlider with pictures.

## Touch targets

Interactive editor handles should target at least roughly 48 logical pixels of touch area on mobile, even when the visible affordance is much smaller.

Never optimize a handle for visual minimalism at the expense of reliable touch input.

## Player controls

The player should support both ordinary viewing and precise editing.

Baseline:
- tap video to show/hide controls,
- play/pause,
- current time / duration,
- scrub through the timeline,
- jump to trim start/end,
- frame-step backward/forward when paused,
- seek should update preview with low perceived latency.

For editing, frame stepping and timeline zoom are more important than adding many transport buttons.

Do not permanently cover the video with a large central play button while the user is editing.

## Tool model

Prefer a compact editing toolbar such as:
- Cut,
- Crop,
- Rotate,
- Speed,
- Audio,
- Adjust.

Add tools only when implemented. Do not show dead controls.

For photo editing, use the same mental model where possible:
- Crop,
- Rotate,
- Adjust,
- Filters,
- Text/draw later.

## Processing choices

Do not expose implementation jargon unless it helps the user make a real choice.

Good:
- Exact — exact frame, may take longer.
- Fast — lossless and very fast, may align to a keyframe.
- Smart — mostly lossless, exact boundary, when implemented.

Bad:
- raw FFmpeg flag names,
- codec-specific controls in the default editor surface.

## Save/export

Saving should not dominate the editor layout.

A top-bar Save/Export action is appropriate. Long-running export progress should move to a background-job surface once background processing exists.

## Failure messages

Show actionable errors:
- unsupported input,
- decoder unavailable,
- encoder unavailable,
- insufficient storage,
- permission denied,
- export failed.

Do not dump full FFmpeg logs into the normal UI. Keep detailed logs available for diagnostics.
