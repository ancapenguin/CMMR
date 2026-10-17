# AGENTS.md

## What CMMR is

CMMR is a mobile app workshop/monorepo for building small, useful, weird, or experimental apps for fun. It is not one product and it should not accumulate infrastructure without a real app that needs it.

The primary workflow is intentionally simple: an idea should be implementable from Codex/ChatGPT, built in CI, installed on a phone, and iterated without requiring a large local mobile toolchain.

The repository should optimize for:
1. fast idea -> installable app,
2. low maintenance,
3. a small and predictable default stack,
4. clear boundaries between apps,
5. keeping experiments disposable.

## Default technical policy

### UI / application layer
- Use Flutter + Dart for CMMR mobile app UI.
- Do not introduce a second mobile UI framework merely because a feature is Android-specific.
- Prefer maintained Flutter plugins for platform capabilities.
- If Android-specific native code is unavoidable, keep it behind a narrow Flutter plugin/platform-channel boundary. Do not move the UI to a native framework.
- An experiment whose explicit purpose is evaluating another framework may ignore this rule, but it must stay isolated and document why.

### Native/core code
- Keep ordinary product logic in Dart.
- Introduce Rust only for code CMMR actually owns and benefits from implementing natively: a measurable CPU-heavy algorithm, reusable parser/protocol/engine, security-sensitive native component, or a core shared across frontends.
- Do not add Rust merely to wrap an already-native engine such as FFmpeg. A Rust wrapper around the same FFmpeg codecs does not make the codecs faster.
- Do not add Rust/FFI pre-emptively.

### Services / tooling
- TypeScript is the default for small web surfaces or API glue when a backend is actually needed.
- A backend is not part of the default app template.
- Add another backend language only when an app has a concrete reason.

## Repository shape

The current root Flutter app is a bootstrap app. Do not treat the current layout as the final monorepo layout.

When a second real app is introduced, migrate to:

```
apps/
  <app_name>/
packages/
  <shared_package>/
tool/
docs/
```

Rules:
- Each app must remain independently understandable and buildable.
- Do not create a shared package until at least two real consumers need the code.
- Do not create "core", "utils", "common", or abstraction layers in anticipation of reuse.
- App-specific assets, state, platform code, tests, and release metadata stay inside that app.

For Dart/Flutter multi-package management, prefer native Pub workspaces. Add Melos only when cross-package commands/versioning provide real value.

## Dependency policy

Before adding a dependency:
- verify the package is maintained and compatible with the repository's current SDK,
- prefer a well-supported package over writing platform glue,
- prefer platform APIs/direct code over a weak dependency,
- avoid packages that duplicate a trivial amount of code,
- never add a package solely because generated code happens to know it.

Pin toolchain versions in CI. Do not perform broad dependency upgrades as part of unrelated feature work.

## App creation policy

A new app should begin with the smallest vertical slice that proves the idea:
- app boots,
- one real interaction works,
- relevant persistence/network/native API works if the concept requires it,
- basic error state exists,
- CI can analyze/test/build it.

Do not begin a new app by building a design system, updater, account system, analytics layer, dependency injection framework, navigation abstraction, generic architecture, or alternate native UI implementation.

## Updates and distribution

The repository already proves that Android APKs can be built and published through GitHub Actions.

Do not build an in-app updater yet.

An updater becomes justified when a real app is installed outside the Play Store and repeated releases make manual updating meaningfully annoying. At that point, design the update path for that app's actual distribution model, signing model, release channel, and Android constraints.

## CI and quality

Every app should eventually have:
- formatting check,
- static analysis,
- tests for non-trivial logic,
- a build job for its supported target.

Do not require large test suites for disposable experiments. Do require tests around parsers, persistence migrations, security-sensitive logic, and complex state.

Keep CI understandable. Avoid a generic matrix until there are enough apps to justify one.

## Agent behavior

When working in this repository:
- read this file and the relevant app README first,
- prefer a working vertical slice over speculative architecture,
- keep changes scoped,
- verify current package APIs and versions before adding dependencies,
- explain any new framework/language/tooling choice in the PR,
- preserve existing build/release behavior unless changing it intentionally,
- do not hide failures with disabled checks or blanket ignores,
- never commit secrets, signing keys, tokens, generated credentials, or private endpoints.

If there are two viable approaches, prefer the one with lower maintenance and less irreversible architecture.
