#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
TMP_HOME="$(mktemp -d)"

cleanup() {
    rm -rf "$TMP_HOME"
}
trap cleanup EXIT

require_cmd() {
    command -v "$1" >/dev/null 2>&1 || {
        echo "Missing required command: $1" >&2
        exit 1
    }
}

require_cmd bash
require_cmd zsh
require_cmd stow

echo "[1/5] Syntax checks"
bash -n "$ROOT_DIR/install.sh"
bash -n "$ROOT_DIR/setup.sh"
bash -n "$ROOT_DIR/shell/.config/shell/shelldefs"
bash -n "$ROOT_DIR/shell/.config/shell/bashrc"
for file in "$ROOT_DIR"/shell/.config/shell/tools/*.sh; do
    bash -n "$file"
done
zsh -n "$ROOT_DIR/shell/.config/shell/zshrc"

echo "[2/5] Stow simulation checks"
stow -n --simulate -d "$ROOT_DIR" -t "$TMP_HOME" shell
stow -n --simulate -d "$ROOT_DIR" -t "$TMP_HOME" starship
stow -n --simulate -d "$ROOT_DIR" -t "$TMP_HOME" gitconfig
stow -n --simulate -d "$ROOT_DIR" -t "$TMP_HOME" ghostty

echo "[3/5] Non-interactive installer run (--no-tools)"
(
    cd "$ROOT_DIR"
    DOTFILES_NONINTERACTIVE=1 HOME="$TMP_HOME" SHELL="/bin/bash" TERM=dumb bash ./install.sh --no-tools >/dev/null
)

echo "[4/5] Source-line idempotency check"
if [ -f "$TMP_HOME/.bashrc" ]; then
    count="$(grep -c "dotfiles-managed:raine-works" "$TMP_HOME/.bashrc" || true)"
    if [ "$count" -ne 1 ]; then
        echo "Expected exactly one managed source line in .bashrc, found: $count" >&2
        exit 1
    fi
fi

(
    cd "$ROOT_DIR"
    DOTFILES_NONINTERACTIVE=1 HOME="$TMP_HOME" SHELL="/bin/bash" TERM=dumb bash ./install.sh --no-tools >/dev/null
)

count="$(grep -c "dotfiles-managed:raine-works" "$TMP_HOME/.bashrc" || true)"
if [ "$count" -ne 1 ]; then
    echo "Managed source line is not idempotent in .bashrc (count=$count)" >&2
    exit 1
fi

echo "[5/5] Completed"
echo "Smoke checks passed"
