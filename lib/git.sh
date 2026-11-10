# shellcheck shell=bash
# Git identity from the GitHub account: gh login, SSH key for auth + commit signing.

# Written below the managed include, so these are the user's own settings.
GIT_USER_CONFIG="$HOME/.gitconfig"
SSH_KEY="$HOME/.ssh/id_ed25519"
ALLOWED_SIGNERS="$HOME/.config/git/allowed_signers"
GH_SCOPES=(admin:public_key admin:ssh_signing_key user:email)

gh_missing_scopes() {
    local granted scope
    granted="$(gh api -i user 2>/dev/null | tr -d '\r' | grep -i '^x-oauth-scopes:')"
    for scope in "${GH_SCOPES[@]}"; do
        case "$granted" in *"$scope"*) ;; *) echo "$scope" ;; esac
    done
}

gh_login() {
    local scopes
    scopes="$(
        IFS=,
        echo "${GH_SCOPES[*]}"
    )"
    if ! gh auth status -h github.com >/dev/null 2>&1; then
        info "Log in to GitHub (a browser opens, or use the code shown at github.com/login/device)"
        gh auth login -h github.com -p ssh -w --skip-ssh-key -s "$scopes" </dev/tty
    elif [ -n "$(gh_missing_scopes)" ]; then
        info "Granting gh the key and email scopes"
        gh auth refresh -h github.com -s "$scopes" </dev/tty
    fi
}

# Upload the public key as the given type unless GitHub already has it.
gh_upload_key() {
    local type="$1" endpoint pub
    [ "$type" = signing ] && endpoint=user/ssh_signing_keys || endpoint=user/keys
    pub="$(cut -d' ' -f1,2 "$SSH_KEY.pub")"
    if gh api "$endpoint" --paginate --jq '.[].key' | grep -xF "$pub" >/dev/null; then
        skip "SSH key already on GitHub ($type)"
    else
        gh ssh-key add "$SSH_KEY.pub" --type "$type" --title "$(hostname -s)" >/dev/null
        ok "SSH key added to GitHub ($type)"
    fi
}

setup_git_identity() {
    section "Git identity (GitHub)"

    if ! { : </dev/tty; } 2>/dev/null; then
        note "No terminal for GitHub login; run '~/.dotfiles/install.sh git' later"
        return 0
    fi
    gh_login || {
        note "GitHub login skipped; run '~/.dotfiles/install.sh git' later"
        return 0
    }

    local id login name email
    IFS=$'\t' read -r id login name < <(gh api user --jq '[.id, .login, (.name // "")] | @tsv')
    name="${name:-$login}"
    email="$id+$login@users.noreply.github.com"

    # One key per machine, used for both pushing and signing.
    if [ ! -f "$SSH_KEY" ]; then
        info "Creating $SSH_KEY (enter a passphrase, or leave empty)"
        mkdir -p "$HOME/.ssh" && chmod 0700 "$HOME/.ssh"
        ssh-keygen -q -t ed25519 -C "$login@$(hostname -s)" -f "$SSH_KEY" </dev/tty
    fi
    gh_upload_key authentication
    gh_upload_key signing

    if ! ssh-keygen -F github.com >/dev/null 2>&1; then
        ssh-keyscan -t ed25519 github.com 2>/dev/null >>"$HOME/.ssh/known_hosts"
    fi

    local cfg=(git config --file "$GIT_USER_CONFIG")
    touch "$GIT_USER_CONFIG"
    "${cfg[@]}" user.name "$name"
    "${cfg[@]}" user.email "$email"
    "${cfg[@]}" user.signingkey "$SSH_KEY.pub"
    "${cfg[@]}" gpg.format ssh
    "${cfg[@]}" gpg.ssh.allowedSignersFile "$ALLOWED_SIGNERS"
    "${cfg[@]}" commit.gpgsign true
    "${cfg[@]}" tag.gpgsign true
    # gh as the HTTPS credential helper (the empty entry clears inherited helpers).
    local host
    for host in https://github.com https://gist.github.com; do
        "${cfg[@]}" --unset-all "credential.$host.helper" 2>/dev/null || true
        "${cfg[@]}" --add "credential.$host.helper" ''
        "${cfg[@]}" --add "credential.$host.helper" '!gh auth git-credential'
    done

    # Lets `git log --show-signature` verify this machine's own commits.
    local signer
    signer="$email namespaces=\"git\" $(cut -d' ' -f1,2 "$SSH_KEY.pub")"
    mkdir -p "$(dirname "$ALLOWED_SIGNERS")"
    touch "$ALLOWED_SIGNERS"
    grep -qxF "$signer" "$ALLOWED_SIGNERS" || echo "$signer" >>"$ALLOWED_SIGNERS"

    ok "Git: $name <$email>, commits signed with $SSH_KEY"
}

# Normal installs leave an existing identity alone, so re-running never undoes a
# user's own git settings. `install.sh git` re-syncs from GitHub on purpose.
ensure_git_identity() {
    if [ -n "$(git config --file "$GIT_USER_CONFIG" user.email 2>/dev/null)" ]; then
        section "Git identity (GitHub)"
        skip "Already set in ~/.gitconfig; run '~/.dotfiles/install.sh git' to re-sync from GitHub"
        return 0
    fi
    setup_git_identity
}
