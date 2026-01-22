if [ -f "$HOME/.envrc" ]; then
    cp ./.envrc.sample "$HOME"
    source "$HOME/.envrc"
else
    echo "ERROR: ~/.envrc not found. Please create it with your env variables."
    exit 1
fi

: "${PROJECTS_DIR:?PROJECTS_DIR must be set in ~/.envrc}"

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

ensure_homebrew() {
    if have_cmd brew; then
        log "Homebrew already installed"
        brew_shellenv
        return
    fi
    log "Installing Homebrew"
    NONINTERACTIVE=1 /bin/bash -c \
        "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" \
        || log "Homebrew install failed; continuing"
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

jamf_self_elevate() {
    [ "${SKIP_JAMF_ELEVATE:-0}" = "1" ] && return
    local jamf_bin=""
    [ -x "/usr/local/bin/jamf" ] && jamf_bin="/usr/local/bin/jamf"
    [ -x "/usr/bin/jamf" ] && jamf_bin="/usr/bin/jamf"
    [ -z "$jamf_bin" ] && return
    [ -z "${JAMF_ELEVATE_TRIGGER:-}" ] && return
    log "Attempting Jamf elevation"
    sudo "$jamf_bin" policy -event "$JAMF_ELEVATE_TRIGGER" || true
}


install_packages() {
    log "Updating Homebrew"
    brew update || true

    local cli=(git gnupg gh starship fzf htop wget curl jq bat ripgrep fd tree tldr httpie tmux watch ncdu git-delta the_silver_searcher pyenv tfenv zoxide gum awscli)
    for pkg in "${cli[@]}"; do
        brew_install_formula "$pkg"
    done

    local apps=(docker iterm2 firefox clipy flux 1password-cli tomatobar session-manager-plugin)
    for app in "${apps[@]}"; do
        brew_install_cask "$app"
    done

    if ! brew list --formula flux >/dev/null 2>&1; then
        log "Installing FluxCD CLI"
        try brew tap fluxcd/tap
        try brew install fluxcd/tap/flux
    fi

    local fonts=(font-fira-code-nerd-font font-jetbrains-mono-nerd-font font-hack-nerd-font)
    for f in "${fonts[@]}"; do
        brew_install_cask "$f"
    done

    local fzf_install_path
    fzf_install_path="$(brew --prefix)/opt/fzf/install"
    [ -x "$fzf_install_path" ] && yes | "$fzf_install_path" --all

    brew upgrade || true
    brew cleanup || true
}

configure_zsh() {
    log "Configuring Zsh environment"
    touch "$HOME/.zshrc"
    cat <<EOF > "$HOME/.zshrc"
source "$PROJECTS_DIR/dotfiles/dotfiles.zsh"
EOF
}

apply_ui_tweaks() {
    log "Applying macOS UI tweaks"

    defaults delete com.apple.dock autohide 2>/dev/null || true
    defaults delete com.apple.dock autohide-delay 2>/dev/null || true
    defaults delete com.apple.dock autohide-time-modifier 2>/dev/null || true
    defaults delete com.apple.dock mineffect 2>/dev/null || true
    defaults delete com.apple.dock launchanim 2>/dev/null || true
    defaults delete com.apple.dock expose-animation-duration 2>/dev/null || true
    defaults write NSGlobalDomain AppleShowAllExtensions -bool true
    defaults write com.apple.finder ShowStatusBar -bool true
    defaults write com.apple.finder ShowPathbar -bool true
    killall Dock Finder

    defaults write NSGlobalDomain KeyRepeat -int "${KEY_REPEAT:-1}"
    defaults write NSGlobalDomain InitialKeyRepeat -int "${INITIAL_KEY_REPEAT:-10}"

    sudo defaults write com.apple.universalaccess reduceMotion -bool true || true
    sudo defaults write com.apple.universalaccess reduceTransparency -bool true || true

    defaults write com.apple.driver.AppleBluetoothMultitouch.trackpad Clicking -bool true
    defaults write com.apple.driver.AppleBluetoothMultitouch.trackpad TrackpadThreeFingerDrag -bool true
    defaults write NSGlobalDomain com.apple.swipescrolldirection -bool false
    defaults write NSGlobalDomain com.apple.mouse.scaling -float 3.0

    mkdir -p "$HOME/Screenshots"
    defaults write com.apple.screencapture location -string "$HOME/Screenshots"
    defaults write com.apple.screencapture disable-shadow -bool true
    killall SystemUIServer

    sudo mdutil -i on / >/dev/null 2>&1 || true
    sudo mdutil -E / >/dev/null 2>&1 || true
}

configure_iterm2() {
    log "Configuring iTerm2"

    local plist="$HOME/Library/Preferences/com.googlecode.iterm2.plist"
    [ ! -f "$plist" ] && { open -a iTerm; sleep 5; killall iTerm >/dev/null 2>&1; }

    defaults write com.googlecode.iterm2 "UseDarkColorPalette" -bool false
    defaults write com.googlecode.iterm2 "SilenceBell" -bool true
    defaults write com.googlecode.iterm2 "UnlimitedScrollback" -bool true
    defaults write com.googlecode.iterm2 "ScrollbackLines" -int 1000000

    local default_uuid
    default_uuid=$(defaults read com.googlecode.iterm2 "Default Bookmark Guid" 2>/dev/null)
    [ -n "$default_uuid" ] && /usr/libexec/PlistBuddy -c "Set :'New Bookmarks':0:'Normal Font' 'Fira Code Nerd Font 14'" "$plist" 2>/dev/null || true
}

set_default_apps() {
    log "Setting default terminal and browser"
    have_cmd duti || brew install duti
    duti -s com.googlecode.iterm2 public.shell-script all
    duti -s com.google.Chrome http
    duti -s com.google.Chrome https
    duti -s com.google.Chrome public.html
}

install_rbenv() { rbenv install 3.4.8 && rbenv global 3.4.8 || true; }
install_tfenv() { tfenv install 1.14.3 && tfenv use 1.14.3 || true; }

main() {
    log "Starting macOS developer provisioning"
    jamf_self_elevate
    ensure_homebrew
    install_packages
    configure_zsh
    apply_ui_tweaks
    configure_iterm2
    set_default_apps
    install_rbenv
    install_tfenv
    log "Provisioning complete. Some changes may require logout/login."
}

main "$@"
