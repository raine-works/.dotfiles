# Git identity

The last installer step logs in with `gh` and sets up git from your GitHub account.

## What it does

1. Logs in to GitHub with `gh auth login` (a browser opens, or you use the code shown at github.com/login/device). If you are already logged in but `gh` lacks the needed scopes (`admin:public_key`, `admin:ssh_signing_key`, `user:email`), it asks for them.
2. Sets `user.name` from your GitHub profile (falling back to your login) and `user.email` to your GitHub noreply address.
3. Creates `~/.ssh/id_ed25519` if it does not exist, asking for a passphrase (leave it empty for none). One key per machine, used for both pushing and signing.
4. Uploads the public key to GitHub as an authentication key and as a signing key, unless GitHub already has it. The key’s title is the machine’s short hostname.
5. Adds `github.com` to `~/.ssh/known_hosts` if it is missing.
6. Turns on commit and tag signing with that key (`gpg.format = ssh`, `commit.gpgsign`, `tag.gpgsign`).
7. Sets `gh` as the HTTPS credential helper for github.com and gist.github.com.
8. Records the key in `~/.config/git/allowed_signers` so `git log --show-signature` verifies your commits.

Everything is written to your own `~/.gitconfig`, never to the repository.

## When it runs

A normal install or update runs this step only if `user.email` is not yet set. Once an identity exists, later runs leave it alone. To run it again, and re-sync from GitHub:

```bash
~/.dotfiles/install.sh git
```

If there is no terminal for the login, or you skip it, the installer warns and tells you to run that command later.
