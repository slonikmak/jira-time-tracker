param(
  [string]$BundlePath = 'build/windows/x64/runner/Release',
  [string]$DestinationPath = 'dist/jira-time-tracker-windows-x64.zip'
)

$ErrorActionPreference = 'Stop'
$bundle = (Resolve-Path -LiteralPath $BundlePath).Path
foreach ($required in @('jira_time_tracker.exe', 'data/app.so')) {
  if (!(Test-Path -LiteralPath (Join-Path $bundle $required))) {
    throw "Incomplete Windows release bundle: $required"
  }
}

# Application-local CRT distribution, as recommended by Flutter's Windows guide.
$vswhere = "${env:ProgramFiles(x86)}/Microsoft Visual Studio/Installer/vswhere.exe"
$visualStudio = & $vswhere -latest -products '*' -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath
if ($LASTEXITCODE -ne 0 -or !$visualStudio) { throw 'Visual Studio C++ tools not found' }
$redistVersion = (Get-Content -LiteralPath (Join-Path $visualStudio 'VC/Auxiliary/Build/Microsoft.VCRedistVersion.default.txt') -Raw).Trim()
$crt = Join-Path $visualStudio "VC/Redist/MSVC/$redistVersion/x64/Microsoft.VC143.CRT"
foreach ($library in @('msvcp140.dll', 'vcruntime140.dll', 'vcruntime140_1.dll')) {
  Copy-Item -LiteralPath (Join-Path $crt $library) -Destination $bundle -Force
}

$destination = [System.IO.Path]::GetFullPath($DestinationPath)
New-Item -ItemType Directory -Path (Split-Path $destination -Parent) -Force | Out-Null
Compress-Archive -Path "$bundle/*" -DestinationPath $destination -Force
Write-Output $destination
