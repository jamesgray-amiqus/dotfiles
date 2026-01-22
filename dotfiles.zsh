if [ -x /opt/homebrew/bin/brew ]; then eval "$(/opt/homebrew/bin/brew shellenv)"; elif [ -x /usr/local/bin/brew ]; then eval "$(/usr/local/bin/brew shellenv)"; fi

eval "$(starship init zsh)"

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

source ~/.fzf.zsh
export PROJECTS_DIR=$HOME/Projects

export PYENV_ROOT="$HOME/.pyenv"
export PATH="$PYENV_ROOT/bin:$PATH"
eval "$(pyenv init --path)"

export PATH="$HOME/.tfenv/bin:$PATH"

eval "$(zoxide init zsh)"

source ~/.fzf.zsh

alias ..="cd .."
alias ...="cd ../.."
alias ....="cd ../../.."
alias ll="ls -lhG"
alias la="ls -AhG"
alias cls="clear"
alias ls='ls --color=always'
alias g='git'
alias gs='git status'
alias gcd='git checkout'
alias ga='git add .'
alias gp='git push'
alias gpr='git push --rebase'
alias bashly='docker run --rm -it --user $(id -u):$(id -g) --volume "$PWD:/app" dannyben/bashly'
alias gbf='git branch | fzf --preview "git log -n 5 --color=always {}"'

HISTFILE="$HOME/.zsh_history"
HISTSIZE=1000000
SAVEHIST=1000000
setopt append_history
setopt share_history

setopt extended_glob
alias rm='rm -i'
alias mv='mv -i'
alias cp='cp -i'

alias c="pbcopy"
alias p="pbpaste"

alias meminfo="top -l 1 | head -n 20"
alias ip="ipconfig getifaddr en0"
