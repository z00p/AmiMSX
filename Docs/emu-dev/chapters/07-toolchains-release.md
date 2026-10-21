# Toolchains and release

*Reading notes.* AmiMSX is one binary built from 68k assembly source. The release path is: build, regression, LHA archive, Aminet upload, public source, GitHub release. Every publishing step is a human decision; agents prepare it (chapter 08). Commit references name the AmiMSX development repository; the public repository carries squashed commits.

## vasm and the 68k assembly build

### Hand-counted branches break when the layout changes

**Problem.** In October 2026 some builds hung at start-up: profiling builds, trace builds, and in principle any build in which code had moved. The source had been assembled with Devpac; it is built with vasm 2.0f (Motorola syntax in Devpac-compatible mode) since 4.0.

**Before** (`AmiMSX_Main_v3.1.asm`, AmiMSX 4.0 development):

```
	TST.B	V5All
	BNE.S	*+10
	MOVE.L	#OUT98M,DREGOUT98(A3)
```

**After** (commit 7a4b5a9):

```
	TST.B	V5All
	BNE.S	V5AllKeep1		; (A label: the MOVE's size depends on the layout.)
	MOVE.L	#OUT98M,DREGOUT98(A3)
V5AllKeep1:
```

and in `build.sh`, a guard that refuses the pattern:

```
# No hand-counted branches (B.. *+n): an instruction's size can change with
# the layout (a displacement past 16 bits), and the branch then lands
# mid-instruction (3 Oct 2026: BNE.S *+10 over a MOVE.L to DREGOUT98(A3)).
if grep -nE "^[^;]*B[A-Z]{1,3}(\.[SBWL])?[[:space:]]+\*[+-]" AmiMSX_Main_v3.1.asm AmiMSX_Menu_v3.1.asm; then
  echo "error: branch to *+n/*-n above: use a label"; exit 1
fi
```

*Source: AmiMSX 4.0, AmiMSX_Main_v3.1.asm and build.sh (freeware by Juan Antonio Gómez Gálvez; 4.x changes; used with permission).*

**Why.** The `MOVE.L` to `DREGOUT98(A3)` is 8 bytes while its displacement fits in 16 bits and 12 bytes once the code has moved far enough from the register block that it does not. A short branch with a hand-counted offset then lands in the middle of an instruction. The build still succeeded and the emulator crashed at boot, only in the layouts where the code had grown. The check is a text search, so it costs nothing and fires the moment someone writes the pattern again.

**Evidence.** The boot hangs of the profiling builds on 2 Oct, first blamed on the new timers, disappeared. The same commit turned five hand-counted branches (three `BNE.S *+10`, two `BLS.S *+8`) into labels. The build line, for reference:

```
vasmm68k_mot -devpac -nocase -m68020 -Fhunkexe -nosym -maxerrors=0 \
  -o build/AmiMSX AmiMSX_Main_v3.1.asm
```

**Look up.** Commit 7a4b5a9; `build.sh`; `tools/buildid.sh` (a build reference in the menu title).

### Debug code must leave the release build byte-identical

**Problem.** Debug aids (an instruction ring, an event trace, a "freeze at the first write to this VRAM address" trap) are needed to investigate a fault, but they must not change what ships, and a wrongly combined set of switches should stop with a clear message.

**Before** (`AmiMSX_Main_v3.1.asm`, the Uridium 2 trap, AmiMSX 4.1.2 development). The trap depended on two other debug switches without saying so. Assembling with `-DU2TRVADDR` alone ended in an undefined-symbol error from deep inside a macro:

```
	IFD	U2TRVADDR
; (U2TRV) Freeze at a port-98 write to VRAM offset U2TRVADDR from MSX frame
; U2TRVFR on, whatever the mode's handler (A2 is the write pointer).
U2TRAP:	MACRO
```

**After** (commit 0872b43):

```
	IFD	U2TRVADDR
; ... Needs TRACE (TraceFreeze) and U2TRV (TrvFrame).
	IFND	U2TRVFR
U2TRVFR	EQU	0			; default: any frame
	ENDC
	IFND	TRACE
	FAIL	U2TRVADDR needs -DTRACE (TraceFreeze)
	ENDC
	IFND	U2TRV
	FAIL	U2TRVADDR needs -DU2TRV (TrvFrame)
	ENDC
U2TRAP:	MACRO
```

Every debug aid is chosen on the vasm command line (`-DTRACE=1`, `-DPERF=1`, `-DSNAPLIVE=1`, `-DNOL0=1`, `-DFMXREC=1`, `-DCD32TEST=1`) and sits inside `IFD` blocks.

*Source: AmiMSX 4.1.2, AmiMSX_Main_v3.1.asm (freeware by Juan Antonio Gómez Gálvez; 4.x changes; used with permission).*

**Why.** When a switch is off, the assembler emits nothing, so the shipped binary is the same bytes with or without the debug code. That makes review simple: build both ways and compare. A `FAIL` with the switch's name turns a confusing error into an instruction.

**Evidence.** Test assemblies: `-DU2TRVADDR=0` alone stops with the two `FAIL` messages (exit 1); `-DTRACE -DU2TRV -DU2TRVADDR=0` assembles (exit 0, `U2TRVFR` defaulted). A release build differed from the reviewed debug-capable build in 14 bytes only, the two build-reference strings (`cmp -l`: offsets 179 to 185 and 67217 to 67223). The first trace build (1 Oct) was checked the same way: the normal build stayed byte-identical. A correct build of the master at the time was 563,368 bytes, a number used to check a toolchain rebuilt elsewhere.

**Look up.** Commits cac36a3, 0872b43; the `IFD` blocks around `TRACE`, `PERF`, `STATEDUMP`, `CORRCHK`, `HANGCHK`, `EXCCHK`; `Docs/CHANGES_4.x.md`, "Debug builds".

## amiga-gcc

*To be written (Arnold).*

## Building the LHA inside WinUAE

### Let the Amiga's own lha make the archive

**Problem.** The release is an LHA archive for Aminet. It holds Amiga icons, a drawer icon and files whose Amiga attributes (protection bits, comments) should be exactly what the Amiga's tools make.

**Before.** The obvious route: archive on the PC, where the staging script runs. No comparison with a PC archiver's output was recorded; the Amiga's own tool was chosen for fidelity.

**After** (`winuae/make_lha.ps1`). The script copies the staged drawer to the shared drive, replaces the boot line of the test Workbench's `Startup-Sequence` with the archive command, boots WinUAE with the standard configuration, waits until the Amiga writes a `done` marker, and restores the startup file in a `finally` block:

```
$cmd = "CD AmiMSX:Release`nC:lha -r a AmiMSX4.lha AmiMSX AmiMSX.info >AmiMSX:Release/lha.log`nC:lha v AmiMSX4.lha >AmiMSX:Release/list.txt`nEcho >AmiMSX:Release/done ok"
$s = [regex]::Replace($orig, '(?m)^(; )?Run >NIL: AmiMSX:AmiMSX.*$', $cmd.Replace('$', '$$'))
...
try {
  ...                          # start WinUAE; wait for the marker, at most $MaxWait s
} finally {
  Get-Process winuae64 -ErrorAction SilentlyContinue | Stop-Process -Force
  [IO.File]::WriteAllText($seq, $orig, $latin1)     # the startup file back
}
if (-not (Test-Path (Join-Path $rel "done"))) { throw "lha did not finish" }
```

*Source: AmiMSX 4.1.2, winuae/make_lha.ps1 (freeware by Juan Antonio Gómez Gálvez; 4.x changes; used with permission).*

**Why.** The archive is made by the tool its users will unpack it with (the Workbench's `lha` 40.57), so the Amiga attributes are the Amiga's own. The startup file is rewritten in Latin-1 to keep its bytes, restored even if the build fails, and WinUAE is stopped by the `finally` block. The archive listing (`lha v`) is printed back, so the staged files can be checked. The staging itself (`tools/make_release.py`) writes text files for the Amiga with LF line ends and Latin-1, replaces typographic quotes and dashes by ASCII, and wraps long Markdown lines at 76 columns.

**Evidence.** The 4.1.1 release archive was 529,947 bytes and 22 files (including the virtual-disk files and the changelog as text). The archive downloaded from GitHub after publication was verified byte-identical to the one built here.

**Look up.** `winuae/make_lha.ps1`, `tools/make_release.py`; the release checklist in `Docs/release_4.0.md` (private).

## Aminet uploads and readme fields

### One `.readme` with fixed fields, and an anonymous FTP upload to `/new`

**Problem.** Aminet files arrive in a queue and are checked by hand; a readme that misses a field, or an archive without a matching readme, waits or is rejected.

**What the readme needs** (`Docs/AmiMSX4.readme`, header; the uploader's address is left out here):

```
Short:        MSX/MSX2/MSX2+ emulator, 4.1.2 beta
Author:       Juan Antonio Gomez Galvez (GUS Entertainment / RED Soft)
Uploader:     <name> (<email address>)
Type:         misc/emu
Version:      4.1.2
Replaces:     misc/emu/AmiMSX4.lha
Architecture: m68k-amigaos >= 3.0.0
Requires:     68030 or better, AGA
Distribution: Aminet
Kurz:         MSX-Emulator (MSX2/2+), mehr Genauigkeit
```

*Source: AmiMSX 4.1.2, Docs/AmiMSX4.readme (freeware by Juan Antonio Gómez Gálvez; 4.x changes; used with permission).*

- **Short** is one line of at most 40 characters. **Type** is the directory the file will be put in. **Replaces** names the previous upload, so the old file is removed when the new one is accepted.
- **Author** is the original author, as agreed; the uploader is the person who uploads.
- The readme is plain text for the Amiga: Latin-1, LF line ends.

**Upload.** Both files go to the `/new` directory of the main Aminet server by anonymous FTP, with the uploader's e-mail address as the password. The pattern (the server returns `226` for each completed transfer):

```
curl -T AmiMSX4.lha    --user anonymous:<uploader address> ftp://main.aminet.net/new/
curl -T AmiMSX4.readme --user anonymous:<uploader address> ftp://main.aminet.net/new/
```

**Why.** The files go into a queue that is checked by hand, so a mistake costs a day, not a minute. Do the upload last, after the archive is built and tested, and only with the owner's go-ahead (agents never upload on their own, chapter 08).

**Evidence.** The 4.0, 4.1 and 4.1.1 uploads returned `226` for both files. A new upload did not show on the "recent" page; it appeared in the directory listing and the search once processed (the 4.0 upload was confirmed live that evening).

**Look up.** `Docs/AmiMSX4.readme`; the release notes in `Docs/release_4.0.md` (private).

## A public source copy, tags and GitHub releases

### Never publish the working repository; add one scrubbed commit per release

**Problem.** The development repository holds internal notes, agent notes, tools with local paths, a few private details in the history, and executables that belong to other projects. The public repository must show none of that.

**Before** (4.0, the first publication). A clone of the working repository with its whole history rewritten: author names normalised, internal documents dropped from every commit, tester names replaced by "a tester" in the changelog and open-issues text, tool executables removed together with the licence that went with them.

**After** (4.1 onwards). History that is already public is never rewritten. For each release:
1. Take the tracked files of the release commit (`git archive`) into the public working copy.
2. Scrub: private paths, machine names and personal names out of text and tool sources.
3. Leave out the internal documents: the release checklist, the review package, the staging plan for the first publication, and the whole `Docs/agent_notes/` directory.
4. Make one commit on top of the public history, tag it (`v4.1.2-beta`), and push it with the owner's go-ahead.
5. Create the GitHub release with `gh`, marked as a pre-release, with the LHA attached, and download it again to compare:

```
gh release create v4.1.2-beta AmiMSX4.lha --prerelease --title "AmiMSX 4.1.2 beta" --notes-file release-notes.md
gh release download v4.1.2-beta --pattern AmiMSX4.lha   # then compare size and checksum
```

*Source: AmiMSX release procedure, 4.1.2 (freeware by Juan Antonio Gómez Gálvez; 4.x changes; used with permission).*

**Why.** The first publication can use a rewritten clone because nothing existed yet. After that, users have clones, so rewriting would break their histories. A private repository is the place for working notes, and the public one gets a scrubbed export. Line endings are fixed (`core.autocrlf=false` in the public working copy), or every release would show every file as changed. Each release has a GitHub release alongside the Aminet upload, so the archive can be downloaded and compared byte for byte.

**Evidence.** Three releases (4.1, 4.1.1, 4.1.2) were added this way, each as one commit and one tag; the 4.1.2 archive was 533,662 bytes and the download from GitHub matched. A text search of the public tree for private path fragments, names and addresses before each push is part of the procedure (and of how this documentation set was checked).

**Look up.** `Docs/release_4.0.md` and the notes template (private); `CONTRIBUTING.md` (public, how to file an issue).

## Preset icons and tooltypes

### Settings that ship with the program: one prefs file and one icon per target

**Problem.** A user with a 68030 A1200 and one with a PiStorm need different settings, and 3.1 had one global preferences file. One preset field also had a misleading name and broke most games.

**Before.** One global `S:AmiMSX2.prefs`, edited from the menu, saved over.

**After** (`tools/make_presets.py`, the `PREFS=<file>` tooltype read from the icon the program was started from):

```
PRESETS = [   # file name, badge text, badge colour, {offset: (format, value)}
    ("AmiMSX 030",     "030",  (40, 150, 60),  {SPRITES: (">H", 1), COLLIDE: ("B", 0), SOUND: ("B", 0), FREQ: ("B", 1)}),
    ("AmiMSX PiStorm", "Pi",   (200, 40, 60),  {SPRITES: (">H", 1), COLLIDE: ("B", 0), SOUND: ("B", 3), FREQ: ("B", 0), FILTER: ("B", 0xFF), DBUF: ("B", 0xFF), JAPAN: ("B", 0xFF)}),
]
```

Each preset is the binary's own default prefs block with a few fields changed (`default_prefs` reads the block out of the built binary, so presets cannot drift from the program), plus a project icon whose default tool is `AmiMSX` and whose tooltype `PREFS=<its own name>` makes the program load, and Save Prefs write, that file. A relative name is taken from the icon's drawer.

*Source: AmiMSX 4.1.1, tools/make_presets.py (freeware by Juan Antonio Gómez Gálvez; 4.x changes; used with permission).*

**The policy.**
- **AmiMSX 030** is the low-spec target: an A1200 or similar with a 68030 at 50 MHz and fast RAM. PSG sound, PAL, sprites drawn every frame. A stock 68020 A1200 is not a target (the program runs there, slowly) and has no preset.
- **AmiMSX PiStorm** is for PiStorm (Emu68), BigMig and other fast CPUs, and carries the costly features: FM sound, the display frequency "From VDP" (60 Hz games shown at 60 Hz), the Japanese ID with its 60 Hz boot, the audio filter and Smooth display. "From VDP" and the Japanese ID each cost about 20% more emulation per second for 60 Hz games, so they are not set for the 030.
- A feature that costs time goes in the fast preset or behind an option, never into the default of the slow target.

**Why.** A preset states a promise: this runs at full speed on this machine. The costs measured in the previous chapters (FM about 8% on a 68030, 6% on a 68060) decide where each feature goes. The "collisions always" field (preferences byte `$6C`) was the original author's hack, which makes every status read report a collision. It is not an on/off switch for collision detection (which always runs). With it set, the 030 and PiStorm presets broke most games: Nemesis 2 looped at boot, Bomb Jack and Lilly's Saga went black. It was set to 0 in every preset (commit b6b2d96), and the menu item was removed later (2e30fb2).

**Evidence.** A Workbench start was tested in WinUAE (`winuae/wb_preset_test.ps1`, 3 Oct 2026): the "AmiMSX 030" project icon in WBStartup started the emulator with its preferences (the menu showed "Sprites: 1 Frame").

**Look up.** `tools/make_presets.py`, `tools/make_release.py` (icons), `Docs/CHANGES_4.x.md` ("Workbench" and "Options").
