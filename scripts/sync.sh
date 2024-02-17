#!/bin/bash

echo "syncing dotfiles..."
stow . --dir=/home/$USER/.dotfiles --target=/home/$USER