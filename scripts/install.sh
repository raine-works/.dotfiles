
# Backup old bashrc file if it exists.
BASHRC=~/.bashrc
BASH_BACKUPS=~/.bash_backups

if [[ -f "$BASHRC" ]]; then
    echo "Making bashrc backup"
    if [[ ! -d "$BASH_BACKUPS" ]]; then 
        mkdir ~/.bash_backups 
    fi
    mv ~/.bashrc ~/.bash_backups/$(date +%s)
fi

ln -s ~/.dotfiles/configs/.bashrc ~/.bashrc -f