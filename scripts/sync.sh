#!/bin/bash

echo "Syncing dotfiles..."
stow . --dir=/home/$USER/.dotfiles --target=/home/$USER