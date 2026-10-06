# Editor Benchmark — 7 Critical States

This benchmark is about interaction hierarchy, not visual cloning.

Reference products:
- Apple Photos (iPhone Photos editor)
- Google Photos (Android video editor)
- CapCut Mobile
- Instagram Edits

Sources checked in October 2026:
- Apple iPhone User Guide: video trim and crop
- Google Photos Android video editor help
- CapCut mobile/editor help
- Instagram Edits App Store listing and current feature description

## Principles learned from the references

### Apple Photos
- The media remains the dominant object.
- Video trim uses a frame viewer directly below the preview.
- The kept region is visually explicit.
- Crop supports direct corner manipulation and pinch open/closed.
- Aspect ratio has an explicit lock state.
- Tools such as Video, Adjust, Filters and Crop live in one editor shell rather than separate products.

### Google Photos
- Uses a streamlined editor with a scrollable action bar.
- Trim handles are direct manipulation.
- Crop/rotate/straighten/mirror are contextual crop tools.
- Adjustments and filters preview on the media rather than becoming detached settings pages.
- The basic surface stays simple while more tools remain reachable.

### CapCut Mobile
- Mobile is deliberately streamlined compared with the more complex iPad/editor experience.
- Timeline is the central temporal editing surface.
- Tools are contextual to the selected clip/action.
- Projects persist as drafts; export creates output rather than replacing the editable project.
- Complexity is revealed as it becomes useful.

### Instagram Edits
- Positions itself as a full mobile creator/editor rather than a two-action utility.
- Promises single-frame precision.
- Keeps drafts/projects.
- Extends the editor with cutout/background tools, overlays, filters/effects, captions and audio enhancement.
- This validates an extensible editor shell, but CMMR should not copy its account/cloud assumptions.

---

# The 7 CMMR states

## 1. Full clip / editor entry

### Goal
The user immediately understands: “this is the result I am editing.”

### CMMR target
- Result preview is visually primary.
- Timeline sits directly below it.
- Current time/playback controls are compact.
- Bottom tool rail is extensible:
  - Trim
  - Crop
  - later Speed / Audio / Adjust / Filters / Text / Captions
- Export is top-level but does not dominate.
- No large Exact/Fast cards occupying the main editor surface.
- Opening the editor does not silently apply any edit.

### Avoid
- settings-page layout,
- giant dead vertical gaps,
- treating preview as a small card,
- asking the user to choose “Cut app” vs “Crop app”.

---

## 2. Precise trim in progress

### Goal
Moving a boundary must immediately answer: “what exact frame am I cutting at?”

### CMMR target
- Trim handles remain visible even at the true first/last frame.
- Dragging a trim handle pauses playback.
- Preview seeks to the boundary continuously.
- Selected range is visually obvious.
- Start/end/current time use precise formatting when needed.
- Handle touch target is large while visible handle remains compact.
- Rapid seek requests are coalesced so preview follows the latest finger position.

### Direction to evaluate
A fixed playhead with the filmstrip scrolling beneath it may be clearer than freely moving both timeline and playhead.

---

## 3. Timeline zoomed in

### Goal
Coarse navigation and sub-second editing should use the same timeline.

### CMMR target
- Standard pinch:
  - fingers apart -> zoom in,
  - fingers together -> zoom out.
- Zoom is anchored around the midpoint between the fingers.
- At 1x, dragging the filmstrip scrubs.
- When zoomed, horizontal movement can navigate the expanded timeline.
- Time ruler adapts from seconds to fractions of a second.
- Eventually use true frame/timebase information for frame stepping.
- Thumbnail density uses cache/LOD rather than decoding every frame.

### Avoid
- a RangeSlider with pictures,
- hidden trim handles at clip edges,
- scroll and scrub fighting for the same gesture without a clear rule.

---

## 4. Crop — full frame

### Goal
Entering Crop must not feel like an edit was already applied.

### CMMR target
- Identity crop is exactly the full source frame.
- Handles remain visible/reachable on all four corners.
- Aspect lock state is explicit.
- Freeform and common ratios are one tap away.
- Crop tool entry does not disable lossless trim by itself.
- Workspace starts at 1x when full-frame.

### Avoid
- hidden 5% initial crop,
- touch targets mostly outside the canvas,
- separate magnifier obscuring the area being edited.

---

## 5. Crop — small selected region

### Goal
A tiny source-space crop must remain comfortable to manipulate.

### CMMR target
Two complementary precision systems:

1. **Workspace zoom**
   - As the crop region becomes small, the crop workspace automatically zooms toward it.
   - The selected crop remains a comfortably manipulable size.
   - Standard two-finger pinch changes workspace zoom.
   - Pinch midpoint is the zoom anchor.
   - Moving both fingers pans the workspace.
   - Manual zoom changes only the editor view, not the saved crop coordinates.

2. **Precision loupe**
   - Appears while a crop handle is being dragged.
   - Shows the exact source point around the active handle.
   - Lives outside the video when practical so it does not hide the crop.
   - Is secondary precision assistance, not a substitute for workspace zoom.

### Storage/model rule
Crop remains normalized source-space project data. Display zoom is editor state and does not change export geometry.

---

## 6. Return from Crop to timeline

### Goal
Previous edits must remain visible across tool switches.

### CMMR target
- If the user cropped the video, Trim shows the cropped result.
- Playback also uses the composed project preview.
- A tool switch changes controls, not project meaning.
- Crop remains editable/non-destructive.
- Reset Crop returns the preview to full source.

### Core rule
**The preview always represents the project result, not whichever tool happens to be open.**

---

## 7. Export

### Goal
A normal user gets a correct result without understanding codecs.

### Default surface
- Export
- resolution / quality preset if useful
- destination

### Advanced disclosure
Only when requested:
- container,
- codec,
- quality/bitrate,
- FPS,
- HDR policy,
- hardware/software processing,
- Exact/Fast/Smart override.

### UX
- technical messages such as “hardware accelerated re-encode” belong in diagnostics/details,
- successful export should use a short transient confirmation,
- editable project remains intact after export,
- later export can run as a persistent background job.

---

# Basic + advanced balance

Do not create separate “Basic” and “Pro” products.

Use progressive disclosure:

## Default
- direct manipulation,
- good automatic choices,
- small number of obvious tools,
- Auto/Smart processing,
- common presets.

## Advanced
Expose deeper controls inside the relevant tool:
- exact timecode,
- frame stepping,
- numeric crop geometry,
- perspective/rotation,
- codec/export control,
- track/effect parameters,
- diagnostics.

The basic path must never be made worse just to prove that advanced capability exists.

---

# Next CMMR editor shell

Direction:

```
Back / Project              Undo Redo   Export

                 RESULT PREVIEW

              compact transport

                  TIMELINE

 Trim   Crop   Speed   Audio   Adjust   Filters   ...

          contextual tool controls
```

Only implemented tools should be shown.

The shell should support future photo/media editing concepts without forcing photo and video to have identical controls.
