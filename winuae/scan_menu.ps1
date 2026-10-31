# Menu test for the RTG scanlines item: start AmiMSX in WinUAE with a given command line
# (e.g. a cartridge and MENU: it stays in the menu), then drive the Amiga pointer through
# WinUAE's magic mouse (the Windows cursor) from a step file, grabbing the window.
# Usage: powershell -File winuae\scan_menu.ps1 -Exe AmiMSX_x -AmiArgs '"AmiMSX:Roms/a.rom" MENU P=AmiMSX:t.prefs'
#        -Steps steps.txt [-Config AmiMSX-rtgx.uae] [-Wb wbrtg] [-Out build\menushots]
# Steps, one a line: wait <s> | move <x> <y> (client pixels) | rdown | rup | ldown | lup |
#        click <x> <y> (left) | grab <name> | key <vk hex> (press and release) |
#        rel <dx> <dy> <n> (n relative moves: the mouse captured, after a click) |
#        help (End = Amiga Help: back to the menu) | kdown <vk hex> / kup <vk hex> (hold and
#        release a key: 5C = Right Windows = Right Amiga) | front
# -Cmd: the start-up line(s) instead of "Run >NIL: AmiMSX:AmiMSX <AmiArgs>", lines separated by
#        '|' (e.g. two AmiMSX runs one after the other); -Exe is then not copied. The caller
#        puts the Startup-Sequence back afterwards (the next run's match is on the first line).
# -MaxSecs: a live session ends after this many seconds (default 900).
param([string]$Exe = "AmiMSX", [string]$AmiArgs = "", [string]$Steps, [string]$Config = "AmiMSX-rtgx.uae",
      [string]$Wb = "wbrtg", [string]$Out = "build\menushots", [string]$Cmd = "", [int]$MaxSecs = 900)
$ErrorActionPreference = "Stop"
$base = Split-Path -Parent $PSScriptRoot
$out = Join-Path $base $Out; New-Item -ItemType Directory -Force $out | Out-Null
if (-not $Cmd) { Copy-Item "$base\build\$Exe" "$base\run\AmiMSX" -Force }
Add-Type -AssemblyName System.Drawing
Add-Type @"
using System; using System.Runtime.InteropServices;
public class WUM {
  [DllImport("user32.dll")] public static extern bool SetWindowPos(IntPtr h, IntPtr a, int x, int y, int cx, int cy, uint f);
  [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h, out RECT r);
  [DllImport("user32.dll")] public static extern bool SetProcessDPIAware();
  [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr h);
  [DllImport("user32.dll")] public static extern bool SetCursorPos(int x, int y);
  [DllImport("user32.dll")] public static extern void mouse_event(uint f, int dx, int dy, uint d, UIntPtr e);
  [DllImport("user32.dll")] public static extern void keybd_event(byte vk, byte scan, uint flags, UIntPtr extra);
  public struct RECT { public int L, T, R, B; }
  public struct PT { public int X, Y; }
  [DllImport("user32.dll")] public static extern bool ClientToScreen(IntPtr h, ref PT p);
  [DllImport("user32.dll")] static extern bool PrintWindow(IntPtr h, IntPtr hdc, uint f);
  public static void Grab(IntPtr h, string path) {
    RECT r; GetWindowRect(h, out r);
    var bmp = new System.Drawing.Bitmap(r.R - r.L, r.B - r.T);
    using (var g = System.Drawing.Graphics.FromImage(bmp)) { IntPtr dc = g.GetHdc(); PrintWindow(h, dc, 2); g.ReleaseHdc(dc); }
    bmp.Save(path, System.Drawing.Imaging.ImageFormat.Png); bmp.Dispose();
  }
  public static void Move(IntPtr h, int x, int y) { PT p = new PT(); p.X = x; p.Y = y; ClientToScreen(h, ref p); SetCursorPos(p.X, p.Y); }
}
"@ -ReferencedAssemblies System.Drawing
[void][WUM]::SetProcessDPIAware()
$seq = "$base\winuae\$Wb\S\Startup-Sequence"
$latin1 = [Text.Encoding]::GetEncoding(28591)
$s = [IO.File]::ReadAllText($seq, $latin1)
$line = "Run >NIL: AmiMSX:AmiMSX $AmiArgs"
if ($Cmd) { $line = $Cmd.Replace('|', "`n") }
$s = [regex]::Replace($s, '(?m)^(; )?Run >NIL: AmiMSX:AmiMSX.*$', $line.Replace('$', '$$'))
[IO.File]::WriteAllText($seq, $s, $latin1)
Get-Process winuae64 -ErrorAction SilentlyContinue | Stop-Process -Force; Start-Sleep 1
Start-Process "C:\Program Files\WinUAE\winuae64.exe" -ArgumentList "-f `"$base\winuae\$Config`"" -WorkingDirectory "C:\Program Files\WinUAE"
$t0 = Get-Date; $hwnd = [IntPtr]::Zero
while ($hwnd -eq [IntPtr]::Zero -and ((Get-Date) - $t0).TotalSeconds -lt 15) {
  Start-Sleep -Milliseconds 300
  $p = Get-Process winuae64 -ErrorAction SilentlyContinue | Where-Object { $_.MainWindowHandle -ne 0 } | Select-Object -First 1
  if ($p) { $hwnd = $p.MainWindowHandle }
}
[void][WUM]::SetWindowPos($hwnd, [IntPtr]::Zero, 300, 40, 0, 0, 5)
[void][WUM]::SetForegroundWindow($hwnd)
# -Steps live: read commands from build\scan\live_cmd.txt as they come (one batch a file;
# the script deletes it, writes live_done.txt after; "quit" ends).
function Lines {
  if ($Steps -ne "live") { return Get-Content $Steps }
  $cf = Join-Path $base "build\scan\live_cmd.txt"; $df = Join-Path $base "build\scan\live_done.txt"
  $all = @()
  while ($true) {
    if (Test-Path $cf) { $c = Get-Content $cf; Remove-Item $cf; if ($c -contains "quit") { break }
      foreach ($l in $c) { Step $l }; Set-Content $df "done"; continue }
    Start-Sleep -Milliseconds 200
    if (((Get-Date) - $t0).TotalSeconds -gt $MaxSecs) { break }
  }
  return @()
}
function Step($line) {
  $t = ($line -split '#')[0].Trim() -split '\s+'
  if (-not $t[0]) { return }
  switch ($t[0]) {
    "wait"  { Start-Sleep -Milliseconds ([int]([double]$t[1] * 1000)) }
    "move"  { [WUM]::Move($hwnd, [int]$t[1], [int]$t[2]); Start-Sleep -Milliseconds 150 }
    "rdown" { [WUM]::mouse_event(0x8, 0, 0, 0, [UIntPtr]::Zero); Start-Sleep -Milliseconds 300 }
    "rup"   { [WUM]::mouse_event(0x10, 0, 0, 0, [UIntPtr]::Zero); Start-Sleep -Milliseconds 300 }
    "ldown" { [WUM]::mouse_event(0x2, 0, 0, 0, [UIntPtr]::Zero); Start-Sleep -Milliseconds 200 }
    "lup"   { [WUM]::mouse_event(0x4, 0, 0, 0, [UIntPtr]::Zero); Start-Sleep -Milliseconds 200 }
    "click" { [WUM]::Move($hwnd, [int]$t[1], [int]$t[2]); Start-Sleep -Milliseconds 200
              [WUM]::mouse_event(0x2, 0, 0, 0, [UIntPtr]::Zero); Start-Sleep -Milliseconds 150
              [WUM]::mouse_event(0x4, 0, 0, 0, [UIntPtr]::Zero); Start-Sleep -Milliseconds 300 }
    "key"   { $vk = [Convert]::ToByte($t[1], 16); [WUM]::keybd_event($vk, 0, 0, [UIntPtr]::Zero); Start-Sleep -Milliseconds 150
              [WUM]::keybd_event($vk, 0, 2, [UIntPtr]::Zero); Start-Sleep -Milliseconds 200 }
    "rel"   { for ($k = 0; $k -lt [int]$t[3]; $k++) { [WUM]::mouse_event(0x1, [int]$t[1], [int]$t[2], 0, [UIntPtr]::Zero); Start-Sleep -Milliseconds 15 }; Start-Sleep -Milliseconds 200 }
    "mid"   { [WUM]::mouse_event(0x20, 0, 0, 0, [UIntPtr]::Zero); Start-Sleep -Milliseconds 150; [WUM]::mouse_event(0x40, 0, 0, 0, [UIntPtr]::Zero); Start-Sleep -Milliseconds 300 }
    "kdown" { [WUM]::keybd_event([Convert]::ToByte($t[1], 16), 0, 0, [UIntPtr]::Zero); Start-Sleep -Milliseconds 150 }
    "kup"   { [WUM]::keybd_event([Convert]::ToByte($t[1], 16), 0, 2, [UIntPtr]::Zero); Start-Sleep -Milliseconds 200 }
    "front" { [void][WUM]::SetForegroundWindow($hwnd); Start-Sleep -Milliseconds 300 }
    "help"  { [WUM]::keybd_event(0x23, 0x4F, 0x9, [UIntPtr]::Zero); Start-Sleep -Milliseconds 400
              [WUM]::keybd_event(0x23, 0x4F, 0xB, [UIntPtr]::Zero); Start-Sleep -Milliseconds 300 }
    "grab"  { [WUM]::Grab($hwnd, (Join-Path $out "$($t[1]).png")); "grab $($t[1]) at $([int]((Get-Date) - $t0).TotalSeconds) s" }
  }
}
foreach ($line in (Lines)) { Step $line }
Get-Process winuae64 -ErrorAction SilentlyContinue | Stop-Process -Force
"ALL DONE"
