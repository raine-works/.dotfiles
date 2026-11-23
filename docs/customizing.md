# Customizing

Put your own settings in the file each tool gives you. They load after the shared config, so they win, and they never appear as changes in `~/.dotfiles`. Don’t edit the files in the repository for personal changes: `git pull` would conflict, and `dotfiles update` stops if it cannot fast-forward.

## zsh

Add anything after the first line of `~/.zshrc`. Leave that first line (the one ending in `# dotfiles-managed`) in place. For example:

```zsh
alias mine='echo hello'
export EDITOR=nano
```

Reload with `reload` (an alias for `exec zsh`).

## git

Use `git config --global`, or edit `~/.gitconfig` below the managed include. Your values override the shared ones.

`~/.config/git/ignore` is your own copy of the global ignore list. Edit it freely.

## starship

Create `~/.config/starship.toml`. Once it exists, it replaces the shared prompt entirely. To go back, delete it.

## Ghostty

Add settings to `~/.config/ghostty/config.local`. Don’t put them in `~/.config/ghostty/config`: that file only holds the includes.

## Zed

Edit `~/.config/zed/settings.json` as normal. Your values survive later installs. The exception is `disable_ai`, which is set back to `true` each time the installer runs.

## Other machines and forks

To change the shared config for everyone who uses it, change the repository itself. See [Development](development.md). To install from a fork, set `DOTFILES_REPO` before running `setup.sh`; see [Installation](installation.md).
