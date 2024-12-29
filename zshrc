# Path to your oh-my-zsh installation.
export ZSH=$HOME/.zsh/oh-my-zsh
export ZSH_CUSTOM=$HOME/.zsh/custom
# Set name of the theme to load. Optionally, if you set this to "random"
# it'll load a random theme each time that oh-my-zsh is loaded.
# See https://github.com/robbyrussell/oh-my-zsh/wiki/Themes
ZSH_THEME="bullet-train"
zstyle ':omz:alpha:lib:git' async-prompt no

# Bullettrain config
BULLETTRAIN_CONTEXT_FG="white"
BULLETTRAIN_NVM_FG="black"
BULLETTRAIN_VIRTUALENV_FG="black"
BULLETTRAIN_KCTX_KCONFIG=$HOME/.kube/config
BULLETTRAIN_KCTX_BG=blue
BULLETTRAIN_KCTX_FG=white
BULLETTRAIN_PROMPT_ADD_NEWLINE=false
BULLETTRAIN_DIR_EXTENDED=0
BULLETTRAIN_PROMPT_ORDER=(
    status
    context
    dir
    virtualenv
    ruby
    nvm
    aws
    go
    custom
    kctx
    git
    hg
    cmd_exec_time
)

export SHOW_AWS_PROMPT=false

# Apply Bullettrain patch
zshwd="$(pwd)" cd ~/.etc/zsh/bullet-train.zsh && git apply ~/.etc/bullet-train.patch > /dev/null 2>&1; cd "$zshwd"

# Uncomment the following line to use hyphen-insensitive completion. Case
# sensitive completion must be off. _ and - will be interchangeable.
HYPHEN_INSENSITIVE="true"

# Uncomment the following line to disable auto-setting terminal title.
DISABLE_AUTO_TITLE="true"

# Uncomment the following line to enable command auto-correction.
ENABLE_CORRECTION="false"

# Uncomment the following line to display red dots whilst waiting for completion.
COMPLETION_WAITING_DOTS="true"

# Which plugins would you like to load? (plugins can be found in ~/.oh-my-zsh/plugins/*)
# Custom plugins may be added to ~/.oh-my-zsh/custom/plugins/
# Example format: plugins=(rails git textmate ruby lighthouse)
# Add wisely, as too many plugins slow down shell startup.
plugins=(
    docker
    tmux
    terraform
    aws
    vi-mode
    history-substring-search
    gpg-agent
    httpie
    bat
    asdf
    gcloud
    exa
    fasd
    kubectl
    zsh-completions
)

#ZSH_TMUX_AUTOSTART=${ZSH_TMUX_AUTOSTART:=true}
ZSH_TMUX_AUTOCONECT=false

case $(uname -s) in
  *Darwin*)
    source $HOME/.zsh/zsh-os-conf/osx-pre-omz.zsh
    ;;
  *Linux*)
    source $HOME/.zsh/zsh-os-conf/linux-pre-omz.zsh
    ;;
esac


PREFILES=($HOME/.zsh/zsh-os-conf/local-pre/*.zsh(N))

for file in $PREFILES; do
  source $file
done

source $ZSH/oh-my-zsh.sh

# User configuration

###  ENVIRONMENT

EDITOR='vim'
KEYTIMEOUT=1

### ALIASES

alias tmux='tmux -2'
alias loadnvm='[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"'  # This loads nvm
alias kc='nocorrect kubectl'
alias l='exa -abglm --color-scale --git --color=automatic'

### FUNCTIONS

pb () {
  curl -F "c=@${1:--}" https://ptpb.pw/
}
TRAPUSR1() {
  if [[ -o INTERACTIVE ]]; then
     {echo; echo execute a new shell instance } 1>&2
     exec "${SHELL}"
  fi
}

fpath=(/usr/local/share/zsh-completions $fpath)

zmodload zsh/complist

### KEYBINDINGS

bindkey -M menuselect ' ' accept-and-infer-next-history
bindkey -M menuselect '^?' undo

bindkey "\e\e[D" backward-word # alt + <-
bindkey "\e\e[C" forward-word # alt + ->

### SOURCES

source $HOME/.zsh/zsh-autosuggestions/zsh-autosuggestions.zsh
source $HOME/.zsh/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
. $HOME/.zsh/scripts/exercism_completion.zsh

export NVM_DIR="$HOME/.nvm"

export PATH="$PATH:$HOME/.scripts"

case $(uname -s) in
  *Darwin*)
    source $HOME/.zsh/zsh-os-conf/osx-post-omz.zsh
    ;;
  *Linux*)
    source $HOME/.zsh/zsh-os-conf/linux-post-omz.zsh
    ;;
esac

POSTFILES=($HOME/.zsh/zsh-os-conf/local-post/*.zsh(N))

for file in $POSTFILES; do
  source $file
done

autoload -U compinit && compinit

. /opt/asdf-vm/asdf.sh

fastfetch

setopt no_hist_verify # prevents substitution confirmation
