# Aliases and small functions shared by every machine.

alias home='cd ~'
alias cl='clear'
alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'
alias reload='exec zsh'

if (( $+commands[eza] )); then
  alias ls='eza --group-directories-first --icons=auto'
  alias ll='eza -l --group-directories-first --icons=auto --git'
  alias la='eza -la --group-directories-first --icons=auto --git'
  alias lt='eza --tree --level=2 --icons=auto'
else
  alias ll='ls -lh'
  alias la='ls -lah'
fi
alias lsa='la'

if (( $+commands[bat] )); then
  alias cat='bat --paging=never --style=plain'
  alias fzfp='fzf -m --preview="bat --color=always --style=numbers {}"'
fi

(( $+commands[lazygit] )) && alias lg='lazygit'

[[ $OSTYPE == darwin* ]] && alias chrome='open -a "Google Chrome"'

# This machine's LAN IP (not named `ip`, which would hide the Linux ip command).
lanip() {
  if [[ $OSTYPE == darwin* ]]; then
    ipconfig getifaddr en0 2>/dev/null || ipconfig getifaddr en1
  else
    hostname -I | awk '{print $1}'
  fi
}

# Fuzzy-find an alias and put it on the command line.
aliases() {
  local pick
  pick="$(alias | fzf --no-sort | cut -d= -f1)"
  [[ -n $pick ]] && print -z -- "$pick"
}

# dotfiles update: pull the shared config and re-run the installer with this
# machine's profile (saved by install.sh), then reload the shell.
dotfiles() {
  local profile_file="$HOME/.config/dotfiles/profile" profile
  case "$1" in
    update)
      git -C "$DOTFILES_DIR" pull --ff-only || return
      [[ -r $profile_file ]] && profile="$(<"$profile_file")"
      DOTFILES_NO_RELOAD=1 bash "$DOTFILES_DIR/install.sh" $profile || return
      # Reload this shell; via sg if the install just added us to the docker group.
      if [[ " ${(f)$(getent group docker 2>/dev/null | cut -d: -f4 | tr , '\n')} " == *" $USER "* ]] &&
         [[ " $(id -nG) " != *" docker "* ]] && (( $+commands[sg] )); then
        exec sg docker -c 'exec zsh -l'
      fi
      exec zsh -l
      ;;
    *)
      print -u2 "usage: dotfiles update"
      return 1
      ;;
  esac
}
