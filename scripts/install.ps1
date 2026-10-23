param(
    [string]$Destination = "",
    [string]$InstallPath = ""
)

$ErrorActionPreference = "Stop"
$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
& "$RepoRoot\install.ps1" @PSBoundParameters
