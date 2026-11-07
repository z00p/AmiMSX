# Input

*Reading notes.* The examples come from AmiMSX, which takes over the machine while the MSX runs. It reads the joystick ports and the keyboard through the custom chips and the CIAs and never goes through the operating system's input handling, so it has to implement the CD32 pad protocol itself. Arnold, which runs with the operating system, reads the pads in the same way from C (see "CD32 pads from C"), and both reads are in an MIT-licensed kit, [kits/cd32pad](../kits/cd32pad/README.md). Commit references name the development repositories; the public repositories carry squashed commits.

## Reading CD32 pads without the stack

### Drive pin 6 high before pin 5 falls

**Problem.** A CD32 pad is a shift register behind the joystick port. In its plain mode it behaves like a two-button joystick (red on pin 6, blue on pin 9). In CD32 mode it returns seven buttons one at a time. A review of the first version of AmiMSX's read predicted that the pad would drop out of CD32 mode whenever the red button was held.

**The protocol, as AmiMSX uses it** (once per frame, joystick port and mouse port in one pass):
1. Make the pin 6 lines (CIA-A port A bits 7 and 6) outputs, driven high.
2. Pull pin 5 low through POTGO (`$DFF034`). The pad latches its buttons and switches to shift mode. Pin 5 has the pot capacitor on it, so it takes about 300 microseconds (4 to 5 raster lines) to fall. The wait is 200 CIA reads: a CIA access takes one E-clock (about 1.4 microseconds) on any CPU, so the wait is the same on a 68030 and on a PiStorm.
3. Seven times: read pin 9 (POTGOR bit 14 for the joystick port, bit 10 for the mouse port) and clock pin 6 low then high, with three CIA reads between the edges. The buttons come out in the order blue, red, yellow, green, right shoulder, left shoulder, play; 0 means pressed.
4. Set POTGO back to `$FF00` (pin 5 high: plain mode, clock edges ignored) and make the pin 6 lines inputs again.

Red becomes MSX trigger A, blue trigger B, yellow Space, green the M key and play F1. The shoulder buttons do nothing.

**Before** (`AmiMSX_Main_v3.1.asm`, `TesteaJoyRut`, AmiMSX 4.0 candidate):

```
	MOVE.W	#$6F00,$DFF034		; pin 5 low: latch
	MOVE.W	#200-1,D0
CD32Lat:
	TST.B	$BFE001			; ~300 us for pin 5 to fall
	DBF	D0,CD32Lat
	BSET	#7,$BFE001		; only now: pin 6 an output, high
	BSET	#7,$BFE201
```

**After** (commit f56a81b, from a peer review):

```
	BSET	#7,$BFE001		; Pin 6: an output, high, held so
	BSET	#7,$BFE201		; while pin 5 falls (no clock edge).
	MOVE.W	#$6F00,$DFF034		; Pin 5 low: latch
	MOVE.W	#200-1,D0
CD32Lat:
	TST.B	$BFE001			; ~300 us for pin 5 to fall
	DBF	D0,CD32Lat
```

*Source: AmiMSX 4.0 and 4.1.1, AmiMSX_Main_v3.1.asm (freeware by Juan Antonio Gómez Gálvez; 4.x changes; used with permission).*

**Why.** The pad's shift register loads its buttons while pin 5 is high and shifts on each rising edge of pin 6 once pin 5 is low. In plain mode a held red button pulls pin 6 low. If the Amiga only drives pin 6 high after the pad has entered shift mode, that rise is a clock edge: the register shifts one bit early, the identification bits land in the wrong places, and the pad is dropped whenever red is held. Holding the line high before pin 5 falls means nothing can move while the pad switches modes. This is the order the CD32 itself and the system library use.

**Evidence.** Found by reading the hardware description during the review; it could not be shown in the emulator. WinUAE's pad model lets an output override its emulated button and does not clock on a direction-register change, so it behaves the same in both orders, and the real pad's internals are not documented. The order was therefore chosen so that it does not depend on either.

**Look up.** Commits f56a81b, 38d0b84; `TesteaJoyRut`, `CD32KEY`; `tests/jtest.asm` (a small test ROM that shows both joysticks and keyboard rows on screen) and the `CD32TEST` build switch, which puts the raw button bits into a keyboard matrix row so a pad can be checked from the screen.

**No stack here.** The read runs from the frame path, where A7 is the Z80 core's page table. It keeps D3 and D4 in memory instead of pushing them (chapter 03, "A7 is a table pointer").

## Switchable adapters and pads that report every button

### Auto-detection by identification bits failed on real pads

*Fixed in 4.1.1.*

**Problem.** AmiMSX 4.0 detected a CD32 pad automatically, so a plain joystick kept working. In testers' hands the detection failed on a KTRL CD32 pad and on a Mega Multi adapter in CD32 mode. Both stayed plain joysticks, which was the original problem: direction and jump did not combine in Pampas & Selene, and the second button was missing in Gradius 2.

**Before** (`AmiMSX_Main_v3.1.asm`, AmiMSX 4.0). The read clocked nine bits and treated bit 7 = 1, bit 8 = 0 as the identification of a real pad. A port with no pad was probed every 16 frames, and a pad that failed a read was probed on each of the next 8 frames, so a plain joystick's fire line was rarely driven:

```
	MOVE.W	D2,D0
	AND.W	#$0180,D0
	CMP.W	#$0080,D0		; Bit 7 = 1, bit 8 = 0: a CD32 pad.
	BEQ.S	CD32Yes
	TST.B	CD32Pad			; No pad. Was one answering last
	...				; frame? Probe again for 8 frames.
```

**After** (commits bee6430 for 4.1, 38d0b84 and 4212d25 for 4.1.1):

```
; (4.1.1) CD32 pads: a menu option per port (PrefCD32 = the joystick
; port, PrefCD32M = the mouse port), saved with the prefs and per game.
; No auto-detection: a port set to CD32 pad is read with the CD32
; protocol every frame and its bits are taken as they come.
	TST.B	PrefCD32
	BEQ.S	CD32NoP2
	MOVE.B	#$80,D3			; pin 6 of port 2 to clock
	AND.W	#$6FFF,D0		; port 2: pin 5 low, pin 9 an input
CD32NoP2:
	TST.B	PrefCD32M
	BEQ.S	CD32NoP1
	OR.B	#$40,D3			; and port 1
	AND.W	#$F6FF,D0
CD32NoP1:
	...				; both ports latched and clocked in
					; the same loop: one wait a frame
```

A port left on Standard is never driven: its read is the old plain read, byte for byte.

*Source: AmiMSX 4.0 and 4.1.1, AmiMSX_Main_v3.1.asm (freeware by Juan Antonio Gómez Gálvez; 4.x changes; used with permission).*

**Why.** The identification test assumed that a real pad answers with a fixed pattern in the last two bits, and that a joystick cannot. Third-party pads and adapters do not all follow that. A detection that fails silently is worse than a menu item: the user cannot tell whether the pad, the adapter or the emulator is at fault. A per-port option also lets the mouse port carry a pad. A port set to CD32 pad costs about 300 microseconds a frame (1.5% of a 50 Hz frame), and a Standard port costs nothing.

**Evidence.**
- 4.1 switched the detection off (a build switch kept it for experiments), and 4.1.1 replaced it with the option and removed the probe code.
- Tested in WinUAE with a build that dumps the raw pad bits into a keyboard matrix row: the option bytes load, each port's path runs, the plain configuration is byte-identical to before, and nothing spurious reaches the MSX. WinUAE's emulated pad never answered in the test harness (its keyboard-layout joystick is not live there), so the protocol itself was verified against WinUAE's source and not against a running pad.
- Checked afterwards on a real A1200 with a KTRL CD32 pad: both fire buttons, Start/Play pausing and blue work; a plain joystick on Standard is unchanged. A Mega Multi adapter in its Standard mode first read as all seven CD32 buttons held (pin 9 never changes over the clocks), so Play paused the game: all seven at once is now taken as a plain pad. The same adapter in its CD32 mode did not answer the CD32 read in a later test (7 Nov 2026, AmiMSX 4.6 and the kit alike): only A and B worked, through the plain read. Whether that is the adapter or its setting is not known.

**Look up.** Commits bee6430, 38d0b84, 4212d25; `PrefCD32`, `PrefCD32M`; notes in `Docs/open_issues.md` (the three CD32 entries).

### A plain pad answers every clock with the same level

*Fixed in 4.1.1.*

**Problem.** With a port set to CD32 pad and a plain pad (or an adapter in its standard mode) connected, pressing the second fire button made the MSX see Space, M and F1 (pause) at once.

**Before.** The nine-clock bits were taken as they came. A plain pad shows the same pin 9 level for every clock, so when its second fire button was down all seven "buttons" read as pressed.

**After** (commit 6530efb):

```
; A port set to CD32 pad with a plain pad (or an adapter in its standard
; mode) answers every clock with the same pin 9 level: all seven 'buttons'
; pressed whenever its fire 2 is. A CD32 pad can't show that, so treat it as
; no pad: the plain read still gives fire 1/2, and no Space/M/F1 (pause).
	MOVE.B	D2,D0
	AND.B	#$7F,D0			; all seven bits 0 = all pressed
	BNE.S	CD32Ok2
	MOVEQ	#-1,D2			; -> released
CD32Ok2:
```

*Source: AmiMSX 4.1.1, AmiMSX_Main_v3.1.asm (freeware by Juan Antonio Gómez Gálvez; 4.x changes; used with permission).*

**Why.** A real CD32 pad cannot report red, blue, yellow, green, both shoulders and play all pressed at once, so that pattern is a signature of "not a CD32 pad", and it can be used to reject it without the identification bits. The plain two-button read still runs, so the pad keeps working as a joystick.

**Evidence.** Found when a plain pad was tried on a port set to CD32 pad. No measurement was recorded beyond the code review. **Look up:** commit 6530efb.

## CD32 pads from C, with the operating system running (Arnold)

*Arnold.* Arnold runs as an ordinary AmigaOS program, so it could have left the pads to lowlevel.library. On a PiStorm that did not work. Arnold now reads the pad itself, using the same protocol as AmiMSX. Both reads are in a standalone kit under an MIT licence: [kits/cd32pad](../kits/cd32pad/README.md).

### lowlevel.library only reported red on the PiStorm

**Problem.** On the PiStorm A1200 with a KTRL CD32 pad, `ReadJoyPort()` reported the pad as a game controller, but only the red button ever showed as pressed. Blue, yellow, green, the shoulders and play did nothing.

**Before** (`amiga_sys.c`, Arnold development before 1.0):

    for (port = 1; port < 4; port++) {
        ULONG v = ReadJoyPort(port);
        ULONG type = v & JP_TYPE_MASK;
        ...
        if (v & JPF_BUTTON_RED) m |= SYS_JOY_FIRE1;
        if (v & (JPF_BUTTON_BLUE | JPF_BUTTON_GREEN | JPF_BUTTON_YELLOW)) m |= SYS_JOY_FIRE2;
        ...

*Source: Arnold-m68k development before 1.0, `arnold/src/amiga/amiga_sys.c` (GPL-2.0, derived from Kevin Thacker's Arnold).*

**After** (commits 5558bc9, 29f07cf; now in `amiga_joy.c`): the buttons are read by hand, with interrupts off, and every wait is a run of CIA reads:

    Disable();
    *pra |= 0x80;                  /* clock high first... */
    *ddra |= 0x80;                 /* ...then port 2 fire line as an output */
    for (d = 0; d < 4; d++) dummy = *pra;
    custom.potgo = 0x6f00;         /* port 2: pin 5 output low (CD32 mode), pin 9 input */
    for (d = 0; d < 25; d++) dummy = *pra;
    for (i = 0; i < 9; i++) {
        for (d = 0; d < 10; d++) dummy = *pra;
        if (!(custom.potinp & 0x4000)) bits |= 1u << i;
        *pra &= ~0x80;             /* clock pulse: next bit */
        for (d = 0; d < 4; d++) dummy = *pra;
        *pra |= 0x80;
    }
    *ddra &= ~0x80;                /* fire line back to input */
    custom.potgo = 0xff00;         /* pin 5 high again: 2-button mode */
    Enable();

*Source: Arnold-m68k 1.7, `arnold/src/amiga/amiga_joy.c` (GPL-2.0); the same routine, for both ports, is in the MIT kit.*

The directions still come from `JOY1DAT`. Red is fire 1, and blue, yellow and green are fire 2. Whether a port has a CD32 pad is a menu option (`PAD=` argument, ToolType and preference), as in AmiMSX 4.1.1.

**Why.** A real pad's shift register needs time between clock edges. A routine whose delays are CPU instructions gets them right on the machine it was written for and too short on a CPU that runs 10 to 50 times faster. A read of a CIA register takes one E-clock (about 1.4 microseconds) on any CPU, because the CIA is on the real Amiga bus, so a wait made of CIA reads is the same length on a 68000 and on a PiStorm. Red survives the fast read because it is the plain-mode fire line, which is valid before any clocking starts.

**Evidence.** Arnold's `padtest` Shell tool (commit 564e69c) showed the hardware bits, lowlevel.library's value and the hand read side by side. With the KTRL pad, lowlevel.library showed red only, and the hand read showed all seven buttons and the ID bits. The first hand read still decided CD32 or not from lowlevel.library's controller type. Two days later that was dropped for the menu option, after a plain joystick read as a CD32 pad lost its fire button.

**Correction (November 2026).** The C above does not do what it says when built with gcc -O2. The NDK's `struct Custom` is not `volatile`, so the compiler removes the `custom.potgo = 0x6f00` write (the later 0xFF00 write overwrites it) and reads `POTINP` once for all nine bits. The pad never enters CD32 mode, and a held button reads as every bit at once. The objdump of Arnold 1.7's joystick code at its release flags shows exactly that, and so does `padtest` built at -O2, so the evidence above cannot be confirmed. The fix is to reach every chip register through a volatile pointer, `#define CUSTOM ((volatile struct Custom *)&custom)`. With it, the kit's `cd32test` reads a KTRL CD32 pad correctly on the PiStorm A1200: the ID bit at rest and each button on its own. The asm read never had the problem. Lesson: when a hardware read in C fails in a way that looks like a hardware fault, read the compiled code before blaming the pad.

**Look up.** Commits 5558bc9, 29f07cf, 564e69c; `read_cd32_buttons`, `padtest.c`; [kits/cd32pad](../kits/cd32pad/README.md), "The compiler trap in the C read".

### Notes from three projects

- **Read once or twice a frame.** Old snippets say a vertical blank must pass between two reads. In practice that is not needed. AmiPCEngine 1.4 reads the pad twice a frame on RTG: once at the vertical blank, and again just before it emulates the frame, to cut lag (see [On a fast machine, start the frame late and read the pad again first](#on-a-fast-machine-start-the-frame-late-and-read-the-pad-again-first)). This has caused no trouble with real pads on CD32 adapters.
- **Adapters send Start as play.** Use play for the console's Start or Run button. AmiPCEngine takes both shoulder buttons together as "back to the menu".
- **The latch wait.** AmiMSX waits about 300 microseconds for pin 5 to fall before the first bit. Arnold waits about 50 microseconds. Both work with the pads above. If a pad or adapter loses the first button (blue), lengthen the wait.
- **The asm kit routine pushes three registers.** That is fine in most programs. In one like AmiMSX, where interrupts run on a borrowed A7, keep them in memory (see "No stack here" above).
- **Directions in a nibble swap.** AmiPCEngine's first CD32 mapping put the d-pad into the buttons and the buttons into the d-pad. The bit order of the read is easy to mislabel, so test each button with a raw-bits tool (the kit's `cd32test`) before you map them.

## Keyboard mapping

### A table of (bit, row) pairs, patched for the host keyboard's faults

**Problem.** The Amiga 1200 keyboard cannot register some key combinations (Space together with Down), and a few MSX keys have no Amiga equivalent (SELECT, STOP, GRAPH, CODE).

**Design** (from 3.1, unchanged in the 4.x series). AmiMSX reads the raw key code from the CIA serial register, acknowledges it with the CIA handshake (a pulse held for five raster lines), and uses the 7-bit code as an index into a table with two bytes per key: the bit number and the row of the 16-row MSX keyboard matrix that the Z80 side reads.

```
MTECLADO:
	MOVEQ	#0,D0
	MOVE.B	$BFEC01,D0		; raw key code (inverted, rotated)
	...
	NOT.B	D0
	LSR.B	#$01,D0			; carry = key up
	BCS.S	NOTECLA
	MOVE.B	TECLADO(PC,D0.W*2),D2	; bit
	MOVE.B	TECLADO+1(PC,D0.W*2),D0	; row
	BMI	CapsON			; row -1: Caps Lock handling
	BCLR	D2,KEY(A3,D0.W)		; pressed: the MSX matrix is active low
	RTS
TECLADO:
	DC.B	7,01,1,00,2,00,3,00,4,00,5,00,6,00,7,00	; 00 - BIT , ROW
	...
```

*Source: AmiMSX 4.1.2, AmiMSX_Main_v3.1.asm (freeware by Juan Antonio Gómez Gálvez; 4.x changes; used with permission).*

The table is patched at start-up from menu options. The shift keys can be remapped to Space to work around the A1200's fault, and the Delete key can become Pause:

```
	MOVE.W	#$0006,TECLADO+($60*2)	; left shift: bit 0, row 6 = MSX SHIFT
	TST.B	$62(A5)			; option "Left and Right Shift as Space"
	BEQ.S	NOLSPACE
	MOVE.W	#$0008,TECLADO+($60*2)	; bit 0, row 8 = MSX SPACE
NOLSPACE:
```

The MSX keys with no Amiga counterpart use the function keys and Alt keys (F6 SELECT, F7 STOP, F8 HOME/CLS, F9 INS, F10 DEL, Left Alt GRAPH, Right Alt CODE). Left Amiga and Right Amiga are the second fire buttons of joysticks 1 and 2, and Left Amiga also swaps the disks in drives A and B. HELP leaves the emulator. A "multi-key" option keeps keys pressed in the matrix until the option is switched off, so a player can build up a chord one key at a time on a keyboard that cannot take them together.

**Why.** A lookup table is the cheapest way to map 128 key codes, and patching entries is cheaper than testing options on every key press. The patches are data writes into the program section at start-up, before the cache flush (`CacheClearU`) that follows every start of the emulation. A self-modifying-code audit found only such start-up patches (14 writes into code in total), and the notes record that Emu68 flushes its translated code on that call.

**Evidence.** This is the 3.1 design; nothing in the 4.x notes measured it. One test-related change is documented, in the next lesson.

### Scripted runs must ignore the host's input

**Problem.** In regression runs under WinUAE, moving the mouse over the WinUAE window changed the MSX picture. The mouse was read as MSX joystick 2.

**Before.** The joystick routine always read the host ports.

**After** (commit 20fa2e6; `TesteaJoyRut` and `MTECLADO`):

```
TesteaJoyRut:
	LEA	REGS,A3
	TST.L	KeyScrPtr		; Scripted test run: no host joystick or
	BEQ.S	TJoyHost		; mouse (moving the mouse over WinUAE
	ST	DATOJOY1(A3)		; read as MSX joystick 2).
	ST	DATOJOY2(A3)
	RTS
TJoyHost:
	...
```

*Source: AmiMSX 4.0, AmiMSX_Main_v3.1.asm (freeware by Juan Antonio Gómez Gálvez; 4.x changes; used with permission).*

**Why.** A test only means something if the same script gives the same MSX state at the same frame every time. When a key script is loaded, the key matrix is written only by the script; the keyboard handshake is still done, so the host's keyboard buffer does not fill, but the matrix is left alone. The key script is injected inside the emulator, so it does not depend on window focus either (chapter 06).

**Evidence.** Together with the other repeatability measures (chapter 06), a scripted run gave identical VRAM at frame 1500 across two runs (compared byte for byte), and most titles were fully repeatable. The exceptions are games that read input AmiMSX takes from the host, such as the mouse. **Look up:** commit 20fa2e6; `KeyScrPtr`; `Docs/regression.md`.

## Key remapping and a key-map editor (Arnold)

*Reading notes.* The CPC keyboard has keys the Amiga keyboard lacks or puts elsewhere, and some games want a key that is awkward to reach (Pinball Dreams flips the right flipper with a key on the right of the CPC keyboard, and the Amiga's Right Shift is not it). Arnold lets the user remap Amiga keys to CPC keys per game.

### Remap at the keyboard translation, behind one test

**Problem.** In Pinball Dreams the right flipper is on the CPC key M, and the user wanted Right Shift for it. A remap must cost nothing for every other program, because the key handler runs for every key event.

**Before.** Amiga rawkeys went through the joystick-key mapping (`joykey()`) and the normal key handling, with no per-key substitution.

**After** (`host_amiga.c`, commit f3dc177, option `remap=AMIGAKEY:CPCKEY[,...]` in the preferences, in a game's own preferences file, and as the `REMAP=` ToolType or argument):

    static void host_key(int code, int down, int qual)
    {
        ...
        if (remap_on && remap_key[code] >= 0) {
            if (down) CPC_SetKey(remap_key[code]); else CPC_ClearKey(remap_key[code]);
            return;
        }
        ... joykey() and the normal table ...

*Source: Arnold-m68k 1.0, `arnold/src/amiga/host_amiga.c` (GPL-2.0, derived from Kevin Thacker's Arnold).*

The remap table is indexed by the Amiga raw key code and filled when the preferences load; with no remap, `remap_on` is 0 and the cost is one test. The CPC key names are the ones the key scripts already use, so there is one list of names in the program.

**Why.** Remapping at the translation, before any other interpretation, means a remapped key behaves exactly like the CPC key it stands for in every mode (joystick keys, scripted runs). A side effect has to be documented: with `RSHIFT:M`, Right Shift no longer acts as Shift (use Left Shift).

**Evidence.** WinUAE with Pinball Dreams, ball launched, `REMAP=RSHIFT:M`: injecting Right Shift moves the picture in the flipper row at x 188 to 228 (the right flipper), injecting Left Shift at x 138 to 176 (the left). The Amiga Return key does not flip: the game's key is Enter or M.

**Look up.** Commit f3dc177; `KEYREMAP.md`.

### Test the hook the way a user reaches it

Key scripts gained `A:<amiga name>` to inject an Amiga raw key through `host_key`, so the remap and the joystick keys apply to scripted tests. The hook had to be set at the start of `main`, because `KEYS=` loads the script while the arguments are still being parsed (commit 5fdd886). A second bug was found only by a per-game preferences test in WinUAE: disk games should read `<disk A>.prefs`, but `game_prefs_name` compared `system.cpr` with `kwcmp`, which wants an upper-case keyword, so the comparison never matched and disk games never used their own preferences (commit 5473341). Rule: for every setting that is saved per game, run one test that saves it, restarts the program and checks the value was used.

### Presets in one table; the editor fits the smallest screen

The key-map screen has a preset list (None, Pinball with Right Shift = M, cursors to joystick, Q A O P to joystick, Right Alt and Right Amiga = fire 2) and an editor window (GadTools). Both are built from a single table so they cannot disagree:

    const struct KeyPreset KeyMap_Presets[] = {
        { "None",                       "" },
        { "Pinball (Right Shift = M)",  "RSHIFT:M" },
        ...
        { NULL, NULL }
    };

*Source: Arnold-m68k 1.0, `arnold/src/amiga/keymaplogic.c` (GPL-2.0, derived from Kevin Thacker's Arnold).*

The logic (preset table, parsing and printing of pairs, Amiga and CPC key names, the one-line summary that must fit the menu) is a plain C module with its own unit check (`tools/keymap_test.sh`: names valid, presets round-trip, summary fits), so the Amiga window code is only glue. Bugs found by running the editor in WinUAE: the menu window was not active again after the editor closed (`ActivateWindow`); the "Save for game" shortcut used raw key 0x22 instead of 0x24 (G); and a summary line of 76 characters clipped its last character, so the limit is 74. The editor and the menu both fit the 200-line NTSC screen (the editor ends near line 175); chapter 02 has the layout rule.

**Look up.** Commits 677bfc9, adb8aec, c7c1f6b; `KEYMAP.md`; `KeyMap_Presets`.

## Cutting input lag (AmiPCEngine)

*AmiPCEngine.* An emulator adds lag on top of the game's own: the pad is read once, the guest frame that uses it is emulated, and the picture is copied to the screen. On a PC Engine game, a press reached the screen two to three frames late (40 to 60 ms at 50 Hz), and reading the code suggested about two of those frames were the emulator's. The two lessons below took back one whole frame (measured) and then 11 to 14 ms more on RTG, each behind its own switch. On the A1200 (PiStorm), a tester's verdict on R-Type with a CD32 pad was "feels very responsive".

### Start the emulated frame at the guest's vertical blank, not at its line 0

**Problem.** The emulator read the pad in the Amiga's vertical blank interrupt, then emulated one whole PC Engine frame, lines 0 to 262. A PC Engine game reads its pad in its own vblank interrupt, which the video chip raises after the last picture line (line 240 for R-Type). So the game saw the press near the end of the emulated frame, and what it did with it was drawn in the next one.

**Before** (`src/PCE.asm`, `PCE_Start`, AmiPCEngine 1.3):

	PCE_Start:
		MOVEQ.L	#0,D0			; line 0 ...
		MOVE.L	#263-1,D1		; ... to 262: one PCE frame
		...				; line-0 work: sprite table copy, scroll log
	PCE_StaBuc:
		...				; one line
		ADDQ.W	#1,D0
		DBF	D1,PCE_StaBuc

**After** (commit 529f488, switch `NO_VBLUNIT`), reduced:

	PCE_Start:
		MOVE.W	UnitStart,D0		; on from the last frame's vblank line
		...
	PCE_StaBuc:
		CMP.W	#263,D0
		BCS.S	.in
		MOVEQ	#0,D0
		BSR	PCE_FrameTop		; the line-0 work, where the guest frame wraps
	.in:	...				; one line
		ADDQ.W	#1,D0
		TST.B	UnitWrapped
		BEQ.S	.go
		CMP.W	VblLine,D0		; the vblank line again: this emulated frame ends
		BCC.S	.end
	.go:	DBF	D1,PCE_StaBuc
	.end:	MOVE.W	D0,UnitStart

*Source: AmiPCEngine 1.4 development, src/PCE.asm (freeware by Juan Antonio Gómez Gálvez and z00p; used with permission).*

**Why.** One emulated frame is now the vblank lines of guest frame N-1 followed by the picture lines of frame N. The game's vblank handler runs first and reads the pad sampled at this Amiga vblank, so whatever it changes is in the next emulated frame's picture, one frame sooner than before. That saves one whole frame, with no extra work: the same lines run, in a different order. The work is in moving everything that was keyed to "the start of the emulated frame" to the place where the guest frame wraps (`PCE_FrameTop`). That means the copy of the sprite table the frame shows, the start of the per-line scroll and colour logs, the scripted test input, and the sound samples filed by line. Anything you forget shows up as a one-frame shift against the reference emulator. That is why every scripted comparison was rerun.

**Evidence.** Press to picture, WinUAE, RTG. A test switch applies a scripted press where the real pad is read (in the Amiga vblank interrupt), and a sum of every composed frame over 64 frames is compared between a run with the press and one without. Taking P as the first emulated frame that can use the press, the first changed picture is P+1 with the switch and P+2 without it, in all three titles tried: R-Type in play, Parodius in play and Soldier Blade's attract mode. Every pair is identical before the press. The frame that is left looks like the games' own (they read the pad in their vblank and the change shows the frame after), but it was not checked against the reference.

WinUAE regressions: 69 of 69 titles on RTG and on AGA, memory guards clean, stack use unchanged. On the A1200, vblanks for the same 2400 frames (1500 for Soldier Blade) moved within noise: Parodius 2602 to 2603, Soldier Blade 1649 to 1655, Street Fighter II' 2430 to 2437. With the switch set to 1 the binary is the 1.3 release byte for byte.

**Look up.** Commit 529f488; switch `NO_VBLUNIT`; `PCE_FrameTop`, `UnitStart`; the press test: commit a8f3975, switches `AutoPressHost`, `RtgSumFrom`, `tools/lagrun.sh`, `tools/lagcmp.py`; notes `docs/agent_notes/lag.md`.

### On a fast machine, start the frame late and read the pad again first

**Problem.** On RTG the A1200 (PiStorm) needs only 13 to 26% of a frame to emulate and draw a PC Engine frame in these runs (8 titles, one scanline setting; the speed sweep in chapter 12 reaches 28% with the strongest scanlines). It started straight after the vblank and then sat idle. A press made during that idle time waited for the next vblank.

**After** (commit db36ef2, switch `NO_LATESTART`, RTG only), reduced:

	LateStart:				; after the last frame is on screen
		...				; D2 = slowest of the last 16 frames (lines)
		MOVE.W	D2,D1			; margin: 24 lines + a quarter
		LSR.W	#2,D1
		ADD.W	#24,D1
		ADD.W	D1,D2
		MOVE.W	LsFrame,D3		; lines from vblank to vblank, measured
		SUB.W	D2,D3			; start at: frame - (work + margin)
		BLE.S	.read			; no time to spare: start now
	.wt:	TST.B	vBlankOccurred		; never past the next vblank
		BNE.S	.read
		BSR	LsTod			; CIA-B time of day: lines
		SUB.W	LsVblTod,D0
		CMP.W	D3,D0
		BLT.S	.wt
	.read:	MOVE.W	#$4000,$DFF09A		; the pad, as the vblank interrupt reads it
		MOVE.L	JoyControlRut,A0
		JSR	(A0)
		...
		MOVE.W	#$C000,$DFF09A

`LateEnd` adds each frame's working time to a ring of 16. A frame still running at the next vblank turns the wait off for 50 frames.

*Source: AmiPCEngine 1.4 development, src/Main.asm (freeware by Juan Antonio Gómez Gálvez and z00p; used with permission).*

**Why.** This is the "frame delay" idea from PC emulators, made adaptive. The wait leaves just enough of the frame for the slowest recent frame plus a margin, then reads the pad again, so the game sees a press made up to most of a frame later. Times are in raster lines from the CIA-B time-of-day counter, which counts horizontal syncs on any CPU and in any display mode (chapter 06, debug rows). The interrupt notes the counter at each vblank, which gives the real frame length (262 or 313 lines; a reading outside 200 to 330 is ignored, and until there is one there is no wait). A heavy game, or a frame that runs late, just falls back to starting at once. Nothing is lost except the gain. It is not used on AGA, where some games already need more than a frame.

Reading the pad twice a frame broke an old rule written over the classic CD32 pad read ("one VBL must have elapsed before repeating this"). On real pads through CD32 adapters it made no difference.

**Evidence.** A1200, 8 RTG titles at full speed with no late frames. "Busy" (everything but the vblank wait) went from 13-26% to 81-85% of the frame, so the frame now starts 57 to 70% of a frame after the vblank: the pad is read 11 to 14 ms later than before, and that much lag is gone. 15 to 19% of the frame is still spare (the margin), which can be tightened later. WinUAE RTG regression: 69 of 69, vblanks unchanged.

**Look up.** Commit db36ef2; switch `NO_LATESTART`; `LateStart`, `LateEnd`, `LsTod`; the `DLAY` figure on the debug rows (lines waited); notes `docs/agent_notes/lag.md`.

## Controller lag: measure the frame, then reorder it (AmiMSX)

Lag is the time from a stick movement to the first picture that shows the game's answer. The game's own share (it may read the stick once a frame, or move the ship a frame later) is the same on every emulator, so the part worth working on is ours: when the input is read, how long after that the frame is emulated, and when the result reaches the screen.

### Log where each frame waits before changing anything

**Problem.** Players on a PiStorm A1200 asked for quicker response, and the code did not say where the time went: the frame loop had grown over many versions (frame skip, double buffer, RTG, key scripts).

**Before.** No measurement: only "it feels a bit slow", which cannot tell a change of one frame from none.

**After** (a log build, `-DLAGLOG=1`). For every emulated frame, three stamps of the VBlank count and beam line: at the end of the emulation, after the input read, and after the render. Then a sum of the video memory at the render, and, for each change of the input, the frame and line where the game first read it. The same key script runs twice in WinUAE, without and with a press at frame N; the first frame whose video sum differs is the game's answer. The log is written at the first return to the menu, so the same build runs on the real machine: the player plays, presses HELP, and sends the file.

    Emula1Frame:
        IFD   LAGLOG
        JSR   LagEntry          ; end of the emulated frame: VBlank, beam line
        ENDC
        ...
        BSR   Wait60fps         ; the tick (copper interrupt, ~line 236)
        ...
        JSR   Act_Hardware      ; keyboard and joysticks read here
        ...
        IFD   LAGLOG
        JSR   LagSample         ; the input as sampled
        ENDC
        ...
    RendDone:
        IFD   LAGLOG
        JSR   LagRender         ; render done, video memory sum
        ENDC

*Source: AmiMSX 4.7 (in development), AmiMSX_Main_v3.1.asm (freeware, used with permission).*

**Why.** Every frame of the emulator is a pipeline: wait for the tick, read the input, emulate (the game reads the input), draw, show. Changes to lag are about the order of those steps, and a log of where each step lands on the beam shows the order as it really runs, on each machine.

**Evidence.** The first log showed that every emulated frame was drawn one tick after it was emulated: the loop emulated a frame, then waited for the next tick before drawing it. On the A1200 the PiStorm emulates a frame in about a tenth of a frame and draws it in about half a frame, so most of the frame was spent waiting with a finished picture.

**Look up.** Commit 28245b7; `tools/lagtest.py` (press and no-press runs, the analysis), `tools/lagshown.py` (read-to-shown for the double buffer); notes `Docs/agent_notes/lag-4.7.md`. The log is in BSS, so its marker reads as zero in the file: the tools find it at a fixed offset from the end (see [chapter 07](07-toolchains-release.md#incbin-into-a-bss-section-gives-zeros-silently) for the same trap with `INCBIN`).

### Draw the frame as soon as it is emulated

**Problem.** On the RTG screen (HDMI), each press reached the screen one tick (20 ms at 50 Hz) later than it had to.

**Before** (`AmiMSX_Main_v3.1.asm`, 4.6): the frame just emulated waits for the next tick, then the input is read, then the frame is drawn.

    Emula1Frame:
        BSR   Wait60fps         ; wait for the next tick
        ...
        JSR   Act_Hardware      ; read the input
        ...
        JSR   RtgFrame          ; draw the frame emulated before the wait

**After** (commit b970b3a, switch `NO_EARLYDRAW`): an RTG frame is drawn first, then the wait, then the input read; after the wait only a key-script capture is left.

    Emula1Frame:
        SF    EarlyDone
        JSR   RtgUse
        TST.B RtgNow
        BEQ.S E1FLate           ; AGA: as before
        BSR   E1FTail           ; draw it now
        ST    EarlyDone
    E1FLate:
        ...
        BSR   Wait60fps
        ...
        JSR   Act_Hardware
        ...
        TST.B EarlyDone
        BEQ.S E1FTail           ; not drawn yet: draw now (the old order)
        ...                     ; drawn: only a pending SNAP
        RTS

*Source: AmiMSX 4.7 (in development), AmiMSX_Main_v3.1.asm (freeware, used with permission).*

**Why.** The wait exists to pace the emulation at 50 or 60 frames a second, not to hold a finished picture. A fast machine finishes the frame long before the next tick, so it can be shown at once. A slow machine loses nothing: it would have drawn right after the wait anyway.

**Evidence.** WinUAE (RTG, real time, Nemesis 2, a press at four offsets): every press on screen one tick sooner. A1200 (PiStorm, RTG over HDMI), the player's log: input read to the end of the drawing 50 beam lines median (3 ms), 99th percentile 9 ms; before, about 460 lines (29 ms). By feel, in an A/B the player preferred the new build. Regression: the same pictures as before on every title where both runs caught one.

**Look up.** Commit b970b3a; `NO_EARLYDRAW`.

### Commit the double-buffered frame before the wait, too

**Problem.** With the double buffer on (AGA, SCREEN 4, the PiStorm preset: chapter 02), a frame read its input at one tick, was drawn at the next tick, committed at the start of the pass after that, and shown from the following VBlank: the finished picture waited a whole pass for its commit.

**Before** (4.6): the commit of the last frame at the start of the pass, then the wait, the copper list for the new frame, the input, the render into the back buffer. The render's picture waits a whole pass for its commit.

**After** (commit 9779ef5, switch `NO_EARLYDB`): when the double buffer is running, the copper list, the render into the back buffer and the commit all happen before the wait. The pass after the wait only reads the input.

    E1FEarDb:
        LEA   Regs(PC),A3
        TST.B DbOn              ; double buffer running, SCREEN 4,
        BEQ.S E1FEdX            ; option on, no MSX-Music...
        ...
        JSR   ActBorder         ; border colour into this frame's snapshot
        JSR   DbLineSafe        ; the list on screen is not rebuilt
        JSR   BMSPrep
        JSR   ActCopperLine     ; the per-line copper list
        LEA   Regs(PC),A3       ; (ActCopperLine's list pointer)
        BSR   E1FTail           ; render into the back buffer
        JSR   DbCommitF         ; commit (or drop it, if late)
        ST    EarlyDone
    E1FEdX:
        RTS

*Source: AmiMSX 4.7 (in development), AmiMSX_Main_v3.1.asm (freeware, used with permission).*

**Why.** The double buffer exists so a frame is shown whole at a frame start. It does not need the render to wait for the next tick: the render's own wait (for the VBlank after the last commit, before the old front buffer is drawn over) already keeps it off the screen until it is safe. Everything the late-frame logic relied on (drop a frame that finishes after the next VBlank) still holds, because the commit test reads the VBlank count and beam line, not its place in the loop.

**Evidence.** WinUAE (68060, Space Manbow, double buffer on, no press), from the input read to the commit plus one VBlank: median 4 VBlanks before, 3 after; 95th percentile 5 before, 4 after. Regression with the double buffer on (15 titles on the 68030 config): the same pictures as the old build. The A1200 check was still to come when this was written.

**Look up.** Commit 9779ef5; `NO_EARLYDB`; `tools/lagshown.py`. Moving a call before a register reload broke it at first: [Reordering a frame loop moves calls before a register reload](06-testing.md#reordering-a-frame-loop-moves-calls-before-a-register-reload).

### A faster path is not a better one until someone has looked at it

**Problem.** With the render now taking a quarter of a frame on the PiStorm, the double buffer looked unnecessary: it costs one frame of lag in SCREEN 4 games, and live drawing should finish before the beam reaches the picture.

**Before.** The plan was to drop the double buffer on fast machines if the log showed live drawing staying ahead of the beam.

**After.** A preset with the double buffer off went to the player for an A/B through the scaler, and the double buffer stays.

**Why.** The log measures our timing, not the picture. Its figures were good, but the player saw scrolling judder without the double buffer, and that ended the experiment. Ask for an A/B by eye on the real display chain before removing anything that exists for the picture.

**Evidence.** A1200 log with the double buffer off (Space Manbow): render 76 beam lines median, 163 at the 99th percentile, 6 of 728 frames late. Player: "jittery", a deal breaker.

### Read the input late, but only where the picture's time is fixed

**Problem.** With live drawing on AGA (every mode but SCREEN 4 on the PiStorm preset, and every mode on the 68030 preset), the frame is drawn at the tick, straight into the bitplanes on screen and behind the beam. The Z80 then emulates the next frame in about a tenth of a frame, and the loop idles until the next tick. The input that frame uses was read at the tick, most of a frame before the frame needed it.

**Before** (4.6, and 4.7 up to Fix A): tick, input read, draw the last frame, emulate the next, idle.

**After** (commit dbe8a5f, switch `NO_LATEREAD`): the keyboard and joystick part of the input read moves to just before the next tick. The sound updates stay at the tick, so they do not move with the read.

    LrRead:                         ; after Emula1Frame
        TST.B   LateRd              ; AGA live drawing, times known
        BEQ.S   LrRdT
        ...                         ; D2 = slowest emulation of the last 32
        MOVE.W  LrPer(PC),D1        ; tick to tick, measured
        SUB.L   D2,D1
        SUB.L   #LRMARGIN,D1        ; 24 lines
        BLE.S   LrRdK               ; no time to spare: read now
        ADD.L   LrTick(PC),D1       ; CIA-B TOD at the last tick
    LrWt:
        BSR     TodNow
        ...                         ; wait for the target line
    LrRdK:
        JSR     ActKeyJoy           ; keyboard and joysticks

*Source: AmiMSX 4.7 (in development), AmiMSX_Main_v3.1.asm (freeware, used with permission).*

**Why.** This is the same sizing rule as the late start of AmiPCEngine and Arnold (above; Arnold's runs only with its lock to the HDMI blank, for the reason below), which move the whole frame's start. Here only the read moves, because the draw is tied to the tick. Why it fits only one of AmiMSX's three display paths is worth knowing before copying it. A later read shortens the lag only if the picture still reaches the screen at the same moment.
- AGA live drawing: the frame is always drawn at the next tick, so reading later is pure gain.
- RTG: one buffer, written as soon as the frame is emulated and not locked to the HDMI refresh, so a later read only shows later. (AmiPCEngine's RTG copy waits for the Amiga vblank, which is why the late start fits there.)
- Smooth Display: the render waits for the vertical blank after the last commit, so its read can move only about 40 lines.

Check where the frame boundary sits first. AmiMSX already starts the emulated frame at the MSX's own vertical blank (VDP line 192, with the game's interrupt straight after), so AmiPCEngine's first saving was already in place.

**Evidence.** Simulated on the A1200 timing logs (Space Manbow, the slowest-of-32 rule, 24 lines of margin): the read 231 to 250 lines later at the median (about 15 ms), with 9 frames late in 974 and in 4084. A late frame costs no frame here: the tick has already passed, so the wait returns at once and that frame is drawn a little late. WinUAE (68060 config, Nemesis 2): the read moved from 313 lines before the next tick to 131 (median). Regression: the same pictures on 15 titles (key scripts apply their keys by frame, not at the read). The A1200 check by feel was still to come when this was written.

**Look up.** Commit dbe8a5f; `NO_LATEREAD`, `LrRead`, `LrDecide`; notes `Docs/agent_notes/lag-4.7.md` ("Fix B").

### Lag outside the emulator

These add more than any of the above, and only the player can change them: the TV's game mode on the HDMI input; Paula by cable rather than HDMI sound through a Bluetooth link; wired or 2.4 GHz pads rather than Bluetooth ones. Say so in the documentation, so players do not chase a frame in the emulator while losing three in the TV.

## Controller lag: the frame boundary and a late start (Arnold)

*Arnold.* The same question as the two sections above, for a C emulator that runs with the operating system. This work is for Arnold 1.8 (in development).

Arnold splits lag into five parts:

1. **The wait for the sample.** The host reads the pad once a frame, so a press waits up to a frame (10 ms on average) before anyone sees it. A real machine has the same wait before the game's own read.
2. **The game's own frames.** Many games read the stick in one frame and draw the answer in the next. That belongs to the game, and the emulator must keep it.
3. **The emulator's frame boundary.** If the emulator's frame ends in the wrong place, the answer can miss a picture and wait a whole extra frame. This part is the emulator's fault, and it can be removed.
4. **Emulation and presentation.** The time from the sample to the picture on the output: the emulation of the frame, the conversion, and the wait for the blank at which the picture goes up.
5. **The TV.** Use game mode. HDMI sound sent to a Bluetooth speaker arrives late, but that does not delay the picture.

### The host's time from sample to picture, and the game's frames

**Problem.** "It feels laggy" does not say which of the five parts to work on. And a host timing alone missed the biggest cut, the frame boundary, because that cut does not change the host's time from sample to picture at all.

**Before.** No figures. The stick was read once a frame, after the 50 Hz wait, and the whole frame was emulated with that value.

**After** (`amiga_sys.c`, switch `NO_LAGLOG` to remove). There are two measures.

The first is a host log. The sample time goes with the frame as a tag through the RTG layer. The vertical blank task records the tag and the time at which it writes that frame, which is when the picture goes up. The next sample collects it:

    void Sys_LagSample(void)
    {
        unsigned long now = Sys_Micros();
        if (Sys_RtgActive) {
            uint32_t tag, wr, n = rtg_x_lag_last(&tag, &wr);
            if (n != lag_seq) { lag_seq = n; if (tag) lag_add(wr - tag); }
        }
        ...
        lag_ts = now;
    }
    ...
    rtg_x_lag_tag(lag_ts);              /* just before rtg_present() */
    e = rtg_present(chunky, pitch, ...);

*Source: Arnold-m68k 1.8 development, `arnold/src/amiga/amiga_sys.c` (GPL-2.0), calling rtgfw (MIT).*

On AGA the figure comes from the beam line of the flip plus the lines left to the vertical blank. The log prints the average, minimum and maximum, and how many frames missed the blank they were made for. The cost is one E-clock read a frame and a semaphore pair in the vertical blank task.

The second measure is the game's frames, counted headless on a PC. Run a key script with and without one press at frame F, and find the first picture that differs. "1 unit" means the answer is in the first picture after the sample, the best possible with one sample a frame. A test-only build switch (`LAGTRACE`) also prints, for each frame, where the frame cut fell against the machine's VSYNC and when the game read the stick.

**Why.** The two measures see different parts. The host log sees part 4, which is real time on the real machine. The headless count sees parts 2 and 3, in whole frames, and is exactly repeatable.

**Evidence.** On the A1200, Sonic GX in a fast vertical scroll, 45 s runs:

| Output | Sample to picture, average (ms) |
|---|---|
| RTG, HDMI sound, frames locked to the HDMI blank | 19.2 to 19.3 |
| The same, with the late start (below) | 15.2 to 15.6 |
| RTG, Paula sound, not locked | 18.8 (6 to 32, swinging with the 49.93/50 Hz beat) |
| AGA, Paula sound | 23.5 |

Headless, 1 to 3 units from the sample to the first changed picture. One of those frames was often the emulator's (next lesson).

**Look up.** `Sys_LagSample`, `rtg_x_lag_tag`, `rtg_x_lag_last`; `tools/lag18/lagtest.py`; notes `Docs/agent_notes/lag18.md`.

### End the frame at the machine's VSYNC

This is the CPC counterpart of AmiPCEngine's frame that starts at the guest's vertical blank (above). Arnold keeps the frame length fixed and moves the boundary once instead of reordering the lines.

**Problem.** Sonic GX and Puzzle Bobble answered a press one frame later than Ghosts 'n Goblins, and in a fast scroll the top band of Sonic's picture was one frame newer than the rest.

**Before** (`arnold.c`, Arnold 1.7). Each emulated frame is 19968 cycles (312 lines of 64 µs), counted from power on. The frame boundary is not tied to the CPC's VSYNC, so where it falls in the game's frame depends on how the game set up the video chip: 60 lines after the VSYNC in Sonic GX, 65 in Puzzle Bobble, 253 in Ghosts 'n Goblins.

**After** (commit 01a84b2, switch `NO_VSYNCCUT`, run-time `VSYNCCUT=0`). Frames stay 19968 cycles. If the boundary has been away from the VSYNC for two frames in the same place, one frame is made shorter, or longer, so that the next boundary falls 32 cycles after the VSYNC:

    static int Vcut_FrameLength(void)
    {
        CRTC_INTERNAL_STATE *s = CRTC_GetInternalState();
        int e = s->Monitor_State.MonitorScanLineCount * 64 + s->Monitor_State.MonitorHorizontalCount;
        int prev = VcutPrevE, L;
        VcutPrevE = e;
        if (e < VCUT_AFTER || e > NOPS_PER_MONITOR_SCREEN - VCUT_BEFORE) return NOPS_PER_MONITOR_SCREEN;   /* at the VSYNC */
        if (prev < 0 || e - prev > 128 || prev - e > 128) return NOPS_PER_MONITOR_SCREEN;   /* not steady yet */
        L = NOPS_PER_MONITOR_SCREEN - e + VCUT_T;
        if (L < NOPS_PER_MONITOR_SCREEN / 2) L += NOPS_PER_MONITOR_SCREEN;
        VcutPrevE = -1;
        CPC_VcutShifts++;
        return L;
    }

*Source: Arnold-m68k 1.8 development, `arnold/src/cpc/arnold.c` (GPL-2.0, derived from Kevin Thacker's Arnold).*

The sound stays on the old fixed grid of 19968-cycle points through a host hook, so the sound blocks and the emulated machine at each old boundary are unchanged. A host that does not set the hook gets the old boundary. The Amiga host waits once per sound block, not once per frame, so the frame that moves the boundary (0 or 2 blocks long) keeps the pace.

**Why.** Puzzle Bobble reads the stick at the VSYNC and draws the answer 198 lines later. A boundary at line 65 falls between the two, so the answer lands in the next picture. Sonic GX reads at line 51 and moves its sprite in the next frame, and the boundary at line 60 split that frame across two pictures. Ghosts 'n Goblins reads at the VSYNC and its boundary was late, so it lost nothing. With the boundary at the VSYNC, every picture is also one whole frame of the machine, and the seam is gone.

**Evidence.**
- Headless, first changed picture: Sonic GX 2 units to 1, Puzzle Bobble 2 to 1, Ghosts 'n Goblins 1 to 1.
- Exactness: with the cut off (`NOVCUT=1` in the headless host), every frame checksum and the sound equal 1.7's. With the cut on and the key script applied at the old grid, the CPU cycle count, all Z80 registers and a hash of the 64 KB RAM equal 1.7's at every grid point over 900 to 2400 frames of four games.
- The seam: every 1.7 picture of a Sonic GX scroll was the top of the new frame k+1 over the bottom of frame k, cut at row 28, in 19 frames of 19.
- On the A1200, a tester's feel test: "much more responsive".

**What it cost.**
- Every key-script baseline with presses changed once, because a press now reaches the CPU at the new boundary. Of 207 headless checks, 108 were unchanged, 13 changed because only the cut moved, and 86 changed because the cut moved and the presses arrived at a different time. None was unexplained.
- On the A1200, one late frame and one skipped frame per run, at the screen changes where the boundary moves.
- A save state needs two more values. Older states load into the new build exactly.

**Look up.** Commit 01a84b2; `Vcut_FrameLength`, `CPC_AudioFrameHook`; headless `NOVCUT`, `GRIDSTATE`, `KEYGRID`, `FRAMEDUMP`; `tools/lag18/vc_proof.sh`, `splice.py`.

### Start the frame late, by the measured work (RTG, locked to the blank)

The same adaptive late start as AmiPCEngine's (above), in C, timed in microseconds from the E-clock, and placed against the HDMI blank that Arnold's RTG output is locked to.

**Problem.** With RTG frames locked to the HDMI blank, each frame started 0.5 ms after a blank. The frame took 9 to 14 ms to emulate and present, so the picture waited several milliseconds for the next blank, and the stick sample was that much older than it needed to be.

**Before** (Arnold 1.7). Each frame is due `SYS_LOCK_US` (500 µs) after a blank.

**After** (switch `NO_LATESTART`, preference `lsmargin=`, argument `LSMARGIN=`; 0 turns it off). The start moves later, to the period minus the slowest work of the last 32 frames minus a margin (4 ms by default):

    static long ls_next(long per)
    {
        long cur = ls_off ? ls_off : SYS_LOCK_US, tgt = SYS_LOCK_US;
        ls_per = per;
        if (ls_hold) ls_hold--;
        else if (Sys_LateMarginUs > 0 && ls_wn >= LS_WIN) {
            unsigned long mx = 0; int i;
            for (i = 0; i < LS_WIN; i++) if (ls_work[i] > mx) mx = ls_work[i];
            tgt = per - (long)mx - Sys_LateMarginUs;
            if (tgt < SYS_LOCK_US) tgt = SYS_LOCK_US;
            if (tgt > per - 2000) tgt = per - 2000;
        }
        if (tgt > cur + 500) tgt = cur + 500;
        ls_off = tgt;
        ...
        return tgt;
    }

*Source: Arnold-m68k 1.8 development, `arnold/src/amiga/amiga_sys.c` (GPL-2.0).*

"Work" is the time from the sample to `rtg_present`. The start moves later by at most 0.5 ms a frame and earlier at once. A frame that presents within 0.3 ms of its blank puts the start back to 0.5 ms for 50 frames (a "hold"). When the start moves, the due time moves by exactly the difference, so it can never slip to another blank. AGA, and RTG without the lock, are not touched.

**Why.** The picture can only go up at a blank, so any time between the end of the work and that blank is wasted. Spending it before the sample instead makes the sample newer by the same amount. Taking the slowest recent frame, not the average, keeps the picture on its blank when the game has a heavy frame.

**Evidence.** On the A1200 (Sonic GX scroll, two runs each): average sample to picture 19.30 and 19.18 ms without it, 15.19 and 15.59 ms with it. No frame missed its blank with the late start; without it, one run had 5 late frames. In a blind A/B on the real machine (presets labelled A and B), the tester found both responsive, with "maybe B had the edge". B was the late start.

**Look up.** `ls_next`, `ls_present`; perf lines `latestart_*`; notes `Docs/agent_notes/lag18.md`, "Late start".

### Ask the tester the right question

**Problem.** After the first feel test, the tester wrote "Late off". That could mean "the build with the late start off felt better" or "I tested the build called LateOff". A photo of the drawer did not settle it.

**After.** A blind A/B: the same build twice, as two icons named "Preset A" and "Preset B", one with each setting. The tester was not told which was which and was asked one question: which felt more responsive, or neither?

**Why.** A difference of 4 ms is near the limit of what anyone can feel, so the result is easily swayed by a name like "LateOff". Neutral names remove that, and a one-line question gets a one-line answer.

**Evidence.** The blind result (both responsive, a slight edge to the late start) overrode the first impression, and the late start stayed on by default.

### What is left

- **Read the stick at the game's own read.** The game reads the joystick part-way through the emulated frame, but sees the value sampled at the frame start. Asking the host for a fresh value at that read would save the time from the frame start to the read: in Sonic GX nearly all the work time, 9 to 12 ms on RTG and up to about 20 ms on AGA. It is the only cut left on AGA, where the frames are too full to start later. Not measured yet.
- **Fewer RTG anchors.** A re-anchor to the HDMI blank can spin for a whole period. That gave the one 38.6 ms maximum in the measurements above.
