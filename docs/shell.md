# Shell

The shared zsh config lives in `zsh/zshrc` and is sourced from the first line of `~/.zshrc`. If it is sourced from another shell, it prints “This config needs zsh. Run: exec zsh” and stops.

## What it sets up

- **Paths:** `~/.local/bin` goes first on `PATH`, and `~/.local/share/zsh/site-functions` is added to `fpath`. Homebrew’s environment is loaded if Homebrew is found.
- **Editor:** `zed --wait` when Zed is installed and you are not in an SSH session; otherwise `vim`. `VISUAL` matches.
- **History:** 100,000 entries in `~/.local/state/zsh/history`, shared between sessions, with duplicates removed. The up and down arrows search history by what you have typed so far.
- **Directories:** `auto_cd` and `auto_pushd` are on.
- **Completion:** the cache is rebuilt at most once a day, matching is case-insensitive, and there is a selectable menu.
- **fzf** key bindings and completion, and **zoxide** (which replaces `cd`), when installed.
- **Plugins:** zsh-autosuggestions and zsh-syntax-highlighting, loaded last, from Homebrew’s `share` directory or `/usr/share`.
- **Prompt:** starship, when installed.

## Aliases

| Alias | What it does |
| :--- | :--- |
| `home`, `..`, `...`, `....` | Change directory |
| `cl` | Clear the screen |
| `reload` | `exec zsh` |
| `ls`, `ll`, `la`, `lt` | eza listings (`lt` is a tree two levels deep); only when eza is installed |
| `cat` | `bat` without paging or decoration; only when bat is installed |
| `fzfp` | fzf with a bat preview; only when bat is installed |
| `lg` | lazygit |
| `chrome` | Opens Google Chrome (macOS only) |

## Functions

| Function | What it does |
| :--- | :--- |
| `lanip` | Prints this machine’s LAN IP |
| `aliases` | Fuzzy-finds an alias with fzf and puts it on the command line |
| `dotfiles update` | Updates the dotfiles; see [Updating](updating.md) |

## Per-tool files

Each file in `zsh/tools/` configures one tool and returns immediately if that tool is not installed, so a server without a tool is not affected. New files in that folder are picked up automatically.

| File | What it does |
| :--- | :--- |
| `bun.zsh` | Adds `~/.bun/bin` to `PATH` and Bun’s completions |
| `docker.zsh` | Aliases `d`, `dps`, `dc`, `dcu`, `dcd`, `lzd`, and `dstop` to stop all running containers |
| `go.zsh` | Adds Go and `$GOPATH/bin` (default `~/go`) to `PATH` |
| `kubernetes.zsh` | Sets `KUBECONFIG`, adds `k`, `ka`, `ke`, `kg`, `kd`, `kgpo`, `kgd`, `kgs`, `kgpow`, `kl`, `kdel`, `kc`, `kns`, and the fzf helpers `kdelp` (delete pods after confirming), `klp` and `klns` (follow a pod’s logs) |
| `node.zsh` | Loads nvm and its completion |
| `python.zsh` | The `venv` function creates a `.venv` with uv if needed and activates it |
| `rust.zsh` | Adds `~/.cargo/bin` to `PATH` |

Zsh files here are sourced before `compinit`, so a tool file may extend `fpath`.

## Prompt

The shared starship prompt is a two-line prompt in a Tokyo-inspired “ukiyo” palette. A red stamp character appears only over SSH, so a server prompt is easy to tell apart. See `starship/starship.toml` for the full configuration, and [Customizing](customizing.md) to replace it.
