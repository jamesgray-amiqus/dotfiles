
if [ -x /opt/homebrew/bin/brew ]; then eval "$(/opt/homebrew/bin/brew shellenv)"; elif [ -x /usr/local/bin/brew ]; then eval "$(/usr/local/bin/brew shellenv)"; fi
eval "$(starship init zsh)"
eval "$(pyenv init --path)"
eval "$(zoxide init zsh)"

export STARSHIP_PROMPT_ORDER=(
  "username"
  "hostname"
  "directory"
  "git_branch"
  "git_state"
  "git_status"
  "cmd_duration"
  "line_break"
  "jobs"
  "time"
  "character"
)

export FZF_CTRL_R_OPTS="--preview 'echo {}'"
export PATH="$HOME/.tfenv/bin:$PATH"
export PATH="$PYENV_ROOT/bin:$PATH"
export PROJECTS_DIR=$HOME/Projects
export PYENV_ROOT="$HOME/.pyenv"
export TMPDIR="$HOME/.tmp"

source ~/.fzf.zsh

alias ....="cd ../../.."
alias ...="cd ../.."
alias ..="cd .."

alias bashly='docker run --rm -it --user $(id -u):$(id -g) --volume "$PWD:/app" dannyben/bashly'
alias c="pbcopy"
alias cat='bat'
alias cls="clear"
alias cp='cp -i'
alias g='git'
alias ga='git add .'
alias gbf='git branch | fzf --preview "git log -n 5 --color=always {}"'
alias gcd='git checkout'
alias gp='git push'
alias gpr='git push --rebase'
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

HISTFILE="$HOME/.zsh_history"
HISTSIZE=1000000
SAVEHIST=1000000
setopt append_history
setopt share_history
setopt extended_glob

mkdir -p "$HOME/.tmp"

gb() {
  local branch
  branch=$(git branch --all | grep -v HEAD | sed 's#remotes/##' | fzf) || return
  git checkout "$branch"
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
