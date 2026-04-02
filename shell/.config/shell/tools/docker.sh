# shellcheck shell=bash
# Docker — container aliases
command -v docker >/dev/null 2>&1 || return 0

alias d='docker'
alias dps='docker ps'
alias dc='docker compose'
alias dcu='docker compose up'
alias dcd='docker compose down'

dstop() {
    local containers
    containers="$(docker ps -aq 2>/dev/null)" || return 1

    if [ -z "$containers" ]; then
        echo "No containers to stop"
        return 0
    fi

    printf '%s\n' "$containers" | xargs docker stop
}
