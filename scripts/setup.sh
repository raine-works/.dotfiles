#!/bin/bash

sudo apt update
sudo apt upgrade -y
sudo apt install zip
sudo apt install unzip
sudo apt install fontconfig -y
sudo apt install stow

# Install nerd font
curl -L https://github.com/ryanoasis/nerd-fonts/releases/download/v3.1.1/JetBrainsMono.zip > /tmp/JetBrainsMono.zip
curl -L https://github.com/ryanoasis/nerd-fonts/releases/download/v3.1.1/NerdFontsSymbolsOnly.zip > /tmp/NerdFontsSymbolsOnly.zip
[ -d ~/.local/share/fonts ] || mkdir -p ~/.local/share/fonts
unzip -o /tmp/JetBrainsMono.zip -d ~/.local/share/fonts
unzip -o /tmp/NerdFontsSymbolsOnly.zip -d ~/.local/share/fonts
rm -rf /tmp/JetBrainsMono.zip
rm -rf /tmp/NerdFontsSymbolsOnly.zip
fc-cache -fv

# Install starship
curl -sS https://starship.rs/install.sh | sh -s -- --bin-dir /usr/local/bin -y

stow . --target=/home/$USER