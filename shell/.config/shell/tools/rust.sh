command -v rustc >/dev/null 2>&1 || return 0

[ -s "$HOME/.cargo/env" ] && . "$HOME/.cargo/env"
