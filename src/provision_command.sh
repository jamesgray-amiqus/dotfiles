#!/usr/bin/env bash
set -uo pipefail

# =================
# Load environment
# =================
if [ -f "$HOME/.envrc" ]; then
  source "$HOME/.envrc"
else
  echo "ERROR: ~/.envrc not found. Please create it with your env variables."
  exit 1
fi

: "${GITHUB_ORG:?GITHUB_ORG must be set in ~/.envrc}"
: "${GITHUB_USERNAME:?GITHUB_USERNAME must be set in ~/.envrc}"
: "${NODE_VERSION:?NODE_VERSION must be set in ~/.envrc}"
: "${PROJECTS_DIR:?PROJECTS_DIR must be set in ~/.envrc}"
: "${PYTHON_VERSION:?PYTHON_VERSION must be set in ~/.envrc}"
: "${RUBY_VERSION:?RUBY_VERSION must be set in ~/.envrc}"
: "${TF_VERSION:?TF_VERSION must be set in ~/.envrc}"

mkdir -p "$PROJECTS_DIR"

# =================
# Helpers
# =================
log() { printf "\n==> %s\n" "$*"; }
have_cmd() { command -v "$1" >/dev/null 2>&1; }
try() { "$@" || log "Non-fatal failure: $*"; }

brew_shellenv() {
  if [ -x "/opt/homebrew/bin/brew" ]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
  elif [ -x "/usr/local/bin/brew" ]; then
    eval "$(/usr/local/bin/brew shellenv)"
  fi
}

# =================
# Homebrew
# =================
ensure_homebrew() {
  if have_cmd brew; then
    log "Homebrew already installed"
    brew_shellenv
    return
  fi
  log "Installing Homebrew"
  NONINTERACTIVE=1 /bin/bash -c \
    "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" ||
    log "Homebrew install failed; continuing"
  brew_shellenv
}

brew_install_formula() {
  local pkg="$1"
  if brew list --formula "$pkg" >/dev/null 2>&1; then
    log "Formula already installed: $pkg"
  else
    log "Installing formula: $pkg"
    try brew install "$pkg"
  fi
}

brew_install_cask() {
  local cask="$1"
  if brew list --cask "$cask" >/dev/null 2>&1; then
    log "Cask already installed: $cask"
  else
    log "Installing cask: $cask"
    try brew install --cask "$cask"
  fi
}

# =================
# Packages / Apps
# =================
install_packages() {
  log "Updating Homebrew"
  brew update || true

  log "Upgrading Homebrew"
  brew upgrade || true

  local cli=(
    ack awscli bat ccal croc curl espanso fd fzf gh git git-branchless git-delta git-extras gnupg gum
    htop httpie jq ncdu nvm lazygit pyenv ripgrep shellcheck starship tfenv
    the_silver_searcher tig tldr tmux tree watch wget yamlfmt zoxide
  )
  for pkg in "${cli[@]}"; do brew_install_formula "$pkg"; done

  local apps=(
    1password-cli clipy docker firefox flux iterm2
    session-manager-plugin tomatobar
  )
  for app in "${apps[@]}"; do brew_install_cask "$app"; done

  # FluxCD CLI
  if ! brew list --formula flux >/dev/null 2>&1; then
    log "Installing FluxCD CLI"
    try brew tap fluxcd/tap
    try brew install fluxcd/tap/flux
  fi

  # Nerd Fonts
  local fonts=(font-fira-code-nerd-font font-jetbrains-mono-nerd-font font-hack-nerd-font)
  for f in "${fonts[@]}"; do brew_install_cask "$f"; done

  # fzf shell integration
  local fzf_install_path
  fzf_install_path="$(brew --prefix)/opt/fzf/install"
  [ -x "$fzf_install_path" ] && yes | "$fzf_install_path" --all

  brew upgrade || true
  brew cleanup || true
}

# =================
# Zsh + env
# =================
configure_zsh() {
  log "Configuring Zsh environment"
  cat <<EOF >"$HOME/.zprofile"
eval "$(/opt/homebrew/bin/brew shellenv)"

if [ -f "$HOME/.zshrc" ]; then
  source "$HOME/.zshrc"
fi
EOF

  cat <<EOF >"$HOME/.zshrc"
source "$PROJECTS_DIR/$GITHUB_USERNAME/dotfiles/dotfiles.zsh"
EOF
}

# =================
# iTerm2 config from exported JSON
# =================
configure_iterm2() {
  log "Configuring iTerm2 from exported JSON"

  local json_file="$PROJECTS_DIR/dotfiles/iterm2_profile.json"
  if [ -f "$json_file" ]; then
    log "Importing iTerm2 profile from JSON"
    open "$json_file" # iTerm will import it automatically
    sleep 3
  else
    log "No exported iTerm2 JSON found, skipping"
  fi
}

# =================
# GitHub CLI + repos
# =================
configure_gh_cli() {
  log "Configuring GitHub CLI"
  if ! gh auth status >/dev/null 2>&1; then
    gh auth login --web
  fi
  gh config set git_protocol ssh
  gh config set editor zed

  # Clone all repos for user/org
  (
    cd "$PROJECTS_DIR"
    for repo in $(gh repo list "$GITHUB_USERNAME" --limit 1000 --json nameWithOwner -q '.[].nameWithOwner'); do
      log "Cloning $repo..."
      gh repo clone "$repo" || log "Already exists or failed: $repo"
    done
    for repo in $(gh repo list "$GITHUB_ORG" --limit 1000 --json nameWithOwner -q '.[].nameWithOwner'); do
      log "Cloning $repo..."
      gh repo clone "$repo" || log "Already exists or failed: $repo"
    done
  )
}

# =================
# Ruby / Terraform / Node / Python
# =================
install_nvm() { nvm install "$NODE_VERSION" && nvm use "$NODE_VERSION" || true; }
install_pyenv() { pyenv install "$PYTHON_VERSION" && pyenv global "$PYTHON_VERSION" || true
install_rbenv() { rbenv install "$RUBY_VERSION" && rbenv global "$RUBY_VERSION" || true; }
install_tfenv() { tfenv install "$TF_VERSION" && tfenv use "$TF_VERSION" || true; }

# =================
# Main
# =================
main() {
  log "Starting macOS developer provisioning"
  ensure_homebrew
  install_packages
  configure_zsh
  configure_iterm2
  configure_gh_cli
  install_rbenv
  install_tfenv
  install_nvm
  install_pyenv
  log "Provisioning complete. Open a new terminal tab to apply Zsh & iTerm2 settings."
}

main "$@"
