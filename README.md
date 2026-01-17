# Dotfiles

This repository contains my personal dotfiles, managed using [GNU Stow](https://www.gnu.org/software/stow/) to create symlinks from this repository to the appropriate locations in my home directory.

## Getting Started

These instructions will get you a copy of the project up and running on your local machine.

### Prerequisites

Before you begin, ensure you have the following installed:

*   **Git**: For cloning the repository.
*   **GNU Stow**: For managing symlinks.

    On macOS, you can install it using Homebrew:
    ```bash
    brew install stow
    ```
    On Debian/Ubuntu:
    ```bash
    sudo apt install stow
    ```

### Installation

1.  **Clone the repository**:
    It is recommended to clone this repository into your home directory as `.dotfiles`. This structure allows `stow` to work effectively by creating symlinks directly in your home directory.

    ```bash
    git clone https://github.com/raine-works/.dotfiles.git ~/.dotfiles
    ```

2.  **Navigate to the dotfiles directory**:

    ```bash
    cd ~/.dotfiles
    ```

3.  **Stow the dotfiles**:
    For each configuration you want to set up, run the `stow` command. This will create symbolic links from the repository to your home directory (`~/`).

    ```bash
    stow zsh
    stow ghostty
    stow zed
    stow starship
    ```

    For example, `stow zsh` will create a symlink for `~/.zshrc` pointing to `~/.dotfiles/zsh/.zshrc`.

    **Important**: If you already have existing configuration files (e.g., `~/.zshrc`), `stow` will not overwrite them. You should move or delete them before running `stow` for the respective package.

## Included Dotfiles

This repository includes configurations for:

*   **`zsh/`**: Zsh shell configuration (`.zshrc`).
*   **`ghostty/`**: Ghostty terminal emulator configuration (`.config/ghostty/config`).
*   **`zed/`**: Zed editor settings (`.config/zed/settings.json`).
*   **`starship/`**: Starship prompt configuration (`.config/starship/starship.toml`).
