# Builds a pre-baked dotfiles overlay image for GitHub Codespaces.
# The resulting image layers (minus the base) are pulled and extracted
# into a codespace by install.sh for fast dotfiles provisioning.
FROM mcr.microsoft.com/devcontainers/universal:2

USER codespace
COPY . /tmp/dotfiles
RUN chown -R codespace:codespace /tmp/dotfiles
RUN CODESPACES=1 DOTFILES_NO_OVERLAY=1 /tmp/dotfiles/install.sh \
    && rm -rf /tmp/dotfiles /home/codespace/.config/chezmoi

# Lightweight runtime sanity check for the pre-baked Codespaces overlay image.
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
    CMD ["/bin/sh", "-c", "test -d /home/codespace && test -f /home/codespace/.zshrc"]
