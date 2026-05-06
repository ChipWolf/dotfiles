if (Get-Module -ListAvailable -Name PSReadLine) {
    Set-PSReadLineOption -EditMode Windows
    if ([Environment]::UserInteractive -and -not [Console]::IsOutputRedirected) {
        Set-PSReadLineOption -PredictionSource History
        Set-PSReadLineOption -PredictionViewStyle ListView
    }
    Set-PSReadLineKeyHandler -Key Tab -Function MenuComplete
}

if (Get-Command oh-my-posh -ErrorAction SilentlyContinue) {
    $ompTheme = Join-Path $env:USERPROFILE ".config\oh-my-posh\theme.omp.json"
    if (Test-Path $ompTheme) {
        $ompInitScript = oh-my-posh init pwsh --config $ompTheme | Out-String
        . ([ScriptBlock]::Create($ompInitScript))
    }
}

$xdgConfigHome = if ($env:XDG_CONFIG_HOME) { $env:XDG_CONFIG_HOME } else { Join-Path $env:USERPROFILE ".config" }
$env:WAKATIME_HOME = if ($env:WAKATIME_HOME) { $env:WAKATIME_HOME } else { Join-Path $xdgConfigHome "wakatime" }

Set-Alias -Name which -Value Get-Command
Set-Alias -Name ll -Value Get-ChildItem

if (Get-Command mise -ErrorAction SilentlyContinue) {
    $miseInitScript = mise activate pwsh | Out-String
    . ([ScriptBlock]::Create($miseInitScript))
}

function Unlock-Bitwarden {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingWriteHost', '')]
    param()
    if (-not (Get-Command bw -ErrorAction SilentlyContinue)) {
        Write-Error "Bitwarden CLI (bw) not found in PATH."
        return
    }

    if (-not [string]::IsNullOrWhiteSpace($env:BW_SESSION)) {
        bw sync --session $env:BW_SESSION --quiet 2>$null | Out-Null
        if ($LASTEXITCODE -eq 0) {
            Write-Host "Bitwarden is already unlocked for this shell." # PSScriptAnalyzer: interactive feedback
            return
        }

        Remove-Item Env:BW_SESSION -ErrorAction SilentlyContinue
    }

    $session = bw unlock --raw
    if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($session)) {
        Write-Error "Failed to unlock Bitwarden."
        return
    }

    $env:BW_SESSION = $session.Trim()
    Write-Host "Bitwarden unlocked for this shell session." # PSScriptAnalyzer: interactive feedback
}

function Assert-BitwardenForChezmoi {
    param(
        [Parameter(Mandatory = $true)]
        [object[]]$Arguments
    )

    if (-not [string]::IsNullOrWhiteSpace($env:DOTFILES_SKIP_BITWARDEN)) {
        return
    }

    if ($Arguments.Count -eq 0) {
        return
    }

    $subcommand = "$($Arguments[0])".ToLowerInvariant()
    $isApply = $subcommand -eq "apply"
    $isInitApply = $subcommand -eq "init" -and ($Arguments -contains "--apply" -or $Arguments -contains "-a")
    if (-not ($isApply -or $isInitApply)) {
        return
    }

    Unlock-Bitwarden
    if ([string]::IsNullOrWhiteSpace($env:BW_SESSION)) {
        throw "Bitwarden unlock is required to run chezmoi apply."
    }
}

function chezmoi {
    param(
        [Parameter(ValueFromRemainingArguments = $true)]
        [object[]]$Arguments
    )

    $chezmoiCmd = Get-Command chezmoi -CommandType Application -ErrorAction SilentlyContinue
    if (-not $chezmoiCmd) {
        Write-Error "chezmoi executable not found in PATH."
        return
    }

    Assert-BitwardenForChezmoi -Arguments $Arguments
    & $chezmoiCmd.Source @Arguments
}
