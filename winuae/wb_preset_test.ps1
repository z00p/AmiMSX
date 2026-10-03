# Workbench start test for the preset icons (PREFS= ToolType, WBToolTypes):
# puts a test copy of one preset (default tool AmiMSX:AmiMSX, DONOTWAIT) into
# the test Workbench's WBStartup, boots without the CLI start (-NoRun) and
# captures the screen; the AmiMSX menu should show that preset's settings.
# Usage: powershell -File winuae\wb_preset_test.ps1 [-Preset "AmiMSX 030"] [-Shots 30] [-SpaceAt 35]
# -Exe: the build to test (default AmiMSX; the Matra splash is off unless
#   built with -DSPLASH=1, and ignores keys when started from WBStartup).
# -SpaceAt n: one Space press n s after launch (host keyboard input to the WinUAE
#   window, foreground only) to close the Matra splash a Workbench start shows.
param([string]$Preset = "AmiMSX 030", [string]$Shots = "30", [int]$SpaceAt = 0, [string]$Exe = "AmiMSX")
$ErrorActionPreference = "Stop"
$base = Split-Path -Parent $PSScriptRoot
Set-Location $base
$stage = Join-Path $base "build\wbtest"
& python tools\make_presets.py build\AmiMSX $stage --tool AmiMSX:AmiMSX --tooltype DONOTWAIT --only $Preset | Out-Null
if ($LASTEXITCODE -ne 0) { throw "make_presets" }
$wbs = Join-Path $base "winuae\wb\WBStartup"
$files = @($Preset, "$Preset.info")
foreach ($f in $files) { Copy-Item -LiteralPath (Join-Path $stage $f) -Destination $wbs -Force }
$extra = @()
if ($SpaceAt -gt 0) { $extra = @("-SpaceFrom", $SpaceAt, "-SpaceTo", ($SpaceAt + 1)) }
try {
  powershell -NoProfile -ExecutionPolicy Bypass -File winuae\batch_test.ps1 -Exe $Exe -Config AmiMSX-030.uae -Roms M_Uridium2_SCC.rom -Shots $Shots -NoRun -Tag wbtest @extra
} finally {
  foreach ($f in $files) { Remove-Item -LiteralPath (Join-Path $wbs $f) -ErrorAction SilentlyContinue }
}
