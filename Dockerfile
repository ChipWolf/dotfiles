# Builds a pre-baked dotfiles overlay image for GitHub Codespaces.
# The resulting image layers (minus the base) are pulled and extracted
# into a codespace by install.sh for fast dotfiles provisioning.
#
# CI extracts only the diff layers (those added by COPY + RUN below) and
# pushes them as a scratch-based delta image to GHCR. install.sh pulls
# all layers from that image; no base-image manifest diffing needed.
#
# IMPORTANT: _build-container.yml hardcodes DIFF_COUNT=2 (one layer per
# instruction after FROM). Update that value if you add or remove layers.
# Pin a concrete universal image tag (not :latest) for reproducible builds and static analysis (Trivy DS-0001 / Checkov).
# kics-scan ignore-line
# hadolint ignore=DL3007
FROM mcr.microsoft.com/devcontainers/universal:6.0.3-linux

USER codespace
# kics-scan ignore-line
COPY --chown=codespace:codespace . /tmp/dotfiles
RUN CODESPACES=1 DOTFILES_NO_OVERLAY=1 /tmp/dotfiles/install.sh \
    && rm -rf /tmp/dotfiles /home/codespace/.config/chezmoi \
    # --- Layer size cleanup (saves ~535 MiB uncompressed) ---
    # Remove Homebrew download cache and stale bottles
    && eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)" \
    && brew cleanup --prune=all -s \
    # Remove Homebrew git repo history (brew update re-clones on first use)
    && rm -rf /home/linuxbrew/.linuxbrew/Homebrew/.git \
    # Remove antidote plugin .git history (only working trees needed at runtime)
    && { find /home/codespace/.cache/antidote -name .git -type d -exec rm -rf {} + 2>/dev/null || true; } \
    # Remove duplicate chezmoi binary (brew-installed copy is on PATH)
    && rm -f /home/codespace/.local/bin/chezmoi

# Lightweight runtime sanity check for the pre-baked Codespaces overlay image.
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
    CMD ["/bin/sh", "-c", "test -d /home/codespace && test -f /home/codespace/.zshrc"]
