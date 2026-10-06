# Stack Policy

CMMR intentionally keeps the mobile stack boring so an app can be created and iterated remotely with Codex/ChatGPT.

## Mobile default

**Flutter + Dart is the CMMR mobile application stack.**

This is stronger than a casual default: normal CMMR apps should not introduce another UI framework.

Why:
- one predictable project shape for agents,
- Android APKs already build in CI,
- fast UI iteration,
- Dart is sufficient for ordinary product logic,
- platform capabilities can stay behind plugins,
- less toolchain and architecture churn between experiments.

## Platform-specific functionality

Use this order:

1. existing maintained Flutter package,
2. a small package/plugin CMMR owns,
3. a narrow platform channel/native implementation only when required.

Native implementation code may exist behind the Flutter boundary. Native UI should not be introduced merely because the feature is Android-specific.

## Rust rule

Rust is opt-in and must own useful work.

Good reasons:
- a measured CPU-heavy algorithm implemented by us,
- protocol/parser/engine code with meaningful reuse,
- a security-sensitive native component,
- a core that is genuinely shared by multiple frontends.

Bad reasons:
- ordinary app/business logic,
- CRUD/state/navigation,
- wrapping an already-native engine such as FFmpeg just to say the app uses Rust,
- hypothetical future performance.

For media work, remember that FFmpeg codecs and filters are already native. Calling them through Rust instead of Dart does not inherently make the actual media processing faster.

## Services / other code

| Need | Preferred choice |
| --- | --- |
| Mobile UI and normal app logic | Flutter + Dart |
| Android capability with good package support | Flutter package |
| Android capability without package support | narrow native plugin/platform channel |
| Owned CPU-heavy/parser/protocol engine | Rust when justified |
| Small web/API glue | TypeScript |
| Tiny standalone service with a strong operational reason | Go may be considered |
| Framework-evaluation experiment | isolate whatever the experiment needs |

## State management and navigation

Do not select repository-wide state-management or routing packages in advance.

Use Flutter primitives while an app is small. Add a package only when a real app creates enough complexity to justify it.

## Monorepo tooling

Dart Pub workspaces are the base mechanism once multiple Dart/Flutter packages exist.

Melos is optional orchestration on top. Add it only when cross-package commands, filtering, or versioning remove real repetition.

## Toolchain versioning

Keep CI toolchain versions explicit. Upgrade Flutter/Dart deliberately and separately from product changes.

At the time this document was introduced, CMMR CI pins Flutter 3.47.5 and the root package requires Dart ^3.13.4. Those values describe repository state, not permanent architecture decisions.
