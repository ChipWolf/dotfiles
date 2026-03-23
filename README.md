Dotfiles
===

<!-- start chipwolf/badgesort default -->
[![macOS](https://img.shields.io/badge/macOS-000000.svg?style=for-the-badge&logo=macos&logoColor=white)](#)
[![BadgeSort](https://img.shields.io/badge/BadgeSort-000000.svg?style=for-the-badge&logo=githubsponsors)](https://github.com/ChipWolf/BadgeSort)
[![tmux](https://img.shields.io/badge/tmux-1BB91F.svg?style=for-the-badge&logo=tmux&logoColor=white)](#)
[![Neovim](https://img.shields.io/badge/Neovim-57A143.svg?style=for-the-badge&logo=neovim&logoColor=white)](#)
[![Linux](https://img.shields.io/badge/Linux-FCC624.svg?style=for-the-badge&logo=linux&logoColor=black)](#)
[![Homebrew](https://img.shields.io/badge/Homebrew-FBB040.svg?style=for-the-badge&logo=homebrew&logoColor=black)](#)
[![Git](https://img.shields.io/badge/Git-F05032.svg?style=for-the-badge&logo=git&logoColor=white)](#)
[![Docker](https://img.shields.io/badge/Docker-2496ED.svg?style=for-the-badge&logo=docker&logoColor=white)](#)
[![GitHub Actions](https://img.shields.io/badge/GitHub%20Actions-2088FF.svg?style=for-the-badge&logo=githubactions&logoColor=white)](#)
[![Bitwarden](https://img.shields.io/badge/Bitwarden-175DDC.svg?style=for-the-badge&logo=bitwarden&logoColor=white)](#)
[![Python](https://img.shields.io/badge/Python-3776AB.svg?style=for-the-badge&logo=python&logoColor=white)](#)
<!-- end chipwolf/badgesort default -->

Opinionated dotfiles managed with [chezmoi](https://chezmoi.io). One repo configures macOS (primary), Linux, Windows, and GitHub Codespaces. A single bootstrap command installs dependencies, applies configs, and gets a new machine to a working state.

## What you get

| Tool | Role | macOS | Linux | Windows | Codespaces |
|------|------|:---:|:---:|:---:|:---:|
| **zsh + Powerlevel10k** | Shell and prompt | x | x | | x |
| **Oh My Posh** | Prompt engine (Windows) | | | x | |
| **Ghostty** | Terminal emulator | x | x | | |
| **WezTerm** | Terminal emulator (Windows) | | | x | |
| **tmux** | Terminal multiplexer | x | x | | x |
| **Neovim (LazyVim)** | Editor | x | x | x | x |
| **OpenCode** | AI coding agent | x | x | x | x |
| **Git** | Version control config | x | x | x | x |
| **GnuPG** | Encryption and signing | x | x | | |
| **Homebrew** | Package manager | x | x | | x |
| **mise** | Runtime manager (node, python, go, etc.) | x | x | x | x |
| **k9s** | Kubernetes TUI | x | x | x | x |
| **Finicky** | Default browser router | x | | | |

---

## Install

> [!WARNING]
> These scripts fetch and execute code from this repo in a single command. Review them first if that matters to you, or use the [inspect-first path](#inspect-first) below.
>
> The install scripts are published as [GitHub Release](https://github.com/chipwolf/dotfiles/releases/tag/v1.1.0) assets with [SLSA Build L3](https://slsa.dev/spec/v1.0/levels#build-l3) provenance, verified with: `gh attestation verify install.sh --owner chipwolf` <!-- x-release-please-version -->

**macOS / Linux**

<!-- x-release-please-start-version -->
```sh
sh -c "$(curl -fsSL https://github.com/chipwolf/dotfiles/releases/download/v1.1.0/install.sh)"
```
<!-- x-release-please-end -->

**Windows** (PowerShell, the script self-elevates)

<!-- x-release-please-start-version -->
```powershell
irm https://github.com/chipwolf/dotfiles/releases/download/v1.1.0/install.ps1 | iex
```
<!-- x-release-please-end -->

### What happens

**macOS / Linux:**

1. Installs Homebrew (if missing) and chezmoi.
2. `chezmoi init --apply` clones this repo and writes configs to `~/`.
3. `brew bundle` installs everything in the Brewfile. `brew upgrade` and `brew cleanup` run after.
4. Antidote (zsh plugin manager) prewarms the plugin cache.
5. mise installs managed runtimes. Neovim syncs plugins.
6. Sets the Homebrew-installed zsh as the default shell.

**Windows:**

1. Installs Chocolatey (if missing) and chezmoi.
2. `chezmoi init --apply` clones this repo and writes configs to `~/`.
3. `choco install` installs packages (Neovim, WezTerm, mise, Oh My Posh, and others).
4. Provisions WSL with Ubuntu via cloud-init: creates a user, clones this repo inside WSL, and runs the Linux bootstrap. If Ubuntu is already installed, it pulls and re-applies instead.
5. mise installs managed runtimes. Neovim syncs plugins.

### <a id="inspect-first"></a>Inspect first

If you want to review everything before it touches your machine:

```sh
chezmoi init https://github.com/chipwolf/dotfiles
chezmoi diff
chezmoi apply
```

This clones the repo and shows a diff. Nothing is written until `chezmoi apply`. You need chezmoi installed first (`brew install chezmoi` or see [chezmoi.io/get](https://www.chezmoi.io/install/)).

### Prerequisites

The bootstrap scripts handle most dependencies. You need:

- **macOS/Linux:** `curl` or `wget`, and a POSIX shell.
- **Windows:** PowerShell 5+.

### Secrets and Bitwarden

chezmoi is configured to use Bitwarden CLI (`bw`) as its secret manager, but no templates currently require it. `chezmoi apply` works fully without a Bitwarden session today. See [docs/secrets.md](docs/secrets.md) for details.

### Template flags

chezmoi uses two boolean flags to adapt behavior per machine. Both are set automatically in `.chezmoi.toml.tmpl`.

| Flag | When true | What it gates |
|------|-----------|---------------|
| `codespaces` | `CODESPACES` env var is set | Skips GUI apps and redundant packages in the Brewfile. Uses the overlay fast path in `install.sh`. |
| `private` | Windows, or `~/.private` exists | Enables personal-machine config: excludes work-specific MCP servers and Atlassian integrations from OpenCode. |

> [!IMPORTANT]
> To mark a macOS or Linux machine as private, run `touch ~/.private` before `chezmoi apply`.

---

## Updating

Pull the latest changes from the repo and re-apply:

```sh
chezmoi update
```

---

## Codespaces

When you set a personal dotfiles repo in your [GitHub Codespaces settings](https://github.com/settings/codespaces), GitHub clones this repo into each new codespace and runs `install.sh`.

This repo ships a pre-baked [overlay container image](https://ghcr.io/chipwolf/dotfiles) on GHCR. When `install.sh` detects `CODESPACES=1`, it pulls only the overlay layers that differ from the base devcontainer image and extracts them directly, skipping the full bootstrap.

> [!IMPORTANT]
> Dotfiles changes only take effect in new codespaces. Existing ones keep their current state unless rebuilt.

---

## Forking

If you fork this repo, the main things to update:

1. **`home/Brewfile`**: adjust packages to taste.
2. **Git identity**: update `home/dot_config/git/` with your name, email, and signing key.

The install scripts (`install.sh`, `install.ps1`) have the repo URL interpolated automatically during the release workflow, so forks that use the same workflow get correct URLs in their release assets without editing.

> [!TIP]
> The chezmoi source state lives under `home/` (set by `.chezmoiroot`). Filenames use chezmoi's attribute prefixes: `dot_` becomes a leading `.`, `private_` restricts permissions, `executable_` adds the execute bit. `home/dot_config/nvim/` deploys to `~/.config/nvim/`.

---

## SSH key setup

If you use a YubiKey for SSH authentication:

```shell
ykman config usb -d OTP
ykman fido access change-pin
ssh-keygen -t ed25519-sk -C "user@domain.tld" -O resident -O verify-required
```

Full workflow (backup keys, credential hygiene, recovery): [docs/yubikey.md](docs/yubikey.md).

---

## Provenance [![SLSA 3](https://slsa.dev/images/gh-badge-level3.svg)](https://slsa.dev)

All release artifacts are built with [SLSA Build L3](https://slsa.dev/spec/v1.0/levels#build-l3) provenance via the [SLSA GitHub Generator](https://github.com/slsa-framework/slsa-github-generator). The signing job runs in isolation from build steps, preventing tampering during and after the build.

This covers:

- **Install scripts** (`install.sh`, `install.ps1`): published as [GitHub Release](https://github.com/chipwolf/dotfiles/releases/tag/v1.1.0) assets with generic SLSA provenance. <!-- x-release-please-version -->
- **Codespaces overlay image** ([ghcr.io/chipwolf/dotfiles](https://ghcr.io/chipwolf/dotfiles)): published to GHCR with container SLSA provenance.

> [!NOTE]
> SLSA provenance does not cover the chezmoi source state (templates, configs, run scripts) or packages installed by Homebrew, Chocolatey, or mise. Those are outside the attestation boundary.

Verify:

<!-- x-release-please-start-version -->
```sh
# Install scripts (download the asset first)
gh attestation verify install.sh --owner chipwolf

# Container image
gh attestation verify oci://ghcr.io/chipwolf/dotfiles:v1.1.0 --owner chipwolf
```
<!-- x-release-please-end -->

---

## Further reading

| Document | Contents |
|----------|----------|
| [docs/yubikey.md](docs/yubikey.md) | YubiKey SSH workflow, backup strategy, credential hygiene |
| [docs/secrets.md](docs/secrets.md) | Bitwarden integration, GnuPG config, secret introduction order |

