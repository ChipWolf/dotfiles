# Start Komorebi + whkd. Pointed at by the HKCU Run key (configured in the
# Windows bootstrap script) and safe to invoke manually.
$ErrorActionPreference = "Stop"

# Point komorebi at our chezmoi-managed config dir. Without this komorebi
# looks in $USERPROFILE for komorebi.json and silently runs with defaults.
$env:KOMOREBI_CONFIG_HOME = Join-Path $env:USERPROFILE ".config\komorebi"

# Ensure the standard install dirs are on PATH so we can locate the binaries
# from non-login shells (where the User PATH from the installer may not be
# inherited).
$installDirs = @(
    "$env:ProgramFiles\komorebi\bin",
    "$env:ProgramFiles\whkd\bin"
) | Where-Object { Test-Path $_ }
if ($installDirs) {
    $env:PATH = ($installDirs -join ';') + ';' + $env:PATH
}

function Resolve-Cmd($name) {
    $cmd = Get-Command "$name.exe" -ErrorAction SilentlyContinue
    if (-not $cmd) { $cmd = Get-Command $name -ErrorAction SilentlyContinue }
    return $cmd.Source
}

$komorebic = Resolve-Cmd "komorebic"
$whkd      = Resolve-Cmd "whkd"

if (-not $komorebic) {
    Write-Error "komorebic not found on PATH or in $env:ProgramFiles\komorebi\bin."
    exit 1
}

if (-not (Get-Process -Name "komorebi" -ErrorAction SilentlyContinue)) {
    & $komorebic start
}

# komorebic's `--whkd` flag has been flaky; launch whkd explicitly so the
# keybindings always come up alongside komorebi.
if ($whkd -and -not (Get-Process -Name "whkd" -ErrorAction SilentlyContinue)) {
    $whkdrc = Join-Path $env:USERPROFILE ".config\whkdrc"
    if (Test-Path $whkdrc) {
        Start-Process -FilePath $whkd -ArgumentList '-c', $whkdrc -WindowStyle Hidden
    } else {
        Start-Process -FilePath $whkd -WindowStyle Hidden
    }
}
