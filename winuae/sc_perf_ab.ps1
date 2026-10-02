# Sprite-collision PERF A/B: each title with its regression key script, builds
# AmiMSX_pnocol (no S#0 collision check) and AmiMSX_psc2, on each config.
param([string]$Configs = "030,a1200", [string]$Builds = "pnocol,psc2",
      [string]$Titles = "M_Abbaye_A8.rom=abbaye,M_Lilly_A16.rom=play,M_Barbarian_A16.rom=play,007_UridiumMSXdev14.rom=play,R2_BunGaRua.rom=bungarua,R2K_SpaceManbow.rom=play")
$base = "C:\AMD\amimsx"
foreach ($c in ($Configs -split ",")) { foreach ($t in ($Titles -split ",")) {
  $rom, $keys = $t -split "="
  foreach ($v in ($Builds -split ",")) {
    Remove-Item "$base\run\perf.bin" -ErrorAction SilentlyContinue
    & powershell -NoProfile -ExecutionPolicy Bypass -File "$base\winuae\batch_test.ps1" -Exe "AmiMSX_$v" -Config "AmiMSX-$c.uae" -Roms $rom `
      -Keys "$base\tests\keys\$keys.keys" -Shots "5" -WaitFile perf.bin -MaxWait 900 -Tag "${v}_$c" | Select-String "saved|no perf"
  }
} }
"SC PERF AB DONE"
