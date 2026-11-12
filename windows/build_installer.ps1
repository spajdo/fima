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
    $iscc = "C:\Program Files\Inno Setup 6\ISCC.exe"
}
if (-not (Test-Path $iscc)) {
    $cmd = Get-Command ISCC.exe -ErrorAction SilentlyContinue
    if ($cmd) {
        $iscc = $cmd.Source
    }
}
if ((-not $iscc -or -not (Test-Path $iscc)) -and $env:ChocolateyInstall) {
    $chocoIscc = Join-Path $env:ChocolateyInstall "bin\iscc.exe"
    if (Test-Path $chocoIscc) {
        $iscc = $chocoIscc
    }
}

if (-not $iscc -or -not (Test-Path $iscc)) {
    Write-Error "ISCC.exe not found. Please install Inno Setup 6."
    exit 1
}

if ($OutputFile) {
    $outputBase = [System.IO.Path]::GetFileNameWithoutExtension($OutputFile)
} else {
    $outputBase = "fima-$version-setup"
}

$issFile = Join-Path $ScriptDir "setup.iss"
& $iscc "/DMyAppVersion=$version" "/DMyOutputBaseFilename=$outputBase" $issFile
if ($LASTEXITCODE -ne 0) {
    Write-Error "ISCC failed with exit code $LASTEXITCODE"
    exit $LASTEXITCODE
}

$builtExe = Join-Path $ScriptDir "dist\windows\$outputBase.exe"
if (-not (Test-Path $builtExe)) {
    Write-Error "Installer binary not found at $builtExe"
    exit 1
}

if ($OutputFile) {
    if ([System.IO.Path]::IsPathRooted($OutputFile)) {
        $destExe = $OutputFile
    } else {
        $destExe = Join-Path $RootDir $OutputFile
    }
} else {
    $destExe = Join-Path $RootDir "$outputBase.exe"
}

Move-Item -Force $builtExe $destExe
Write-Host "Successfully created Windows installer: $destExe"
