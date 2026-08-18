#!powershell.exe -ExecutionPolicy Bypass -File

<#
    Regenerates the reference assemblies in ref/ from a local game installation.

    The game assemblies themselves are never committed here. Point -GameDllPath at a
    folder holding the full set, e.g. one extracted from your own install.

    Requires: dotnet tool install -g JetBrains.Refasmer.CliTool
#>

param(
    [Parameter(Mandatory = $true)]
    [string] $GameDllPath,

    [string] $OutputDir = (Join-Path $PSScriptRoot 'ref')
)

$ErrorActionPreference = 'Stop'

if (-not (Get-Command refasmer -ErrorAction SilentlyContinue))
{
    Write-Error "refasmer not found. Install it with: dotnet tool install -g JetBrains.Refasmer.CliTool"
    exit 1
}

if (-not (Test-Path $GameDllPath))
{
    Write-Error "GameDllPath not found: $GameDllPath"
    exit 1
}

# assemblies.txt is the contract: exactly the assemblies the SDK and mods reference from
# a Game folder. Runtime and BCL assemblies are intentionally absent, they come from the
# target framework.
$listFile = Join-Path $PSScriptRoot 'assemblies.txt'
$names = Get-Content $listFile | Where-Object { $_.Trim() -ne '' }
Write-Output "$($names.Count) assemblies listed in assemblies.txt"

$inputs = @()
$missing = @()
foreach ($n in $names)
{
    $p = Join-Path $GameDllPath $n
    if (Test-Path $p) { $inputs += $p } else { $missing += $n }
}

if ($missing.Count)
{
    Write-Error "Missing from ${GameDllPath}:`n  $($missing -join "`n  ")"
    exit 1
}

# Record which game build these came from. The assemblies carry no usable build stamp of
# their own, so a hash of the input set is the only reliable identifier.
$sha = [System.Security.Cryptography.SHA256]::Create()
$acc = [System.IO.MemoryStream]::new()
foreach ($p in ($inputs | Sort-Object))
{
    $h = (Get-FileHash $p -Algorithm SHA256).Hash
    $bytes = [System.Text.Encoding]::ASCII.GetBytes($h)
    $acc.Write($bytes, 0, $bytes.Length)
}
$acc.Position = 0
$setHash = ([System.BitConverter]::ToString($sha.ComputeHash($acc)) -replace '-', '').ToLower().Substring(0, 16)

if (Test-Path $OutputDir) { Remove-Item (Join-Path $OutputDir '*.dll') -Force }
New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null

# --omit-non-api-members drops private members and types that cannot be referenced from
# another assembly anyway, roughly halving the published surface. It preserves empty vs
# non-empty struct semantics. Use --all instead if you need full metadata fidelity.
Write-Output "Running refasmer over $($inputs.Count) assemblies..."
& refasmer --omit-non-api-members true -c -O $OutputDir @inputs
if ($LASTEXITCODE -ne 0)
{
    Write-Error "refasmer failed with exit code $LASTEXITCODE"
    exit 1
}

$produced = (Get-ChildItem $OutputDir -Filter *.dll)
Write-Output ""
Write-Output "Generated $($produced.Count) reference assemblies, $([int](($produced | Measure-Object Length -Sum).Sum / 1MB)) MB"
Write-Output "Input-set hash: $setHash"
Write-Output ""
Write-Output "Record that hash in README.md so it is clear which game build these match."

if ($produced.Count -ne $inputs.Count)
{
    Write-Warning "Expected $($inputs.Count) outputs but got $($produced.Count). Check the refasmer output above."
    exit 1
}
