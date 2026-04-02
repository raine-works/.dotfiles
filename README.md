# Dotfiles

[![Buy Me A Coffee](https://img.shields.io/badge/Buy_Me_A_Coffee-FFDD00?style=for-the-badge&logo=buy-me-a-coffee&logoColor=black)](https://buymeacoffee.com/raineworks)

My personal, opinionated development environment — managed with [GNU Stow](https://www.gnu.org/software/stow/) and designed to get a new machine feeling like home in a single command.

> **Fair warning:** These dotfiles reflect *my* workflow and preferences. They ship with specific tool choices (Ghostty, Starship, fzf), a Tokyo Night Storm Starship/VS Code theme direction, rebase-oriented Git defaults, and an alias vocabulary that makes sense to me. Feel free to fork and bend them to your own taste, but don't expect a neutral starting point — this is a setup that works for one person and is shared in the spirit of "steal what's useful."

## Overview

```
~/.dotfiles/
├── ghostty/                   # Ghostty terminal emulator config
├── gitconfig/                 # Git settings, aliases, and merge strategy
├── shell/                     # Shared aliases, exports, and shell-specific rc files
│   └── .config/shell/
│       ├── shelldefs           # Core env vars and general aliases
│       ├── tools/              # Modular tool configs (auto-sourced)
│       │   ├── bun.sh
│       │   ├── deno.sh
│       │   ├── docker.sh
│       │   ├── golang.sh
│       │   ├── kubernetes.sh
│       │   ├── nvm.sh
│       │   ├── python.sh
│       │   └── rust.sh
│       ├── zshrc               # Zsh-specific config
│       └── bashrc              # Bash-specific config
├── starship/                  # Starship cross-shell prompt theme
├── vscode/                    # VS Code base settings (merged into local user settings)
├── install.sh                 # Interactive installer with tool selection
└── setup.sh                   # One-liner: clone, install deps, hand off to install.sh
```

Each top-level directory is a **Stow package** — running `stow <package>` symlinks its contents into the corresponding location under `$HOME`. Most files are symlinked only; the VS Code installer intentionally merges a tracked base config into your local `settings.json` so local edits stay out of this repo.

## Quick Start

If you want everything at once — clone the repo, install dependencies, stow all packages, and set up your Git identity — run:

```bash
curl -fsSL https://raw.githubusercontent.com/raine-works/.dotfiles/master/setup.sh | bash
```

The setup script will:
1. On macOS, auto-install **Homebrew** first if it's missing
2. Install base dependencies — **Git**, **GNU Stow**, **Starship**, and **fzf** — via Homebrew
3. Clone this repo to `~/.dotfiles` (or pull latest if it already exists)
4. Hand off to the interactive installer (`install.sh`), which will:
5. Ensure **GNU Stow** is available (defensive check; installs via Homebrew if needed)
6. Stow the core packages (`shell`, `starship`, `gitconfig`) into `$HOME`
7. Inject a single `source` line into your existing `~/.zshrc` or `~/.bashrc` (your current config is never overwritten)
8. Launch an **interactive tool picker** — choose which dev tools to install and configure (Ghostty, NVM, Bun, Deno, Go, Rust, Python, Docker, Kubernetes, VS Code)
9. Prompt you to create a local `~/.gitconfig.local` for your Git identity

## Manual Installation

### Prerequisites

| Dependency | Purpose |
|---|---|
| [Git](https://git-scm.com/) | Version control |
| [GNU Stow](https://www.gnu.org/software/stow/) | Symlink manager for dotfiles |
| [Starship](https://starship.rs/) | Cross-shell prompt |
| [fzf](https://github.com/junegunn/fzf) | Fuzzy finder used by shell aliases and completions |

```bash
# macOS
brew install stow starship fzf
```

### Steps

1. **Clone** the repo into your home directory:

    ```bash
    git clone https://github.com/raine-works/.dotfiles.git ~/.dotfiles
    cd ~/.dotfiles
    ```

2. **Run the install script** — it stows packages, then launches an interactive menu to pick which dev tools to install:

    ```bash
    ./install.sh
    ```

    On macOS, this script will auto-install Homebrew first if it is not already installed.

    The menu uses arrow keys to navigate, spacebar to toggle, and enter to confirm. Tools already detected on your system are pre-selected:

        ```
     ❯ [ ] Ghostty          GPU-accelerated terminal emulator
       [✔] NVM              Node Version Manager
       [✔] Bun              JavaScript runtime & bundler
       [ ] Deno             Secure JavaScript/TypeScript runtime
         [ ] Go               Go programming language
         [ ] Rust             Rust programming language and Cargo
       [ ] Python           Python 3 via pyenv version manager
       [ ] Docker           Docker Desktop for containers
       [ ] Kubernetes       kubectl + kubectx/kubens aliases
       [ ] VS Code          Visual Studio Code editor
       ↑/↓ navigate · space toggle · enter confirm
    ```

        If you deselect a tool that is currently installed, the installer offers to remove it (and its managed data/config where applicable). It also asks whether to run a deeper package-manager purge when supported.

    **Flags:**
    - `./install.sh --all` — select every tool without the menu
    - `./install.sh --no-tools` — skip tool selection entirely (stow + shell config only)

    **Current installer tools (source of truth: `install.sh` TOOL_REGISTRY):**
    - [ ] Ghostty — GPU-accelerated terminal emulator
    - [ ] NVM — Node Version Manager
    - [ ] Bun — JavaScript runtime & bundler
    - [ ] Deno — Secure JavaScript/TypeScript runtime
    - [ ] Go — Go programming language
    - [ ] Rust — Rust programming language and Cargo
    - [ ] Python — Python 3 via pyenv version manager
    - [ ] Docker — Docker Desktop for containers
    - [ ] Kubernetes — kubectl + kubectx/kubens aliases
    - [ ] VS Code — Visual Studio Code editor

    Or stow individual packages manually if you only want parts of the config:

    ```bash
    stow shell        # aliases, exports, PATH, shell rc files
    stow starship     # prompt theme
    stow gitconfig    # git settings + aliases
    stow vscode       # VS Code base settings (Tokyo Night Storm defaults)
    ```

    Ghostty config is stowed automatically when selected in the tool picker.

3. The installer will also prompt you to **create your local Git identity** (not tracked by this repo). You can skip this and create it manually later:

    ```bash
    cat > ~/.gitconfig.local << 'EOF'
    [user]
        email = you@example.com
        name  = Your Name
    EOF
    ```

## What's Inside

### Shell — `shell/`

Symlinks to `~/.config/shell/`. The shell config is split into a core file, modular tool configs, and shell-specific rc files:

| File | Role |
|---|---|
| `shelldefs` | Core exports, general aliases, and auto-sources everything in `tools/` |
| `tools/*.sh` | One file per tool — self-guarding modules that only activate when the tool is installed |
| `zshrc` | Zsh completions (case-insensitive, menu-select, colored), fzf integration, and Starship init |
| `bashrc` | Bash equivalents of the above |

The `HOST_IP` variable is auto-detected from your active network interface.

**General aliases** (always active):
- `..` / `...` / `....` — navigate up directories
- `cl` — clear, `lsa` — `ls -a`, `ip` — show local IP
- `fzfp` — fzf with a bat file preview

**Tool modules** (activate when the tool is on your PATH):

| Module | Aliases / Config |
|---|---|
| `tools/nvm.sh` | NVM initialization and PATH setup |
| `tools/bun.sh` | Bun shell completions |
| `tools/deno.sh` | Deno install path export (`$DENO_INSTALL`) and PATH setup |
| `tools/docker.sh` | `d`, `dps`, `dstop` (safe stop-all helper), `dc`, `dcu`, `dcd` |
| `tools/golang.sh` | GOPATH defaulting (`$HOME/go` when unset) and `GOPATH/bin` PATH setup |
| `tools/kubernetes.sh` | `k`, `ka`, `ke`, `kg`, `kd`, `kgpo`, `kgd`, `kgs`, `kgpow`, `kc`/`kns`, `kl`, `klp`/`klns` (fzf pod log selector), `kdel`, `kdelp` (fzf pod deletion) |
| `tools/python.sh` | pyenv initialization and PATH setup |
| `tools/rust.sh` | Sources `~/.cargo/env` when present |

### Ghostty — `ghostty/`

Symlinks to `~/.config/ghostty/config`.

- **Font size:** 19px
- **Font family:** JetBrainsMono Nerd Font
- **Background opacity:** 0.8 with a 50px blur radius
- **macOS option key** mapped as Alt (not Meta) for proper keybinds
- Mouse cursor hides while typing

### Git — `gitconfig/`

Symlinks to `~/.gitconfig`. Identity is kept out of version control via an `[include]` of `~/.gitconfig.local`.

Key opinions baked in:
- **Editor:** VS Code (`code --wait`)
- **Default branch:** `master`
- **Pull strategy:** rebase (no merge bubbles)
- **Merge conflict style:** `zdiff3` (shows common ancestor for clearer diffs)
- **Diff algorithm:** `histogram`
- **Rerere:** enabled — Git remembers how you resolved conflicts
- **Auto push setup:** `autoSetupRemote = true` (no more `--set-upstream` on first push)
- **Fetch:** auto-prunes deleted remote branches
- **Autocorrect:** enabled (10 decisecond delay)
- **Delta:** commented-out config ready to enable if [delta](https://github.com/dandavison/delta) is installed

**Aliases:** `st`, `co`, `ci`, `br`, `df`, `cp`, `unstage`, `undo`, `amend`, `lg` (pretty graph log), `aliases` (list all aliases)

### Starship — `starship/`

Symlinks to `~/.config/starship/starship.toml`.

- **Theme:** Tokyo Night Storm palette
- **Left prompt:** directory → git branch → input character
- **Right prompt:** Kubernetes context → Docker context → command duration → time
- **Prompt character:** green `❯` in insert mode, `[N] >>>` in vi normal mode

### VS Code — `vscode/`

Symlinks a base file at `~/Library/Application Support/Code/User/dotfiles.settings.json` on macOS.

When VS Code is selected in `install.sh`, the installer merges this base file into your local `settings.json` with local values taking precedence. That means editing settings from inside VS Code updates your local file, not this repo.

- **Theme:** `Tokyo Night Storm`
- **Extension:** `enkia.tokyo-night` (installed automatically when VS Code is selected in the installer)

## Uninstalling

To remove core dotfile packages, unstow them:

```bash
cd ~/.dotfiles
stow -D shell
stow -D ghostty
stow -D starship
stow -D gitconfig
stow -D vscode
```

This deletes only the symlinks — your original files are untouched. You may also want to remove the `# dotfiles-managed` source line from your `~/.zshrc` or `~/.bashrc`.

For development tools (Ghostty, NVM, Bun, Deno, Python/pyenv, Docker, Kubernetes, VS Code), the easiest path is to rerun `./install.sh` and deselect the tools you want removed. The script will prompt you before uninstalling anything.

## License

This project is licensed under the MIT License. See the [LICENSE](LICENSE) file for details.
