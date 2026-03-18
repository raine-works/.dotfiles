#!/usr/bin/env bash
set -e

DOTFILES_DIR="$(cd "$(dirname "$0")" && pwd)"
PACKAGES=(shell starship gitconfig)
SOURCE_TAG="# dotfiles-managed"

# ── Helpers ──────────────────────────────────────────────
info()  { printf "\033[1;34m[info]\033[0m  %s\n" "$1"; }
ok()    { printf "\033[1;32m[ok]\033[0m    %s\n" "$1"; }
warn()  { printf "\033[1;33m[warn]\033[0m  %s\n" "$1"; }
fail()  { printf "\033[1;31m[error]\033[0m %s\n" "$1" >&2; exit 1; }
command_exists() { command -v "$1" >/dev/null 2>&1; }

# ── Tool Registry ───────────────────────────────────────
TOOL_IDS=(    ghostty            nvm               bun                            deno                               docker                                   kubernetes            vscode)
TOOL_NAMES=(  "Ghostty"          "NVM"             "Bun"                          "Deno"                             "Docker"                                 "Kubernetes"          "VS Code")
TOOL_DESCS=(  "GPU-accelerated terminal emulator"  "Node Version Manager"  "JavaScript runtime & bundler"  "Secure JavaScript/TypeScript runtime"  "Docker Desktop for containers"              "kubectl + kubectx/kubens aliases"  "Visual Studio Code editor")

# ── Interactive Tool Menu ────────────────────────────────
show_menu() {
    local num=${#TOOL_IDS[@]}
    local selected=()
    local cursor=0
    local first_draw=true

    # Pre-select tools already present on the system
    for ((i = 0; i < num; i++)); do
        selected+=(false)
        case "${TOOL_IDS[$i]}" in
            ghostty)    command_exists ghostty                                  && selected[$i]=true ;;
            nvm)        [ -d "$HOME/.nvm" ]                                    && selected[$i]=true ;;
            bun)        command_exists bun                                      && selected[$i]=true ;;
            deno)       command_exists deno                                     && selected[$i]=true ;;
            docker)     command_exists docker                                   && selected[$i]=true ;;
            kubernetes) command_exists kubectl                                  && selected[$i]=true ;;
            vscode)     command_exists code                                     && selected[$i]=true ;;
        esac
    done

    tput civis 2>/dev/null || true

    while true; do
        $first_draw || printf "\033[%dA" "$num"
        first_draw=false

        for ((i = 0; i < num; i++)); do
            local check=" "
            [[ "${selected[$i]}" == true ]] && check="✔"
            local name
            name=$(printf "%-16s" "${TOOL_NAMES[$i]}")

            if [[ $i -eq $cursor ]]; then
                printf "\r\033[K\033[1;36m ❯ [%s] %s %s\033[0m\n" "$check" "$name" "${TOOL_DESCS[$i]}"
            else
                printf "\r\033[K   [%s] %s %s\n" "$check" "$name" "${TOOL_DESCS[$i]}"
            fi
        done
        printf "\r\033[K\033[2m   ↑/↓ navigate · space toggle · enter confirm\033[0m"

        IFS= read -rsn1 key < /dev/tty
        case "$key" in
            $'\x1b')
                read -rsn2 key < /dev/tty
                case "$key" in
                    '[A') ((cursor > 0)) && ((cursor--)) || true ;;
                    '[B') ((cursor < num - 1)) && ((cursor++)) || true ;;
                esac ;;
            ' ')
                [[ "${selected[$cursor]}" == true ]] && selected[$cursor]=false || selected[$cursor]=true ;;
            '')
                break ;;
        esac
    done

    printf "\n"
    tput cnorm 2>/dev/null || true

    SELECTED_TOOLS=()
    for ((i = 0; i < num; i++)); do
        [[ "${selected[$i]}" == true ]] && SELECTED_TOOLS+=("${TOOL_IDS[$i]}")
    done
}

# ── Tool Installers ──────────────────────────────────────
install_ghostty() {
    if command_exists ghostty; then
        ok "Ghostty already installed"
    elif command_exists brew; then
        info "Installing Ghostty via Homebrew..."
        brew install --cask ghostty
        ok "Ghostty installed"
    elif command_exists pacman; then
        info "Installing Ghostty via pacman..."
        sudo pacman -S --noconfirm ghostty
        ok "Ghostty installed"
    elif command_exists dnf; then
        info "Installing Ghostty via DNF (Terra)..."
        sudo dnf install -y --nogpgcheck --repofrompath 'terra,https://repos.fyralabs.com/terra$releasever' terra-release 2>/dev/null || true
        sudo dnf install -y ghostty
        ok "Ghostty installed"
    elif command_exists snap; then
        info "Installing Ghostty via Snap..."
        sudo snap install ghostty --classic
        ok "Ghostty installed"
    else
        warn "Install Ghostty manually: https://ghostty.org/docs/install/binary"
    fi
    if [ -d "$DOTFILES_DIR/ghostty" ]; then
        stow -d "$DOTFILES_DIR" -t "$HOME" --restow ghostty && ok "  ghostty config stowed"
    fi
}

install_nvm() {
    if [ -d "$HOME/.nvm" ] || command_exists nvm; then
        ok "NVM already installed"
        return
    fi
    if command_exists brew; then
        info "Installing NVM via Homebrew..."
        brew install nvm
    else
        info "Installing NVM via install script (latest)..."
        local nvm_latest
        nvm_latest=$(curl -fsSL https://api.github.com/repos/nvm-sh/nvm/releases/latest | grep '"tag_name"' | sed -E 's/.*"([^"]+)".*/\1/')
        PROFILE=/dev/null bash <(curl -fsSL "https://raw.githubusercontent.com/nvm-sh/nvm/${nvm_latest}/install.sh")
    fi
    ok "NVM installed"
}

install_bun() {
    if command_exists bun; then
        ok "Bun already installed"
        return
    fi
    info "Installing Bun..."
    bash <(curl -fsSL https://bun.sh/install)
    ok "Bun installed"
}

install_deno() {
    if command_exists deno; then
        ok "Deno already installed"
        return
    fi
    if command_exists brew; then
        info "Installing Deno via Homebrew..."
        brew install deno
    else
        info "Installing Deno via install script..."
        bash <(curl -fsSL https://deno.land/install.sh)
    fi
    ok "Deno installed"
}

install_docker() {
    if command_exists docker; then
        ok "Docker Desktop already installed"
        return
    fi
    if command_exists brew; then
        info "Installing Docker Desktop via Homebrew..."
        brew install --cask docker
        ok "Docker Desktop installed"
    else
        warn "Install Docker Desktop manually: https://www.docker.com/products/docker-desktop/"
    fi
}

install_kubernetes() {
    if ! command_exists kubectl; then
        if command_exists brew; then
            info "Installing kubectl via Homebrew..."
            brew install kubectl
            ok "kubectl installed"
        elif command_exists apt-get; then
            info "Installing kubectl via snap..."
            sudo snap install kubectl --classic 2>/dev/null && ok "kubectl installed" \
                || warn "kubectl install failed — install it manually."
        else
            warn "Install kubectl manually: https://kubernetes.io/docs/tasks/tools/"
        fi
    else
        ok "kubectl already installed"
    fi

    if ! command_exists kubectx && command_exists brew; then
        info "Installing kubectx & kubens via Homebrew..."
        brew install kubectx
        ok "kubectx installed"
    fi
}

install_vscode() {
    if command_exists code; then
        ok "VS Code already installed"
        return
    fi
    if command_exists brew; then
        info "Installing VS Code via Homebrew..."
        brew install --cask visual-studio-code
        ok "VS Code installed"
    else
        warn "Install VS Code manually: https://code.visualstudio.com/"
    fi
}

# ── Stow Packages ───────────────────────────────────────
stow_packages() {
    info "Stowing dotfiles..."
    for pkg in "${PACKAGES[@]}"; do
        if [ -d "$DOTFILES_DIR/$pkg" ]; then
            stow -d "$DOTFILES_DIR" -t "$HOME" --restow "$pkg" && ok "  $pkg"
        fi
    done
}

# ── Shell RC Injection ──────────────────────────────────
inject_shell_config() {
    local rc_file config_file

    case "$(basename "$SHELL")" in
        zsh)  rc_file="$HOME/.zshrc";  config_file="$HOME/.config/shell/zshrc"  ;;
        bash) rc_file="$HOME/.bashrc"; config_file="$HOME/.config/shell/bashrc" ;;
        *)    warn "Unrecognized shell ($SHELL) — source ~/.config/shell/zshrc (or bashrc) manually."
              return ;;
    esac

    local source_line="[ -f \"$config_file\" ] && source \"$config_file\" $SOURCE_TAG"

    if [ ! -f "$rc_file" ]; then
        echo "$source_line" > "$rc_file"
        ok "Created $rc_file"
    elif ! grep -qF "$SOURCE_TAG" "$rc_file"; then
        printf "\n%s\n" "$source_line" >> "$rc_file"
        ok "Appended source line to $rc_file"
    else
        ok "$rc_file already configured"
    fi
}

# ── Git Identity ────────────────────────────────────────
setup_git_identity() {
    if [ -f "$HOME/.gitconfig.local" ]; then
        ok "~/.gitconfig.local already exists"
        return
    fi

    echo ""
    info "Setting up Git identity (~/.gitconfig.local)"
    read -rp "  Git name:  " git_name  < /dev/tty
    read -rp "  Git email: " git_email < /dev/tty

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
}

# ── Main ─────────────────────────────────────────────────
main() {
    local select_all=false
    local skip_tools=false

    for arg in "$@"; do
        case "$arg" in
            --all)       select_all=true ;;
            --no-tools)  skip_tools=true ;;
        esac
    done

    echo ""
    echo "  ╔══════════════════════════════════╗"
    echo "  ║       Dotfiles Installer         ║"
    echo "  ╚══════════════════════════════════╝"
    echo ""

    if [[ "$(uname)" == "Darwin" ]] && ! command_exists brew; then
        info "Installing Homebrew..."
        bash <(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)
        eval "$(/opt/homebrew/bin/brew shellenv 2>/dev/null || /usr/local/bin/brew shellenv 2>/dev/null)"
        ok "Homebrew installed"
    fi

    if ! command_exists stow; then
        if command_exists brew; then
            info "Installing GNU Stow via Homebrew..."
            brew install stow
            ok "GNU Stow installed"
        else
            fail "GNU Stow is required. Install it first."
        fi
    fi

    stow_packages
    inject_shell_config

    echo ""

    if $skip_tools; then
        info "Skipping tool installation (--no-tools)"
    else
        info "Select the development tools you'd like to install:"
        info "Tools already detected on your system are pre-selected."
        echo ""

        if $select_all; then
            SELECTED_TOOLS=("${TOOL_IDS[@]}")
        else
            show_menu
        fi

        if [ ${#SELECTED_TOOLS[@]} -gt 0 ]; then
            echo ""
            info "Installing selected tools..."
            echo ""
            for tool in "${SELECTED_TOOLS[@]}"; do
                "install_$tool"
            done
        else
            info "No tools selected — skipping installation."
            info "Re-run this script anytime to add tools."
        fi
    fi

    echo ""
    setup_git_identity

    echo ""
    ok "All done! Restart your shell (or run: exec \$SHELL) to pick up the new config."
}

main "$@"
