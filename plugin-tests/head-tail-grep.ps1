# Verify head/tail/grep work in real PowerShell on Windows (issue #446).
# The opencode plugin injects Git for Windows usr/bin onto PATH for
# PowerShell shells; this test confirms the commands are usable without
# a full path and function correctly.
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

$env:PATH = "$usrBin;$env:PATH"

foreach ($cmd in @("head", "tail", "grep")) {
    if (-not (Get-Command $cmd -ErrorAction SilentlyContinue)) {
        Write-Error "$cmd not resolvable on PATH"
        exit 1
    }
}

$lines = "alpha`nbeta`ngamma"
$headOut = ($lines | & (Join-Path $usrBin "head.exe") -n 1)
if ($headOut -ne "alpha") { Write-Error "head failed: $headOut"; exit 1 }
$tailOut = ($lines | & (Join-Path $usrBin "tail.exe") -n 1)
if ($tailOut -ne "gamma") { Write-Error "tail failed: $tailOut"; exit 1 }
$grepOut = ($lines | & (Join-Path $usrBin "grep.exe") "beta")
if ($grepOut -ne "beta") { Write-Error "grep failed: $grepOut"; exit 1 }

# Also test via PATH-resolved commands from PowerShell.
$headOut2 = ($lines | head -n 1)
if ($headOut2 -ne "alpha") { Write-Error "head (PATH) failed: $headOut2"; exit 1 }
$tailOut2 = ($lines | tail -n 1)
if ($tailOut2 -ne "gamma") { Write-Error "tail (PATH) failed: $tailOut2"; exit 1 }
$grepOut2 = ($lines | grep beta)
if ($grepOut2 -ne "beta") { Write-Error "grep (PATH) failed: $grepOut2"; exit 1 }

Write-Host "head/tail/grep OK in PowerShell (Git for Windows)"
exit 0
