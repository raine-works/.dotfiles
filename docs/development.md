# Development

This page is for changing the dotfiles themselves. The repository is used by several people, so two rules apply to everything:

- **User-agnostic.** No names, emails, hostnames or personal paths in tracked files. Identity comes from each user’s own `gh` login.
- **The clone stays clean.** Nothing in `$HOME` symlinks into the repository, and no installer writes into it. Personal changes go in the user-owned files described in [Configuration](configuration.md).

## Layout

| Path | Purpose |
| :--- | :--- |
| `setup.sh` | Bootstrap: install Homebrew or git, clone, run `install.sh` |
| `install.sh` | Profile entry point: `desktop`, `server` or `git` |
| `lib/common.sh` | Logging, OS and architecture detection, helpers |
| `lib/macos.sh` | Homebrew formulae and casks, Colima setup |
| `lib/linux.sh` | apt packages, GitHub-release binaries, gh, Go, Docker, desktop apps |
| `lib/tools.sh` | Languages, Claude Code, herdr, NetBird, config wiring |
| `lib/git.sh` | GitHub login, SSH key and identity |
| `lib/merge_jsonc.py` | Zed settings merge |
| `scripts/smoke-check.sh` | Offline checks, also run in CI |
| `zsh/`, `starship/`, `git/`, `ghostty/`, `zed/` | The shared configs |

## Conventions

- **Profiles:** shared steps run for both; gate desktop-only work with `if [ "$profile" = desktop ]`. Don’t end a function with `[ … ] && cmd`: under `set -e` a false test fails the caller.
- **Idempotence:** check first (`has <cmd>` or a path test) and call `skip` when already present.
- **No rc edits by installers:** pass each tool’s flag to stop it editing rc files. PATH setup lives in `zsh/tools/`.
- **Linux binaries** go in `~/.local/bin`: prefer apt, then `github_bin <cmd> <repo> <asset-regex>`.
- **Warnings** the user must act on go through `note`, so they repeat in the final summary.
- **Failure policy:** core steps stop the run; optional apps `note` and continue.
- **zsh tool files** guard themselves with `(( $+commands[tool] )) || return 0`.
- **Completions** are generated once at install, not at shell startup.
- **Bash style:** 4-space indent, `shfmt -i 4 -ci`, clean under `shellcheck -x`.

## Adding things

- **A CLI tool on both systems:** add it to `BREW_FORMULAE`, and to `APT_PACKAGES` or a `github_bin` line in `linux_install_packages`.
- **A desktop app:** add it to `BREW_CASKS_DESKTOP` (as `cask|App.app`) and to `linux_install_desktop_apps`.
- **Shell setup for a tool:** add `zsh/tools/<tool>.zsh`; it is picked up automatically.
- **New shared config:** add `<tool>/<file>` and a `hook_<tool>` in `lib/tools.sh` that creates or updates a user-owned entry file pointing at it. Never symlink.

## Testing

The offline checks need no network:

```bash
bash scripts/smoke-check.sh
```

They check bash and zsh syntax, run `shellcheck` and `shfmt` when installed, parse the git, Zed and starship configs, check the Zed merge, and wire the configs into a scratch `HOME` twice, verifying that your own settings are kept, that no symlinks are created and that the repository stays clean. CI (`.github/workflows/shell-quality.yml`) runs the same script on every pull request and push to `master`.

To test a full server install in a throwaway container (needs Docker):

```bash
docker run --rm -v "$PWD":/src:ro ubuntu:24.04 bash -c '
  apt-get update -qq && apt-get install -y -qq sudo curl git >/dev/null
  useradd -m dev && echo "dev ALL=(ALL) NOPASSWD:ALL" >/etc/sudoers.d/dev
  cp -r /src /home/dev/.dotfiles && chown -R dev /home/dev/.dotfiles
  su - dev -c "bash ~/.dotfiles/install.sh server"'
```

Don’t run the installer on a machine you care about while testing changes to it.
