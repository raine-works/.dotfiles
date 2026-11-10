# Bun
export BUN_INSTALL="$HOME/.bun"
[[ -d $BUN_INSTALL/bin ]] && path=("$BUN_INSTALL/bin" $path)
(( $+commands[bun] )) || return 0

# ~/.bun/_bun is a completion function; putting its directory on fpath lets compinit load it.
fpath=("$BUN_INSTALL" $fpath)
