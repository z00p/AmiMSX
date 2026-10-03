# Boot each ROM in WinUAE via the AmiMSX CLI hook and capture the window.
# Usage: powershell -File winuae\batch_test.ps1 [-Roms a.rom,b.dsk] [-Shots 35,60]
# (.rom from run\Roms in Slot 1; .dsk from run\Disks in drive A)
param([string[]]$Roms, [string[]]$Shots = @("12", "25"), [string]$Exe = "AmiMSX",
      [int]$SpaceFrom = 0, [int]$SpaceTo = 0, [int]$SpaceEvery = 2, [int]$ExitAt = 0, [string]$Hold = "",
      [string]$Config = "AmiMSX-test.uae", [string]$WaitFile = "", [int]$MaxWait = 300, [string]$Tag = "",
      [string]$Keys = "", [int]$SnapWait = 200, [switch]$NoRun)
# -NoRun: boot without the CLI start of AmiMSX (Workbench tests: a project in
#   WBStartup starts it instead); the line is left commented out until the next run
# -Keys file.keys: scripted MSX keyboard input in the emulator (tools\keyscript.py format),
#   focus-independent; converted to run\Keys\<rom>.key and passed as AmiMSX's 2nd argument
# -Hold key@from-to[,...]: hold a key (right, left, up, down, space) e.g. "right@40-48"
# -ExitAt: press End = Amiga Help (AmiMSX: back to the menu; the trace build then dumps)
# -Config: WinUAE config in winuae\ (e.g. AmiMSX-a1200.uae)
# -WaitFile perf.bin: after the events, wait (up to -MaxWait s) until the build writes
#   run\perf.bin, then copy it to build\perf\<rom>[_<Tag>].bin
# -SpaceFrom/-SpaceTo/-SpaceEvery: press Space on that schedule (seconds after launch)
# to get past title screens; only sent while WinUAE is the foreground window.
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
  [DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();
  [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr h);
  [DllImport("user32.dll")] public static extern void keybd_event(byte vk, byte scan, uint flags, UIntPtr extra);
  public struct RECT { public int L, T, R, B; }
  [DllImport("user32.dll")] static extern bool PrintWindow(IntPtr h, IntPtr hdc, uint f);
  // The window's own content (PW_RENDERFULLCONTENT), even when it is covered
  // or not in front; on a worker thread with a timeout (it can stall in warp).
  public static string Grab(IntPtr h, string path, int timeoutMs) {
    RECT r; GetWindowRect(h, out r);
    var bmp = new System.Drawing.Bitmap(r.R - r.L, r.B - r.T);
    bool ok = false;
    var t = new System.Threading.Thread(() => {
      using (var g = System.Drawing.Graphics.FromImage(bmp)) { IntPtr dc = g.GetHdc(); ok = PrintWindow(h, dc, 2); g.ReleaseHdc(dc); } });
    t.IsBackground = true; t.Start();
    if (!t.Join(timeoutMs)) return "timeout";
    if (!ok) return "failed";
    var small = new System.Drawing.Bitmap(bmp, bmp.Width / 2, bmp.Height / 2);
    small.Save(path, System.Drawing.Imaging.ImageFormat.Png); small.Dispose(); bmp.Dispose();
    return "ok";
  }
  // Power LED lit in WinUAE's status bar (AmiMSX key-script SNAP): the "Power"
  // text is drawn brighter (212 vs 195). Saves the frame when lit.
  public static int GrabIfLed(IntPtr h, string path, int timeoutMs) {
    RECT r; GetWindowRect(h, out r);
    var bmp = new System.Drawing.Bitmap(r.R - r.L, r.B - r.T);
    bool ok = false;
    var t = new System.Threading.Thread(() => {
      using (var g = System.Drawing.Graphics.FromImage(bmp)) { IntPtr dc = g.GetHdc(); ok = PrintWindow(h, dc, 2); g.ReleaseHdc(dc); } });
    t.IsBackground = true; t.Start();
    if (!t.Join(timeoutMs) || !ok) { bmp.Dispose(); return -1; }
    // Measured on the half-size image (as saved): "Power" text max 212 lit, 195 dim.
    var small = new System.Drawing.Bitmap(bmp, bmp.Width / 2, bmp.Height / 2);
    bmp.Dispose();
    int m = 0;
    for (int y = small.Height - 14; y < small.Height - 3; y++)
      for (int x = small.Width * 69 / 100; x < small.Width * 75 / 100; x++) {
        var c = small.GetPixel(x, y);
        int v = (c.R + c.G + c.B) / 3; if (v > m) m = v;   // brightest pixel
      }
    int n = (m >= 204) ? 100 : 0;
    if (n > 20 && !string.IsNullOrEmpty(path))
      small.Save(path, System.Drawing.Imaging.ImageFormat.Png);
    small.Dispose();
    return n;
  }
}
"@ -ReferencedAssemblies System.Drawing
[void][WU]::SetProcessDPIAware()   # physical pixels for both GetWindowRect and CopyFromScreen
$seq = "$base\winuae\wb\S\Startup-Sequence"
$latin1 = [Text.Encoding]::GetEncoding(28591)
function Capture($hwnd, $path) {   # WinUAE's window content only: never other windows
  $res = [WU]::Grab($hwnd, $path, 5000)
  if ($res -ne "ok") { "capture $path : $res" }
}
foreach ($rom in $Roms) {
  $s = [IO.File]::ReadAllText($seq, $latin1)
  $dir = if ($rom -match '\.dsk$') { "Disks" } else { "Roms" }   # disk images boot from drive A (run\Disks)
  $keyArg = ""; $snaps = @()
  if ($Keys) {
    $kd = Join-Path $base "run\Keys"; New-Item -ItemType Directory -Force $kd | Out-Null
    $kn = [IO.Path]::GetFileNameWithoutExtension($rom) -replace '[\[\]]', '_'
    $snapf = Join-Path $kd "$kn.snaps"
    & python "$base\tools\keyscript.py" $Keys --amimsx (Join-Path $kd "$kn.key") --snaps $snapf | Out-Null
    if ($LASTEXITCODE -ne 0) { throw "key script $Keys" }
    $keyArg = " `"AmiMSX:Keys/$kn.key`""
    $snaps = @(Get-Content $snapf | Where-Object { $_ })
  }
  $pre = if ($NoRun) { "; " } else { "" }
  $s = [regex]::Replace($s, '(?m)^(; )?Run >NIL: AmiMSX:AmiMSX.*$', "${pre}Run >NIL: AmiMSX:AmiMSX `"AmiMSX:$dir/$rom`"$keyArg")
  [IO.File]::WriteAllText($seq, $s, $latin1)
  Get-Process winuae64 -ErrorAction SilentlyContinue | Stop-Process -Force; Start-Sleep 1
  Start-Process "C:\Program Files\WinUAE\winuae64.exe" -ArgumentList "-f `"$base\winuae\$Config`"" -WorkingDirectory "C:\Program Files\WinUAE"
  $t0 = Get-Date; $hwnd = [IntPtr]::Zero
  while ($hwnd -eq [IntPtr]::Zero -and ((Get-Date) - $t0).TotalSeconds -lt 15) {
    Start-Sleep -Milliseconds 300
    $p = Get-Process winuae64 -ErrorAction SilentlyContinue | Where-Object { $_.MainWindowHandle -ne 0 } | Select-Object -First 1
    if ($p) { $hwnd = $p.MainWindowHandle }
  }
  [void][WU]::SetWindowPos($hwnd, [IntPtr]::Zero, 300, 40, 0, 0, 5)
  $name = [IO.Path]::GetFileNameWithoutExtension($rom)
  [void][WU]::SetForegroundWindow($hwnd)
  $events = @($Shots | ForEach-Object { [pscustomobject]@{ t = $_; kind = "shot" } })
  if ($ExitAt -gt 0) { $events += [pscustomobject]@{ t = $ExitAt; kind = "exit" } }
  $keys = @{ right = @(0x27, 0x4D, 1); left = @(0x25, 0x4B, 1); up = @(0x26, 0x48, 1); down = @(0x28, 0x50, 1); space = @(0x20, 0x39, 0) }
  foreach ($h in ($Hold -split "," | Where-Object { $_ })) {
    $k, $span = $h -split "@"; $a, $b = $span -split "-"
    $events += [pscustomobject]@{ t = [int]$a; kind = "down"; key = $keys[$k] }
    $events += [pscustomobject]@{ t = [int]$b; kind = "up"; key = $keys[$k] }
  }
  if ($SpaceTo -gt $SpaceFrom) {
    for ($k = $SpaceFrom; $k -le $SpaceTo; $k += $SpaceEvery) { $events += [pscustomobject]@{ t = $k; kind = "space" } }
  }
  if ($snaps.Count -gt 0) {   # SNAP markers: capture each frozen frame (power LED lit)
    $events = @($events | Where-Object { $_.kind -ne "shot" })
    # The LED is also lit while Workbench boots: phase 0 waits for that, phase 1 for
    # it to go dark (AmiMSX running), phase 2 captures each lit (SNAP) period. While
    # lit every grab overwrites the capture, so the last one stands: in warp mode
    # WinUAE shows new frames only now and then, the frozen one eventually.
    $got = 0; $was = $false; $phase = 0
    while ($got -lt $snaps.Count -and ((Get-Date) - $t0).TotalSeconds -lt $SnapWait) {
      $p = if ($phase -lt 2) { $null } else { Join-Path $out "${name}_$($snaps[$got]).png" }
      if ($env:SNAPDEBUG) { $dbg = Join-Path $base "build\snapdbg"; New-Item -ItemType Directory -Force $dbg | Out-Null
        [void][WU]::Grab($hwnd, (Join-Path $dbg ("{0:000}.png" -f [int](((Get-Date) - $t0).TotalSeconds * 10))), 3000) }
      $n = [WU]::GrabIfLed($hwnd, $p, 3000)
      if ($env:SNAPDEBUG) { Add-Content (Join-Path $base "build\snapdbg.txt") ("{0:N1} {1} {2}" -f ((Get-Date) - $t0).TotalSeconds, $n, $was) }
      if ($phase -eq 0) { if ($n -gt 20) { $phase = 1 } }
      elseif ($phase -eq 1) { if ($n -le 20) { $phase = 2; $was = $false } }
      elseif ($n -gt 20) { $was = $true }                 # lit: (re)captured above
      elseif ($was) { $got++; $was = $false }             # went dark: that SNAP is done
      Start-Sleep -Milliseconds 120
    }
    "$name : $got of $($snaps.Count) snaps"
  }
  foreach ($e in ($events | Sort-Object t)) {
    $wait = $e.t - ((Get-Date) - $t0).TotalSeconds
    if ($wait -gt 0) { Start-Sleep -Milliseconds ([int]($wait * 1000)) }
    if ($e.kind -eq "shot") { Capture $hwnd (Join-Path $out "${name}_$($e.t)s.png") }
    elseif ($e.kind -eq "down" -or $e.kind -eq "up") {
      if ([WU]::GetForegroundWindow() -eq $hwnd) {
        $fl = 0x8 -bor $e.key[2]; if ($e.kind -eq "up") { $fl = $fl -bor 0x2 }   # scancode (+extended) (+keyup)
        [WU]::keybd_event([byte]$e.key[0], [byte]$e.key[1], [uint32]$fl, [UIntPtr]::Zero)
      }
    }
    elseif ($e.kind -eq "exit") {
      if ([WU]::GetForegroundWindow() -eq $hwnd) {
        [WU]::keybd_event(0x23, 0x4F, 0x9, [UIntPtr]::Zero)                 # End = Amiga Help (AmiMSX: quit)
        Start-Sleep -Milliseconds 400
        [WU]::keybd_event(0x23, 0x4F, 0xB, [UIntPtr]::Zero)
        Start-Sleep -Seconds 4                                                              # let the dump finish
      }
    }
    elseif ([WU]::GetForegroundWindow() -eq $hwnd) {
      [WU]::keybd_event(0x20, 0x39, 0x8, [UIntPtr]::Zero); Start-Sleep -Milliseconds 120   # Space down (scancode)
      [WU]::keybd_event(0x20, 0x39, 0xA, [UIntPtr]::Zero)                                  # Space up
    }
  }
  if ($WaitFile) {
    $wf = Join-Path "$base\run" $WaitFile; $got = $false
    while (((Get-Date) - $t0).TotalSeconds -lt $MaxWait) {
      if ((Test-Path $wf) -and (Get-Item $wf).LastWriteTime -gt $t0) { Start-Sleep 2; $got = $true; break }
      Start-Sleep 1
    }
    if ($got) {
      $pd = Join-Path $base "build\perf"; New-Item -ItemType Directory -Force $pd | Out-Null
      $suffix = if ($Tag) { "_$Tag" } else { "" }
      Copy-Item $wf (Join-Path $pd "$name$suffix.bin") -Force
      "$name$suffix.bin saved after $([int]((Get-Date) - $t0).TotalSeconds) s"
    } else { "$name : no $WaitFile within $MaxWait s" }
  }
  "$(Get-Date -Format HH:mm:ss) $rom done"
}
Get-Process winuae64 -ErrorAction SilentlyContinue | Stop-Process -Force
"ALL DONE"





