# Terminal and Personal Compute

CMMR should eventually include a real terminal as a first-class vertical.

The goal is not a fake command box. It should be capable of running interactive terminal applications, shells and coding agents while keeping execution backends replaceable.

## Product goal

A user should be able to open CMMR and get:

- terminal tabs/sessions,
- interactive TTY applications,
- local or remote shells,
- persistent sessions,
- workspace/project folders,
- SSH,
- agent launchers,
- background jobs where Android permits them,
- clear storage/process controls.

Examples include:
- bash/zsh,
- git,
- ssh,
- Python/Node tooling,
- OpenCode or other coding-agent CLIs,
- local servers,
- commands on the user's PC/VPS.

The terminal is a separate vertical from the media editor. It should share CMMR infrastructure such as storage, jobs, projects and remote-compute providers without being coupled to media code.

## Architecture rule

**Terminal UI is not the execution environment.**

Keep these layers separate:

```
Flutter terminal UI
        |
TerminalSession interface
        |
+----------------+----------------+----------------+----------------+
| Termux backend | Local PTY      | SSH backend    | Future runtime |
| localhost      | Android shell  | PC/VPS         | embedded Linux |
+----------------+----------------+----------------+----------------+
```

This lets us replace the backend without rewriting the terminal UI.

## Terminal UI

Use a proper VT/xterm-compatible terminal renderer rather than manually drawing text.

Requirements:
- ANSI/VT sequences,
- alternate screen,
- colors,
- Unicode/IME,
- mouse/touch selection,
- resize,
- clipboard,
- hardware keyboard,
- mobile modifier-key row,
- tabs/sessions,
- search,
- scrollback.

A maintained Flutter xterm implementation is a good fit for this layer.

## Recommended first useful backend: Termux over localhost SSH

Do not fork or embed all of Termux as the first implementation.

For the first serious version:

1. CMMR owns the terminal UI.
2. Termux provides the Linux userspace/package ecosystem.
3. CMMR connects to Termux through an interactive localhost SSH session.
4. The SSH channel allocates a PTY, so TUI/agent programs behave like a real terminal.

Benefits:
- real interactive PTY,
- existing Termux package ecosystem,
- bash/zsh/git/node/python/etc.,
- no need to rebuild the Termux bootstrap immediately,
- same terminal frontend can also connect to a PC/VPS,
- OpenCode and similar tools can run where their Android/Termux build permits it.

The first-run setup can eventually help the user configure Termux/sshd, but must remain explicit and inspectable.

## Termux command bridge

Termux also exposes a RUN_COMMAND integration for third-party Android apps.

This can be useful for:
- starting sshd,
- running one-shot commands,
- setup/status checks,
- launching jobs.

It is not the preferred transport for a fully interactive terminal session because CMMR needs a real PTY stream.

Use RUN_COMMAND as orchestration; use SSH/PTTY for the interactive session.

## Local PTY backend

A second backend can run Android-native commands through a local PTY.

This is useful for:
- /system/bin/sh,
- binaries shipped with CMMR,
- diagnostics,
- small local tools.

It is not equivalent to Termux and should not pretend to provide a full package-managed Linux environment.

## Remote SSH backend

The same terminal should support:
- VPS,
- desktop PC,
- home server,
- another phone,
- self-hosted compute node.

This matches the broader CMMR principle that hosted CMMR services must not be the only option.

Agent sessions should therefore be able to run:
- locally in Termux,
- on the user's own PC,
- on a VPS,
- later in an embedded CMMR runtime,
- optionally on a managed CMMR compute service.

## Embedded runtime: later

A self-contained Linux/Termux-compatible runtime inside CMMR is desirable long-term, but should not be the first milestone.

Reasons:
- Android executable-file/W^X restrictions complicate downloaded native binaries in app-private writable storage,
- Termux itself carries special compatibility constraints,
- package/bootstrap maintenance is substantial,
- process lifetime on modern Android has platform limits,
- distribution through Play has different constraints from sideload/F-Droid-style distribution.

Potential future paths to evaluate:
- a Termux-compatible bootstrap maintained for CMMR,
- PRoot/container-backed userspace,
- packaged native runtime components,
- an embedded Termux SDK if one becomes production-ready.

Do not commit the product to one of these before a real prototype and licensing/distribution review.

## Agent mode

Terminal support should not stop at “open a shell.”

Later CMMR can add an Agent surface on top of TerminalSession:

- choose workspace/repository,
- choose backend,
- launch agent command,
- persist/reconnect session,
- show token/model/provider status,
- grant filesystem/network capabilities explicitly,
- attach files or selected project context,
- send a task from the normal CMMR UI,
- drop into the raw terminal at any time.

Important rule:
**the agent is a client of the terminal/runtime, not the owner of it.**

Users must always be able to access the underlying shell and their files without the AI layer.

## Security

Terminal/agent access is powerful.

Requirements:
- no silent command execution from unrelated UI,
- explicit backend/workspace identity,
- secrets stored in Android secure storage where practical,
- show when a command is local vs remote,
- SSH host-key verification,
- separate session/process management,
- user-visible kill/stop controls,
- no arbitrary web content triggering terminal commands.

## Storage

Terminal environments can become large.

The CMMR storage dashboard must break terminal data down into:
- runtime/base system,
- installed packages,
- home/workspaces,
- package caches,
- agent caches,
- models,
- logs,
- container/rootfs images.

Users should be able to locate and clean these categories without deleting unrelated project files.

## Milestone order

### Terminal V0
- terminal renderer,
- tabs/sessions,
- SSH connection to an arbitrary host,
- mobile modifier-key row.

### Terminal V1
- localhost Termux SSH backend,
- setup/status screen,
- persisted sessions/settings,
- workspace shortcuts.

### Agent V1
- launch a configured agent CLI such as OpenCode,
- select repo/workspace,
- reconnect to session,
- raw terminal fallback.

### Runtime V2
- evaluate self-contained CMMR Linux runtime only after the above proves useful.

This keeps the first implementation small while preserving the long-term vision.
