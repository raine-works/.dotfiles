# Go
[[ -d /usr/local/go/bin ]] && path=(/usr/local/go/bin $path)
(( $+commands[go] )) || return 0

export GOPATH="${GOPATH:-$HOME/go}"
path=("$GOPATH/bin" $path)
