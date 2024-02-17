#!/bin/bash

# Clone dotfiles and run install
echo "Setting up repository..."
sudo git clone https://github.com/raine-works/.dotfiles.git /tmp/dotfiles
sudo mv /tmp/dotfiles ~/.dotfiles
sudo rm -rf /tmp/dotfiles
bash ~/.dotfiles/scripts/install.sh

# Backup files
echo "Backing up dotfiles"
mkdir ~/.dotfiles_backup
cp ~/.bashrc ~/.dotfiles_backup/.bashrc
cp ~/.gitconfig ~/.dotfiles_backup/.gitconfig

# Sync dotfiles to user directory
bash ~/.dotfiles/scripts/sync.sh

