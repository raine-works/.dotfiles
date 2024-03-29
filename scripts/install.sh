#!/bin/bash

sudo apt update
sudo apt install zip -y
sudo apt install unzip -y
sudo apt install fontconfig -y
sudo apt install stow -y

# Install nerd font
curl -L https://github.com/ryanoasis/nerd-fonts/releases/download/v3.1.1/JetBrainsMono.zip > /tmp/JetBrainsMono.zip
curl -L https://github.com/ryanoasis/nerd-fonts/releases/download/v3.1.1/NerdFontsSymbolsOnly.zip > /tmp/NerdFontsSymbolsOnly.zip
sudo unzip -o /tmp/JetBrainsMono.zip -d /usr/local/share/fonts
sudo unzip -o /tmp/NerdFontsSymbolsOnly.zip -d /usr/local/share/fonts
if [[ $(grep -i Microsoft /proc/version) ]]; then
    sudo chmod a+w /mnt/c/Windows/Fonts
    sudo  unzip -o /tmp/JetBrainsMono.zip -d /mnt/c/Windows/Fonts
    sudo  unzip -o /tmp/NerdFontsSymbolsOnly.zip -d /mnt/c/Windows/Fonts
fi
rm -rf /tmp/JetBrainsMono.zip
rm -rf /tmp/NerdFontsSymbolsOnly.zip
fc-cache -fv

# Install starship
curl -sS https://starship.rs/install.sh | sh -s -- --bin-dir /usr/local/bin -y