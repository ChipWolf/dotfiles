# This file is sourced only on OSX after OMZ is loaded. Use it to set osx specific aliases, functions and sources.

### ENVIRONMENT
PATH="$PATH:/usr/local/sbin"
export GPG_TTY=$(tty)

### ALIASES
alias bubus='if brew outdated | grep -q "yabai"; then brew services stop yabai; fi && bubu && brew cu --quiet --yes --no-brew-update && if ! pgrep -x "yabai" > /dev/null; then brew services start yabai && sudo yabai --uninstall-sa && sudo yabai --install-sa && killall {Dock,Finder}; fi'

### FUNCTIONS


### SOURCES
