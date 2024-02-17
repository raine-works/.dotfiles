#!/bin/bash

echo "Unsyncing dotfiles..."
stow --delete . --dir=/home/$USER/.dotfiles --target=/home/$USER

echo "Removing files..."
sudo apt remove stow

cp ~/.dotfiles_backup/.bashrc ~/.bashrc
cp ~/.dotfiles_backup/.gitconfig ~/.gitconfig

rm -rf ~/.dotfiles_backup
rm -rf ~/.dotfiles