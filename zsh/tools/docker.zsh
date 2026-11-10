# Docker
(( $+commands[docker] )) || return 0

alias d='docker'
alias dps='docker ps'
alias dc='docker compose'
alias dcu='docker compose up'
alias dcd='docker compose down'
(( $+commands[lazydocker] )) && alias lzd='lazydocker'

dstop() {
  local containers
  containers="$(docker ps -q)" || return 1
  if [[ -z $containers ]]; then
    echo "No running containers"
    return 0
  fi
  docker stop ${(f)containers}
}
