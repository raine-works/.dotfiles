# Profiles

The installer has two profiles. Both install the same shell setup and developer tools. Desktop adds GUI apps.

| | Desktop | Server |
| :--- | :-: | :-: |
| zsh config, starship prompt, git config | yes | yes |
| Dev utilities: fzf, ripgrep, fd, bat, eza, zoxide, btop, tmux, tree, jq, lazygit, delta | yes | yes |
| Node (nvm), Bun, Go, Rust (rustup), Python (uv) | yes | yes |
| gh, Claude Code, herdr | yes | yes |
| Docker, lazydocker, kubectl, k9s, kubectx and kubens | yes | yes |
| NetBird | GUI | CLI |
| Zed (AI disabled), Ghostty, JetBrainsMono Nerd Font | yes | no |

## macOS

Everything comes from Homebrew, apart from the languages that have their own installers (Node, Bun and Rust).

Formulae, for both profiles: git, curl, wget, jq, starship, zsh-autosuggestions, zsh-syntax-highlighting, fzf, ripgrep, fd, bat, eza, zoxide, btop, tmux, tree, lazygit, git-delta, go, uv, gh, herdr, colima, docker, docker-compose, docker-buildx, lazydocker, kubernetes-cli, k9s and kubectx.

Casks, desktop only: Ghostty, Zed and the JetBrainsMono Nerd Font. A cask is skipped if the app or font is already installed by hand. If a cask fails to install, the installer warns and continues.

Docker runs in a [Colima](https://github.com/abiosoft/colima) VM instead of Docker Desktop. On the first run the installer creates the VM (`vz` with Rosetta, 4 CPUs, 8 GB of memory, 60 GB of disk), registers the Compose and buildx plugins with the docker CLI, and starts Colima as a Homebrew service so Docker is available after every login. `brew services stop colima` turns that off. If Docker Desktop is still installed, the installer reminds you that you can remove it.

## Linux (Debian and Ubuntu)

- **apt:** zsh, git, curl, wget, unzip, ca-certificates, gnupg, build-essential, vim, jq, ripgrep, fd-find, bat, tree, tmux, btop, zsh-autosuggestions and zsh-syntax-highlighting. eza and git-delta come from apt when your release has them.
- **Desktop only, apt:** fontconfig, fonts-noto-cjk and python3.
- **GitHub releases**, installed to `~/.local/bin` when not already on your `PATH`: starship, fzf, eza, delta, lazygit, lazydocker, k9s, kubectx and kubens. zoxide comes from its own install script and kubectl from dl.k8s.io. gh comes from GitHub’s apt repository.
- `fd` and `bat` are linked into `~/.local/bin`, because Debian names them `fdfind` and `batcat`.
- **Go** is installed from the official tarball to `/usr/local/go`.
- **Docker Engine** comes from get.docker.com. Your user is added to the `docker` group, and the final shell starts with that group active, so you don’t need to log out. If systemd is not running, the installer warns that you must start `dockerd` yourself.
- **Desktop apps:** Zed (its install script), Ghostty (the `ghostty-ubuntu` .deb build) and the JetBrainsMono Nerd Font (into `~/.local/share/fonts`).
- zsh is set as your login shell. Where that is not possible (accounts managed by a directory service), `~/.bashrc` hands interactive shells to zsh instead, with a line marked `# dotfiles-managed`. Non-interactive bash sessions (scp, rsync, remote commands) are not affected.

## On both systems

- **Node** through nvm, with the latest LTS as the default.
- **Bun**, **Rust** through rustup, and **Python** through uv (`uv python install --default`, which puts `python` and `python3` in `~/.local/bin`).
- **Claude Code**, **herdr** and **NetBird**, each from its official installer. The server profile installs NetBird without its GUI.
- **zsh completions** for gh, kubectl, docker, uv, rustup and cargo, generated once at install into `~/.local/share/zsh/site-functions`.

The language installers are told not to edit your shell rc files. Their `PATH` setup lives in the zsh config instead; see [Shell](shell.md).
