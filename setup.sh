#!/usr/bin/env bash
set -e

DOTFILES_REPO="https://github.com/raine-works/.dotfiles.git"
DOTFILES_DIR="$HOME/.dotfiles"

# ── Helpers ──────────────────────────────────────────────
info()  { printf "\033[1;34m[info]\033[0m  %s\n" "$1"; }
ok()    { printf "\033[1;32m[ok]\033[0m    %s\n" "$1"; }
warn()  { printf "\033[1;33m[warn]\033[0m  %s\n" "$1"; }
fail()  { printf "\033[1;31m[error]\033[0m %s\n" "$1" >&2; exit 1; }
command_exists() { command -v "$1" >/dev/null 2>&1; }

# ── Install base dependencies ───────────────────────────
install_base_deps() {
    if command_exists brew; then
        info "Installing base dependencies via Homebrew..."
        brew install stow git starship fzf 2>/dev/null || true
    elif command_exists apt-get; then
        info "Installing base dependencies via apt..."
        sudo apt-get update -qq && sudo apt-get install -y -qq stow git fzf
        command_exists starship || {
            info "Installing Starship..."
            curl -sS https://starship.rs/install.sh | sh -s -- -y
        }
    else
        command_exists git      || fail "git is required. Install it and re-run."
        command_exists stow     || fail "stow is required. Install it and re-run."
        command_exists starship || fail "starship is required: https://starship.rs"
        command_exists fzf      || fail "fzf is required: https://github.com/junegunn/fzf"
    fi
}

# ── Clone or update ─────────────────────────────────────
clone_dotfiles() {
    if [ -d "$DOTFILES_DIR/.git" ]; then
        info "Dotfiles repo exists — pulling latest..."
        git -C "$DOTFILES_DIR" pull --rebase --quiet
    elif [ -d "$DOTFILES_DIR" ]; then
        fail "$DOTFILES_DIR exists but is not a git repo. Remove it first."
    else
        info "Cloning dotfiles into $DOTFILES_DIR..."
        git clone "$DOTFILES_REPO" "$DOTFILES_DIR"
    fi
}

# ── Run ──────────────────────────────────────────────────
install_base_deps
clone_dotfiles

# Hand off to the interactive installer
exec "$DOTFILES_DIR/install.sh" "$@"
