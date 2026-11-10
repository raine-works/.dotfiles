# shellcheck shell=bash
# Linux (Debian/Ubuntu): apt packages, GitHub-release binaries, Docker Engine, desktop apps.

APT_PACKAGES=(
    zsh git curl wget unzip ca-certificates gnupg build-essential vim
    jq ripgrep fd-find bat tree tmux btop
    zsh-autosuggestions zsh-syntax-highlighting
)

# Installed from apt when the distro has them, otherwise from GitHub releases.
APT_OPTIONAL=(eza git-delta)

APT_DESKTOP=(fontconfig fonts-noto-cjk)

case "${ARCH:-}" in
    x86_64) ARCH_RE='(x86_64|amd64)' DEB_ARCH=amd64 ;;
    arm64) ARCH_RE='(arm64|aarch64)' DEB_ARCH=arm64 ;;
esac

apt_install() {
    as_root env DEBIAN_FRONTEND=noninteractive apt-get install -y -qq "$@" >/dev/null
}

apt_has_candidate() {
    # grep without -q: an early exit would SIGPIPE apt-cache and fail under pipefail.
    apt-cache policy "$1" 2>/dev/null | grep 'Candidate: [^(]' >/dev/null
}

# Download URL of the first release asset whose name matches a regex.
github_asset_url() {
    curl -fsSL "https://api.github.com/repos/$1/releases/latest" |
        jq -r --arg re "$2" '[.assets[].browser_download_url | select(test($re; "i"))][0] // empty'
}

# Install one binary from a GitHub release tarball unless it is already on PATH.
# Usage: github_bin <command> <owner/repo> <asset-regex>
github_bin() {
    local cmd="$1" repo="$2" re="$3" url
    if has "$cmd"; then
        skip "$cmd already installed"
        return 0
    fi
    url="$(github_asset_url "$repo" "$re")"
    [ -n "$url" ] || {
        note "No release asset for $cmd matched $re; skipped"
        return 0
    }
    info "Installing $cmd"
    install_tarball_bin "$url" "$cmd"
}

linux_install_packages() {
    local profile="$1" pkg

    has apt-get || die "Only Debian/Ubuntu (apt) Linux is supported"

    section "System packages (apt)"
    as_root apt-get update -qq
    apt_install "${APT_PACKAGES[@]}"
    for pkg in "${APT_OPTIONAL[@]}"; do
        if apt_has_candidate "$pkg"; then apt_install "$pkg"; fi
    done
    if [ "$profile" = desktop ]; then apt_install "${APT_DESKTOP[@]}"; fi
    ok "apt packages ready"

    mkdir -p "$LOCAL_BIN"
    # Debian ships these under different names.
    if has fdfind; then ln -sf "$(command -v fdfind)" "$LOCAL_BIN/fd"; fi
    if has batcat; then ln -sf "$(command -v batcat)" "$LOCAL_BIN/bat"; fi

    section "CLI tools (GitHub releases)"
    github_bin starship starship/starship "starship-${ARCH_RE}-unknown-linux-(gnu|musl)\\.tar\\.gz$"
    github_bin fzf junegunn/fzf "linux_${ARCH_RE}\\.tar\\.gz$"
    github_bin eza eza-community/eza "eza_${ARCH_RE}-unknown-linux-gnu\\.tar\\.gz$"
    github_bin delta dandavison/delta "${ARCH_RE}-unknown-linux-gnu\\.tar\\.gz$"
    github_bin lazygit jesseduffield/lazygit "linux_${ARCH_RE}\\.tar\\.gz$"
    github_bin lazydocker jesseduffield/lazydocker "linux_${ARCH_RE}\\.tar\\.gz$"
    github_bin k9s derailed/k9s "k9s_linux_${ARCH_RE}\\.tar\\.gz$"
    github_bin kubectx ahmetb/kubectx "kubectx_v.*_linux_${ARCH_RE}\\.tar\\.gz$"
    github_bin kubens ahmetb/kubectx "kubens_v.*_linux_${ARCH_RE}\\.tar\\.gz$"

    if has kubectl; then
        skip "kubectl already installed"
    else
        info "Installing kubectl"
        curl -fsSLo "$LOCAL_BIN/kubectl" \
            "https://dl.k8s.io/release/$(curl -fsSL https://dl.k8s.io/release/stable.txt)/bin/linux/$DEB_ARCH/kubectl"
        chmod 0755 "$LOCAL_BIN/kubectl"
    fi

    if has zoxide; then
        skip "zoxide already installed"
    else
        info "Installing zoxide"
        run_remote https://raw.githubusercontent.com/ajeetdsouza/zoxide/main/install.sh sh --bin-dir "$LOCAL_BIN" >/dev/null
    fi

    linux_install_gh
    ok "CLI tools ready"
}

linux_install_gh() {
    if has gh; then
        skip "gh already installed"
        return 0
    fi
    info "Installing gh (GitHub apt repo)"
    local keyring=/etc/apt/keyrings/githubcli-archive-keyring.gpg
    as_root install -d -m 0755 /etc/apt/keyrings
    curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | as_root tee "$keyring" >/dev/null
    as_root chmod go+r "$keyring"
    echo "deb [arch=$DEB_ARCH signed-by=$keyring] https://cli.github.com/packages stable main" |
        as_root tee /etc/apt/sources.list.d/github-cli.list >/dev/null
    as_root apt-get update -qq
    apt_install gh
}

linux_install_go() {
    if [ -x /usr/local/go/bin/go ] || has go; then
        skip "Go already installed"
        return 0
    fi
    local version
    version="$(curl -fsSL 'https://go.dev/VERSION?m=text' | head -1)"
    info "Installing $version to /usr/local/go"
    curl -fsSL "https://go.dev/dl/$version.linux-$DEB_ARCH.tar.gz" | as_root tar -xz -C /usr/local
}

linux_setup_docker() {
    section "Docker Engine"
    if has docker; then
        skip "docker already installed"
    else
        info "Installing Docker Engine (get.docker.com)"
        curl -fsSL https://get.docker.com | as_root sh >/dev/null
    fi

    if ! id -nG "$USER" | grep -w docker >/dev/null; then
        as_root usermod -aG docker "$USER"
        note "Added $USER to the docker group; log out and back in to use docker without sudo"
    fi

    if has_systemd; then
        as_root systemctl enable --now docker >/dev/null 2>&1 && ok "docker service enabled"
    else
        note "systemd not running; start dockerd yourself"
    fi
}

linux_install_desktop_apps() {
    section "Desktop apps"

    if has zed; then
        skip "Zed already installed"
    else
        info "Installing Zed"
        run_remote https://zed.dev/install.sh sh >/dev/null
    fi

    if has ghostty; then
        skip "Ghostty already installed"
    else
        # Ghostty has no official Linux packages; this is the .deb build its docs point to.
        info "Installing Ghostty (ghostty-ubuntu)"
        run_remote https://raw.githubusercontent.com/mkasberg/ghostty-ubuntu/HEAD/install.sh bash ||
            note "Ghostty install failed; see https://ghostty.org/docs/install/binary"
    fi

    local font_dir="$HOME/.local/share/fonts/JetBrainsMonoNerd"
    if [ -d "$font_dir" ]; then
        skip "JetBrainsMono Nerd Font already installed"
    else
        info "Installing JetBrainsMono Nerd Font"
        mkdir -p "$font_dir"
        curl -fsSL https://github.com/ryanoasis/nerd-fonts/releases/latest/download/JetBrainsMono.tar.xz |
            tar -xJ -C "$font_dir"
        fc-cache -f >/dev/null
    fi
    ok "Desktop apps ready"
}

linux_set_login_shell() {
    local zsh_path current
    zsh_path="$(command -v zsh)"
    current="$(getent passwd "$USER" | cut -d: -f7)"
    if [ "$current" = "$zsh_path" ]; then
        skip "zsh is already the login shell"
        return 0
    fi
    as_root chsh -s "$zsh_path" "$USER" && ok "Login shell set to zsh"
}
