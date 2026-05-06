#!/bin/sh

set -eu

git remote -v

if [ "${CODESPACES:-}" != "true" ]; then
	echo "setup.sh is only supported in GitHub Codespaces (requires CODESPACES=true)." >&2
	exit 1
fi

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
	bin_dir="${HOME}/.local/bin"
	chezmoi="${bin_dir}/chezmoi"
	echo "Installing chezmoi to '${chezmoi}'" >&2
	run_remote sh https://chezmoi.io/get -b "${bin_dir}"
	unset bin_dir
fi

script_dir="$(cd -P -- "$(dirname -- "$0")" && pwd -P)"

DOTFILES_REPO_URL="${DOTFILES_REPO_URL:-https://github.com/chipwolf/dotfiles}"
DOTFILES_IMAGE_NAME="${DOTFILES_IMAGE_NAME:-ghcr.io/chipwolf/dotfiles}"
DOTFILES_ATTESTATION_REPO="${DOTFILES_ATTESTATION_REPO:-chipwolf/dotfiles}"
DOTFILES_RELEASE_TAG="${DOTFILES_RELEASE_TAG:-latest}"

install_script="${script_dir}/install.sh"

env \
	DOTFILES_REPO_URL="${DOTFILES_REPO_URL}" \
	DOTFILES_IMAGE_NAME="${DOTFILES_IMAGE_NAME}" \
	DOTFILES_ATTESTATION_REPO="${DOTFILES_ATTESTATION_REPO}" \
	DOTFILES_RELEASE_TAG="${DOTFILES_RELEASE_TAG}" \
	"$chezmoi" execute-template --file "${script_dir}/install.sh.tmpl" >"${install_script}"
chmod +x "${install_script}"

exec "${install_script}"
