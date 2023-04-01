#!/bin/bash

source ~/.dotfiles/scripts/helpers.sh

# Make bashrc backup
backupBashrc() {
    echo "Making bashrc backup..."
    loading 1
    
    BASHRC=~/.bashrc
    BASH_BACKUPS=~/.bash_backups

    if [[ -f "$BASHRC" ]]; then
        if [[ ! -d "$BASH_BACKUPS" ]]; then 
            mkdir ~/.bash_backups 
        fi
        mv ~/.bashrc ~/.bash_backups/$(date +%s)
    fi
}

# Install bashrc
installBashrc() {
    echo "Installing bashrc..."
    loading 1
    ln -s ~/.dotfiles/configs/.bashrc ~/.bashrc -f
}

# Install global git config and hooks
installGitCOnfig() {
    GIT_TEMPLATES=~/.git-templates
    GIT_HOOKS=~/.git-templates/hooks

    if [[ ! -d "$GIT_TEMPLATES" ]]; then
        mkdir -p ~/.git-templates/hooks
    fi 

    if [[ ! -d "$GIT_HOOKS" ]]; then
        mkdir -p ~/.git-templates/hooks
    fi

    ln -s ~/.dotfiles/configs/.gitconfig ~/.gitconfig -f
    ln -s ~/.dotfiles/configs/git-hooks/post-commit ~/.git-templates/hooks/post-commit -f
}

# Start here
backupBashrc
installBashrc

while true; do
    read -p "Do you wish to overwrite your global git config this? " yn
    case $yn in
        [Yy]* ) installGitCOnfig; break;;
        [Nn]* ) exit;;
        * ) echo "Please answer yes or no.";;
    esac
done