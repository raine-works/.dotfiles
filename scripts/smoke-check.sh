#!/usr/bin/env bash
# Fast checks that need no network: syntax, lint, config parsing, and that
# wiring up configs leaves the repo untouched.
set -Eeuo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP_HOME="$(mktemp -d)"
trap 'rm -rf "$TMP_HOME"' EXIT
cd "$ROOT"

step() { printf '\n== %s\n' "$*"; }

step "bash syntax"
for f in install.sh setup.sh lib/*.sh scripts/*.sh; do bash -n "$f"; done

step "zsh syntax"
for f in zsh/zshrc zsh/*.zsh zsh/tools/*.zsh; do zsh -n "$f"; done

if command -v shellcheck >/dev/null; then
    step "shellcheck"
    shellcheck -x install.sh setup.sh lib/*.sh scripts/*.sh
fi

if command -v shfmt >/dev/null; then
    step "shfmt"
    shfmt -i 4 -ci -d install.sh setup.sh lib/*.sh scripts/*.sh
fi

step "config parsing"
git config -f git/config --list >/dev/null
python3 -c 'import json, sys; json.load(open(sys.argv[1]))' zed/settings.json
python3 -c 'import sys, tomllib; tomllib.load(open(sys.argv[1], "rb"))' starship/starship.toml

step "Zed merge keeps local values and forces disable_ai"
mkdir -p "$TMP_HOME/.config/zed"
printf '{\n  // comment\n  "disable_ai": false,\n  "ui_font_size": 20,\n}\n' >"$TMP_HOME/.config/zed/settings.json"
python3 lib/merge_jsonc.py zed/settings.json "$TMP_HOME/.config/zed/settings.json" disable_ai
python3 - "$TMP_HOME/.config/zed/settings.json" <<'PY'
import json, sys
s = json.load(open(sys.argv[1]))
assert s["disable_ai"] is True and s["ui_font_size"] == 20 and "theme" in s, s
PY

step "config wiring in a scratch HOME (twice), repo stays clean"
before="$(git status --porcelain)"
printf 'alias mine=true\n' >"$TMP_HOME/.zshrc"
printf '[user]\n\tname = Someone\n' >"$TMP_HOME/.gitconfig"
printf 'font-size = 12\n' >"$TMP_HOME/.config/ghostty-seed"
mkdir -p "$TMP_HOME/.config/ghostty" && mv "$TMP_HOME/.config/ghostty-seed" "$TMP_HOME/.config/ghostty/config"
for _ in 1 2; do
    HOME="$TMP_HOME" DOTFILES_DIR="$ROOT" bash -c '
        set -Eeo pipefail
        . lib/common.sh
        . lib/tools.sh
        link_configs desktop >/dev/null'
done
[ "$(grep -c 'dotfiles-managed' "$TMP_HOME/.zshrc")" -eq 1 ]
grep -qx 'alias mine=true' "$TMP_HOME/.zshrc"
[ "$(HOME="$TMP_HOME" git config --global user.name)" = Someone ]
[ "$(HOME="$TMP_HOME" git config --global --includes init.defaultBranch)" = master ]
grep -qx 'font-size = 12' "$TMP_HOME/.config/ghostty/config.local"
[ -f "$TMP_HOME/.config/git/ignore" ]
[ -z "$(find "$TMP_HOME" -type l)" ]
[ "$(git status --porcelain)" = "$before" ]

printf '\nAll checks passed.\n'
