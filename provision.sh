#!/usr/bin/env bash
set -uo pipefail

# =================
# Parameters / env
# =================
KEY_REPEAT="${KEY_REPEAT:-1}"
INITIAL_KEY_REPEAT="${INITIAL_KEY_REPEAT:-10}"
JAMF_ELEVATE_TRIGGER="${JAMF_ELEVATE_TRIGGER:-}"
SKIP_JAMF_ELEVATE="${SKIP_JAMF_ELEVATE:-0}"
GIT_USER_NAME="${GIT_USER_NAME:-}"
GIT_USER_EMAIL="${GIT_USER_EMAIL:-}"

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
    return 0
  fi
  log "Installing Homebrew"
  NONINTERACTIVE=1 /bin/bash -c \
    "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" \
    || log "Homebrew install failed or partially present; continuing"
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
# Jamf elevate
# =================
jamf_self_elevate() {
  [ "$SKIP_JAMF_ELEVATE" = "1" ] && return 0
  local jamf_bin=""
  [ -x "/usr/local/bin/jamf" ] && jamf_bin="/usr/local/bin/jamf"
  [ -x "/usr/bin/jamf" ] && jamf_bin="/usr/bin/jamf"
  [ -z "$jamf_bin" ] && return 0
  [ -z "$JAMF_ELEVATE_TRIGGER" ] && return 0
  log "Attempting Jamf elevation"
  sudo "$jamf_bin" policy -event "$JAMF_ELEVATE_TRIGGER" || true
}

# =================
# Packages / Apps / CLI
# =================
install_packages() {
  log "Updating Homebrew"
  brew update || true

  # CLI essentials
  local cli=(git gnupg gh starship fzf htop wget curl jq bat ripgrep fd tree tldr httpie tmux watch ncdu git-delta the_silver_searcher pyenv tfenv)
  for pkg in "${cli[@]}"; do
    brew_install_formula "$pkg"
  done

  # GUI apps
  # local apps=(docker iterm2 slack firefox google-chrome clipy flux)
  local apps=(docker iterm2 firefox clipy flux 1password 1password-cli tomatobar)
  for app in "${apps[@]}"; do
    brew_install_cask "$app"
  done

  # FluxCD CLI
  if ! brew list --formula flux >/dev/null 2>&1; then
    log "Installing FluxCD CLI"
    try brew tap fluxcd/tap
    try brew install fluxcd/tap/flux
  fi

  # Nerd Fonts
  brew tap homebrew/cask-fonts
  local fonts=(font-fira-code-nerd-font font-jetbrains-mono-nerd-font font-hack-nerd-font)
  for f in "${fonts[@]}"; do
    brew_install_cask "$f"
  done

  # fzf shell integration
  if [ -x "/opt/homebrew/opt/fzf/install" ]; then
    yes | /opt/homebrew/opt/fzf/install --all
  elif [ -x "/usr/local/opt/fzf/install" ]; then
    yes | /usr/local/opt/fzf/install --all
  fi

  brew upgrade || true
  brew cleanup || true
}

# =================
# Git + GPG
# =================
configure_git_gpg() {
  log "Configuring GPG + Git signing"
  have_cmd gpg || return 0

  local key_id
  key_id="$(gpg --list-secret-keys --keyid-format=long 2>/dev/null | awk '/sec/{print $2}' | cut -d/ -f2 | head -n1 || true)"

  if [ -z "$key_id" ]; then
    log "No GPG key found — generating one"
    local name="${GIT_USER_NAME:-$(git config --global user.name || "Git User")}"
    local email="${GIT_USER_EMAIL:-$(git config --global user.email || "user@localhost")}"

    cat > /tmp/gpg-batch <<EOF
Key-Type: RSA
Key-Length: 4096
Subkey-Type: RSA
Subkey-Length: 4096
Name-Real: $name
Name-Email: $email
Expire-Date: 0
%no-protection
%commit
EOF

    gpg --batch --generate-key /tmp/gpg-batch || true
    rm -f /tmp/gpg-batch
    key_id="$(gpg --list-secret-keys --keyid-format=long 2>/dev/null | awk '/sec/{print $2}' | cut -d/ -f2 | head -n1 || true)"
  fi

  [ -z "$key_id" ] && return 0
  log "Using GPG key: $key_id"

  git config --global user.signingkey "$key_id"
  git config --global commit.gpgsign true
  git config --global gpg.program gpg
  git config --global alias.co checkout
  git config --global alias.br branch
  git config --global alias.ci commit
  git config --global alias.st status

  local pubkey
  pubkey="$(gpg --armor --export "$key_id")"

  if have_cmd gh && gh auth status >/dev/null 2>&1; then
    log "Uploading GPG key to GitHub via gh"
    printf "%s\n" "$pubkey" | gh gpg-key add - || true
  else
    log "Opening GitHub GPG key page"
    printf "\n%s\n" "$pubkey"
    open "https://github.com/settings/keys/gpg/new" || true
  fi
}

# =================
# SSH key
# =================
configure_github_ssh() {
  log "Configuring GitHub SSH key"
  local ssh_file="$HOME/.ssh/id_github"
  [ -f "$ssh_file" ] && { log "SSH key already exists: $ssh_file"; return 0; }

  mkdir -p "$HOME/.ssh"
  ssh-keygen -t ed25519 -C "${GIT_USER_EMAIL:-user@localhost}" -f "$ssh_file" -N "" || true

  eval "$(ssh-agent -s)" >/dev/null 2>&1 || true
  ssh-add "$ssh_file" >/dev/null 2>&1 || true

  pbcopy < "${ssh_file}.pub"
  log "SSH public key copied to clipboard"
  open "https://github.com/settings/ssh/new" || true
}

# =================
# Zsh + Starship + Projects
# =================
configure_zsh() {
  log "Configuring Zsh environment"
  local zshrc="$HOME/.zshrc"
  touch "$zshrc"

  grep -q "brew shellenv" "$zshrc" || {
    echo '# Homebrew PATH' >> "$zshrc"
    echo 'if [ -x /opt/homebrew/bin/brew ]; then eval "$(/opt/homebrew/bin/brew shellenv)"; elif [ -x /usr/local/bin/brew ]; then eval "$(/usr/local/bin/brew shellenv)"; fi' >> "$zshrc"
  }

  grep -q "starship init zsh" "$zshrc" || {
    echo '# Starship prompt' >> "$zshrc"
    echo 'eval "$(starship init zsh)"' >> "$zshrc"
  }

  grep -q "HISTSIZE" "$zshrc" || {
    echo '# Infinite history' >> "$zshrc"
    echo 'HISTFILE="$HOME/.zsh_history"'
    echo 'HISTSIZE=1000000'
    echo 'SAVEHIST=1000000'
    echo 'setopt append_history'
    echo 'setopt share_history'
  }

  # Source fzf safely
  local fzf_zsh="$HOME/.fzf.zsh"
  if [ -f "$fzf_zsh" ]; then
    grep -q "fzf.zsh" "$zshrc" || echo "source $fzf_zsh" >> "$zshrc"
  fi

  mkdir -p "$HOME/Projects"
  grep -q "PROJECTS_DIR" "$zshrc" || echo "export PROJECTS_DIR=\$HOME/Projects" >> "$zshrc"

  # pyenv
  grep -q "pyenv init" "$zshrc" || {
    echo '' >> "$zshrc"
    echo '# Pyenv init' >> "$zshrc"
    echo 'export PYENV_ROOT="$HOME/.pyenv"' >> "$zshrc"
    echo 'export PATH="$PYENV_ROOT/bin:$PATH"' >> "$zshrc"
    echo 'eval "$(pyenv init --path)"' >> "$zshrc"
  }

  # tfenv
  grep -q "tfenv" "$zshrc" || {
    echo '' >> "$zshrc"
    echo '# tfenv path' >> "$zshrc"
    echo 'export PATH="$HOME/.tfenv/bin:$PATH"' >> "$zshrc"
  }
}

# =================
# macOS UI Tweaks
# =================
apply_ui_tweaks() {
  log "Applying macOS UI tweaks"

  # Dock
  defaults write com.apple.dock autohide -bool true
  defaults write com.apple.dock autohide-delay -float 0
  defaults write com.apple.dock autohide-time-modifier -float 0.1
  defaults write com.apple.dock mineffect -string "scale"
  defaults write com.apple.dock launchanim -bool false

  # Finder
  defaults write NSGlobalDomain AppleShowAllExtensions -bool true
  defaults write com.apple.finder ShowStatusBar -bool true
  defaults write com.apple.finder ShowPathbar -bool true
  killall Dock
  killall Finder

  # Keyboard
  defaults write NSGlobalDomain KeyRepeat -int "$KEY_REPEAT"
  defaults write NSGlobalDomain InitialKeyRepeat -int "$INITIAL_KEY_REPEAT"

  # Accessibility (sudo)
  sudo sh -c 'defaults write com.apple.universalaccess reduceMotion -bool true'
  sudo sh -c 'defaults write com.apple.universalaccess reduceTransparency -bool true'

  # Trackpad / Mouse
  defaults write com.apple.driver.AppleBluetoothMultitouch.trackpad Clicking -bool true
  defaults write com.apple.driver.AppleBluetoothMultitouch.trackpad TrackpadThreeFingerDrag -bool true
  defaults write NSGlobalDomain com.apple.swipescrolldirection -bool false
  defaults write NSGlobalDomain com.apple.mouse.scaling -float 3.0

  # Screenshot
  mkdir -p "$HOME/Screenshots"
  defaults write com.apple.screencapture location -string "$HOME/Screenshots"
  defaults write com.apple.screencapture disable-shadow -bool true
  killall SystemUIServer

  # Spotlight
  sudo mdutil -i on / >/dev/null 2>&1
  sudo mdutil -E / >/dev/null 2>&1
}

# =================
# iTerm2 config
# =================
configure_iterm2() {
  log "Configuring iTerm2"

  local plist="$HOME/Library/Preferences/com.googlecode.iterm2.plist"
  [ ! -f "$plist" ] && { log "Starting iTerm2 once to generate default preferences"; open -a iTerm; sleep 5; killall iTerm >/dev/null 2>&1; }

  # Light theme
  defaults write com.googlecode.iterm2 "UseDarkColorPalette" -bool false
  # No bell
  defaults write com.googlecode.iterm2 "SilenceBell" -bool true
  # Unlimited scrollback
  defaults write com.googlecode.iterm2 "UnlimitedScrollback" -bool true
  defaults write com.googlecode.iterm2 "ScrollbackLines" -int 1000000

  # Set font properly for default profile
  local default_uuid
  default_uuid=$(defaults read com.googlecode.iterm2 "Default Bookmark Guid" 2>/dev/null)
  [ -n "$default_uuid" ] && /usr/libexec/PlistBuddy -c "Set :'New Bookmarks':0:'Normal Font' 'Fira Code Nerd Font 14'" "$plist" 2>/dev/null || true

  log "iTerm2 configured (restart iTerm2 to apply)"
}

# =================
# Set default apps
# =================
set_default_apps() {
  log "Setting default terminal and browser"

  # Install duti if missing
  have_cmd duti || brew install duti

  # Terminal
  duti -s com.googlecode.iterm2 public.shell-script all
  # Browser
  duti -s com.google.Chrome http
  duti -s com.google.Chrome https
  duti -s com.google.Chrome public.html
}

configure_gh_cli() {
    log "Configuring GitHub CLI"

    # Check if already authenticated
    if gh auth status >/dev/null 2>&1; then
        log "GitHub CLI already logged in"
        return
    fi

    # Try web login interactively
    log "Opening browser for GitHub CLI authentication..."
    gh auth login --web

    gh config set git_protocol ssh

    gh config set editor "zed"
}

# =================
# Main
# =================
main() {
  log "Starting macOS developer provisioning"

  jamf_self_elevate
  ensure_homebrew
  install_packages
  configure_git_gpg
  configure_github_ssh
  configure_zsh
  apply_ui_tweaks
  configure_iterm2
  set_default_apps
  configure_gh_cli

  log "Provisioning complete. Some changes may require logout/login."
}

main "$@"
