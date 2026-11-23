# Dotfiles — Agent Guide

Shared dev environment for macOS and Debian/Ubuntu, used by several people. One installer, two profiles (`desktop`, `server`), no menus and no uninstall. Re-running is the update path, so every step must be idempotent.

Two hard rules:
- **User-agnostic.** No names, emails, hostnames or paths of a specific person in tracked files. Identity comes from the user's own `gh` login.
- **The clone stays clean.** Nothing in `$HOME` may symlink into the repo, and no installer may write into it. Each tool gets a user-owned entry file that loads the shared config first (see `link_configs` in `lib/tools.sh`); personal changes go in that file. `scripts/smoke-check.sh` enforces this.

## Raineworks base rules

This repository follows Raineworks' base rules, in [`.raineworks/base.md`](.raineworks/base.md): read them before
changing anything. They're a copy of `base.md` in `raine-works/agents`, kept current by its sync: change them there,
not here. Where this file is more specific, it wins.

@.raineworks/base.md

## Docs

How-tos and reasoning live in [`docs/`](docs/README.md), indexed by its README. [Development](docs/development.md)
has the repository layout, how to add a tool, app or shared config, and how to test;
[Configuration](docs/configuration.md) shows where each shared config is loaded from.

## Conventions

- **Profiles:** shared steps run for both; gate desktop-only work with `if [ "$profile" = desktop ]`. Don't use `[ … ] && cmd` as the last line of a function: under `set -e` a false test fails the caller.
- **Idempotence:** every install checks first (`has <cmd>` or a path test) and calls `skip` when already present.
- **No rc edits by installers:** pass the tool's flag (`PROFILE=/dev/null` for nvm, `--no-modify-path` for rustup, `UV_NO_MODIFY_PATH=1`, `SHELL=/bin/sh` for bun). PATH setup lives in `zsh/tools/`.
- **Linux binaries** go to `~/.local/bin`; prefer apt, then `github_bin <cmd> <repo> <asset-regex>` with `$ARCH_RE`.
- **Warnings** that the user must act on go through `note` so they repeat in the final summary.
- **Failure policy:** core steps (packages, languages, config wiring) stop the run. Optional apps (casks, GUI apps, Claude Code, herdr, NetBird, Colima start) `note` and continue. Config wiring runs right after the base packages so a later failure never leaves a half-migrated shell. Anything may already be installed outside the package manager (e.g. a hand-installed font or app), so check for it first.
- **zsh tool files** guard themselves: `(( $+commands[tool] )) || return 0`, or a directory test when the file adds the tool to PATH. They're sourced before `compinit`, so they may extend `fpath`.
- **Completions** are generated once at install into `~/.local/share/zsh/site-functions`, not at shell startup.
- **Git identity** is only ever written to the user's `~/.gitconfig`, never the tracked config.
- Bash style: 4-space indent, `shfmt -i 4 -ci`, clean under `shellcheck -x`.
- **Strict mode:** `install.sh`, `setup.sh` and `scripts/*.sh` start with `set -Eeuo pipefail` (the smoke check enforces it), so the `lib/` files they source run under `set -u` too: default optional variables (`${VAR:-}`) and expand arrays that may be empty as `${arr[@]+"${arr[@]}"}`, since macOS's bash 3.2 calls an empty array unbound.

## Updates

`dotfiles update` (zsh function in `zsh/aliases.zsh`) runs `git pull --ff-only`, then `install.sh <profile>` with the profile saved in `~/.config/dotfiles/profile`. Anything a re-run touches must leave user customizations alone: the git identity step only runs when `user.email` is unset (`ensure_git_identity`), unless invoked as `install.sh git`.

Both `install.sh` and `dotfiles update` finish by replacing the process with a fresh `zsh -l`. If the run just added the user to the `docker` group, they start it through `sg docker` so Docker works without logging out (`reload_shell` in `lib/common.sh`; the zsh copy is in `dotfiles()`). `dotfiles update` sets `DOTFILES_NO_RELOAD=1` so the installer doesn't start a nested shell.

## Adding things

- A CLI tool or desktop app is added for both OSes, never just one. A new shared config gets a `hook_<tool>` in `lib/tools.sh` that creates or updates a user-owned entry file pointing at it; never a symlink. The steps are in [Development](docs/development.md#adding-things).

## Testing

`bash scripts/smoke-check.sh` must pass before a change is done (CI runs it too). For installer changes, also do the full server run in a throwaway container described in [Development](docs/development.md#testing).
