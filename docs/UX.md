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
- the playhead must remain visually distinct from trim handles.

## Touch targets

Interactive editor handles should target at least roughly 48 logical pixels of touch area on mobile, even when the visible affordance is much smaller.

Never optimize a handle for visual minimalism at the expense of reliable touch input.

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
