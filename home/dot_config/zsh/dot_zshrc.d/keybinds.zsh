#!/bin/zsh

bindkey -M menuselect ' ' accept-and-infer-next-history
bindkey -M menuselect '^?' undo

bindkey "\e\e[D" backward-word # alt + <-
bindkey "\e\e[C" forward-word # alt + ->
