# Rust — rustup/Cargo PATH
if [ -s "$HOME/.cargo/env" ]; then
	. "$HOME/.cargo/env"
elif [ -d "$HOME/.cargo/bin" ]; then
	case ":$PATH:" in
		*":$HOME/.cargo/bin:"*) ;;
		*) export PATH="$HOME/.cargo/bin:$PATH" ;;
	esac
fi
