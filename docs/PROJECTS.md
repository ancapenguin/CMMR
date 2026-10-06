# Projects and Non-destructive Editing

A CMMR project should preserve work without copying the user's source media unless the user explicitly requests a portable copy.

## Project file

Use a small, versioned project manifest (working extension: `.cmmrproj`; the exact encoding can change before it becomes a compatibility promise).

It should contain product state such as:
- project version,
- source media references,
- timeline/clip structure,
- trim ranges,
- crop/transform state,
- effects and parameters,
- audio settings,
- text/subtitle references,
- export settings,
- optional provider/source metadata.

It should **not** contain full source videos by default.

The project is an edit description, not a rendered video.

## Source references

On Android, source media may be referenced through:
- persisted Storage Access Framework URIs,
- MediaStore identifiers/URIs,
- explicit file paths only where appropriate.

Keep enough identity metadata to help reconnect moved media, for example:
- display name,
- size,
- duration/type,
- modified time,
- optional content fingerprint.

If a source disappears or moves, open the project in an offline/relink state rather than silently failing.

## Relink

Provide a "Locate missing media" flow.

A relink should update the source reference without rewriting the user's edits.

For multiple missing files, allow folder-level/batch relinking where possible.

## Autosave and resume

Projects should support:
- autosave,
- crash recovery,
- last-opened position/tool state where useful,
- explicit duplicate/save-as,
- backwards-compatible schema migration.

Autosave metadata must remain small. Do not autosave copies of giant source videos.

## Cache and proxies

The project may point to derived resources such as:
- thumbnails,
- waveforms,
- preview proxies,
- transcription results,
- masks/analysis results.

These belong in managed cache/sidecar storage with clear ownership and cleanup. Rebuildable data should remain rebuildable.

## Portable / collected projects

Offer an explicit portability operation later:

**Collect project**

This may create a folder or archive containing:
- the project manifest,
- only the source assets the user chooses,
- optional proxies/sidecars,
- fonts/assets required by the project.

This is different from normal editing and must never happen silently.

## Cloud/remote compute

A project manifest is also the natural unit for remote rendering.

A remote worker needs:
1. the project description,
2. access to the required source assets,
3. compatible processing capabilities.

This allows the same project to render:
- locally on the phone,
- on the user's PC,
- on a self-hosted machine,
- on an optional CMMR-hosted compute service.

The project format must therefore describe intent, not be coupled to one local renderer's command strings.

## Reference model

This is similar in spirit to mature non-linear editors: the project stores edit decisions and references to media, while source files remain untouched. Rendered output is a new file.
