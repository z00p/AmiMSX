# PERF A/B: each ROM on each config with build A and build B (PERFTICKS builds), perf.bin -> build\perf\<rom>_<tag>.bin
param([string]$ExeA, [string]$ExeB, [string]$TagA = "A", [string]$TagB = "B", [string]$Roms, [string]$Configs = "030,a1200")
$base = "C:\AMD\amimsx"
foreach ($c in ($Configs -split ",")) { foreach ($r in ($Roms -split ",")) { foreach ($v in @(@($ExeA, $TagA), @($ExeB, $TagB))) {
  Remove-Item "$base\run\perf.bin" -ErrorAction SilentlyContinue
  & powershell -NoProfile -ExecutionPolicy Bypass -File "$base\winuae\batch_test.ps1" -Exe $v[0] -Config "AmiMSX-$c.uae" -Roms $r `
    -Shots "20" -WaitFile perf.bin -MaxWait 150 -Tag "$($v[1])_$c" | Select-String "saved|no perf"
} } }
"PERF AB DONE"
