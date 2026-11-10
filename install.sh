#!/usr/bin/env bash
# Usage: install.sh [desktop|server|git]
#   desktop  full workstation: CLI tools, languages, GUI apps
#   server   headless: CLI tools and languages only
#   git      only (re)run the GitHub login and git identity step
# Safe to re-run: every step skips what is already in place.
set -Eeo pipefail
trap 'printf "\n✗ install.sh failed at line %s: %s\n" "$LINENO" "$BASH_COMMAND" >&2' ERR

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
USER="${USER:-$(id -un)}"
export DOTFILES_DIR USER

# shellcheck source=lib/common.sh
. "$DOTFILES_DIR/lib/common.sh"
detect_platform
# So re-runs find what earlier runs installed.
PATH="$LOCAL_BIN:$HOME/.cargo/bin:$HOME/.bun/bin:/usr/local/go/bin:$PATH"
# shellcheck source=lib/macos.sh
. "$DOTFILES_DIR/lib/macos.sh"
# shellcheck source=lib/linux.sh
. "$DOTFILES_DIR/lib/linux.sh"
# shellcheck source=lib/tools.sh
. "$DOTFILES_DIR/lib/tools.sh"
# shellcheck source=lib/git.sh
. "$DOTFILES_DIR/lib/git.sh"

choose_profile() {
    local answer
    printf '%s浮世%s dotfiles · %s/%s\n\n' "$C_PINK" "$C_RESET" "$OS" "$ARCH" >/dev/tty
    printf '  [d] desktop  everything, including GUI apps\n  [s] server   headless CLI only\n\n' >/dev/tty
    read -rp "Install profile [d/s]: " answer </dev/tty
    case "$answer" in
        d | D | desktop) echo desktop ;;
        s | S | server) echo server ;;
        *) die "Pick d or s" ;;
    esac
}

# Keep sudo's timestamp fresh so long installs don't re-prompt.
keep_sudo_alive() {
    [ "$(id -u)" -eq 0 ] && return 0
    sudo -v
    while kill -0 "$$" 2>/dev/null; do
        sudo -n true
        sleep 50
    done 2>/dev/null &
}

main() {
    local profile="${1:-}"
    case "$profile" in
        desktop | server) ;;
        git)
            setup_git_identity
            return
            ;;
        "") profile="$(choose_profile)" ;;
        *) die "Usage: install.sh [desktop|server|git]" ;;
    esac

    # Remembered for `dotfiles update`.
    mkdir -p "$HOME/.config/dotfiles"
    echo "$profile" >"$HOME/.config/dotfiles/profile"

    section "Installing the $profile profile on $OS/$ARCH"
    if [ "$OS" = linux ]; then keep_sudo_alive; fi

    if [ "$OS" = macos ]; then
        macos_install_packages "$profile"
    else
        linux_install_packages "$profile"
    fi

    install_toolchains
    install_cli_apps "$profile"

    if [ "$OS" = macos ]; then
        macos_setup_docker
    else
        linux_setup_docker
        if [ "$profile" = desktop ]; then linux_install_desktop_apps; fi
    fi

    link_configs "$profile"
    generate_completions
    if [ "$OS" = linux ]; then linux_set_login_shell; fi
    ensure_git_identity

    section "Done"
    local n
    for n in "${NOTES[@]}"; do warn "$n"; done
    info "Start a new shell to load everything: exec zsh"
}

main "$@"
