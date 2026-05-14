#!/usr/bin/env bats
# install.bats — structural tests for install script templates and CI workflows.
# Validates that regressions from the install script hardening are not reintroduced.

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  if command -v cygpath >/dev/null 2>&1; then
    REPO_ROOT="$(cygpath -m "$REPO_ROOT")"
  fi
}

# --- install.ps1.tmpl: prerequisite packages in elevated block ---

@test "install.ps1: elevated block installs chezmoi" {
  grep -q 'Get-Command chezmoi.*packages.*chezmoi' "$REPO_ROOT/install.ps1.tmpl"
}

@test "install.ps1: elevated block installs gnupg" {
  grep -q 'Get-Command gpg.*packages.*gnupg' "$REPO_ROOT/install.ps1.tmpl"
}

@test "install.ps1: elevated block installs mise" {
  grep -q 'Get-Command mise.*packages.*mise' "$REPO_ROOT/install.ps1.tmpl"
}

@test "install.ps1: elevated block installs powershell-core" {
  grep -q 'Get-Command pwsh.*packages.*powershell-core' "$REPO_ROOT/install.ps1.tmpl"
}

@test "install.ps1: elevated block installs bitwarden-cli" {
  grep -q 'Get-Command bw.*packages.*bitwarden-cli' "$REPO_ROOT/install.ps1.tmpl"
}

@test "install.ps1: elevated block installs git" {
  grep -q 'packages.*git' "$REPO_ROOT/install.ps1.tmpl"
}

# --- install.ps1.tmpl: elevation split ---

@test "install.ps1: uses scriptblock elevation pattern" {
  grep -q '\$elevatedScript\s*=' "$REPO_ROOT/install.ps1.tmpl"
}

@test "install.ps1: bw login is outside elevated block" {
  local non_elevated
  non_elevated=$(grep -n '# --- Non-elevated' "$REPO_ROOT/install.ps1.tmpl" | head -1 | cut -d: -f1)
  local bw_login
  bw_login=$(grep -vn '^\s*#' "$REPO_ROOT/install.ps1.tmpl" | grep 'bw login' | head -1 | cut -d: -f1)
  [ "$bw_login" -gt "$non_elevated" ]
}

@test "install.ps1: chezmoi init is outside elevated block" {
  local non_elevated
  non_elevated=$(grep -n '# --- Non-elevated' "$REPO_ROOT/install.ps1.tmpl" | head -1 | cut -d: -f1)
  local chezmoi_init
  chezmoi_init=$(grep -n 'initArgs = @("init", "--apply")' "$REPO_ROOT/install.ps1.tmpl" | head -1 | cut -d: -f1)
  [ "$chezmoi_init" -gt "$non_elevated" ]
}

# --- install.ps1.tmpl: error handling ---

@test "install.ps1: elevated block has try-catch" {
  grep -q 'try {' "$REPO_ROOT/install.ps1.tmpl"
  grep -q 'catch {' "$REPO_ROOT/install.ps1.tmpl"
}

@test "install.ps1: elevated block pauses on failure" {
  grep -q 'ReadKey' "$REPO_ROOT/install.ps1.tmpl"
}

@test "install.ps1: checks LASTEXITCODE after chezmoi init" {
  # LASTEXITCODE check must appear after chezmoi init --apply
  local chezmoi_init
  chezmoi_init=$(grep -n '& \$chezmoiPath @initArgs' "$REPO_ROOT/install.ps1.tmpl" | tail -1 | cut -d: -f1)
  local exit_check
  exit_check=$(grep -n 'LASTEXITCODE' "$REPO_ROOT/install.ps1.tmpl" | tail -1 | cut -d: -f1)
  [ "$exit_check" -gt "$chezmoi_init" ]
}

@test "install.ps1: does not print Done on chezmoi failure" {
  # "Done!" must be inside a success branch (after LASTEXITCODE check), not unconditional
  ! grep -P '^\s*Write-Host.*Done!.*Green' "$REPO_ROOT/install.ps1.tmpl" | head -1 | grep -v 'else'
  grep -B5 'Done!' "$REPO_ROOT/install.ps1.tmpl" | grep -q 'LASTEXITCODE'
}

# --- install.ps1.tmpl: bw login ---

@test "install.ps1: checks bw status before login" {
  grep -q 'bw status' "$REPO_ROOT/install.ps1.tmpl"
}

@test "windows elevation helper bypasses UAC in CI" {
  grep -q '\$isCi = -not \[string\]::IsNullOrWhiteSpace(\$env:CI)' "$REPO_ROOT/home/.chezmoitemplates/windows-elevation.ps1.tmpl"
  grep -q "CI detected: running '\$Name' without UAC elevation." "$REPO_ROOT/home/.chezmoitemplates/windows-elevation.ps1.tmpl"
}

@test "install.ps1: skips bw setup when non-interactive unless forced" {
  grep -q 'ConsoleHost' "$REPO_ROOT/install.ps1.tmpl"
  grep -q 'DOTFILES_FORCE_BITWARDEN' "$REPO_ROOT/install.ps1.tmpl"
  grep -q 'Skipping Bitwarden setup: non-interactive session detected' "$REPO_ROOT/install.ps1.tmpl"
}

@test "install.ps1: prompts bw login when unauthenticated" {
  grep -q 'unauthenticated' "$REPO_ROOT/install.ps1.tmpl"
  grep -q 'bw login' "$REPO_ROOT/install.ps1.tmpl"
}

@test "install.ps1: syncs bw vault after login" {
  grep -q 'bw sync' "$REPO_ROOT/install.ps1.tmpl"
  local bw_login
  bw_login=$(grep -n 'bw login' "$REPO_ROOT/install.ps1.tmpl" | head -1 | cut -d: -f1)
  local bw_sync
  bw_sync=$(grep -n 'bw sync' "$REPO_ROOT/install.ps1.tmpl" | head -1 | cut -d: -f1)
  [ "$bw_sync" -gt "$bw_login" ]
}

# --- install.sh.tmpl: bitwarden prereqs ---

@test "setup.sh: only runs in codespaces" {
  run sh "$REPO_ROOT/setup.sh"
  [ "$status" -ne 0 ]
  [[ "$output" == *"CODESPACES=true"* ]]
}

@test "setup.sh: renders install.sh from template via chezmoi" {
  grep -q 'execute-template --file "${script_dir}/install.sh.tmpl"' "$REPO_ROOT/setup.sh"
}

@test "setup.sh: executes generated install.sh" {
  grep -q 'exec "${install_script}"' "$REPO_ROOT/setup.sh"
}

@test "install.sh: installs bitwarden-cli via brew (non-codespaces)" {
  grep -q 'brew install bitwarden-cli' "$REPO_ROOT/install.sh.tmpl"
}

@test "install.sh: bw install is gated on non-codespaces" {
  grep -q 'CODESPACES' "$REPO_ROOT/install.sh.tmpl"
}

@test "install.sh: checks bw status and prompts login" {
  grep -q 'bw status' "$REPO_ROOT/install.sh.tmpl"
  grep -q 'bw login' "$REPO_ROOT/install.sh.tmpl"
}

@test "install.sh: unlocks bw when vault is locked" {
  grep -q 'bw unlock --passwordenv BW_PASSWORD --raw' "$REPO_ROOT/install.sh.tmpl"
}

@test "bootstrap_windows: elevated block installs Chocolatey packages and provisions WSL" {
  grep -q 'choco-packages.config.tmpl' "$REPO_ROOT/home/.chezmoiscripts/run_onchange_after_bootstrap_windows.ps1.tmpl"
  grep -q 'dotfiles-choco-packages.config' "$REPO_ROOT/home/.chezmoiscripts/run_onchange_after_bootstrap_windows.ps1.tmpl"
  grep -q 'choco install "\$chocoPackagesConfig"' "$REPO_ROOT/home/.chezmoiscripts/run_onchange_after_bootstrap_windows.ps1.tmpl"
  grep -q 'choco install' "$REPO_ROOT/home/.chezmoiscripts/run_onchange_after_bootstrap_windows.ps1.tmpl"
  grep -q 'wsl --install' "$REPO_ROOT/home/.chezmoiscripts/run_onchange_after_bootstrap_windows.ps1.tmpl"
}

@test "bootstrap_windows: choco review run_onchange exists" {
  grep -q 'choco-review' "$REPO_ROOT/home/.chezmoiscripts/run_onchange_after_choco_review_windows.ps1.tmpl"
  grep -q 'UserInteractive' "$REPO_ROOT/home/.chezmoiscripts/run_onchange_after_choco_review_windows.ps1.tmpl"
}

@test "bootstrap_windows: Chocofile ignore is source-only" {
  grep -q 'Chocofile.ignore' "$REPO_ROOT/home/.chezmoiignore"
}

@test "bootstrap_windows: choco review filters genesis/dependency packages" {
  grep -q 'choco-packages.config.tmpl' "$REPO_ROOT/home/dot_scripts/executable_choco-review"
  grep -q '_dependency_packages' "$REPO_ROOT/home/dot_scripts/executable_choco-review"
  grep -q '_resolve_choco_lib_dir' "$REPO_ROOT/home/dot_scripts/executable_choco-review"
  grep -q 'grep -qxF "\\$pkg"' "$REPO_ROOT/home/dot_scripts/executable_choco-review"
  grep -q '_has_parent_package_installed' "$REPO_ROOT/home/dot_scripts/executable_choco-review"
}

@test "install.sh: skips bw setup when non-interactive unless forced" {
  grep -q '\[ ! -t 0 \] || \[ ! -t 1 \]' "$REPO_ROOT/install.sh.tmpl"
  grep -q 'DOTFILES_FORCE_BITWARDEN' "$REPO_ROOT/install.sh.tmpl"
  grep -q 'Skipping Bitwarden setup: non-interactive session detected' "$REPO_ROOT/install.sh.tmpl"
}

@test "install.sh: syncs bw vault after login" {
  grep -q 'bw sync' "$REPO_ROOT/install.sh.tmpl"
  local bw_login
  bw_login=$(grep -n 'bw login' "$REPO_ROOT/install.sh.tmpl" | head -1 | cut -d: -f1)
  local bw_sync
  bw_sync=$(grep -n 'bw sync' "$REPO_ROOT/install.sh.tmpl" | head -1 | cut -d: -f1)
  [ "$bw_sync" -gt "$bw_login" ]
}

# --- bootstrap_windows: mise error handling ---

@test "bootstrap_windows: checks LASTEXITCODE after mise install" {
  grep -A2 'mise install' "$REPO_ROOT/home/.chezmoiscripts/run_onchange_after_bootstrap_windows.ps1.tmpl" | grep -q 'LASTEXITCODE'
}

@test "bootstrap_windows: gnupg in chocolatey chezmoidata" {
  grep -q 'gnupg' "$REPO_ROOT/home/.chezmoidata/chocolatey/00-base.yaml"
}

# --- CI workflows: bot skip conditions ---

@test "test.yml: skips bot pushes to main" {
  grep -q "contains(github.actor.*bot" "$REPO_ROOT/.github/workflows/test.yml"
}

@test "megalinter.yml: skips bot pushes to main" {
  grep -q "contains(github.actor.*bot" "$REPO_ROOT/.github/workflows/megalinter.yml"
}

# --- chezmoi.bats: Windows compatibility guards ---

@test "chezmoi.bats: setup converts MSYS paths via cygpath" {
  grep -q 'cygpath' "$REPO_ROOT/tests/source/chezmoi.bats"
}

@test "chezmoi.bats: Ruby globs use File.join (no shell wildcard to native executables)" {
  # No *.yaml passed as an argument to ruby — globs must be constructed inside Ruby
  ! grep -P "ruby.*\*\.yaml" "$REPO_ROOT/tests/source/chezmoi.bats"
}
