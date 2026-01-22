if [ -x /opt/homebrew/bin/brew ]; then eval "$(/opt/homebrew/bin/brew shellenv)"; elif [ -x /usr/local/bin/brew ]; then eval "$(/usr/local/bin/brew shellenv)"; fi

# Starship prompt
eval "$(starship init zsh)"
# Infinite history
HISTFILE="$HOME/.zsh_history"
HISTSIZE=1000000
SAVEHIST=1000000
setopt append_history
setopt share_history
source ~/.fzf.zsh
export PROJECTS_DIR=$HOME/Projects

# Pyenv initialization
export PYENV_ROOT="$HOME/.pyenv"
export PATH="$PYENV_ROOT/bin:$PATH"
eval "$(pyenv init --path)"

# tfenv path
export PATH="$HOME/.tfenv/bin:$PATH"

eval "$(zoxide init zsh)"

source ~/.fzf.zsh

alias ls='ls --color=always'
alias g='git'
alias gs='git status'
alias gcd='git checkout'
alias ga='git add .'
alias gp='git push'
alias gpr='git push --rebase'
alias bashly='docker run --rm -it --user $(id -u):$(id -g) --volume "$PWD:/app" dannyben/bashly'
