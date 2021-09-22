# This file is sourced only on OSX after OMZ is loaded. Use it to set osx specific aliases, functions and sources.

### ENVIRONMENT
PATH="$PATH:/usr/local/sbin"
export GPG_TTY=$(tty)

### ALIASES
alias bubus='if brew outdated | grep -q "yabai"; then if pgrep -x "yabai" > /dev/null; then brew services stop yabai; fi; fi && if ! pgrep -x "yabai" > /dev/null; then brew services start yabai && sudo yabai --uninstall-sa && sudo yabai --install-sa && killall {Dock,Finder}; fi && bubu && brew cu --quiet --yes --no-brew-update && sudo softwareupdate --all --install --force --restart'

### FUNCTIONS
function awschrome {
    # set to yes to create one-time use profiles in /tmp
    # anything else will create them in $HOME/.aws/awschrome
    TEMP_PROFILE="yes"

    # set to yes to always start in a new window
    NEW_WINDOW="no"

    profile="$1"
    if [[ -z "$profile" ]]; then
        echo "Profile is a required argument" >&2
        return 1
    fi

    # replace non word and not - with __
    profile_dir_name=${profile//[^a-zA-Z0-9_-]/__}
    user_data_dir="${HOME}/.aws/awschrome/${profile_dir_name}"
    new_window_arg=''

    if [[ "$TEMP_PROFILE" = "yes" ]]; then
        user_data_dir=$(mktemp -d /tmp/awschrome_userdata.XXXXXXXX)
    fi

    if [[ "$NEW_WINDOW" = "yes" ]]; then
        new_window_arg='--new-window'
    fi

    # run aws-vault
    # --prompt osascript only works on OSX
    url=$(aws-vault login $profile --stdout --prompt osascript)
    av_status=$?

    if [[ ${av_status} -ne 0 ]]; then
        # bash will also capture stderr, so echo $url
        echo ${url}
        return ${av_status}
    fi

    mkdir -p ${user_data_dir}
    disk_cache_dir=$(mktemp -d /tmp/awschrome_cache.XXXXXXXX)
    /Applications/Google\ Chrome.app/Contents/MacOS/Google\ Chrome \
        --no-first-run \
        --user-data-dir=${user_data_dir} \
        --disk-cache-dir=${disk_cache_dir} \
        ${new_window_arg} \
        ${url} \
      >/dev/null 2>&1 &
}

### SOURCES
