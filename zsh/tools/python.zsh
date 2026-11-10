# Python via uv
(( $+commands[uv] )) || return 0

# Create a .venv in the current project and activate it.
venv() {
  [[ -d .venv ]] || uv venv || return
  source .venv/bin/activate
}
