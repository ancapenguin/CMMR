# CMMR

**Codex Mobile Monorepo** — a workshop for building mobile apps and experiments for fun.

CMMR is not one product. The goal is to make it cheap to go from an idea to an installable app without forcing every experiment into the same architecture.

## Current state

The repository currently contains a Flutter Android bootstrap app at the root. It exists to prove the build/release path before real apps are added.

The GitHub Actions workflow:
- builds release APKs,
- splits them by Android CPU architecture,
- keeps run artifacts for quick testing,
- publishes APKs to GitHub Releases for version tags or manual release runs.

## Direction

Flutter + Dart is the default starting stack, with Kotlin/Jetpack Compose and Rust available when an app has a concrete reason to use them.

The repository will become a real multi-app layout when a second actual app is introduced rather than pre-building a large monorepo structure now.

See:
- [AGENTS.md](AGENTS.md) — repository rules for coding agents and contributors
- [ROADMAP.md](ROADMAP.md) — infrastructure order and trigger points
- [docs/STACK.md](docs/STACK.md) — framework/language decision guide
