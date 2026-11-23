# Updating

```bash
dotfiles update
```

This zsh function:

1. Runs `git pull --ff-only` in `~/.dotfiles`. If that fails, it stops.
2. Re-runs `install.sh` with the profile saved in `~/.config/dotfiles/profile`, without starting a nested shell.
3. Reloads your shell. On Linux, if the run added you to the `docker` group, the new shell starts with that group active.

Most changes (zsh, prompt, git config) are live as soon as the pull finishes. The installer step picks up new tools and Zed settings.

## What a re-run touches

Every installer step checks for what is already installed and skips it. Your files are left alone:

- The managed first line of `~/.zshrc` is refreshed; the rest is untouched.
- The managed include in `~/.gitconfig` is added only if missing.
- `~/.config/git/ignore` is never overwritten.
- Your git identity is only set if none exists.
- `config.local` for Ghostty is never overwritten.
- Zed settings are merged again with your values winning, except that `disable_ai` stays `true`.

The installer does not upgrade tools that are already installed; use Homebrew (`brew upgrade`) or apt for that.

## Without the function

If the function is not available, run the installer yourself:

```bash
git -C ~/.dotfiles pull --ff-only
~/.dotfiles/install.sh "$(cat ~/.config/dotfiles/profile)"
```
