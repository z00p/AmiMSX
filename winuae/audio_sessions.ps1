Add-Type @"
using System; using System.Runtime.InteropServices;
[Guid("A95664D2-9614-4F35-A746-DE8DB63617E6"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
interface IMMDeviceEnumerator { int NotImpl1(); int GetDefaultAudioEndpoint(int flow, int role, out IMMDevice dev); }
[Guid("D666063F-1587-4E43-81F1-B948E807363F"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
interface IMMDevice { int Activate(ref Guid iid, int ctx, IntPtr p, [MarshalAs(UnmanagedType.IUnknown)] out object o); }
[Guid("77AA99A0-1BD6-484F-8BC7-2C654C9A9B6F"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
interface IAudioSessionManager2 { int NotImpl1(); int NotImpl2(); int GetSessionEnumerator(out IAudioSessionEnumerator e); }
[Guid("E2F5BB11-0570-40CA-ACDD-3AA01277DEE8"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
interface IAudioSessionEnumerator { int GetCount(out int n); int GetSession(int i, out IAudioSessionControl2 s); }
[Guid("bfb7ff88-7239-4fc9-8fa2-07c950be9c6d"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
interface IAudioSessionControl2 { int GetState(out int st); int a(); int b(); int c(); int d(); int e(); int f(); int g(); int h();
  int GetSessionIdentifier(IntPtr p); int GetSessionInstanceIdentifier(IntPtr p); int GetProcessId(out uint pid); }
[Guid("C02216F6-8C67-4B5B-9D00-D008E73E0064"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
interface IAudioMeterInformation { int GetPeakValue(out float peak); }
[ComImport, Guid("BCDE0395-E52F-467C-8E3D-C4579291692E")] class MMDeviceEnumeratorCo {}
public class Sess {
  public static string List() {
    var en = (IMMDeviceEnumerator)new MMDeviceEnumeratorCo(); IMMDevice dev; en.GetDefaultAudioEndpoint(0, 1, out dev);
    Guid iid = typeof(IAudioSessionManager2).GUID; object o; dev.Activate(ref iid, 23, IntPtr.Zero, out o);
    var m = (IAudioSessionManager2)o; IAudioSessionEnumerator e; m.GetSessionEnumerator(out e); int n; e.GetCount(out n);
    var sb = new System.Text.StringBuilder();
    for (int i = 0; i < n; i++) { IAudioSessionControl2 s; e.GetSession(i, out s); int st; uint pid; s.GetState(out st); s.GetProcessId(out pid);
      float pk = -1; var mi = s as IAudioMeterInformation; if (mi != null) { for (int k = 0; k < 40; k++) { float p; mi.GetPeakValue(out p); if (p > pk) pk = p; System.Threading.Thread.Sleep(50); } }
      string name = "?"; try { name = System.Diagnostics.Process.GetProcessById((int)pid).ProcessName; } catch {}
      sb.AppendFormat("pid {0} {1} state {2} peak {3:N3}\n", pid, name, st == 1 ? "ACTIVE" : (st == 0 ? "inactive" : "expired"), pk); }
    return sb.ToString();
  }
}
"@
[Sess]::List()
