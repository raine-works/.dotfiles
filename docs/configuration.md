# Configuration

The installer never symlinks anything into the repository, and never writes into it. Each tool instead gets a file in your home directory that you own, and that file loads the shared config from `~/.dotfiles`. Because your settings come after the shared ones, they win. `git pull` in the repository therefore always updates cleanly.

| Tool | Your file | How it loads the shared config | Profile |
| :--- | :--- | :--- | :--- |
| zsh | `~/.zshrc` | The first line sources `~/.dotfiles/zsh/zshrc` | both |
| git | `~/.gitconfig` | An `[include]` at the top points at `git/config` | both |
| git ignores | `~/.config/git/ignore` | Copied once from `git/ignore`, then yours | both |
| starship | `~/.config/starship.toml` | If it exists it replaces the shared prompt; otherwise `STARSHIP_CONFIG` points at `starship/starship.toml` | both |
| Ghostty | `~/.config/ghostty/config` | Includes the shared `ghostty/config`, then `config.local` | desktop |
| Zed | `~/.config/zed/settings.json` | The shared settings are merged in at install | desktop |

## zsh

The first line of `~/.zshrc` is `source "~/.dotfiles/zsh/zshrc" # dotfiles-managed` (with the real path). On every install the installer removes any earlier managed line and puts the current one first. Everything else in the file is yours. See [Shell](shell.md) for what the shared config does.

## git

`~/.gitconfig` starts with the managed include:

```ini
# Managed defaults (dotfiles). Settings below this include override them.
[include]
	path = /path/to/.dotfiles/git/config
```

Anything below it, including what `git config --global` writes, overrides the shared defaults. The shared defaults include `delta` as the pager, `pull.rebase`, `fetch.prune`, `push.autoSetupRemote`, `rerere`, `zdiff3` conflict style, `defaultBranch = master`, and a set of aliases such as `st`, `co`, `sw`, `br`, `amend`, `wip`, `recent` and `lg`. Run `git aliases` to list the aliases. The identity and signing settings are written to your own `~/.gitconfig`; see [Git identity](git-identity.md).

The global ignore list is copied to `~/.config/git/ignore` only if that file does not exist. After that it is yours, and later installs never touch it.

## starship

If `~/.config/starship.toml` exists, it is used and the shared prompt is not. Otherwise the shared `starship/starship.toml` is used, an ink-wash theme with a red stamp that only appears over SSH.

## Ghostty (desktop)

`~/.config/ghostty/config` holds only includes: the shared config, then `config.local`. Ghostty loads includes after the main file, in order, so `config.local` wins. If you already had a `config` file, its contents are moved into `config.local` and nothing is lost.

The shared config sets the ToKyoNight theme, JetBrainsMono Nerd Font at size 19, a translucent blurred background, and `macos-option-as-alt`.

## Zed (desktop)

Zed rewrites its own `settings.json`, so the shared settings (`zed/settings.json`) are merged into yours rather than included. Your values win, with one exception: `disable_ai` is always forced to `true`. Comments and trailing commas in your file are tolerated but are not preserved after the merge. The shared settings also set the Tokyo Night themes (installed automatically as an extension), JetBrainsMono Nerd Font, and the panel docks.

## Files outside your home config

| Path | Purpose |
| :--- | :--- |
| `~/.config/dotfiles/profile` | The profile this machine was installed with (`desktop` or `server`) |
| `~/.local/bin` | Binaries the Linux installer places, plus `uv`'s Python |
| `~/.local/share/zsh/site-functions` | Generated zsh completions |
| `~/.local/state/zsh/history` | zsh history |
| `~/.cache/zsh/zcompdump` | The completion cache |
| `~/.config/git/allowed_signers` | Lets `git log --show-signature` verify your own commits |

## Older layouts

Earlier versions symlinked files into the repository. On every install the installer removes those links, and only links that point into the repository, so the user-owned files above can take their place.
