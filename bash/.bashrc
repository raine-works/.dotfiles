# ---------------------------------------------------------
# Shared configuration (aliases, exports, tools)
# ---------------------------------------------------------
[ -f "$HOME/.shelldefs" ] && source "$HOME/.shelldefs"

# ---------------------------------------------------------
# Bash-specific: Completion
# ---------------------------------------------------------
if command -v fzf >/dev/null 2>&1; then
    eval "$(fzf --bash)"
fi

# ---------------------------------------------------------
# Bash-specific: Functions
# ---------------------------------------------------------
fzf-alias-finder() {
  local result=$(alias | fzf --no-sort --ansi | cut -d'=' -f1 | sed 's/alias //')
  if [[ -n "$result" ]]; then
    history -s "$result"
    echo "$result"
  fi
}

alias aliases='fzf-alias-finder'
alias refresh='source ~/.bashrc'

# ---------------------------------------------------------
# Prompt (must be last)
# ---------------------------------------------------------
eval "$(starship init bash)"
