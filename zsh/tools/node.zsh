# Node via nvm
export NVM_DIR="$HOME/.nvm"
[[ -s $NVM_DIR/nvm.sh ]] || return 0

source "$NVM_DIR/nvm.sh"
[[ -s $NVM_DIR/bash_completion ]] && source "$NVM_DIR/bash_completion"
return 0
