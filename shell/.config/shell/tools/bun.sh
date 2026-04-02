# Bun — completions
command -v bun >/dev/null 2>&1 || return 0

[ -s "$HOME/.bun/_bun" ] && source "$HOME/.bun/_bun"
