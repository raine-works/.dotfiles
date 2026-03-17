# Docker — container aliases
command -v docker >/dev/null 2>&1 || return 0

alias d='docker'
alias dps='docker ps'
alias dstop='docker stop $(docker ps -aq)'
alias dc='docker compose'
alias dcu='docker compose up'
alias dcd='docker compose down'
