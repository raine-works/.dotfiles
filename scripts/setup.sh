#!/bin/bash

# Clone dotfiles and run install
git clone https://github.com/raine-works/.dotfiles.git ~/.dotfiles
bash ~/.dotfiles/scripts/install.sh

# Backup files
mkdir ~/.dotfiles_backup
cp ~/.bashrc ~/.dotfiles_backup/.bashrc
cp ~/.gitconfig ~/.dotfiles_backup/.gitconfig

# Sync dotfiles to user directory
bash ~/.dotfiles/scripts/sync.sh

