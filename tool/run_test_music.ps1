param(
  [switch]$StageOnly,
  [int]$WebPort = 52848
)

$ErrorActionPreference = 'Stop'
$projectRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$catalog = Get-Content -LiteralPath (Join-Path $projectRoot 'assets/audio/development_songs.json') -Raw | ConvertFrom-Json
$staging = @()

# Validate all sources before staging. Copies preserve the original bytes;
# conversion, renaming, downloading and editing audio are not performed.
foreach ($track in $catalog) {
  if ($track.asset_path -notmatch '^assets/audio/[^/\\]+\.wav$') { continue }
  $fileName = [IO.Path]::GetFileName($track.asset_path)
  $source = [IO.Path]::GetFullPath((Join-Path (Join-Path $projectRoot 'Music') $fileName))
  $destination = [IO.Path]::GetFullPath((Join-Path $projectRoot $track.asset_path))
  $assetRoot = [IO.Path]::GetFullPath((Join-Path $projectRoot 'assets/audio'))
  if (-not $destination.StartsWith($assetRoot + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) { throw 'Invalid staging destination.' }
  if (-not (Test-Path -LiteralPath $source -PathType Leaf)) { throw "Existing test recording is missing: $source" }
  $hash = (Get-FileHash -LiteralPath $source -Algorithm SHA256).Hash
  if ((Test-Path -LiteralPath $destination) -and (Get-FileHash -LiteralPath $destination -Algorithm SHA256).Hash -ne $hash) { throw "An existing asset differs; it was not overwritten: $destination" }
  $staging += [pscustomobject]@{ Source = $source; Destination = $destination; Hash = $hash }
}

foreach ($track in $staging) {
  if (-not (Test-Path -LiteralPath $track.Destination)) { Copy-Item -LiteralPath $track.Source -Destination $track.Destination }
  if ((Get-FileHash -LiteralPath $track.Destination -Algorithm SHA256).Hash -ne $track.Hash) { throw 'Staged audio hash mismatch.' }
}
Write-Output ("Ready: {0} unchanged WAV test assets. Audio remains ignored by Git." -f $staging.Count)
if ($StageOnly) { return }

$flutterCommand = Get-Command flutter -ErrorAction SilentlyContinue
if ($null -ne $flutterCommand) { $flutterPath = $flutterCommand.Source }
else {
  $flutterPath = Join-Path $env:USERPROFILE 'SDK/flutter/bin/flutter.bat'
  if (-not (Test-Path -LiteralPath $flutterPath)) { throw 'Flutter was not found. Add your Flutter SDK bin directory to PATH.' }
}
Push-Location -LiteralPath $projectRoot
try {
  Write-Output 'Open Library > Songs to see Track 1 through Track 6. Click a track, then Play.'
  & $flutterPath run -d chrome --web-port=$WebPort --dart-define=ENABLE_DEVELOPMENT_AUDIO=true
  $runExit = $LASTEXITCODE
} finally { Pop-Location }
if ($runExit -ne 0) { throw "Flutter exited with code $runExit" }
