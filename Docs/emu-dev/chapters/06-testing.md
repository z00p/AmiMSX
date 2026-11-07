# Testing

*Reading notes.* The AmiMSX parts of this chapter describe a test set-up for an emulator that takes over the whole machine, so it cannot be debugged from inside the operating system. The Arnold parts (real hardware over the network, the headless host, the debug switches) are in their own sections below, and so are the AmiPCEngine parts (run totals from debug rows, switch discipline, comparing with a reference emulator, the rig). Commit references name the AmiMSX development repository; the public repository carries squashed commits.

## Two loops: the PC loop and the hardware loop

### Use both loops, and keep a build reference that ties them together

**Problem.** AmiMSX is developed on a PC and used on real Amigas, and some faults exist on only one of them. The Barbarian fighters flickered on a PiStorm A1200 but not in a normal WinUAE capture. Manbow 2's title showed as black on the WinUAE 68030 configuration and as scattered fragments on the PiStorm, from one cause. A joystick adapter in CD32 mode could not be tested in WinUAE at all.

**The PC loop.**
- WinUAE runs the emulator from a script, with a key script typed inside the emulator and exact-frame captures (next sections).
- A reference emulator (openMSX with the free C-BIOS ROMs, driven by the same key scripts) gives the expected picture, register logs and VRAM dumps.
- A regression suite compares captures pixel for pixel with accepted baselines.
- Debug builds: an instruction ring (`TRACE`), an event ring (`TRACELITE`), a state dump (`STATEDUMP`), frame timing (`PERF`).
- Fast and repeatable; it finds logic faults and anything that can be compared against the reference. It cannot show what depends on the speed of the real CPU, on a real pad or on real video.

**The hardware loop.**
- A tester runs release candidates on real machines (a 68030 A1200, PiStorm, BigMig) and sends reports with photos of the screen.
- Measurement builds write their frame timings to a file that is read back on the PC (`PERF` builds; `PERFLOCAL` writes `perf.bin` to the current directory, which can be a network share).
- Later an agent drove the A1200 over the network (see "Real hardware over the network", below).
- Slow and sparse; it finds what only real hardware shows.

**Before.** A bug report said "the fighters flicker" and nothing about which build.

**After** (`tools/buildid.sh`, writing a file that the menu title and `$VER` string include):

```
#   DC.B   "13.10.2026 86e893d+"   (date, short commit, '+' = uncommitted changes)
h=$(git rev-parse --short HEAD 2>/dev/null || echo nogit)
git diff --quiet HEAD -- '*.asm' '*.s' 2>/dev/null || h="$h+"
printf '\tDC.B\t"%s %s"\n' "$(date +%d.%m.%Y)" "$h" > buildid.i
```

*Source: AmiMSX 4.0, tools/buildid.sh (freeware by Juan Antonio Gómez Gálvez; 4.x changes; used with permission).*

**Why.** The commit hash in the program's title lets any photo or report be matched to the exact source, and a trailing `+` says the build was not from a clean commit. A report is only useful if it can be reproduced in the PC loop on that same source.

**Evidence: what each loop caught.**

| Fault | PC loop | Hardware loop |
|---|---|---|
| Uridium 2 title picture | Found by a burst against the reference emulator in a regression run; the cause came from the reference emulator's register log and an event ring | |
| Gradius III scroll jumps | A 120-frame burst showed the 32-dot jump and located the cause | Reported by a tester on the A1200 first |
| Barbarian fighters | Clean in a normal capture; reproduced only with a live-view freeze | Reported on the PiStorm |
| Manbow 2 title | Black on the 68030 configuration | Fragments on the PiStorm: same cause (the frame's DMACON word) |
| Power meter boxes | Reproduced from the game's own BASIC listing | Reported with photos |
| CD32 pad detection | Could not be driven in WinUAE's harness | Failed on a real pad and an adapter |
| Colours "too bright" | Captures looked cream and white; the capture path was found to boost contrast (below) | On the A1200, a tester confirmed the corrected levels look right on a real TV (the sky salmon, as in the reference emulator); the earlier "too bright" look was only in the captures |

**Look up.** `tools/buildid.sh`; `winuae/` (configurations, `batch_test.ps1`); `Docs/regression.md`; `tools/read_perf.py` (decodes `perf.bin`: load as a percentage of an Amiga frame).

## WinUAE automation, key scripts and regression tiers

### Key scripts typed inside the emulator, with exact-frame captures

**Problem.** Wall-clock screenshots of a running emulator are not repeatable: the same game shows a different frame each run, so a pixel comparison with a baseline is meaningless.

**Before.** Screenshots taken after a fixed delay (`winuae/batch_test.ps1 -Shots`, still available).

**After** (`tests/keys/*.keys`, `tools/keyscript.py`, `KeyScrRun` and `KeySnapDo` in `AmiMSX_Main_v3.1.asm`; commit 20fa2e6). One text file drives both AmiMSX and the reference emulator:

```
14s   SPACE 5 every 100 until 30s      # Space taps past the title
32s   LEFT  5                          # hold LEFT for 5 frames
48s   LEFT  400                        # walk left for 8 s
30s   SNAP                             # capture this exact MSX frame
option sprites 1                       # AmiMSX: sprites drawn every frame
include play.keys
```

`tools/keyscript.py` turns it into 8-byte records for AmiMSX (frame, key-matrix row, mask, hold; row `$FF` is a snapshot and `$FE` an option) or into a Tcl script for openMSX, where a snapshot becomes a screenshot. On a SNAP, AmiMSX holds the finished frame with the Amiga power LED on:

```
KeySnapDo:
	MOVEM.L	D0/D2,-(SP)
	MOVE.B	$BFE001,-(SP)
	BSET	#1,$BFE201		; (DDRA: LED bit an output.)
	BCLR	#1,$BFE001		; LED on.
	...				; wait SnapPend Amiga frames
	MOVE.B	(SP)+,D0
	AND.B	#$02,D0			; LED back as it was.
	...
```

*Source: AmiMSX 4.0, tests/keys and AmiMSX_Main_v3.1.asm (freeware by Juan Antonio Gómez Gálvez; 4.x changes; used with permission).*

**Why.** The key matrix is written inside the emulator, so there is no focus problem and no input lag. Times are MSX frames from power on. The harness (`winuae/batch_test.ps1`) watches WinUAE's power-LED indicator, grabs the window while it is lit, and keeps the last grab, because in warp mode WinUAE presents frames to the window only now and then. The scripted run also starts at the top of an Amiga frame and ignores host input (chapter 05). In a SNAP the emulator freezes for a fixed number of Amiga frames and then stays frozen as long again with the LED dark, so consecutive snaps a frame apart still show as separate lit periods.

**Evidence.** A scripted run gave the same MSX state at the same frame every time: VRAM compared byte for byte at frame 1500 across two runs. Running all the captures of a title in one run matched one run per capture in 24 of 24 cases for 8 titles (a freeze once perturbed later captures, so the option for one run per capture, `--per-shot`, stays).

**Look up.** `Docs/regression.md`; `tools/keyscript.py`; commit 20fa2e6.

### The tiers, baselines and the "varies" status

**Problem.** A full run takes too long to repeat after every change, and a pixel comparison is noisy where a game is not frame-locked.

**Design** (`tools/regress.py`, `tests/titles.csv`, `Docs/coverage.md`):
- **Smoke:** 15 titles at 3 times each, about 50 minutes: the titles that broke before ("canaries") plus a greedy cover of every feature the reference emulator's scan found in use. Run it on every change.
- **Feature:** `python tools/regress.py feature:split:mode` runs every title that uses a feature; the list comes from a scan of what each title does (screen modes, splits, palette writes, VDP commands, mapper).
- **Full:** every title, before changes to the Z80 core, timing or the VDP, and at milestones.
- **Named:** `ids:a,b` for ad hoc checks.
- Each run writes a report and a side-by-side sheet (`changed.png`) of the changed titles only. A run becomes the baseline with `--accept` or `--accept-run <run>`. `--calibrate` runs a tier twice and records the captures that differ between the runs as unstable; later runs call those "varies", not "changed".

A comparison needs a baseline that is not stale. When a branch is tested against a baseline that already differs from the previous release, compare the branch's run with the previous release's run instead:

```
Against the baseline: 007_Uridium 30 s, M_Ianna 60 s, M_Zevimodoki 60 s, R2K_UsasEnh 60 s,
R2_BunGaRua 45/60 s, R2_MonsterHunter 30/45/60 s, R2_io 40/60 s and R2_Popolon 30/45/60 s "changed".
Pixel comparison against the 4.1.1 master build's smoke run: all 45 captures identical except
R2_Popolon 30/45/60 s (the new feature, expected) and R2_io 40/60 s.
```

*Source: AmiMSX 4.1.2 development notes (Docs/agent_notes/bitlogic.md, branch only); tools/regress.py (freeware by Juan Antonio Gómez Gálvez; 4.x changes; used with permission).*

**Why.** The first number says "9 titles changed"; the second says "one expected change and one unstable one". A baseline records what was accepted, not what is correct, and it ages as other changes land.

**Evidence.** The colour change produced 43 changed captures of 45; `tools/colour_only.py` showed that at least 99.8% of pixels in every pair mapped an old colour to one new colour and that content and position did not move, so the change was accepted as a whole. Another change produced 45 of 45 identical (Barbarian's page flip), which also shows that its fix did not disturb unrelated titles.

**Look up.** `Docs/regression.md`, `tools/regress.py`, `tools/colour_only.py`.

### Repeatable runs: `LD A,R` from emulated time

**Problem.** In the first full calibration 13 of 66 titles gave different pixels in two identical runs (the Zanac games, Bomb Jack, The Menace from Triton and others). The regression suite could not tell a change from noise.

**Before** (`LDAR`, AmiMSX 3.1): the Z80 refresh register read returned the Amiga's horizontal beam position.

```
LDAR:
	MOVE.B	D3,D1
	MOVE.B	$DFF007,D7		; the Amiga beam
	AND.B	#$7F,D7
```

**After** (commit 89427e6):

```
LDAR:
	MOVE.W	CurLine(A3),D1
	MULU	#57,D1			; ~M1 cycles per line (228 / 4)
	SUB.W	(A3),D1			; cycles left in the line count down
	ADD.B	RFrame,D1		; frame counter, incremented at line 0
	AND.W	#$007F,D1
	MOVE.B	D1,D7
	MOVE.B	D3,D1
```

*Source: AmiMSX 3.1 and 4.0, AmiMSX_Main_v3.1.asm (freeware by Juan Antonio Gómez Gálvez; 4.x changes; used with permission).*

**Why.** Games seed their random numbers from R. A value derived from the emulated line, the cycles left in the line and the frame count varies like a real refresh counter but is the same on every run. Making the emulator deterministic is part of making it testable.

**Evidence.** After the change, 12 of the 13 varying titles were pixel-identical across runs. The thirteenth, a disk title, differs in the phase of an animation by a few frames and stays marked unstable. A second source of noise turned out to be the disk image loader, which did not check for a short read; reading until all bytes are in, and treating a short read as an error, ended failures of four disk demos (the cause was likely, not proven, because the failures could not be reproduced).

**Look up.** Commits 89427e6, e91dac3, a5aab15; `Docs/open_issues.md`, "Run-to-run variation".

### The power LED is the harness's signal

**Problem.** A regression run with the PiStorm preset never produced a capture.

**Before.** The preset has the audio filter on, which on an Amiga is the power-LED bit: AmiMSX keeps the LED lit while a game runs.

**After.** The harness arms only after the Workbench boot has lit and then dimmed the LED, and for any scripted run the prefs copy has the filter off (`tools/make_presets.py --only "AmiMSX PiStorm"` writes the preset; the filter byte is at a fixed offset from the end of the prefs block):

```
FILTER = -5   # byte (from the end): audio filter (Amiga low-pass, the power LED bit),
              # FFh = on while a game runs
```

*Source: AmiMSX 4.1.1, tools/make_presets.py (freeware by Juan Antonio Gómez Gálvez; 4.x changes; used with permission).*

**Why.** The snapshot signal and the product feature share a hardware bit, so with the feature on the harness sees a permanently lit LED and never captures. **Evidence:** this is a behavioural fact from the notes ("no SNAP is ever captured"); the PiStorm-preset reproduction of the Barbarian fault used such a prefs copy. **Look up:** `Docs/regression.md`, "Repeatability".

## Consecutive-frame bursts against the reference emulator

### A three-shot regression cannot show a one-frame glitch

**Problem.** Flicker, a sprite missing for one frame, and a picture that jumps are all invisible in captures taken at 30, 45 and 60 s.

**Before.** Three captures a title.

**After** (`tools/burst.py`): N consecutive MSX frames from both emulators, a contact sheet, and a flicker score. AmiMSX gets a snapshot record on each of N consecutive frames:

```
for t in times:
    for k in range(n):
        f.write(f"{int(round(t * FPS)) + k} SNAP 300\n")
```

openMSX takes a screenshot every frame with throttling on. The flicker score counts pixels that go A, B, A over three consecutive frames (A different from B), averaged per frame triple on a 256 by 212 scale.

*Source: AmiMSX 4.1.2, tools/burst.py (freeware by Juan Antonio Gómez Gálvez; 4.x changes; used with permission).*

**Why.** The two emulators are not frame-locked: the same script time is close, not the same frame, and they drift apart over a minute. A burst is compared by look and by score, not by pixel. Sprite multiplexing on a real MSX also scores, so the AmiMSX score is compared with the reference emulator's score, not with zero.

**Evidence.**
- Uridium 2's title: bursts at 8 times of 3 frames, title picture identical to the reference emulator from 6 to 14 s, flicker 0 and 0.
- Gradius III Legends: 120 consecutive frames showed the 32-dot jumps in the old build and a steady 1-dot-per-3-or-4-frames scroll in the new one.
- Barbarian: 12 and 24 consecutive frames showed whether both fighters were present in each.

**Look up.** `tools/burst.py`; `tools/strip_sheet.py` (film strips); commit history of `Docs/agent_notes/`.

## Blind spots: after-render captures vs what the beam shows

### A SNAP freezes after the render, which is the one moment that is always consistent

**Problem.** Barbarian's fighters vanished on the PiStorm but never in a SNAP capture; an earlier WinUAE check (10 to 11 Oct) was clean.

**Why the captures missed it.** The captures missed it because of when they freeze, not because of the CPU. A SNAP freezes after the emulated frame has been rendered. At that moment the copper list and the bitplanes agree. On a real machine the Z80 core carries on into the next MSX frame while the beam is still drawing: a very fast CPU has already run the next frame's border (the page restore of chapter 02) by the time the beam reaches the fighters, so the beam sees the new bitplanes with the old list.

**Before** (`KeyScrSnap`, AmiMSX 4.1.1):

```
KeyScrSnap:
	CMP.L	D0,D3
	BNE.S	KeyScrNx
	MOVE.W	-2(A0),SnapPend		; Freeze after this frame's render.
```

**After** (commit 5d15cdf; debug build switch `SNAPLIVE`):

```
KeyScrSnap:
	...
	IFD	SNAPLIVE
	MOVE.W	-2(A0),SnapLvN		; (debug) Freeze at the next display start.
	ELSE
	MOVE.W	-2(A0),SnapPend		; Freeze after this frame's render.
	ENDC
...
MiraInter0:
	IFD	SNAPLIVE
	TST.W	SnapLvN
	BEQ.S	MI0NoLive
	JMP	SnapLiveDo		; the freeze happens as the display starts
MI0NoLive:
	ENDC
```

*Source: AmiMSX 4.1.2, AmiMSX_Main_v3.1.asm (freeware by Juan Antonio Gómez Gálvez; 4.x changes; used with permission).*

**Why.** With the freeze at the next display start (`MiraInter0`), the Amiga shows the copper list of the snapped frame with the bitplanes as the next frame's border left them. That is what a very fast CPU shows from the top of the screen down. It is a debug build, not the default, because the default's job is consistent captures for the regression suite.

**Evidence.** Unfixed build with the live freeze: one fighter missing in 7 of 12 consecutive frames. Fixed build: both fighters in all 12, and in 24 of 24 with the late-event path forced visible (red border). The normal post-render smoke run with the fix: 45 of 45 captures identical to the baselines. It checks that nothing else changed. It does not check the live view.

**Look up.** `SNAPLIVE`, `SnapLiveDo`, `NOL0`, `L0DEBUG`; `Docs/agent_notes/barbarian.md`.

### A script that skips the screen under test

**Problem.** The "power meter select" screen of Gradius III Legends had been broken in every version, and the whole regression suite passed.

**Before** (`tests/keys/g3l.keys`):

```
# Gradius III Legends: Space through the menus and the disk load (~80s), then play.
14s   SPACE 5 every 100 until 200s
100s  UP 30
110s  DOWN 30
```

**After** (`tests/keys/g3l_pm2.keys`, branch agents412/g3pm):

```
# The POWER METER SELECT screen comes at boot, before the title, and waits for Space;
# no Space here, DOWN every 4 s moves the box (cyclic over the 4 rows).
option machine 2
option sound 0
30s   DOWN 10 every 4s until 100s
```

*Source: AmiMSX 4.1.2 and 4.2 development, tests/keys (freeware by Juan Antonio Gómez Gálvez; 4.x changes; used with permission).*

**Why.** The game's start-up program shows a fighter selection screen before the title and waits for Space. The generic script taps Space from 14 s, which chooses the first fighter at once, so the screen was on display for a fraction of a second and was never captured. A regression suite only tests the paths its scripts take. A new test needs the key script that lingers on the screen under test, and it needs the game's own logic: here, the game's BASIC loader, listed from a copy of the disk, gave the mechanism exactly and showed that the screen's boxes are drawn and erased with XOR (chapter 03, "A command that ignored the logical operation").

**Evidence.** With the new script, WinUAE reproduced the symptom (boxes accumulating) in the old build, and the fixed build showed one box. The reference emulator never reached the screen in these runs. Smoke tier afterwards: 15 titles identical.

**Look up.** `tests/keys/g3l_pm2.keys`; notes `Docs/agent_notes/g3pm.md` (branch only).

## Capture colours: Direct3D vs GDI output

### WinUAE's default output boosts contrast and saturation

**Problem.** AmiMSX's colours looked brighter and whiter than the reference emulator's in every comparison: Barbarian's sky cream where openMSX showed salmon, Lilly's Saga's sky pure cyan.

**Before.** The harness grabbed the window with WinUAE's default Direct3D 11 output. On the test PC that image carried a strong contrast and saturation boost: about 1.74 times plus 9 per channel, clipped, with hues pushed towards the primaries. Setting WinUAE's HDR and filter options off made no difference.

**After.** A second configuration, identical except one line, selects GDI output:

```
gfx_api=directdraw
```

*Source: AmiMSX 4.1.2, winuae/AmiMSX-030gdi.uae (freeware by Juan Antonio Gómez Gálvez; 4.x changes; used with permission).*

**Why.** The GDI grab shows the Amiga register values exactly (a colour of $222 grabbed as 34, $EEE as 238, $E86 as 238,136,102). The Direct3D grab does not. A colour test ROM of 32 solid columns was used to find this: one build, one frame, three outputs.

| Colour | openMSX | AmiMSX in Direct3D 11 | AmiMSX in GDI |
|---|---|---|---|
| grey 1 | 43 | 68 | 34 |
| grey 3 | 118 | 186 | 102 |
| grey 5 | 187 | 255 | 170 |
| Barbarian sky (754) | 255,187,153 | 255,255,244 | 238,170,136 |

**Evidence.** In GDI the sky was already salmon. The grey levels were then one step dark, which was a real bug in AmiMSX (chapter 02, "3-bit levels to 4-bit nibbles"). So the "too bright" reports had two causes, a capture-path boost and a real, opposite error, and only comparing exact register values separated them. The GDI configuration was added next to the default one and not made the default, because every baseline would have changed colour.

**Later finding (a full run with GDI as the default).** In a full 84-title regression with GDI output, many captures came out black or only partly drawn: the GDI window is not always fully painted when the snapshot is taken, while the Direct3D output always gives a whole frame. So GDI is for one-off colour checks, where you look at the frame and repeat a bad grab. The regression stays on Direct3D, and its baselines are compared with each other, never with the reference emulator's colours. Lesson: before changing a capture path for a whole suite, run the full suite once with it and check that every frame is complete.

**Later finding (AmiPCEngine).** A known-colour test in that project's window grabs read `$222` as `44`, `$444` as `7F`, `$666` as `BA`, `$888` as `F5`, `$AAA` and up as `FF`, and blue `$00E` as (24,0,255). So "brighter than the reference" was the grab again, and AGA grabs came out about 1.65 times RTG grabs. The real machine's trap runs the other way. In A1200 photos black in HuZERO's picture shows as a lit grey beside a border blanked by BRDRBLNK, which is truly black, while WinUAE has true black. The level moves with camera exposure, so the reading is that the analogue black sits above blanking level in this display chain; that was not measured. In a photo, use a blanked border as the known black.

**Look up.** `winuae/AmiMSX-030gdi.uae` (`--config 030gdi` in `tools/regress.py` and `tools/burst.py`); `tools/make_colour_test.py`, `tools/colour_bars.py`; notes `Docs/agent_notes/colours.md`.

## Measuring the reference emulator by display line

### Use the frame event and the vertical-retrace flag, not the interrupt probe

**Problem.** To find where a game writes a register within the frame, the logging scripts anchored time on the reference emulator's vertical-interrupt probe. For some games the probe breakpoint never fired, so every write was logged as frame 0 with an absolute time.

**After.** Anchor each frame on the emulator's own per-frame event (`after frame`, re-armed each time). Calibrate the display line once from the game's own reads of status register 2: the vertical-retrace bit turns on at the end of the last display line. Then display line = (time since the frame event - the retrace offset) / line length + 212.

**Why.** A frame event fires whatever the game does with its interrupts. The line length matters: a V9938 line is 1368 cycles at 21.477 MHz, 63.695 microseconds. A script that divides by 64 microseconds drifts by about 1.5 lines over a frame.

**Evidence.** Jailbreak, 200 frames: the retrace bit came on at the same offset in every frame (spread 0.2 lines). That fixed the HUD palette restore at display line 231.5 in every frame, which located the fault (the emulator wrote it at line 210).

### Status-register polls tell you how long a video command is busy

Log every status-2 read with the value the game sees (read through the debugger, so the read has no side effects) and every write to the command registers. The first read with CE clear after a command starts bounds its duration from above. This gave the reference durations for the command-timing model without access to the emulator's internal tables.

## A control build separates a timing change from a regression

**Problem.** After a timing change (command busy time) 10 of 15 smoke titles changed, including an MSX1 game that never uses the video commands. The changes could have come from the timing model, from an unrelated change merged at the same time, or from layout effects.

**After.** Build the same source with the new code switched off (`-DNOCETIME=1`) and run the changed titles with it. All 10 matched the old baselines, so the timing model alone caused the shifts. Then explain the outliers: the MSX1 game shifted because the BIOS clears video memory with a block command at power-on, and that clear now takes about three frames.

**Why.** A change in emulated timing moves every later event by a few frames, and a scripted run then captures a different moment of play. Such a shift is not a fault, but you can only say so once a control run has shown that nothing else changed. Compare a few captures with the reference emulator as well: one title now matched it where it had not before.

## Live window grabs run on the wall clock, the key script on MSX frames

The harness can grab WinUAE's window back to back while the game runs (no freeze), to catch beam races that after-render captures cannot show. Its schedule is wall-clock seconds, but the key script that drives the game counts MSX frames. On a real-time config where the emulator runs below full speed (about 70% for a heavy game on a cycle-exact 68030/50), 30 s of wall clock is only about 21 s of MSX time. A first series of 200 grabs "at 30 s" showed the game's white title screen and looked like a capture failure. Schedule real-time grabs from the measured speed, or start them late and grab longer. The grab rate is about 18 per second, so a one-frame fault needs a few hundred grabs.

## Real hardware over the network (amimcp)

*Arnold.* Arnold is an ordinary AmigaOS program, so the real A1200 can be driven from the PC while the emulator runs in the operating system. This section says what that gives us and what it costs; the practical traps of the machine itself are in [chapter 11](11-test-machine.md).

**How we use it.** A small agent on the Amiga ("amimcp") lets the PC run shell commands, read and write files, take screenshots, send keys and mouse clicks, and list screens, through an MCP server. For measurements we do not drive the program interactively: the PC writes a short AmigaDOS script, the script runs the program with a fixed key script and a per-frame log (chapter 10), the results land in a directory on a network share, and a Python reader on the PC prints the figures. A run of 2250 frames takes under a minute and can be repeated, interleaved with another build, for hours.

**What it gives**
- Real numbers. WinUAE's JIT 68040 says whether the picture is right; only the PiStorm says whether the frame fits in 20 ms (chapter 10).
- Unattended runs, for example overnight, with the machine left at Workbench at the end.
- Precise logs: a time for every frame, the chip bytes written, audio underruns, the measured vertical blank time.

**What it costs**
- One machine, and turn-taking: only one session can use it at a time, and the tester wants it too. Check what is running first, and write the use in the shared coordination file (chapter 08).
- It is fragile. A reboot leaves the network down until someone goes online on the Amiga (chapter 11), and a stuck network copy can wedge every later command.
- No view of the real TV or speaker. The remote screenshot is the screen as the machine saw it (chapter 11 lists what it cannot show). Colour, flicker and sound still need the tester.
- Run-to-run noise: the same binary varies by up to about 0.6 ms a frame between runs (chapter 10), so compare builds in turn and more than once.
- Security: the agent is a remote shell on the local network protected by a token. Use it only on a home network that you trust.

**Practicalities.** The ones that cost us time are collected in [chapter 11](11-test-machine.md): [programs started with `Run` do not get the shell's stack](11-test-machine.md#a-program-started-with-run-does-not-get-the-shells-stack), [brackets in paths act as wildcards](11-test-machine.md#brackets-are-wildcards-for-copy-and-list), [what the remote screenshot cannot see](11-test-machine.md#driving-the-screen-remotely), [the network after a reboot](11-test-machine.md#after-a-reboot-the-network-may-stay-down), and [starting an icon from a script](11-test-machine.md#starting-a-workbench-icon-from-a-script).

**Look up.** `tools/vscroll/a1200_run.sh` and `tools/sprites/stats.py` in the development repository; notes `SONIC-SPEED.md`, `PERF50.md`; chapter 08 for how to brief an agent to use it.

## Debug rows on the screen: measuring from a photo

*AmiMSX.* When the emulator takes over the machine (the operating system is stopped during play), there is no network, no file and no log to read back. What there always is: the tester, a phone camera, and the screen. So a debug build draws a few rows of hex numbers over the top of the picture, every frame, and the tester sends a photo. It needs no harness, works on any machine you can borrow, and the numbers belong to exactly what was on screen at that moment.

**Problem.** Space Manbow 2 on the RTG output of the PiStorm A1200 "sounded slower" than on AGA. WinUAE's RTG config runs a JIT 68040 at full speed, so it could not show it. We had to know whether the A1200 was short of time, and where the time went.

**Before:** a guess from the sound, and a video at 25 fps that cannot show a 70% frame rate.

**After** (`AmiMSX_Rtg_v4.asm`, AmiMSX 4.5 development, switch `RTGDBG`): a speed row, counted per window of 50 Amiga vertical blanks and drawn in a 3x5-dot hex font straight into the screen memory:

    RtgDbSpd:                       ; every MSX frame, also on frames drawn elsewhere
        ADDQ.W  #1,RdMsx            ; MSX frames in this window
        ...                         ; + frames drawn on RTG / on AGA
        MOVE.W  FMXVbl,D0           ; vertical blanks since the window began
        SUB.W   RdV0,D0
        CMP.W   #50,D0
        BCS.S   .draw               ; window not over: draw the last result
        LEA     RdOut,A0            ; window over: latch the counts, clear them
        MOVE.W  RdMsx,(A0)+
        ...
        MOVE.W  RdFlush,(A0)+       ; time spent in section 1
        MOVE.W  RdRend,(A0)+        ; time spent in section 2
    .draw:  ...                     ; the latched values as hex glyphs, row 58

*Source: AmiMSX 4.5 development, AmiMSX_Rtg_v4.asm (freeware, used with permission).*

The row reads `0023 0023 0000 0000 0032 2A84 063D`: 35 MSX frames per 50 blanks (70% speed), all 35 drawn on RTG, none on AGA, no spare time in the frame wait, 50 blanks, then the two section times.

**Why it works.** A count per fixed window (50 blanks = 1 s) gives a steady number that a photo can catch; per-frame values flicker too fast to read. Counting the frames by where they were drawn shows at once whether the slow path is even in use. A "spare time" count (loop turns in the frame wait, divided by 256) separates "short of CPU" (0000) from "waiting on something else" (a large value with fewer frames).

**Timing sections.** Read a free-running counter at the start and end of each section and add the difference to a word per window. Our first timer was `FMXVbl * 313 + the beam line from VPOSR/VHPOSR`. It assumed a 313-line PAL frame, and that the blank counter moves on at line 0. Under RTG the native display was not that, and a section that never runs read `F30F` (a sum of negative steps). The big values were still usable for ranking (the section that copies the AGA planes back to MSX video memory took about 7 times the RTG drawing, which settled the design question), but the small ones were nonsense. For a timer that does not care about the display mode, use the CIA-B time-of-day counter, which counts horizontal syncs (`$BFDA00` high, `$BFD900` middle, `$BFD800` low; read the high byte first and the low byte last). Also show the window's own total, so each section can be read as a share of the time.

**Evidence.** On the A1200: the title 0032 frames (full speed), starfield 0032 with spare time, stage 1 walls 0023 with none. Section times: copy-back about 2A80h against about 0635h for the drawing. WinUAE could show none of this.

**Tips.**
- Put the values in a fixed order, write the legend in the tester's checklist ("the 3rd row: 1st = MSX frames, 0032 = full speed"), and keep a build reference in the menu title so the photo also says which build it was.
- Keep the rows to the top few lines of the picture and draw them on every frame, also on frames the debug display does not otherwise own.
- Make it a build switch, so the release binary stays byte-identical apart from the build reference.
- Ask for one photo early and one later in the same scene: rising time shows up as a falling first number.

**Look up.** AmiMSX `Docs/agent_notes/v45_rtg.md` (29 Oct 2026 entries); switch `RTGDBG`; the speed row commit e1cb289, section timers 2097120.

### Add the windows up: run totals in a result file

*AmiPCEngine.* A photo of the debug rows shows one second of one scene. A sweep over titles and settings needs a figure for the whole run, without anyone holding a camera.

**Problem.** The question was whether more RTG speed work was worth doing on the PiStorm A1200. That takes the same rows for 8 titles with 2 settings, on the real machine, unattended.

**Before** (`src/DbgRows.asm`, AmiPCEngine 1.1): the rows are latched per window of 50 vblanks, drawn on the screen, and lost.

**After** (commit a44eae7, build with both `DbgRows` and `AutoExit`): each window's figures are added to run totals, and the run's extremes are kept. AutoExit test builds quit after a set number of frames, give the operating system back and write a result file, so the totals go there:

	DbgAutoSum:
		...
		LEA	DbgOut,A0
		LEA	DbgAuto,A1
		MOVEQ	#13-1,D1
	.a:	MOVEQ	#0,D0
		MOVE.W	(A0)+,D0
		ADD.L	D0,(A1)+
		DBF	D1,.a
		MOVE.W	DbgOut+22,D0		; longest frame of the run
		CMP.L	(A1),D0
		BLS.S	.nw
		MOVE.L	D0,(A1)
	.nw:	ADDQ.L	#4,A1
		MOVE.W	DbgOut+4,D0		; least spare time in one window
		...

*Source: AmiPCEngine development after 1.1, src/DbgRows.asm (freeware by Juan Antonio Gómez Gálvez and z00p; used with permission).*

and the run script on the PC prints each share of all lines:

	pc = lambda k: 100 * v.get(k, 0) / v["totl"]
	line = (f"  scan {v.get('scan', 0)} busy {100 - pc('wait'):5.1f}%  cpu {pc('cpu_'):5.1f}  rtg {pc('rtg_'):5.1f}"
	        f"  copy {pc('copy'):5.1f}  vbli {pc('vbli'):5.1f}  othr {pc('othr'):5.1f}  late {v.get('late', 0)}"
	        ...

*Source: AmiPCEngine development after 1.1, tools/a1200run.py (used with permission).*

**Why.** A total of lines spent waiting, divided by all lines, gives "busy" as a share of the machine, the one figure that says how much room is left. Keeping the tightest window as well as the total stops a good average from hiding one bad second. The counters are the same CIA-B lines as the rows, so a photo and a result file can be compared, and neither the default nor the Debug binary changes.

**Evidence.** 16 runs on the A1200: no late frame, frames = vblanks in all, and busy between 12.8% and 28.0% of all lines. The table and what it changed are in [chapter 12](12-rtg.md#measure-before-tuning-rtg-is-busy-13-to-28-of-the-frame-on-a-pistorm). One figure was explained only in part: 'worst' read about 1800 lines in every run with no late frame at all. It looks like the first frame after the counters start, which was not checked further. A figure that is the same in every run is more likely the rig than the game.

**Look up.** Commit a44eae7; `DbgAutoSum`, `DbgAutoFill`; `tools/a1200run.py --args`; STATUS, "RTG speed sweep".

**A trap with debug rows.** The panel takes lines, so a debug build moves the picture. In a photo of an AGA debug build, Parodius' lives and score row was off the bottom of the display. On NTSC the row landed at about line 268, past the end of a 262-line frame. A normal build shows it. WinUAE's 313-line PAL window showed it both ways, so only the real machine showed the loss. Before calling a photo of a debug build a fault, look at a normal build.

## When the rows say "slow" but not why: probe counters, then a state dump

*AmiPCEngine.* The speed rows above showed that Parodius on AGA was redrawing the whole background every frame after a flash bomb (17 of 51 frames, background time up tenfold). They could not say why. Two more steps found it in three test rounds, without anyone describing the screen.

**Step 1: counters that name the cause.** A probe build (switch `DbgProbe`) replaces one debug row with counts for one frame: cells redrawn because their map word changed, cells redrawn because their tile was written, how many tiles were written and the lowest and highest of them, the CPU and DMA writes to video RAM, and how many written bytes actually changed. Each count is one `ADDQ` at the decision it explains:

	CMP.W	(A5)+,(A6)+		; map word as last drawn?
	BNE.S	.pBat			; probe: count, then redraw
	TST.B	([A7])			; tile written since?
	BNE.S	.pTil
	...
	.pBat:	ADDQ.W	#1,PrbBat
		BRA.S	.PrtGfxRut
	.pTil:	ADDQ.W	#1,PrbTil
		BRA.S	.PrtGfxRut

The first photo ruled out half the theories at once: 0 map changes, about 466 cells redrawn for written tiles, 17 tiles written each frame. The second build added the "bytes changed" count, which showed the rewrites were almost all of the same values. A fix for that went into the third build, and it helped only a little, so the cause was still elsewhere.

**Step 2: a dump of the guest state, read on the PC.** The next build kept a copy of the guest's video RAM, redraw flags, video registers and palette each frame, the last two frames. When the tester pressed Esc, with the operating system back, it wrote them to a file in the program's own drawer:

	PrbDumpWrite:				; Esc, OS alive
		...				; dos.library Open(PROGDIR:pcevram.bin, MODE_NEWFILE)
		MOVE.L	PrbSnapNew,D2		; newest frame: VRAM 64K, flags 2K, regs, palette
		MOVE.L	#PrbSnapLen,D3
		JSR	-48(A6)			; Write
		MOVE.L	PrbSnapOld,D2		; the frame before
		...

*Source: AmiPCEngine 1.4 development, src/DbgRows.asm and src/VDP_AGA.asm (freeware by Juan Antonio Gómez Gálvez and z00p; used with permission).*

A short script on the PC decoded the map and the tiles, listed the tiles that changed between the two frames, and rendered the whole map to a PNG. It showed at once 480 cells with tile numbers above $7FF, the lesson in chapter 02 ("A tile number past the end of the guest's memory read a flag nobody clears"). The counts had pointed at "written tiles", and the dump showed that those cells' tiles were not being written at all.

**Why it works.** Counters are cheap and safe while the OS is frozen, and a photo carries them. A dump has to wait for the OS, but it holds everything, and the analysis can be rerun on the PC as often as needed. Keep the snapshot buffers in a BSS section (137 KB inline in the code pushed short branches out of range), keep the dump in its own build switch, and keep the rest of the build the tester's normal one.

**Look up.** Commits 61e045c (probe rows), faee2c7 (changed-bytes count), 4f48ef9 and 3384ec0 (dump); switch `DbgProbe`; `DbgProbeScan`, `PrbDumpWrite`; notes `docs/agent_notes/lag.md`.

## A headless x86 host with per-frame checksums

*Arnold.* The emulator core is plain C, so the same source also builds as a small program for a PC with no window and no sound: the headless host (`arnold/src/headless`). It runs a game for a given number of frames and writes out what it did. This is the cheapest test we have, and most of the work in this book was checked with it first.

**What it does.** The host is driven by environment variables: the hardware (`HW`), the cartridge, disk, tape and key-script files, `FRAMESUM` (a checksum of every drawn frame, over the RGB values, because palette index numbers may change), `RAMOUT` (the 64 KB of RAM at the end), `RAWIDX` and `RAW16` (the raw mixed sound), `TRACE_FROM` (a trace of the video-chip and ASIC writes with their raster position), `UNDRAWN` (reports any row of any frame the core did not draw), and for media `DISKWB` and `TAPEFAST`.

**The checks we run with it.**

1. **The homebrew check.** About 150 small freely available programs run to a few fixed frame numbers; the checksums are compared with those of the same program built from a reference git commit. Result in the notes: "150 same, 0 different" means the change is invisible there. A change that is meant to alter the picture must show a count of different programs you can explain (for example 8 of 150 for the I/O-lead fix, all of them games with many writes to the ASIC page).
2. **Whole-run checksums.** The big games (Sonic GX with two key scripts, 2300 and 4400 frames; Ghouls'n Ghosts GX; Puzzle Bobble; Burnin' Rubber) are built once with a change and once with its `NO_x` switch and every frame's checksum is compared. Identical means the change is exact, which is what every speed change must be (chapter 10).
3. **Equivalence tests for hot code.** The new c2p was compared with the old loop on 2 million random lines, the scroll table with the loop on 280 million random inputs, and the new sprite merge with the full loop on every call of a check build.
4. **Profiles.** callgrind on the same run shows which functions are hot (a guide only: chapter 10 shows why x86 counts mislead on Emu68).
5. **Traces against the reference emulator.** The reference emulator was patched to print the same writes with the same raster position (a private patched copy, never published). Plot "our position minus its position" in characters. This is how the Pinball Dreams and Sonic GX write timing was found (chapter 03).

**Limits.** (1) The host's `long` is 64 bits, the Amiga's is 32: a 32-bit overflow and a table read past its end both gave correct recordings on the PC and wrong sound on the Amiga (chapter 04). (2) Timing is not measured. (3) Nothing here shows what the beam shows; chapter 02 and the audit below do.

**Second leg: WinUAE regression** (`tools/regress.py`). Tiers: `smoke` (the titles marked in a table, 7 in 1.0), `full`, or named ids. All titles run in one WinUAE boot of a PiStorm-like configuration; an AmigaDOS script runs Arnold once per title with its key script, in a no-wait mode (`TURBO`). Arnold itself writes each requested `SNAP` as an exact CPC frame (a PNG of the core's frame) and a "done" file at quit, so no screen grabs are involved and none of the capture colour problems of the AmiMSX sections of this chapter apply. The report compares pixel for pixel with the accepted baseline and lists new, changed and missing captures with a side-by-side sheet. One capture (Burnin' Rubber, frame 400) has been "changed" since the Pinball Dreams timing work, with the same box every time; it is recorded as known so a new change stands out.

**Look up.** `arnold/src/headless`, `tools/regress.py`, `tools/perf50/cmp.sh`, `tools/dskwb_tests.py`, `tools/tape/tape_tests.py`.

## NO_x switches and AUDIT mode

*Arnold.* Every behaviour change in Arnold since 0.6 sits behind a `NO_x` define that restores the old behaviour exactly. The discipline is more useful than it sounds, and the AUDIT mode answers the question "is the bug in the emulator or in the display?".

### One switch per change, and what it buys

**Rule.** A change gets a name (`NO_IOTIME_FIX`, `NO_MONLINE_FIX`, `NO_SNDAA`, `NO_VSHIFT`, `NO_DSK80`, ...) and a comment where it is made:

    #ifndef NO_PALBEAM
        ... new behaviour ...
    #endif
    /* NO_PALBEAM: leave the beam as it was */

and the top of a feature's file lists its switches, with the "exact path": which set of switches reproduces the previous release (for example `-DNO_ASICTIME -DNO_DMAPHASE` gives the build before the Plus timing work). Run-time switches that users may want (`NOVSHIFT`, `TALL`, `WIDE`, `FASTTAPE=0`, `DISKWRITE=0`) are arguments, ToolTypes and preferences as well.

**What it buys.**
1. **Exactness tests.** A speed change must give identical frames with and without its switch (chapter 10); a fix gives identical frames except where it is meant to differ. With all the sound switches defined, the sound output was byte-identical to the previous release on two games.
2. **Bisecting a merge.** After merging the speed work with the timing work, 358 of 2300 Sonic frames changed. Switching changes off one at a time showed that `-DNO_EMUBR` alone made the frames identical, which led to the negative cycle count of chapter 03. Without the switches this would have been a search through the whole merge.
3. **A/B on the machine.** Build the same source with and without a switch and run both on the A1200 in turn (chapter 10).
4. **A fallback for users.** A tester can run the previous behaviour from the same binary or build set while a fix is being checked.

**Costs.** More `#ifdef`s; and a profile-guided build keys its profile on function order and line numbers, so adding a switch in hot code needs a new profile (chapter 10).

### All switches on must rebuild the last binary, and each switch must assemble alone

*AmiPCEngine.* This project keeps the Arnold rule in its strictest form: a job's list of `NO_x` switches, all set to 1, must give the previous binary byte for byte, checked with `cmp`. The assembly build allows that, because there is no linker layout and no time stamp to get in the way once the build reference is off (`-DNO_BUILDINFO=1`).

**Problem.** A check that sets every switch at once proves only that case. The whole point of the switches is to turn one off.

**Before** (`tools/nightcheck.sh`, all switches of the job at once):

	SW="-DNO_BUILDINFO=1 $(sed 's/^/-D/;s/$/=1/' ../tools/night_switches.txt | tr -d '\r' | tr '\n' ' ')"
	../tools/vasmm68k_mot.exe ... $SW -o ../build/night/check.bin Build.asm ...
	cmp ../build/night/check.bin ../build/base.AmiPCEngine && echo SAME

*Source: AmiPCEngine development, tools/nightcheck.sh (used with permission).*

**After.** Add a loop that builds with each switch alone. A small sketch, written for these notes (CC0):

	for s in $(tr -d '\r' < tools/night_switches.txt); do
	    vasmm68k_mot ... -D$s=1 -o /dev/null Build.asm || echo "$s does not build alone"
	done

The two faults that a review of the diff found, as the conditions read now (commit 7145014). `IFEQ NO_VDCDMA` left a `BEQ.S` out of range past the `NO_VDCREAD` code, and `IFEQ NO_VDLATE` used a label, `RrLine`, that only exists with `NO_VDCDMA=0`:

	IFEQ	NO_VDCDMA&NO_VDCREAD
	...
	IFEQ	NO_VDLATE|NO_VDCDMA

*Source: AmiPCEngine 1.1, src/IO.asm, src/PCE.asm (freeware by Juan Antonio Gómez Gálvez and z00p; used with permission).*

**Why.** Code added under one switch often sits on top of another's: a label it needs, or a branch that only stays short while the other block is left out. With all switches on, both blocks vanish together and the build is fine. A block that depends on two switches must name both.

**Evidence.** All the switches at once gave SAME, while `NO_VDCDMA=1` alone failed to assemble. A review of the whole diff caught that; the check script could not. After the fix each switch assembles alone and all together still give SAME.

**Other uses of the same check.**
- A release build must equal the same source with every test switch given as 0 (`cmp` SAME), and a string scan of the release binary finds no test file names.
- A switch that defaults to the old behaviour (`NO_PSGBASS`, a choice for a tester's ears) does not belong on the list. Its default is already "off".
- One figure for the cost of a whole job: all switches on against all off, same schedule. Night job on a 68030/50 in WinUAE: Parodius 3288 to 3338 vblanks, R-Type 2754 to 2794, Soldier Blade 4822 to 4869 (+1.0 to +1.5%).

**Look up.** Commit 7145014; `tools/*_switches.txt`, `tools/basecheck.sh`, `tools/nightcheck.sh`; notes `docs/agent_notes/night.md`, "Lead's review".

### AUDIT: telling an emulator bug from a display bug

**Problem.** The tester saw a dark row "a third of the way down" in Pinball Dreams on the A1200, and the top row of the score was cut. Is the picture wrong in the core, in the conversion to bitplanes, or on screen?

**What AUDIT does** (`amiga_sys.c`, argument `AUDIT`; commit d66764c). After each conversion the program reads every converted buffer back from chip RAM and compares it with a plain, slow c2p of the same chunky frame; it also compares the hardware copper list's `BPL1PT` with the plane pointer of the buffer it expects to be shown, which proves that `ChangeScreenBuffer` picked up a moved display window. The counts go into the performance report and the first mismatches into the log.

**Three stages, three tools.** (1) The core's frame: the menu's Screenshot saves the core's chunky frame exactly, and the headless host can do the same on a PC. (2) The bitplanes in chip RAM: AUDIT. (3) What the beam shows: a screen grab (chapter 11 says what it cannot see). A fault that is in (1) is the core; in (2) the conversion; only in (3) the display set-up (overscan, beam, window).

**Evidence.** Pinball Dreams: the dark row did not appear at any stage we could test. The core's frames had no isolated dark row (101 scroll frames and 61 play frames checked, and a switch that reports undrawn rows found none); 371 audited WinUAE frames had 0 bad rows and 371 of 371 copper checks correct; 82 real-time grabs showed no dark line. That placed it outside the core and the conversion, and the tester was given Screenshot and AUDIT to place it on the A1200. The cut score row was the display window; the TALL option (chapter 02) fixed it, audited over 9256 frames with 0 bad. For the vertical shift: 2250 frames, 0 bad rows, 2250 of 2250 copper checks, on WinUAE and on the A1200.

**Look up.** Commit d66764c; `VSCROLL.md`, `PINBALL.md`.

## Comparing with a reference emulator (AmiPCEngine)

*AmiPCEngine.* The reference is Mesen 2, run headless with Lua scripts: pad schedules, frame grabs, RAM and VRAM dumps, logs of register writes. The same schedule runs in a test build in WinUAE. Most faults of the night job were found by scanning every ROM against it, and most of the "faults" that scan raised turned out not to be faults. Both halves are below. Commits and `docs/agent_notes/` in this section belong to the AmiPCEngine development repository.

### Test ROMs compared byte for byte with the reference emulator

**Problem.** A game shows that something is wrong, not what the rule is. ninjabutai's broken logo said VRAM reads were wrong. It could not say what a read does after each order of address writes. Other details no game on hand tested at all.

**Before.** Read a game's trace and guess a model.

**After** (`tools/testrom_vdcread.py`, and three more). A small Python script writes a ROM in raw machine code. The ROM runs a list of small cases and stores every result in RAM from a fixed address. It runs on the reference (a Lua script dumps the RAM at a set frame) and on ours (test switch `StateDump=1` writes the same RAM to a file), and the two files are compared byte for byte:

	def rd(*regs):
	    for r in regs:
	        e(0xAD, r, 0x00)       # LDA $0002/3
	        lg()
	...
	mark(0xE1); marr_lh(0x1004); rd(2, 3, 2, 3)
	mark(0xE2); marr_hl(0x1008); rd(3, 2, 3, 2, 3)
	mark(0xE3); marr_l(0x100C); rd(2, 3, 2, 3)
	mark(0xE7); marr_lh(0x101C); rd(2, 3)        # buffer now word 1D
	mawr(0x101D); e(0x13, 0x11, 0x23, 0x22)      # write over it
	rd(2, 3, 2, 3)

*Source: AmiPCEngine development, tools/testrom_vdcread.py (used with permission).*

Each `mark` is a known byte in the log, so a difference can be placed at once.

| ROM | What it runs | Result |
|---|---|---|
| `testrom_ops` | every plain opcode over value and flag lists, hashed per opcode | 223 of 232 hashes equal, all 214 binary entries |
| `testrom_bcd` | T flag and decimal mode | 0 real differences |
| `testrom_vdcread` | read-ahead, address orders, increments, writes over the buffer | 0 of 76 bytes differ |
| `testrom_misc` | block moves, flow, page registers, I/O reads, colour read-back, timer | all differences understood |

**How to read the differences.** A count of differing bytes is not a verdict. Each one goes into a class:

| Class | Example | What to do |
|---|---|---|
| Undefined on the 68k | the 9 hashes left in `testrom_ops` are decimal SBC, because V is undefined after SBCD | narrow the test: the decimal ROM compares N, Z, D and C only, and it matches |
| The reference's own randomness | its random power-on RAM and palette | exclude those bytes |
| Open bus | reads of `$0800`, `$1400`, `$1800` | note and leave |
| A test artefact | a stack artefact at `$1FF` | note and leave |
| A real fault no game shows | `$1000` bits 4-5, `$0405` bits 1-7, `$0001`, `$1402` at reset | fix behind a switch (`NO_IOREAD`) |
| A real limit, kept | a push at SP = 0 writes `$2200`, not `$2100`; a (zp) pointer at `$FF` fetches its high byte from `$100` | write it down: fixing them costs in the hottest paths, and no title was seen to do either |
| Different on purpose | a probe card with one tag per 8 KB page: 64 of 128 banks differ for a 384 KB card | check what games read. The reference reads 0 at `$30-$3F` and `$50-$5F` where ours mirrors; the banks used by those titles are `$00-$1F` and `$40-$4F` |

**Why.** Generating the ROM takes minutes, and it runs through the same rig as a game, so it needs no new tools. Its value over a game is coverage of the cases no game on hand reaches, and a log with nothing else in it.

**Evidence.** The read-ahead rule above came from it (chapter 03). So did four I/O read-back fixes that no title was seen to need. The probe card found a real fault in a 512 KB card's mirror the first version got wrong: the reference answers with the last 256 KB at banks `$40-$7F`, and after the fix 0 of 128 differ.

**Look up.** `tools/testrom_ops.py`, `testrom_bcd.py`, `testrom_vdcread.py`, `testrom_misc.py`, `mesen_ramdump.lua`; notes `docs/agent_notes/night.md`, "Test ROMs against Mesen", and `p1.md`, "Lead's review".

### A frame number compares moments, not faults

**Problem.** Three reports read as display bugs: a white line in Soldier Blade at frame 2400 on RTG, HuZERO's picture "one line low", and teal bands in Soldier Blade at frame 1200. None was a fault.

**Before.** Compare one frame number in both emulators, and read a high percentage as a fault.

**After.** Compare a run of frames, and look at the pair before believing the number. The comparison also searches a small offset, because the two pictures need not start at the same column (`tools/rtgcmp.py`, reduced):

	for dx in range(0, 13):
	    for dy in range(-8, 9):
	        aa = a.crop((0, 8, w, 8 + h))
	        bb = b.crop((dx, 8 + dy, dx + w, 8 + dy + h))
	        d = ImageChops.difference(aa, bb).convert("L").point(lambda v: 255 if v > 40 else 0)
	        n = d.histogram()[255]
	        if res is None or n < res[0]:
	            res = (n, dx, dy, d)

*Source: AmiPCEngine development, tools/rtgcmp.py (used with permission).*

**What the three were.**
- **Soldier Blade's white line** is the game's own effect. A white line grows 16 pixels a step (reference frames 2408-2423), holds, opens into a white screen (2438-2468) and cuts to black (2486). Ours does the same about 16 to 20 frames ahead, so a fixed frame number catches it in one and not in the other.
- **HuZERO "one line low".** The reference offset is 0 at frames 600 and 1200, before and after. The figures at frames 200, 300 and 450 are the logo's rotation phase, not a line.
- **The teal bands** were a palette fade at another step: 170 of 512 entries behind the reference's, one fade step late.

**Traps.**
- A near-equal figure at two frames does not prove a still screen. Blazing Lazers read 26.15% and 26.14% at frames 1500 and 2400, which looked like a fixed fault. It was the same level at another scroll position.
- The offset search can pick a false match: a full-screen gradient matches at any dy.
- The reference carries state too. A blue icon by Parasol Stars' score came from the reference's saved backup RAM file. Its own frames differ between runs: Soldier Blade's reference frame 1200 differed between two runs of one schedule, and Soldier Blade's blinking panel made one run's figures move although our frames were the same bytes. Treat a reference grab as one sample of a range.

**Evidence.** Every ROM against the reference, frames 1200, 1800 and 2400 for originals, 600, 1200 and 1800 for homebrew: 41 same (all frames under 3%), 27 phase only, 0 wrong, 1 not a PC Engine ROM (an iNES file with a `.pce` name). "Phase only" was a verdict by eye on all 27 pairs in contact sheets: same scene and graphics at a different moment. Bonk's Revenge's 74.6% was ours in a scene while the reference was on black. The scan is only as deep as its pad schedule: ten titles stopped at a menu or an entry screen and need a longer schedule or real play. Seven titles were wrong at the start of that night, and they are fixed.

**Look up.** `tools/nightbatch.py`, `rtgcmp.py`; `docs/shots/` contact sheets; notes `docs/agent_notes/night.md`, part 2b item 3 and part 2a.

### Latch scripted input at the emulated frame, not at the host's vblank

**Problem.** Two builds of different speed diverged at frame 703, just after a press scheduled for frame 700. The scheduled pad bits were read by the Amiga's vblank, at a point in the PC Engine frame that depended on the build's speed, so a press could land a frame early or late.

**Before** (`src/Main.asm`, the vblank interrupt):

	JSR	AutoPressBits		; scheduled pad bits for this frame

**After** (commit ca7d085): worked out once at the start of the emulated frame, and only read by the vblank:

	JSR	AutoPressBits		; pad bits for this frame, the same for the whole frame
	MOVE.B	D1,AutoPressCur
	MOVE.B	D1,Regs+JoyX
	...
	MOVE.B	AutoPressCur,D1		; scheduled pad bits, latched at the start of the PCE frame
	OR.B	D1,JoyX(A3)

*Source: AmiPCEngine 1.1, src/Main.asm (freeware by Juan Antonio Gómez Gálvez and z00p; used with permission).*

**Why.** The schedule is the same as the reference's, in emulated frames, so anything that reads it must run in emulated time. Compare [Scripted runs must ignore the host's input](05-input.md#scripted-runs-must-ignore-the-hosts-input), which removes the other host influence. **Evidence.** With the fix, per-frame CPU traces of 2100 frames were identical between two builds of different speed.

## The rig first

### A test config pointing at another checkout gives "no result" on every title

**Problem.** An all-ROMs regression run from a second worktree showed "no result" on every title. When everything fails at once, the emulator is the least likely cause.

**Before** (`winuae/AmiPCE-jit.uae`, the shared AGA config; the path shortened here):

	filesystem2=rw,DH9:PCE:<main checkout>\run,-128

The runner copies the new build into the run folder of the checkout it runs in. WinUAE then looks in the other checkout's folder, so it runs a stale binary or none, and any result lands in the wrong place.

**After.** Give the regression a config with the worktree's run folder:

	sh tools/autoexit_all.sh OUT.txt 600 build/cfg/AmiPCE-jitwt.uae

*Source: AmiPCEngine development, winuae/AmiPCE-jit.uae; the third argument of tools/autoexit_all.sh is the config (used with permission).*

**Why.** The same config had bitten earlier and more quietly. One probe run read and ran the main checkout's Debug-rows build, a job that used these configs would have written into the main checkout, and a leftover `job.script` in the run folder would have turned every AGA run into an RTG run. A config that points at the wrong tree gives no error. Either nothing comes back, or worse, an old binary gives a good-looking result.

**Evidence.** With the worktree config: 69 of 69 titles reach 600 frames on AGA and on RTG, guards clean, stack free 130484 and 129488.

**Habits that catch this.**
- Suspect the rig when every title fails the same way.
- Delete old captures before a run, so a run that did not happen cannot be compared (`tools/rtgrun.sh` does).
- Check the output path of a batch. One script's loop variable was overwritten, and all five titles wrote to one folder.
- Tie a result to its binary with a build reference ([the first section](#use-both-loops-and-keep-a-build-reference-that-ties-them-together)), so a stale binary shows.

**Look up.** STATUS, "Release 1.1"; notes `docs/agent_notes/rc1.md`, "Rig notes", `faults.md`, B7.

### A grab of the wrong screen compares equal

**Problem.** A check of two builds, a fix on and off, compared WinUAE window grabs of eight titles: all eight "identical". They were. Every grab was the Workbench screen. Five test configs still mounted the run folder and the Workbench of an old worktree, so the program was never started.

**Before** (`winuae/AmiPCE-wt.uae`; the path shortened here):

	filesystem2=rw,DH9:PCE:<checkout>\build\wt_rtg\run,-128

**After** (commit 3bfff46): the main checkout's own `run` folder and a Workbench copy beside the configs.

**Why.** The previous lesson's failure ("no result") was loud because the regression waits for a result file only the program can write. A grab comparison has no such signal. Two grabs of the same wrong screen match perfectly, and a perfect match looks like the best possible answer.

**Habits.**
- Look at one grab of each set before reading any comparison figure, or check that something only the program writes is there.
- Treat "identical everywhere" with the same suspicion as "fails everywhere".
- When a config is copied for a worktree, rename it, and keep the shared ones on the main checkout.

**Look up.** Commit 3bfff46; STATUS, "Layout" (the configs and the tools that use them).

### A guard block catches the overrun, and so hides the crash

*AmiPCEngine.* The emulator freezes the operating system while it runs, so a stray write gives no fault and no log, only an alert later, or nothing. Test builds carry a memory check for that.

**Problem.** A tester saw Software Failure 8000 0004 after R-Type, most likely back in the menu while loading a second game. The 10 AutoExit runs on the same machine were clean, R-Type's included.

**After** (`src/Main.asm`, AutoExit builds only). Guard blocks at both ends of each hunk are filled with `$DEADBEEF` at the start, checked at exit, and reported in the result file. The unused stack is filled the same way, so the file gives the deepest stack use too:

	GuardLongs=64		; AutoExit memory check: longs per guard block
	MemGuard:	MACRO		; \1 = guard name; only in AutoExit builds
		IFNE	AutoExit
		CNOP	0,4
	Guard_\1:	DS.L	GuardLongs
		ENDC
		ENDM

*Source: AmiPCEngine 1.1, src/Main.asm (freeware by Juan Antonio Gómez Gálvez and z00p; used with permission).*

**Cause** (commit 37cbece, switch `NO_SPRDIRTY`). New sprite code took D2 for the sprite's column, but D2 was still the height counter of the loop that follows:

	move.w	d7,d2		; D2 is saved: buffer column = window column + 4
	and.w	#63,d2
	bfset	ColOcc{d2:d1}

so each sprite marked (column + 1) x 16 dirty lines. A sprite in the bottom-right corner, reachable only with the new wide window, ran up to 256 bytes past the end of the hunk. In a test build that memory is the guard, so it takes the whole overrun and nothing crashes. In the menu build it is the system's free list or another allocation, which fails when next used.

*Source: AmiPCEngine development before 1.0, src/VDP_AGA.asm (used with permission). The fix uses D6.*

**Why this is a lesson about the test.** A guard changes the memory layout it protects: the fault that crashes the real build cannot crash the test build. So the guard report is the test, not "it did not crash", and a short run may never reach the fault. It took a long scripted run that plays, dies and continues: R-Type, 9000 frames.

**Evidence.**

| Build | Machine | Result |
|---|---|---|
| Old code, 9000 frames of plain play | WinUAE 68040 | guard damaged: 13 longs, `DEADBEEF FFADBEEF` alternating |
| Fixed, same schedule | WinUAE 68040 and 68030 | clean |
| Old code, 9000 frames in 9166 vblanks | A1200 | guard damaged, same pattern |
| Fixed, 9000 frames in 9166 vblanks | A1200 | clean |

The pattern itself pointed at the cause: one byte in every 8 set to `$FF` is a bitmap with 8 bytes a line. The link to the tester's alert is by timing and code, not by a trace of that alert. An earlier use of the guards: HuZERO's alert 8100 0005 (corrupt memory list) was traced the same way to a copper list buffer of 8 bytes that took 76 bytes per scroll change; the guards showed two blocks fully overwritten (`NO_COPFIX`).

**Look up.** Commits 37cbece, fd33808; `MemCheckInit`, test switches `CodeCheck`, `AutoMenu`, `MenuAuto`; notes `docs/agent_notes/crash.md`.

## Bisecting a hang with variant builds

### Reordering a frame loop moves calls before a register reload

**Problem.** After the double-buffered frame was moved before the wait (chapter 05), four of fifteen regression titles on the 68030 config gave no captures at all: a black window from the first seconds. One of them was an MSX1 game that never uses SCREEN 4.

**Before** (the first version of the reordered path):

        JSR   ActCopperLine     ; builds the per-line copper list
        BSR   E1FTail           ; render: JSR ([RVDP.W,A3]) ...

**After** (commit 9779ef5):

        JSR   ActCopperLine
        LEA   Regs(PC),A3       ; (ActCopperLine's list pointer)
        BSR   E1FTail

*Source: AmiMSX 4.7 (in development), AmiMSX_Main_v3.1.asm (freeware, used with permission).*

**Why.** `ActCopperLine` writes the copper list through A3 (`MOVE.W D2,(A3)+`), so it returns with A3 pointing into the list, not at the emulator's registers. In the old order a `LEA Regs(PC),A3` came straight after it, before the input read, and the render ran later still. Moved forward, the render read its renderer address through `RVDP(A3)` of a pointer into the copper list and jumped into nothing. Nothing in the routine's comment said it used A3; the old caller simply never relied on A3 surviving it. When code moves within a loop, list the registers each moved call needs on entry and check who set them in the old order.

**Evidence.** The MSX1 game turned out to run the SCREEN 4 renderer for its first frames at boot, before the BIOS sets its screen mode, so it took the new path too. With the reload: 15 of 15 titles as before.

### Find a hang with variant builds, not by reading

**Problem.** A hang in WinUAE gives nothing to read: no log is written (it is written at the return to the menu), the screen is black, and the code looked right.

**Before.** Reading the code for an hour, through three plausible causes (an unguarded wait, the stack, the copper interrupt).

**After.** One title, one config, the slot harness, and builds that each change one thing, about two minutes a run:

| Build | Change | Result |
|---|---|---|
| new | the new path | 0 of 3 captures |
| v3 | new path compiled out (`NO_EARLYDB`) | 3 of 3 |
| v5 | v3 + 128 bytes of padding where the new code was | 3 of 3: not the code layout |
| v6 | new + the scratch stack doubled | 0 of 3: not the stack |
| vA | new path returns after its checks | 3 of 3: the checks pass on this title |
| vB | new path does the copper list, then returns | 3 of 3 |
| vD | new + no tick wait after an early frame | 0 of 3: not the tick interrupt |

That left the render itself, called right after the copper list, and the register above.

**Why.** Each variant halves what is left, and a hang is binary: captures or none. Padding to the same size rules out the layout (alignment and cache effects, which have caused trouble before), and an early `RTS` at each stage of a new routine finds the step that breaks without understanding it first.

**Look up.** `Docs/agent_notes/lag-4.7.md`; the harness is in this chapter's WinUAE section.

## Logs from the player's machine

### Write the log next to the program, not to its assign

**Problem.** A timing build sent to a player for a real-hardware test put up "Please insert volume AmiMSX in any drive" each time a game returned to the menu. The player suspected new software they had just installed.

**Before** (the log build):

    PerfName:   DC.B  "AmiMSX:perf.bin",0

**After** (commit a47d098):

    PerfName:   DC.B  "PROGDIR:perf.bin",0   ; next to the program: the
                                            ; tester's A1200 has no AmiMSX:
                                            ; assign

*Source: AmiMSX 4.7 (in development), AmiMSX_Menu_v3.1.asm (freeware, used with permission).*

**Why.** The development machines all had the program's assign; a player who starts it from a drawer icon has none, and AmigaDOS asks for the missing volume. `PROGDIR:` is the directory the program was loaded from, on every machine.

**Evidence.** The player's photos of the requester; with `PROGDIR:` the log arrived in the drawer with no requester. Tell the tester it was the build, not their setup, as soon as you know.

## Save states: a harness that tries to break them

### Five checks, run headless on every change to the machine state

*Arnold.* Arnold's save states are exact: a state saved at frame F, loaded and run on, gives the same frames and sound as a run that was never stopped. Once a state format can carry a whole machine, any new field, chunk or timing value can break it in ways a user only finds weeks later. So every change to what a state holds runs the same headless harness.

**Problem.** In Arnold 1.8 development, the frame boundary moved to the CPC's VSYNC (chapter 05). That added two values to the machine's state, and it meant a frame no longer ended on a whole number of sound blocks. Both are easy ways to break a state silently.

**The checks** (`tools/savestate/check.sh` in the development repository):
1. **Resume.** Save at a set of frames, load each state into a fresh process and run on. Every later frame checksum and the sound tail must equal the plain run's.
2. **Round trip.** Load a state and save it again at once. The two files must be identical.
3. **Saving is invisible.** A run that saves states along the way must equal a run that does not.
4. **Refusals.** A flipped byte, a file cut short at 11 lengths, another format version, random bytes, another cartridge, the wrong machine, a tape state with no tape: each must be refused, and the run must then go on exactly like a plain one. A crash counts as a failure.
5. **Fuzz.** 300 states with random changes and the checksum fixed, so they get past the first test. Each must be refused (and, if it was refused part way through, the machine put back exactly) or loaded. None may crash.

Two more checks cover versions and hosts. A state from the previous release must load into the new build and give the old run exactly. The other way round, the old release must refuse a new state cleanly. A state made on the Amiga build must also load in the PC build, and a PC state on the Amiga.

**Why.** Each check catches a different fault. Resume catches a value that is not saved. Round trip catches one that is saved but not loaded. "Invisible" catches a save that changes the machine, for example by flushing the sound at the wrong moment. Refusals and fuzz catch a loader that trusts its input. The headless host makes all of it cheap: the whole set runs in minutes on a PC.

**Evidence.** After the VSYNC change: resume 143 same and 0 different; round trip 138 and 0; invisible 31 and 0; refusals 23 and 0; fuzz 300 (175 refused, 172 of them part way with the machine put back exactly; 125 loaded); 0 crashes. Previous-release states into the new build: 24 of 24 exact. New states into the previous release: 24 of 24 refused with the machine unchanged, but with a misleading message ("a section is 16 bytes off"). That led to the plan to put new values in a separate chunk that older releases skip.

**Look up.** `tools/savestate/check.sh`, `mutate.py`; `tools/lag18/ss_check.sh`, `ss_compat.sh`, `uae_test.py`; notes `Docs/agent_notes/lag18.md`, "Save states".

## Leave the rig as you found it

*Arnold.* The WinUAE regression rewrites a batch file in the shared run folder, and a session that forgets to restore it leaves the next run testing the wrong titles. After each run, restore the file from git and check the boot script against a known checksum. The checks are two commands and take a second. Run them after every regression or smoke run, and before you hand WinUAE to another session.

## What works and what doesn't

A summary of this chapter and the testing lessons in other chapters, across the three projects. Each row names the section with the details.

### What works

| Technique | Good for | Where |
|---|---|---|
| A headless PC build of the core with a checksum of every frame | Proving a speed change exact, bisecting a merge, save states, lag in whole frames; minutes per run | "A headless x86 host", "Save states" |
| One `NO_x` switch per change, and a build with all of them that equals the last release | Exactness, bisecting, A/B on the real machine, a fallback for users | "NO_x switches and AUDIT mode" |
| Key scripts typed inside the emulator, with captures at exact emulated frames | Repeatable picture regressions in WinUAE, independent of window focus | "WinUAE automation" |
| A signal that only the program can give (a result file, the power LED) | Telling "no result" from "same result" | "The power LED", "The rig first" |
| Bursts of consecutive frames against the reference emulator | One-frame glitches that a three-shot regression misses | "Consecutive-frame bursts" |
| Test ROMs compared byte for byte with the reference emulator | CPU and video-chip details | "Comparing with a reference emulator" |
| Scripted runs on the real machine over the network | Real frame times, unattended, repeated for hours | "Real hardware over the network" |
| Debug rows on the screen and a photo from the tester | Programs that take over the machine (no OS, no files) | "Debug rows on the screen" |
| Totals in a result file, probe counters, a state dump at exit | Sweeps without a camera; finding why, not just that, something is slow | "Add the windows up", "When the rows say slow" |
| A blind A/B for the tester, with neutral names | Feel, judder and sound, where 4 ms or a filter is near the limit of perception | Chapter 05, "Ask the tester the right question" |

### What doesn't

| Approach | Why it fails | Where |
|---|---|---|
| WinUAE speed as a guide to PiStorm speed | The JIT 68040 says whether the picture is right, not whether the frame fits in 20 ms | Chapter 10 |
| x86 profile counts as a guide to Emu68 hot spots | A different CPU, cache and JIT | Chapter 10 |
| WinUAE window grabs, or captures after the render, as the last word on the picture | Colour boosted by the default output, and nothing of what the beam shows | "Capture colours", "Blind spots" |
| Comparing grabs with no "the program ran" signal | Two grabs of the wrong screen match perfectly | "A grab of the wrong screen compares equal" |
| Checking all switches on at once only | A switch that does not build or run alone goes unseen | "All switches on must rebuild the last binary" |
| Host timing alone for lag | It cannot see a frame lost to where the emulator's frame ends | Chapter 05, Arnold's lag section |
| WinUAE's emulated CD32 pad in the test harness | It never answered there, so pad code was checked against WinUAE's source and on real pads | Chapter 05 |
| A figure that measured well, kept without listening or looking | A software sound mix and live drawing without the double buffer both measured better and were rejected by ear and eye | Chapters 04, 05 |
| A question that names the answer | "LateOff" on an icon steered the first verdict | Chapter 05 |
