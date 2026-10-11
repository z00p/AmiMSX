# AmiMSX Tester: play MSX games in AmiMSX under WinUAE, in two speed modes,
# and report problems with one click (screenshots + notes for analysis).
#
#   68030     the regression rig's 68030/50 (cycle-exact), at real speed, sound on
#   PiStorm   68040 with JIT at full speed (as close to Emu68 as WinUAE gets)
#
# Games: run\Roms (.rom, Slot 1) and run\Disks (.dsk, drive A). "Play" boots
# straight into the game; "AmiMSX menu" starts the menu, whose Slot 1 / Disk
# requesters show the same folders (AmiMSX:Roms, AmiMSX:Disks).
# Reports: reports\<time>_<game>\ (report.md, report.json, screen.png, 12 frames
# a little apart) and reports\index.csv.
#
# Shares the Workbench copy (winuae\wb) and run\AmiMSX with the test harness
# (batch_test.ps1), so it won't start WinUAE while a test run is going, and
# writes run\tester.lock while its own WinUAE runs (batch_test then waits).
# Settings saved from the AmiMSX menu (S:AmiMSX2.prefs) are moved aside when a
# session ends, so the regression keeps the built-in defaults; the next tester
# session puts them back.
Add-Type -AssemblyName System.Windows.Forms, System.Drawing
Add-Type @"
using System; using System.Runtime.InteropServices;
public class TW {
  [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h, out RECT r);
  [DllImport("user32.dll")] public static extern bool SetProcessDPIAware();
  [DllImport("user32.dll")] static extern bool PrintWindow(IntPtr h, IntPtr hdc, uint f);
  public struct RECT { public int L, T, R, B; }
  // WinUAE's own window content only (PrintWindow), never other windows.
  public static System.Drawing.Bitmap Grab(IntPtr h) {
    RECT r; GetWindowRect(h, out r);
    if (r.R - r.L < 10) return null;
    var bmp = new System.Drawing.Bitmap(r.R - r.L, r.B - r.T);
    using (var g = System.Drawing.Graphics.FromImage(bmp)) { IntPtr dc = g.GetHdc(); PrintWindow(h, dc, 2); g.ReleaseHdc(dc); }
    return bmp;
  }
}
"@ -ReferencedAssemblies System.Drawing
[void][TW]::SetProcessDPIAware()

$base = Split-Path -Parent $PSScriptRoot
$winuae = "C:\Program Files\WinUAE\winuae64.exe"
$seq = "$base\winuae\wb\S\Startup-Sequence"
$prefs = "$base\winuae\wb\S\AmiMSX2.prefs"
$prefsAside = "$base\run\AmiMSX2.prefs.tester"
$lock = "$base\run\tester.lock"
$reports = "$base\reports"
$latin1 = [Text.Encoding]::GetEncoding(28591)
$script:proc = $null; $script:game = ""; $script:mode = ""; $script:t0 = $null; $script:build = ""

function Make-Configs {
  # From the regression config (it holds the local paths): real speed and sound.
  $src = Get-Content "$base\winuae\AmiMSX-030.uae"
  $c030 = $src | ForEach-Object {
    if ($_ -match '^warp=') { 'warp=false' }
    elseif ($_ -match '^config_description=') { 'config_description=AmiMSX Tester: 68030/50 cycle-exact, real speed' }
    else { $_ } }
  Set-Content "$base\run\Tester-030.uae" $c030 -Encoding ASCII
  $drop = '^(cpu_multiplier|cpu_data_cache|cpu_cycle_exact|cpu_memory_cycle_exact|cpu_compatible|cpu_speed|cachesize|cpu_model|fpu_model|warp|config_description)='
  $cpi = @($src | Where-Object { $_ -notmatch $drop }) + @(
    'config_description=AmiMSX Tester: PiStorm-like (68040 JIT, full speed)',
    'cpu_model=68040', 'fpu_model=68040', 'cpu_compatible=false', 'cpu_cycle_exact=false',
    'cpu_memory_cycle_exact=false', 'cpu_speed=max', 'cachesize=16384', 'warp=false')
  Set-Content "$base\run\Tester-PiStorm.uae" $cpi -Encoding ASCII
}

function Get-Build {
  $c = (& git -C $base log -1 --format="%h %cd" --date=format:"%Y-%m-%d %H:%M" 2>$null)
  $t = (Get-Item "$base\build\AmiMSX").LastWriteTime.ToString("yyyy-MM-dd HH:mm")
  "build\AmiMSX of $t (commit $c)"
}

function Busy {
  $p = Get-Process winuae64 -ErrorAction SilentlyContinue
  if (-not $p) { return $false }
  if ($script:proc -and -not $script:proc.HasExited) { return $false }   # ours
  return $true
}

function Start-Session($game, $menuOnly) {
  if (Busy) {
    [Windows.Forms.MessageBox]::Show("WinUAE is already running (probably a test run of Claude's).`nWait for it to finish, then try again.", "AmiMSX Tester") | Out-Null
    return
  }
  Stop-Session
  Make-Configs
  if ((Test-Path $prefsAside) -and -not (Test-Path $prefs)) { Move-Item $prefsAside $prefs }
  Copy-Item "$base\build\AmiMSX" "$base\run\AmiMSX" -Force
  $script:build = Get-Build
  $s = [IO.File]::ReadAllText($seq, $latin1)
  if ($menuOnly) { $run = "Run >NIL: AmiMSX:AmiMSX" }
  else {
    $dir = if ($game -match '\.dsk$') { "Disks" } else { "Roms" }
    $run = "Run >NIL: AmiMSX:AmiMSX `"AmiMSX:$dir/$game`""
  }
  $s = [regex]::Replace($s, '(?m)^(; )?Run >NIL: AmiMSX:AmiMSX.*$', $run)
  [IO.File]::WriteAllText($seq, $s, $latin1)
  $cfg = if ($rbPi.Checked) { "$base\run\Tester-PiStorm.uae" } else { "$base\run\Tester-030.uae" }
  $script:mode = if ($rbPi.Checked) { "PiStorm-like (68040 JIT)" } else { "68030/50 cycle-exact" }
  $script:game = if ($menuOnly) { "(AmiMSX menu)" } else { $game }
  $script:proc = Start-Process $winuae -ArgumentList "-f `"$cfg`"" -WorkingDirectory (Split-Path $winuae) -PassThru
  Set-Content $lock $script:proc.Id
  $script:t0 = Get-Date
  $timer.Start()
}

function Stop-Session {
  if ($script:proc -and -not $script:proc.HasExited) { $script:proc.Kill(); $script:proc.WaitForExit(3000) | Out-Null }
  End-Session
}

function End-Session {
  $script:proc = $null
  Remove-Item $lock -ErrorAction SilentlyContinue
  if (Test-Path $prefs) { Move-Item $prefs $prefsAside -Force }   # keep the regression on defaults
  $timer.Stop()
  $lblStatus.Text = "Not running."
}

function WinUAE-Window {
  if (-not $script:proc -or $script:proc.HasExited) { return [IntPtr]::Zero }
  $script:proc.Refresh(); return $script:proc.MainWindowHandle
}

function Report-Issue {
  $h = WinUAE-Window
  if ($h -eq [IntPtr]::Zero) {
    [Windows.Forms.MessageBox]::Show("Start a game first: the report captures the WinUAE window.", "AmiMSX Tester") | Out-Null; return
  }
  # Capture first: the problem is on screen now. One full-size grab, then 12
  # half-size frames ~80 ms apart (flicker, sprites that come and go).
  $stamp = Get-Date -Format "yyyyMMdd-HHmmss"
  $safe = ($script:game -replace '[^\w\.\-\[\]]', '_')
  $dir = Join-Path $reports "${stamp}_$safe"
  New-Item -ItemType Directory -Force $dir | Out-Null
  $elapsed = [int]((Get-Date) - $script:t0).TotalSeconds
  $full = [TW]::Grab($h)
  if ($full) { $full.Save("$dir\screen.png", [Drawing.Imaging.ImageFormat]::Png) }
  for ($i = 0; $i -lt 12; $i++) {
    $b = [TW]::Grab($h)
    if ($b) {
      $sm = New-Object Drawing.Bitmap $b, ([int]($b.Width / 2)), ([int]($b.Height / 2))
      $sm.Save(("$dir\frame{0:D2}.png" -f $i), [Drawing.Imaging.ImageFormat]::Png); $sm.Dispose(); $b.Dispose()
    }
    Start-Sleep -Milliseconds 80
  }
  # Then the description.
  $f = New-Object Windows.Forms.Form
  $f.Text = "Report an issue: $($script:game)"; $f.Size = New-Object Drawing.Size 520, 420; $f.StartPosition = "CenterParent"
  $f.Font = New-Object Drawing.Font "Segoe UI", 10
  $l1 = New-Object Windows.Forms.Label; $l1.Text = "What kind of problem?"; $l1.Location = "12,12"; $l1.AutoSize = $true
  $cb = New-Object Windows.Forms.ComboBox; $cb.Location = "12,36"; $cb.Width = 480; $cb.DropDownStyle = "DropDownList"
  "Graphics (wrong or corrupted)", "Sprites (missing, flicker, wrong place)", "Colours", "Scrolling / split screen",
  "Sound / music", "Speed (too slow, stutter)", "Controls / keys", "Crash, hang or reset", "Won't start / load", "Other" |
    ForEach-Object { [void]$cb.Items.Add($_) }
  $cb.SelectedIndex = 0
  $l2 = New-Object Windows.Forms.Label; $l2.Text = "What happened? (what you did, what you saw, what you expected)"; $l2.Location = "12,72"; $l2.AutoSize = $true
  $tb = New-Object Windows.Forms.TextBox; $tb.Multiline = $true; $tb.ScrollBars = "Vertical"; $tb.Location = "12,96"; $tb.Size = New-Object Drawing.Size 480, 200
  $chk = New-Object Windows.Forms.CheckBox; $chk.Text = "It happens every time (reproducible)"; $chk.Location = "12,304"; $chk.AutoSize = $true
  $ok = New-Object Windows.Forms.Button; $ok.Text = "Save report"; $ok.Location = "300,336"; $ok.Width = 110; $ok.DialogResult = "OK"
  $cn = New-Object Windows.Forms.Button; $cn.Text = "Discard"; $cn.Location = "416,336"; $cn.Width = 76; $cn.DialogResult = "Cancel"
  $f.Controls.AddRange(@($l1, $cb, $l2, $tb, $chk, $ok, $cn)); $f.AcceptButton = $null; $f.CancelButton = $cn
  if ($f.ShowDialog($form) -ne "OK") { Remove-Item $dir -Recurse -Force; return }
  $r = [ordered]@{
    time = (Get-Date -Format "yyyy-MM-dd HH:mm:ss"); game = $script:game; mode = $script:mode
    seconds_into_session = $elapsed; category = $cb.SelectedItem; reproducible = $chk.Checked
    description = $tb.Text; build = $script:build; folder = $dir
  }
  $r | ConvertTo-Json | Set-Content "$dir\report.json" -Encoding UTF8
  @("# $($r.game): $($r.category)", "",
    "- **When:** $($r.time), $elapsed s into the session", "- **Mode:** $($r.mode)",
    "- **Build:** $($r.build)", "- **Reproducible:** $($r.reproducible)", "",
    $r.description, "", "Files: screen.png (full size), frame00-11.png (about 80 ms apart).") |
    Set-Content "$dir\report.md" -Encoding UTF8
  $idx = Join-Path $reports "index.csv"
  if (-not (Test-Path $idx)) { "time,game,mode,category,reproducible,folder" | Set-Content $idx -Encoding UTF8 }
  ('"{0}","{1}","{2}","{3}",{4},"{5}"' -f $r.time, $r.game, $r.mode, $r.category, $r.reproducible, (Split-Path $dir -Leaf)) |
    Add-Content $idx -Encoding UTF8
  $lblStatus.Text = "Report saved: $(Split-Path $dir -Leaf). Ask Claude to check the reports."
}

# --- Window ------------------------------------------------------------------
$form = New-Object Windows.Forms.Form
$form.Text = "AmiMSX Tester"; $form.Size = New-Object Drawing.Size 560, 640; $form.StartPosition = "CenterScreen"
$form.Font = New-Object Drawing.Font "Segoe UI", 10
$ico = "$base\winuae\AmiMSX-Tester.ico"; if (Test-Path $ico) { $form.Icon = New-Object Drawing.Icon $ico }

$grp = New-Object Windows.Forms.GroupBox; $grp.Text = "Speed mode"; $grp.Location = "12,8"; $grp.Size = New-Object Drawing.Size 520, 76
$rb030 = New-Object Windows.Forms.RadioButton; $rb030.Text = "68030 / 50 MHz (cycle-exact: the 4.0 baseline)"; $rb030.Location = "12,22"; $rb030.AutoSize = $true; $rb030.Checked = $true
$rbPi = New-Object Windows.Forms.RadioButton; $rbPi.Text = "PiStorm-like (68040 JIT, full speed)"; $rbPi.Location = "12,46"; $rbPi.AutoSize = $true
$grp.Controls.AddRange(@($rb030, $rbPi))

$lblF = New-Object Windows.Forms.Label; $lblF.Text = "Find:"; $lblF.Location = "12,98"; $lblF.AutoSize = $true
$txtF = New-Object Windows.Forms.TextBox; $txtF.Location = "60,95"; $txtF.Width = 472
$lst = New-Object Windows.Forms.ListBox; $lst.Location = "12,128"; $lst.Size = New-Object Drawing.Size 520, 330
$all = @(Get-ChildItem "$base\run\Roms" -File | Where-Object { $_.Extension -match '^\.(rom|mx1|mx2)$' } | ForEach-Object { $_.Name }) +
       @(Get-ChildItem "$base\run\Disks" -File -Filter *.dsk -ErrorAction SilentlyContinue | ForEach-Object { $_.Name })
$all = $all | Sort-Object
function Fill { $lst.BeginUpdate(); $lst.Items.Clear(); $all | Where-Object { $_ -like "*$($txtF.Text)*" } | ForEach-Object { [void]$lst.Items.Add($_) }; $lst.EndUpdate() }
$txtF.Add_TextChanged({ Fill }); Fill

$btnPlay = New-Object Windows.Forms.Button; $btnPlay.Text = "Play selected"; $btnPlay.Location = "12,468"; $btnPlay.Width = 126
$btnMenu = New-Object Windows.Forms.Button; $btnMenu.Text = "AmiMSX menu"; $btnMenu.Location = "144,468"; $btnMenu.Width = 120
$btnRep = New-Object Windows.Forms.Button; $btnRep.Text = "Report issue"; $btnRep.Location = "270,468"; $btnRep.Width = 130
$btnRep.BackColor = [Drawing.Color]::FromArgb(255, 230, 200)
$btnStop = New-Object Windows.Forms.Button; $btnStop.Text = "Stop"; $btnStop.Location = "406,468"; $btnStop.Width = 126
$lblStatus = New-Object Windows.Forms.Label; $lblStatus.Location = "12,506"; $lblStatus.Size = New-Object Drawing.Size 520, 44; $lblStatus.Text = "Not running."
$lblHelp = New-Object Windows.Forms.Label; $lblHelp.Location = "12,552"; $lblHelp.Size = New-Object Drawing.Size 520, 40
$lblHelp.Text = "Double-click a game to play. Report issue grabs the WinUAE window right away, then asks what went wrong."
$lblHelp.ForeColor = [Drawing.Color]::DimGray

$btnPlay.Add_Click({ if ($lst.SelectedItem) { Start-Session $lst.SelectedItem $false } })
$lst.Add_DoubleClick({ if ($lst.SelectedItem) { Start-Session $lst.SelectedItem $false } })
$btnMenu.Add_Click({ Start-Session "" $true })
$btnRep.Add_Click({ Report-Issue })
$btnStop.Add_Click({ Stop-Session })

$timer = New-Object Windows.Forms.Timer; $timer.Interval = 1000
$timer.Add_Tick({
  if (-not $script:proc -or $script:proc.HasExited) { End-Session; return }
  $s = [int]((Get-Date) - $script:t0).TotalSeconds
  $lblStatus.Text = "Running: $($script:game)  |  $($script:mode)  |  ${s}s`n$($script:build)"
})
$form.Add_FormClosing({ Stop-Session })
$form.Controls.AddRange(@($grp, $lblF, $txtF, $lst, $btnPlay, $btnMenu, $btnRep, $btnStop, $lblStatus, $lblHelp))
[void]$form.ShowDialog()
