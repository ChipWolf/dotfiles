#!/bin/zsh

alias kc='nocorrect kubectl'
alias kd='kubectl describe'
alias kg='kubectl get'
alias kx='kubens'

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
