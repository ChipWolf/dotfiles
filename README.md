# Dotfiles

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

| Tool                    | Role                                     | macOS | Linux | Windows | Codespaces |
|-------------------------|------------------------------------------|:-----:|:-----:|:-------:|:----------:|
| **zsh + Powerlevel10k** | Shell and prompt                         |   x   |   x   |         |     x      |
| **Oh My Posh**          | Prompt engine (Windows)                  |       |       |    x    |            |
| **Ghostty**             | Terminal emulator                        |   x   |       |         |            |
| **WezTerm**             | Terminal emulator (Windows)              |       |       |    x    |            |
| **tmux**                | Terminal multiplexer                     |   x   |       |         |            |
| **Neovim (LazyVim)**    | Editor                                   |   x   |   x   |    x    |     x      |
| **OpenCode**            | AI coding agent                          |   x   |   x   |    x    |     x      |
| **tree-sitter CLI**     | Treesitter parser generator              |       |       |    x    |            |
| **WakaTime CLI**        | Coding activity tracker                  |   x   |   x   |         |            |
| **Git**                 | Version control config                   |   x   |   x   |    x    |     x      |
| **GnuPG**               | Encryption and signing                   |   x   |   x   |         |            |
| **Tailscale**           | VPN mesh and secure remote access        |       |       |    x    |            |
| **Homebrew**            | Package manager                          |   x   |   x   |         |     x      |
| **mise**                | Runtime manager (node, python, go, etc.) |   x   |   x   |    x    |     x      |
| **Finicky**             | Default browser router                   |   x   |       |         |            |
| **Steam**               | Game platform (Windows)                  |       |       |    x    |            |
| **Sysinternals**        | Windows diagnostics utilities            |       |       |    x    |            |
| **GlazeWM**             | Windows tiling window manager            |       |       |    x    |            |
| **YASB**                | Windows status bar                       |       |       |    x    |            |
| **WinLibs (GCC)**       | C compiler toolchain (Windows)           |       |       |    x    |            |

---

## Install

> [!WARNING]
> These scripts fetch and execute code from this repo in a single command. Review them first if that matters to you, or use the [inspect-first path](#inspect-first) below.
>
> The install scripts are published as [GitHub Release](https://github.com/chipwolf/dotfiles/releases/tag/v1.7.0) assets with [SLSA Build L3](https://slsa.dev/spec/v1.0/levels#build-l3) provenance, verified with: `gh attestation verify install.sh --repo chipwolf/dotfiles` <!-- x-release-please-version -->

**macOS / Linux**

<!-- x-release-please-start-version -->

```sh
sh -c "$(curl -fsSL https://github.com/chipwolf/dotfiles/releases/download/v1.7.0/install.sh)"
```

<!-- x-release-please-end -->

**Windows** (PowerShell, the script self-elevates)

<!-- x-release-please-start-version -->

```powershell
irm https://github.com/chipwolf/dotfiles/releases/download/v1.7.0/install.ps1 | iex
```

<!-- x-release-please-end -->

### What happens

**macOS / Linux:**

1. Installs Homebrew (if missing) and chezmoi.
2. `chezmoi init --apply` clones this repo and writes configs to `~/`.
3. `brew bundle` installs everything from the rendered Homebrew bundle template. `brew upgrade` and `brew cleanup` run after.
4. Antidote (zsh plugin manager) prewarms the plugin cache.
5. mise installs managed runtimes. Neovim syncs plugins.
6. Sets the Homebrew-installed zsh as the default shell.

**Windows:**

1. Installs Chocolatey (if missing) and chezmoi.
2. `chezmoi init --apply` clones this repo and writes configs to `~/`.
3. `choco install` installs packages (Neovim, WezTerm, GlazeWM, YASB, mise, Oh My Posh, and others).
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

chezmoi is configured to use Bitwarden CLI (`bw`) as its secret manager. Some templates (for example WakaTime API key config) read values from Bitwarden at apply time, so unlock Bitwarden before `chezmoi apply` when those targets are in scope. See [docs/secrets.md](docs/secrets.md) for details.

### Template flags

chezmoi uses two boolean flags to adapt behavior per machine. Both are set automatically in [`home/.chezmoi.toml.tmpl`](home/.chezmoi.toml.tmpl).

| Flag         | When true                       | What it gates                                                                                                              |
|--------------|---------------------------------|----------------------------------------------------------------------------------------------------------------------------|
| `codespaces` | `CODESPACES` env var is set     | Skips GUI apps and redundant packages in the Brewfile. Uses the overlay fast path in [`install.sh.tmpl`](install.sh.tmpl). |
| `private`    | Windows, or `~/.private` exists | Enables personal-machine config: excludes work-specific MCP servers and Atlassian integrations from OpenCode.              |

> [!IMPORTANT]
> To mark a macOS or Linux machine as private, run `touch ~/.private` before `chezmoi apply`.

---

## Updating

Pull the latest changes from the repo and re-apply:

```sh
chezmoi update
```

For local repo checks before commit:

```sh
pre-commit install
```

---

## Codespaces

When you set a personal dotfiles repo in your [GitHub Codespaces settings](https://github.com/settings/codespaces), set the install script to `setup.sh`. GitHub clones this repo into each new codespace and runs that script.

`setup.sh` is a lightweight Codespaces-only shim: it renders `install.sh` from [`install.sh.tmpl`](install.sh.tmpl) with `chezmoi execute-template`, then executes the generated installer.

This repo ships a pre-baked [overlay container image](https://ghcr.io/chipwolf/dotfiles) on GHCR. When `install.sh` detects `CODESPACES=1`, it pulls only the overlay layers that differ from the base devcontainer image and extracts them directly, skipping the full bootstrap.

> [!IMPORTANT]
> Dotfiles changes only take effect in new codespaces. Existing ones keep their current state unless rebuilt.

---

## Forking

Recommended fork workflow:

1. Fork this repo on GitHub.
2. Clone your fork locally.
3. Update identity and package overlays (checklist below).
4. Run `chezmoi apply` and validate your machine state.

### Fork checklist

Change these files first:

- **Identity**: `home/.chezmoidata/profile.yaml`
  - `profile.git.name`
  - `profile.git.email`
  - `profile.git.githubUser`
  - `profile.git.githubRepo` (for WSL bootstrap clone target)
  - `profile.git.signingKey` (optional)
  - `profile.codespaces.gitName`
- **Git config template**: `home/dot_gitconfig.tmpl` (usually no change needed, only edit if you want different structure)
- **Homebrew packages**: `home/.chezmoidata/brew/*.yaml`
  - Keep `00-base.yaml` for shared packages.
  - Replace `10-chipwolf.yaml` with your own overlay file (for example `10-yourname.yaml`) and adjust package entries.
  - Keep package state in `home/Brewfile.tmpl` and `home/.chezmoidata/brew/*.yaml`; no checked-in rendered Brewfile is required.
- **Agent permissions** (optional but common): `home/.chezmoidata/agent-permissions/*.yaml`
  - Keep `00-base.yaml` for shared rules.
  - Replace `10-chipwolf.yaml` with your own overlay file.
- **MCP servers** (optional but common): `home/.chezmoidata/mcps/*.yaml`
  - Keep `00-base.yaml` for shared servers.
  - Replace `10-chipwolf.yaml` with your own overlay file.
- **OpenCode config template**: `home/dot_config/opencode/opencode.jsonc.tmpl` (usually no change needed unless you want to change render structure)

Optional removals if not relevant to your setup:

- `home/private_dot_gnupg/` (if you do not use this GnuPG setup)
- `home/dot_config/finicky.js` (if you do not use Finicky on macOS)
- `home/dot_scripts/executable_7zw` (if you do not use the archive/encryption wrapper)
- Any app/package entries you do not want in `home/.chezmoidata/brew/*.yaml`

Install scripts note:

- `install.sh.tmpl` and `install.ps1.tmpl` are the installer source of truth.
- Release automation renders release-ready `install.sh` and `install.ps1` from those templates using the current repository and tag values.

> [!TIP]
> The chezmoi source state lives under [`home/`](home/) (set by [`.chezmoiroot`](.chezmoiroot)). Filenames use chezmoi's attribute prefixes: `dot_` becomes a leading `.`, `private_` restricts permissions, `executable_` adds the execute bit. [`home/dot_config/nvim/`](home/dot_config/nvim/) deploys to `~/.config/nvim/`.

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

All release artifacts are built with [SLSA Build L3](https://slsa.dev/spec/v1.0/levels#build-l3) provenance via [GitHub artifact attestations](https://docs.github.com/en/actions/security-guides/using-artifact-attestations-to-establish-provenance-for-builds) in [reusable workflows](https://docs.github.com/en/actions/security-guides/using-artifact-attestations-and-reusable-workflows-to-achieve-slsa-v1-build-level-3) that isolate the build from the calling workflow.

This covers:

- **Install scripts** ([`install.sh.tmpl`](install.sh.tmpl), [`install.ps1.tmpl`](install.ps1.tmpl)): published as [GitHub Release](https://github.com/chipwolf/dotfiles/releases/tag/v1.7.0) assets after CI template rendering. <!-- x-release-please-version -->
- **Codespaces overlay image** ([ghcr.io/chipwolf/dotfiles](https://ghcr.io/chipwolf/dotfiles)): published to GHCR.

> [!NOTE]
> Provenance does not cover the chezmoi source state (templates, configs, run scripts) or packages installed by Homebrew, Chocolatey, or mise. Those are outside the attestation boundary.

Verify:

<!-- x-release-please-start-version -->

```sh
# Install scripts (download the asset first)
gh attestation verify install.sh --repo chipwolf/dotfiles

# Container image
gh attestation verify oci://ghcr.io/chipwolf/dotfiles:v1.7.0 --repo chipwolf/dotfiles
```

<!-- x-release-please-end -->

---

## Further reading

| Document                                               | Contents                                                           |
|--------------------------------------------------------|--------------------------------------------------------------------|
| [docs/brew.md](docs/brew.md)                           | Homebrew overlays, template rendering, and brew-review workflow    |
| [docs/agent-permissions.md](docs/agent-permissions.md) | Shared agent permission rule schema, overlays, and rendering model |
| [docs/mcp-servers.md](docs/mcp-servers.md)             | MCP server setup, conditions, targets, and arg interpolation       |
| [docs/yubikey.md](docs/yubikey.md)                     | YubiKey SSH workflow, backup strategy, credential hygiene          |
| [docs/secrets.md](docs/secrets.md)                     | Bitwarden integration, GnuPG config, secret introduction order     |
