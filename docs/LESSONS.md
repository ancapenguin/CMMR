# Engineering Lessons

This file records concrete lessons learned while building CMMR. It is not a changelog. Add items only when a real implementation, test, or device session teaches us something worth not relearning.

## 1. A green build is not a working editor

Compilation and static analysis catch code problems. They do not prove:
- gestures feel correct,
- crop handles are reachable,
- trim points match what the user thinks they selected,
- export is frame-accurate,
- gallery/storage behavior works,
- hardware codecs behave correctly.

Rule:
**build -> automated tests -> real-device use -> done**

## 2. Tests should be allowed to disagree with the implementation

A test is not there to make CI green.

The trim-handle interaction test expected a 40 px drag to produce the full corresponding timeline movement. The implementation only applied part of the motion because drag deltas were effectively lost across rebuild timing.

Correct response:
- keep the behavioral expectation,
- fix the gesture implementation,
- do not weaken the test to match the bug.

This is especially important for editor geometry and timeline behavior.

## 3. Gesture state must survive rebuild timing

Do not derive a continuous drag solely from the latest widget value plus the latest pointer delta.

For drag interactions:
- snapshot the value at drag start,
- accumulate pointer displacement locally,
- derive the new value from start + cumulative displacement,
- clamp only at the domain boundary.

This avoids dropped motion when parent rebuilds do not occur between every pointer event.

## 4. Visible handles and touch targets are different things

A crop/trim handle can look small while remaining easy to grab.

Keep:
- compact visual affordance,
- large invisible touch target,
- touch target inside the usable canvas even at full-frame/full-range boundaries.

Do not let a corner handle's hitbox extend mostly outside the video and then blame the user for missing it.

## 5. Entering an editing tool must not apply an edit

Opening the Crop tool originally marked crop as active even when the user had not changed the frame. That disabled the fast trim path.

Rule:
**tool selection is UI state; edit application is project state.**

The same rule will matter later for:
- filters,
- audio effects,
- color adjustment,
- text,
- masks,
- AI tools.

Opening a tool must not dirty/apply the project by itself.

## 6. Full-frame / identity state should be a real identity state

For crop:
- full-frame is (0, 0, 1, 1),
- no hidden 5% margin,
- no re-encode merely because the user opened Crop,
- identity transforms should be detectable and removable from the processing plan.

This applies generally:
- 1.0x speed,
- 0 degree rotation,
- 0 dB gain,
- no-op color adjustments,
- empty effects.

No-op edits should collapse to no-op processing.

## 7. Scrubbing is editing, not playback

When the user drags a trim handle or timeline:
- pause playback,
- seek to the manipulated time,
- give immediate visual feedback.

Playing through the video while the user is trying to place an exact boundary makes the editor feel imprecise even if the math is correct.

## 8. A timeline is not a RangeSlider with thumbnails

A real editor timeline needs:
- filmstrip/waveform,
- playhead,
- in/out handles,
- pinch-to-zoom,
- adaptive time scale,
- sub-second/frame-level precision,
- scrolling/zoom state,
- high-quality seeking feedback.

Build the timeline as its own interaction system, not as a decorated generic slider.

## 9. The media must remain the primary visual object

The first editor UI treated the video like a preview card inside a settings form.

That was wrong.

Editor layout priority:
1. media canvas,
2. timeline,
3. active tool controls,
4. secondary settings.

Avoid giant empty regions, long scrolling forms, and controls that visually dominate the media.

## 10. Do not keep dependencies just because they were once useful

The obsolete `video_thumbnail` dependency remained after thumbnails moved to FFmpeg.

It then broke the Android build because its Gradle script still used `jcenter()`.

Rule:
- remove replaced dependencies immediately,
- periodically inspect the dependency graph,
- prefer fewer maintained dependencies,
- do not patch an obsolete dependency when removing it is the correct solution.

## 11. Package size must be measured, not guessed

Switching from the larger FFmpeg video package to the minimal variant reduced the ARM64 APK from about 41.8 MB to 32.9 MB.

Lesson:
- use release ARM64 measurements,
- understand which native libraries earn their size,
- do not optimize based on intuition alone,
- later use a custom FFmpeg build if packaged variants force a bad size/capability tradeoff.

## 12. Fast lossless trim and exact trim are different promises

Stream-copy trim is fast and quality-preserving, but keyframe boundaries can move the visible start.

Do not label it as exact.

Current product language:
- Exact: precise requested boundary, may re-encode.
- Fast: lossless/very fast, keyframe-limited.
- Smart: planned hybrid boundary re-encode + copied remainder.

Never fake Smart Cut with a normal `-c copy` command.

## 13. Project state must describe intent, not engine commands

Do not let Flutter widgets or FFmpeg command strings become the project format.

The project should say things like:
- trim range,
- crop rectangle,
- rotation,
- gain,
- effects,
- clip ordering.

Adapters decide how to render that intent.

This keeps FFmpeg, Media3, a future Rust core, cloud rendering, or the user's own PC replaceable.

## 14. User media is not app data

Do not silently copy large source videos into private app storage.

Prefer:
- references to user-owned files,
- small project metadata,
- rebuildable cache for thumbnails/waveforms/proxies,
- explicit portable-project collection when the user asks for it.

Storage should be inspectable and cleanable by category.

## 15. Scope can be huge; implementation scope must stay narrow

CMMR may eventually include:
- media editing,
- file management,
- local AI,
- remote control,
- local servers,
- downloads/import providers,
- backup/sync,
- phone-PC integration.

That does not mean all of these belong in the current sprint.

Rule:
**broad vision, narrow iteration.**

Ship one coherent vertical slice, learn from it, then expand.
