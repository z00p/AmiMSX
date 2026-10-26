# CPU cores in 68k

*Reading notes.* The examples come from AmiMSX's Z80 core: every Z80 instruction is a 68k handler reached through a 256-entry jump table, and the Z80 registers live in 68k registers. In the excerpts D7 is the Z80 A register, D3 its flags, D4 HL, D5 BC, A5 the program counter (as a host address), A6 the stack pointer (as a host address) and A3 the base of the register block (`REGS`). Commit references name the AmiMSX development repository; the public repository carries squashed commits.

## Register conventions and no stack in handlers

### A7 is a table pointer, not a stack

**Problem.** On a PiStorm A1200 with a joystick port set to "CD32 pad", AmiMSX hung now and then at MSX start-up (seen with Nemesis 2 Enhanced). It never hung with the port set to Standard.

**Background.** To keep the Z80 program counter check cheap, the core uses the 68k stack pointer as a pointer into a per-page table in the register block. `(A7)` holds the number that turns the host program counter back into a Z80 address, and `Desbor+4(A7)` holds the host address where the current page (8 KB) ends. Fetching a byte that may cross a page boundary is then one compare:

```
CheckB:	MACRO
	CMP.L	Desbor+4(A7),A5		; PC past the end of this page?
	BLE.S	\@NO
	SUBQ.W	#1,A5
	MOVE.W	A5,D1
	SUB.W	(A7),D1			; host address -> Z80 address
	CogePag	D1,A5			; the next page's pointer
	LEA	Restas(A3,D1.W*8),A7	; A7 now points at that page's entry
	MOVE.B	(A5)+,\1
\@NO:
	ENDM
```

*Source: AmiMSX 4.1.2, AmiMSX_Main_v3.1.asm (freeware by Juan Antonio Gómez Gálvez; 4.x changes; used with permission).*

Every Z80 handler, and every routine called from a handler (port I/O, the VDP command engine, the plane conversions, the once-a-frame input read), therefore runs with A7 pointing into the table of live page entries. One call level is tolerated: its return address lands in a scratch long that each page entry reserves. A second level, or any push, writes over a neighbouring page's entry.

**Before** (`AmiMSX_Main_v3.1.asm`, the CD32 pad read, AmiMSX 4.1.1 candidate):

```
	MOVEM.L	D3/D4,-(SP)		; 8-byte push on the Z80 core's A7
	MOVEQ	#0,D3			; ...
	...
	MOVEM.L	(SP)+,D3/D4
```

**After** (commit c969a0e):

```
	MOVE.L	D3,CD32SvD3		; (No stack: the frame interrupt runs on the
	MOVE.L	D4,CD32SvD4		; Z80 core's A7, the Restas table.)
	MOVEQ	#0,D3
	...
	MOVE.L	CD32SvD3,D3
	MOVE.L	CD32SvD4,D4
...
CD32SvD3:	DC.L	0
CD32SvD4:	DC.L	0
```

*Source: AmiMSX 4.1.1, AmiMSX_Main_v3.1.asm (freeware by Juan Antonio Gómez Gálvez; 4.x changes; used with permission).*

**Why.** The new input code was called from the frame interrupt. When the interrupt landed at the wrong moment, the 8-byte MOVEM push overwrote a live page entry, and the next page-boundary crossing used garbage. Whether it hurt depended on which page the Z80 was executing, which is why it was intermittent and only with the CD32 option on (the Standard read pushes nothing). The same worry applied to the profiling builds. Their boot hangs of 2 Oct 2026 depended on the code layout and were first blamed on the new timer macros, which push a return address. They proved to be a hand-counted branch (chapter 07), but the macros were made stack-free anyway, because a push there would have been just as wrong.

**Evidence.** There is no measurement here, because an intermittent hang cannot be shown fixed by its absence. The evidence is the mechanism: the push lands on a live table entry. The project has a checking build for exactly this class of fault (`CORRCHK`, an option of the `TRACE` build). Once per line it scans the table for anything that looks like a code address and, on the first hit, freezes the instruction ring buffer with the value and its location, so a stray push names the routine that made it.

**Look up.** Commit c969a0e (and abcc1ae, which removed a second call level from the MSX2+ code); `CORRCHK`, `TRACE`; the comment blocks above `PERFSTAMPI` and `CORRCHECK`.

**Conventions that follow** (also the first lines of every agent briefing, chapter 08):
- Handlers must not use BSR, JSR or any push. Save registers in memory.
- A Z80 I/O handler receives the value in D2.B and ends with `SWAP D2`.
- D1 and A4 are scratch at handler entry.
- The source files are Latin-1; keep the encoding when editing.
- `build.sh` refuses branches written as `*+n` (chapter 07).

### D1's high word must stay zero

**Problem.** Barbarian hung in sprite mode 2 once its SCREEN 5 table sat above 64 KB: the Z80 ran into a stretch of NOPs.

**Before** (`BANDSHOT`, AmiMSX 3.1 plus early 4.0):

```
	MOVE.W	BandN,D1
	...
	MULU	#640,D1			; long result in D1
	...
	LSL.L	#7,D1			; address as a long in D1
	LEA	DIRVRAM-512,A0
	ADD.L	D1,A0
```

**After** (commit 3f21b17):

```
	MOVEQ	#0,D0			; long arithmetic in the saved D0
	MOVE.W	BandN,D0
	MULU	#640,D0
	...
	LSL.L	#7,D0
	ADD.L	D0,A0
```

*Source: AmiMSX 4.0, AmiMSX_Main_v3.1.asm (freeware by Juan Antonio Gómez Gálvez; 4.x changes; used with permission).*

**Why.** The Z80 core indexes its jump tables with `D1.L` and assumes the high word is zero after any scanline handler. The sprite snapshot computed an address of 64 KB or more in D1, left a 1 in the high word, and the next opcode fetch jumped to the wrong table entry. **Evidence:** Barbarian's mode-2 hang is gone. **Look up:** commit 3f21b17; the comment above `SNAPSPR`.

## Interrupt timing: the instruction after EI

### A pending interrupt is taken after the instruction following EI, not at the end of the line

**Problem.** Uridium 2's SCREEN 8 title picture came out as a dark red field with the bottom strip of the logo, wrapped sideways (WinUAE and PiStorm). The reference emulator drew it whole.

**Cause, in four steps** (found with an event ring buffer and a Z80 instruction ring, frozen at the first write to the wrong VRAM address):
1. The game polls VDP status register 2 until the vertical-retrace flag is up, then writes a block of VDP registers as pairs of bytes to port 99h (data, then register number), with interrupts enabled.
2. AmiMSX checked pending interrupts only at the end of an emulated line. The vertical-blank interrupt was accepted a line late, between the two bytes of a pair.
3. The interrupt handler reads status register 0, which resets the VDP's first-byte latch. Every later byte was paired wrongly, the register 14 write (VRAM address bits 14 to 16) never arrived, and the picture was streamed to VRAM address C08Eh instead of 0000h.
4. A real Z80 accepts a pending interrupt right after the instruction that follows EI, so the handler runs at the poll routine's EI/RET, before any pair starts.

**Before** (`AmiMSX_Main_v3.1.asm`, the EI handler, AmiMSX 4.1.1; the old attempt was commented out):

```
EI:
	ST	IFF(A3)
;	BTST	#4,DVDP0(A3)		; Interrupcion Horizontal?
;	...
;	CLR.W	(A3)			; * Resta Cycles *
;EIcon:
	OtraEI	4
```

**After** (commit 228226d, with the review change in cd0d46b):

```
EI:
	ST	IFF(A3)
	TST.W	PetInt38(A3)		; an interrupt already pending?
	BEQ.S	EIPlain
	TST.B	EIForce			; (EI; EI keeps the first save)
	BNE.S	EIPlain
	ST	EIForce
	MOVE.W	(A3),EISave		; the line's remaining cycles ...
	CLR.W	(A3)			; ... saved; counter zero, so the NEXT
EIPlain:				; instruction ends in MiraInter
	OtraEI	4
...
MiraInter:
	TST.B	EIForce			; forced by EI: not a line end
	BNE.S	MiraInterEI
...
MiraInterEI:
	SF	EIForce
	MOVE.W	EISave,D1
	ADD.W	D1,(A3)			; give the cycles back
	MOVEQ	#0,D1
	TST.B	PetInt38(A3)		; line interrupt first, as the
	BEQ.S	MiraInterEIV		; normal path does ...
	BTST	#4,DVDP0(A3)
	BNE	InterRun
MiraInterEIV:
	TST.B	PetInt38+1(A3)		; ... then the vertical blank
	BNE	InterRunV
	JMP	([A3,D2.W*8])		; back to the Z80 core
```

*Source: AmiMSX 4.1.2, AmiMSX_Main_v3.1.asm (freeware by Juan Antonio Gómez Gálvez; 4.x changes; used with permission).*

**Why.** The per-line cycle counter at `(A3)` is how the core knows a line has ended: the next instruction's tail checks it. Setting it to zero from EI makes the following instruction look like a line end, which sends control through the normal interrupt-acceptance code. Giving the saved cycles back means no emulated time is added or lost. `EI; DI` takes nothing (IFF is clear again) and `EI; HALT` wakes at once. A review round found that the first version checked the vertical blank before the line interrupt. A title that runs with the line interrupt enabled but the frame interrupt disabled, and never reads status register 0, keeps the vertical-blank flag up, so every EI took the forced detour and returned without looking at the pending line interrupt. The order was swapped to match the core's normal path.

**Evidence.**
- Bursts of Uridium 2 at 6, 8, 10, 12, 14, 16, 20 and 30 s, 3 consecutive frames each, against the reference emulator: the title picture is whole and identical from 6 to 14 s, and play at 16 to 30 s matches.
- Regression on 10 titles: 4 identical, 6 changed. All six changes were game-state shifts caused by the earlier interrupt acceptance (a different attract sequence in Uridium 2; scroll, sprite positions, scores or phases different in the other five), with no corruption in any capture. The baselines were re-accepted from a full run after the merge.
- After the review reorder, the 21 cropped captures were pixel-identical to the first version.
- Not explained by this: the controls page of another title that garbles for the same visible reason (a vertical-blank interrupt between two port-99 writes). There the interrupt arrives by timing alone with interrupts already on, so it needs a frame-timing study, not this fix.

**Look up.** Commits 228226d, cd0d46b; `EI`, `MiraInterEI`, `EIForce`, `EISave`; the debug switches `U2TRV` and `U2TRAP` (freeze at a write to a given VRAM address); notes `Docs/agent_notes/urid.md`.

## Flags that games depend on

Games use the Z80's quirks as tools. The three lessons below are about state that looked unimportant until a game relied on it.

### The stack pointer in ROM: POP and RET read tables

**Problem.** Godzilla Balls and Alien Attack reset in a loop after their title screens. Later, Barbarian's fighters were drawn as garbage after the first 256 bytes of a data copy.

**What the games do.** `LD SP,table` followed by `RET` is a computed jump through a table; `LD SP,source`, then a run of `POP` and `OUT (98h)`, is a fast copy to the VDP. In both cases the stack pointer points into ROM and the stack is only read.

**Before** (`AmiMSX_Main_v3.1.asm`, AmiMSX 3.1). A Z80 address becomes a host pointer by adding a per-page base. The stack pointer was built from the page's write pointer, and the write side of a ROM page is a dummy:

```
CogePagE:MACRO			; used for LD SP,nn and for the POP/RET
	MOVE.L	\1,\2		; page-crossing code
	...
	ADD.L	PagWrite(A3,D1.W*4),\2
	ENDM
```

**After** (commits cac36a3 and 1863a1f):

```
CogePagS:MACRO			; stack pointer for Z80 address \1
	...
	MOVE.L	PagRead(A3,D1.W*4),A4
	CMP.L	PagWrite(A3,D1.W*4),A4
	BEQ.S	\@W			; RAM: read pointer = write pointer
	...
	CMP.L	#NOMEM,A4
	BEQ.S	\@U			; unmapped: keep the write pointer
	...
	ADD.L	A4,\2			; ROM: the READ pointer
```

and `MPOP` and `MRET` call `CogePagS` where they crossed a 256-byte boundary and rebuilt A6 with the write pointer.

*Source: AmiMSX 3.1 and 4.0, AmiMSX_Main_v3.1.asm (freeware by Juan Antonio Gómez Gálvez; 4.x changes; used with permission).*

**Why.** The write pointer of a RAM page equals its read pointer, so the stack worked in RAM. For ROM the write pointer is a dummy (writes to ROM must be ignored), so every pop read zeros, and the `RET` went to address 0, a reset. An unmapped page keeps the write pointer, so a push can never corrupt the dummy memory. The second fix covered the page-crossing path: after 256 bytes the pointer was rebuilt from the write side again, so the pops turned into BIOS or dummy bytes. A small related fix: `MRET` kept its return address in A4, which `CogePagS` now uses, so it moved to A5.

**Evidence.** Found with a trace build (`TRACE`: every instruction entry logs PC, opcode and slot into a 4096-entry ring, and an opcode at address 0 with page 0 on the BIOS slot freezes it and writes `trace.bin`; `tools/read_trace.py` decodes it). The reference emulator, with a watch script, confirmed the games work there. Regression in WinUAE over 34 ROMs (24 linear, 10 megaROMs): all reach title, intro or play, and both games now run. Barbarian's fighters draw correctly.

**Look up.** Commits cac36a3, 1863a1f; `CogePagS`, `MPOP`, `MRET`; `tools/read_trace.py`, `tools/omsx_watch.tcl`.

### RLD and RRD on ROM

**Problem.** In Ianna, every second pixel of the hero's graphics was transparent, so the hero was drawn in stripes.

**What the game does.** It unpacks graphics with RLD and RRD, nibble rotations through `(HL)`, straight out of ROM. On a real Z80 the write to ROM is ignored, but the rotate itself reads the ROM byte.

**Before** (`IRRD`, AmiMSX 4.0 candidate):

```
IRRD:
	CogePagE D4,A4		; (HL) through the WRITE pointer
	...
	MOVE.B	(A4),D1		; reads the dummy: zero on ROM
	...
	MOVE.B	D1,(A4)
```

**After** (commit 1bab1fa):

```
IRRD:
	CogePag	D4,A4		; read through the READ pointer
	...
	MOVE.B	(A4),D1
	...
	MOVE.B	D1,RxDNew	; the new (HL), held in a variable
	...
	CogePagE D4,A4		; write through the WRITE pointer
	MOVE.B	RxDNew,(A4)
	Otra	12
```

*Source: AmiMSX 4.0, AmiMSX_Main_v3.1.asm (freeware by Juan Antonio Gómez Gálvez; 4.x changes; used with permission).*

**Why.** Read-modify-write instructions have two addresses on the host: one to read from and one to write to. For RAM they are the same. For ROM only the read pointer is meaningful. Any instruction that reads and writes the same Z80 address needs both pointers.

**Evidence.** A test ROM that replays the hero's unpack (`tools/make_ianna_test.py`) and a full regression: only Ianna changed (one capture of a disk title was marked as varying because of disk-load timing). **Look up:** commit 1bab1fa; `IRRD`, `IRLD`, `RxDNew`.

### A MOVE changes the flags you are about to save

**Problem.** After the Z80 core audit, every disk title stopped at the "Disk BASIC" banner. The DOS kernel's directory search never found a file.

**What the code does.** The search uses `CPIR` (compare and repeat). The handler must leave the Z80 carry flag unchanged and report the zero flag of the last compare. On the 68k the flags are translated: the compare sets the CCR, the handler copies it into D3 with `MOVE.W CCR,D3`, and the old carry is restored by a bit-field insert.

**Before** (`BlkCmpF`, AmiMSX 4.0 development):

```
CPIRF:	CMP.B	(A4),D7			; flags of the last compare
BlkCmpF:
	MOVE.B	D3,D1			; save the old flags (for C) ...
	MOVE.W	CCR,D3			; ... but this MOVE.B already changed the CCR
	BFINS	D1,D3{31:1}		; C unchanged
```

**After** (commit 6e508be):

```
CPIRF:	MOVE.B	D3,D1			; old flags (C) before the compare
	CMP.B	(A4),D7			; flags of the last compare
BlkCmpF:
	MOVE.W	CCR,D3
	BFINS	D1,D3{31:1}		; C unchanged
```

*Source: AmiMSX 4.0, AmiMSX_Main_v3.1.asm (freeware by Juan Antonio Gómez Gálvez; 4.x changes; used with permission).*

**Why.** On the 68k nearly every instruction, including `MOVE`, sets the CCR. The save of the old flags was written after the compare, so `MOVE.B` replaced the compare's Z with the Z of the old flags byte, and `CPIR` always saw "not found". Order matters: capture the flags immediately after the instruction that produces them, and do any bookkeeping before it. The same commit reverted a second change. The audit had charged the cycles of all repeated iterations in one block (23 per step, capped), which drove the line cycle counter far negative inside the directory search and hung the disk boot. The charge went back to a flat one.

**Evidence.** Disk titles boot again. The audit that found this class of bug compared every changed flag against the reference emulator's Z80 core and was driven by a generated self-checking test ROM (`tools/make_zex.py`, a ZEXALL-style generator whose expected results come from an independent core). **Look up:** commits 6e508be, 84bcf3c; `Docs/z80_audit.md`, `Docs/review_z80_audit.md`.

### A command that ignored the logical operation (VDP LINE)

*4.2 (after the 4.1.2 release).*

**Problem.** On the "power meter select" screen of Gradius III Legends (MSX2+), moving the selection left the old boxes drawn. After a few moves three or four boxes were on screen.

**What the game does.** MSX-BASIC's `LINE (x,y)-(x2,y2),c,B,XOR` draws a box as four VDP LINE commands with the logical operation XOR in the low nibble of R#46. To move the box, the program draws the old one again with XOR to erase it.

**Before** (`AmiMSX_Main_v3.1.asm`, the blitter line routine, any version up to 4.1.2): the line's blitter minterm was a constant, `$CA` (the dot takes the colour bit), whatever the operation. Every LINE was an IMP, so the "erase" repainted the box.

**After** (commit fec19c2, branch agents412/g3pm):

```
	MOVEQ	#$0F,D6
	AND.B	DVDPREG(A3),D6		; the logical op (R#46 low nibble)
	BCLR	#3,D6			; T-ops (8..12) test the colour:
	BEQ.S	LineOpN
	MOVE.B	DVDPCL(A3),D7
	AND.B	$22(A4),D7		; transparent colour: nothing to draw
	BEQ	V2EMAL
LineOpN:
	MOVE.B	LineMtTab(PC,D6.W),LineMint+1
...
LineMtTab:	DC.B	$CA,$8A,$EA,$6A	; IMP, AND, OR, XOR
		DC.B	$3A,$CA,$CA,$CA	; NOT; 5-7 behave as IMP
```

*Source: AmiMSX 4.2 development, AmiMSX_Main_v3.1.asm (freeware by Juan Antonio Gómez Gálvez; 4.x changes; used with permission).*

**Why.** The point and block commands already honoured the operation; LINE never had. The fix selects the blitter minterm from the operation (A is the line's dot, B the colour bit, C the existing dot in the plane). The corner dots of an XOR box are toggled twice by the four lines on a real VDP too, which the fix reproduces.

**Evidence.** The reference emulator never reached the screen in these runs (it sat black after the logo), so the reference was the game's own BASIC program, read from the disk. In WinUAE with the 68030 configuration and a key script that moves the box down every 4 s: the unfixed build accumulated boxes (rows 1 to 2, then 1 to 3, then all four), as on the tester's A1200; the fixed build shows one box moving down the rows and wrapping. Smoke tier: 15 titles identical apart from WinUAE's status-bar frame counter. No regression title uses LINE with an operation other than IMP, so nothing else was expected to change.

**Look up.** Commit fec19c2; `LineMint`, `LineMtTab`; `tests/keys/g3l_pm2.keys` (branch); notes `Docs/agent_notes/g3pm.md` (branch only). The screen is easy to miss in testing: see chapter 06, "scripted keys that skip a screen".

## Video-chip commands: draw at once, but report busy for the real time

### A command that finishes instantly moves the game's mid-screen work up the frame

**Problem.** Jailbreak (MSX2, SCREEN 5) showed a two-line strip in the HUD colours at the bottom of the playfield, in some frames only (WinUAE 68030/50 and PiStorm). The reference emulator showed no strip.

**Cause.** From a line interrupt at display line 200, the game starts three V9938 block commands (two byte copies and a logical copy) and polls status register 2 until its CE (command executing) bit clears before starting the next. Only after the last one does it restore the HUD registers and four palette colours. On the reference emulator the two copies stay busy 12.6 and 10.3 lines, so the restore lands at display line 231, in the bottom border. AmiMSX ran each command at once with the blitter and never set CE, so the three waits ended immediately and the restore landed at line 210. The last display line took the HUD palette.

**Before** (`AmiMSX_Main_v3.1.asm`, the register 46 handler, AmiMSX 4.2): the command was drawn and CE was cleared in the same handler, so a status read straight after it saw "done".

```
VDP2E:
	...
	MOVE.B	D2,DVDPREG(A3)
	BCLR	#0,DVDPS2(A3)		; execution finished
	...				; (the blit follows)
```

**After** (commit bd53ebb, switch `NOCETIME` to build without): the blit is unchanged; at the start the handler works out when a real VDP would finish (frame, line and cycles left in that line), and every status-2 read reports CE until then.

```
CEPOLL:	MACRO				; in each S#2 read handler, D1 only
	TST.B	CEPend
	BEQ.S	\@X
	MOVE.W	CmdFrN,D1		; frames since power-on (frame start)
	SUB.W	CEEndFr,D1
	BMI.S	\@B			; end in a later frame: busy
	BNE.S	\@D			; in an earlier one: done
	MOVE.W	CurLine(A3),D1
	CMP.W	CEEndL,D1
	BCS.S	\@B
	BHI.S	\@D
	MOVE.W	(A3),D1			; the end line: cycles left count down
	CMP.W	CEEndLeft,D1
	BLE.S	\@D
\@B:	BSET	#0,D2			; CE set in the value returned
	BRA.S	\@X
\@D:	SF	CEPend
\@X:
	ENDM
```

*Source: AmiMSX 4.3 (development), AmiMSX_Main_v3.1.asm (freeware by Juan Antonio GÃ³mez GÃ¡lvez; 4.x changes; used with permission).*

**Why.** Games pace their own mid-frame work on the video chip's busy flag, so "instant" is a timing change, not a speed-up. The model costs nothing per line: the end time is computed once when the command starts and only compared when a game reads the status register. The costs come from the reference emulator's per-access timing (VDP cycles, 1368 a line): 48 a byte for a fill (HMMV), 88 for a byte copy (HMMM), 64 for YMMM, 96 a dot for a logical fill, 120 for a logical copy, 112 a dot plus 32 a minor step for LINE, plus 56 to 64 a row. Inside the display window the chip gets fewer memory slots: the model multiplies by 3/2 with sprites on and 5/4 with them off. The time is walked through display and blank segments, so a long command can end frames later.

**Evidence.**
- End lines, model vs reference emulator, for Jailbreak's two copies: 216.7 vs 216.6, and 228.3 vs 228.6. A full-screen fill at power-on (256 by 212): about 961 lines vs about 982.
- Jailbreak bursts at 58, 60 and 62 s: flicker score 170 before, 0 after (reference 0).
- Side effect: 10 of 15 smoke titles shifted in time (play reached a different moment at each capture), with no corruption. With the model switched off (`NOCETIME`), all 10 matched the old baselines again, which proves the shift came from the model and nothing else. Every game that waits for the chip, including the BIOS's own clear at power-on, now waits as long as on a real MSX.

**Look up.** Commit bd53ebb; `CETime`, `CEPOLL`, `CEPend`; switch `NOCETIME`; notes `Docs/open_issues.md` (Jailbreak).

## Auditing every opcode's cycle count against a reference table

### A generated test cartridge and a trace of the line counter find cost bugs that reading the code missed

**Problem.** A user asked whether AmiMSX counts the MSX's M1 wait state. It did, but an earlier audit had only read the handlers against the reference emulator's source. Two costs were still wrong.

**Method.**
1. A generator (`tools/make_z80time.py`) reads a published Z80 timing table (the "Z80+M1" column) and writes a cartridge that runs every documented instruction once, in a straight line: each register, bit and condition, conditional jumps taken and not taken, block instructions with one repeat. Each test is preceded by a restore block, so memory operands always point into RAM, the stack stays valid, and jump targets are simply the next instruction.
2. A trace build (`-DTRACE=1 -DCYCLOG=1`) logs, at each instruction, its address and the line's remaining cycle counter. The cost of an instruction is the drop to the next entry, plus one line's worth when a line ended in between.
3. A reader (`tools/read_z80time.py`) matches entries to tests and prints every difference.

**Before** (AmiMSX 4.2): the DAA handler used its dispatch macro without a cycle count, so only the M1 wait was charged:

```
DAA:
	...
	OtraDAA				; macro: Otra \1  ->  Otra (empty) = 1 cycle
```

and the prefix tables pointed DD/FD + a plain `LD r,r'` straight at the unprefixed handler, so the prefix cost 1 cycle instead of 5:

```
INSDD:	...
	DC.L	LDBB,LDBC,LDBD,LDBE,LDBHX,LDBLX,LDBIX,LDBA	; 40
```

**After** (commit c7e8078):

```
	OtraDAA	4			; DAA is 4 T-states (+1 M1 wait)
...
	DC.L	NOCO,NOCO,NOCO,NOCO,LDBHX,LDBLX,LDBIX,NOCO	; 40
```

`NOCO` charges the prefix as a 4-cycle NOP (plus its M1 wait) and re-dispatches the opcode, as the table already did for every other plain opcode.

*Source: AmiMSX 4.3 (development), AmiMSX_Main_v3.1.asm (freeware by Juan Antonio GÃ³mez GÃ¡lvez; 4.x changes; used with permission).*

**Why.** Both bugs are invisible when you read the handler (the right macro is there) and only show up when you measure. A macro with an empty argument assembles quietly in Devpac mode.

**Evidence.** First run: 906 of 959 matched. After the two fixes: 957 of 959. The two left (CPIR/CPDR, a flat charge for the whole search) are deliberate: charging per repeat once drove the line counter far negative inside a disk BIOS directory search and hung the boot.

**Three traps in the method.**
- **Interrupts.** The table includes EI, RETN and IM 2, so a straight-line test leaves interrupts on, in IM 2 mode, partway through. The next frame interrupt jumped through a random vector into RAM, ran 15,000 bytes of zeros and came back through a stray RET. Put a DI at the start of every restore block.
- **Other slots at the same addresses.** The trace ring also holds BIOS and disk-ROM code that runs at the cartridge's addresses in other slots. Keep only the entries after the cartridge's first instruction's last appearance.
- **The table's notation.** The table writes a 16-bit operand as two tokens, `nn nn`, one per byte. Reading each `nn` as a word made every jump land two bytes too far.

**Look up.** Commits a090efa, c7e8078, ec66147; `tools/make_z80time.py`, `tools/read_z80time.py`, switch `CYCLOG`; `Docs/z80_audit.md`.

## I/O at the right cycle within an instruction

*Reading notes (Arnold).* The Z80 core in Arnold runs one whole instruction at a time and then catches the video chip up by the instruction's length in "NOPs" (one NOP is 1 microsecond, four T-states). That is exact only if nothing outside the CPU can see the middle of an instruction. Some things can.

### Pinball Dreams: the CRTC saw each OUT at the start of its instruction

**Problem.** Pinball Dreams on the Plus and on a plain 6128: from the first table on, most frames were black or partial, the picture rolled, and two frames were multicoloured noise. The reference emulator showed a steady full table in every frame from the same key script. After the ball launch the game died (black screen from about frame 6600).

**What the game does** (from a trace of CRTC writes). It rewrites R0, R4, R5, R6, R7, R9, R12 and R13 several times a frame: one-line rows, short lines (R0 = 6 or 4) for the fine vertical position, and R5 and R7 to keep the frame at 312 lines. Arnold's vertical counter at the same monitor line drifted by 2 rows a frame, because the CRTC frame was no longer 312 lines. Every Arnold write landed 2 to 4 characters before the reference emulator's. The critical one: R0 = 6 is written at horizontal count 41 in Arnold, before the end of the R0 = &2A line (count 42), so the count runs on to 255, one long line of about 4 lines' length instead of 3 short ones. The reference writes it at count 1 of the next line, as the game intends.

**Before** (`arnold.c`, Arnold-m68k 0.8): after each whole Z80 instruction, `CRTC_DoCycles(NopCount)`. Every `OUT` and `IN` therefore reached the hardware at the start of its instruction. On a real CPC the I/O cycle comes late in the instruction: `OUT (C),r` does its I/O after 3 of its 4 NOPs, `IN r,(C)` after all 4, `OUT (n),A` and `IN A,(n)` after 2 of 3, `OUTI`, `OUTD`, `INI` and `IND` after 5 (per the reference emulator's delay table).

**After** (`arnold.c`, `z80.h`, `cpc.c`, commit 83d4db2, switch `NO_IOTIME_FIX`): before every `Z80_DoOut` and `Z80_DoIn` the core says how many NOPs of the instruction come first (`Z80_IO_AT(n)`), the CRTC is run to that point, and the main loop then runs only the rest:

    int CPC_IOPre, CPC_IOAhead;
    void CPC_IOCatchUp(void)
    {
        int k = CPC_IOPre - CPC_IOAhead;
        if (k > NopCountToDate - CPC_IOAhead) k = NopCountToDate - CPC_IOAhead;  /* never past the frame end */
        CPC_IOPre = 0;
        if (k > 0) { CRTC_DoCycles(k); CPC_IOAhead += k; }
    }
    #define IO_AHEAD_TAKE(n) do { (n) -= CPC_IOAhead; CPC_IOAhead = 0; } while (0)

*Source: Arnold-m68k 1.0, `arnold/src/cpc/arnold.c` (GPL-2.0, derived from Kevin Thacker's Arnold).*

**Scope.** The first version timed every I/O instruction and changed 43 of 150 homebrew test frames. Timing only writes to the CRTC (`&BDxx`) is the default (`IOTIME_ALL` times everything, and stays opt-in): Sonic GX is then identical, Ghouls'n Ghosts GX differs on 5 of 1826 frames by a few sprite pixels, Puzzle Bobble on 52 of 1026 (a band edge at the boot transition, the logo's slide-in). The homebrew check still showed 105 same, 45 different, for a reason worth knowing: the cartridge boot programs the CRTC from R0 = 0, where the horizontal count restarts every cycle, so the moment of the first R0 write, now 3 microseconds later, sets a different CPU-versus-CRTC phase for the whole run. Any correct I/O timing does this, so "different" must be judged against the reference emulator, not against the old build.

**Evidence.** A table played in the fixed build (a ball launch, scroll to the top, scores, balls 2 and 3) matches the reference, on the Plus and on the 6128; steady full table in every snapshot from frame 5600 to 9000. With `NO_IOTIME_FIX` the picture breaks at the launch and the game dies. In WinUAE the fixed build plays to 126,426 points by frame 11,000.

**Look up.** Commits 83d4db2, 20352e2; `PINBALL.md`; switches `NO_IOTIME_FIX`, `IOTIME_ALL`.

## Carrying I/O-ahead cycles into the next instruction; Plus DMA phase

### Plus ASIC registers are written by a memory write, not by OUT

**Problem.** The same early-write fault existed for the Plus: the ASIC's registers (palette, sprite, split and scroll registers) sit at `&6000` to `&7FFF` when mapped in, and sprite pixels at `&4000`. Sonic GX's code ran about 10 characters late relative to the beam (CRTC writes +10, ASIC writes +5/+6 against the reference emulator in a write-by-write trace).

**After** (`cpc.c`, `z80.c`, commit 26729bf, switch `NO_ASICTIME`): a write to the ASIC page runs the CRTC up to the NOP in which the write happens, as an `OUT` does:

    #define ASICTIME_ADDR(a) (((a) & 0xe000) == 0x6000 || ((a) & 0xf000) == 0x4000)
    ...
    if (ASICTIME_ADDR(Addr)) { CPC_IOPre = Z80_WriteNop(Addr); CPC_IOCatchUp(); }

`Z80_WriteNop` decodes the instruction at the program counter and gives the NOP of its write (`LD (HL),r` 2, `LD (nn),A` 4, `PUSH` 3 or 4, `(IX+d)` forms 5 or 6, `LDIR` 4, and so on; 0 for pushes made by `CALL`, `RST` and interrupts, which the reference does not time either). `PUSH` also writes the high byte first, as a Z80 does.

*Source: Arnold-m68k 1.0, `arnold/src/cpc/cpc.c` (GPL-2.0, derived from Kevin Thacker's Arnold).*

**Evidence.** A write-by-write comparison with the reference (a patched build prints every ASIC and CRTC write with its raster position), then a histogram of "Arnold position minus reference position" in characters. The only cost is on writes to the ASIC page while it is mapped in.

### The DMA ran at the end of HSYNC; the real ASIC runs it just after the start

**Problem.** After the write-timing fix all Sonic GX writes were +10 characters from the reference. Arnold ran the Plus DMA at the end of the horizontal sync (12 to 14 characters after its start with the usual sync); the real ASIC runs it 2 to 3 microseconds after the start. Code driven by DMA interrupts (Sonic's split, scroll and palette writes) therefore ran late against the beam.

**After** (`asic.c`, commits 7562c68 and 1991458, switch `NO_DMAPHASE`):

    /* at HSYNC start: run the channels now, raise their interrupt DMAPHASE_DELAY cycles later */
    if (ASIC_Data.InternalDCSR & 0x07) {
        ASIC_DMA_RunChannels(ASIC_Data.InternalDCSR & 0x07, DMAPHASE_DELAY);   /* 2 cycles */
        ASIC_TriggerInterrupt();
    }
    /* a DCSR write that enables a channel within those cycles runs it at once */

*Source: Arnold-m68k 1.0, `arnold/src/cpc/asic.c` (GPL-2.0, derived from Kevin Thacker's Arnold).*

**Two traps found on the way.** (1) The first version scheduled the DMA only if a channel was enabled at the start of HSYNC; Sonic's special stage enables its channel one character later and the stage froze and garbled. Always schedule, and check DCSR when the DMA runs. (2) An extra CRTC event at the DMA cycle was the obvious design and cost 1.05 ms a frame on the PiStorm (12.59 to 13.64 ms core); running the channels at the HSYNC-start event and raising the interrupt later through a countdown gave the same trace results for 12.81 to 12.87 ms (the write timing alone costs nothing: 12.54).

**Evidence** (write position histogram, characters; Sonic title): CRTC +10 and ASIC +5/+6 before; +0 for 1060 of 1252 writes after (the rest is per-row interrupt jitter that differs in both emulators). Pixels against the reference over a window of frames: 591,751 pixels and 5909 rows different before, 591,695 and 5894 after, i.e. nothing worse. Pinball Dreams, which only writes the CRTC, was unchanged at 0 and +1.

**Look up.** Commits 26729bf, 7562c68, 1991458; `ASICTIME.md`; switches `NO_ASICTIME`, `NO_ASICTIME_SPR`, `NO_DMAPHASE`.

### A cycle of lead must be carried into the next instruction, never made negative

**Problem.** Merged with the speed work, the build showed palette-split rows one cell off on Sonic GX, 358 of 2300 frames from frame 835, 1988 of 4400 in the second script, 148 of 1826 in Ghouls'n Ghosts GX.

**Cause.** `LD (HL),n` takes 2 NOPs in Arnold, but the write is timed at NOP 3, so `CPC_IOCatchUp` ran the CRTC one cycle past the end of the instruction and the main loop was left with a count of -1 (70 times in Sonic, 106,616 in Bomb Jack GX, 10,150 in Ghouls'n Ghosts GX, over 3000 frames; `LD (HL),n` is the only opcode seen). The old generic cell loop drew nothing for a negative count but moved the monitor counters back while the horizontal count stayed ahead. The new fast cell paths moved the position back a whole cell.

**After** (`arnold.c`, commit 536860d, switch `NO_IOAHEAD_DEBT`):

    #define IO_AHEAD_TAKE(n) do { (n) -= CPC_IOAhead; CPC_IOAhead = 0; \
        if (__builtin_expect((n) < 0, 0)) { CPC_IOAhead = -(n); (n) = 0; } } while (0)

and the fast cell paths take only positive counts.

*Source: Arnold-m68k 1.0, `arnold/src/cpc/arnold.c` (GPL-2.0, derived from Kevin Thacker's Arnold).*

**How it was found.** Per-frame checksums of the merged build against the build before the merge. Switching off one change at a time showed that `-DNO_EMUBR` (the speed change) made the frames identical, which pointed at its cell paths, not at the timing change itself; then the negative count. This is why every change in Arnold has a `NO_x` switch (chapter 06).

**Evidence.** The merge alone was exact against the 150-program homebrew check (150 same). The debt fix changes game timing slightly, never the picture: 8 programs of 150 differ (the ones with many `LD (HL),n` writes to the ASIC page), Sonic's Act 2 title comes about 20 frames later, and nothing glitches in the snapshots.

**Look up.** Commit 536860d; `Docs/agent_notes/release-0.9.md`; switch `NO_IOAHEAD_DEBT`.

## Tapes and disks (Arnold)

*Reading notes.* The CPC loads games from cassette tape (.cdt files, the TZX format) or from 3-inch and 3.5-inch disks (.dsk). The emulation of both belongs to the core, but each needed something the Amiga host must supply.

### A tape pause was 12.5% too short, and loading took a minute and a half of real time

**Problem.** The core's tape player was complete but nothing in the Amiga host called it. Once wired, tapes had to load correctly, and a 90-second load had to be skippable without changing the result.

**Before** (`tzxold.c`, Arnold-m68k 0.9): `TapeImage_MillisecondsToTStates` converted pauses with 3500 T-states a millisecond (a Spectrum clock) while pulse lengths were scaled to the CPC's 4 MHz, so every pause between blocks was 12.5% short.

**After** (`tzxold.c`, commit ac9a7ef, switch `NO_TAPE_FIX`):

    /* pulse lengths are in CPC T-states (4 MHz), so pauses must be too */
    return (4000*Milliseconds);

*Source: Arnold-m68k 1.0, `arnold/src/cpc/tzxold.c` (GPL-2.0, derived from Kevin Thacker's Arnold).*

**Fast tape** (`host_amiga.c`, commit fdaa2dd, option `FASTTAPE`, on by default): while the motor is on and the tape is playable, the host does not wait for the 50 Hz frame, mutes and drops the sound blocks, and draws only 1 frame in 25. The emulation is untouched, so it runs exactly the same instructions as real-speed loading.

    static int tape_fast_active(void)
    {   return menu.fasttape && tape_in[0] && CPC_GetTapeMotor() && TapeImage_IsPlayable(); }
    ...
    if (fast) { behind_us = 0; tape_fast_frames++; return; }   /* fast tape: no 50 Hz wait */

*Source: Arnold-m68k 1.0, `arnold/src/amiga/host_amiga.c` (GPL-2.0, derived from Kevin Thacker's Arnold).*

**Evidence.** 36 of 36 test tapes load to the end on a 464 (the last motor stop at the last block); for all 36, real-speed and fast loading give the same frame checksum **and** the same MD5 of the 64 KB of RAM 150 frames after the last motor stop. Timing: the data of one tape ends 85.92 s in by the file's own timings, the emulated motor ran 86.12 s (frames 203 to 4509); fast loading took 10 to 12 s. A tape with a custom loader (ROM-loaded loader, then standard-speed blocks read by the game's own code) loads and matches the reference. Same results with a 6128 (`|TAPE`) and on the Plus with its system cartridge.

**Look up.** Commits ac9a7ef, fdaa2dd; `TAPE.md`; switches `NO_TAPE_FIX`, `FASTTAPE=0`. A profile-guided build keys its data on function order: the new accessor `CPC_GetTapeMotor` was put at the end of `cpc.c` so no profile was lost (chapter 10).

### A disk image with 80 tracks, a drive with 43

**Problem.** Pinball Dreams' tables Beat Box and Nightmare stayed on "LOADING" for ever; Ignition and Steel Wheel loaded. It had never worked, in any Arnold version, on the Plus or on the 6128; the reference emulator loads Beat Box.

**Cause.** The disk image is an 80-track single-sided 3.5-inch image. Arnold's drive A is a 43-track 3-inch drive, so the head stopped at track 42 and the later tables were never found.

**After** (`fdd.c`, commit 5dd7adf, switch `NO_DSK80`): an image with more tracks than the drive gets an 80-track drive; an image that fits keeps the drive's own count:

    static const unsigned long FDD_BaseTracks[2] = { 43, 80 };
    ...
    if (DiskTracks > (int)n) n = DiskTracks < 80 ? 80 : (DiskTracks > 86 ? 86 : DiskTracks);
    theDrive->NumberOfTracks = n;

*Source: Arnold-m68k 1.0, `arnold/src/cpc/fdd.c` (GPL-2.0, derived from Kevin Thacker's Arnold).*

**Evidence.** All four tables load and play; the snapshots of the two tables that loaded before are identical. (This is a good example of a non-regression: it failed in four versions, so only a reference emulator could show it should work.)

### Writing a disk back: changed sectors only, a spare copy once, and a rename that works on AmigaOS

**Problem.** Games save high scores and levels to disk, and the emulator should write those changes to the .dsk file without damaging the image.

**After** (`dskwrite.c`, commit 86888ee; host: commit 805df0f; option `DISKWRITE`, "Write disks back"):

1. The new image is built from the original file as a template: tracks whose sector IDs are unchanged are copied byte for byte and only changed sectors (data, or the two status bytes) are patched in. Weak sectors are kept, and a rewritten weak sector gets the new data in every copy. Formatted or new tracks are built from the core's data; a standard image stays standard unless a formatted track cannot fit, then it becomes extended.
2. The file side writes `<name>.tmp`, reads it back to check its length, renames the original away (the first time to `<name>.bak`, which is never replaced afterwards, later to `.old`), renames the temp over the name and removes `.old`:

        if (!file_exists(bak)) { if (rename(name, bak) != 0) {...} moved = bak; *made_bak = 1; }
        else { remove(old); if (rename(name, old) != 0) {...} moved = old; }
        if (rename(tmp, name) != 0) { rename(moved, name); ... "original kept" }
        if (moved == old) remove(old);

   *Source: Arnold-m68k 1.0, `arnold/src/cpc/diskimage/dskwrite.c` (GPL-2.0, derived from Kevin Thacker's Arnold).*
3. `Host_FileWritable` refuses to touch a file that is protected: it looks at the file's protection bits and asks the filesystem if the volume is write-protected, and the failure goes to the log and the menu status, with no retry.

**Why the odd order.** On AmigaOS `rename()` does not replace an existing file, so the original has to be moved away first, and if the last rename fails the original must come back. When anything goes wrong the user keeps either the old file or the new one, never half of one.

**Evidence.** Headless 33 of 33 tests: save to a standard and to an extended image, reload and save again, `.bak` made once, byte compare with the reference emulator (identical except 126 bytes of uninitialised RAM), `FORMAT` of all 40 tracks of drive B by patching and by changing the layout, a high-score write beside a weak sector (only those bytes change), a write-protected file untouched, no change means no write. WinUAE on the PiStorm configuration 7 of 7 (standard, resave through the temp, old and rename path, extended, read-only).

**Look up.** Commits 86888ee, 805df0f, cbb5e01; `DSKWRITE.md`; switches `NO_DSK80`, `DISKWRITE=0`.
