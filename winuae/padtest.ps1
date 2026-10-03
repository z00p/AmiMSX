# padtest.ps1 -Names a,b: run build\AmiMSX_<name> on Uridium 2 to 30 s; BLUE = the debug-build boot hang
param([string[]]$Names)
$Names = @($Names | ForEach-Object { $_ -split "," } | Where-Object { $_ })
Set-Location (Split-Path -Parent $PSScriptRoot)
foreach ($c in $Names) {
  Remove-Item build\shots\M_Uridium2_SCC_*.png -ErrorAction SilentlyContinue
  powershell -NoProfile -ExecutionPolicy Bypass -File winuae\batch_test.ps1 -Exe "AmiMSX_$c" -Config AmiMSX-030.uae -Roms M_Uridium2_SCC.rom -Shots 30 2>&1 | Out-Null
  Copy-Item build\shots\M_Uridium2_SCC_30s.png "build\shots\pt_$c.png" -ErrorAction SilentlyContinue
  python -c "from PIL import Image, ImageStat; m=ImageStat.Stat(Image.open(r'build\shots\pt_$c.png').convert('RGB').crop((20,40,700,500))).mean; print('$c', 'BLUE' if m[2]>200 and m[0]<60 else 'ok')"
}
