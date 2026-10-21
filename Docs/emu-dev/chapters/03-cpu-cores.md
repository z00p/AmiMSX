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

## I/O at the right cycle within an instruction

*To be written (Arnold).*

## Carrying I/O-ahead cycles into the next instruction; Plus DMA phase

*To be written (Arnold).*
