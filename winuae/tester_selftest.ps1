# Self-test for AmiMSX-Tester.ps1's WinUAE configs: boot a game with the
# tester's config (68030 or PiStorm), then read the default audio device's
# peak meter (Windows Core Audio) before and while it plays, and grab the
# WinUAE window. No input is sent to WinUAE.
# Usage: powershell -File winuae\tester_selftest.ps1 [-TestMode 030|PiStorm] [-Rom M_Lilly_A16.rom] [-Secs 35]
param([string]$TestMode = "030", [string]$Rom = "M_Lilly_A16.rom", [int]$Secs = 35)
$base = Split-Path -Parent $PSScriptRoot
Add-Type -AssemblyName System.Drawing
Add-Type @"
using System; using System.Runtime.InteropServices;
[Guid("A95664D2-9614-4F35-A746-DE8DB63617E6"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
interface IMMDeviceEnumerator { int NotImpl1(); int GetDefaultAudioEndpoint(int flow, int role, out IMMDevice dev); }
[Guid("D666063F-1587-4E43-81F1-B948E807363F"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
interface IMMDevice { int Activate(ref Guid iid, int ctx, IntPtr p, [MarshalAs(UnmanagedType.IUnknown)] out object o); }
[Guid("C02216F6-8C67-4B5B-9D00-D008E73E0064"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
interface IAudioMeterInformation { int GetPeakValue(out float peak); }
[ComImport, Guid("BCDE0395-E52F-467C-8E3D-C4579291692E")] class MMDeviceEnumeratorCo {}
public class Meter {
  public static float Peak(int ms) {
    var en = (IMMDeviceEnumerator)new MMDeviceEnumeratorCo(); IMMDevice dev;
    en.GetDefaultAudioEndpoint(0, 1, out dev);
    Guid iid = typeof(IAudioMeterInformation).GUID; object o;
    dev.Activate(ref iid, 23, IntPtr.Zero, out o);
    var m = (IAudioMeterInformation)o; float max = 0;
    for (int t = 0; t < ms; t += 50) { float p; m.GetPeakValue(out p); if (p > max) max = p; System.Threading.Thread.Sleep(50); }
    return max;
  }
}
public class SW {
  [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h, out RECT r);
  [DllImport("user32.dll")] static extern bool PrintWindow(IntPtr h, IntPtr hdc, uint f);
  [DllImport("user32.dll")] public static extern bool SetProcessDPIAware();
  public struct RECT { public int L, T, R, B; }
  public static void Grab(IntPtr h, string path) {
    RECT r; GetWindowRect(h, out r);
    var b = new System.Drawing.Bitmap(r.R - r.L, r.B - r.T);
    using (var g = System.Drawing.Graphics.FromImage(b)) { IntPtr dc = g.GetHdc(); PrintWindow(h, dc, 2); g.ReleaseHdc(dc); }
    var s = new System.Drawing.Bitmap(b, b.Width / 2, b.Height / 2); s.Save(path); s.Dispose(); b.Dispose();
  }
}
"@ -ReferencedAssemblies System.Drawing
[void][SW]::SetProcessDPIAware()
if (Get-Process winuae64 -ErrorAction SilentlyContinue) { throw "WinUAE is running: try again when it is free" }

# The tester's own config builder (everything before its window code).
$src = Get-Content "$PSScriptRoot\AmiMSX-Tester.ps1" -Raw
$defs = $src.Substring(0, $src.IndexOf("# --- Window"))
$defs = $defs -replace '(?s)Add-Type -AssemblyName.*?"@ -ReferencedAssemblies System.Drawing', ''
$defs = $defs -replace '\[void\]\[TW\]::SetProcessDPIAware\(\)', ''
$keepBase = $base
. ([ScriptBlock]::Create($defs))
$base = $keepBase
$seq = "$base\winuae\wb\S\Startup-Sequence"
Make-Configs
$cfg = "$base\run\Tester-$TestMode.uae"
"config: $cfg"; Get-Content $cfg | Where-Object { $_ -match '^(sound_|warp|cpu_model|cpu_speed|cachesize)' }

$quiet = [Meter]::Peak(3000)
"peak before WinUAE: {0:N3}" -f $quiet
Copy-Item "$base\build\AmiMSX" "$base\run\AmiMSX" -Force
$latin1 = [Text.Encoding]::GetEncoding(28591)
$s = [IO.File]::ReadAllText($seq, $latin1)
$s = [regex]::Replace($s, '(?m)^(; )?Run >NIL: AmiMSX:AmiMSX.*$', "Run >NIL: AmiMSX:AmiMSX `"AmiMSX:Roms/$Rom`"")
[IO.File]::WriteAllText($seq, $s, $latin1)
$p = Start-Process $winuae -ArgumentList "-f `"$cfg`"" -WorkingDirectory (Split-Path $winuae) -PassThru
Start-Sleep $Secs
$playing = [Meter]::Peak(5000)
"peak while playing ($Rom, $TestMode, after $Secs s): {0:N3}" -f $playing
$p.Refresh()
if ($p.MainWindowHandle -ne 0) { [SW]::Grab($p.MainWindowHandle, "$base\build\tester_selftest_$TestMode.png"); "screenshot: build\tester_selftest_$TestMode.png" }
$p.Kill(); $p.WaitForExit(3000) | Out-Null
if ($playing -gt [Math]::Max(0.02, $quiet * 2)) { "SOUND: OK" } else { "SOUND: not detected" }
