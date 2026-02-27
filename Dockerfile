# Builds a pre-baked dotfiles overlay image for GitHub Codespaces.
# The resulting image layers (minus the base) are pulled and extracted
# into a codespace by install.sh for fast dotfiles provisioning.
FROM mcr.microsoft.com/devcontainers/universal:latest

USER codespace
COPY --chown=codespace:codespace . /tmp/dotfiles
RUN CODESPACES=1 /tmp/dotfiles/install.sh \
    && rm -rf /tmp/dotfiles /home/codespace/.config/chezmoi
