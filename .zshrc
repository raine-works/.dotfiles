# Enable Powerlevel10k instant prompt. Should stay close to the top of ~/.zshrc.
# Initialization code that may require console input (password prompts, [y/n]
# confirmations, etc.) must go above this block; everything else may go below.
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

# Set up the prompt

autoload -Uz promptinit
promptinit
prompt adam1

setopt histignorealldups sharehistory

# Use emacs keybindings even if our EDITOR is set to vi
bindkey -e

# Keep 1000 lines of history within the shell and save it to ~/.zsh_history:
HISTSIZE=1000
SAVEHIST=1000
HISTFILE=~/.zsh_history

# Use modern completion system
autoload -Uz compinit
compinit

zstyle ':completion:*' auto-description 'specify: %d'
zstyle ':completion:*' completer _expand _complete _correct _approximate
zstyle ':completion:*' format 'Completing %d'
zstyle ':completion:*' group-name ''
zstyle ':completion:*' menu select=2
eval "$(dircolors -b)"
zstyle ':completion:*:default' list-colors ${(s.:.)LS_COLORS}
zstyle ':completion:*' list-colors ''
zstyle ':completion:*' list-prompt %SAt %p: Hit TAB for more, or the character to insert%s
zstyle ':completion:*' matcher-list '' 'm:{a-z}={A-Z}' 'm:{a-zA-Z}={A-Za-z}' 'r:|[._-]=* r:|=* l:|=*'
zstyle ':completion:*' menu select=long
zstyle ':completion:*' select-prompt %SScrolling active: current selection at %p%s
zstyle ':completion:*' use-compctl false
zstyle ':completion:*' verbose true

zstyle ':completion:*:*:kill:*:processes' list-colors '=(#b) #([0-9]#)*=0=01;31'
zstyle ':completion:*:kill:*' command 'ps -u $USER -o pid,%cpu,tty,cputime,cmd'
source ~/.powerlevel10k/powerlevel10k.zsh-theme

# To customize prompt, run `p10k configure` or edit ~/.p10k.zsh.
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh
# Start Docker daemon automatically when logging in if not running.
RUNNING=`ps aux | grep dockerd | grep -v grep`
if [ -z "$RUNNING" ]; then
    sudo dockerd > /dev/null 2>&1 &
    disown
fi

export NVM_DIR="$([ -z "${XDG_CONFIG_HOME-}" ] && printf %s "${HOME}/.nvm" || printf %s "${XDG_CONFIG_HOME}/nvm")"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh" # This loads nvm

WINUSER=$(wslvar USERNAME)

# My custom aliases 
alias mnt="cd /mnt/c/Users/'$WINUSER'"
alias dev="cd /home/`whoami`/projects"
alias home="cd /home/`whoami`"
alias .="cd .."
alias ..="cd ../.."
alias ...="cd ../../.."
alias lsa="ls -a"
alias reload="source ~/.zshrc && echo 'reloading...'"
alias c="clear"

# Git aliases
function nb() {
  git checkout -b "$@"
}

function db() {
  git branch -D "$@"
} 

function co() {
  git checkout "$@"
}

function push() {
  OPTION=${1:-''}
  if [ "$OPTION" = "new" ]; then 
    BRANCH=`git rev-parse --abbrev-ref HEAD`
    git push --set-upstream origin $BRANCH
  else 
    git push
  fi
}

function add() {
  git add "$@"
  git status
}

function commit() {
  git commit -m "$@"
}

alias pull="git pull"
alias bls="git branch -l"
alias status="git status"

# Misc functions
function cdls() {
  cd "$@" && ls;
}

function cdcode() {
  cd "$@" && code .;
}

function show() {
  explorer.exe "$@"
}

# My paths
export PNPM_HOME="/home/raine/.local/share/pnpm"
export PATH="$PNPM_HOME:$PATH"
