#!/usr/bin/env bash
set -Ee

DOTFILES_REPO="${DOTFILES_REPO:-https://github.com/raine-works/.dotfiles.git}"
DOTFILES_DIR="$HOME/.dotfiles"

# ── Helpers ──────────────────────────────────────────────
info() { printf "\033[1;34m[info]\033[0m  %s\n" "$1"; }
ok() { printf "\033[1;32m[ok]\033[0m    %s\n" "$1"; }
warn() { printf "\033[1;33m[warn]\033[0m  %s\n" "$1"; }
fail() {
    printf "\033[1;31m[error]\033[0m %s\n" "$1" >&2
    exit 1
}
command_exists() { command -v "$1" >/dev/null 2>&1; }

on_err() {
    local line_no="$1"
    local exit_code="$2"
    fail "setup.sh failed at line ${line_no} (exit ${exit_code})"
}

trap 'on_err "$LINENO" "$?"' ERR

eval_brew_shellenv() {
    local brew_bin
    brew_bin="$(command -v brew 2>/dev/null || true)"
    [ -n "$brew_bin" ] && eval "$("$brew_bin" shellenv)"
}

# ── Platform bootstrap ──────────────────────────────────
ensure_homebrew_macos() {
    if [[ "$(uname)" == "Darwin" ]] && ! command_exists brew; then
        info "Homebrew not found — installing..."
        bash <(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)
        eval_brew_shellenv
        ok "Homebrew installed"
    fi
}

# ── Install base dependencies ───────────────────────────
install_base_deps() {
    if command_exists brew; then
        info "Installing base dependencies via Homebrew..."
        if ! brew update; then
            warn "Homebrew update failed; continuing with dependency checks"
        fi

        local pkg
        for pkg in stow git starship fzf; do
            if ! brew list --formula "$pkg" >/dev/null 2>&1; then
                HOMEBREW_NO_AUTO_UPDATE=1 brew install "$pkg" || warn "Failed to install $pkg via Homebrew"
            fi
        done

        return 0
    elif command_exists apt-get; then
        info "Installing base dependencies via apt..."
        sudo apt-get update -qq
        sudo apt-get install -y -qq git stow fzf

        if ! command_exists starship; then
            info "Installing Starship prompt..."
            curl -fsSL https://starship.rs/install.sh | sh -s -- -y
        fi
    elif command_exists dnf; then
        info "Installing base dependencies via DNF..."
        local pkg
        for pkg in git stow fzf; do
            sudo dnf install -y "$pkg" || warn "Failed to install $pkg via DNF"
        done

        if ! command_exists starship; then
            info "Installing Starship prompt..."
            curl -fsSL https://starship.rs/install.sh | sh -s -- -y
        fi
    elif command_exists pacman; then
        info "Installing base dependencies via pacman..."
        local pkg
        for pkg in git stow fzf; do
            sudo pacman -S --noconfirm "$pkg" || warn "Failed to install $pkg via pacman"
        done

        if ! command_exists starship; then
            info "Installing Starship prompt..."
            curl -fsSL https://starship.rs/install.sh | sh -s -- -y
        fi
    else
        command_exists git || fail "git is required. Install it and re-run."
        command_exists stow || fail "stow is required. Install it and re-run."
        command_exists starship || fail "starship is required: https://starship.rs"
        command_exists fzf || fail "fzf is required: https://github.com/junegunn/fzf"
    fi
}

# ── Clone or update ─────────────────────────────────────
clone_dotfiles() {
    if [ -d "$DOTFILES_DIR/.git" ]; then
        info "Dotfiles repo exists — pulling latest..."
        if ! git -C "$DOTFILES_DIR" pull --rebase; then
            warn "git pull --rebase failed. Attempting to abort any in-progress rebase..."
            git -C "$DOTFILES_DIR" rebase --abort >/dev/null 2>&1 || true
            fail "Failed to update dotfiles repo at $DOTFILES_DIR. Check: git -C $DOTFILES_DIR status"
        fi
    elif [ -d "$DOTFILES_DIR" ]; then
        fail "$DOTFILES_DIR exists but is not a git repo. Remove it first."
    else
        info "Cloning dotfiles into $DOTFILES_DIR..."
        git clone "$DOTFILES_REPO" "$DOTFILES_DIR"
    fi
}

# ── Run ──────────────────────────────────────────────────
ensure_homebrew_macos
install_base_deps
clone_dotfiles

# Hand off to the interactive installer
exec "$DOTFILES_DIR/install.sh" "$@"
