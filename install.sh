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

BACKUP_DIR="$HOME/.dotfiles-backups"
BACKUP_ARCHIVE=""

backup_stow_conflicts() {
    local pkg="$1"
    local conflicts=()
    local line target

    while IFS= read -r line; do
        if [[ "$line" =~ \*\ stowing\ .*\ would\ cause\ conflicts: ]] || \
           [[ "$line" =~ \*\ existing\ target\ is ]] || \
           [[ "$line" =~ \*\ cannot\ stow ]]; then
            continue
        fi
        target=$(echo "$line" | grep -oE '~?/[^ ]+' | head -1 || true)
        if [ -n "$target" ]; then
            target="${target/\~/$HOME}"
            [ -e "$target" ] || [ -L "$target" ] && conflicts+=("$target")
        fi
    done < <(stow -n --simulate -d "$DOTFILES_DIR" -t "$HOME" --restow "$pkg" 2>&1 || true)

    if [ ${#conflicts[@]} -eq 0 ]; then
        return 0
    fi

    mkdir -p "$BACKUP_DIR"
    local timestamp
    timestamp="$(date -u +%Y-%m-%dT%H%M%SZ)"
    BACKUP_ARCHIVE="$BACKUP_DIR/dotfiles-backup-${pkg}-${timestamp}.tar.gz"

    info "Backing up ${#conflicts[@]} conflicting file(s) to $BACKUP_ARCHIVE ..."
    tar -czf "$BACKUP_ARCHIVE" --ignore-failed-read "${conflicts[@]}" 2>/dev/null || true
    ok "Backup created: $BACKUP_ARCHIVE"

    # Trim backups to the last 5 per package prefix
    local count
    count=$(find "$BACKUP_DIR" -maxdepth 1 -name "dotfiles-backup-${pkg}-*.tar.gz" | wc -l | tr -d ' ')
    if (( count > 5 )); then
        find "$BACKUP_DIR" -maxdepth 1 -name "dotfiles-backup-${pkg}-*.tar.gz" \
            | sort | head -n $(( count - 5 )) | xargs rm -f
    fi

    return 0
}

restore_stow_backup() {
    if [ -z "$BACKUP_ARCHIVE" ] || [ ! -f "$BACKUP_ARCHIVE" ]; then
        return 0
    fi

    local answer
    printf "\n"
    warn "Stow operation failed. A backup was saved to: $BACKUP_ARCHIVE"
    read -rp "Restore the backup now? [Y/n]: " answer < /dev/tty
    case "$answer" in
        n|N|no|NO) info "Backup retained at $BACKUP_ARCHIVE — restore manually with: tar -xzf $BACKUP_ARCHIVE -C /" ;;
        *) tar -xzf "$BACKUP_ARCHIVE" -C / 2>/dev/null || tar -xzf "$BACKUP_ARCHIVE" -C "$HOME" 2>/dev/null || true
           ok "Backup restored" ;;
    esac
}

check_stow_preflight() {
    local pkg="$1"
    local output

    backup_stow_conflicts "$pkg"

    if ! output=$(stow -n --simulate -d "$DOTFILES_DIR" -t "$HOME" --restow "$pkg" 2>&1); then
        warn "Stow preflight failed for package: $pkg"
        printf "%s\n" "$output" >&2
        restore_stow_backup
        fail "Resolve the stow conflicts above and re-run installer."
    fi
}

restow_package() {
    local pkg="$1"
    local label="$2"

    check_stow_preflight "$pkg"
    if stow -d "$DOTFILES_DIR" -t "$HOME" --restow "$pkg"; then
        BACKUP_ARCHIVE=""
        ok "$label"
    else
        restore_stow_backup
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
# Format: "id|Display Name|Description"
# Adding a tool: add one entry here + create install_<id>() and uninstall_<id>() functions.
TOOL_REGISTRY=(
    "ghostty|Ghostty|GPU-accelerated terminal emulator"
    "nvm|NVM|Node Version Manager"
    "bun|Bun|JavaScript runtime & bundler"
    "deno|Deno|Secure JavaScript/TypeScript runtime"
    "python|Python|Python 3 via pyenv version manager"
    "docker|Docker|Docker Desktop for containers"
    "kubernetes|Kubernetes|kubectl + kubectx/kubens aliases"
    "vscode|VS Code|Visual Studio Code editor"
)

TOOL_IDS=() TOOL_NAMES=() TOOL_DESCS=()
for _entry in "${TOOL_REGISTRY[@]}"; do
    IFS='|' read -r _id _name _desc <<< "$_entry"
    TOOL_IDS+=("$_id")
    TOOL_NAMES+=("$_name")
    TOOL_DESCS+=("$_desc")
done
unset _entry _id _name _desc

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
# detect_package_manager: echo the first available manager (brew|apt|dnf|pacman)
detect_package_manager() {
    if command_exists brew;    then echo "brew";   return; fi
    if command_exists apt-get; then echo "apt";    return; fi
    if command_exists dnf;     then echo "dnf";    return; fi
    if command_exists pacman;  then echo "pacman"; return; fi
    echo ""
}

# install_package BREW_PKG APT_PKG DNF_PKG PACMAN_PKG [--cask]
# Installs a package from whichever manager is available.
# Pass empty string "" for a manager that has no package.
install_package() {
    local brew_pkg="$1" apt_pkg="$2" dnf_pkg="$3" pacman_pkg="$4"
    local is_cask=false
    [[ "${5:-}" == "--cask" ]] && is_cask=true
    local pm
    pm="$(detect_package_manager)"
    case "$pm" in
        brew)
            if $is_cask; then
                brew install --cask "$brew_pkg"
            else
                brew install "$brew_pkg"
            fi ;;
        apt)
            [ -z "$apt_pkg" ] && return 1
            sudo apt-get update -qq && sudo apt-get install -y -qq "$apt_pkg" ;;
        dnf)
            [ -z "$dnf_pkg" ] && return 1
            sudo dnf install -y "$dnf_pkg" ;;
        pacman)
            [ -z "$pacman_pkg" ] && return 1
            sudo pacman -S --noconfirm "$pacman_pkg" ;;
        *)
            return 1 ;;
    esac
}

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
    if command_exists brew; then
        info "Installing Bun via Homebrew..."
        brew install oven-sh/bun/bun
    elif command_exists apt-get || command_exists dnf || command_exists pacman; then
        info "Installing Bun via install script..."
        bash <(curl -fsSL https://bun.sh/install)
    else
        info "Installing Bun via install script..."
        bash <(curl -fsSL https://bun.sh/install)
    fi
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
    elif command_exists pacman; then
        info "Installing Deno via pacman..."
        sudo pacman -S --noconfirm deno
    elif command_exists dnf; then
        info "Installing Deno via install script..."
        bash <(curl -fsSL https://deno.land/install.sh)
    elif command_exists apt-get; then
        info "Installing Deno via install script..."
        bash <(curl -fsSL https://deno.land/install.sh)
    else
        warn "Install Deno manually: https://deno.land/#installation"
        return
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
    elif command_exists apt-get; then
        info "Installing Docker Engine via apt..."
        sudo apt-get update -qq
        sudo apt-get install -y -qq ca-certificates curl gnupg lsb-release
        sudo install -m 0755 -d /etc/apt/keyrings
        curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
        sudo chmod a+r /etc/apt/keyrings/docker.gpg
        echo "deb [arch=\"$(dpkg --print-architecture)\" signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \"$(lsb_release -cs)\" stable" | sudo tee /etc/apt/sources.list.d/docker.list >/dev/null
        sudo apt-get update -qq
        sudo apt-get install -y -qq docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
        ok "Docker Engine installed"
    elif command_exists dnf; then
        info "Installing Docker Engine via DNF..."
        sudo dnf -y install dnf-plugins-core
        sudo dnf config-manager --add-repo https://download.docker.com/linux/fedora/docker-ce.repo
        sudo dnf install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
        sudo systemctl enable --now docker
        ok "Docker Engine installed"
    elif command_exists pacman; then
        info "Installing Docker via pacman..."
        sudo pacman -S --noconfirm docker docker-compose
        sudo systemctl enable --now docker
        ok "Docker installed"
    else
        warn "Install Docker manually: https://www.docker.com/products/docker-desktop/"
    fi
}

install_kubernetes() {
    if ! command_exists kubectl; then
        if command_exists brew; then
            info "Installing kubectl via Homebrew..."
            brew install kubectl
            ok "kubectl installed"
        elif command_exists apt-get; then
            info "Installing kubectl via apt..."
            sudo apt-get update -qq && sudo apt-get install -y -qq apt-transport-https gnupg
            curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.29/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
            echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.29/deb/ /' | sudo tee /etc/apt/sources.list.d/kubernetes.list >/dev/null
            sudo apt-get update -qq && sudo apt-get install -y -qq kubectl
            ok "kubectl installed"
        elif command_exists dnf; then
            info "Installing kubectl via DNF..."
            cat <<'EOF' | sudo tee /etc/yum.repos.d/kubernetes.repo >/dev/null
[kubernetes]
name=Kubernetes
baseurl=https://pkgs.k8s.io/core:/stable:/v1.29/rpm/
enabled=1
gpgcheck=1
gpgkey=https://pkgs.k8s.io/core:/stable:/v1.29/rpm/repodata/repomd.xml.key
EOF
            sudo dnf install -y kubectl
            ok "kubectl installed"
        elif command_exists pacman; then
            info "Installing kubectl via pacman..."
            sudo pacman -S --noconfirm kubectl
            ok "kubectl installed"
        else
            warn "Install kubectl manually: https://kubernetes.io/docs/tasks/tools/"
        fi
    else
        ok "kubectl already installed"
    fi

    if ! command_exists kubectx; then
        if command_exists brew; then
            info "Installing kubectx & kubens via Homebrew..."
            brew install kubectx
            ok "kubectx installed"
        elif command_exists apt-get; then
            info "Installing kubectx via apt..."
            sudo apt-get install -y -qq kubectx 2>/dev/null || {
                warn "kubectx not in apt — install manually: https://github.com/ahmetb/kubectx"
            }
        elif command_exists pacman; then
            info "Installing kubectx via pacman..."
            sudo pacman -S --noconfirm kubectx 2>/dev/null || {
                warn "kubectx not in pacman — install manually: https://github.com/ahmetb/kubectx"
            }
        fi
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
    elif command_exists apt-get; then
        info "Installing VS Code via apt..."
        sudo apt-get install -y -qq wget gpg
        wget -qO- https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor > /tmp/packages.microsoft.gpg
        sudo install -o root -g root -m 644 /tmp/packages.microsoft.gpg /etc/apt/keyrings/packages.microsoft.gpg
        rm -f /tmp/packages.microsoft.gpg
        echo "deb [arch=amd64,arm64,armhf signed-by=/etc/apt/keyrings/packages.microsoft.gpg] https://packages.microsoft.com/repos/code stable main" | sudo tee /etc/apt/sources.list.d/vscode.list >/dev/null
        sudo apt-get update -qq && sudo apt-get install -y -qq code
        ok "VS Code installed"
    elif command_exists dnf; then
        info "Installing VS Code via DNF..."
        sudo rpm --import https://packages.microsoft.com/keys/microsoft.asc
        sudo sh -c 'echo -e "[code]\nname=Visual Studio Code\nbaseurl=https://packages.microsoft.com/yumrepos/vscode\nenabled=1\ngpgcheck=1\ngpgkey=https://packages.microsoft.com/keys/microsoft.asc" > /etc/yum.repos.d/vscode.repo'
        sudo dnf install -y code
        ok "VS Code installed"
    elif command_exists pacman; then
        info "Installing VS Code (OSS) via pacman..."
        sudo pacman -S --noconfirm code 2>/dev/null || {
            warn "code not in pacman — try AUR (yay -S visual-studio-code-bin) or download from https://code.visualstudio.com/"
        }
    else
        warn "Install VS Code manually: https://code.visualstudio.com/"
    fi
}

verify_tool_installed() {
    local tool="$1"
    local cmd
    case "$tool" in
        ghostty)     cmd="ghostty" ;;
        nvm)         [ -d "$HOME/.nvm" ] && return 0; return 1 ;;
        bun)         cmd="bun" ;;
        deno)        cmd="deno" ;;
        python)      cmd="pyenv" ;;
        docker)      cmd="docker" ;;
        kubernetes)  cmd="kubectl" ;;
        vscode)      cmd="code" ;;
        *)           return 0 ;;
    esac
    command_exists "$cmd" && return 0
    warn "$tool installed but '${cmd}' not found in PATH — you may need to restart your shell."
    return 0
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
        *)          warn "No install handler for tool: $tool" ;;
    esac

    verify_tool_installed "$tool"
    return 0
}

# ── Tool Uninstallers ───────────────────────────────────
# uninstall_via_brew FORMULA_OR_CASK type [purge]
#   type: formula | cask
#   purge: true → add --zap for casks
uninstall_via_brew() {
    local pkg="$1" type="$2" purge="${3:-false}"
    command_exists brew || return 0

    local list_flag=""
    local uninstall_flags=()
    if [[ "$type" == "cask" ]]; then
        list_flag="--cask"
        uninstall_flags=(--cask)
        [[ "$purge" == true ]] && uninstall_flags+=(--zap)
    else
        list_flag="--formula"
    fi

    if brew list $list_flag "$pkg" >/dev/null 2>&1; then
        info "Uninstalling $pkg via Homebrew..."
        brew uninstall "${uninstall_flags[@]}" "$pkg" || warn "$pkg uninstall encountered an issue"
    fi
}

uninstall_ghostty() {
    local purge="${1:-false}"
    uninstall_via_brew ghostty cask "$purge"
    if command_exists pacman && pacman -Q ghostty >/dev/null 2>&1; then
        info "Uninstalling Ghostty via pacman..."
        if [[ "$purge" == true ]]; then
            sudo pacman -Rns --noconfirm ghostty || warn "Ghostty uninstall encountered an issue"
        else
            sudo pacman -R --noconfirm ghostty || warn "Ghostty uninstall encountered an issue"
        fi
    elif command_exists dnf && rpm -q ghostty >/dev/null 2>&1; then
        info "Uninstalling Ghostty via DNF..."
        sudo dnf remove -y ghostty || warn "Ghostty uninstall encountered an issue"
    elif command_exists snap && snap list ghostty >/dev/null 2>&1; then
        info "Uninstalling Ghostty via Snap..."
        sudo snap remove ghostty || warn "Ghostty uninstall encountered an issue"
    fi
    if [ -d "$DOTFILES_DIR/ghostty" ]; then
        unstow_package "ghostty" "Ghostty config unstowed"
    fi
}

uninstall_nvm() {
    uninstall_via_brew nvm formula
    if [ -d "$HOME/.nvm" ]; then
        info "Removing ~/.nvm..."
        rm -rf "$HOME/.nvm"
        ok "Removed ~/.nvm"
    fi
}

uninstall_bun() {
    uninstall_via_brew bun formula
    if [ -d "$HOME/.bun" ]; then
        info "Removing ~/.bun..."
        rm -rf "$HOME/.bun"
        ok "Removed ~/.bun"
    fi
}

uninstall_deno() {
    uninstall_via_brew deno formula
    if [ -d "$HOME/.deno" ]; then
        info "Removing ~/.deno..."
        rm -rf "$HOME/.deno"
        ok "Removed ~/.deno"
    fi
}

uninstall_python() {
    uninstall_via_brew pyenv formula
    if command_exists apt-get && dpkg -s pyenv >/dev/null 2>&1; then
        info "Uninstalling pyenv via apt..."
        sudo apt-get remove -y pyenv || warn "pyenv uninstall encountered an issue"
    fi
    if [ -d "$HOME/.pyenv" ]; then
        info "Removing ~/.pyenv (installed Python versions included)..."
        rm -rf "$HOME/.pyenv"
        ok "Removed ~/.pyenv"
    fi
}

uninstall_docker() {
    uninstall_via_brew docker cask "${1:-false}"
}

uninstall_kubernetes() {
    uninstall_via_brew kubectl formula
    uninstall_via_brew kubectx formula
    if command_exists snap && snap list kubectl >/dev/null 2>&1; then
        info "Uninstalling kubectl via Snap..."
        sudo snap remove kubectl || warn "kubectl uninstall encountered an issue"
    fi
}

uninstall_vscode() {
    uninstall_via_brew visual-studio-code cask "${1:-false}"
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
