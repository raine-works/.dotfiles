#!/bin/bash

sudo apt update
sudo apt upgrade -y
sudo apt install stow

stow . --target=/home/$USER