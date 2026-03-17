#!/usr/bin/env bash
set -e

DOTFILES_REPO="https://github.com/raine-works/.dotfiles.git"
DOTFILES_DIR="$HOME/.dotfiles"
PACKAGES=(shell ghostty starship gitconfig)

# Detect shell and add the right shell package
case "$(basename "$SHELL")" in
    zsh)  PACKAGES+=(zsh)  ;;
    bash) PACKAGES+=(bash) ;;
    *)    warn "Unrecognized shell ($SHELL) — skipping shell config" ;;
esac

# -------------------------------------------------------------------
# Helpers
# -------------------------------------------------------------------
info()  { printf "\033[1;34m[info]\033[0m  %s\n" "$1"; }
ok()    { printf "\033[1;32m[ok]\033[0m    %s\n" "$1"; }
warn()  { printf "\033[1;33m[warn]\033[0m  %s\n" "$1"; }
fail()  { printf "\033[1;31m[error]\033[0m %s\n" "$1" >&2; exit 1; }

command_exists() { command -v "$1" >/dev/null 2>&1; }

# -------------------------------------------------------------------
# 1. Install prerequisites
# -------------------------------------------------------------------
install_deps() {
    if command_exists brew; then
        info "Installing dependencies via Homebrew..."
        brew install stow git starship fzf 2>/dev/null || true
    elif command_exists apt-get; then
        info "Installing dependencies via apt..."
        sudo apt-get update -qq && sudo apt-get install -y -qq stow git fzf
        command_exists starship || {
            info "Installing Starship..."
            curl -sS https://starship.rs/install.sh | sh -s -- -y
        }
    else
        command_exists git      || fail "git is required but not found. Install it and re-run."
        command_exists stow     || fail "stow is required but not found. Install it and re-run."
        command_exists starship || fail "starship is required but not found. Install it: https://starship.rs"
        command_exists fzf      || fail "fzf is required but not found. Install it: https://github.com/junegunn/fzf"
    fi
}

# -------------------------------------------------------------------
# 2. Clone or update the repo
# -------------------------------------------------------------------
clone_dotfiles() {
    if [ -d "$DOTFILES_DIR/.git" ]; then
        info "Dotfiles repo already exists, pulling latest..."
        git -C "$DOTFILES_DIR" pull --rebase --quiet
    else
        if [ -d "$DOTFILES_DIR" ]; then
            fail "$DOTFILES_DIR already exists but is not a git repo. Remove it first."
        fi
        info "Cloning dotfiles into $DOTFILES_DIR..."
        git clone "$DOTFILES_REPO" "$DOTFILES_DIR"
    fi
}

# -------------------------------------------------------------------
# 3. Stow packages
# -------------------------------------------------------------------
stow_packages() {
    info "Stowing packages..."
    for pkg in "${PACKAGES[@]}"; do
        if [ -d "$DOTFILES_DIR/$pkg" ]; then
            # --restow re-creates symlinks cleanly
            stow -d "$DOTFILES_DIR" -t "$HOME" --restow "$pkg" && ok "$pkg"
        fi
    done
}

# -------------------------------------------------------------------
# 4. Git identity setup
# -------------------------------------------------------------------
setup_git_identity() {
    if [ ! -f "$HOME/.gitconfig.local" ]; then
        echo ""
        info "Setting up your git identity (~/.gitconfig.local)"
        read -rp "  Git name:  " git_name
        read -rp "  Git email: " git_email

        if [ -n "$git_name" ] && [ -n "$git_email" ]; then
            cat > "$HOME/.gitconfig.local" <<EOF
[user]
    name = $git_name
    email = $git_email
EOF
            ok "Created ~/.gitconfig.local"
        else
            warn "Skipped — create ~/.gitconfig.local manually later."
        fi
    else
        ok "~/.gitconfig.local already exists, skipping."
    fi
}

# -------------------------------------------------------------------
# Run
# -------------------------------------------------------------------
echo ""
echo "  ╔══════════════════════════════════╗"
echo "  ║       Dotfiles Installer         ║"
echo "  ╚══════════════════════════════════╝"
echo ""

install_deps
clone_dotfiles
stow_packages
setup_git_identity

echo ""
ok "All done! Restart your shell or run: source ~/.zshrc"
