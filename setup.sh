#!/bin/bash

echo " __  ____     __  _____   ____ _______ ______ _____ _      ______  _____ 
|  \/  \ \   / / |  __ \ / __ \__   __|  ____|_   _| |    |  ____|/ ____|
| \  / |\ \_/ /  | |  | | |  | | | |  | |__    | | | |    | |__  | (___  
| |\/| | \   /   | |  | | |  | | | |  |  __|   | | | |    |  __|  \___ \ 
| |  | |  | |    | |__| | |__| | | |  | |     _| |_| |____| |____ ____) |
|_|  |_|  |_|    |_____/ \____/  |_|  |_|    |_____|______|______|_____/ 

By @raine-works   
"

DIR=`whoami`

echo "Updating packages"
sudo apt update

echo "Installing zsh"
sudo apt install zsh

echo "Setting zsh to default shell"
sudo chsh -s /bin/zsh $DIR

echo "Installing powerlevel10k"
git clone --depth=1 https://github.com/romkatv/powerlevel10k.git ~/.powerlevel10k

ln -s ~/.dotfiles/.zshrc ~/.zshrc
ln -s ~/.dotfiles/.p10k.zsh ~/.p10k.zsh
