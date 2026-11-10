# 浮世 dotfiles

[![Buy Me A Coffee](https://img.shields.io/badge/Buy_Me_A_Coffee-FFDD00?style=for-the-badge&logo=buy-me-a-coffee&logoColor=black)](https://buymeacoffee.com/raineworks)

A shared development environment for macOS and Debian/Ubuntu, in two profiles.

**Desktop** (workstation with GUI apps):

```bash
curl -fsSL https://raw.githubusercontent.com/raine-works/.dotfiles/master/setup.sh | bash -s -- desktop
```

**Server** (headless, CLI only):

```bash
curl -fsSL https://raw.githubusercontent.com/raine-works/.dotfiles/master/setup.sh | bash -s -- server
```

Already cloned? Run `~/.dotfiles/install.sh desktop` or `~/.dotfiles/install.sh server`. With no argument it asks.
Re-running is safe: every step skips what is already installed.

## What gets installed

| | Desktop | Server |
|---|:-:|:-:|
| zsh config, starship prompt, git config | ✓ | ✓ |
| Dev utilities: fzf, ripgrep, fd, bat, eza, zoxide, btop, tmux, tree, jq, lazygit, delta | ✓ | ✓ |
| Node (nvm), Bun, Go, Rust (rustup), Python (uv) | ✓ | ✓ |
| gh, Claude Code, herdr | ✓ | ✓ |
| Docker + lazydocker, kubectl, k9s, kubectx/kubens | ✓ | ✓ |
| NetBird | GUI | CLI |
| Zed (AI disabled), Ghostty, JetBrainsMono Nerd Font | ✓ | |

On macOS everything comes from Homebrew, and Docker runs in a [Colima](https://github.com/abiosoft/colima) VM instead of Docker Desktop.
On Linux, packages come from apt, Docker Engine from get.docker.com, and the rest from each tool's official installer or GitHub releases.

## Updating

```bash
dotfiles update
```

Pulls the latest shared config, re-runs the installer with the profile this machine was set up with (it skips everything already installed), and reloads the shell.
Most changes (zsh, prompt, git config) are live as soon as the pull finishes; the installer step picks up new tools and Zed settings.
Your own settings are never overwritten (see Customizing).

## Git identity

The last step logs in with `gh` and sets up git from your GitHub account:

- `user.name` from your GitHub profile, `user.email` as your GitHub noreply address
- a per-machine `~/.ssh/id_ed25519`, uploaded to GitHub as both an auth key and a signing key
- commits and tags signed with that key (shown as **Verified** on GitHub)
- `gh` as the HTTPS credential helper

Once an identity is set, later installs and updates leave it alone.

All of this is written to your own `~/.gitconfig`, never to the repo. Run it again any time with `~/.dotfiles/install.sh git`.

## Customizing

Nothing in your home directory links into the repo, so your own changes never show up as edits in `~/.dotfiles`, and `git pull` always updates cleanly.
Each tool gets a file you own that loads the shared config first; your settings go after it and win.

| Tool | Your file | How it loads the shared config |
|---|---|---|
| zsh | `~/.zshrc` | first line sources `~/.dotfiles/zsh/zshrc` |
| git | `~/.gitconfig` | `[include]` at the top; `git config --global` writes below it |
| git ignores | `~/.config/git/ignore` | copied once from `git/ignore`, then yours |
| starship | `~/.config/starship.toml` | if you create it, it replaces the shared prompt |
| Ghostty | `~/.config/ghostty/config.local` | `config` includes the shared file, then `config.local` |
| Zed | `~/.config/zed/settings.json` | shared settings merged in at install; yours win, but AI stays off |

## Layout

| Path | Purpose |
|---|---|
| `setup.sh` | Bootstrap: install Homebrew or git, clone, run `install.sh` |
| `install.sh` | Runs the profile |
| `lib/` | Install steps: `macos.sh`, `linux.sh`, `tools.sh` (languages, apps, config wiring), `git.sh` |
| `zsh/`, `starship/`, `git/`, `ghostty/`, `zed/` | Shared configs, loaded from the files above |

Set `DOTFILES_REPO` (and optionally `DOTFILES_DIR`) before running `setup.sh` to install from a fork.

## Checks

```bash
bash scripts/smoke-check.sh
```
