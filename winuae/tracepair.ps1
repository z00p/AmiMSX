# tracepair.ps1 -N 1000000: run AmiMSX_t<N>_good and AmiMSX_t<N> on Uridium 2 until the TRACEAT freeze; dumps to build\perf\uri2_t<N>[_good].bin
param([string]$N, [int]$MaxWait = 300)
Set-Location (Split-Path -Parent $PSScriptRoot)
foreach ($e in "t${N}_good", "t$N") {
  Remove-Item run\trace.bin -ErrorAction SilentlyContinue
  powershell -NoProfile -ExecutionPolicy Bypass -File winuae\batch_test.ps1 -Exe "AmiMSX_$e" -Config AmiMSX-030.uae -Roms M_Uridium2_SCC.rom -Shots 3 -WaitFile trace.bin -MaxWait $MaxWait 2>&1 | Select-String "saved|no trace"
  Copy-Item run\trace.bin "build\perf\uri2_$e.bin" -ErrorAction SilentlyContinue
}
