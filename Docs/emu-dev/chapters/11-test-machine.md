# The test machine: an OS 3.2.3 PiStorm A1200

The emulators are tested on a real A1200 with a PiStorm32-lite and a Raspberry Pi CM4 running Emu68 1.1 (it reports a 68040 with FPU). It runs AmigaOS 3.2.3, Picasso96 3.x on the VideoCore RTG driver, PiStorm3D (`minigl.library` 29.1), AHI and Roadshow with wired Ethernet. Large data lives on a NAS share mounted with `smb2-handler` (called `NAS:` in the examples below). Agents drive it over the network with amimcp (see [Real hardware over the network](06-testing.md#real-hardware-over-the-network-amimcp)).

The lessons below were learned while setting this machine up and running PC game ports and 3D programs on it. They are about the machine and its tools, not about one emulator, but every emulator test run depends on them.

## Launching programs remotely

### A program started with Run does not get the shell's stack

**Problem.** Quake III (ioq3, MiniGL) crashed the A1200 twice on start-up. `Status FULL` showed the game running with a 128 KB stack, although the remote shell had just set 2 MB.

**Before** (remote shell commands):

    Stack 2000000
    CD Q3D:Q3
    Run >NIL: <NIL: quake3

**After** (a launch script, started with `Execute`):

    ; Play A1200
    Stack 2000000
    Assign Q3D: ""
    CD Q3D:Q3
    quake3 +set fs_basepath Q3D:Q3 +set fs_homepath Q3D:Q3 +set r_fullscreen 1
    CD SYS:
    Assign Q3D: REMOVE

started remotely as `Run >NIL: <NIL: Execute "Play A1200"`.

**Why.** The remote agent's shell is not the CLI that `Run` clones, so its `Stack` setting does not carry over. Inside a script, `Stack` applies to the script's own CLI, and a program started directly from it (without `Run`) inherits that stack.

**Evidence.** `Status FULL` showed `stk 131072` for the first run and `stk 2000000` after the change. The game reached its menu and played. The two earlier attempts reset the machine.

*Source: launch script written for the test machine (CC BY 4.0).*

### Paths with spaces break programs that start helpers by full path

**Problem.** Quake III could not load its native game modules. A console window showed `NAS:PC: Unknown command`, and the game fell back to the much slower bytecode modules (the ones that then crashed on the small stack).

**Before:** the game ran from a drawer whose path contains spaces (on the share: `PC Games/_Needs PiStorm 3D/Quake III Arena (...)`). Its log read:

    Sys_LoadDll(NAS:PC Games/_Needs PiStorm 3D/.../baseq3/ui68k.dll)...
    Failed loading dll, trying next

**After:** the launch script above. The game lives in a subdrawer `Q3`, the script assigns a space-free name to the drawer and passes it as `fs_basepath`. The log then reads `Sys_LoadDll(Q3D:Q3/baseq3/ui68k.dll)...` with no failure.

**Why.** The port starts each module as a separate program by building a command line from the full path. AmigaDOS splits that command line at the first space, so `NAS:PC` is taken as the command name. Setting `CD` alone is not enough: the engine resolves the current directory to its full path. The base path must be given explicitly as a path without spaces.

**Evidence.** Two log runs, before and after. A Quake II port by the same author showed the same failure on another machine, and the same fix worked there.

**Look up.** The game's `qconsole.log` (`+set logfile 2` writes it line by line, so it survives a crash).

### Brackets are wildcards for Copy and List

**Problem.** A copy of a game drawer called `Star Wars Jedi Knight - Dark Forces II (OpenJKDF2)` copied nothing and printed no error (`QUIET`). `List` of a drawer named `157 Heliobane (2026)` printed nothing at all.

**Before:**

    Copy "NAS:PC Games/Syndicate (FreeSynd)" "Games:PC Games/Syndicate (FreeSynd)" ALL CLONE QUIET

Result: `Wildcard destination invalid`.

**After:**

    Assign DST: "Games:PC Games/Syndicate (FreeSynd)"
    Copy "NAS:PC Games/Syndicate '(FreeSynd')" DST: ALL CLONE QUIET
    Copy "NAS:PC Games/Syndicate '(FreeSynd').info" "Games:PC Games/" CLONE QUIET
    Assign DST: REMOVE

**Why.** `(`, `)` and `|` are AmigaDOS pattern characters. A source name with brackets is treated as a pattern that no longer matches the literal name. Escape each bracket with `'` in a source. A destination may not contain a pattern at all, even an escaped one, so reach it through an assign. `CD`, `Assign` and `MakeDir` take plain names and are not affected.

**Evidence.** The escaped source with an assigned destination copied the whole drawer. The unescaped form copied nothing. Later copies done this way matched the share's file count and byte total exactly.

### Starting a Workbench icon from a script

`C:WBRun` is not part of every OS 3.2 install. This machine has `C:WBLoad` instead, which starts an icon (including an Installer script with its tooltypes) as if it were double-clicked:

    CD "NAS:Install/PrinceOfPersia2/PoP2 Install"
    Run >NIL: <NIL: C:WBLoad Install

The Installer window can then be driven remotely with clicks on its gadgets (see the next section).

## Driving the screen remotely

### Screenshots see full screens, not 3D windows

The agent's native capture reads the screen's bitmap. It worked on 640x480 and 320x240 full-screen MiniGL screens (Hurrican, GLQuake, Quake III), on SDL screens and on the 32-bit RTG Workbench. A MiniGL program in a *window* on Workbench (Quake III windowed, Jedi Knight in its default window) showed only an empty grey window in the capture, while the real display showed the game. Use full-screen modes for anything you need to see remotely.

### SDL programs ignore injected mouse movement

Exult and FreeSynd (SDL2) accepted injected clicks only where their own pointer already was: moving the Intuition pointer did not move the game's pointer. They did accept keys, so the menus were driven with cursor keys, Return and Escape. The agent's key tool also has no letter keys (type them as text instead). There is therefore no Right-Amiga+X to clear a string gadget: click into it and send Backspace and Delete instead.

## 3D on PiStorm (PiStorm3D / MiniGL)

### Windowed MiniGL needs a 32-bit BGRA Workbench

**Problem.** OpenLara (MiniGL build) ran windowed on Workbench with black vertical stripes over the picture.

**Before:** Workbench on a 24-bit RTG mode (`0x500A1200`, depth 24).

**After:** Workbench on a 32-bit BGRA mode of the same size (`0x500A1303`). The picture was clean, with no change to the program.

**Why.** PiStorm3D renders in 32-bit BGRA. A window shares the screen's pixel format, and a 24-bit screen cannot take the 32-bit output. Full-screen programs open their own screen and are not affected.

**Evidence.** The same build and the same level, with only the Workbench mode changed.

### One 3D context at a time, and never Break a 3D program

`minigl.library` 29.1 serves one program at a time. Stopping the gears demo with Ctrl-C left its last frame frozen on screen and blocked the next MiniGL program (OpenLara started, used memory and drew nothing) until a reboot. Starting a second 3D program while another one was still running had the same effect. Before starting a 3D test, check `Status` for leftover 3D processes. Quit 3D programs with their own keys or menus. If one is stuck, reboot.

### Keep all Picasso96 parts on the same version

The disk imager installed the Picasso96 2.0 monitor driver next to the 3.x libraries. RTG worked, but PiStorm3D tests were only reliable once every part (rtg, emulation, API libraries, `DEVS:Monitors` driver) carried the same date. Check them with `Version` before blaming the 3D driver.

## The machine itself

### A marginal power supply looks like random resets under load

The A1200 rebooted every few minutes at a CM4 clock of 2.2 GHz (`arm_freq=2200`, `over_voltage=9`, `force_turbo=1`). The Emu68 meter showed no CPU or temperature fault. Setting `avoid_warnings=2` (no throttling on undervoltage) made it worse. At `arm_freq=1800`, with no over-voltage and no forced turbo, it has run for days with 3D games. The supply on this machine cannot feed a CM4 at 2.2 GHz plus the Amiga board. So **record the CM4 clock with every performance figure**: a measurement taken at 1.8 GHz is not comparable with one taken at 2.2 GHz.

### Run big data from local disk, and copy it in small pieces

Games that stream a lot of data loaded slowly from the NAS share (Hurrican 90 s, FreeSynd 70 s), and Jedi Knight was too slow to play from it. One long copy of several gigabytes from the share hung `smb2-handler`. Every program waiting on the share then froze, including `Info SMB0:`, which ignored Ctrl-C, and only a reboot cleared it. Copy one drawer per command and compare file counts and byte totals with the source after each one. (`List ... LFORMAT "%l"` prints `empty`, not `0`, for a zero-byte file. Count those too, or the totals never match.) Then a hang costs one drawer, and you know exactly where it stopped. The hang was repeatable: both times it stopped at the same game-generated cache folder (a dozen small files and subfolders, nothing unusual in the names), and a second reboot was needed. Skipping cache folders, which the programs rebuild anyway, avoided it. If the share hangs on one folder, go round it rather than retrying it. A third hang came in the middle of a 315 MB file while a web browser on the Amiga was also using the network; with the browser closed, the same file and 3.3 GB more copied without a hang. Keep other network programs closed during long transfers.

### After a reboot the network may stay down

On this machine a flag file (`S:NoNetworkAtBoot`) skips the network at boot, so after any reboot or crash the remote agent cannot be reached until someone starts the network on the machine. When a test can reset the machine, plan for a person to bring it back online. Either have the network start at boot, or write results to the share as you go, so they survive the reset.
