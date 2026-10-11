# AmiMSX Tester: play MSX games in AmiMSX under WinUAE, in two speed modes,
# and report problems with one click (screenshots + notes for analysis).
#
#   68030     the regression rig's 68030/50 (cycle-exact), at real speed, sound on
#             (AmiMSX's own Sound gadget: PSG by default; Konami SCC cartridges need SCC)
#   PiStorm   68040 with JIT at full speed (as close to Emu68 as WinUAE gets)
#
# Games: run\Roms (.rom, Slot 1) and run\Disks (.dsk, drive A), with title,
# developer and year from run\Roms\roms.csv (tools\make_rom_list.py; hand edits
# welcome). "Play" boots straight into the game; "Open in AmiMSX menu" puts the
# game in Slot 1 and stays in the menu (AmiMSX <cartridge> MENU) for settings
# and Power ON; with no game selected it opens the menu with Slot 1 empty.
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
$script:proc = $null; $script:game = ""; $script:title = ""; $script:mode = ""; $script:t0 = $null; $script:build = ""

# Sound for people (the regression configs stay as they are): in sync with the
# emulation, 48 kHz stereo, full volume, no automatic switching off.
$soundKeys = @('sound_output=exact', 'sound_channels=stereo', 'sound_stereo_separation=7',
               'sound_frequency=48000', 'sound_volume=0', 'sound_auto=false')

function Make-Configs {
  # From the regression config (it holds the local paths): real speed and sound.
  $src = @(Get-Content "$base\winuae\AmiMSX-030.uae" | Where-Object { $_ -notmatch '^(sound_|gfx_fullscreen_amiga=)' }) + $soundKeys
  # Fullscreen: WinUAE's borderless full-window mode (no display mode change on
  # the 4K desktop). Alt+Enter switches it in WinUAE, F12 opens WinUAE's settings.
  $src += if ($chkFull.Checked) { 'gfx_fullscreen_amiga=fullwindow' } else { 'gfx_fullscreen_amiga=false' }
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
  if (-not $game) { $run = "Run >NIL: AmiMSX:AmiMSX" }
  else {
    $dir = if ($game -match '\.dsk$') { "Disks" } else { "Roms" }
    $run = "Run >NIL: AmiMSX:AmiMSX `"AmiMSX:$dir/$game`""
    # Menu: the cartridge goes into Slot 1 and AmiMSX stays in its menu (settings,
    # Save game settings, then Power ON). Disk images have no such option: they boot.
    if ($menuOnly -and $dir -eq "Roms") { $run += " MENU" }
  }
  $s = [regex]::Replace($s, '(?m)^(; )?Run >NIL: AmiMSX:AmiMSX.*$', $run)
  [IO.File]::WriteAllText($seq, $s, $latin1)
  $cfg = if ($rbPi.Checked) { "$base\run\Tester-PiStorm.uae" } else { "$base\run\Tester-030.uae" }
  $script:mode = if ($rbPi.Checked) { "PiStorm-like (68040 JIT)" } else { "68030/50 cycle-exact" }
  $script:game = if (-not $game) { "(AmiMSX menu)" } elseif ($menuOnly) { "$game (in the menu)" } else { $game }
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
  # Then the description (a layout that scales with the display).
  $f = New-Object Windows.Forms.Form
  $f.Text = "Report an issue: $($script:game)"; $f.StartPosition = "CenterParent"
  $f.AutoScaleDimensions = New-Object Drawing.SizeF 96, 96; $f.AutoScaleMode = "Dpi"
  $f.Font = New-Object Drawing.Font "Segoe UI", 11
  $f.ClientSize = New-Object Drawing.Size 640, 470; $f.MinimumSize = New-Object Drawing.Size 520, 420
  $t = New-Object Windows.Forms.TableLayoutPanel; $t.Dock = "Fill"; $t.Padding = "12,12,12,12"; $t.ColumnCount = 1
  foreach ($k in "AutoSize", "AutoSize", "AutoSize", "Percent", "AutoSize", "AutoSize") {
    [void]$t.RowStyles.Add((New-Object Windows.Forms.RowStyle $k, 100)) }
  $l1 = New-Object Windows.Forms.Label; $l1.Text = "What kind of problem?"; $l1.AutoSize = $true
  $cb = New-Object Windows.Forms.ComboBox; $cb.Dock = "Fill"; $cb.DropDownStyle = "DropDownList"
  "Graphics (wrong or corrupted)", "Sprites (missing, flicker, wrong place)", "Colours", "Scrolling / split screen",
  "Sound / music", "Speed (too slow, stutter)", "Controls / keys", "Crash, hang or reset", "Won't start / load", "Other" |
    ForEach-Object { [void]$cb.Items.Add($_) }
  $cb.SelectedIndex = 0
  $l2 = New-Object Windows.Forms.Label; $l2.Text = "What happened? (what you did, what you saw, what you expected)"; $l2.AutoSize = $true
  $l2.Margin = "3,10,3,3"
  $tb = New-Object Windows.Forms.TextBox; $tb.Multiline = $true; $tb.ScrollBars = "Vertical"; $tb.Dock = "Fill"
  $chk = New-Object Windows.Forms.CheckBox; $chk.Text = "It happens every time (reproducible)"; $chk.AutoSize = $true
  $bp = New-Object Windows.Forms.FlowLayoutPanel; $bp.FlowDirection = "RightToLeft"; $bp.AutoSize = $true; $bp.Dock = "Fill"
  $cn = New-Object Windows.Forms.Button; $cn.Text = "Discard"; $cn.AutoSize = $true; $cn.Padding = "10,4,10,4"; $cn.DialogResult = "Cancel"
  $ok = New-Object Windows.Forms.Button; $ok.Text = "Save report"; $ok.AutoSize = $true; $ok.Padding = "10,4,10,4"; $ok.DialogResult = "OK"
  $bp.Controls.AddRange(@($cn, $ok))
  $t.Controls.AddRange(@($l1, $cb, $l2, $tb, $chk, $bp)); $f.Controls.Add($t); $f.CancelButton = $cn
  if ($f.ShowDialog($form) -ne "OK") { Remove-Item $dir -Recurse -Force; return }
  $r = [ordered]@{
    time = (Get-Date -Format "yyyy-MM-dd HH:mm:ss"); game = $script:game; title = $script:title; mode = $script:mode
    seconds_into_session = $elapsed; category = $cb.SelectedItem; reproducible = $chk.Checked
    description = $tb.Text; build = $script:build; folder = $dir
  }
  $r | ConvertTo-Json | Set-Content "$dir\report.json" -Encoding UTF8
  @("# $($r.title) ($($r.game)): $($r.category)", "",
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
# Layout panels with Dpi auto-scaling, so the window scales with the display
# (fixed pixel positions were cramped and cut off on a 4K screen at 150-200 %).
[Windows.Forms.Application]::EnableVisualStyles()
$form = New-Object Windows.Forms.Form
$form.Text = "AmiMSX Tester"; $form.StartPosition = "CenterScreen"
$form.AutoScaleDimensions = New-Object Drawing.SizeF 96, 96; $form.AutoScaleMode = "Dpi"
$form.Font = New-Object Drawing.Font "Segoe UI", 11
# Window size in logical units, times the display scale (the panels and the
# font scale by themselves).
$gfx = $form.CreateGraphics(); $dpiScale = $gfx.DpiX / 96; $gfx.Dispose()
$form.ClientSize = New-Object Drawing.Size ([int](980 * $dpiScale)), ([int](760 * $dpiScale))
$form.MinimumSize = New-Object Drawing.Size ([int](760 * $dpiScale)), ([int](560 * $dpiScale))
$ico = "$base\winuae\AmiMSX-Tester.ico"; if (Test-Path $ico) { $form.Icon = New-Object Drawing.Icon $ico }

$tl = New-Object Windows.Forms.TableLayoutPanel; $tl.Dock = "Fill"; $tl.Padding = "12,10,12,10"; $tl.ColumnCount = 1
foreach ($k in "AutoSize", "AutoSize", "Percent", "AutoSize", "AutoSize", "AutoSize") {
  [void]$tl.RowStyles.Add((New-Object Windows.Forms.RowStyle $k, 100)) }

$grp = New-Object Windows.Forms.GroupBox; $grp.Text = "Speed mode"; $grp.AutoSize = $true; $grp.Dock = "Fill"
$gf = New-Object Windows.Forms.FlowLayoutPanel; $gf.Dock = "Fill"; $gf.AutoSize = $true; $gf.FlowDirection = "TopDown"
$rb030 = New-Object Windows.Forms.RadioButton; $rb030.Text = "68030 / 50 MHz  (cycle-exact: the 4.0 baseline)"; $rb030.AutoSize = $true; $rb030.Checked = $true
$rbPi = New-Object Windows.Forms.RadioButton; $rbPi.Text = "PiStorm-like  (68040 JIT, full speed: as the BigMig)"; $rbPi.AutoSize = $true
$chkFull = New-Object Windows.Forms.CheckBox; $chkFull.Text = "Fullscreen  (Alt+Enter switches it in WinUAE; Alt+Tab back here to report an issue)"; $chkFull.AutoSize = $true
$chkFull.Margin = "3,10,3,3"
$gf.Controls.AddRange(@($rb030, $rbPi, $chkFull)); $grp.Text = "Speed mode and display"; $grp.Controls.Add($gf)

$ff = New-Object Windows.Forms.FlowLayoutPanel; $ff.AutoSize = $true; $ff.Dock = "Fill"; $ff.WrapContents = $false
$lblF = New-Object Windows.Forms.Label; $lblF.Text = "Find:"; $lblF.AutoSize = $true; $lblF.Margin = "3,7,3,3"
$txtF = New-Object Windows.Forms.TextBox; $txtF.Width = 420
$lblN = New-Object Windows.Forms.Label; $lblN.AutoSize = $true; $lblN.Margin = "12,7,3,3"; $lblN.ForeColor = [Drawing.Color]::DimGray
$ff.Controls.AddRange(@($lblF, $txtF, $lblN))

# Game list: click a column header to sort (again to reverse); blanks sort last.
$lv = New-Object Windows.Forms.ListView; $lv.View = "Details"; $lv.FullRowSelect = $true; $lv.MultiSelect = $false
$lv.HideSelection = $false; $lv.Dock = "Fill"; $lv.GridLines = $true
foreach ($c in @(@("Game", 330), @("Developer", 250), @("Year", 70), @("File", 240))) { [void]$lv.Columns.Add($c[0], [int]($c[1] * $dpiScale)) }

$meta = @{}
$csvPath = "$base\run\Roms\roms.csv"
if (Test-Path $csvPath) { Import-Csv $csvPath | ForEach-Object { $meta[$_.file] = $_ } }
$games = @()
Get-ChildItem "$base\run\Roms" -File | Where-Object { $_.Extension -match '^\.(rom|mx1|mx2)$' } | ForEach-Object {
  $m = $meta[$_.Name]
  $games += [pscustomobject]@{ File = $_.Name; Title = $(if ($m -and $m.title) { $m.title } else { $_.BaseName })
                               Developer = $(if ($m) { $m.developer } else { "" }); Year = $(if ($m) { $m.year } else { "" }) } }
Get-ChildItem "$base\run\Disks" -File -Filter *.dsk -ErrorAction SilentlyContinue | ForEach-Object {
  $games += [pscustomobject]@{ File = $_.Name; Title = "$($_.BaseName) (disk)"; Developer = ""; Year = "" } }
$keys = @("Title", "Developer", "Year", "File"); $heads = @("Game", "Developer", "Year", "File")
$script:sortKey = "Title"; $script:sortAsc = $true
function Fill {
  $q = $txtF.Text
  $rows = @($games | Where-Object { -not $q -or "$($_.Title) $($_.Developer) $($_.Year) $($_.File)" -like "*$q*" })
  $rows = @($rows | Sort-Object @{ Expression = { [string]::IsNullOrEmpty($_.($script:sortKey)) } },
                                @{ Expression = { $_.($script:sortKey) }; Descending = (-not $script:sortAsc) },
                                @{ Expression = { $_.Title } })
  $lv.BeginUpdate(); $lv.Items.Clear()
  foreach ($g in $rows) {
    $it = New-Object Windows.Forms.ListViewItem ([string]$g.Title)
    [void]$it.SubItems.Add([string]$g.Developer); [void]$it.SubItems.Add([string]$g.Year); [void]$it.SubItems.Add([string]$g.File)
    $it.Tag = $g; [void]$lv.Items.Add($it)
  }
  $lv.EndUpdate()
  for ($k = 0; $k -lt 4; $k++) {
    $lv.Columns[$k].Text = if ($keys[$k] -eq $script:sortKey) { $heads[$k] + $(if ($script:sortAsc) { "  ^" } else { "  v" }) } else { $heads[$k] }
  }
  $lblN.Text = "$($rows.Count) of $($games.Count) games"
}
$lv.Add_ColumnClick({ param($sender, $e)
  $k = $keys[$e.Column]
  if ($k -eq $script:sortKey) { $script:sortAsc = -not $script:sortAsc } else { $script:sortKey = $k; $script:sortAsc = $true }
  Fill })
$txtF.Add_TextChanged({ Fill })
function Selected { if ($lv.SelectedItems.Count) { return $lv.SelectedItems[0].Tag } }

$bf = New-Object Windows.Forms.FlowLayoutPanel; $bf.AutoSize = $true; $bf.Dock = "Fill"
function New-Btn($text) { $b = New-Object Windows.Forms.Button; $b.Text = $text; $b.AutoSize = $true; $b.Padding = "12,6,12,6"; $b.Margin = "3,6,9,3"; $b }
$btnPlay = New-Btn "Play"; $btnMenu = New-Btn "Open in AmiMSX menu"; $btnRep = New-Btn "Report issue"; $btnStop = New-Btn "Stop"
$btnRep.BackColor = [Drawing.Color]::FromArgb(255, 230, 200)
$bf.Controls.AddRange(@($btnPlay, $btnMenu, $btnRep, $btnStop))

$lblStatus = New-Object Windows.Forms.Label; $lblStatus.AutoSize = $true; $lblStatus.Text = "Not running."; $lblStatus.Margin = "3,8,3,3"
$lblHelp = New-Object Windows.Forms.Label; $lblHelp.AutoSize = $true; $lblHelp.ForeColor = [Drawing.Color]::DimGray; $lblHelp.Margin = "3,6,3,3"
$lblHelp.Text = "Play (or double-click): boots straight into the game.   Open in AmiMSX menu: the game goes into Slot 1 so you can change settings, or use Cartridges > Slot 1 > Save game settings, then Power ON.   Report issue grabs the WinUAE window at once, then asks what went wrong."
function Wrap-Labels { $w = [Math]::Max(300, $form.ClientSize.Width - 40)
  $lblHelp.MaximumSize = New-Object Drawing.Size $w, 0; $lblStatus.MaximumSize = New-Object Drawing.Size $w, 0 }
$form.Add_Resize({ Wrap-Labels })

$btnPlay.Add_Click({ $g = Selected; if ($g) { $script:title = $g.Title; Start-Session $g.File $false } })
$lv.Add_DoubleClick({ $g = Selected; if ($g) { $script:title = $g.Title; Start-Session $g.File $false } })
$btnMenu.Add_Click({ $g = Selected; if ($g) { $script:title = $g.Title; Start-Session $g.File $true } else { $script:title = ""; Start-Session "" $true } })
$btnRep.Add_Click({ Report-Issue })
$btnStop.Add_Click({ Stop-Session })

$timer = New-Object Windows.Forms.Timer; $timer.Interval = 1000
$timer.Add_Tick({
  if (-not $script:proc -or $script:proc.HasExited) { End-Session; return }
  $s = [int]((Get-Date) - $script:t0).TotalSeconds
  $who = if ($script:title) { "$($script:title)  -  $($script:game)" } else { $script:game }
  $lblStatus.Text = "Running: $who   |   $($script:mode)   |   ${s} s`n$($script:build)"
})
$form.Add_FormClosing({ Stop-Session })
$tl.Controls.AddRange(@($grp, $ff, $lv, $bf, $lblStatus, $lblHelp))
$form.Controls.Add($tl)
$form.Add_Shown({ Fill; Wrap-Labels })
[void]$form.ShowDialog()
