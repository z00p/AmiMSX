# Input

*Reading notes.* The examples come from AmiMSX, which takes over the machine while the MSX runs. It reads the joystick ports and the keyboard through the custom chips and the CIAs and never goes through the operating system's input handling, so it has to implement the CD32 pad protocol itself. Commit references name the AmiMSX development repository; the public repository carries squashed commits.

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
- Checked afterwards on a real A1200 with a KTRL CD32 pad and a Mega Multi adapter in CD32 mode: both fire buttons, Start/Play pausing, and the extra buttons work; a plain joystick on Standard is unchanged.

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
