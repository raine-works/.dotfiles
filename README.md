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
    stow shell       # shared aliases & exports (always stow this)
    stow zsh         # if using zsh
    stow bash        # if using bash
    stow ghostty
    stow starship
    stow gitconfig
    ```

    The install script auto-detects your shell (`$SHELL`) and stows the correct one.

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
| `shell/` | `~/.shelldefs` | Shared aliases, exports, and PATH setup |
| `zsh/` | `~/.zshrc` | Zsh-specific config (sources `~/.shelldefs`) |
| `bash/` | `~/.bashrc` | Bash-specific config (sources `~/.shelldefs`) |
| `ghostty/` | `~/.config/ghostty/config` | Ghostty terminal emulator |
| `starship/` | `~/.config/starship/starship.toml` | Starship prompt |
| `gitconfig/` | `~/.gitconfig` | Git configuration (includes `~/.gitconfig.local`) |
