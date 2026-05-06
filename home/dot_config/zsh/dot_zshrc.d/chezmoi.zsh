# Chezmoi wrapper: auto-unlock Bitwarden before apply
#
# Stores BW_SESSION in the shell environment for the terminal session lifetime,
# mirroring the PowerShell profile behaviour on Windows.

bw-unlock() {
    if ! command -v bw &>/dev/null; then
        echo >&2 "Bitwarden CLI (bw) not found in PATH."
        return 1
    fi

    if [[ -n "$BW_SESSION" ]]; then
        if bw sync --session "$BW_SESSION" --quiet 2>/dev/null; then
            echo "Bitwarden is already unlocked for this shell."
            return 0
        fi
        unset BW_SESSION
    fi

    local session
    session="$(bw unlock --raw)" || {
        echo >&2 "Failed to unlock Bitwarden."
        return 1
    }

    if [[ -z "$session" ]]; then
        echo >&2 "Failed to unlock Bitwarden."
        return 1
    fi

    export BW_SESSION="$session"
    echo "Bitwarden unlocked for this shell session."
}

chezmoi() {
    local cmd="${1:-}"

    if [[ -z "$DOTFILES_SKIP_BITWARDEN" ]]; then
        local needs_unlock=0
        if [[ "$cmd" == "apply" ]]; then
            needs_unlock=1
        elif [[ "$cmd" == "init" ]] && [[ " $* " == *" --apply "* || " $* " == *" -a "* ]]; then
            needs_unlock=1
        fi

        if (( needs_unlock )); then
            bw-unlock || return 1
            if [[ -z "$BW_SESSION" ]]; then
                echo >&2 "Bitwarden unlock is required to run chezmoi apply."
                return 1
            fi
        fi
    fi

    command chezmoi "$@"
}
