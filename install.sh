#!/usr/bin/env bash
set -e

DOTFILES_DIR="$(cd "$(dirname "$0")" && pwd)"
PACKAGES=(shell ghostty starship gitconfig)
SOURCE_TAG="# dotfiles-managed"

echo "Stowing dotfiles from $DOTFILES_DIR"

for pkg in "${PACKAGES[@]}"; do
    if [ -d "$DOTFILES_DIR/$pkg" ]; then
        echo "  Stowing $pkg..."
        stow -d "$DOTFILES_DIR" -t "$HOME" "$pkg"
    fi
done

# Inject source line into the user's shell rc file
inject_source_line() {
    local rc_file="$1"
    local config_file="$2"
    local source_line="[ -f \"$config_file\" ] && source \"$config_file\" $SOURCE_TAG"

    if [ ! -f "$rc_file" ]; then
        echo "$source_line" > "$rc_file"
        echo "  Created $rc_file with dotfiles source line"
    elif ! grep -qF "$SOURCE_TAG" "$rc_file"; then
        echo "" >> "$rc_file"
        echo "$source_line" >> "$rc_file"
        echo "  Appended source line to $rc_file"
    else
        echo "  $rc_file already configured, skipping"
    fi
}

case "$(basename "$SHELL")" in
    zsh)  inject_source_line "$HOME/.zshrc"  "$HOME/.config/shell/zshrc"  ;;
    bash) inject_source_line "$HOME/.bashrc" "$HOME/.config/shell/bashrc" ;;
    *)    echo "  Warning: unrecognized shell ($SHELL) — add this to your rc file manually:"
          echo "    source ~/.config/shell/zshrc   # or bashrc" ;;
esac

echo ""
echo "Done! Don't forget to create ~/.gitconfig.local with your personal info:"
echo '  [user]'
echo '      email = you@example.com'
echo '      name = your-name'
