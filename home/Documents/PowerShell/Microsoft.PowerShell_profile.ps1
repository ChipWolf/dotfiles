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

Set-Alias -Name which -Value Get-Command
Set-Alias -Name ll -Value Get-ChildItem

if (Get-Command mise -ErrorAction SilentlyContinue) {
    $miseInitScript = mise activate pwsh | Out-String
    . ([ScriptBlock]::Create($miseInitScript))
}
