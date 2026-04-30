# shellcheck shell=bash
# Go — GOPATH and Go bin directory setup
command -v go >/dev/null 2>&1 || return 0

export GOPATH="${GOPATH:-$HOME/go}"
case ":$PATH:" in
    *":$GOPATH/bin:"*) ;;
    *) export PATH="$GOPATH/bin:$PATH" ;;
esac
