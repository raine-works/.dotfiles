# shellcheck shell=bash
# Deno — runtime PATH and completions
export DENO_INSTALL="$HOME/.deno"
[ -d "$DENO_INSTALL/bin" ] && export PATH="$DENO_INSTALL/bin:$PATH"
