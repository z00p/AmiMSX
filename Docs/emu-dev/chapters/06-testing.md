# Testing

*Reading notes.* The AmiMSX parts of this chapter describe a test set-up for an emulator that takes over the whole machine, so it cannot be debugged from inside the operating system. The Arnold parts (real hardware over the network, the headless host, the debug switches) are in their own sections below. Commit references name the AmiMSX development repository; the public repository carries squashed commits.

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

### AUDIT: telling an emulator bug from a display bug

**Problem.** The tester saw a dark row "a third of the way down" in Pinball Dreams on the A1200, and the top row of the score was cut. Is the picture wrong in the core, in the conversion to bitplanes, or on screen?

**What AUDIT does** (`amiga_sys.c`, argument `AUDIT`; commit d66764c). After each conversion the program reads every converted buffer back from chip RAM and compares it with a plain, slow c2p of the same chunky frame; it also compares the hardware copper list's `BPL1PT` with the plane pointer of the buffer it expects to be shown, which proves that `ChangeScreenBuffer` picked up a moved display window. The counts go into the performance report and the first mismatches into the log.

**Three stages, three tools.** (1) The core's frame: the menu's Screenshot saves the core's chunky frame exactly, and the headless host can do the same on a PC. (2) The bitplanes in chip RAM: AUDIT. (3) What the beam shows: a screen grab (chapter 11 says what it cannot see). A fault that is in (1) is the core; in (2) the conversion; only in (3) the display set-up (overscan, beam, window).

**Evidence.** Pinball Dreams: the dark row did not appear at any stage we could test. The core's frames had no isolated dark row (101 scroll frames and 61 play frames checked, and a switch that reports undrawn rows found none); 371 audited WinUAE frames had 0 bad rows and 371 of 371 copper checks correct; 82 real-time grabs showed no dark line. That placed it outside the core and the conversion, and the tester was given Screenshot and AUDIT to place it on the A1200. The cut score row was the display window; the TALL option (chapter 02) fixed it, audited over 9256 frames with 0 bad. For the vertical shift: 2250 frames, 0 bad rows, 2250 of 2250 copper checks, on WinUAE and on the A1200.

**Look up.** Commit d66764c; `VSCROLL.md`, `PINBALL.md`.
