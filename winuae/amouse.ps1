# Relative mouse input for a captured WinUAE window (it reads raw deltas).
# Usage: amouse.ps1 move <dx> <dy> | click | rclick
param([string]$cmd, [int]$dx = 0, [int]$dy = 0)
Add-Type @"
using System; using System.Runtime.InteropServices;
public class AM {
  [StructLayout(LayoutKind.Sequential)] public struct MI { public int dx, dy; public uint data, flags, time; public IntPtr extra; }
  [StructLayout(LayoutKind.Sequential)] public struct IN { public uint type; public MI mi; public long pad; }
  [DllImport("user32.dll")] public static extern uint SendInput(uint n, IN[] i, int size);
  public static void Send(int dx, int dy, uint flags) {
    var a = new IN[1]; a[0].type = 0; a[0].mi.dx = dx; a[0].mi.dy = dy; a[0].mi.flags = flags;
    SendInput(1, a, Marshal.SizeOf(typeof(IN)));
  }
}
"@
switch ($cmd) {
  "move" {
    # small steps so the emulator sees steady motion rather than one jump
    $steps = [math]::Max([math]::Ceiling([math]::Max([math]::Abs($dx), [math]::Abs($dy)) / 10), 1)
    for ($i = 1; $i -le $steps; $i++) {
      $sx = [int]([math]::Round($dx * $i / $steps) - [math]::Round($dx * ($i - 1) / $steps))
      $sy = [int]([math]::Round($dy * $i / $steps) - [math]::Round($dy * ($i - 1) / $steps))
      [AM]::Send($sx, $sy, 0x0001); Start-Sleep -Milliseconds 15
    }
  }
  "click"  { [AM]::Send(0, 0, 0x0002); Start-Sleep -Milliseconds 80; [AM]::Send(0, 0, 0x0004) }
  "rclick" { [AM]::Send(0, 0, 0x0008); Start-Sleep -Milliseconds 80; [AM]::Send(0, 0, 0x0010) }
}
