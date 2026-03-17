# Dotfiles

Personal dotfiles managed with [GNU Stow](https://www.gnu.org/software/stow/).

## Prerequisites

*   **Git**
*   **GNU Stow**
*   **[Starship](https://starship.rs/)** — cross-shell prompt
*   **[fzf](https://github.com/junegunn/fzf)** — fuzzy finder

    ```bash
    # macOS
    brew install stow starship fzf

    # Debian/Ubuntu
    sudo apt install stow fzf
    curl -sS https://starship.rs/install.sh | sh
    ```

## Quick Start

Run this single command to clone, install dependencies, stow everything, and configure your git identity:

```bash
curl -fsSL https://raw.githubusercontent.com/raine-works/.dotfiles/master/setup.sh | bash
```

## Manual Installation

1.  **Clone the repository** into your home directory:

    ```bash
    git clone <your-repo-url> ~/.dotfiles
    cd ~/.dotfiles
    ```

2.  **Run the install script** to stow everything at once:

    ```bash
    ./install.sh
    ```

    Or stow individual packages:

    ```bash
    stow shell       # shared aliases, exports, tools → ~/.config/shell/
    stow ghostty
    stow starship
    stow gitconfig
    ```

    The install script auto-detects your shell (`$SHELL`) and appends a single `source` line to your existing `~/.zshrc` or `~/.bashrc`. Your current config is never overwritten.

3.  **Create your local git identity** (not tracked by this repo):

    ```bash
    cat > ~/.gitconfig.local << 'EOF'
    [user]
        email = you@example.com
        name = your-name
    EOF
    ```

## What's Included

| Package | Config Path | Description |
|---|---|---|
| `shell/` | `~/.config/shell/` | Shared aliases, exports, PATH + shell-specific configs |
| `ghostty/` | `~/.config/ghostty/config` | Ghostty terminal emulator |
| `starship/` | `~/.config/starship/starship.toml` | Starship prompt |
| `gitconfig/` | `~/.gitconfig` | Git configuration (includes `~/.gitconfig.local`) |

The `shell/` package contains:
- `shelldefs` — shared exports, aliases, and tool setup (POSIX-compatible)
- `zshrc` — zsh-specific completions, functions, and prompt init
- `bashrc` — bash-specific completions, functions, and prompt init

The install script adds one line to your existing rc file:
```bash
[ -f "~/.config/shell/zshrc" ] && source "~/.config/shell/zshrc" # dotfiles-managed
```
| `gitconfig/` | `~/.gitconfig` | Git configuration (includes `~/.gitconfig.local`) |
