# NVM — Node Version Manager
export NVM_DIR="$HOME/.nvm"

nvm_script=""

if [ -s "$NVM_DIR/nvm.sh" ]; then
    nvm_script="$NVM_DIR/nvm.sh"
elif command -v brew >/dev/null 2>&1; then
    brew_nvm_prefix="$(brew --prefix nvm 2>/dev/null || true)"
    [ -n "$brew_nvm_prefix" ] && [ -s "$brew_nvm_prefix/nvm.sh" ] && nvm_script="$brew_nvm_prefix/nvm.sh"
fi

[ -n "$nvm_script" ] && . "$nvm_script"

unset nvm_script
unset brew_nvm_prefix
