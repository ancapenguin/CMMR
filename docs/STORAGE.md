# Storage and File Policy

CMMR should make storage behavior understandable and boring.

## Rule of thumb

If the user thinks of something as **their file**, store it in user-visible/shared storage or in a user-selected folder.

If it is only an implementation detail, store it as app data/cache.

## User-owned files

Examples:
- exported video/photo/audio,
- downloaded media,
- project source copies if the user explicitly asks for copies,
- project archives/backups,
- batch-converted files,
- user presets intended to survive reinstall/export.

Prefer MediaStore or the Storage Access Framework depending on the type of content.

Offer sensible organization:
- one CMMR root when the user wants it,
- per-project folders as an option,
- configurable export folders,
- predictable names,
- batch rename,
- duplicate/temporary cleanup tools,
- clear storage usage reporting.

Do not silently duplicate imported gigabyte-scale videos into private app storage.

Where possible, keep references/URIs to source files and store only project metadata.

## App-private persistent data

Keep only app implementation state here:
- settings,
- small databases,
- project indexes,
- permission/provider metadata,
- undo/autosave metadata when appropriate,
- credentials/tokens that must be private,
- tiny internal assets/state.

Large user media should not live here merely because it is convenient for code.

## Cache

Cache is disposable.

Examples:
- timeline thumbnails,
- waveform caches,
- temporary preview proxies,
- decoded/derived thumbnails,
- transient download fragments,
- probe results,
- temporary render intermediates.

Requirements:
- cache entries must be reconstructible,
- cache must have quotas/eviction,
- old project caches should age out,
- expose "Clear cache",
- show cache size,
- never rely on Android eventually cleaning it for us.

## Temporary export files

Temporary render output should:
1. be written to a controlled temp location,
2. move/copy into the user's final destination after success,
3. be deleted after completion/failure according to recovery policy.

Do not leave abandoned multi-GB temp files indefinitely.

## Project folders

Optional per-project storage is desirable:

```
CMMR/
  Projects/
    Project Name/
      project.cmmr
      exports/
      assets/      # only copied/imported assets if requested
```

Projects should also be able to reference files outside this folder without duplicating them.

## Storage UI

Eventually provide a storage dashboard:

- app data,
- cache,
- project metadata,
- proxies/thumbnails,
- downloaded/imported media,
- exports,
- optional models.

Allow cleanup by category and project.

The UI should explain whether deleting a category is:
- safe/rebuildable,
- destructive,
- deleting user-owned files.

## Models and optional heavy assets

Local AI models, codec packs, effects/assets, templates and other large optional resources should be separately visible and removable.

Do not disguise gigabytes of downloadable models as unexplained "App data".


## Storage dashboard UX

Show storage as a **segmented storage-usage bar** (a stacked horizontal bar) with a total above it.

Example:

```
9.5 GB used by CMMR-managed data

[ App 42 MB ][ Cache 620 MB ][ Projects 18 MB ][ Models 2.4 GB ][ Downloads 5.7 GB ][ Previews 720 MB ]
```

Each segment must be drillable. A user should be able to tap a category and see exactly what consumes space.

For every category, provide where applicable:
- total size,
- largest items first,
- owning project/provider,
- file/folder location when user-visible,
- last used date,
- whether it is rebuildable,
- Open / Locate,
- Delete,
- Delete all,
- Move,
- change default location.

Never show only an opaque aggregate such as "App data: 8.1 GB" if CMMR itself can explain that storage.

Suggested categories:
- application/runtime,
- settings/databases,
- project metadata,
- cache,
- thumbnails,
- waveforms,
- preview/proxy media,
- temporary render files,
- local AI models,
- downloaded media,
- downloaded assets/effects,
- user exports.

Downloaded media and exports are user-owned files. The dashboard may index/manage them, but must make clear that deleting them deletes the user's actual files.

Cache/proxy/model cleanup should also be available per project, not only globally.
