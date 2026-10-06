# CMMR

**Codex Mobile Monorepo** — a workshop for building mobile apps and experiments for fun.

CMMR is not one product. The goal is to make it cheap to go from an idea to an installable app without forcing every experiment into the same architecture.

The preferred workflow is: describe an idea, let Codex/ChatGPT implement it, let CI validate it, install it on a phone, then iterate from real usage.

## Current state

The first real experiment is a local-first media editor beginning with video trim and crop.

The repository still uses a single root Flutter app. It becomes a real multi-app monorepo only when a second actual app arrives.

## Direction

Flutter + Dart is the mobile UI/application stack. Native plugins are allowed behind narrow boundaries when a platform capability requires them. Rust is opt-in for concrete native work CMMR itself owns; it is not added ceremonially.

See:
- [AGENTS.md](AGENTS.md) — repository rules for agents and contributors
- [ROADMAP.md](ROADMAP.md) — infrastructure order and trigger points
- [docs/STACK.md](docs/STACK.md) — stack policy
- [docs/MEDIA.md](docs/MEDIA.md) — media editor direction and processing modes
- [docs/UX.md](docs/UX.md) — editor interaction rules
- [docs/TESTING.md](docs/TESTING.md) — real-device media test matrix
