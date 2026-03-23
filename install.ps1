# install.ps1 — Bootstrap chezmoi dotfiles on Windows.
# Forks: update $repoUrl below to point at your fork.
# Usage (elevated PowerShell not required — script self-elevates):
#   irm https://github.com/chipwolf/dotfiles/releases/download/v1.2.0/install.ps1 | iex # x-release-please-version
# Or clone the repo and run:
#   .\install.ps1

$repoUrl = "https://github.com/chipwolf/dotfiles"
$rawBase = "https://github.com/chipwolf/dotfiles/releases/download/v1.2.0" # x-release-please-version

$ErrorActionPreference = "Stop"

# Self-elevate if not already running as administrator
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Host "Elevating to administrator..." -ForegroundColor Cyan
    $scriptPath = $MyInvocation.MyCommand.Path
    if ($scriptPath) {
        # Running from a file — re-launch the file elevated
        Start-Process powershell -Verb RunAs -ArgumentList "-ExecutionPolicy Bypass -File `"$scriptPath`"" -Wait
    } else {
        # Running via iex/pipe — re-download and re-launch elevated via a temp file
        $tmp = "$env:TEMP\dotfiles-install.ps1"
        (New-Object System.Net.WebClient).DownloadFile("$rawBase/install.ps1", $tmp)
        Start-Process powershell -Verb RunAs -ArgumentList "-ExecutionPolicy Bypass -File `"$tmp`"" -Wait
        Remove-Item $tmp -ErrorAction SilentlyContinue
    }
    exit
}

# Install Chocolatey if not present
if (-not (Get-Command choco -ErrorAction SilentlyContinue)) {
    Write-Host "Installing Chocolatey..." -ForegroundColor Cyan
    Set-ExecutionPolicy Bypass -Scope Process -Force
    [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
    Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
    $env:PATH = "$env:ALLUSERSPROFILE\chocolatey\bin;$env:PATH"
}

# Install chezmoi if not present
if (-not (Get-Command chezmoi -ErrorAction SilentlyContinue)) {
    Write-Host "Installing chezmoi..." -ForegroundColor Cyan
    choco install chezmoi -y --no-progress
    $env:PATH = [System.Environment]::GetEnvironmentVariable("PATH", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("PATH", "User")
}

# Ensure git is on PATH (chezmoi init needs it)
if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    $gitPaths = @("$env:ProgramFiles\Git\cmd", "${env:ProgramFiles(x86)}\Git\cmd", "$env:LOCALAPPDATA\Programs\Git\cmd")
    $found = $gitPaths | Where-Object { Test-Path "$_\git.exe" } | Select-Object -First 1
    if ($found) {
        Write-Host "Found git at $found, adding to PATH..." -ForegroundColor Cyan
        $env:PATH = "$found;$env:PATH"
    } else {
        Write-Host "Installing git..." -ForegroundColor Cyan
        choco install git -y --no-progress
        $env:PATH = [System.Environment]::GetEnvironmentVariable("PATH", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("PATH", "User")
    }
}

# Initialise and apply chezmoi dotfiles.
# If the script is running from a local clone, use that as the source.
# Otherwise (e.g. irm | iex), let chezmoi clone from GitHub into the default location.
$defaultSourceDir = "$env:USERPROFILE\.local\share\chezmoi"
if ($PSScriptRoot -and (Test-Path "$PSScriptRoot\.chezmoiroot")) {
    $sourceDir = $PSScriptRoot
    Write-Host "Applying chezmoi dotfiles from $sourceDir..." -ForegroundColor Cyan
    chezmoi init --apply --source="$sourceDir"
} else {
    Write-Host "Applying chezmoi dotfiles from GitHub..." -ForegroundColor Cyan
    chezmoi init --apply $repoUrl
    $sourceDir = $defaultSourceDir
}

# Disable filemode tracking (Windows does not support the executable bit)
git -C "$sourceDir" config core.fileMode false

Write-Host "Done! Restart your terminal to pick up the new configuration." -ForegroundColor Green
