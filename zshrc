# Path to your oh-my-zsh installation.
export ZSH=$HOME/.zsh/oh-my-zsh
export ZSH_CUSTOM=$HOME/.zsh/custom
# Set name of the theme to load. Optionally, if you set this to "random"
# it'll load a random theme each time that oh-my-zsh is loaded.
# See https://github.com/robbyrussell/oh-my-zsh/wiki/Themes
ZSH_THEME="bullet-train"
ZSH_AUTOSUGGEST_USE_ASYNC=true
ZSH_AUTOSUGGEST_BUFFER_MAX_SIZE=15

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
    aws_vault
    virtualenv2
    ruby2
    nvm
    aws
    go
    custom
    kctx2
    git
    hg
    cmd_exec_time
)

export SHOW_AWS_PROMPT=false

export SHOW_AWS_PROMPT=false

# Uncomment the following line to use hyphen-insensitive completion. Case
# sensitive completion must be off. _ and - will be interchangeable.
HYPHEN_INSENSITIVE="true"

# Uncomment the following line to disable auto-setting terminal title.
DISABLE_AUTO_TITLE="true"

# Uncomment the following line to enable command auto-correction.
ENABLE_CORRECTION="true"

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
    fzf
    zsh-completions
    kubectl
    fasd
    fzf
    zsh-completions
)

ZSH_TMUX_AUTOSTART=true

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
alias kx='kubens'

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
#source <(helm completion zsh | sed -E 's/\["(.+)"\]/\[\1\]/g')

source $HOME/.zsh/zsh-aws-vault/zsh-aws-vault.plugin.zsh

prompt_aws_vault() {
  local vault_segment
  vault_segment="`prompt_aws_vault_segment`"
  [[ $vault_segment != '' ]] && prompt_segment cyan black "$vault_segment"
}

prompt_kctx2() {
  local vault_segment
  vault_segment="`prompt_aws_vault_segment`"
  if [[ "$BULLETTRAIN_KCTX_KUBECTL" == "true" && $vault_segment != '' ]] && command -v kubectl > /dev/null 2>&1; then
    local jsonpath='{.current-context}'
    if [[ "$BULLETTRAIN_KCTX_NAMESPACE" == "true" ]]; then
      jsonpath="${jsonpath}{':'}{..namespace}"
    fi
    prompt_segment $BULLETTRAIN_KCTX_BG $BULLETTRAIN_KCTX_FG $BULLETTRAIN_KCTX_PREFIX" $(kubectl config view --minify --output "jsonpath=${jsonpath}" 2>/dev/null | cut -d/ -f2)"
  fi
}

prompt_ruby2() {
  if command -v rvm-prompt > /dev/null 2>&1; then
    prompt_segment $BULLETTRAIN_RUBY_BG $BULLETTRAIN_RUBY_FG $BULLETTRAIN_RUBY_PREFIX" $(rvm-prompt i v g)"
  elif command -v chruby > /dev/null 2>&1; then
    prompt_segment $BULLETTRAIN_RUBY_BG $BULLETTRAIN_RUBY_FG $BULLETTRAIN_RUBY_PREFIX"  $(chruby | sed -n -e 's/ \* //p')"
  elif command -v rbenv > /dev/null 2>&1; then
    current_gemset() {
      echo "$(rbenv gemset active 2&>/dev/null | sed -e 's/ global$//')"
    }

    if [[ -n $(current_gemset) ]]; then
      prompt_segment $BULLETTRAIN_RUBY_BG $BULLETTRAIN_RUBY_FG $BULLETTRAIN_RUBY_PREFIX"  $(rbenv version | sed -e 's/ (set.*$//')"@"$(current_gemset)"
    else
      prompt_segment $BULLETTRAIN_RUBY_BG $BULLETTRAIN_RUBY_FG $BULLETTRAIN_RUBY_PREFIX"  $(rbenv version | sed -e 's/ (set.*$//')"
    fi
  fi
}

prompt_virtualenv2() {
  local virtualenv_path="$VIRTUAL_ENV"
  if [[ -n $virtualenv_path && -n $VIRTUAL_ENV_DISABLE_PROMPT ]]; then
    prompt_segment $BULLETTRAIN_VIRTUALENV_BG $BULLETTRAIN_VIRTUALENV_FG $BULLETTRAIN_VIRTUALENV_PREFIX" $(basename $virtualenv_path)"
  elif which pyenv &> /dev/null; then
    if [[ "$(pyenv version | sed -e 's/ (set.*$//' | tr '\n' ' ' | sed 's/.$//')" != "system" ]]; then
      prompt_segment $BULLETTRAIN_VIRTUALENV_BG $BULLETTRAIN_VIRTUALENV_FG $BULLETTRAIN_VIRTUALENV_PREFIX" $(pyenv version | sed -e 's/ (set.*$//' | tr '\n' ' ' | sed 's/.$//')"
    fi
  fi
}

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

[ -f ~/.fzf.zsh ] && source ~/.fzf.zsh

alias note='bash ~/.etc/scripts/notes.sh'

setopt no_hist_verify # prevents substitution confirmation

zstyle ':bracketed-paste-magic' active-widgets '.self-*'.

autoload -U compinit && compinit

[ -f ~/.fzf.zsh ] && source ~/.fzf.zsh
