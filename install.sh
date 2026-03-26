#!/usr/bin/env bash
set -Ee

DOTFILES_DIR="$(cd "$(dirname "$0")" && pwd)"
PACKAGES=(shell starship gitconfig)
SOURCE_TAG="# dotfiles-managed:raine-works"
LEGACY_SOURCE_TAG="# dotfiles-managed"
DETECTED_TOOLS=()

# ── Helpers ──────────────────────────────────────────────
info()  { printf "\033[1;34m[info]\033[0m  %s\n" "$1"; }
ok()    { printf "\033[1;32m[ok]\033[0m    %s\n" "$1"; }
warn()  { printf "\033[1;33m[warn]\033[0m  %s\n" "$1"; }
fail()  { printf "\033[1;31m[error]\033[0m %s\n" "$1" >&2; exit 1; }
command_exists() { command -v "$1" >/dev/null 2>&1; }

android_studio_installed() {
    [ -d "/Applications/Android Studio.app" ] && return 0
    [ -d "$HOME/Applications/Android Studio.app" ] && return 0

    if command_exists brew; then
        brew list --cask android-studio >/dev/null 2>&1 && return 0
    fi

    return 1
}

on_err() {
    local line_no="$1"
    local exit_code="$2"
    fail "install.sh failed at line ${line_no} (exit ${exit_code})"
}

trap 'on_err "$LINENO" "$?"' ERR

eval_brew_shellenv() {
    local brew_bin
    brew_bin="$(command -v brew 2>/dev/null || true)"
    [ -n "$brew_bin" ] && eval "$("$brew_bin" shellenv)"
}

check_stow_preflight() {
    local pkg="$1"
    local output

    if ! output=$(stow -n --simulate -d "$DOTFILES_DIR" -t "$HOME" --restow "$pkg" 2>&1); then
        warn "Stow preflight failed for package: $pkg"
        printf "%s\n" "$output" >&2
        fail "Resolve the stow conflicts above and re-run installer."
    fi
}

restow_package() {
    local pkg="$1"
    local label="$2"

    check_stow_preflight "$pkg"
    if stow -d "$DOTFILES_DIR" -t "$HOME" --restow "$pkg"; then
        ok "$label"
    else
        fail "Failed to stow package: $pkg"
    fi
}

unstow_package() {
    local pkg="$1"
    local label="$2"

    if stow -d "$DOTFILES_DIR" -t "$HOME" -D "$pkg"; then
        ok "$label"
    else
        warn "Failed to unstow package: $pkg"
    fi
}

array_contains() {
    local needle="$1"
    shift
    local item
    for item in "$@"; do
        [[ "$item" == "$needle" ]] && return 0
    done
    return 1
}

tool_name() {
    local tool_id="$1"
    local i
    for ((i = 0; i < ${#TOOL_IDS[@]}; i++)); do
        [[ "${TOOL_IDS[$i]}" == "$tool_id" ]] && {
            echo "${TOOL_NAMES[$i]}"
            return
        }
    done
    echo "$tool_id"
}

is_tool_detected() {
    case "$1" in
        ghostty)    command_exists ghostty ;;
        nvm)        [ -d "$HOME/.nvm" ] ;;
        bun)        command_exists bun ;;
        deno)       command_exists deno ;;
        python)     command_exists pyenv ;;
        docker)     command_exists docker ;;
        kubernetes) command_exists kubectl ;;
        vscode)     command_exists code ;;
        android-sdk) android_studio_installed || [ -d "$HOME/Library/Android/sdk" ] || [ -d "$HOME/Android/Sdk" ] ;;
        *)          return 1 ;;
    esac
}

detect_installed_tools() {
    DETECTED_TOOLS=()
    local tool
    for tool in "${TOOL_IDS[@]}"; do
        if is_tool_detected "$tool"; then
            DETECTED_TOOLS+=("$tool")
        fi
    done

    return 0
}

tool_lineup() {
    local tools=("$@")
    local tool
    for tool in "${tools[@]}"; do
        printf "  - %s\n" "$(tool_name "$tool")"
    done
}

# ── Tool Registry ───────────────────────────────────────
TOOL_IDS=(    ghostty            nvm               bun                            deno                               python                          docker                                   kubernetes            vscode                 android-sdk)
TOOL_NAMES=(  "Ghostty"          "NVM"             "Bun"                          "Deno"                             "Python"                        "Docker"                                 "Kubernetes"          "VS Code"              "Android Studio")
TOOL_DESCS=(  "GPU-accelerated terminal emulator"  "Node Version Manager"  "JavaScript runtime & bundler"  "Secure JavaScript/TypeScript runtime"  "Python 3 via pyenv version manager"  "Docker Desktop for containers"              "kubectl + kubectx/kubens aliases"  "Visual Studio Code editor"  "Android Studio (SDK Manager + emulator)")

# ── Interactive Tool Menu ────────────────────────────────
show_menu() {
    local num=${#TOOL_IDS[@]}
    local selected=()
    local cursor=0
    local first_draw=true

    # Pre-select tools already present on the system
    DETECTED_TOOLS=()
    for ((i = 0; i < num; i++)); do
        selected+=(false)
        if is_tool_detected "${TOOL_IDS[$i]}"; then
            selected[$i]=true
            DETECTED_TOOLS+=("${TOOL_IDS[$i]}")
        fi
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
        if [[ "${selected[$i]}" == true ]]; then
            SELECTED_TOOLS+=("${TOOL_IDS[$i]}")
        fi
    done

    return 0
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
        restow_package "ghostty" "Ghostty config stowed"
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

install_python() {
    if command_exists pyenv; then
        ok "pyenv already installed"
    elif command_exists brew; then
        info "Installing pyenv via Homebrew..."
        brew install pyenv
        ok "pyenv installed"
    elif command_exists apt-get; then
        info "Installing pyenv build dependencies..."
        sudo apt-get update -qq && sudo apt-get install -y -qq \
            make build-essential libssl-dev zlib1g-dev libbz2-dev \
            libreadline-dev libsqlite3-dev wget curl llvm libncursesw5-dev \
            xz-utils tk-dev libxml2-dev libxmlsec1-dev libffi-dev liblzma-dev
        info "Installing pyenv via installer..."
        curl -fsSL https://pyenv.run | bash
        ok "pyenv installed"
    else
        warn "Install pyenv manually: https://github.com/pyenv/pyenv#installation"
    fi

    if command_exists pyenv && ! pyenv versions --bare | grep -q .; then
        info "Installing latest stable Python 3..."
        local latest
        latest=$(pyenv install --list | grep -E '^\s+3\.[0-9]+\.[0-9]+$' | tail -1 | tr -d ' ')
        pyenv install "$latest" && pyenv global "$latest"
        ok "Python $latest installed and set as global"
    fi
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

install_android_sdk() {
    if [[ "$(uname)" != "Darwin" ]]; then
        warn "Automatic Android Studio install is currently macOS-only in this installer."
        warn "Install Android Studio manually: https://developer.android.com/studio"
        warn "Then ensure ANDROID_HOME points to ~/Library/Android/sdk (macOS) or ~/Android/Sdk (Linux)."
        return
    fi

    if android_studio_installed; then
        ok "Android Studio already installed"
        warn "If platform-tools are missing, open Android Studio > SDK Manager and install 'Android SDK Platform-Tools'."
        return
    fi

    if command_exists brew; then
        info "Installing Android Studio via Homebrew..."
        if brew install --cask android-studio; then
            ok "Android Studio installed"
            warn "Use Android Studio > SDK Manager to install or update platform-tools as needed."
            return
        fi

        warn "Android Studio install via Homebrew failed."
        warn "Install Android Studio manually: https://developer.android.com/studio"
        warn "Then open SDK Manager to install platform-tools if needed."
    else
        warn "Install Android Studio manually: https://developer.android.com/studio"
        warn "Then ensure ANDROID_HOME points to ~/Library/Android/sdk (macOS) or ~/Android/Sdk (Linux)."
    fi
}

install_tool() {
    local tool="$1"
    case "$tool" in
        ghostty)    install_ghostty ;;
        nvm)        install_nvm ;;
        bun)        install_bun ;;
        deno)       install_deno ;;
        python)     install_python ;;
        docker)     install_docker ;;
        kubernetes) install_kubernetes ;;
        vscode)     install_vscode ;;
        android-sdk) install_android_sdk ;;
        *)          warn "No install handler for tool: $tool" ;;
    esac

    return 0
}

# ── Tool Uninstallers ───────────────────────────────────
uninstall_ghostty() {
    if command_exists brew; then
        if brew list --cask ghostty >/dev/null 2>&1; then
            info "Uninstalling Ghostty via Homebrew..."
            if [[ "$1" == true ]]; then
                brew uninstall --cask --zap ghostty || warn "Ghostty uninstall encountered an issue"
            else
                brew uninstall --cask ghostty || warn "Ghostty uninstall encountered an issue"
            fi
        fi
    elif command_exists pacman; then
        if pacman -Q ghostty >/dev/null 2>&1; then
            info "Uninstalling Ghostty via pacman..."
            if [[ "$1" == true ]]; then
                sudo pacman -Rns --noconfirm ghostty || warn "Ghostty uninstall encountered an issue"
            else
                sudo pacman -R --noconfirm ghostty || warn "Ghostty uninstall encountered an issue"
            fi
        fi
    elif command_exists dnf; then
        if rpm -q ghostty >/dev/null 2>&1; then
            info "Uninstalling Ghostty via DNF..."
            sudo dnf remove -y ghostty || warn "Ghostty uninstall encountered an issue"
        fi
    elif command_exists snap; then
        if snap list ghostty >/dev/null 2>&1; then
            info "Uninstalling Ghostty via Snap..."
            sudo snap remove ghostty || warn "Ghostty uninstall encountered an issue"
        fi
    fi

    if [ -d "$DOTFILES_DIR/ghostty" ]; then
        unstow_package "ghostty" "Ghostty config unstowed"
    fi
}

uninstall_nvm() {
    if command_exists brew && brew list --formula nvm >/dev/null 2>&1; then
        info "Uninstalling NVM via Homebrew..."
        brew uninstall nvm || warn "NVM uninstall encountered an issue"
    fi

    if [ -d "$HOME/.nvm" ]; then
        info "Removing ~/.nvm..."
        rm -rf "$HOME/.nvm"
        ok "Removed ~/.nvm"
    fi
}

uninstall_bun() {
    if command_exists brew && brew list --formula bun >/dev/null 2>&1; then
        info "Uninstalling Bun via Homebrew..."
        brew uninstall bun || warn "Bun uninstall encountered an issue"
    fi

    if [ -d "$HOME/.bun" ]; then
        info "Removing ~/.bun..."
        rm -rf "$HOME/.bun"
        ok "Removed ~/.bun"
    fi
}

uninstall_deno() {
    if command_exists brew && brew list --formula deno >/dev/null 2>&1; then
        info "Uninstalling Deno via Homebrew..."
        brew uninstall deno || warn "Deno uninstall encountered an issue"
    fi

    if [ -d "$HOME/.deno" ]; then
        info "Removing ~/.deno..."
        rm -rf "$HOME/.deno"
        ok "Removed ~/.deno"
    fi
}

uninstall_python() {
    if command_exists brew && brew list --formula pyenv >/dev/null 2>&1; then
        info "Uninstalling pyenv via Homebrew..."
        brew uninstall pyenv || warn "pyenv uninstall encountered an issue"
    elif command_exists apt-get; then
        if dpkg -s pyenv >/dev/null 2>&1; then
            info "Uninstalling pyenv via apt..."
            sudo apt-get remove -y pyenv || warn "pyenv uninstall encountered an issue"
        fi
    fi

    if [ -d "$HOME/.pyenv" ]; then
        info "Removing ~/.pyenv (installed Python versions included)..."
        rm -rf "$HOME/.pyenv"
        ok "Removed ~/.pyenv"
    fi
}

uninstall_docker() {
    if command_exists brew && brew list --cask docker >/dev/null 2>&1; then
        info "Uninstalling Docker Desktop via Homebrew..."
        if [[ "$1" == true ]]; then
            brew uninstall --cask --zap docker || warn "Docker uninstall encountered an issue"
        else
            brew uninstall --cask docker || warn "Docker uninstall encountered an issue"
        fi
    fi
}

uninstall_kubernetes() {
    if command_exists brew; then
        if brew list --formula kubectl >/dev/null 2>&1; then
            info "Uninstalling kubectl via Homebrew..."
            brew uninstall kubectl || warn "kubectl uninstall encountered an issue"
        fi
        if brew list --formula kubectx >/dev/null 2>&1; then
            info "Uninstalling kubectx/kubens via Homebrew..."
            brew uninstall kubectx || warn "kubectx uninstall encountered an issue"
        fi
    elif command_exists snap; then
        if snap list kubectl >/dev/null 2>&1; then
            info "Uninstalling kubectl via Snap..."
            sudo snap remove kubectl || warn "kubectl uninstall encountered an issue"
        fi
    fi
}

uninstall_vscode() {
    if command_exists brew && brew list --cask visual-studio-code >/dev/null 2>&1; then
        info "Uninstalling VS Code via Homebrew..."
        if [[ "$1" == true ]]; then
            brew uninstall --cask --zap visual-studio-code || warn "VS Code uninstall encountered an issue"
        else
            brew uninstall --cask visual-studio-code || warn "VS Code uninstall encountered an issue"
        fi
    fi
}

uninstall_android_sdk() {
    if command_exists brew; then
        if brew list --cask android-studio >/dev/null 2>&1; then
            info "Uninstalling Android Studio via Homebrew..."
            if [[ "$1" == true ]]; then
                brew uninstall --cask --zap android-studio || warn "Android Studio uninstall encountered an issue"
            else
                brew uninstall --cask android-studio || warn "Android Studio uninstall encountered an issue"
            fi
        fi

        # Legacy cleanup for earlier installer behavior.
        if brew list --formula android-sdk >/dev/null 2>&1; then
            info "Uninstalling legacy Android SDK formula via Homebrew..."
            brew uninstall android-sdk || warn "Android SDK uninstall encountered an issue"
        elif brew list --cask android-sdk >/dev/null 2>&1; then
            info "Uninstalling legacy Android SDK cask via Homebrew..."
            if [[ "$1" == true ]]; then
                brew uninstall --cask --zap android-sdk || warn "Android SDK uninstall encountered an issue"
            else
                brew uninstall --cask android-sdk || warn "Android SDK uninstall encountered an issue"
            fi
        fi

        if brew list --cask android-commandlinetools >/dev/null 2>&1; then
            info "Uninstalling legacy Android command-line tools cask via Homebrew..."
            if [[ "$1" == true ]]; then
                brew uninstall --cask --zap android-commandlinetools || warn "Android command-line tools uninstall encountered an issue"
            else
                brew uninstall --cask android-commandlinetools || warn "Android command-line tools uninstall encountered an issue"
            fi
        fi
    fi

    if [ -d "$HOME/Library/Android/sdk" ]; then
        info "Removing ~/Library/Android/sdk..."
        rm -rf "$HOME/Library/Android/sdk"
        ok "Removed ~/Library/Android/sdk"
    fi

    if [ -d "$HOME/Android/Sdk" ]; then
        info "Removing ~/Android/Sdk..."
        rm -rf "$HOME/Android/Sdk"
        ok "Removed ~/Android/Sdk"
    fi
}

uninstall_tool() {
    local tool="$1"
    local purge="$2"
    case "$tool" in
        ghostty)    uninstall_ghostty "$purge" ;;
        nvm)        uninstall_nvm "$purge" ;;
        bun)        uninstall_bun "$purge" ;;
        deno)       uninstall_deno "$purge" ;;
        python)     uninstall_python "$purge" ;;
        docker)     uninstall_docker "$purge" ;;
        kubernetes) uninstall_kubernetes "$purge" ;;
        vscode)     uninstall_vscode "$purge" ;;
        android-sdk) uninstall_android_sdk "$purge" ;;
        *)          warn "No uninstall handler for tool: $tool" ;;
    esac

    # Uninstall helpers may legitimately find nothing to remove; don't fail installer.
    return 0
}

handle_deselected_tools() {
    local selected=("$@")
    local deselected=()
    local tool

    for tool in "${DETECTED_TOOLS[@]}"; do
        if ! array_contains "$tool" "${selected[@]}"; then
            deselected+=("$tool")
        fi
    done

    if [ ${#deselected[@]} -eq 0 ]; then
        return
    fi

    echo ""
    warn "You deselected installed tools."
    tool_lineup "${deselected[@]}"

    local remove_answer purge_answer purge=false
    read -rp "Uninstall deselected tools and remove their managed config/data? [y/N]: " remove_answer < /dev/tty
    case "$remove_answer" in
        y|Y|yes|YES)
            read -rp "Also purge package-manager leftovers where supported (Homebrew zap, etc.)? [y/N]: " purge_answer < /dev/tty
            case "$purge_answer" in
                y|Y|yes|YES) purge=true ;;
            esac

            info "Removing deselected tools..."
            for tool in "${deselected[@]}"; do
                uninstall_tool "$tool" "$purge"
            done
            ok "Deselected tool removal complete"
            ;;
        *)
            info "Skipped deselected tool removal"
            ;;
    esac
}

# ── Stow Packages ───────────────────────────────────────
stow_packages() {
    info "Stowing dotfiles..."
    for pkg in "${PACKAGES[@]}"; do
        if [ -d "$DOTFILES_DIR/$pkg" ]; then
            restow_package "$pkg" "  $pkg"
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
    elif ! grep -qF "$SOURCE_TAG" "$rc_file" && ! grep -qF "$LEGACY_SOURCE_TAG" "$rc_file"; then
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
        eval_brew_shellenv
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
            detect_installed_tools
            SELECTED_TOOLS=("${TOOL_IDS[@]}")
        else
            show_menu
        fi

        handle_deselected_tools "${SELECTED_TOOLS[@]}"

        if [ ${#SELECTED_TOOLS[@]} -gt 0 ]; then
            echo ""
            info "Installing selected tools..."
            echo ""
            for tool in "${SELECTED_TOOLS[@]}"; do
                install_tool "$tool"
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
