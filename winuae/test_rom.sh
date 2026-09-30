#!/bin/sh
# Boot WinUAE straight into AmiMSX with a cartridge in slot 1.
# Usage: winuae/test_rom.sh <file in run/Roms>   (build first: sh build.sh)
cd "$(dirname "$0")/.." || exit 1
rom="$1"
[ -f "run/Roms/$rom" ] || { echo "no run/Roms/$rom"; exit 1; }
cp build/AmiMSX run/AmiMSX
sed -i "s|^Run >NIL: AmiMSX:AmiMSX.*|Run >NIL: AmiMSX:AmiMSX \"AmiMSX:Roms/$rom\"|" winuae/wb/S/Startup-Sequence
grep -n "^Run >NIL: AmiMSX:AmiMSX" winuae/wb/S/Startup-Sequence
taskkill //IM winuae64.exe //F >/dev/null 2>&1; sleep 1
powershell -NoProfile -Command '
Start-Process -FilePath "C:\Program Files\WinUAE\winuae64.exe" -ArgumentList "-f `"C:\AMD\amimsx\winuae\AmiMSX-test.uae`"" -WorkingDirectory "C:\Program Files\WinUAE"
Start-Sleep -Seconds 3
Add-Type "using System; using System.Runtime.InteropServices; public class WP { [DllImport(`"user32.dll`")] public static extern bool SetWindowPos(IntPtr h, IntPtr a, int x, int y, int cx, int cy, uint f); }"
$w = Get-Process winuae64 | Where-Object { $_.MainWindowHandle -ne 0 } | Select-Object -First 1
$null = [WP]::SetWindowPos($w.MainWindowHandle, [IntPtr]::Zero, 300, 40, 0, 0, 5)
"WinUAE started"'
