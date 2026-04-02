# shellcheck shell=bash
# Rust — rustup/Cargo PATH
command -v rustc >/dev/null 2>&1 || command -v cargo >/dev/null 2>&1 || [ -s "$HOME/.cargo/env" ] || [ -d "$HOME/.cargo/bin" ] || return 0

if [ -s "$HOME/.cargo/env" ]; then
    # shellcheck source=/dev/null
    . "$HOME/.cargo/env"
elif [ -d "$HOME/.cargo/bin" ]; then
    case ":$PATH:" in
        *":$HOME/.cargo/bin:"*) ;;
        *) export PATH="$HOME/.cargo/bin:$PATH" ;;
    esac
fi
