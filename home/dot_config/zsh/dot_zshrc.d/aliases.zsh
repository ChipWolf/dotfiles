#!/bin/zsh

alias kc='nocorrect kubectl'
alias kd='kubectl describe'
alias kg='kubectl get'
alias kx='kubens'

alias g='git'
alias ga='git add'
alias gr='git rm'
alias grm='git rm'
alias gc='git commit'
alias gca='git commit --amend'
alias gcan='git commit --amend --no-edit'
alias gpu='git pull'
alias gp='git push'
alias gpf='git push --force'
alias gr='git rebase'
alias gri='git rebase -i'
alias grir='git rebase -i --root'
alias gr='git reset'
alias grh='git reset --hard'

alias tmux='tmux -2'

alias v='nvim'
alias vc='nvim .'
alias vi='nvim'
alias vim='nvim'

alias cm='chezmoi'

alias fuck='say fuck; fuck'

if (( $+commands[bat] )); then
  alias cat=bat
fi

if (( $+commands[eza] )); then
  alias ls=eza
  alias l='eza -abglm --color-scale --git --color=automatic'
  alias ll='eza -l --git --time-style=long-iso'
  alias tree='eza -T'
fi
