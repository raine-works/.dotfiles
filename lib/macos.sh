# shellcheck shell=bash
# macOS: Homebrew packages and Colima-based Docker.

BREW_FORMULAE=(
    # core
    git curl wget jq starship zsh-autosuggestions zsh-syntax-highlighting
    # dev utilities
    fzf ripgrep fd bat eza zoxide btop tmux tree lazygit git-delta
    # languages (node, bun, rust come from their own installers)
    go uv
    # cli tools
    gh herdr
    # containers
    colima docker docker-compose docker-buildx lazydocker kubernetes-cli k9s kubectx
)

# cask|App bundle name (an app already in /Applications is left alone)
BREW_CASKS_DESKTOP=(
    "ghostty|Ghostty.app"
    "zed|Zed.app"
    "font-jetbrains-mono-nerd-font|"
)

ensure_brew_on_path() {
    local brew_bin
    for brew_bin in /opt/homebrew/bin/brew /usr/local/bin/brew; do
        if [ -x "$brew_bin" ]; then
            eval "$("$brew_bin" shellenv)"
            return 0
        fi
    done
    return 1
}

install_homebrew() {
    if ensure_brew_on_path; then
        skip "Homebrew already installed"
        return 0
    fi
    info "Installing Homebrew"
    NONINTERACTIVE=1 run_remote https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh bash
    ensure_brew_on_path || die "Homebrew installed but brew is not on PATH"
}

macos_install_packages() {
    local profile="$1" installed missing=() formula entry cask app

    section "Homebrew packages"
    install_homebrew

    installed=" $(brew list --formula -1 | tr '\n' ' ') "
    for formula in "${BREW_FORMULAE[@]}"; do
        case "$installed" in
            *" $formula "*) ;;
            *) missing+=("$formula") ;;
        esac
    done

    if [ ${#missing[@]} -gt 0 ]; then
        info "Installing: ${missing[*]}"
        brew install --quiet "${missing[@]}"
    fi
    ok "Formulae ready (${#BREW_FORMULAE[@]})"

    [ "$profile" = desktop ] || return 0

    installed=" $(brew list --cask -1 | tr '\n' ' ') "
    for entry in "${BREW_CASKS_DESKTOP[@]}"; do
        IFS='|' read -r cask app <<<"$entry"
        case "$installed" in *" $cask "*) continue ;; esac
        if [ -n "$app" ] && [ -d "/Applications/$app" ]; then
            skip "$app already in /Applications"
            continue
        fi
        info "Installing $cask"
        brew install --quiet --cask "$cask"
    done
    ok "Desktop apps ready"
}

macos_setup_docker() {
    section "Docker (Colima)"

    # Let the docker CLI find Homebrew's compose and buildx plugins.
    local config="$HOME/.docker/config.json" plugins tmp
    plugins="$(brew --prefix)/lib/docker/cli-plugins"
    mkdir -p "$HOME/.docker"
    [ -s "$config" ] || echo '{}' >"$config"
    tmp="$(mktemp)"
    jq --arg dir "$plugins" '.cliPluginsExtraDirs = ((.cliPluginsExtraDirs // []) - [$dir] + [$dir])' "$config" >"$tmp" && mv "$tmp" "$config"
    ok "Compose and buildx plugins registered"

    if colima status >/dev/null 2>&1; then
        skip "Colima VM already running"
    else
        info "Starting Colima VM"
        colima start --vm-type vz --vz-rosetta --cpu 4 --memory 8 --disk 60
    fi
    docker context use colima >/dev/null
    ok "Docker context set to colima"

    if [ -d /Applications/Docker.app ]; then
        note "Docker Desktop is still installed. Once Colima works for you, remove it with: brew uninstall --cask docker-desktop (or drag Docker.app to the Trash)"
    fi
}
