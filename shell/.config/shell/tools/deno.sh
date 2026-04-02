# shellcheck shell=bash
# Deno — runtime PATH and completions
command -v deno >/dev/null 2>&1 || return 0

export DENO_INSTALL="$HOME/.deno"
[ -d "$DENO_INSTALL/bin" ] && export PATH="$DENO_INSTALL/bin:$PATH"

return 0
