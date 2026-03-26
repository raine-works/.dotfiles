# Dotfiles — Agent Guide

This file provides orientation for AI agents and the known-issue backlog for this repository.

---

## Overview

A personal development environment managed with **GNU Stow**. Designed to provision a new machine in one command:

```bash
curl -fsSL https://raw.githubusercontent.com/raine-works/.dotfiles/main/setup.sh | bash
```

- **Primary platform:** macOS (partial Linux support)
- **Theme:** Catppuccin Frappe applied consistently across Ghostty and Starship
- **Package manager:** Homebrew (macOS); apt fallback on Linux
- **Config strategy:** symlinks via `stow`; nothing is copied or overwritten

---

## Repository Structure

Each top-level directory is a **Stow package**. The directory tree inside each package mirrors `$HOME`, so Stow can create the correct symlinks.

```
.dotfiles/
├── agents.md               ← this file
├── install.sh              ← interactive installer (~550 lines)
├── setup.sh                ← bootstrap (curl | bash entry point)
├── README.md
├── .gitignore              ← ignores .DS_Store and *.local files
│
├── shell/                  ← stow package: shell configuration
│   └── .config/shell/
│       ├── shelldefs       ← shared aliases + env vars (zsh + bash)
│       ├── zshrc           ← zsh-specific config (completions, prompt)
│       ├── bashrc          ← bash-specific config
│       └── tools/          ← modular per-tool configs, self-guarding
│           ├── android-sdk.sh
│           ├── bun.sh
│           ├── deno.sh
│           ├── docker.sh
│           ├── kubernetes.sh
│           ├── nvm.sh
│           └── python.sh
│
├── starship/               ← stow package: Starship prompt config
│   └── .config/starship/starship.toml
│
├── gitconfig/              ← stow package: Git config
│   └── .gitconfig
│
└── ghostty/                ← stow package: Ghostty terminal config
    └── .config/ghostty/config
```

**Stow command used throughout:**
```bash
stow -d "$DOTFILES_DIR" -t "$HOME" --restow <package>
```

---

## Shell Config Layering

Understanding this chain is critical before editing any shell file.

```
~/.zshrc  (or ~/.bashrc)
  ↓  [source line injected by install.sh with marker: # dotfiles-managed:raine-works]
~/.config/shell/zshrc  (or bashrc)
  ↓  [explicit source at top of file]
~/.config/shell/shelldefs
  ↓  [glob loop: for f in tools/*.sh; do . "$f"; done]
~/.config/shell/tools/*.sh  (nvm.sh, docker.sh, kubernetes.sh, …)
```

**The injection marker** used to detect and prevent duplicate entries:
```bash
SOURCE_TAG="# dotfiles-managed:raine-works"
```

**Tool files are self-guarding** — they bail out immediately if the tool isn't installed:
```bash
# Example: docker.sh
command -v docker >/dev/null 2>&1 || return 0
```
Always follow this pattern when adding a new tool file.

**shelldefs** is sourced by both `zshrc` and `bashrc`, making it the right place for cross-shell aliases and environment variables.

---

## Installation Flow

### `setup.sh` (bootstrap)
1. Detects OS; installs Homebrew on macOS if missing
2. Installs base deps: `stow`, `git`, `starship`, `fzf` via Homebrew or apt
3. Clones the repo to `~/.dotfiles`, or pulls latest if it already exists
4. Execs into `install.sh`

### `install.sh` (interactive installer)
1. Presents an arrow-key/spacebar TUI menu to select tools
2. Stows core packages: `shell`, `starship`, `gitconfig`
3. Injects `source ~/.config/shell/{zshrc|bashrc}` into user's existing rc file
4. Runs selected tool installers
5. Prompts to create `~/.gitconfig.local` with name/email

**Flags:**
| Flag | Effect |
|------|--------|
| `--all` | Pre-select all tools, skip the menu |
| `--no-tools` | Skip tool selection entirely (stow + shell config only) |

**Re-running is safe:** `--restow` re-creates symlinks idempotently; the marker prevents double-injection of the source line.

---

## Key Conventions

### Adding a new tool config

1. Create `shell/.config/shell/tools/<toolname>.sh`
2. First line must be a self-guard:
   ```bash
   command -v <toolname> >/dev/null 2>&1 || return 0
   ```
3. No registration needed — `shelldefs` globs all `*.sh` files in `tools/` automatically

### Adding a new Stow package

1. Create `<packagename>/<mirror of $HOME path>/` — e.g. `foo/.config/foo/config`
2. Add the package name to the `STOW_PACKAGES` array in `install.sh`
3. Test first with dry run: `stow -n --simulate -d ~/.dotfiles -t ~ <packagename>`

### Adding a tool to the installer

- Follow the `install_<toolname>` / `uninstall_<toolname>` function naming convention
- Add the tool to the tool registry arrays at the top of `install.sh`
- Installer functions should detect the platform and use the appropriate package manager

### Adding cross-shell aliases or env vars

- Put them in `shell/.config/shell/shelldefs` (sourced by both zsh and bash)
- Shell-specific logic goes in `shell/.config/shell/zshrc` or `bashrc`

### Git identity

Stored in `~/.gitconfig.local` (git-ignored, user-local). The stowed `.gitconfig` includes it via `[include] path = ~/.gitconfig.local`.

---

## Testing Changes

```bash
# Dry-run stow to preview symlinks without creating them
stow -n --simulate -d ~/.dotfiles -t ~ <package>

# Re-stow a package after editing its files
stow -d ~/.dotfiles -t ~ --restow <package>

# Reload shell config without opening a new shell
exec $SHELL

# Re-run the full installer
bash ~/.dotfiles/install.sh

# Re-run with all tools selected, no menu
bash ~/.dotfiles/install.sh --all

# Re-run skipping tool selection (stow + shell config only)
bash ~/.dotfiles/install.sh --no-tools
```

---

## Known Issues / TODO

### Open

- **No pre-flight backup before `stow --restow`** — existing symlinks pointing elsewhere can still be replaced once stow executes. A preflight conflict check now exists, but automated backup/restore is still not implemented.  
  File: `install.sh`  
  Next step: Add optional backup creation for conflicting targets before any restow operation.

---

### Completed (March 2026)

- **`HOST_IP` cross-platform fallback** implemented in `shell/.config/shell/shelldefs`.
- **NVM double-sourcing** fixed in `shell/.config/shell/tools/nvm.sh` by choosing one valid source path.
- **Starship `success_symbol`** already corrected in `starship/.config/starship/starship.toml`.
- **`ANDROID_HOME` macOS-only path** fixed in `shell/.config/shell/tools/android-sdk.sh` with OS-based branching.
- **Android tool install target** updated in `install.sh` to Android Studio-first behavior, with SDK path compatibility retained.
- **`git pull --quiet` silent failures** fixed in `setup.sh` by removing quiet mode and adding explicit failure handling.
- **Unique source marker** implemented in `install.sh` (`# dotfiles-managed:raine-works`) with legacy marker compatibility.
- **Stow failure diagnostics** improved in `install.sh` with preflight checks and explicit error messaging.
- **Kubernetes empty fzf selection feedback** implemented in `shell/.config/shell/tools/kubernetes.sh` via guarded `klp`/`klns` functions.
- **Fragile Homebrew path assumptions** removed in `setup.sh` and `install.sh` by resolving brew through `command -v`.
- **`DOTFILES_REPO` hardcoded value** replaced in `setup.sh` with environment-default override.
- **`set -e` without context** addressed in `setup.sh` and `install.sh` with line-aware ERR traps.
