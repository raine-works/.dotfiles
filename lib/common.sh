# shellcheck shell=bash
# Shared helpers: logging, platform detection, small install utilities.

DOTFILES_DIR="${DOTFILES_DIR:-$HOME/.dotfiles}"
LOCAL_BIN="$HOME/.local/bin"
# shellcheck disable=SC2034 # used by lib/tools.sh
ZSH_COMPLETIONS_DIR="$HOME/.local/share/zsh/site-functions"

# ── Logging ──────────────────────────────────────────────
if [ -t 1 ]; then
    C_RESET=$'\033[0m' C_DIM=$'\033[2m' C_PINK=$'\033[38;2;210;126;153m'
    C_BLUE=$'\033[38;2;126;156;216m' C_GOLD=$'\033[38;2;230;195;132m' C_RED=$'\033[38;2;228;104;118m'
else
    C_RESET='' C_DIM='' C_PINK='' C_BLUE='' C_GOLD='' C_RED=''
fi

section() { printf '\n%s━━ %s%s\n' "$C_PINK" "$*" "$C_RESET"; }
info() { printf '%s  ·%s %s\n' "$C_BLUE" "$C_RESET" "$*"; }
ok() { printf '%s  ✓%s %s\n' "$C_BLUE" "$C_RESET" "$*"; }
skip() { printf '%s  – %s%s\n' "$C_DIM" "$*" "$C_RESET"; }
warn() { printf '%s  ! %s%s\n' "$C_GOLD" "$*" "$C_RESET" >&2; }
die() {
    printf '%s  ✗ %s%s\n' "$C_RED" "$*" "$C_RESET" >&2
    exit 1
}

# Warnings collected during the run, printed again in the final summary.
NOTES=()
note() {
    NOTES+=("$*")
    warn "$*"
}

# ── Platform ─────────────────────────────────────────────
has() { command -v "$1" >/dev/null 2>&1; }

detect_platform() {
    case "$(uname -s)" in
        Darwin) OS=macos ;;
        Linux) OS=linux ;;
        *) die "Unsupported OS: $(uname -s)" ;;
    esac

    case "$(uname -m)" in
        x86_64 | amd64) ARCH=x86_64 ;;
        arm64 | aarch64) ARCH=arm64 ;;
        *) die "Unsupported architecture: $(uname -m)" ;;
    esac

    export OS ARCH
}

# Run as root: directly if we already are, otherwise through sudo.
as_root() {
    if [ "$(id -u)" -eq 0 ]; then
        "$@"
    else
        sudo "$@"
    fi
}

has_systemd() { [ -d /run/systemd/system ]; }

# In the docker group (per /etc/group) but this session started before that,
# so the session doesn't have it yet.
docker_group_pending() {
    getent group docker 2>/dev/null | cut -d: -f4 | tr ',' '\n' | grep -x "$USER" >/dev/null &&
        ! id -nG | tr ' ' '\n' | grep -x docker >/dev/null
}

# Replace this process with a fresh login zsh, picking up a newly added docker
# group if needed (like newgrp). Only when there's a terminal to hand over.
reload_shell() {
    { : </dev/tty; } 2>/dev/null || return 0
    has zsh || return 0
    if [ "$OS" = linux ] && docker_group_pending && has sg; then
        info "Starting zsh with the docker group active"
        exec sg docker -c 'exec zsh -l' </dev/tty
    fi
    exec zsh -l </dev/tty
}

# Run a remote installer script. Usage: run_remote <url> <shell> [args...]
run_remote() {
    local url="$1" shell="$2"
    shift 2
    curl -fsSL "$url" | "$shell" -s -- "$@"
}

# Latest release tag of a GitHub repo, e.g. "v0.44.1".
github_latest_tag() {
    curl -fsSL "https://api.github.com/repos/$1/releases/latest" | jq -r .tag_name
}

# Download a tar.gz and install one binary from it into ~/.local/bin.
# Usage: install_tarball_bin <url> <binary-name>
install_tarball_bin() {
    local url="$1" bin="$2" tmp
    tmp="$(mktemp -d)"
    curl -fsSL "$url" | tar -xz -C "$tmp"
    install -m 0755 "$(find "$tmp" -type f -name "$bin" | head -1)" "$LOCAL_BIN/$bin"
    rm -rf "$tmp"
}
