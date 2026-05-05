# shellcheck shell=bash
# Bun — completions
command -v bun >/dev/null 2>&1 || return 0

if [ -s "$HOME/.bun/_bun" ]; then
    # shellcheck source=/dev/null
    source "$HOME/.bun/_bun"
fi

return 0
