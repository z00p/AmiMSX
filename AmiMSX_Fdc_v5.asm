;	 --------------------------------------------
;	- WD2793 floppy disk controller (5.6) -
;	 --------------------------------------------
;
; The Philips/Sony-style disk interface at register level (openMSX's
; PhilipsFDC + WD2793, used as the behaviour reference), on top of the
; virtual disks drives A and B already hold (DIRVD0/DIRVD1). The disk ROM's
; patched BIOS calls (DSKIO and friends) stay as they are; this is for
; software that drives the controller itself (SymbOS, own loaders).
;
; Registers, in the disk ROM's slot (slot 2), page 1:
;   7FF8 status (read) / command (write)   7FF9 track   7FFA sector
;   7FFB data (a read takes the byte and clears DRQ)
;   7FFC side latch (bit 0)   7FFD drive latch (bits 0-1: 00/10 A, 01 B,
;   11 none; bit 7 motor; read: bit 2 = 0 once after a disk change)
;   7FFF read: bit 7 = !DRQ, bit 6 = !INTRQ, the rest 1.
;
; While slot 2 shows in page 1 (and only then) FDCHOOK (end of OUTA8) swaps
; handlers in INSTR (FdcHkTab). Reads: AmiMSX reads memory directly, so
; LD A,(nn), LD A,(BC), LD A,(DE) and LD r,(HL) get hooked twins that look at
; 7FF8h-7FFFh and run the plain handler otherwise; other read instructions
; see the disk ROM's bytes there. Writes: the plain write handlers (MapNorm)
; never call the slot routines, so LD (nn),A, LD (HL),r, LD (BC),A, LD (DE),A
; and LD (HL),n become MapExp's (charge, then PagRuts), and FdcSetup puts
; FdcWr on slot 2's 6000h-7FFFh entry ($68C(A3)). The disk ROM's own INIT
; drives the registers (force interrupt, steps, restore), so the controller
; answers from power on. Handlers leave D1's high word 0 (MRET does
; MOVE.L D1,A5).
;
; No BSR inside the Z80 core (A7 points into the Restas table): the hooks
; save the registers and switch to FdcStk before calling in here.
;
; Time: counter units (Z80 cycles x ZCYC) from FdcClk (a frame's cycles
; added at each frame start, MiraInter0) plus the cycles into the frame,
; as the turbo R E6h timer counts them. A disk turns 5 times a second,
; 6250 bytes a turn (double density, 32 us a byte: 229/2 Z80 cycles).
; Sector k's ID (its C byte) passes at byte 162 + 658 k of the turn (the
; standard 9-sector layout), its data 44 bytes later.
;
; Not modelled: read track (ends after a turn with no data), verify on
; seek, CRC errors, head/side compare beyond the C flag. Track positions
; follow the image's boot sector (sectors per track, sides); 40-track
; disks need the double step the software asks for.

	IFD	TRACE			; (debug) the trace stubs' real handlers
FDCIT	EQU	TraceTab
	ELSEIF
FDCIT	EQU	INSTR
	ENDC
FDCB2	EQU	229*ZCYC		; two byte times (units)
FDCROT	EQU	(6250*229*ZCYC)/2	; a turn, 200 ms
FDCMS	EQU	3580*ZCYC		; 1 ms
FDCIDX	EQU	125			; index pulse, bytes (4 ms)
FDCSEC0	EQU	162			; sector 1's ID (C byte), bytes
FDCSECL	EQU	658			; bytes a sector takes on the track
FDCMAXS	EQU	1440			; 720 KB of 512-byte sectors

; Status bits
FDS_BUSY	EQU	$01
FDS_DRQ		EQU	$02		; type II/III; type I: index
FDS_LOST	EQU	$04		; type II/III; type I: track 0
FDS_CRC		EQU	$08
FDS_RNF		EQU	$10		; type I: seek error
FDS_RTYPE	EQU	$20		; type I: head loaded
FDS_WP		EQU	$40
FDS_NRDY	EQU	$80

; FDCRD: a hooked read of address D1.W (7FF8h-7FFFh); the byte in D1.
FDCRD	MACRO
	MOVEM.L	D0/D2-D7/A0-A2/A4-A6,FdcRegs
	MOVE.L	A7,FdcSP
	LEA	FdcStkE,A7
	IFD	FDCLOG
	MOVE.W	D1,FdcLgA
	ENDC
	BSR	FdcRead
	IFD	FDCLOG
	MOVE.B	FdcLgA+1,D1
	AND.B	#7,D1
	IFD	FDCLOGS
	CMP.B	#3,D1			; (data reads: only a count and a sum)
	BNE.S	\@n
	ADDQ.W	#1,FdcLgS
	ADD.B	D0,FdcLgS+3
	MOVE.B	FdcLgS+3,D1
	ROL.B	#1,D1
	MOVE.B	D1,FdcLgS+3
	BRA.S	\@s
\@n:
	ENDC
	BSR	FdcLgW
\@s:
	ENDC
	MOVE.L	FdcSP,A7
	MOVE.B	D0,FdcRes
	MOVEM.L	FdcRegs,D0/D2-D7/A0-A2/A4-A6
	MOVEQ	#0,D1			; (the core wants D1's high word 0:
	MOVE.B	FdcRes,D1		; MRET does MOVE.L D1,A5)
	ENDM

; FHKRR addr, dest, H/L, plain handler: LD r,(rr) hooked.
FHKRR	MACRO
	MOVE.W	\1,D1
	AND.W	#$FFF8,D1
	CMP.W	#$7FF8,D1
	BEQ.S	\@y
	JMP	\4
\@y:	MOVE.W	\1,D1
	FDCRD
	IFC	"H","\3"
	ROR.W	#8,\2
	MOVE.B	D1,\2
	ROR.W	#8,\2
	ELSEIF
	MOVE.B	D1,\2
	ENDC
	Otra	7,4			; (R800: 3 + 1, r800time.tsv)
	ENDM

	CNOP	0,4
FHkLDAM:
	CMP.B	#$7F,1(A5)		; LD A,(nn): nn = 7FF8h-7FFFh?
	BNE.S	FHkLDAMn
	CMP.B	#$F8,(A5)
	BCC.S	FHkLDAMy
FHkLDAMn:
	JMP	LDAM
FHkLDAMy:
	MOVEQ	#0,D1
	MOVE.B	(A5),D1
	OR.W	#$7F00,D1
	ADDQ.L	#2,A5
	FDCRD
	MOVE.B	D1,D7
	Otra	13,6			; (R800: 5 + 1)

FHkLDABC:	FHKRR	D5,D7,L,LDABC
FHkLDADE:	FHKRR	D6,D7,L,LDADE
FHkLDBHL:	FHKRR	D4,D5,H,LDBHL
FHkLDCHL:	FHKRR	D4,D5,L,LDCHL
FHkLDDHL:	FHKRR	D4,D6,H,LDDHL
FHkLDEHL:	FHKRR	D4,D6,L,LDEHL
FHkLDHHL:	FHKRR	D4,D4,H,LDHHL
FHkLDLHL:	FHKRR	D4,D4,L,LDLHL
FHkLDAHL:	FHKRR	D4,D7,L,LDAHL

; INSTR offsets, plain and hooked handlers (FDCHOOK). The reads first (bit
; field offsets 0-9 of FdcHkM), then the writes (10-20): on an MSX2/2+ with no
; mapper cartridge the plain writes (MapNorm) never call the slot routines, so
; while the controller shows they become MapExp's (the FM-PAC's: they charge
; the cycles, then PagRuts). Only plain entries are swapped, and only swapped
; ones are put back (FdcHkM), so MapMapp/MapExp set elsewhere stay.
	CNOP	0,4
FdcHkTab:
	IFND	FDCWRONLY
	DC.W	$3A*8
	DC.L	LDAM,FHkLDAM
	DC.W	$0A*8
	DC.L	LDABC,FHkLDABC
	DC.W	$1A*8
	DC.L	LDADE,FHkLDADE
	DC.W	$46*8
	DC.L	LDBHL,FHkLDBHL
	DC.W	$4E*8
	DC.L	LDCHL,FHkLDCHL
	DC.W	$56*8
	DC.L	LDDHL,FHkLDDHL
	DC.W	$5E*8
	DC.L	LDEHL,FHkLDEHL
	DC.W	$66*8
	DC.L	LDHHL,FHkLDHHL
	DC.W	$6E*8
	DC.L	LDLHL,FHkLDLHL
	DC.W	$7E*8
	DC.L	LDAHL,FHkLDAHL
	ENDC
	IFND	FDCRDONLY
	DC.W	$32*8
	DC.L	LDMA,T8LDMA
	DC.W	$77*8
	DC.L	LDHLA,T8LDHLA
	DC.W	$70*8
	DC.L	LDHLB,T8LDHLB
	DC.W	$71*8
	DC.L	LDHLC,T8LDHLC
	DC.W	$72*8
	DC.L	LDHLD,T8LDHLD
	DC.W	$73*8
	DC.L	LDHLE,T8LDHLE
	DC.W	$74*8
	DC.L	LDHLH,T8LDHLH
	DC.W	$75*8
	DC.L	LDHLL,T8LDHLL
	DC.W	$02*8
	DC.L	LDBCA,T8LDBCA
	DC.W	$12*8
	DC.L	LDDEA,T8LDDEA
	DC.W	$36*8
	DC.L	LDHLMN,T8LDHLMN
	ENDC
	DC.W	-1

; PagRuts entry for 6000h-7FFFh of slot 2 (a hooked write: A4 = the byte
; written, already stored in the ROM page's NORAM dummy).
	CNOP	0,4
FdcWr:
	IFD	FDCNOWR
	BRA	FdcWrX
	ENDC
	MOVE.L	A4,D1
	SUB.L	PagWrite+12(A3),D1
	CMP.W	#$7FF8,D1
	BCS.S	FdcWrX
	MOVEM.L	D0/D2-D7/A0-A2/A4-A6,FdcRegs
	MOVE.L	A7,FdcSP
	LEA	FdcStkE,A7
	MOVE.B	(A4),D0
	AND.W	#7,D1
	IFD	FDCLOG
	MOVE.W	D1,FdcLgA
	MOVE.B	D0,FdcLgV
	ENDC
	BSR	FdcWrite
	IFD	FDCLOG
	MOVE.B	FdcLgA+1,D1
	OR.B	#$80,D1
	MOVE.B	FdcLgV,D0
	BSR	FdcLgW
	MOVE.L	FdcLgP,A0		; (writes: the last long = Z80 A,
	MOVE.B	FdcRegs+27,-4(A0)	; the byte at A4 now, A4's low word)
	MOVE.L	FdcRegs+(10*4),A1
	MOVE.B	(A1),-3(A0)
	MOVE.W	A1,-2(A0)
	ENDC
	MOVE.L	FdcSP,A7
	MOVEM.L	FdcRegs,D0/D2-D7/A0-A2/A4-A6
FdcWrX:	MOVEQ	#0,D1			; (D1's high word 0 for the core)
	Otra2

; FdcA8: from FDCHOOK at the end of OUTA8 (core context: no stack). The hooks
; go into INSTR when wanted (the controller on and slot 2 in page 1) and come
; out otherwise (FdcHkTab). Keeps D0-D2 and A4: OUTA8's callers use D1
; (the stack's segment) after it returns.
FdcA8:
	IFD	FDCDBG
	ADDQ.B	#1,FdcDbgC
	MOVE.B	DA8(A3),FdcDbgA8
	ENDC
	IFD	FDCOLDA8
	MOVEQ	#0,D1
	TST.B	FdcOn
	BEQ.S	FdcO8W
	MOVE.B	DA8(A3),D1
	AND.B	#$0C,D1
	CMP.B	#$08,D1
	SEQ	D1
FdcO8W:
	IFD	FDCDBG
	MOVE.B	D1,FdcDbgD
	ENDC
	CMP.B	FdcHook,D1
	BEQ.S	FdcO8X
	MOVE.B	D1,FdcHook
	MOVE.L	D0,FdcHkD0
	LEA	FdcHkTab,A4
FdcO8L:	MOVE.W	(A4)+,D0
	BMI.S	FdcO8E
	TST.B	D1
	BEQ.S	FdcO8O
	MOVE.L	4(A4),(INSTR,D0.W)
	MOVE.L	4(A4),(INSTR+4,D0.W)
	BRA.S	FdcO8N
FdcO8O:	MOVE.L	(A4),(INSTR,D0.W)
	MOVE.L	(A4),(INSTR+4,D0.W)
FdcO8N:	ADDQ.L	#8,A4
	BRA.S	FdcO8L
FdcO8E:	MOVE.L	FdcHkD0,D0
FdcO8X:	JMP	FdcA8R
	ENDC
	MOVEM.L	D0-D2/A4,FdcHkD0
	MOVEQ	#0,D1
	TST.B	FdcOn
	BEQ.S	FdcA8W
	MOVE.B	DA8(A3),D1
	AND.B	#$0C,D1
	CMP.B	#$08,D1
	SEQ	D1
	IFD	FDCSTATIC
	ST	D1			; (experiment) hooks in all the time
	ENDC
FdcA8W:
	IFD	FDCDBG
	MOVE.B	D1,FdcDbgD
	ENDC
	CMP.B	FdcHook,D1
	BEQ.S	FdcA8X
	MOVE.B	D1,FdcHook
	IFD	FDCDBG
	ADDQ.B	#1,FdcDbgP
	ENDC
	LEA	FdcHkTab,A4
	MOVEQ	#0,D2			; entry (FdcHkM bit field offset)
FdcA8L:	MOVE.W	(A4)+,D0
	BMI.S	FdcA8E
	MOVE.L	(FDCIT+4,D0.W),D1
	TST.B	FdcHook
	BEQ.S	FdcA8O
	CMP.L	(A4),D1			; hook: only over the plain handler
	BNE.S	FdcA8N
	BFSET	FdcHkM{D2:1}
	MOVE.L	4(A4),D1
	BRA.S	FdcA8S
FdcA8O:	BFTST	FdcHkM{D2:1}		; unhook: only what went in here
	BEQ.S	FdcA8N
	BFCLR	FdcHkM{D2:1}
	MOVE.L	(A4),D1
FdcA8S:	MOVE.L	D1,(FDCIT,D0.W)
	MOVE.L	D1,(FDCIT+4,D0.W)
FdcA8N:	ADDQ.L	#8,A4
	ADDQ.W	#1,D2
	BRA.S	FdcA8L
FdcA8E:
FdcA8X:	MOVEM.L	FdcHkD0,D0-D2/A4
	JMP	FdcA8R

	IFD	FDCDBG
FdcDbgIn:
	MOVEQ	#0,D1
	MOVE.B	FdcDbgI,D1
	ADDQ.B	#1,FdcDbgI
	AND.W	#7,D1
	MOVE.B	([FdcDbgA,D1.W*4]),D1
	RTS
	CNOP	0,4
FdcDbgA:	DC.L	FdcOn,FdcHook,FdcHkM,FdcHkM+1,FdcDbgD,FdcDbgA8,FdcDbgC,FdcDbgP
FdcDbgD:	DC.B	0
FdcDbgA8:	DC.B	0
FdcDbgI:	DC.B	0
FdcDbgC:	DC.B	0
FdcDbgP:	DC.B	0
	EVEN
	ENDC

	IFD	FDCLOG
; (debug) The register accesses, 16 bytes each: Z80 PC.W, op (bit 7 write,
; bits 0-2 the register), value, FdcSt, FdcPh, repeats.W, FdcT.L, FdcEndAt.L.
; A repeat of the last entry (same PC, op, value, status) only counts. Fills
; once, then stops; FdcLogDump (menu) writes AmiMSX:fdclog.bin. Normal stack;
; D1 = op, D0 = value; keeps D0.
FdcLgW:
	MOVE.L	FdcLgP,A0
	MOVE.L	FdcSP,A1
	MOVE.W	A5,D2
	SUB.W	(A1),D2			; Z80 PC (as TraceStub)
	CMP.L	#FdcLgBuf,A0
	BEQ.S	FdcLgNw
	CMP.W	-16(A0),D2
	BNE.S	FdcLgNw
	CMP.B	-14(A0),D1
	BNE.S	FdcLgNw
	CMP.B	-13(A0),D0
	BNE.S	FdcLgNw
	MOVE.B	FdcSt,D3
	CMP.B	-12(A0),D3
	BNE.S	FdcLgNw
	ADDQ.W	#1,-10(A0)
	BCC.S	FdcLgT
	SUBQ.W	#1,-10(A0)		; (stays at FFFFh)
FdcLgT:	MOVE.L	FdcT,-8(A0)
	RTS
FdcLgNw:
	CMP.L	#FdcLgEnd,A0
	BCC.S	FdcLgX
	MOVE.W	D2,(A0)+
	MOVE.B	D1,(A0)+
	MOVE.B	D0,(A0)+
	MOVE.B	FdcSt,(A0)+
	MOVE.B	FdcPh,(A0)+
	CLR.W	(A0)+
	MOVE.L	FdcT,(A0)+
	IFD	FDCLOGS
	MOVE.L	FdcLgS,(A0)+		; (data reads since: count.W, 0, sum.B)
	CLR.L	FdcLgS
	ELSEIF
	IFD	FDCLOGB
	MOVE.W	FdcRegs+2,(A0)+		; (D0.W: the Z80 SP's low byte, and
	MOVE.L	FdcRegs+48,A1		; the word at A6: the return address)
	MOVE.W	(A1),(A0)+
	ELSEIF
	MOVE.L	FdcEndAt,(A0)+
	ENDC
	ENDC
	MOVE.L	A0,FdcLgP
FdcLgX:	RTS
FdcLogDump:
	MOVEM.L	D0-D7/A0-A6,-(SP)
	MOVE.L	#FdcLgName,D1
	MOVE.L	#$3EE,D2
	JSR	OPENFILE
	TST.L	D0
	BEQ.S	FdcLgDX
	MOVE.L	#FdcLgBuf,D2
	MOVE.L	FdcLgP,D3
	SUB.L	D2,D3
	JSR	WRITEFILE
	JSR	CLOSEFILE
FdcLgDX:
	MOVEM.L	(SP)+,D0-D7/A0-A6
	RTS
FdcLgName:	DC.B	"AmiMSX:fdclog.bin",0
	CNOP	0,4
FdcLgP:		DC.L	FdcLgBuf
FdcLgA:		DC.W	0
FdcLgV:		DC.B	0
	EVEN
FdcLgS:		DC.L	0
	EVEN
	SECTION	FDCLG,BSS
FdcLgBuf:	DS.B	16*8192
FdcLgEnd:
	SECTION	MSX2,CODE
	CNOP	0,4
	ENDC

; Called from CONTINUAR (normal stack) after the slots are set: the
; controller is on when the disk ROM is in slot 2 (not the turbo R).
FdcSetup:
	SF	FdcOn
	CMP.B	#2,DIRPREFS+$65		; Disk ROM = None?
	BEQ.S	FdcSetX
	IFD	TURBOR
	TST.B	TRMach
	BNE.S	FdcSetX
	ENDC
	MOVE.L	SLOT2+8,D0
	CMP.L	ActDosROM,D0
	BNE.S	FdcSetX
	ST	FdcOn
	MOVE.L	#FdcWr,REGS+$68C
	CMP.L	#Bucle,DirConti+2	; power on: the controller resets
	BNE.S	FdcSetX
	BSR	FdcReset
FdcSetX:
	IFD	FDCDBG
	MOVE.L	#FdcDbgIn,INS+($2E*4)
	ENDC
	AND.L	#$FFC00000,FdcHkM	; the writes were set afresh (ConMapper)
	MOVE.B	#1,FdcHook		; neither state: FDCHOOK sets the table again
	RTS

FdcReset:
	SF	FdcPh
	SF	FdcIrq
	SF	FdcHld
	SF	FdcWr8
	CLR.B	FdcSt
	MOVE.B	#3,FdcCmd
	CLR.B	FdcTrk
	MOVE.B	#1,FdcSec
	CLR.B	FdcDat
	CLR.B	FdcSide
	CLR.B	FdcDrv
	RTS

; --------------------------------------------------------------- time

; FdcNow: FdcT = now (units). Trashes D0/A0.
FdcNow:
	MOVE.W	CurLine(A3),D0
	CMP.W	#255,D0
	BNE.S	FdcNowL
	MOVE.L	#VPeriodPAL*HPeriod,D0	; line 255 runs to the frame end
	BTST	#1,DVDP9(A3)
	BNE.S	FdcNowF
	MOVE.L	#VPeriodNTSC*HPeriod,D0
	BRA.S	FdcNowF
FdcNowL:
	ADDQ.W	#1,D0
	MULU.W	#HPeriod,D0
FdcNowF:
	MOVE.W	(A3),A0			; cycles left (sign extended)
	SUB.L	A0,D0
	ADD.L	FdcClk,D0
	MOVE.L	D0,FdcT
	RTS

; FdcBT: D0 = D0 bytes in units.
FdcBT:
	MULU.L	#FDCB2,D0
	LSR.L	#1,D0
	RTS

; FdcAt: D0 = the first time >= D0 when the disk is at byte D1 of the turn.
; Trashes D1-D3.
FdcAt:
	MOVE.L	D0,D3			; t
	MOVE.L	D0,D2
	DIVUL.L	#FDCROT,D0:D2		; D0 = into the turn
	MOVE.L	D3,D2
	SUB.L	D0,D2			; the turn's start
	MOVE.L	D1,D0
	BSR.S	FdcBT
	ADD.L	D2,D0
	MOVE.L	D0,D1
	SUB.L	D3,D1
	BPL.S	FdcAtX
	ADD.L	#FDCROT,D0		; passed this turn: the next
FdcAtX:	RTS

; FdcAng: D0 = the byte of the turn at time D0. Trashes D1.
FdcAng:
	DIVUL.L	#FDCROT,D1:D0
	MOVE.L	D1,D0
	ADD.L	D0,D0
	DIVU.L	#FDCB2,D0
	RTS

; ------------------------------------------------------------ the drive

; FdcDN: D0 = the selected drive: 0 A, 1 B, 2 none.
FdcDN:
	MOVEQ	#0,D0
	MOVE.B	FdcDrv,D0
	AND.B	#3,D0
	CMP.B	#2,D0
	BNE.S	FdcDN1
	MOVEQ	#0,D0			; 10 = A
FdcDN1:	CMP.B	#3,D0
	BNE.S	FdcDNX
	MOVEQ	#2,D0
FdcDNX:	RTS

; FdcImg: A0 = the selected drive's image, D0 = 0 if none (Z).
FdcImg:
	BSR.S	FdcDN
	SUB.L	A0,A0
	CMP.B	#1,D0
	BEQ.S	FdcImgB
	BHI.S	FdcImgN
	CMP.W	#5,UNIDADA
	BNE.S	FdcImgN
	MOVE.L	DIRVD0,A0
	BRA.S	FdcImgT
FdcImgB:
	CMP.W	#5,UNIDADB
	BNE.S	FdcImgN
	MOVE.L	DIRVD1,A0
FdcImgT:
	MOVE.L	A0,D0
	RTS
FdcImgN:
	MOVEQ	#0,D0
	RTS

; FdcGeo: A0 = image -> D2 sectors per track, D3 sides, D4 tracks (from the
; boot sector; 9, 2, 80 when it doesn't look valid). Keeps D5/D6 (FdcSearch
; holds the time in D5).
FdcGeo:
	MOVEM.L	D5-D6,-(SP)
	MOVEQ	#9,D2
	MOVEQ	#2,D3
	MOVEQ	#80,D4
	MOVEQ	#0,D5
	MOVE.B	$19(A0),D5
	LSL.W	#8,D5
	MOVE.B	$18(A0),D5
	CMP.W	#1,D5
	BCS.S	FdcGeoX
	CMP.W	#18,D5
	BHI.S	FdcGeoX
	MOVEQ	#0,D6
	MOVE.B	$1B(A0),D6
	LSL.W	#8,D6
	MOVE.B	$1A(A0),D6
	CMP.W	#1,D6
	BCS.S	FdcGeoX
	CMP.W	#2,D6
	BHI.S	FdcGeoX
	MOVE.W	D5,D2
	MOVE.W	D6,D3
	MOVEQ	#0,D5
	MOVE.B	$14(A0),D5
	LSL.W	#8,D5
	MOVE.B	$13(A0),D5		; total sectors
	MOVE.W	D2,D6
	MULU.W	D3,D6
	DIVU.W	D6,D5
	CMP.W	#1,D5
	BCS.S	FdcGeoX
	CMP.W	#84,D5
	BHI.S	FdcGeoX
	MOVE.W	D5,D4
FdcGeoX:
	MOVEM.L	(SP)+,D5-D6
	RTS

; FdcDirty: the selected drive's image changed (saved as the BIOS path
; does: drive B's own file on the way to the menu, else the MVD).
FdcDirty:
	BSR	FdcImg
	CMPA.L	DIRFILEB,A0
	BNE.S	FdcDirA
	ST	DskDirtyB
	RTS
FdcDirA:
	ST	MVDMODIFI
	RTS

; FdcHd: A1 = the selected drive's head position (byte).
FdcHd:
	BSR	FdcDN
	LEA	FdcHead,A1
	ADD.W	D0,A1
	RTS

; ------------------------------------------------------- command flow

; FdcEnd: the command ends at time D0 (INTRQ from then).
FdcEnd:
	SF	FdcPh
	AND.B	#~FDS_BUSY,FdcSt
	ST	FdcIrq
	MOVE.L	D0,FdcIrqAt
	RTS

; FdcBusyTo: busy until D0, then end (phase 1).
FdcBusyTo:
	MOVE.B	#1,FdcPh
	MOVE.L	D0,FdcEndAt
	RTS

; FdcSync: move the controller on to FdcT.
FdcSync:
	MOVEQ	#8,D7			; (guard)
FdcSyL:	MOVE.L	FdcT,D6
	MOVE.B	FdcPh,D0
	CMP.B	#1,D0
	BNE.S	FdcSy2
	MOVE.L	D6,D1			; busy until FdcEndAt
	SUB.L	FdcEndAt,D1
	BMI.S	FdcSyX
	MOVE.L	FdcEndAt,D0
	BRA	FdcEnd
FdcSy2:	CMP.B	#2,D0
	BNE.S	FdcSy4
	MOVE.L	D6,D1			; searching until FdcEndAt
	SUB.L	FdcEndAt,D1
	BMI.S	FdcSyX
	TST.B	FdcFnd
	BNE.S	FdcSy2F
	OR.B	#FDS_RNF,FdcSt		; record not found
	MOVE.L	FdcEndAt,D0
	BRA	FdcEnd
FdcSy2F:
	BSR	FdcFound
	BRA.S	FdcSyN
FdcSy4:	CMP.B	#4,D0
	BCS.S	FdcSyX
	CMP.B	#5,D0
	BHI.S	FdcSyX
	BSR	FdcTake
	TST.B	D0
	BEQ.S	FdcSyX
FdcSyN:	SUBQ.W	#1,D7
	BNE.S	FdcSyL
FdcSyX:	RTS

; FdcFound: the search found its ID at FdcEndAt: start the data phase.
FdcFound:
	MOVE.L	FdcEndAt,D5
	MOVE.B	FdcCmd,D0
	AND.B	#$F0,D0
	CMP.B	#$C0,D0
	BEQ.S	FdcFnRA
	CMP.B	#$F0,D0
	BEQ	FdcFnWT
	AND.B	#$E0,D0
	CMP.B	#$A0,D0
	BEQ.S	FdcFnWS
	MOVE.B	#3,FdcPh		; read sector: data 40 bytes on
	CLR.W	FdcN
	MOVE.W	#512,FdcCnt
	MOVEQ	#40,D0
	BSR	FdcBT
	ADD.L	D5,D0
	MOVE.L	D0,FdcT0
	RTS
FdcFnRA:
	MOVE.B	#6,FdcPh		; read address: the 6 ID bytes
	CLR.W	FdcN
	MOVE.W	#6,FdcCnt
	MOVE.L	D5,FdcT0
	MOVE.L	#FdcId,FdcPtr
	RTS
FdcFnWS:
	MOVE.B	#4,FdcPh		; write sector: DRQ 2 bytes after the
	CLR.W	FdcN			; ID, the first byte taken 11 bytes
	SF	FdcWr8			; after it
	MOVEQ	#2,D0
	BSR	FdcBT
	ADD.L	D5,D0
	MOVE.L	D0,FdcDrq0
	MOVEQ	#11,D0
	BSR	FdcBT
	ADD.L	D5,D0
	MOVE.L	D0,FdcT0
	RTS
FdcFnWT:
	MOVE.B	#5,FdcPh		; write track: from the index pulse
	CLR.W	FdcN			; (DRQ since the command, FdcDrq0)
	MOVE.L	D5,FdcT0
	SF	FdcSyn1
	SF	FdcWtSt
	SF	FdcWtHv
	RTS

; FdcSearch: start looking for the ID the command wants from time D0.
FdcSearch:
	MOVE.L	D0,D5			; t
	MOVE.B	#2,FdcPh
	SF	FdcFnd
	BSR	FdcImg
	BEQ	FdcSeNo
	MOVE.L	A0,A2
	BSR	FdcGeo			; D2 spt, D3 sides, D4 tracks
	BSR	FdcHd
	MOVEQ	#0,D6
	MOVE.B	(A1),D6			; head track
	CMP.W	D4,D6
	BCC	FdcSeNo
	MOVEQ	#0,D1
	MOVE.B	FdcSide,D1
	AND.W	#1,D1
	CMP.W	D3,D1
	BCC	FdcSeNo
	MOVE.W	D1,FdcSdN
	MOVE.B	FdcCmd,D0
	AND.B	#$F0,D0
	CMP.B	#$F0,D0
	BEQ	FdcSeWT
	CMP.B	#$C0,D0
	BEQ	FdcSeRA
	; read/write sector: track register = head track, sector in range,
	; side compare when the C flag is set
	CMP.B	FdcTrk,D6
	BNE	FdcSeNo
	BTST	#1,FdcCmd
	BEQ.S	FdcSeS
	MOVE.B	FdcCmd,D0
	LSR.B	#3,D0
	AND.W	#1,D0
	CMP.W	D1,D0
	BNE	FdcSeNo
FdcSeS:	MOVEQ	#0,D0
	MOVE.B	FdcSec,D0
	BEQ	FdcSeNo
	CMP.W	D2,D0
	BHI	FdcSeNo
	SUBQ.W	#1,D0
	MOVE.W	D0,D4			; k
	MOVE.W	D6,D0			; LBA = (track * sides + side) * spt + k
	MULU.W	D3,D0
	ADD.W	D1,D0
	MULU.W	D2,D0
	ADD.W	D4,D0
	CMP.W	#FDCMAXS,D0
	BCC	FdcSeNo
	MULU.L	#512,D0
	ADD.L	A2,D0
	MOVE.L	D0,FdcPtr
	MOVE.W	D4,D1			; found when the ID has passed
	MULU.W	#FDCSECL,D1
	ADD.W	#FDCSEC0+6,D1
	MOVE.L	D5,D0
	BSR	FdcAt
	MOVE.L	D0,FdcEndAt
	ST	FdcFnd
	RTS
FdcSeWT:
	MOVE.W	D2,FdcWtSpt		; write track: the next index pulse
	MOVE.W	D3,FdcWtSds
	MOVE.B	D6,FdcWtTrk
	MOVE.L	D5,D0
	MOVEQ	#0,D1
	BSR	FdcAt
	MOVE.L	D0,FdcEndAt
	ST	FdcFnd
	RTS
FdcSeRA:
	MOVE.L	D5,D0			; read address: the next ID to pass
	BSR	FdcAng
	MOVEQ	#0,D4			; k
FdcSeRAk:
	MOVE.W	D4,D1
	MULU.W	#FDCSECL,D1
	ADD.W	#FDCSEC0,D1
	CMP.W	D0,D1
	BHI.S	FdcSeRAf
	ADDQ.W	#1,D4
	CMP.W	D2,D4
	BCS.S	FdcSeRAk
	MOVEQ	#0,D4			; none left this turn: sector 1, next turn
	MOVE.W	#FDCSEC0,D1
FdcSeRAf:
	MOVE.L	D5,D0
	BSR	FdcAt
	MOVE.L	D0,FdcEndAt
	LEA	FdcId,A0
	MOVE.B	D6,(A0)+		; C
	MOVE.W	FdcSdN,D0
	MOVE.B	D0,(A0)+		; H
	MOVE.B	D4,D0
	ADDQ.B	#1,D0
	MOVE.B	D0,(A0)+		; R
	MOVE.B	#2,(A0)+		; N (512)
	MOVE.W	#$CDB4,D0		; CRC after A1 A1 A1: FE C H R N
	LEA	FdcIdM,A0
	MOVEQ	#5,D1
	BSR	FdcCrc
	MOVE.W	D0,D1
	LSR.W	#8,D1
	MOVE.B	D1,FdcId+4
	MOVE.B	D0,FdcId+5
	ST	FdcFnd
	RTS
FdcSeNo:
	MOVE.L	D5,D0			; record not found after 5 index pulses
	MOVEQ	#0,D1
	BSR	FdcAt
	ADD.L	#4*FDCROT,D0
	MOVE.L	D0,FdcEndAt
	SF	FdcFnd
	RTS

; FdcCrc: CRC-CCITT of D1 bytes at A0 on D0.
FdcCrc:
	MOVE.B	(A0)+,D2
	LSL.W	#8,D2
	EOR.W	D2,D0
	MOVEQ	#7,D3
FdcCrcB:
	ADD.W	D0,D0
	BCC.S	FdcCrcN
	EOR.W	#$1021,D0
FdcCrcN:
	DBF	D3,FdcCrcB
	SUBQ.W	#1,D1
	BNE.S	FdcCrc
	RTS

; FdcTake: write sector/track: the bytes the disk has taken by FdcT
; (the data register's, or 0 and lost data when it wasn't loaded in time).
; D0 = 1 when the command moved on (ended or searches again).
FdcTake:
	MOVE.W	#512,D4
	CMP.B	#5,FdcPh
	BNE.S	FdcTkL
	MOVE.W	#6250,D4
FdcTkL:	MOVEQ	#0,D0
	MOVE.W	FdcN,D0
	CMP.W	D4,D0
	BCC.S	FdcTkE
	BSR	FdcBT
	ADD.L	FdcT0,D0		; this byte's time
	MOVE.L	D0,D5
	MOVE.L	FdcT,D1
	SUB.L	D0,D1
	BMI.S	FdcTk0			; not yet
	TST.B	FdcWr8
	BEQ.S	FdcTkL0
	MOVE.B	FdcDat,D0
	SF	FdcWr8
	BRA.S	FdcTkB
FdcTkL0:
	OR.B	#FDS_LOST,FdcSt
	TST.W	FdcN
	BNE.S	FdcTkZ
	MOVE.L	D5,D0			; the first byte late: the command stops
	BSR	FdcEnd
	MOVEQ	#1,D0
	RTS
FdcTkZ:	MOVEQ	#0,D0
FdcTkB:	CMP.B	#5,FdcPh
	BEQ.S	FdcTkT
	LEA	FdcBuf,A0
	MOVE.W	FdcN,D1
	MOVE.B	D0,(A0,D1.W)
	BRA.S	FdcTkN
FdcTkT:	BSR	FdcWtB
FdcTkN:	ADDQ.W	#1,FdcN
	BRA.S	FdcTkL
FdcTk0:	MOVEQ	#0,D0
	RTS
FdcTkE:	CMP.B	#5,FdcPh		; all taken
	BEQ.S	FdcTkEt
	MOVE.L	#512+2,D0		; write sector: after the CRC
	BSR	FdcBT
	ADD.L	FdcT0,D0
	MOVE.L	D0,D5
	MOVE.L	FdcT,D1
	SUB.L	D0,D1
	BMI.S	FdcTk0
	MOVE.L	FdcPtr,A1		; the sector to the image
	LEA	FdcBuf,A0
	MOVE.W	#512/4-1,D1
FdcTkC:	MOVE.L	(A0)+,(A1)+
	DBF	D1,FdcTkC
	BSR	FdcDirty
	BTST	#4,FdcCmd		; multi sector: the next one
	BEQ.S	FdcTkEn
	ADDQ.B	#1,FdcSec
	MOVE.L	D5,D0
	BSR	FdcSearch
	MOVEQ	#1,D0
	RTS
FdcTkEn:
	MOVE.L	D5,D0
	BSR	FdcEnd
	MOVEQ	#1,D0
	RTS
FdcTkEt:
	MOVE.L	#6250,D0		; write track: a turn written
	BSR	FdcBT
	ADD.L	FdcT0,D0
	BSR	FdcEnd
	MOVEQ	#1,D0
	RTS

; FdcWtB: write track, one byte (D0) of the stream: F5 = sync (A1), FE
; after a sync starts an ID (C H R N), FB/F8 after a sync the data. Each
; data block goes to the image at this track and side, sector R.
FdcWtB:
	MOVE.B	FdcWtSt,D1
	CMP.B	#2,D1
	BEQ	FdcWtD
	CMP.B	#1,D1
	BEQ.S	FdcWtI
	CMP.B	#$F5,D0
	BNE.S	FdcWt1
	ST	FdcSyn1
	RTS
FdcWt1:	TST.B	FdcSyn1
	SF	FdcSyn1
	BEQ.S	FdcWtX
	CMP.B	#$FE,D0
	BNE.S	FdcWt2
	MOVE.B	#1,FdcWtSt
	CLR.W	FdcWtPos
	RTS
FdcWt2:	TST.B	FdcWtHv
	BEQ.S	FdcWtX
	CMP.B	#$FB,D0
	BEQ.S	FdcWt3
	CMP.B	#$F8,D0
	BNE.S	FdcWtX
FdcWt3:	MOVE.B	#2,FdcWtSt
	CLR.W	FdcWtPos
	MOVE.B	FdcWtId+3,D1
	AND.W	#3,D1
	MOVE.W	#128,D0
	LSL.W	D1,D0
	MOVE.W	D0,FdcWtLeft
FdcWtX:	RTS
FdcWtI:	LEA	FdcWtId,A0
	MOVE.W	FdcWtPos,D1
	MOVE.B	D0,(A0,D1.W)
	ADDQ.W	#1,D1
	MOVE.W	D1,FdcWtPos
	CMP.W	#4,D1
	BCS.S	FdcWtX
	SF	FdcWtSt
	ST	FdcWtHv
	RTS
FdcWtD:	MOVE.W	FdcWtPos,D1
	CMP.W	#512,D1
	BCC.S	FdcWtD1
	LEA	FdcBuf,A0
	MOVE.B	D0,(A0,D1.W)
FdcWtD1:
	ADDQ.W	#1,FdcWtPos
	SUBQ.W	#1,FdcWtLeft
	BNE.S	FdcWtX
	SF	FdcWtSt			; block complete
	SF	FdcWtHv
	CMP.B	#2,FdcWtId+3		; 512-byte sectors only
	BNE.S	FdcWtX
	MOVEQ	#0,D2
	MOVE.B	FdcWtId+2,D2		; R
	BEQ.S	FdcWtX
	CMP.W	FdcWtSpt,D2
	BHI.S	FdcWtX
	SUBQ.W	#1,D2
	MOVEQ	#0,D0
	MOVE.B	FdcWtTrk,D0
	MULU.W	FdcWtSds,D0
	ADD.W	FdcSdN,D0
	MULU.W	FdcWtSpt,D0
	ADD.W	D2,D0
	CMP.W	#FDCMAXS,D0
	BCC	FdcWtX
	MULU.L	#512,D0
	MOVE.L	D0,D2
	BSR	FdcImg
	BEQ	FdcWtX
	ADD.L	D2,A0
	LEA	FdcBuf,A1
	MOVE.W	#512/4-1,D1
FdcWtC:	MOVE.L	(A1)+,(A0)+
	DBF	D1,FdcWtC
	BRA	FdcDirty

; --------------------------------------------------------- the registers

; FdcRead: D1.W = address (7FF8h-7FFFh) -> D0.B. Normal stack, A3 = REGS.
FdcRead:
	IFD	FDCRDFF
	MOVEQ	#-1,D0
	RTS
	ENDC
	MOVE.B	DA8(A3),D0		; (only while slot 2 is in page 1:
	AND.B	#$0C,D0			; else the plain memory byte)
	CMP.B	#$08,D0
	BEQ.S	FdcRd1
	MOVE.L	PagRead+12(A3),A0
	AND.L	#$FFFF,D1
	MOVE.B	(A0,D1.L),D0
	RTS
FdcRd1:	MOVE.W	D1,-(SP)
	BSR	FdcNow
	BSR	FdcSync
	MOVE.W	(SP)+,D1
	AND.W	#7,D1
	BEQ	FdcRdS
	CMP.W	#1,D1
	BEQ.S	FdcRdT
	CMP.W	#2,D1
	BEQ.S	FdcRdC
	CMP.W	#3,D1
	BEQ	FdcRdD
	CMP.W	#4,D1
	BEQ.S	FdcRdSd
	CMP.W	#5,D1
	BEQ.S	FdcRdDv
	CMP.W	#7,D1
	BEQ.S	FdcRdF
	MOVEQ	#-1,D0
	RTS
FdcRdT:	MOVE.B	FdcTrk,D0
	RTS
FdcRdC:	MOVE.B	FdcSec,D0
	RTS
FdcRdSd:
	MOVE.B	FdcSide,D0
	RTS
FdcRdDv:
	BSR	FdcImg			; bit 2 = 0 once after a change
	MOVE.L	A0,D1
	BSR	FdcDN			; D0 = drive (A0 kept)
	LEA	FdcSeen,A1
	MOVE.B	FdcDrv,D2
	AND.B	#~4,D2
	CMP.L	(A1,D0.W*4),D1
	BEQ.S	FdcRdDvS
	MOVE.L	D1,(A1,D0.W*4)
	MOVE.B	D2,D0			; changed
	RTS
FdcRdDvS:
	OR.B	#4,D2
	MOVE.B	D2,D0
	RTS
FdcRdF:	MOVEQ	#-1,D2			; 7FFF: !DRQ, !INTRQ
	BSR	FdcDrq
	TST.B	D0
	BEQ.S	FdcRdF1
	AND.B	#$7F,D2
FdcRdF1:
	BSR	FdcIrqQ
	BEQ.S	FdcRdF2
	AND.B	#$BF,D2
FdcRdF2:
	MOVE.B	D2,D0
	RTS
FdcRdS:	BSR	FdcStat			; status; reading it clears INTRQ
	MOVE.B	D0,-(SP)
	BSR	FdcIrqQ
	BEQ.S	FdcRdS1
	SF	FdcIrq
FdcRdS1:
	MOVE.B	(SP)+,D0
	RTS

; FdcRdD: the data register; in a read phase with DRQ up, take the byte
; (bytes passed meanwhile are lost data, as openMSX's getDataReg).
FdcRdD:
	MOVE.B	FdcPh,D0
	CMP.B	#3,D0
	BEQ.S	FdcRdD1
	CMP.B	#6,D0
	BNE	FdcRdDx
FdcRdD1:
	BSR	FdcDrq
	TST.B	D0
	BEQ	FdcRdDx
	MOVE.L	FdcPtr,A0
FdcRdDl:
	MOVE.W	FdcN,D1
	MOVE.B	(A0,D1.W),FdcDat
	ADDQ.W	#1,D1
	MOVE.W	D1,FdcN
	CMP.W	FdcCnt,D1
	BCC.S	FdcRdDe
	MOVEQ	#0,D0
	MOVE.W	D1,D0
	BSR	FdcBT
	ADD.L	FdcT0,D0
	MOVE.L	FdcT,D1
	SUB.L	D0,D1
	BMI.S	FdcRdDx
	OR.B	#FDS_LOST,FdcSt		; the next one passed too
	BRA.S	FdcRdDl
FdcRdDe:
	CMP.B	#6,FdcPh
	BEQ.S	FdcRdDa
	BTST	#4,FdcCmd		; read sector multi: the next sector
	BEQ.S	FdcRdDn
	ADDQ.B	#1,FdcSec
	MOVE.L	FdcT,D0
	BSR	FdcSearch
	BRA.S	FdcRdDx
FdcRdDa:
	MOVE.B	FdcId,FdcSec		; read address: C into the sector reg
FdcRdDn:
	MOVE.L	FdcT,D0
	BSR	FdcEnd
FdcRdDx:
	MOVE.B	FdcDat,D0
	RTS

; FdcDrq: D0 = $FF when DRQ is up.
FdcDrq:
	MOVE.B	FdcPh,D0
	CMP.B	#3,D0
	BEQ.S	FdcDqR
	CMP.B	#6,D0
	BEQ.S	FdcDqR
	CMP.B	#4,D0
	BEQ.S	FdcDqW
	CMP.B	#5,D0
	BEQ.S	FdcDqW
FdcDqN:	MOVEQ	#0,D0
	RTS
FdcDqR:	MOVE.W	FdcN,D0			; read: byte N available
	CMP.W	FdcCnt,D0
	BCC.S	FdcDqN
	AND.L	#$FFFF,D0
	BSR	FdcBT
	ADD.L	FdcT0,D0
FdcDqT:	MOVE.L	FdcT,D1
	SUB.L	D0,D1
	BMI.S	FdcDqN
	MOVEQ	#-1,D0
	RTS
FdcDqW:	TST.B	FdcWr8			; write: wanted, not loaded yet
	BNE.S	FdcDqN
	MOVE.W	#512,D1			; (none after the last byte)
	CMP.B	#5,D0
	BNE.S	FdcDqW0
	MOVE.W	#6250,D1
FdcDqW0:
	MOVE.W	FdcN,D0
	CMP.W	D1,D0
	BCC.S	FdcDqN
	TST.W	D0
	BNE.S	FdcDqW1
	MOVE.L	FdcDrq0,D0
	BRA.S	FdcDqT
FdcDqW1:
	SUBQ.W	#1,D0			; since the previous byte was taken
	AND.L	#$FFFF,D0
	BSR	FdcBT
	ADD.L	FdcT0,D0
	BRA.S	FdcDqT

; FdcIrqQ: Z clear when INTRQ is up.
FdcIrqQ:
	TST.B	FdcIrq
	BEQ.S	FdcIqX
	MOVE.L	FdcT,D1
	SUB.L	FdcIrqAt,D1
	BMI.S	FdcIqN
	MOVEQ	#1,D1
	RTS
FdcIqN:	MOVEQ	#0,D1
FdcIqX:	RTS

; FdcStat: D0 = the status register (openMSX peekStatusReg).
FdcStat:
	MOVE.B	FdcSt,D2
	MOVE.B	FdcCmd,D0
	BPL.S	FdcStI			; type I
	AND.B	#$F0,D0
	CMP.B	#$D0,D0
	BEQ.S	FdcStI			; type IV: as type I
	AND.B	#~FDS_DRQ,D2
	BSR	FdcDrq
	TST.B	D0
	BEQ.S	FdcStR
	OR.B	#FDS_DRQ,D2
	BRA.S	FdcStR
FdcStI:	AND.B	#~(FDS_DRQ|FDS_LOST|FDS_RTYPE|FDS_WP),D2
	MOVE.L	FdcT,D0			; index pulse
	BSR	FdcAng
	CMP.W	#FDCIDX,D0
	BCC.S	FdcStI1
	OR.B	#FDS_DRQ,D2
FdcStI1:
	BSR	FdcHd			; track 0 (no drive: never, as
	CMP.B	#2,D0			; openMSX's DummyDrive)
	BEQ.S	FdcStI3
	TST.B	(A1)
	BNE.S	FdcStI3
	OR.B	#FDS_LOST,D2
FdcStI3:
	TST.B	FdcHld			; head loaded (for 3 s)
	BEQ.S	FdcStI4
	MOVE.L	FdcT,D0
	SUB.L	FdcHldAt,D0
	CMP.L	#3000*FDCMS,D0
	BCC.S	FdcStI4
	OR.B	#FDS_RTYPE,D2
FdcStI4:
	BSR	FdcImg			; write protected (no disk: always,
	BEQ.S	FdcStI5			; as openMSX's DummyDisk)
	TST.B	MVDPROT
	BEQ.S	FdcStR
FdcStI5:
	OR.B	#FDS_WP,D2
FdcStR:	AND.B	#(~FDS_NRDY)&$FF,D2		; ready: a disk in the drive
	BSR	FdcImg
	BNE.S	FdcStR1
	OR.B	#FDS_NRDY,D2
FdcStR1:
	MOVE.B	D2,D0
	RTS

; FdcWrite: register D1 (0-7) = D0. Normal stack, A3 = REGS.
FdcWrite:
	MOVE.B	D0,FdcVal
	MOVE.W	D1,-(SP)
	BSR	FdcNow
	BSR	FdcSync
	MOVE.W	(SP)+,D1
	MOVE.B	FdcVal,D6
	TST.W	D1
	BEQ.S	FdcCmdW
	CMP.W	#1,D1
	BNE.S	FdcWr2
	MOVE.B	D6,FdcTrk
	RTS
FdcWr2:	CMP.W	#2,D1
	BNE.S	FdcWr3
	MOVE.B	D6,FdcSec
	RTS
FdcWr3:	CMP.W	#3,D1
	BNE.S	FdcWr4
	MOVE.B	D6,FdcDat
	MOVE.B	FdcPh,D0
	CMP.B	#4,D0
	BEQ.S	FdcWr3w
	CMP.B	#5,D0
	BNE.S	FdcWr3x
FdcWr3w:
	ST	FdcWr8
FdcWr3x:
	RTS
FdcWr4:	CMP.W	#4,D1
	BNE.S	FdcWr5
	MOVE.B	D6,FdcSide
	RTS
FdcWr5:	CMP.W	#5,D1
	BNE.S	FdcWr6
	MOVE.B	D6,FdcDrv
FdcWr6:	RTS

; FdcCmdW: a command (D6).
FdcCmdW:
	MOVE.B	D6,FdcCmd
	SF	FdcIrq
	MOVE.L	FdcT,D5			; now
	MOVE.B	D6,D0
	LSR.B	#4,D0
	CMP.B	#$D,D0
	BEQ	FdcC4
	CMP.B	#8,D0
	BCS.S	FdcC1
	CMP.B	#$C,D0
	BCS	FdcC2
	BRA	FdcC3

; Type I: restore, seek, step, step-in, step-out (openMSX step(): the
; track register moves first; going out at track 0 ends with it 0).
FdcC1:	AND.B	#~(FDS_RNF|FDS_CRC),FdcSt
	OR.B	#FDS_BUSY,FdcSt
	SF	FdcHld
	BTST	#3,D6			; H: head loaded now
	BEQ.S	FdcC1h
	ST	FdcHld
	MOVE.L	D5,FdcHldAt
FdcC1h:	BSR	FdcHd			; A1 = head, D0 = drive
	MOVE.B	D0,D3			; (2 = none: its head stays at 0)
	MOVEQ	#0,D4			; steps
	MOVE.B	D6,D0
	LSR.B	#4,D0
	CMP.B	#1,D0
	BHI.S	FdcC1st
	BEQ.S	FdcC1sk
	MOVE.B	#$FF,FdcTrk		; restore: seek to 0
	CLR.B	FdcDat
FdcC1sk:
	MOVE.B	FdcTrk,D0		; seek
	CMP.B	FdcDat,D0
	BEQ.S	FdcC1e
	SCS	FdcDirIn		; in when the target is higher
	BSR	FdcStep1
	BEQ.S	FdcC1e
	CMP.W	#255,D4
	BCS.S	FdcC1sk
	BRA.S	FdcC1e
FdcC1st:
	CMP.B	#4,D0			; step: as before; 4/5 in, 6/7 out
	BCS.S	FdcC1s1
	CMP.B	#6,D0
	SCS	FdcDirIn
FdcC1s1:
	BSR	FdcStep1
FdcC1e:	MOVE.W	D4,D0			; busy for the steps
	MOVE.B	D6,D1
	AND.W	#3,D1
	MULU.W	FdcStepT(PC,D1.W*2),D0
	MULU.L	#FDCMS,D0
	ADD.L	D5,D0
	BRA	FdcBusyTo
FdcStepT:
	DC.W	6,12,20,30		; ms a step (1 MHz clock)

; FdcStep1: one step (D6 = command, A1 = head, D3 = drive, D4 counts).
; Z set when it ended at track 0 going out.
FdcStep1:
	MOVE.B	D6,D0
	AND.B	#$E0,D0			; restore/seek, or the T flag:
	BEQ.S	FdcSt1u			; the track register moves
	BTST	#4,D6
	BEQ.S	FdcSt1m
FdcSt1u:
	TST.B	FdcDirIn
	BEQ.S	FdcSt1o
	ADDQ.B	#1,FdcTrk
	BRA.S	FdcSt1m
FdcSt1o:
	SUBQ.B	#1,FdcTrk
FdcSt1m:
	TST.B	FdcDirIn
	BNE.S	FdcSt1i
	CMP.B	#2,D3			; going out at track 0: stop there
	BEQ.S	FdcSt1z
	TST.B	(A1)
	BNE.S	FdcSt1d
FdcSt1z:
	CLR.B	FdcTrk
	MOVEQ	#0,D0			; Z
	RTS
FdcSt1d:
	SUBQ.B	#1,(A1)
	BRA.S	FdcSt1c
FdcSt1i:
	CMP.B	#2,D3
	BEQ.S	FdcSt1c
	CMP.B	#83,(A1)		; the stop past the last track
	BCC.S	FdcSt1c
	ADDQ.B	#1,(A1)
FdcSt1c:
	ADDQ.W	#1,D4
	MOVEQ	#1,D0			; NZ
	RTS

; Type II: read/write sector.
FdcC2:	AND.B	#~(FDS_LOST|FDS_RNF|FDS_RTYPE|FDS_WP),FdcSt
	OR.B	#FDS_BUSY,FdcSt
	BSR	FdcImg
	BNE.S	FdcC2r
	MOVE.L	D5,D0			; not ready: ends now
	BRA	FdcEnd
FdcC2r:	ST	FdcHld
	MOVE.L	D5,FdcHldAt
	BTST	#2,D6			; E: 30 ms head settle
	BEQ.S	FdcC2e
	ADD.L	#30*FDCMS,D5
FdcC2e:	MOVE.B	D6,D0
	AND.B	#$E0,D0
	CMP.B	#$A0,D0
	BNE.S	FdcC2s
	TST.B	MVDPROT			; write on a protected disk
	BEQ.S	FdcC2s
	OR.B	#FDS_WP,FdcSt
	MOVE.L	D5,D0
	BRA	FdcBusyTo
FdcC2s:	MOVE.L	D5,D0
	BRA	FdcSearch

; Type III: read address, read track, write track.
FdcC3:	AND.B	#~(FDS_LOST|FDS_RNF|FDS_RTYPE),FdcSt
	OR.B	#FDS_BUSY,FdcSt
	MOVE.L	D5,FdcDrq0		; (write track: DRQ from now)
	BSR	FdcImg
	BNE.S	FdcC3r
	MOVE.L	D5,D0
	BRA	FdcEnd
FdcC3r:	ST	FdcHld
	MOVE.L	D5,FdcHldAt
	BTST	#2,D6
	BEQ.S	FdcC3e
	ADD.L	#30*FDCMS,D5
FdcC3e:	MOVE.B	D6,D0
	AND.B	#$F0,D0
	CMP.B	#$E0,D0
	BNE.S	FdcC3w
	MOVE.L	D5,D0			; read track: a turn, no data
	ADD.L	#FDCROT,D0
	BRA	FdcBusyTo
FdcC3w:	CMP.B	#$F0,D0
	BNE.S	FdcC3s
	TST.B	MVDPROT
	BEQ.S	FdcC3s
	OR.B	#FDS_WP,FdcSt
	MOVE.L	D5,D0
	BRA	FdcBusyTo
FdcC3s:	MOVE.L	D5,D0
	BRA	FdcSearch

; Type IV: force interrupt (I3 = INTRQ now).
FdcC4:	TST.B	FdcPh
	BEQ.S	FdcC4i
	SF	FdcPh
	AND.B	#~FDS_BUSY,FdcSt
	BRA.S	FdcC4q
FdcC4i:	CLR.B	FdcSt
FdcC4q:	BTST	#3,D6
	BEQ.S	FdcC4x
	ST	FdcIrq
	MOVE.L	D5,FdcIrqAt
FdcC4x:	RTS

; --------------------------------------------------------------- data
	CNOP	0,4
FdcClk:		DC.L	0		; units at this frame's start
FdcT:		DC.L	0		; now (FdcNow)
FdcSP:		DC.L	0
FdcRegs:	DS.L	14
FdcHkD0:	DC.L	0,0,0,0		; (D0-D2/A4 kept)
FdcHkM:		DC.L	0		; FdcHkTab entries swapped in (bit field)
FdcEndAt:	DC.L	0		; phase 1/2 ends
FdcIrqAt:	DC.L	0		; INTRQ from
FdcHldAt:	DC.L	0		; head loaded at
FdcT0:		DC.L	0		; data phase: byte 0's time
FdcDrq0:	DC.L	0		; write: DRQ for byte 0 from
FdcPtr:		DC.L	0		; read: the bytes
FdcSeen:	DC.L	0,0,0		; images last reported (disk change)
FdcN:		DC.W	0		; data phase: next byte
FdcCnt:		DC.W	0		; data phase: bytes
FdcSdN:		DC.W	0		; side being read/written
FdcWtPos:	DC.W	0
FdcWtLeft:	DC.W	0
FdcWtSpt:	DC.W	0
FdcWtSds:	DC.W	0
FdcOn:		DC.B	0		; the controller is in slot 2
FdcHook:	DC.B	0		; INSTR has the hooked reads
FdcRes:		DC.B	0
FdcVal:		DC.B	0
FdcCmd:		DC.B	3
FdcSt:		DC.B	0
FdcTrk:		DC.B	0
FdcSec:		DC.B	1
FdcDat:		DC.B	0
FdcSide:	DC.B	0
FdcDrv:		DC.B	0
FdcHead:	DC.B	0,0,0,0		; head track: A, B, none
FdcPh:		DC.B	0		; 0 idle, 1 busy to FdcEndAt, 2 search,
					; 3 read data, 4 write data, 5 write
					; track, 6 read address
FdcFnd:		DC.B	0
FdcIrq:		DC.B	0
FdcHld:		DC.B	0
FdcDirIn:	DC.B	0
FdcWr8:		DC.B	0		; write: the data register is loaded
FdcSyn1:	DC.B	0		; write track: last byte F5
FdcWtSt:	DC.B	0		; write track: 0 scan, 1 ID, 2 data
FdcWtHv:	DC.B	0		; write track: an ID seen
FdcWtTrk:	DC.B	0
FdcIdM:		DC.B	$FE		; (the ID mark, for its CRC)
FdcId:		DS.B	6
FdcWtId:	DS.B	4
	CNOP	0,4
FdcBuf:		DS.B	512
FdcStk:		DS.L	64
FdcStkE:
