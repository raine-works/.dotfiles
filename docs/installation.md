# Installation

## Supported systems

- macOS, on Intel or Apple silicon (`x86_64` and `arm64`)
- Debian and Ubuntu (anything with `apt`), on `x86_64` or `arm64`

Other systems and architectures stop with an error. On Linux the installer uses `sudo` unless you are root.

## The one command

Pick a profile (see [Profiles](profiles.md)) and run one of these.

Desktop, a workstation with GUI apps:

```bash
curl -fsSL https://raw.githubusercontent.com/raine-works/.dotfiles/master/setup.sh | bash -s -- desktop
```

Server, headless with CLI tools only:

```bash
curl -fsSL https://raw.githubusercontent.com/raine-works/.dotfiles/master/setup.sh | bash -s -- server
```

`setup.sh` is the bootstrap. It:

1. Installs Homebrew on macOS (which includes git), or git, curl and ca-certificates through apt on Linux, if they are missing.
2. Clones the repository to `~/.dotfiles`, or fast-forwards it if it is already there. If it cannot fast-forward (for example because of local changes), it says so and continues with what is on disk.
3. Hands over to `install.sh` with the profile you gave.

To install from a fork, set `DOTFILES_REPO` (and optionally `DOTFILES_DIR`, which defaults to `~/.dotfiles`) before running `setup.sh`.

## From a clone

If the repository is already cloned:

```bash
~/.dotfiles/install.sh desktop
~/.dotfiles/install.sh server
```

With no argument, `install.sh` asks which profile you want. `install.sh git` runs only the [git identity](git-identity.md) step.

## What the installer does

In order:

1. Records the profile in `~/.config/dotfiles/profile`, so [updates](updating.md) reuse it.
2. Installs system packages (Homebrew on macOS, apt and GitHub releases on Linux).
3. Wires up the configuration files, straight after the base packages, so a later failure never leaves a half-configured shell. See [Configuration](configuration.md).
4. Installs the language toolchains: Node through nvm, Bun, Rust through rustup, Go, and Python through uv.
5. Installs Claude Code, herdr and NetBird.
6. Sets up Docker: Colima on macOS, Docker Engine on Linux. On the desktop profile for Linux it also installs the desktop apps.
7. Generates zsh completions.
8. On Linux, makes zsh the login shell.
9. Sets up your [git identity](git-identity.md) if none is set.
10. Prints any warnings collected along the way, then starts a fresh zsh.

Core steps (packages, languages, config wiring) stop the run if they fail. Optional apps (casks, GUI apps, Claude Code, herdr, NetBird, starting Colima) print a warning and the run continues. The warnings are repeated in the closing summary.

## Re-running safely

Re-running the installer is the supported way to update. Every step checks what is already there and skips it, and your own settings are never overwritten. See [Updating](updating.md).

## Uninstalling

There is no uninstaller. The installer never symlinks into the repository, so removing the config is a matter of deleting the line marked `# dotfiles-managed` from `~/.zshrc` and the managed `[include]` from `~/.gitconfig`; see [Configuration](configuration.md) for each file. Installed tools stay in place.
