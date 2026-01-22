if [ -f "$HOME/.envrc" ]; then
    source "$HOME/.envrc"
else
    cp ./.envrc.sample "$HOME"
    echo "ERROR: ~/.envrc not found. Please create it with your env variables."
    exit 1
fi

: "${GITHUB_USERNAME:?GITHUB_USERNAME must be set in ~/.envrc}"
: "${GITHUB_ORG:?GITHUB_ORG must be set in ~/.envrc}"
: "${PROJECTS_DIR:?PROJECTS_DIR must be set in ~/.envrc}"
: "${GIT_USER_NAME:?GIT_USER_NAME must be set in ~/.envrc}"
: "${GIT_USER_EMAIL:?GIT_USER_EMAIL must be set in ~/.envrc}"

mkdir -p "$PROJECTS_DIR"

log() { printf "\n==> %s\n" "$*"; }

configure_gh_cli() {
    log "Configuring GitHub CLI..."
    if gh auth status >/dev/null 2>&1; then
        log "Already logged in"
    else
        log "Logging in via web..."
        gh auth login --web
    fi

    gh config set git_protocol ssh
    gh config set editor "zed"
}

configure_github_ssh() {
    log "Configuring GitHub SSH key..."
    local ssh_file="$HOME/.ssh/id_github"
    if [ -f "$ssh_file" ]; then
        log "SSH key already exists: $ssh_file"
    else
        ssh-keygen -t ed25519 -C "$GIT_USER_EMAIL" -f "$ssh_file" -N "" || true
        eval "$(ssh-agent -s)" >/dev/null 2>&1 || true
        ssh-add "$ssh_file" >/dev/null 2>&1 || true
        pbcopy < "${ssh_file}.pub"
        log "SSH public key copied to clipboard. Add it to GitHub: https://github.com/settings/new"
    fi
}

configure_git_gpg() {
    log "Configuring GPG for signed commits..."
    have_gpg=$(command -v gpg || true)
    [ -z "$have_gpg" ] && { log "GPG not installed, skipping"; return; }

    local key_id
    key_id="$(gpg --list-secret-keys --keyid-format=long 2>/dev/null | awk '/sec/{print $2}' | cut -d/ -f2 | head -n1 || true)"

    if [ -z "$key_id" ]; then
        log "No GPG key found — generating one"
        cat > /tmp/gpg-batch <<EOF
Key-Type: RSA
Key-Length: 4096
Subkey-Type: RSA
Subkey-Length: 4096
Name-Real: $GIT_USER_NAME
Name-Email: $GIT_USER_EMAIL
Expire-Date: 0
%no-protection
%commit
EOF
        gpg --batch --generate-key /tmp/gpg-batch || true
        rm -f /tmp/gpg-batch
        key_id="$(gpg --list-secret-keys --keyid-format=long 2>/dev/null | awk '/sec/{print $2}' | cut -d/ -f2 | head -n1 || true)"
    fi

    [ -z "$key_id" ] && return

    git config --global user.signingkey "$key_id"
    git config --global commit.gpgsign true
    git config --global gpg.program gpg
    log "Using GPG key: $key_id"

    git config --global alias.co checkout
    git config --global alias.br branch
    git config --global alias.ci commit
    git config --global alias.st status

    if gh auth status >/dev/null 2>&1; then
        printf "%s\n" "$(gpg --armor --export "$key_id")" | gh gpg-key add - || true
        log "Uploaded GPG key to GitHub"
    else
        log "Open GitHub GPG key page to add key manually"
        open "https://github.com/settings/keys/gpg/new"
    fi
}

clone_github_repos() {
    log "Cloning repositories into $PROJECTS_DIR..."

    clone_repos_from() {
        local owner="$1"
        local repos
        repos=$(gh repo list "$owner" --limit 1000 --json nameWithOwner -q '.[].nameWithOwner')
        for repo in $repos; do
            log "Cloning $repo..."
            local dir="$PROJECTS_DIR/$(basename "$repo")"
            if [ -d "$dir/.git" ]; then
                log "Already cloned: $repo"
            else
                gh repo clone "$repo" "$dir" || log "Failed to clone: $repo"
            fi
        done
    }

    clone_repos_from "$GITHUB_USERNAME"
    clone_repos_from "$GITHUB_ORG"
}

main() {
    log "Starting GitHub setup + repo cloning"
    configure_gh_cli
    configure_github_ssh
    configure_git_gpg
    clone_github_repos
    log "GitHub setup and cloning complete!"
}

main "$@"
