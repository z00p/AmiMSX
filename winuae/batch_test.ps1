# Boot each ROM in WinUAE via the AmiMSX CLI hook and capture the window.
# Usage: powershell -File winuae\batch_test.ps1 [-Roms a.rom,b.rom] [-Shots 35,60]
param([string[]]$Roms, [string[]]$Shots = @("12", "25"), [string]$Exe = "AmiMSX")
$ErrorActionPreference = "Stop"
$base = Split-Path -Parent $PSScriptRoot
# -File passes "a,b" as ONE string ("20,40,60" would even parse as the int 204060)
$Shots = @($Shots | ForEach-Object { $_ -split "," } | Where-Object { $_ } | ForEach-Object { [int]$_ })
$Roms = @($Roms | ForEach-Object { $_ -split "," } | Where-Object { $_ })   # -File passes "a,b" as one string
if (-not $Roms) { $Roms = (Get-Content "$PSScriptRoot\linear_todo.json" | ConvertFrom-Json).rom }
$out = Join-Path $base "build\shots"; New-Item -ItemType Directory -Force $out | Out-Null
Copy-Item "$base\build\$Exe" "$base\run\AmiMSX" -Force   # e.g. -Exe AmiMSX_trace
Add-Type -AssemblyName System.Drawing
Add-Type @"
using System; using System.Runtime.InteropServices;
public class WU {
  [DllImport("user32.dll")] public static extern bool SetWindowPos(IntPtr h, IntPtr a, int x, int y, int cx, int cy, uint f);
  [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h, out RECT r);
  [DllImport("user32.dll")] public static extern bool SetProcessDPIAware();
  public struct RECT { public int L, T, R, B; }
}
"@
[void][WU]::SetProcessDPIAware()   # physical pixels for both GetWindowRect and CopyFromScreen
$seq = "$base\winuae\wb\S\Startup-Sequence"
$latin1 = [Text.Encoding]::GetEncoding(28591)
function Capture($hwnd, $path) {
  $r = New-Object WU+RECT; [void][WU]::GetWindowRect($hwnd, [ref]$r)
  $bmp = New-Object Drawing.Bitmap ($r.R - $r.L), ($r.B - $r.T)
  $g = [Drawing.Graphics]::FromImage($bmp)
  $g.CopyFromScreen($r.L, $r.T, 0, 0, $bmp.Size); $g.Dispose()   # PrintWindow blocks in warp mode
  $small = New-Object Drawing.Bitmap $bmp, ([int]($bmp.Width / 2)), ([int]($bmp.Height / 2))
  $small.Save($path, [Drawing.Imaging.ImageFormat]::Png); $small.Dispose(); $bmp.Dispose()
}
foreach ($rom in $Roms) {
  $s = [IO.File]::ReadAllText($seq, $latin1)
  $s = [regex]::Replace($s, '(?m)^Run >NIL: AmiMSX:AmiMSX.*$', "Run >NIL: AmiMSX:AmiMSX `"AmiMSX:Roms/$rom`"")
  [IO.File]::WriteAllText($seq, $s, $latin1)
  Get-Process winuae64 -ErrorAction SilentlyContinue | Stop-Process -Force; Start-Sleep 1
  Start-Process "C:\Program Files\WinUAE\winuae64.exe" -ArgumentList "-f `"$base\winuae\AmiMSX-test.uae`"" -WorkingDirectory "C:\Program Files\WinUAE"
  $t0 = Get-Date; $hwnd = [IntPtr]::Zero
  while ($hwnd -eq [IntPtr]::Zero -and ((Get-Date) - $t0).TotalSeconds -lt 15) {
    Start-Sleep -Milliseconds 300
    $p = Get-Process winuae64 -ErrorAction SilentlyContinue | Where-Object { $_.MainWindowHandle -ne 0 } | Select-Object -First 1
    if ($p) { $hwnd = $p.MainWindowHandle }
  }
  [void][WU]::SetWindowPos($hwnd, [IntPtr]::Zero, 300, 40, 0, 0, 5)
  $name = [IO.Path]::GetFileNameWithoutExtension($rom)
  foreach ($t in $Shots) {
    $wait = $t - ((Get-Date) - $t0).TotalSeconds
    if ($wait -gt 0) { Start-Sleep -Seconds $wait }
    Capture $hwnd (Join-Path $out "${name}_${t}s.png")
  }
  "$(Get-Date -Format HH:mm:ss) $rom done"
}
Get-Process winuae64 -ErrorAction SilentlyContinue | Stop-Process -Force
"ALL DONE"





