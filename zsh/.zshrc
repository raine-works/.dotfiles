# 1. PATHS & ENVIRONMENT VARIABLES
# ---------------------------------------------------------
export KUBECONFIG=~/.kube/config
export BUN_INSTALL="$HOME/.bun"
export JAVA_HOME=/Library/Java/JavaVirtualMachines/zulu-11.jdk/Contents/Home
export ANDROID_HOME="$HOME/Library/Android/sdk"
export NVM_DIR="$HOME/.nvm"
export HOST_IP=$(ipconfig getifaddr en0 || ipconfig getifaddr en1)
export STARSHIP_CONFIG=~/.config/starship/starship.toml

# Update PATH
export PATH="$BUN_INSTALL/bin:$JAVA_HOME/bin:$PATH"

# 2. COMPLETION SYSTEM (Crucial Order)
# ---------------------------------------------------------
# Load completions for Docker/Homebrew before compinit
fpath=(/Users/rainepetersen/.docker/completions $fpath)

# Initialize completion system (Only call this ONCE)
autoload -Uz compinit && compinit

source <(fzf --zsh)

# 3. ZSTYLE CONFIGURATION (FZF-Tab & Completion Behavior)
# ---------------------------------------------------------
# Case-insensitive completion
zstyle ':completion:*' matcher-list 'm:{a-z}={A-Z}'
zstyle ':completion:*' list-colors ${(s.:.)LS_COLORS}
zstyle ':completion:*' menu select

# 4. EXTERNAL TOOLS (NVM, Bun, etc.)
# ---------------------------------------------------------
[ -s "/Users/rainepetersen/.bun/_bun" ] && source "/Users/rainepetersen/.bun/_bun"
[ -s "$(brew --prefix nvm)/nvm.sh" ] && . "$(brew --prefix nvm)/nvm.sh"

# 5. FUNCTIONS
# ---------------------------------------------------------
fzf-alias-finder() {
  local result=$(alias | fzf --no-sort --ansi | cut -d'=' -f1 | sed 's/alias //')
  if [[ -n "$result" ]]; then
    print -z -- "$result"
  fi
}

# 6. ALIASES
# ---------------------------------------------------------
alias aliases='fzf-alias-finder'
alias refresh='source ~/.zshrc'
alias home='cd ~/'
alias cl='clear'
alias ..='cd ../'
alias ...='cd ../../'
alias ....='cd ../../../'
alias lsa='ls -a'
alias ip='echo $HOST_IP'
alias fzfp='fzf -m --preview="bat --color=always {}"'

# Application Aliases
alias chrome='open -a "Google Chrome"'

# Docker
alias d='docker'
alias dps='docker ps'
alias dstop='docker stop $(docker ps -aq)'
alias dc='docker compose'
alias dcu='docker compose up'
alias dcd='docker compose down'

# K8S Aliases
alias k='kubectl'
alias ka='kubectl apply -f'
alias ke='kubectl exec -it'
alias kg='kubectl get'
alias kd='kubectl describe'
alias kgpo='kubectl get pods'
alias kgd='kubectl get deployments'
alias kgs='kubectl get svc'
alias kgpow='kubectl get pods -o wide'
alias kc='kubectx'
alias kns='kubens'
alias kl='kubectl logs -f --tail=50'
alias klp='kubectl get pods | fzf --header-lines=1 --header "Select Pod to Log" | awk "{print \$1}" | xargs -r kubectl logs -f --tail=50'
alias klns='kubectl get pods -A | fzf --header-lines=1 --header "Select Pod (All Namespaces)" | awk "{print \"-n \" \$1 \" \" \$2}" | xargs -r kubectl logs -f --tail=50'
alias kdel="kubectl delete"
alias kdelp='kubectl get pods | fzf -m --header "Select Pods to Delete" --header-lines=1 | awk "{print \$1}" | xargs kubectl delete pod'

# 7. PROMPT (Must be last)
# ---------------------------------------------------------
eval "$(starship init zsh)"
