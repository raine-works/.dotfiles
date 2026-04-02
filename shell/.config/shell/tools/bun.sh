# shellcheck shell=bash
# Bun — completions
command -v bun >/dev/null 2>&1 || return 0

# shellcheck source=/dev/null
[ -s "$HOME/.bun/_bun" ] && source "$HOME/.bun/_bun"
