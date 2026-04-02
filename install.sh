#!/usr/bin/env bash
set -Ee

DOTFILES_DIR="$(cd "$(dirname "$0")" && pwd)"
PACKAGES=(shell starship gitconfig)
SOURCE_TAG="# dotfiles-managed:raine-works"
LEGACY_SOURCE_TAG="# dotfiles-managed"
DETECTED_TOOLS=()

# ── Helpers ──────────────────────────────────────────────
info() { printf "\033[1;34m[info]\033[0m  %s\n" "$1"; }
ok() { printf "\033[1;32m[ok]\033[0m    %s\n" "$1"; }
warn() { printf "\033[1;33m[warn]\033[0m  %s\n" "$1"; }
fail() {
    printf "\033[1;31m[error]\033[0m %s\n" "$1" >&2
    exit 1
}
command_exists() { command -v "$1" >/dev/null 2>&1; }

vscode_cli_path() {
    local code_bin
    code_bin="$(command -v code 2>/dev/null || true)"
    if [ -n "$code_bin" ]; then
        echo "$code_bin"
        return 0
    fi

    local macos_code_bin="/Applications/Visual Studio Code.app/Contents/Resources/app/bin/code"
    if [ -x "$macos_code_bin" ]; then
        echo "$macos_code_bin"
        return 0
    fi

    return 1
}

vscode_user_settings_dir() {
    echo "$HOME/Library/Application Support/Code/User"
}

vscode_merge_settings() {
    local settings_dir settings_file base_file
    settings_dir="$(vscode_user_settings_dir)"
    settings_file="$settings_dir/settings.json"
    base_file="$settings_dir/dotfiles.settings.json"

    mkdir -p "$settings_dir"

    # Migrate older setups where settings.json was symlinked into the dotfiles repo.
    if [ -L "$settings_file" ]; then
        rm -f "$settings_file"
    fi

    if [ ! -f "$base_file" ]; then
        warn "VS Code base settings not found at $base_file; skipping settings merge"
        return 0
    fi

    if command_exists python3; then
        local merge_error
        if merge_error="$(python3 - "$base_file" "$settings_file" 2>&1 <<'PY'
import json
import os
import sys

base_path, settings_path = sys.argv[1], sys.argv[2]


def strip_jsonc(text):
    out = []
    i = 0
    in_string = False
    escape = False
    n = len(text)

    while i < n:
        ch = text[i]

        if in_string:
            out.append(ch)
            if escape:
                escape = False
            elif ch == '\\':
                escape = True
            elif ch == '"':
                in_string = False
            i += 1
            continue

        if ch == '"':
            in_string = True
            out.append(ch)
            i += 1
            continue

        if ch == '/' and i + 1 < n and text[i + 1] == '/':
            i += 2
            while i < n and text[i] not in '\r\n':
                i += 1
            continue

        if ch == '/' and i + 1 < n and text[i + 1] == '*':
            i += 2
            while i + 1 < n and not (text[i] == '*' and text[i + 1] == '/'):
                i += 1
            i = min(i + 2, n)
            continue

        out.append(ch)
        i += 1

    return ''.join(out)


def remove_trailing_commas(text):
    out = []
    i = 0
    in_string = False
    escape = False
    n = len(text)

    while i < n:
        ch = text[i]

        if in_string:
            out.append(ch)
            if escape:
                escape = False
            elif ch == '\\':
                escape = True
            elif ch == '"':
                in_string = False
            i += 1
            continue

        if ch == '"':
            in_string = True
            out.append(ch)
            i += 1
            continue

        if ch == ',':
            j = i + 1
            while j < n and text[j] in ' \t\r\n':
                j += 1
            if j < n and text[j] in '}]':
                i += 1
                continue

        out.append(ch)
        i += 1

    return ''.join(out)


def load_json(path, required=False):
    if not os.path.exists(path):
        if required:
            raise FileNotFoundError(path)
        return {}
    with open(path, 'r', encoding='utf-8') as f:
        raw = f.read()

    if not raw.strip():
        return {}

    cleaned = remove_trailing_commas(strip_jsonc(raw))
    return json.loads(cleaned)


def deep_merge(base, override):
    if not isinstance(base, dict) or not isinstance(override, dict):
        return override

    merged = dict(base)
    for key, value in override.items():
        if key in merged and isinstance(merged[key], dict) and isinstance(value, dict):
            merged[key] = deep_merge(merged[key], value)
        else:
            merged[key] = value
    return merged


base = load_json(base_path, required=True)
current = load_json(settings_path, required=False)

if not isinstance(base, dict):
    raise ValueError('Base VS Code settings must be a JSON object')
if not isinstance(current, dict):
    raise ValueError('Existing VS Code settings must be a JSON object')

merged = deep_merge(base, current)

with open(settings_path, 'w', encoding='utf-8') as f:
    json.dump(merged, f, indent=2)
    f.write('\n')
PY
        )"; then
            ok "VS Code settings merged (dotfiles base + local overrides)"
        else
            warn "Failed to merge VS Code settings; leaving existing settings untouched"
            [ -n "$merge_error" ] && warn "VS Code merge error: $merge_error"
        fi
    elif [ ! -f "$settings_file" ]; then
        cp "$base_file" "$settings_file"
        ok "Created VS Code settings.json from dotfiles base"
    else
        warn "python3 not found; skipped VS Code settings merge"
    fi
}

rust_toolchain_detected() {
    command_exists rustc && return 0
    command_exists cargo && return 0
    command_exists rustup && return 0
    [ -x "$HOME/.cargo/bin/rustc" ] && return 0
    [ -x "$HOME/.cargo/bin/cargo" ] && return 0
    [ -x "$HOME/.cargo/bin/rustup" ] && return 0
    [ -d "$HOME/.rustup" ] && return 0
    [ -d "$HOME/.cargo/bin" ] && return 0
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

BACKUP_DIR="$HOME/.dotfiles-backups"
BACKUP_ARCHIVE=""

has_tty() {
    [ -r /dev/tty ] && [ -w /dev/tty ]
}

is_non_interactive() {
    [ "${DOTFILES_NONINTERACTIVE:-0}" = "1" ] || [ "${CI:-}" = "true" ]
}

prompt_read() {
    local out_var="$1"
    local prompt="$2"
    local default_value="${3:-}"
    local answer

    if is_non_interactive; then
        answer="$default_value"
    elif has_tty; then
        if ! read -rp "$prompt" answer </dev/tty; then
            answer="$default_value"
        fi
    else
        answer="$default_value"
    fi

    printf -v "$out_var" '%s' "$answer"
}

safe_rm_rf() {
    local target="$1"

    if [ -z "$HOME" ] || [ "$HOME" = "/" ]; then
        warn "Refusing to remove '$target': invalid HOME"
        return 1
    fi

    case "$target" in
        "$HOME" | "")
            warn "Refusing to remove protected path: $target"
            return 1
            ;;
        "$HOME"/*) ;;
        *)
            warn "Refusing to remove non-home path: $target"
            return 1
            ;;
    esac

    if [ -e "$target" ] || [ -L "$target" ]; then
        rm -rf "$target"
    fi
    return 0
}

backup_stow_conflicts() {
    local pkg="$1"
    local conflicts=()
    local line target relative_target

    while IFS= read -r line; do
        if [[ "$line" =~ \*\ stowing\ .*\ would\ cause\ conflicts: ]] ||
            [[ "$line" =~ \*\ existing\ target\ is ]] ||
            [[ "$line" =~ \*\ cannot\ stow ]]; then
            continue
        fi
        target=$(echo "$line" | grep -oE '~?/[^ ]+' | head -1 || true)
        if [ -n "$target" ]; then
            target="${target/\~/$HOME}"
            if [ -e "$target" ] || [ -L "$target" ]; then
                case "$target" in
                    "$HOME"/*)
                        relative_target="${target#"$HOME"/}"
                        conflicts+=("$relative_target")
                        ;;
                    *)
                        warn "Skipping backup target outside HOME: $target"
                        ;;
                esac
            fi
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
    if ! tar -C "$HOME" -czf "$BACKUP_ARCHIVE" --ignore-failed-read "${conflicts[@]}" 2>/dev/null; then
        warn "Failed to create backup archive for $pkg"
        BACKUP_ARCHIVE=""
        return 0
    fi
    ok "Backup created: $BACKUP_ARCHIVE"

    # Trim backups to the last 5 per package prefix
    local count prune_count old_file
    count=$(find "$BACKUP_DIR" -maxdepth 1 -name "dotfiles-backup-${pkg}-*.tar.gz" | wc -l | tr -d ' ')
    if ((count > 5)); then
        prune_count=$((count - 5))
        while IFS= read -r old_file; do
            [ -n "$old_file" ] && rm -f "$old_file"
        done < <(
            find "$BACKUP_DIR" -maxdepth 1 -name "dotfiles-backup-${pkg}-*.tar.gz" |
                sort | head -n "$prune_count"
        )
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

    if tar -tzf "$BACKUP_ARCHIVE" 2>/dev/null | grep -Eq '(^/|(^|/)\.\.(|/))'; then
        warn "Skipping restore: backup archive contains unsafe paths"
        return 1
    fi

    prompt_read answer "Restore the backup now? [Y/n]: " "n"
    case "$answer" in
        n | N | no | NO) info "Backup retained at $BACKUP_ARCHIVE — restore manually with: tar -xzf $BACKUP_ARCHIVE -C $HOME" ;;
        *)
            if tar -xzf "$BACKUP_ARCHIVE" -C "$HOME" 2>/dev/null; then
                ok "Backup restored"
            else
                warn "Backup restore failed"
            fi
            ;;
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
        ghostty) command_exists ghostty ;;
        nvm) [ -d "$HOME/.nvm" ] ;;
        bun) command_exists bun ;;
        deno) command_exists deno ;;
        golang) command_exists go ;;
        rust) rust_toolchain_detected ;;
        python) command_exists pyenv ;;
        docker) command_exists docker ;;
        kubernetes) command_exists kubectl ;;
        vscode) vscode_cli_path >/dev/null 2>&1 ;;
        *) return 1 ;;
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
    "golang|Go|Go programming language"
    "rust|Rust|Rust programming language and Cargo"
    "python|Python|Python 3 via pyenv version manager"
    "docker|Docker|Docker Desktop for containers"
    "kubernetes|Kubernetes|kubectl + kubectx/kubens aliases"
    "vscode|VS Code|Visual Studio Code editor"
)

TOOL_IDS=() TOOL_NAMES=() TOOL_DESCS=()
for _entry in "${TOOL_REGISTRY[@]}"; do
    IFS='|' read -r _id _name _desc <<<"$_entry"
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
            selected[i]=true
            DETECTED_TOOLS+=("${TOOL_IDS[$i]}")
        fi
    done

    if is_non_interactive || ! has_tty || [ -z "${TERM:-}" ] || [ "${TERM:-}" = "dumb" ]; then
        warn "No interactive terminal available; using detected tool selection"
        SELECTED_TOOLS=("${DETECTED_TOOLS[@]}")
        return 0
    fi

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

        IFS= read -rsn1 key </dev/tty
        case "$key" in
            $'\x1b')
                read -rsn2 key </dev/tty
                case "$key" in
                    '[A') if ((cursor > 0)); then ((cursor--)); fi ;;
                    '[B') if ((cursor < num - 1)); then ((cursor++)); fi ;;
                esac
                ;;
            ' ')
                if [[ "${selected[$cursor]}" == true ]]; then
                    selected[cursor]=false
                else
                    selected[cursor]=true
                fi
                ;;
            '')
                break
                ;;
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
# detect_package_manager: echo brew when available
detect_package_manager() {
    if command_exists brew; then
        echo "brew"
        return
    fi
    echo ""
}

# install_package BREW_PKG [--cask]
# Installs a package via Homebrew.
install_package() {
    local brew_pkg="$1"
    local is_cask=false
    [[ "${2:-}" == "--cask" ]] && is_cask=true

    command_exists brew || return 1
    if $is_cask; then
        brew install --cask "$brew_pkg"
    else
        brew install "$brew_pkg"
    fi
}

install_jetbrains_mono_nerd_font() {
    [[ "$(uname)" == "Darwin" ]] || return 0

    # Homebrew cask state can disagree with user font directory state.
    # Treat existing JetBrains Mono Nerd Font files as already installed.
    local has_user_fonts=false
    if compgen -G "$HOME/Library/Fonts/JetBrainsMono*NerdFont*.ttf" >/dev/null; then
        has_user_fonts=true
    fi

    if ! command_exists brew; then
        warn "Skipping JetBrainsMono Nerd Font install because Homebrew is unavailable"
        return 0
    fi

    if brew list --cask font-jetbrains-mono-nerd-font >/dev/null 2>&1 ||
        brew list --cask font-jetbrainsmono-nerd-font >/dev/null 2>&1 ||
        $has_user_fonts; then
        ok "JetBrainsMono Nerd Font already installed"
        return 0
    fi

    info "Installing JetBrainsMono Nerd Font via Homebrew..."
    if HOMEBREW_NO_AUTO_UPDATE=1 brew install --cask font-jetbrains-mono-nerd-font ||
        HOMEBREW_NO_AUTO_UPDATE=1 brew install --cask font-jetbrainsmono-nerd-font; then
        ok "JetBrainsMono Nerd Font installed"
    elif compgen -G "$HOME/Library/Fonts/JetBrainsMono*NerdFont*.ttf" >/dev/null; then
        ok "JetBrainsMono Nerd Font already present in ~/Library/Fonts"
    else
        warn "JetBrainsMono Nerd Font install failed; the cask may be unavailable in current Homebrew repos"
    fi
}

install_ghostty() {
    if command_exists ghostty; then
        ok "Ghostty already installed"
    elif command_exists brew; then
        info "Installing Ghostty via Homebrew..."
        brew install --cask ghostty
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
        nvm_latest=$(curl -fsSL https://api.github.com/repos/nvm-sh/nvm/releases/latest | grep -m1 '"tag_name"' | sed -E 's/.*"([^"]+)".*/\1/')
        if [[ -z "$nvm_latest" || "$nvm_latest" != v* ]]; then
            fail "Could not resolve latest NVM release tag"
        fi
        PROFILE=/dev/null bash <(curl -fsSL "https://raw.githubusercontent.com/nvm-sh/nvm/${nvm_latest}/install.sh")
    fi

    if [ -d "$HOME/.nvm" ] || command_exists nvm; then
        ok "NVM installed"
    else
        warn "NVM installation may have failed — verify manually"
    fi
}

install_bun() {
    if command_exists bun; then
        ok "Bun already installed"
        return
    fi
    if command_exists brew; then
        info "Installing Bun via Homebrew..."
        brew install oven-sh/bun/bun
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
    else
        info "Installing Deno via install script..."
        bash <(curl -fsSL https://deno.land/install.sh)
    fi
    ok "Deno installed"
}

install_golang() {
    if command_exists go; then
        ok "Go already installed"
        return
    fi

    info "Installing Go..."
    if install_package "go"; then
        ok "Go installed"
    else
        warn "Install Go manually: https://go.dev/doc/install"
    fi
}

install_rust() {
    if rust_toolchain_detected; then
        ok "Rust already installed"
        return
    fi

    if ! command_exists curl; then
        warn "curl is required to install Rust via rustup"
        warn "Install Rust manually: https://www.rust-lang.org/tools/install"
        return
    fi

    info "Installing Rust via rustup..."
    if curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y; then
        # shellcheck source=/dev/null
        [ -s "$HOME/.cargo/env" ] && . "$HOME/.cargo/env"
        ok "Rust installed"
    else
        warn "Install Rust manually: https://www.rust-lang.org/tools/install"
    fi
}

install_python() {
    if command_exists pyenv; then
        ok "pyenv already installed"
    elif command_exists brew; then
        info "Installing pyenv via Homebrew..."
        brew install pyenv
        ok "pyenv installed"
    else
        warn "Install pyenv manually: https://github.com/pyenv/pyenv#installation"
    fi

    if command_exists pyenv && ! pyenv versions --bare | grep -q .; then
        info "Installing latest stable Python 3..."
        local latest
        latest=$(pyenv install --list | grep -E '^\s+3\.[0-9]+\.[0-9]+$' | tail -1 | tr -d ' ')
        if [ -z "$latest" ]; then
            warn "Could not determine latest stable Python 3 version via pyenv"
            return
        fi
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
        warn "Install Docker manually: https://www.docker.com/products/docker-desktop/"
    fi
}

install_kubernetes() {
    if ! command_exists kubectl; then
        if command_exists brew; then
            info "Installing kubectl via Homebrew..."
            brew install kubectl
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
        fi
    fi
}

install_vscode() {
    local installed_now=false
    local vscode_cli

    if vscode_cli="$(vscode_cli_path 2>/dev/null)"; then
        ok "VS Code already installed"
    elif command_exists brew; then
        info "Installing VS Code via Homebrew..."
        brew install --cask visual-studio-code
        ok "VS Code installed"
        installed_now=true
    else
        warn "Install VS Code manually: https://code.visualstudio.com/"
    fi

    if vscode_cli="$(vscode_cli_path 2>/dev/null)"; then
        info "Installing Tokyo Night VS Code theme extension..."
        if "$vscode_cli" --install-extension enkia.tokyo-night --force >/dev/null 2>&1; then
            ok "Tokyo Night theme extension installed"
        else
            warn "Could not auto-install Tokyo Night theme extension; install manually: code --install-extension enkia.tokyo-night"
        fi

        if [ -d "$DOTFILES_DIR/vscode" ]; then
            restow_package "vscode" "VS Code base settings stowed"
            vscode_merge_settings
        fi
    elif [ "$installed_now" = false ]; then
        warn "VS Code is not available on PATH; skipped theme extension install and settings stow"
    fi
}

verify_tool_installed() {
    local tool="$1"
    local cmd
    case "$tool" in
        ghostty) cmd="ghostty" ;;
        nvm)
            [ -d "$HOME/.nvm" ] && return 0
            return 1
            ;;
        bun) cmd="bun" ;;
        deno) cmd="deno" ;;
        golang) cmd="go" ;;
        rust)
            rust_toolchain_detected || {
                warn "Rust install completed but no toolchain was detected"
                return 0
            }
            command_exists rustc || warn "Rust detected but 'rustc' not found in PATH — you may need to restart your shell."
            return 0
            ;;
        python) cmd="pyenv" ;;
        docker) cmd="docker" ;;
        kubernetes) cmd="kubectl" ;;
        vscode)
            if vscode_cli_path >/dev/null 2>&1; then
                return 0
            fi
            warn "vscode installed but no VS Code CLI found — open VS Code and install the 'code' shell command."
            return 0
            ;;
        *) return 0 ;;
    esac
    command_exists "$cmd" && return 0
    warn "$tool installed but '${cmd}' not found in PATH — you may need to restart your shell."
    return 0
}

install_tool() {
    local tool="$1"
    case "$tool" in
        ghostty) install_ghostty ;;
        nvm) install_nvm ;;
        bun) install_bun ;;
        deno) install_deno ;;
        golang) install_golang ;;
        rust) install_rust ;;
        python) install_python ;;
        docker) install_docker ;;
        kubernetes) install_kubernetes ;;
        vscode) install_vscode ;;
        *) warn "No install handler for tool: $tool" ;;
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
    if [ -d "$DOTFILES_DIR/ghostty" ]; then
        unstow_package "ghostty" "Ghostty config unstowed"
    fi
}

uninstall_nvm() {
    uninstall_via_brew nvm formula
    if [ -d "$HOME/.nvm" ]; then
        info "Removing ~/.nvm..."
        if safe_rm_rf "$HOME/.nvm"; then
            ok "Removed ~/.nvm"
        fi
    fi
}

uninstall_bun() {
    uninstall_via_brew bun formula
    if [ -d "$HOME/.bun" ]; then
        info "Removing ~/.bun..."
        if safe_rm_rf "$HOME/.bun"; then
            ok "Removed ~/.bun"
        fi
    fi
}

uninstall_deno() {
    uninstall_via_brew deno formula
    if [ -d "$HOME/.deno" ]; then
        info "Removing ~/.deno..."
        if safe_rm_rf "$HOME/.deno"; then
            ok "Removed ~/.deno"
        fi
    fi
}

uninstall_golang() {
    uninstall_via_brew go formula
}

uninstall_rust() {
    if command_exists rustup; then
        info "Uninstalling Rust via rustup..."
        rustup self uninstall -y || warn "rustup uninstall encountered an issue"
    fi
    if [ -d "$HOME/.rustup" ] || [ -d "$HOME/.cargo" ]; then
        info "Removing Rust toolchain directories..."
        safe_rm_rf "$HOME/.rustup"
        safe_rm_rf "$HOME/.cargo"
        ok "Removed ~/.rustup and ~/.cargo"
    fi
}

uninstall_python() {
    uninstall_via_brew pyenv formula
    if [ -d "$HOME/.pyenv" ]; then
        info "Removing ~/.pyenv (installed Python versions included)..."
        if safe_rm_rf "$HOME/.pyenv"; then
            ok "Removed ~/.pyenv"
        fi
    fi
}

uninstall_docker() {
    uninstall_via_brew docker cask "${1:-false}"
}

uninstall_kubernetes() {
    uninstall_via_brew kubectl formula
    uninstall_via_brew kubectx formula
}

uninstall_vscode() {
    local vscode_cli
    uninstall_via_brew visual-studio-code cask "${1:-false}"
    if vscode_cli="$(vscode_cli_path 2>/dev/null)"; then
        "$vscode_cli" --uninstall-extension enkia.tokyo-night >/dev/null 2>&1 || true
    fi
    if [ -d "$DOTFILES_DIR/vscode" ]; then
        unstow_package "vscode" "VS Code base settings unstowed"
    fi
}

uninstall_tool() {
    local tool="$1"
    local purge="$2"
    case "$tool" in
        ghostty) uninstall_ghostty "$purge" ;;
        nvm) uninstall_nvm "$purge" ;;
        bun) uninstall_bun "$purge" ;;
        deno) uninstall_deno "$purge" ;;
        golang) uninstall_golang "$purge" ;;
        rust) uninstall_rust "$purge" ;;
        python) uninstall_python "$purge" ;;
        docker) uninstall_docker "$purge" ;;
        kubernetes) uninstall_kubernetes "$purge" ;;
        vscode) uninstall_vscode "$purge" ;;
        *) warn "No uninstall handler for tool: $tool" ;;
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
    prompt_read remove_answer "Uninstall deselected tools and remove their managed config/data? [y/N]: " "n"
    case "$remove_answer" in
        y | Y | yes | YES)
            prompt_read purge_answer "Also purge package-manager leftovers where supported (Homebrew zap, etc.)? [y/N]: " "n"
            case "$purge_answer" in
                y | Y | yes | YES) purge=true ;;
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
        zsh)
            rc_file="$HOME/.zshrc"
            config_file="$HOME/.config/shell/zshrc"
            ;;
        bash)
            rc_file="$HOME/.bashrc"
            config_file="$HOME/.config/shell/bashrc"
            ;;
        *)
            warn "Unrecognized shell ($SHELL) — source ~/.config/shell/zshrc (or bashrc) manually."
            return
            ;;
    esac

    local source_line="[ -f \"$config_file\" ] && source \"$config_file\" $SOURCE_TAG"

    if [ ! -f "$rc_file" ]; then
        echo "$source_line" >"$rc_file"
        ok "Created $rc_file"
    elif ! grep -qF "$SOURCE_TAG" "$rc_file" && ! grep -qF "$LEGACY_SOURCE_TAG" "$rc_file"; then
        printf "\n%s\n" "$source_line" >>"$rc_file"
        ok "Appended source line to $rc_file"
    else
        ok "$rc_file already configured"
    fi
}

# ── Git Identity ────────────────────────────────────────
setup_git_identity() {
    if [ -f "$HOME/.gitconfig.local" ]; then
        ok "$HOME/.gitconfig.local already exists"
        return
    fi

    echo ""
    info "Setting up Git identity (~/.gitconfig.local)"
    prompt_read git_name "  Git name:  " ""
    prompt_read git_email "  Git email: " ""

    if [ -n "$git_name" ] && [ -n "$git_email" ]; then
        git config --file "$HOME/.gitconfig.local" user.name "$git_name"
        git config --file "$HOME/.gitconfig.local" user.email "$git_email"
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
            --all) select_all=true ;;
            --no-tools) skip_tools=true ;;
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

    install_jetbrains_mono_nerd_font

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
