# Dotfiles — Agent Guide

Shared dev environment for macOS and Debian/Ubuntu, used by several people. One installer, two profiles (`desktop`, `server`), no menus and no uninstall. Re-running is the update path, so every step must be idempotent.

Two hard rules:
- **User-agnostic.** No names, emails, hostnames or paths of a specific person in tracked files. Identity comes from the user's own `gh` login.
- **The clone stays clean.** Nothing in `$HOME` may symlink into the repo, and no installer may write into it. Each tool gets a user-owned entry file that loads the shared config first (see `link_configs` in `lib/tools.sh`); personal changes go in that file. `scripts/smoke-check.sh` enforces this.

## Layout

```
setup.sh                 bootstrap (curl | bash): brew or apt git → clone → exec install.sh
install.sh               profile entry point: desktop | server | git
lib/common.sh            logging, OS/ARCH detection, has, as_root, run_remote, note
lib/macos.sh             BREW_FORMULAE / BREW_CASKS_DESKTOP, Colima docker setup
lib/linux.sh             APT_PACKAGES, github_bin (GitHub-release binaries), gh/go/docker, desktop apps
lib/tools.sh             languages (nvm, bun, rustup, uv), Claude Code, herdr, NetBird, config wiring
lib/git.sh               gh login → SSH key (auth + signing) → identity in ~/.gitconfig
lib/merge_jsonc.py       Zed settings merge (JSONC tolerant)
scripts/smoke-check.sh   offline checks, also run in CI

zsh/                     zshrc, aliases.zsh, tools/*.zsh   ← sourced from ~/.zshrc
starship/starship.toml   ← STARSHIP_CONFIG, unless ~/.config/starship.toml exists
git/config               ← [include] at the top of ~/.gitconfig
git/ignore               ← copied once to ~/.config/git/ignore
ghostty/config           ← config-file include from ~/.config/ghostty/config (desktop)
zed/settings.json        ← merged into ~/.config/zed/settings.json (desktop)
```

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

## Updates

`dotfiles update` (zsh function in `zsh/aliases.zsh`) runs `git pull --ff-only`, then `install.sh <profile>` with the profile saved in `~/.config/dotfiles/profile`. Anything a re-run touches must leave user customizations alone: the git identity step only runs when `user.email` is unset (`ensure_git_identity`), unless invoked as `install.sh git`.

Both `install.sh` and `dotfiles update` finish by replacing the process with a fresh `zsh -l`. If the run just added the user to the `docker` group, they start it through `sg docker` so Docker works without logging out (`reload_shell` in `lib/common.sh`; the zsh copy is in `dotfiles()`). `dotfiles update` sets `DOTFILES_NO_RELOAD=1` so the installer doesn't start a nested shell.

## Adding things

- **CLI tool on both OSes:** add to `BREW_FORMULAE` and either `APT_PACKAGES` or a `github_bin` line in `linux_install_packages`.
- **Desktop app:** `BREW_CASKS_DESKTOP` (`cask|App.app`) and `linux_install_desktop_apps`.
- **Shell setup for a tool:** new `zsh/tools/<tool>.zsh`; it is picked up automatically.
- **New shared config:** add `<tool>/<file>` and a `hook_<tool>` in `lib/tools.sh` that creates or updates a user-owned entry file pointing at it (include, source, or env var). Never symlink.

## Testing

```bash
bash scripts/smoke-check.sh
# Full server run in a throwaway container (needs docker):
docker run --rm -v "$PWD":/src:ro ubuntu:24.04 bash -c '
  apt-get update -qq && apt-get install -y -qq sudo curl git >/dev/null
  useradd -m dev && echo "dev ALL=(ALL) NOPASSWD:ALL" >/etc/sudoers.d/dev
  cp -r /src /home/dev/.dotfiles && chown -R dev /home/dev/.dotfiles
  su - dev -c "bash ~/.dotfiles/install.sh server"'
```
