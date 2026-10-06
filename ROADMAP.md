# ROADMAP.md

CMMR is intentionally idea-driven. This roadmap defines repository infrastructure order, not a giant product backlog.

## Phase 0 — Foundation

Status: in progress.

- [x] Prove Flutter Android build in CI.
- [x] Produce optimized ABI-split release APKs.
- [x] Publish tagged/manual builds to GitHub Releases.
- [x] Define repository and agent rules.
- [x] Define the single-stack mobile policy.
- [ ] Replace the bootstrap demo with the first actual app.

### Explicit non-goals for Phase 0
- in-app updater,
- account/auth framework,
- analytics,
- generic backend,
- shared "core" package,
- design system,
- state-management framework chosen before an app needs one,
- a second mobile UI framework.

## Phase 1 — First real app: video cutter

Build a small local-first video utility with both meanings of "crop/cut":

- temporal trim: choose start and end time,
- spatial crop: choose the rectangle to keep,
- preview the selected video,
- export the result locally,
- show processing progress and failure details.

Implementation direction:
- Flutter/Dart UI,
- Flutter's maintained `video_player` for preview,
- native FFmpeg processing through a maintained Flutter integration,
- use stream-copy for a fast trim-only path where acceptable,
- crop/re-encode through FFmpeg; use Android hardware codecs when they are reliable,
- no Rust initially.

Rust is reconsidered only if profiling later identifies substantial processing that CMMR itself owns rather than work already performed inside FFmpeg.

The first app should also answer:
- which file/SAF workflow is least annoying on Android,
- how large the native media dependency makes the APK,
- whether hardware encoding is reliable across the phones we actually use,
- what release/update friction appears in real usage.

## Phase 2 — Real monorepo

Trigger: a second real app is ready to enter the repository.

Then migrate from the root app layout to:

```
apps/
  app_one/
  app_two/
packages/
tool/
docs/
```

Use native Dart Pub workspaces for Dart/Flutter packages. Consider Melos for cross-workspace scripting/versioning only if it removes real repetition.

Update CI in the same change so no app becomes unbuildable during the migration.

## Phase 3 — App template

Trigger: at least two apps reveal repeated setup work.

Create a lightweight app template/scaffolder covering only proven repetition, for example:
- package/bundle naming,
- lints,
- test skeleton,
- theme/bootstrap shell,
- Android release build,
- standard CI hooks.

Do not template architecture decisions that differ between apps.

## Phase 4 — Update infrastructure

Trigger: at least one app is regularly installed outside an app store and manual upgrades are now a real recurring cost.

Only then choose/update:
- signing strategy,
- release manifest format,
- stable vs experimental channels,
- update checking,
- download + install UX,
- rollback/failure behavior.

The updater should solve actual distribution friction, not exist because updater infrastructure sounds useful.

## Phase 5 — Shared packages

Trigger: duplicated production code exists in two or more apps.

Extract only demonstrated shared code. No package is created merely because it sounds reusable.
