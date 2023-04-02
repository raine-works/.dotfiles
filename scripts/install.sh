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
    echo "Installing global git config..."
    loading 1

    GIT_TEMPLATES=~/.git-templates
    GIT_HOOKS=~/.git-templates/hooks
    GHOST_PROJECT=~/.ghost

    if [[ ! -d "$GIT_TEMPLATES" ]]; then
        mkdir -p ~/.git-templates/hooks
    fi 

    if [[ ! -d "$GIT_HOOKS" ]]; then
        mkdir -p ~/.git-templates/hooks
    fi

    ln -s ~/.dotfiles/configs/.gitconfig ~/.gitconfig -f
    ln -s ~/.dotfiles/configs/git-hooks/* ~/.git-templates/hooks -f
    
    # Install ghost project if not already installed
    if [[ ! -d "$GHOST_PROJECT" ]]; then
        echo "Installing ghost project..."
        git clone git@github.com:raine-works/.ghost.git
    fi
}

# Install tools
setupTools () {

    # Install github cli
    type -p curl >/dev/null || (sudo apt update && sudo apt install curl -y)
    curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg 
    sudo chmod go+r /usr/share/keyrings/githubcli-archive-keyring.gpg
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null 
    sudo apt update 
    sudo apt install gh -y

    # Install volta
    curl https://get.volta.sh | bash
}

# Start here
setupTools

while true; do
    read -p "Do you wish to overwrite your bashrc config? " yn
    case $yn in
        [Yy]* ) backupBashrc && installBashrc; break;;
        [Nn]* ) exit;;
        * ) echo "Please answer yes or no.";;
    esac
done

while true; do
    read -p "Do you wish to overwrite your global git config this? " yn
    case $yn in
        [Yy]* ) installGitCOnfig; break;;
        [Nn]* ) exit;;
        * ) echo "Please answer yes or no.";;
    esac
done