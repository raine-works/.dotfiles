# Troubleshooting

## The installer stops with an error

The failing line is printed (`install.sh failed at line …`). Core steps (packages, languages, config wiring) stop the run. Fix the cause and re-run; finished steps are skipped.

## “Only Debian/Ubuntu (apt) Linux is supported” or “Unsupported OS”

The installer supports macOS and Linux with `apt`, on `x86_64` or `arm64`. Anything else is refused.

## An optional app did not install

Casks, Zed, Ghostty, Claude Code, herdr, NetBird and the Nerd Font print a warning and the run continues. The warning is repeated at the end with a link or hint. Re-run the installer to retry, or install the app yourself; an app already on your system is detected and skipped.

## A GitHub release asset was not found

On Linux the installer prints “No release asset for … matched …; skipped” if a project’s release naming changes. The rest of the install continues. Install that tool another way.

## The git identity step was skipped

“No terminal for GitHub login” or “GitHub login skipped” means there was no terminal or the login was cancelled. Run `~/.dotfiles/install.sh git`. See [Git identity](git-identity.md).

## Docker does not work

- **macOS:** the installer warns “Colima failed to start; run 'colima start' to see why” or “Docker isn't answering yet”. Check the Colima log under the Homebrew prefix (`var/log/colima.log`) and `brew services info colima`.
- **Linux, permission denied:** you were added to the `docker` group, which takes effect in a new login. The installer’s final shell already has it; other terminals need a fresh login.
- **Linux, “systemd not running”:** start `dockerd` yourself.

## Fonts or icons look wrong

The prompt and `eza` icons need the JetBrainsMono Nerd Font. The desktop profile installs it. On a server, set the font in your terminal on the machine you connect from.

## `dotfiles update` fails to pull

`git pull --ff-only` fails if `~/.dotfiles` has local changes or has diverged. Keep personal changes in the files described in [Customizing](customizing.md), and return the clone to a clean state before updating.

## The shell is not zsh after install

On Linux the installer changes your login shell, which applies at the next login. If your account is managed by a directory service and `chsh` cannot change it, the installer adds a line to `~/.bashrc` that hands interactive shells to zsh. Start zsh now with `exec zsh`.

## My `~/.zshrc` changes are ignored

Keep the first line (ending in `# dotfiles-managed`) and put your settings after it. Open a new shell with `reload`.
