# Restore bashrc and remove dotfiles package

BASH_BACKUPS=~/.bash_backups
if [[ ! -d "$BASH_BACKUPS" ]]; then 
    # Reset bashrc to default
    echo "Could not find any backups. Initializing a new bashrc file..."
    rm ~/.bashrc
    /bin/cp /etc/skel/.bashrc ~/.bashrc
else 
    # Get the most recent backup and restore it
    echo "Restoring to last backup..."
    FILES=($BASH_BACKUPS/*)
    for FILE in "${FILES[@]}"; do
        if [[ ! $LATEST_BACKUP ]]; then
            LATEST_BACKUP=$(basename "$FILE")
        else
            if [[ $(basename "$FILE") > $LATEST_BACKUP ]]; then
                LATEST_BACKUP=$(basename "$FILE")
            fi
        fi
        
    done
    rm ~/.bashrc
    cp ${BASH_BACKUPS}/${LATEST_BACKUP} ~/.bashrc
fi

# Remove dotfiles package from system
rm -rf ~/.dotfiles