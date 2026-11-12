param (
    [string]$OutputFile = ""
)

$ErrorActionPreference = "Stop"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$RootDir = Split-Path -Parent $ScriptDir

# Extract version from pubspec.yaml
$pubspecPath = Join-Path $RootDir "pubspec.yaml"
$match = (Get-Content $pubspecPath | Select-String -Pattern '^version:\s*([^\s+]+)').Matches[0]
$version = $match.Groups[1].Value

Write-Host "Building Inno Setup installer for Fima version $version..."

$iscc = "C:\Program Files (x86)\Inno Setup 6\ISCC.exe"
if (-not (Test-Path $iscc)) {
    $iscc = (Get-Command ISCC.exe -ErrorAction SilentlyContinue)?.Source
}

if (-not $iscc) {
    Write-Error "ISCC.exe not found. Please install Inno Setup 6."
    exit 1
}

$outputBase = if ($OutputFile) {
    [System.IO.Path]::GetFileNameWithoutExtension($OutputFile)
} else {
    "fima-$version-setup"
}

& $iscc "/DMyAppVersion=$version" "/DMyOutputBaseFilename=$outputBase" (Join-Path $ScriptDir "setup.iss")

$builtExe = Join-Path $ScriptDir "dist\windows\$outputBase.exe"
$destExe = if ($OutputFile) { $OutputFile } else { Join-Path $RootDir "$outputBase.exe" }

Move-Item -Force $builtExe $destExe
Write-Host "Successfully created Windows installer: $destExe"

