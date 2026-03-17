#!/usr/bin/env bash
set -e

DOTFILES_DIR="$(cd "$(dirname "$0")" && pwd)"
PACKAGES=(shell ghostty starship gitconfig)

# Detect shell and add the right shell package
case "$(basename "$SHELL")" in
    zsh)  PACKAGES+=(zsh)  ;;
    bash) PACKAGES+=(bash) ;;
    *)    echo "  Warning: unrecognized shell ($SHELL), skipping shell config" ;;
esac

echo "Stowing dotfiles from $DOTFILES_DIR"

for pkg in "${PACKAGES[@]}"; do
    if [ -d "$DOTFILES_DIR/$pkg" ]; then
        echo "  Stowing $pkg..."
        stow -d "$DOTFILES_DIR" -t "$HOME" "$pkg"
    fi
done

echo ""
echo "Done! Don't forget to create ~/.gitconfig.local with your personal info:"
echo '  [user]'
echo '      email = you@example.com'
echo '      name = your-name'
