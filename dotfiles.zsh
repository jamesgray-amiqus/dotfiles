# -----------------------------------------
# Homebrew
# -----------------------------------------
if [ -x /opt/homebrew/bin/brew ]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
elif [ -x /usr/local/bin/brew ]; then
    eval "$(/usr/local/bin/brew shellenv)"
fi

# -----------------------------------------
# Prompt & language tools
# -----------------------------------------
eval "$(starship init zsh)"
eval "$(pyenv init --path)"
eval "$(zoxide init zsh --hook prompt)"   # use prompt hook, not 'complete'
eval "$(zoxide init zsh)"
eval "$(direnv hook zsh)"

# -----------------------------------------
# Zsh completions
# -----------------------------------------
autoload -Uz compinit
compinit
zstyle ':compinstall' auto-update no

# -----------------------------------------
# Environment variables
# -----------------------------------------
export PATH="$HOME/.tfenv/bin:$PATH"
export PATH="$PYENV_ROOT/bin:$PATH"
export PATH="$HOME/Projects/amiqus/dev-scripts:$PATH"
export PYENV_ROOT="$HOME/.pyenv"
export TMPDIR="$HOME/.tmp"
export PROJECTS_DIR=~/Projects
export PROJECTS_CACHE=~/.cache/projects_list.txt

mkdir -p "$HOME/.tmp"
mkdir -p ~/.cache

# -----------------------------------------
# Source fzf if installed
# -----------------------------------------
[ -f ~/.fzf.zsh ] && source ~/.fzf.zsh

# -----------------------------------------
# Environment file
# -----------------------------------------
if [ -f "$HOME/.envrc" ]; then
    source "$HOME/.envrc"
else
    cp ./.envrc.sample "$HOME"
    echo "ERROR: ~/.envrc not found. Please create it with your env variables."
    exit 1
fi

# -----------------------------------------
# Aliases
# -----------------------------------------
alias ....="cd ../../.."
alias ...="cd ../.."
alias ..="cd .."
alias bashly='docker run --rm -it --user $(id -u):$(id -g) --volume "$PWD:/app" dannyben/bashly'
alias bg='bashly generate'
alias c="pbcopy"
alias cat='bat'
alias c='bat'
alias d='bat -p'
alias cls="clear"
alias cp='cp -i'
alias g='git'
alias ga='git add .'
alias gbf='git branch | fzf --preview "git log -n 5 --color=always {}"'
alias gcd='git checkout'
alias gd='git diff'
alias gp='git push'
alias gpr='git pull --rebase'
alias gpt='git push --tags'
alias gs='git status'
alias ip="ipconfig getifaddr en0"
alias la="ls -AhG"
alias ll="ls -lhG"
alias ls='ls --color=always'
alias meminfo="top -l 1 | head -n 20"
alias mv='mv -i'
alias p="pbpaste"
alias rm='rm -i'
alias sc='shellcheck'
alias superlint='docker run --rm \
  -e RUN_LOCAL=true \
  -e USE_FIND_ALGORITHM=true \
  -v "$(pwd):/tmp/lint" \
  github/super-linter:latest'

export NVM_DIR="$HOME/.nvm"
[ -s "/opt/homebrew/opt/nvm/nvm.sh" ] && \
    source "/opt/homebrew/opt/nvm/nvm.sh"
[ -s "/opt/homebrew/opt/nvm/etc/bash_completion.d/nvm" ] && \
    source "/opt/homebrew/opt/nvm/etc/bash_completion.d/nvm"

# -----------------------------------------
# History settings
# -----------------------------------------
HISTFILE="$HOME/.zsh_history"
HISTSIZE=1000000
SAVEHIST=1000000
setopt append_history
setopt share_history
setopt extended_glob

# -----------------------------------------
# Git helper functions
# -----------------------------------------
gb() {
  # Fetch latest remotes
  git fetch --all --prune

  # List local + remote branches, remove duplicates
  local branch selected
  branch=$(git for-each-ref --format='%(refname:short)' refs/heads/ \
          && git for-each-ref --format='%(refname:short)' refs/remotes/origin/ \
             | sed 's#^origin/##' \
             | grep -v -F -f <(git for-each-ref --format='%(refname:short)' refs/heads/)) || return

  # Let user select with fzf
  selected=$(echo "$branch" | fzf --prompt="Branch> ") || return
  [ -z "$selected" ] && return

  # Switch to local branch if exists, else track remote
  if git show-ref --verify --quiet "refs/heads/$selected"; then
    git switch "$selected"
  else
    git switch -c "$selected" --track "origin/$selected"
  fi
}

scf() {
  local file
  file=$(git ls-files '*.sh' | fzf) || return
  shellcheck "$file"
}

sc-changed() {
  git diff --name-only --diff-filter=ACM \
    | grep '\.sh$' \
    | xargs -r shellcheck
}

# -----------------------------------------
# Projects jump function (fuzzy with fzf)
# -----------------------------------------
update_projects_cache() {
  find "$PROJECTS_DIR" -maxdepth 2 -type d > "$PROJECTS_CACHE"
}

# Initialize cache if missing
[ ! -f "$PROJECTS_CACHE" ] && update_projects_cache

r() {
  if [ -z "$1" ]; then
    # No argument: just open fuzzy menu
    local dir
    dir=$(cat "$PROJECTS_CACHE" | fzf --preview "ls -l {}" --prompt="Project> ")
    [ -n "$dir" ] && cd "$dir"
    return
  fi

  # Argument provided: try exact match first, then fuzzy
  local dir
  dir=$(grep -i "$1" "$PROJECTS_CACHE" | head -n 1)
  if [ -n "$dir" ]; then
    cd "$dir" || return
  else
    # fallback to fzf fuzzy search if no exact match
    dir=$(grep -i "$1" "$PROJECTS_CACHE" | fzf --preview "ls -l {}" --prompt="Project> ")
    [ -n "$dir" ] && cd "$dir"
  fi
}

pr() {
    local branch="${1:-$(git symbolic-ref --short HEAD)}"
    local default_branch=$(git remote show origin | awk '/HEAD branch/ {print $NF}')
    gh pr create --web --base "$default_branch" --head "$branch"
}

# Optional: bind Ctrl-P to fuzzy project jump
fzf-project-jump() {
  local dir=$(cat "$PROJECTS_CACHE" | fzf --preview "ls -l {}" --prompt="Project> ")
  [ -n "$dir" ] && cd "$dir"
}
bindkey '^P' fzf-project-jump

_r_completions() {
  local -a projects
  local cur

  cur="${words[CURRENT]}"
  # extract last directory name from cache
  projects=($(awk -F/ '{print $NF}' "$PROJECTS_CACHE"))

  # Use compadd to provide completions
  compadd -W projects -- "$cur"
}

# Attach tab-completion to r
compdef _r_completions r

# -----------------------------------------
# End of config
# -----------------------------------------
