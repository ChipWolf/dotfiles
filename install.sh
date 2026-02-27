#!/bin/sh

# -e: exit on error
# -u: exit on unset variables
set -eu

# --- Codespaces fast path ---
# Pull only our overlay layers from GHCR and extract them directly,
# skipping the full chezmoi apply + brew bundle. Falls back silently.
if [ -n "${CODESPACES:-}" ]; then
  _dotfiles_fast_path() {
    CRANE_VERSION="v0.20.2"
    mkdir -p /tmp/_crane
    curl -fsSL "https://github.com/google/go-containerregistry/releases/download/${CRANE_VERSION}/go-containerregistry_Linux_x86_64.tar.gz" \
      | tar -xz -C /tmp/_crane crane
    CRANE=/tmp/_crane/crane

    OUR_IMAGE="ghcr.io/chipwolf/dotfiles:latest"
    BASE_IMAGE="mcr.microsoft.com/devcontainers/universal:latest"

    OUR_LAYERS=$("$CRANE" manifest "$OUR_IMAGE" | jq -r '.layers[].digest')
    BASE_LAYERS=$("$CRANE" manifest --platform linux/amd64 "$BASE_IMAGE" | jq -r '.layers[].digest')

    printf '%s\n' "$OUR_LAYERS" | while IFS= read -r digest; do
      if ! printf '%s\n' "$BASE_LAYERS" | grep -qxF "$digest"; then
        printf 'Applying overlay layer %s\n' "$digest" >&2
        "$CRANE" blob "$OUR_IMAGE" "$digest" | tar -xz --no-same-owner -C /
      fi
    done

    rm -rf /tmp/_crane
  }

  if (set -e; _dotfiles_fast_path); then
    printf 'Dotfiles applied from pre-built overlay.\n' >&2
    exit 0
  fi
  printf 'Overlay fast path failed — falling back to chezmoi.\n' >&2
fi
# --- end Codespaces fast path ---

# run_remote <interpreter> <url> [args...]: fetch a script from <url> and run it
run_remote() {
  interpreter="$1"; url="$2"; shift 2
  if command -v curl >/dev/null 2>&1; then
    curl -fsSL "${url}" | "${interpreter}" -s -- "$@"
  elif command -v wget >/dev/null 2>&1; then
    wget -qO- "${url}" | "${interpreter}" -s -- "$@"
  else
    echo "curl or wget is required; please install one and retry." >&2
    exit 1
  fi
}

if ! chezmoi="$(command -v chezmoi)"; then
  if command -v brew >/dev/null 2>&1; then
    echo "Installing chezmoi via Homebrew" >&2
    brew install chezmoi
    chezmoi="$(command -v chezmoi)"
  else
    # No brew available — prompt if we have a TTY, otherwise fall back to direct install
    install_via_script=1
    if [ -t 0 ]; then
      printf "Homebrew is not installed. Install Homebrew first (recommended)? [Y/n] " >&2
      read -r brew_answer </dev/tty
      case "${brew_answer}" in
        [Nn]*)
          # User declined; proceed with direct install below
          ;;
        *)
          echo "Installing Homebrew..." >&2
          run_remote bash https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh || {
            echo "Homebrew installation failed; continuing without it." >&2
          }
          # Homebrew may not be on PATH yet in this session; source shellenv if needed
          if ! command -v brew >/dev/null 2>&1; then
            for brew_prefix in /opt/homebrew /usr/local /home/linuxbrew/.linuxbrew; do
              if [ -x "${brew_prefix}/bin/brew" ]; then
                eval "$("${brew_prefix}/bin/brew" shellenv)"
                break
              fi
            done
          fi
          if command -v brew >/dev/null 2>&1; then
            echo "Installing chezmoi via Homebrew" >&2
            brew install chezmoi
            chezmoi="$(command -v chezmoi)"
            install_via_script=0
          fi
          ;;
      esac
    fi

    if [ "${install_via_script}" -eq 1 ]; then
      bin_dir="${HOME}/.local/bin"
      chezmoi="${bin_dir}/chezmoi"
      echo "Installing chezmoi to '${chezmoi}'" >&2
      run_remote sh https://chezmoi.io/get -b "${bin_dir}"
      unset bin_dir
    fi
    unset install_via_script
  fi
fi

# POSIX way to get script's dir: https://stackoverflow.com/a/29834779/12156188
script_dir="$(cd -P -- "$(dirname -- "$(command -v -- "$0")")" && pwd -P)"

set -- init --apply --source="${script_dir}"

echo "Running 'chezmoi $*'" >&2
# exec: replace current process with chezmoi
exec "$chezmoi" "$@"
