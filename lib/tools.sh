# shellcheck shell=bash
# Cross-platform steps: language toolchains, CLI apps, config linking.

ZSHRC_MARKER="# dotfiles-managed"

install_toolchains() {
    section "Languages"

    # Node via nvm. PROFILE=/dev/null stops the installer from editing rc files.
    # nvm doesn't tolerate strict mode, so it runs in its own shell.
    export NVM_DIR="$HOME/.nvm"
    if [ ! -s "$NVM_DIR/nvm.sh" ]; then
        info "Installing nvm"
        PROFILE=/dev/null run_remote "https://raw.githubusercontent.com/nvm-sh/nvm/$(github_latest_tag nvm-sh/nvm)/install.sh" bash >/dev/null
    fi
    bash -c '. "$NVM_DIR/nvm.sh"
        if nvm ls default >/dev/null 2>&1; then exit 0; fi
        echo "  · Installing Node LTS"
        nvm install --lts >/dev/null && nvm alias default "lts/*" >/dev/null'
    ok "Node $(bash -c '. "$NVM_DIR/nvm.sh"; nvm version default')"

    # Bun. Its installer appends to ~/.zshrc unless SHELL is something it doesn't know.
    if [ -x "$HOME/.bun/bin/bun" ] || has bun; then
        skip "Bun already installed"
    else
        info "Installing Bun"
        SHELL=/bin/sh run_remote https://bun.sh/install bash >/dev/null
    fi
    ok "Bun"

    # Rust via rustup.
    if [ -x "$HOME/.cargo/bin/rustup" ]; then
        skip "Rust already installed"
    else
        info "Installing Rust (rustup)"
        run_remote https://sh.rustup.rs sh -y --no-modify-path >/dev/null
    fi
    ok "Rust"

    # Go: Homebrew on macOS, official tarball on Linux.
    if [ "$OS" = linux ]; then linux_install_go; fi
    ok "Go"

    # Python via uv: uv installs and manages Python itself; --default puts python/python3 on PATH.
    if ! has uv && [ ! -x "$LOCAL_BIN/uv" ]; then
        info "Installing uv"
        UV_NO_MODIFY_PATH=1 run_remote https://astral.sh/uv/install.sh sh >/dev/null
    fi
    PATH="$LOCAL_BIN:$PATH"
    if [ -x "$LOCAL_BIN/python3" ]; then
        skip "Python already installed (uv)"
    else
        info "Installing Python (uv)"
        uv python install --default >/dev/null 2>&1 || uv python install --preview --default >/dev/null
    fi
    ok "Python $("$LOCAL_BIN/python3" --version 2>/dev/null | cut -d' ' -f2)"
}

install_cli_apps() {
    local profile="$1"
    section "CLI apps"

    if has claude; then
        skip "Claude Code already installed"
    else
        info "Installing Claude Code"
        run_remote https://claude.ai/install.sh bash >/dev/null
    fi
    ok "Claude Code"

    if has herdr; then
        skip "herdr already installed"
    else
        info "Installing herdr"
        run_remote https://herdr.dev/install.sh sh >/dev/null
    fi
    ok "herdr"

    # NetBird's installer uses brew/apt as appropriate; the server profile skips its GUI.
    if has netbird; then
        skip "NetBird already installed"
    else
        info "Installing NetBird ($([ "$profile" = desktop ] && echo GUI || echo CLI))"
        if [ "$profile" = server ]; then
            SKIP_UI_APP=true run_remote https://pkgs.netbird.io/install.sh sh >/dev/null ||
                note "NetBird install failed; see https://docs.netbird.io/get-started/install"
        else
            run_remote https://pkgs.netbird.io/install.sh sh >/dev/null ||
                note "NetBird install failed; see https://docs.netbird.io/get-started/install"
        fi
    fi
    ok "NetBird"
}

# Pre-generate zsh completions so shell startup doesn't have to.
generate_completions() {
    mkdir -p "$ZSH_COMPLETIONS_DIR"
    local d="$ZSH_COMPLETIONS_DIR"
    # Failures here only cost tab completion, so they don't stop the install.
    if has gh; then gh completion -s zsh >"$d/_gh" || true; fi
    if has kubectl; then kubectl completion zsh >"$d/_kubectl" || true; fi
    if has docker; then docker completion zsh >"$d/_docker" 2>/dev/null || true; fi
    if has uv; then uv generate-shell-completion zsh >"$d/_uv" || true; fi
    if [ -x "$HOME/.cargo/bin/rustup" ]; then
        "$HOME/.cargo/bin/rustup" completions zsh >"$d/_rustup" || true
        "$HOME/.cargo/bin/rustup" completions zsh cargo >"$d/_cargo" || true
    fi
    ok "zsh completions generated"
}

# Earlier versions symlinked files into the repo. Remove those links (and only those)
# so the user-owned entry files below can take their place.
remove_legacy_links() {
    local repo_name path
    repo_name="$(basename "$DOTFILES_DIR")"
    for path in "$HOME/.config/shell" "$HOME/.config/starship" "$HOME/.config/starship.toml" \
        "$HOME/.config/zsh" "$HOME/.config/git" "$HOME/.gitconfig" "$HOME/.config/ghostty/config" \
        "$HOME/.config/zed/dotfiles.settings.json" \
        "$HOME/Library/Application Support/Code/User/dotfiles.settings.json"; do
        if [ -L "$path" ]; then
            case "$(readlink "$path")" in *"$repo_name"/*) rm "$path" ;; esac
        elif [ -d "$path" ]; then
            find "$path" -type l -lname "*$repo_name/*" -exec rm {} +
            find "$path" -name .DS_Store -exec rm {} +
            find "$path" -depth -type d -empty -exec rmdir {} +
        fi
    done
}

# Every config is wired up through a file the user owns, which points at the repo.
# Personal changes go in those files, so the clone never picks up local edits.
link_configs() {
    local profile="$1"
    section "Config files"
    remove_legacy_links
    hook_zshrc
    hook_gitconfig
    if [ "$profile" = desktop ]; then
        hook_ghostty
        merge_zed_settings
    fi
}

# ~/.zshrc: the first line sources the managed config; the rest is the user's.
hook_zshrc() {
    local rc="$HOME/.zshrc" line
    line="source \"$DOTFILES_DIR/zsh/zshrc\" $ZSHRC_MARKER"
    touch "$rc"
    # Drop any earlier managed line (including older layouts') and put the current one first.
    {
        echo "$line"
        grep -v '# dotfiles-managed' "$rc" || true
    } >"$rc.tmp" && mv "$rc.tmp" "$rc"
    ok ".zshrc sources the managed zsh config"
}

# ~/.gitconfig: includes the managed config at the top, so anything below it
# (including `git config --global` writes) overrides it.
hook_gitconfig() {
    local rc="$HOME/.gitconfig" base="$DOTFILES_DIR/git/config"
    touch "$rc"
    if ! git config --file "$rc" --get-all include.path | grep -xF "$base" >/dev/null; then
        {
            printf '# Managed defaults (dotfiles). Settings below this include override them.\n'
            printf '[include]\n\tpath = %s\n\n' "$base"
            cat "$rc"
        } >"$rc.tmp" && mv "$rc.tmp" "$rc"
    fi
    # Identity from older installs lived in ~/.gitconfig.local.
    # shellcheck disable=SC2088 # the literal ~ is what git stores
    if [ -f "$HOME/.gitconfig.local" ] &&
        ! git config --file "$rc" --get-all include.path | grep -xF '~/.gitconfig.local' >/dev/null; then
        git config --file "$rc" --add include.path '~/.gitconfig.local'
    fi

    # The global ignore list is copied once, then belongs to the user.
    local ignore="$HOME/.config/git/ignore"
    if [ ! -f "$ignore" ]; then
        mkdir -p "$(dirname "$ignore")"
        cp "$DOTFILES_DIR/git/ignore" "$ignore"
    fi
    ok ".gitconfig includes the managed git config"
}

# Ghostty loads config-file includes after the main file, in order, so the main
# file only holds includes: the managed base, then the user's config.local.
hook_ghostty() {
    local dir="$HOME/.config/ghostty" base="$DOTFILES_DIR/ghostty/config"
    local main="$dir/config" local_cfg="$dir/config.local"
    mkdir -p "$dir"
    if [ -f "$main" ] && ! grep -F "config-file = $base" "$main" >/dev/null; then
        # Keep the user's existing settings as their overrides.
        cat "$main" >>"$local_cfg"
        rm "$main"
    fi
    if [ ! -f "$main" ]; then
        printf '%s\n' \
            '# Managed by dotfiles. Put your own settings in config.local, not here:' \
            '# Ghostty loads these includes after this file, so they would override it.' \
            "config-file = $base" \
            'config-file = ?config.local' >"$main"
    fi
    touch "$local_cfg"
    ok "Ghostty loads the managed config, then config.local"
}

# Zed rewrites settings.json itself, so the managed settings are merged into it:
# the user's values win, except AI stays off.
merge_zed_settings() {
    python3 "$DOTFILES_DIR/lib/merge_jsonc.py" "$DOTFILES_DIR/zed/settings.json" \
        "$HOME/.config/zed/settings.json" disable_ai || die "Could not merge Zed settings"
    ok "Zed settings merged (AI disabled)"
}
