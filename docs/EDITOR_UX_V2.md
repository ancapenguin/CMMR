# Editor UX V2

This is the target interaction model for the mobile media editor. It exists because the first implementation proved that a collection of working controls can still feel unlike an editor.

## Core principle

The user edits the result, not implementation settings.

The preview must always represent the current project state:
- crop remains visible while trimming,
- transforms/effects remain visible while changing time,
- timeline movement updates the preview,
- switching tools never makes prior edits visually disappear.

## Editor shell

Use one scalable editor shell rather than a permanent two-mode "Cut / Crop" product.

Top:
- back/project,
- compact project title,
- undo/redo when available,
- export.

Center:
- result preview.

Below preview:
- transport only when useful,
- timeline.

Bottom:
- horizontally extensible tool rail,
- context panel for the selected tool.

Initial tools can still be only:
- Trim,
- Crop.

Future tools can join the same shell:
- Speed,
- Audio,
- Adjust,
- Text,
- Captions,
- Effects.

Do not show dead tools.

## Timeline model

The current hybrid timeline is temporary.

Preferred mobile interaction:
- a clear playhead represents the current frame,
- dragging/scrubbing changes the preview immediately,
- trim handles define clip boundaries,
- pinch changes temporal scale,
- high zoom exposes sub-second/frame precision,
- the selected range remains visually obvious even when it spans the full clip,
- full-range handles remain visible/reachable at the real clip edges.

Evaluate a fixed-playhead model where the timeline scrolls under the playhead. This can reduce ambiguity between scrolling, seeking and moving the playhead.

Processing strategy (Exact/Fast/Smart) should not dominate the timeline UI. Prefer Auto/Smart behavior by default and expose processing details at export or in advanced options.

## Crop model

A separate magnifier that covers the content is not the desired solution.

The crop workspace itself should magnify the active crop as it becomes small.

Target behavior:
- crop boundaries remain easy to grab,
- as the selected source region shrinks, the workspace zooms toward it,
- the user can still understand where the crop lies in the original frame,
- prior crop is reflected in the normal result preview,
- aspect presets alter the crop without unexpectedly applying unrelated edits.

Evaluate the common mobile model of a large crop viewport with the media transformed underneath it. Store the edit as source-space crop/transform state, not display coordinates.

## Feedback and status

Do not leave technical export implementation messages occupying permanent editor space.

Good:
- short success snackbar/status,
- detailed export diagnostics behind an info/details surface.

Avoid primary-screen text like:
- hardware encoder fallback,
- codec implementation details,
unless the user explicitly opens diagnostics.

## Screenshot-driven review

Before another broad UI pass, compare the same states in reference editors:

1. full untrimmed clip,
2. precise trim in progress,
3. timeline zoomed in,
4. crop full-frame,
5. crop reduced to a small region,
6. crop result after returning to the timeline,
7. export entry point.

Study interaction patterns, spacing and information hierarchy rather than copying branding.

References worth checking:
- Instagram Edits,
- CapCut,
- Apple Photos,
- Google Photos.

For every CMMR screenshot review, identify:
- what is the primary object,
- what action is currently active,
- what can be manipulated directly,
- what is visually competing with the media,
- whether project state remains visible across tool switches.
