#!/usr/bin/env bash
# Bootstrap a new machine:
#   curl -fsSL https://raw.githubusercontent.com/raine-works/.dotfiles/master/setup.sh | bash -s -- [desktop|server]
# Installs git (via Homebrew on macOS, apt on Linux), clones the repo, then runs install.sh.
set -Eeo pipefail
trap 'printf "\n✗ setup.sh failed at line %s: %s\n" "$LINENO" "$BASH_COMMAND" >&2' ERR

DOTFILES_REPO="${DOTFILES_REPO:-https://github.com/raine-works/.dotfiles.git}"
DOTFILES_DIR="${DOTFILES_DIR:-$HOME/.dotfiles}"

as_root() { if [ "$(id -u)" -eq 0 ]; then "$@"; else sudo "$@"; fi; }

case "$(uname -s)" in
    Darwin)
        if ! [ -x /opt/homebrew/bin/brew ] && ! [ -x /usr/local/bin/brew ]; then
            echo "Installing Homebrew (includes git)…"
            /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" </dev/tty
        fi
        ;;
    Linux)
        if ! command -v git >/dev/null 2>&1 || ! command -v curl >/dev/null 2>&1; then
            command -v apt-get >/dev/null 2>&1 || {
                echo "Only Debian/Ubuntu (apt) Linux is supported" >&2
                exit 1
            }
            as_root apt-get update -qq
            as_root env DEBIAN_FRONTEND=noninteractive apt-get install -y -qq git curl ca-certificates >/dev/null
        fi
        ;;
    *)
        echo "Unsupported OS: $(uname -s)" >&2
        exit 1
        ;;
esac

if [ -d "$DOTFILES_DIR/.git" ]; then
    echo "Updating $DOTFILES_DIR"
    git -C "$DOTFILES_DIR" pull --ff-only ||
        echo "Could not fast-forward $DOTFILES_DIR (local changes?); continuing with what's there" >&2
else
    git clone "$DOTFILES_REPO" "$DOTFILES_DIR"
fi

exec bash "$DOTFILES_DIR/install.sh" "$@"
