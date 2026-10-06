# ROADMAP.md

CMMR is intentionally idea-driven. This roadmap defines repository infrastructure order, not a product feature backlog.

## Phase 0 — Foundation

Status: in progress.

- [x] Prove Flutter Android build in CI.
- [x] Produce optimized ABI-split release APKs.
- [x] Publish tagged/manual builds to GitHub Releases.
- [x] Define repository and agent rules.
- [x] Define default stack-selection policy.
- [ ] Replace the bootstrap demo with the first actual app/experiment.

### Explicit non-goals for Phase 0
- in-app updater,
- account/auth framework,
- analytics,
- generic backend,
- shared "core" package,
- design system,
- state-management framework chosen before an app needs one.

## Phase 1 — First real app

Pick an idea small enough to reach an installable useful state quickly.

The first app should answer:
- Is Flutter sufficient for the idea?
- Which Android/platform capabilities are actually required?
- What app-level conventions are worth keeping?
- Which parts of the current release workflow are annoying in real use?

Do not restructure the whole repository merely to make the first app look "enterprise".

## Phase 2 — Real monorepo

Trigger: a second real app is ready to enter the repository.

Then migrate from the root bootstrap layout to:

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

The updater should be an app/distribution solution, not repo infrastructure looking for a use case.

## Phase 5 — Shared packages

Trigger: duplicated production code exists in two or more apps.

Extract only demonstrated shared code. Candidate packages may eventually include:
- release/update metadata client,
- small UI primitives,
- persistence helpers,
- platform capability wrappers,
- a Rust-backed engine shared by multiple apps.

No package is created merely because it sounds reusable.
