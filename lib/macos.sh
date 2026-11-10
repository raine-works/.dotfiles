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

# cask|path that means it's already installed (e.g. installed by hand, outside Homebrew)
BREW_CASKS_DESKTOP=(
    "ghostty|/Applications/Ghostty.app"
    "zed|/Applications/Zed.app"
    "font-jetbrains-mono-nerd-font|$HOME/Library/Fonts/JetBrainsMonoNerdFont-Regular.ttf"
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
    local profile="$1" installed missing=() formula entry cask path

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
        IFS='|' read -r cask path <<<"$entry"
        case "$installed" in *" $cask "*) continue ;; esac
        if [ -e "$path" ]; then
            skip "$cask already installed"
            continue
        fi
        info "Installing $cask"
        brew install --quiet --cask "$cask" || note "Could not install $cask; install it yourself and re-run"
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

    # The first start creates the VM with these settings; later starts reuse them.
    if [ ! -f "$HOME/.colima/default/colima.yaml" ]; then
        info "Creating Colima VM"
        if ! colima start --vm-type vz --vz-rosetta --cpu 4 --memory 8 --disk 60; then
            note "Colima failed to start; run 'colima start' to see why"
            return 0
        fi
    fi

    # Run it as a Homebrew service so it starts at login. A VM started by hand
    # is stopped first so the service owns the only instance.
    if brew services info colima --json | jq -e '.[0].running' >/dev/null; then
        skip "Colima already starts at login"
    else
        info "Setting Colima to start at login"
        if colima status >/dev/null 2>&1; then colima stop >/dev/null 2>&1 || true; fi
        brew services start colima >/dev/null
        ok "Colima starts at login (brew services)"
    fi

    # While starting, Colima briefly switches docker to the default context, so
    # wait until docker answers on the current context, not just `colima status`.
    for _ in $(seq 1 60); do
        [ "$(docker context show 2>/dev/null)" = colima ] && docker info >/dev/null 2>&1 && break
        sleep 2
    done
    if docker info >/dev/null 2>&1; then
        ok "Docker is ready (context: colima)"
    else
        note "Docker isn't answering yet; see $(brew --prefix)/var/log/colima.log"
    fi

    if [ -d /Applications/Docker.app ]; then
        note "Docker Desktop is still installed. Once Colima works for you, remove it with: brew uninstall --cask docker-desktop (or drag Docker.app to the Trash)"
    fi
}
