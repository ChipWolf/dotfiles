#!/bin/sh
# Forks: update repo_url below to point at your fork.

# -e: exit on error
# -u: exit on unset variables
set -eu

repo_url="https://github.com/chipwolf/dotfiles"

# --- Codespaces fast path ---
# The GHCR image is a delta-only image (scratch + our overlay layers).
# Pull every layer and extract directly, skipping full chezmoi apply +
# brew bundle. Falls back silently on any failure.
if [ -n "${CODESPACES:-}" ] && [ -z "${DOTFILES_NO_OVERLAY:-}" ]; then
	_dotfiles_fast_path() {
		CRANE_VERSION="v0.21.4"
		CRANE_BASE="https://github.com/google/go-containerregistry/releases/download/${CRANE_VERSION}"
		CRANE_TAR="go-containerregistry_Linux_x86_64.tar.gz"
		mkdir -p /tmp/_crane
		curl -fsSL "${CRANE_BASE}/${CRANE_TAR}" -o "/tmp/_crane/${CRANE_TAR}"
		curl -fsSL "${CRANE_BASE}/checksums.txt" -o /tmp/_crane/checksums.txt
		(cd /tmp/_crane && grep "${CRANE_TAR}" checksums.txt | sha256sum -c --strict)
		tar -xzf "/tmp/_crane/${CRANE_TAR}" -C /tmp/_crane crane
		CRANE=/tmp/_crane/crane

		OUR_IMAGE="ghcr.io/chipwolf/dotfiles:v1.5.0" # x-release-please-version

		OUR_MANIFEST=$("$CRANE" manifest "$OUR_IMAGE")
		OUR_DIGEST=$("$CRANE" digest "$OUR_IMAGE")
		gh attestation verify "oci://${OUR_IMAGE%:*}@${OUR_DIGEST}" \
			--repo chipwolf/dotfiles

		printf '%s' "$OUR_MANIFEST" | jq -r '.layers[].digest' | while IFS= read -r digest; do
			printf 'Applying overlay layer %s\n' "$digest" >&2
			"$CRANE" blob "${OUR_IMAGE}@${digest}" | sudo tar -xz --no-overwrite-dir --warning=no-timestamp --exclude='./tmp' -C /
		done

		rm -rf /tmp/_crane
	}

	if (
		set -e
		_dotfiles_fast_path
	); then
		set -x
		printf 'Dotfiles applied from pre-built overlay.\n' >&2
		# Trust and install mise tools for the workspace project.
		for d in /workspaces/[!.]*/; do
			if [ -d "$d" ]; then
				eval "$(mise activate sh 2>/dev/null)" || true
				mise trust --all "$d" 2>/dev/null || true
				mise install --cd "$d" 2>/dev/null || true
				break
			fi
		done
		# Kill stale terminal sessions opened during provisioning so the user
		# gets a fresh shell with the newly applied config.
		pkill -HUP -u "$(whoami)" bash 2>/dev/null || true
		pkill -HUP -u "$(whoami)" zsh 2>/dev/null || true
		exit 0
	fi
	printf 'Overlay fast path failed, falling back to chezmoi.\n' >&2
fi
# --- end Codespaces fast path ---

# run_remote <interpreter> <url> [args...]: fetch a script from <url> and run it
run_remote() {
	interpreter="$1"
	url="$2"
	shift 2
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

# If the script is running from a local clone (i.e. .chezmoiroot exists next to it),
# use that as the source. Otherwise (e.g. piped via curl/sh), let chezmoi clone from
# GitHub into the default location (~/.local/share/chezmoi).
if [ -f "${script_dir}/.chezmoiroot" ]; then
	set -- init --apply --source="${script_dir}"
else
	set -- init --apply "${repo_url}"
fi

echo "Running 'chezmoi $*'" >&2
# exec: replace current process with chezmoi
exec "$chezmoi" "$@"
