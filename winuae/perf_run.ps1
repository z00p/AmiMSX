# Speed counter runs: each ROM on each WinUAE config with the PERF build.
# Usage: powershell -File winuae\perf_run.ps1 -Configs a1200,030 [-Roms a.rom,b.rom] [-Exe AmiMSX_perf]
# Input comes from the focus-independent key script (tests\keys\play.keys):
# no real key presses, WinUAE is never brought to the front.
# Results: build\perf\<rom>_<config>.bin (decode with tools\read_perf.py).
param([string]$Configs = "a1200", [string]$Roms = "", [string]$Exe = "AmiMSX_perf", [int]$MaxWait = 400)
$default = "BombJack.rom,007_UridiumMSXdev14.rom,100_ChikubiNinja.rom,NightKnight.rom,M_Nogalious_A8.rom,M_Barbarian_A16.rom,M_Lilly_A16.rom"
if (-not $Roms) { $Roms = $default }
foreach ($c in ($Configs -split ",")) {
  foreach ($r in ($Roms -split ",")) {
    Remove-Item "$PSScriptRoot\..\run\perf.bin" -ErrorAction SilentlyContinue
    & powershell -NoProfile -ExecutionPolicy Bypass -File "$PSScriptRoot\batch_test.ps1" -Exe $Exe `
      -Config "AmiMSX-$c.uae" -Roms $r -Shots "30" -Keys "$PSScriptRoot\..\tests\keys\play.keys" `
      -WaitFile perf.bin -MaxWait $MaxWait -Tag $c
  }
}
