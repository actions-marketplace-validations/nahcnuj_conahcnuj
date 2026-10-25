# Verify that on Windows, Git for Windows provides head/tail/grep and that
# they actually run under PowerShell (issue #446). Skips on platforms without
# Git for Windows so the same script can run harmlessly elsewhere.
$gitRoot = "C:\Program Files\Git"
if (-not (Test-Path -LiteralPath $gitRoot)) {
    Write-Host "SKIP: Git for Windows not found at $gitRoot"
    exit 0
}
$usrBin = Join-Path $gitRoot "usr\bin"
foreach ($cmd in @("head", "tail", "grep")) {
    $exe = Join-Path $usrBin "$cmd.exe"
    if (-not (Test-Path -LiteralPath $exe)) {
        Write-Error "missing: $exe"
        exit 1
    }
}

# Functional check: each command must produce the expected output.
$lines = "alpha`nbeta`ngamma"
$headOut = ($lines | & (Join-Path $usrBin "head.exe") -n 1)
if ($headOut -ne "alpha") { Write-Error "head failed: $headOut"; exit 1 }
$tailOut = ($lines | & (Join-Path $usrBin "tail.exe") -n 1)
if ($tailOut -ne "gamma") { Write-Error "tail failed: $tailOut"; exit 1 }
$grepOut = ($lines | & (Join-Path $usrBin "grep.exe") "beta")
if ($grepOut -ne "beta") { Write-Error "grep failed: $grepOut"; exit 1 }

# PATH injection parity: when the plugin puts usr/bin on PATH, the commands
# resolve from PowerShell without a full path.
$env:PATH = "$usrBin;$env:PATH"
foreach ($cmd in @("head", "tail", "grep")) {
    if (-not (Get-Command $cmd -ErrorAction SilentlyContinue)) {
        Write-Error "$cmd not resolvable on PATH"
        exit 1
    }
}
Write-Host "head/tail/grep OK (Git for Windows)"
exit 0
