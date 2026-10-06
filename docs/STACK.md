# Stack Policy

This is a decision guide, not a ban list.

## Default

**Flutter + Dart** is the default starting point for a CMMR mobile app.

Why:
- one codebase reaches Android quickly,
- the repository already has a working Flutter Android CI/release path,
- UI iteration is fast,
- Dart is sufficient for most app/business logic,
- native code can still be added when necessary.

Do not interpret "default" as "every app must use Flutter".

## When to choose something else

| Need | Preferred choice | Reason |
| --- | --- | --- |
| Normal cross-platform/mobile UI app | Flutter + Dart | Lowest setup/maintenance cost for CMMR |
| Android-only app with deep OS integration | Kotlin + Jetpack Compose | Direct access to Android APIs and lifecycle |
| Home-screen widgets, services, accessibility, unusual Android platform behavior | Kotlin/Compose, or a small native Kotlin layer under Flutter | Avoid fighting framework/plugin boundaries |
| CPU-heavy parser/engine/codec | Rust core + thin app bindings | Native performance and reusable safe core |
| Crypto/protocol-sensitive reusable core | Rust | Strong fit for constrained, testable core logic |
| Small web dashboard/API glue | TypeScript | Fast ecosystem and iteration |
| Tiny standalone service with a strong reason for a single binary | Go can be considered | Operational simplicity; not a default dependency |
| Pure experiment whose purpose is evaluating another framework | Whatever the experiment requires | Experiments are allowed; isolate the choice to that app |

## Rust rule

Rust is opt-in, not ceremonial.

Good reasons:
- measurable hot path,
- protocol/parser/engine that benefits from strict types and native execution,
- shared core across several frontends,
- security-sensitive native component.

Bad reasons:
- a settings screen,
- ordinary CRUD,
- simple state management,
- "the project might need performance later".

## State management

Do not select a repository-wide Flutter state-management library now.

Start with Flutter primitives for small apps. Introduce an external state-management package when the first real app demonstrates enough complexity to justify it. The choice may remain app-specific.

## Navigation

Same rule: do not install a routing framework before an app needs non-trivial navigation/deep links.

## Monorepo tooling

Dart Pub workspaces are the base mechanism once multiple Dart/Flutter packages exist.

Melos is optional orchestration on top. As of October 2026, the current pub.dev release is Melos 8.9.0, and it is designed to work with Pub workspaces. Add it when commands across multiple packages, filtering, or versioning become useful—not before.

## Toolchain versioning

Keep CI toolchain versions explicit. Upgrade Flutter/Dart deliberately and separately from product changes.

At the time this document was introduced, CMMR CI pins Flutter 3.47.5 and the root package requires Dart ^3.13.4. Those values describe the current repository state; they are not permanent architecture decisions.
