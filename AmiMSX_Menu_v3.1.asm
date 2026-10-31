
;	Menu para MSX2 Emulator.
;	Por: Juan Antonio G�mez

;    DC.L    $80000093,1			; En MSX2WIN
;    DC.L    $80080032,6,$00000000		; En MTags0


_SysBase=4

REGISTRO:MACRO
	INCLUDE	"Registros/Registros.asm"
	ENDM

	IFND	Usuario
Usuario=0
	ENDC

	IFND	Key_ON
Key_ON=0			; 1=Off
	ENDC

	INCLUDE	"AmiMSX_MenuPos.i"	; (4.6) named menu positions

; <=-----------------------=>

	MOVEQ	#0,D0
	LEA	GADNOM(PC),A1
	MOVE.L	$4.W,A6
	JSR	-$228(A6)
	MOVE.L	D0,_GADTOOLSBASE
	BEQ	LIBSERROR
; <=----------------------------------=>
	MOVEQ	#0,D0
	LEA	INTNOM(PC),A1
	MOVE.L	$4.W,A6
	JSR	-$228(A6)
	MOVE.L	D0,_INTUITIONBASE
	BEQ	LIBSERROR
; <=----------------------------------=>
	MOVEQ	#0,D0
	LEA	DOSNOM(PC),A1
	MOVE.L	$4.W,A6
	JSR	-$228(A6)
	MOVE.L	D0,_DOSBASE
	BEQ	LIBSERROR
; <=----------------------------------=>
	MOVEQ	#0,D0
	LEA	ASLNOM(PC),A1
	MOVE.L	4.W,A6
	JSR	-$228(A6)
	MOVE.L	D0,_ASLBASE
; <=----------------------------------=>
	MOVEQ	#3,D0
	LEA	STCNOM(PC),A1
	MOVE.L	4.W,A6
	JSR	-$228(A6)
	MOVE.L	D0,_STCBASE
	BNE.S	YASTC20
	MOVEQ	#3,D0
	LEA	STCNOM20(PC),A1
	MOVE.L	4.W,A6
	JSR	-$228(A6)
	MOVE.L	D0,_STCBASE
YASTC20:
; <=----------------------------------=>
	MOVEQ	#0,D0
	LEA	xpkNOM(PC),A1
	MOVE.L	4.W,A6
	JSR	-$228(A6)
	MOVE.L	D0,_xpkBase
; <=-----------------------=>
	CLR.L	MENSWB
	MOVE.L	$4.W,A6
	SUB.L	A1,A1
	JSR	-$126(A6)
	MOVE.L	D0,A2
	TST.L	$AC(A2)
	BNE.S	CLI
	LEA	$5C(A2),A0
	JSR	-$180(A6)
	LEA	$5C(A2),A0
	JSR	-$174(A6)
	MOVE.L	D0,MENSWB
	MOVE.L	D0,A2
	BSR	WBToolTypes		; PREFS=<file> from the icon.
	MOVE.L	$24(A2),D0
	BEQ.S	CLI
	MOVE.L	_DOSBASE,A6
	MOVE.L	D0,A0
	MOVE.L	(A0),D1
	JSR	-$7E(A6)
CLI:

; -------------------------------
	IFEQ	Key_ON
	BSR	LoadKey			; Lee Key.
	ENDC
; -------------------------------

	LEA	DIRINFOTEXT,A0
	BSR	CENTRAR

; <=-----------------------=>

	BSR	PROGRAMA

; <=-----------------------=>

; -------------------------------
	IFEQ	Key_ON
	BSR	BorraKey		; Borra Key.
	ENDC
; -------------------------------

; <=-----------------------=>
	MOVE.L	BucCartS1(PC),D0
	BEQ.S	NoHayCartS1
	ADD.L	BucCartAddS1(PC),D0
	MOVE.L	DirCartS1(PC),A1
	MOVE.L	$4.W,A6
	JSR	-$D2(A6)		; Libera memoria.
	CLR.L	BucCartS1
NoHayCartS1:
	MOVE.L	BucCartS2(PC),D0
	BEQ.S	NoHayCartS2
	ADD.L	BucCartAddS2(PC),D0
	MOVE.L	DirCartS2(PC),A1
	MOVE.L	$4.W,A6
	JSR	-$D2(A6)		; Libera memoria.
	CLR.L	BucCartS2
NoHayCartS2:
; <=-----------------------=>

; <=-----------------------=>
	MOVE.L	BucKanji(PC),D0
	BEQ.S	NoHayKanji
	MOVE.L	DirKanji(PC),A1
	MOVE.L	$4.W,A6
	JSR	-$D2(A6)		; Libera memoria.
	CLR.L	DirKanji
	CLR.L	BucKanji
NoHayKanji:
; <=-----------------------=>

; <=-----------------------=>
	MOVE.L	BucMapper(PC),D0
	BEQ.S	NoHayMapper
	MOVE.L	DirMapper(PC),A1
	MOVE.L	$4.W,A6
	JSR	-$D2(A6)		; Libera memoria.
	CLR.L	DirMapper
	CLR.L	BucMapper
NoHayMapper:
	JSR	RomDbFree		; (4.0) ROM database and cache.
; <=-----------------------=>

	TST.L	_ASLBASE
	BEQ.S	NOHAYASL

	MOVE.L	REQBASE,A0
	MOVE.L	_ASLBASE,A6
	JSR	-$36(A6)	; FreeAslRequest.

	MOVE.L	REQBASETape,A0
	MOVE.L	_ASLBASE,A6
	JSR	-$36(A6)	; FreeAslRequest.

	MOVE.L	ReqBaseVram,A0
	MOVE.L	_ASLBASE,A6
	JSR	-$36(A6)	; FreeAslRequest.

	MOVE.L	ReqBaseSlot,A0
	MOVE.L	_ASLBASE,A6
	JSR	-$36(A6)	; FreeAslRequest.
NOHAYASL:

	MOVE.L	DIRFILE,A1
	MOVE.L	BUCFILE,D0
	BEQ.S	NOHAYMEM2
	MOVE.L	4.W,A6
	JSR	-$D2(A6)		; Libera memoria.
	CLR.L	BUCFILE
	CLR.L	DIRFILE
NOHAYMEM2:
	MOVE.L	BUCFILEB,D0		; (4.0) drive B's virtual disk.
	BEQ.S	NOHAYMEMB
	MOVE.L	DIRFILEB,A1
	MOVE.L	4.W,A6
	JSR	-$D2(A6)
	CLR.L	BUCFILEB
	CLR.L	DIRFILEB
NOHAYMEMB:
	MOVE.L	MagAlloc,D0		; (4.1.2) the magnified sprites' bank.
	BEQ.S	NoHayMagMem
	MOVE.L	D0,A1
	MOVE.L	#MAGSIZE*2,D0
	MOVE.L	4.W,A6
	JSR	-$D2(A6)
	CLR.L	MagAlloc
	CLR.L	MagBank
NoHayMagMem:

	MOVEQ	#0,D0
	JSR	LIBMEM

; <=-----------------------=>
	TST.B	MFMDEVICE
	BEQ.S	NOHAYDEVICE
	LEA	DISKIOREQI,A1		; Cierra Device.
	MOVE.L	$4,A6
	JSR	-$1C2(A6)	
NOHAYDEVICE:
; <=-----------------------=>
	MOVE.L	$4.W,A6
	TST.L	MENSWB(PC)
	BEQ.S	MENSWBRET
	JSR	-$84(A6)
	MOVE.L	MENSWB(PC),A1
	JSR	-$17A(A6)
MENSWBRET:
; <=-----------------------=>

; <=-----------------------=>
LiberaLib:MACRO
	MOVE.L	\1,A1
	TST.L	A1
	BEQ.S	\@LibLib
	MOVE.L	$4.W,A6
	JSR	-$19E(A6)	; Libera Librer�a.
\@LibLib:
	ENDM

LibsError:
	LiberaLib _DosBase
	LiberaLib _IntuitionBase
	LiberaLib _GadToolsBase
	LiberaLib _AslBase
	LiberaLib _xpkBase
	LiberaLib _StcBase

	RTS

; <=-----------------------=>

	CNOP	0,4
ACTUTAGS:			; A0=Dir TagListBase.
	MOVE.L	A0,A1
	TST.W	D0		; D0=N�mero de gadget.
	BEQ.S	ACTAGCON	; D1=N�mero de Tag a modificar.
ACTUTAGSB:			; D2=Dato a modificar.
	TST.L	(A0)+
	DBNE	D0,ACTUTAGS
	ADDQ	#4,A0
	BRA.S	ACTUTAGSB
ACTAGCON:
	TST.L	(A0)
	BEQ.S	ACTAGRET
	CMP.L	(A0)+,D1
	BEQ.S	ACTAGFIN
	ADDQ	#4,A0
	BRA.S	ACTAGCON
ACTAGFIN:
	MOVE.L	D2,(A0)+
ACTAGRET:
	RTS
; <=-----------------------=>

	CNOP	0,4
CENTRAR:
	TST.L	(A0)
	BNE.S	MIRACERO
	RTS
MIRACERO:
	MOVE.L	(A0)+,A2
	MOVE.L	(A0)+,D1
	MOVE.L	$C(A2),A1
	MOVEQ	#0,D0
MIRACEROB:
	ADDQ.W	#1,D0
	TST.B	(A1)+
	BNE.S	MIRACEROB
	SUBQ.W	#1,D0
	LSL.W	#3,D0
	SUB.W	D0,D1
	LSR.W	#1,D1
	MOVE.W	D1,4(A2)
	BRA.S	CENTRAR


	CNOP	0,4
DIRINFOTEXT:
	DC.L	ABOUTTEXT0,324
	DC.L	ABOUTTEXT1,324
	DC.L	ABOUTTEXT2,324
	DC.L	ABOUTTEXT3,324
	DC.L	ABOUTTEXT4,324
	DC.L	ABOUTTEXT5,324
	DC.L	ABOUTTEXT6,324
	DC.L	ABOUTTEXT7,324
	DC.L	ABOUTTEXT8,324
	DC.L	ABOUTTEXT9,324
	DC.L	ABOUTTEXT10,324
	DC.L	0,0

; <=-----------------------=>
		CNOP	0,8
CabFileBuf:	DS.L	4
XpkFibBase:	DC.L	0
DirCart:	DC.L	0
BucCart:	DC.L	0
BucCartAdd:	DC.L	0
BucCartAdd2:	DC.L	0
PagCart:	DC.W	0
DirCartS1:	DC.L	0
BucCartS1:	DC.L	0
BucCartAddS1:	DC.L	0
PagCartS1:	DC.W	0
DirCartS2:	DC.L	0
BucCartS2:	DC.L	0
BucCartAddS2:	DC.L	0
PagCartS2:	DC.W	0

DirMapper:	DC.L	0
BucMapper:	DC.L	0

Comprimido:	DC.B	0
DisCheaDat:	DC.B	0
LoROMBaDat:	DC.B	0
KanjiDat:	DC.B	0

DirActuMapp:	DC.L	0
SiNewMapp:	DC.B	0,0

CheckId:	DC.L	0
CheckIdS1:	DC.L	0
CheckIdS2:	DC.L	0
CheckIdS1Old:	DC.L	0
CheckIdS2Old:	DC.L	0

DirKanji:	DC.L	0
BucKanji:	DC.L	0

SlotxCart:	DC.L	0
Slot1Cart:	DC.B	0
Slot2Cart:	DC.B	0
; <=-----------------------=>
DatTxt:		DC.L	0
DatItem:	DC.L	0
; <=-----------------------=>
EsReset:	DC.B	0
ProtectDat:	DC.B	0
; <=-----------------------=>
		CNOP	0,4
MENSWB:		DC.L	0
DISBASE:	DC.L	0
_GADTOOLSBASE:	DC.L	0
		DC.W	USUARIO*3
MFMDEVICE:	DC.B	0
		DC.B	0		; (was the Imploder's efficiency)
DISKERRORES:	DC.B	0
EsUn060:	DC.B	0
		CNOP	0,4
		DC.W	USUARIO*2
GADNOM:		DC.B	"gadtools.library",0
		EVEN
_INTUITIONBASE:	DC.L	0
INTNOM:		DC.B	"intuition.library",0
		EVEN
_DOSBASE:	DC.L	0
		DC.W	USUARIO
DOSNOM:		DC.B	"dos.library",0
		CNOP	0,4
_xpkBase:	DC.L	0
REQBASE:	DC.L	0
ReqBaseTape:	DC.L	0
ReqBaseVram:	DC.L	0
ReqBaseSlot:	DC.L	0
_ASLBASE:	DC.L	0
ASLNOM:		DC.B	"asl.library",0
		EVEN
_STCBASE:	DC.L	0
STCNOM20:	DC.B	"stc020.library",0,0
STCNOM:		DC.B	"stc.library",0,0
xpkNom:		DC.B	"xpkmaster.library",0,0

		CNOP	0,4
ActuROM:	DC.W	-1
ActuDOS:	DC.W	-1
TexDirDOS:
		DC.L	tDOS1
		DC.L	tDOS2
TexDirROM:
		DC.L	tMSX1
		DC.L	tMSX2
		DC.L	tMSX2p
		DC.L	tMSXtR
tMSX1:		DC.B	"PROGDIR:ROM_Files/MSX.ROM",0,0
tMSX2:		DC.B	"PROGDIR:ROM_Files/MSX2.ROM",0,0
tMSX2p:		DC.B	"PROGDIR:ROM_Files/MSX2+.ROM",0,0
tMSXtR:		DC.B	"PROGDIR:ROM_Files/Turbo R.ROM",0,0
tDOS1:		DC.B	"PROGDIR:ROM_Files/DOS.ROM",0,0
tDOS2:		DC.B	"PROGDIR:ROM_Files/DOS2.ROM",0,0

		CNOP	0,4
DIRTXTLOD:	DC.L	TLOADDEC
ControlKeys:	DC.W	0
TIPOROM:	DC.W	1
MVDMODIFI:	DC.B	0,0
GODAT:		DC.B	0
FILECOMP:	DC.B	0

		DC.L	0
		CNOP	0,4
DegugDirFrom:	DC.L	0
DegugDirTo:	DC.L	0
DIRFILE:	DC.L	0
BUCFILE:	DC.L	0
DIRFILEB:	DC.L	0		; (4.0) drive B's virtual disk (CLI B=),
BUCFILEB:	DC.L	0		; plain 360/720 Kb images only.
BucFileCart:	DC.L	0
DirKeyFile:	DC.L	0
BucKeyFile:	DC.L	0
DirKeyBuff:	DC.L	0
BYTEFILE:	DC.L	0
SLBUCFILE:	DC.L	0
TapeBUCFILE:	DC.L	0
DirCaset:	DC.L	0
LoadCaset:	DC.L	0
SaveCaset:	DC.L	0
BucCaset:	DC.W	0
ModoCaset:	DC.B	0,0
SizeCaset:	DC.W	0
CheatDir:	DC.W	0
DirMonitor:	DC.W	0
SpeedTest:	DC.L	0
		DC.L	0
FILENOM:	DS.B	$208
	IFD	PERF
; Speed counter dump: header (APRF, records, ring pointer, copper ints, int
; lines, CPU) then the record ring (see PerfFrame in the main source).
PerfDump:
	TST.B	PerfDone		; (4.0) Once: the first return to the
	BNE	PerfDRet		; menu, however the run ended (Measure).
	ST	PerfDone
	MOVE.L	$4.W,A0
	MOVE.B	$129(A0),PerfCPU	; ExecBase AttnFlags (low byte).
	MOVE.B	EsUn060,PerfCPU+1
	MOVE.L	#PerfName,D1
	MOVE.L	#$3EE,D2
	BSR	OPENFILE
	TST.L	D0
	BEQ	PerfDFin
	MOVE.L	#PerfHdr,D2
	MOVE.L	#PerfPCEnd0-PerfHdr,D3	; Records and profile header...
	BSR	WRITEFILE
	MOVE.L	#PerfPCBuf,D2		; ...and the PC samples.
	MOVE.L	#PerfPCEnd-PerfPCBuf,D3
	BSR	WRITEFILE
	MOVE.L	#GFXSPR,D2		; Debug: GFXSPR, GFXSPR8, GFXSPRT, then
	MOVE.L	#8,D3			; both sprite pattern areas.
	BSR	WRITEFILE
	MOVE.L	#GFXSPRT,D2
	MOVE.L	#4,D3
	BSR	WRITEFILE
	MOVE.L	GFXSPR,D2
	SUB.L	#96,D2
	MOVE.L	#10240,D3
	BSR	WRITEFILE
	MOVE.L	GFXSPR8,D2
	MOVE.L	#20480,D3
	BSR	WRITEFILE
	MOVE.L	#DIRVRAM,D2		; VDP state: 128 KB VRAM, the state
	MOVE.L	#128*1024,D3		; block (REGS-$400..+$800), MSX2
	BSR	WRITEFILE		; palette, TSplit.
	MOVE.L	#REGS-$400,D2
	MOVE.L	#$C00,D3
	BSR	WRITEFILE
	MOVE.L	#MSX2Pal,D2
	MOVE.L	#32,D3
	BSR	WRITEFILE
	MOVE.L	#TSplit,D2
	MOVE.L	#2,D3
	BSR	WRITEFILE
	MOVE.L	#PalDbgBlk,D2		; Mid-frame palette state (debug).
	MOVE.L	#PalDbgEnd-PalDbgBlk,D3
	BSR	WRITEFILE
	MOVE.L	CopperLineDos,D2	; Copper: line slots, then the routines.
	MOVE.L	#212*CoppLineSize,D3
	BSR	WRITEFILE
	MOVE.L	CopperOptsDos,D2
	MOVE.L	#4096,D3
	BSR	WRITEFILE
	MOVE.L	#CopperLineDos,D2	; (and both pointers)
	MOVE.L	#4,D3
	BSR	WRITEFILE
	MOVE.L	#CopperOptsDos,D2
	MOVE.L	#4,D3
	BSR	WRITEFILE
	MOVE.L	#SCREEN,D2		; SCREEN 2/4 buffer (32 KB).
	MOVE.L	#32*32*8*4,D3
	BSR	WRITEFILE
	MOVE.L	GfxCaPtr,D2		; Character cache in use (64 KB),
	MOVE.L	#64*1024,D3
	BSR	WRITEFILE
	MOVE.L	#GfxCaPtr,D2		; and which one (GFXCA, GFXCA2).
	MOVE.L	#4,D3
	BSR	WRITEFILE
	MOVE.L	#GfxCaAdr,D2
	MOVE.L	#8,D3
	BSR	WRITEFILE
	MOVE.L	#TAB98,D2		; Dirty flags of both cache banks.
	MOVE.L	#$800*8,D3
	BSR	WRITEFILE
	MOVE.L	#TAB98B,D2
	MOVE.L	#$800*8,D3
	BSR	WRITEFILE
	MOVE.L	REGS+$10+6*4,D2		; MSX RAM C000-FFFF as mapped now (PagWrite
	ADD.L	#$C000,D2		; holds base minus Z80 address, per 8 KB).
	MOVE.L	#$2000,D3
	BSR	WRITEFILE
	MOVE.L	REGS+$10+7*4,D2
	ADD.L	#$E000,D2
	MOVE.L	#$2000,D3
	BSR	WRITEFILE
	MOVE.L	#KeyFrN,D2		; Key-script frame count (last 4 bytes).
	MOVE.L	#4,D3
	BSR	WRITEFILE
	MOVE.L	#SCCalls,D2		; Sprite collision checks run (after it).
	MOVE.L	#4,D3
	BSR	WRITEFILE
	MOVE.L	#Tabla7C,D2		; (4.0) OPLL registers, then the count
	MOVE.L	#$44,D3			; of OPLL data writes.
	BSR	WRITEFILE
	MOVE.L	#Opll7DCnt,D2
	MOVE.L	#4,D3
	BSR	WRITEFILE
	MOVE.B	DirPrefs+$76,FlDbg+11	; (4.0) flash cartridge counters, mapper.
	MOVE.L	#FlDbg,D2
	MOVE.L	#12,D3
	BSR	WRITEFILE
	MOVE.L	#DispN,D2		; (4.0) display timing: count, then the
	MOVE.L	#4,D3			; ring (byte per MSX frame).
	BSR	WRITEFILE
	MOVE.L	#DispLog,D2
	MOVE.L	#4096,D3
	BSR	WRITEFILE
	MOVE.L	#DispLine,D2
	MOVE.L	#4096,D3
	BSR	WRITEFILE
	MOVE.L	#DbCommits,D2		; (4.0) double-buffered frames shown,
	MOVE.L	#16,D3			; stops (option/split, renderer), starts
	BSR	WRITEFILE
	MOVE.L	#AclN,D2		; (4.0) copper line list rebuilds, late ones.
	MOVE.L	#8,D3
	BSR	WRITEFILE
	MOVE.L	#"SPRL",SprHwHdr	; (4.4) hardware-test log: frame and sprite
	MOVE.L	#SprHwHdr,D2		; pass timing (SPRLOG).
	MOVE.L	#4+3*4096,D3
	BSR	WRITEFILE
	IFD	STATEDUMP
	MOVE.L	#StDumpN,D2		; (state dumps: count, then 4 slots)
	MOVE.L	#4+4*STDSIZE,D3
	BSR	WRITEFILE
	ENDC
	IFD	BANDCHK
	MOVE.L	#BcBad,D2		; (band check: bad count, pointer, ring)
	MOVE.L	#4096+8,D3
	BSR	WRITEFILE
	ENDC
	IFD	FMXREC			; (FMX check build) start registers,
	MOVE.L	#FMXRecInit,D2		; pointers, writes (frame.W, reg, value),
	MOVE.L	#64,D3			; output bytes.
	BSR	WRITEFILE
	MOVE.L	#FMXRecWP,D2
	MOVE.L	#8,D3
	BSR	WRITEFILE
	MOVE.L	#FMXRecW,D2
	MOVE.L	#65536,D3
	BSR	WRITEFILE
	MOVE.L	#FMXRecO,D2
	MOVE.L	#1048576,D3
	BSR	WRITEFILE
	ENDC
	BSR	CLOSEFILE
PerfDFin:
PerfDRet:
	RTS
PerfDone:	DC.B	0
		EVEN
	IFD	PERFLOCAL		; (measurement builds: the current
PerfName:	DC.B	"perf.bin",0		; directory, no AmiMSX: assign)
	ELSE
PerfName:	DC.B	"AmiMSX:perf.bin",0
	ENDC
		EVEN
	EVEN
	ENDC
	IFD	TRACE
; Debug trap dump: header (TraceHdr), ring buffer, then the Z80's &HC000-&HFFFF
; as seen when it froze (page 3: RAM with RDPRIM/CLPRIM at &HF380).
TraceDump:
	MOVE.L	TracePtr,D0
	SUB.L	#TraceBuf,D0
	MOVE.L	D0,TraceHdr+4
	MOVE.L	TraceCount,TraceHdr+8
	MOVE.L	#TraceName,D1
	MOVE.L	#$3EE,D2
	BSR	OPENFILE
	TST.L	D0
	BEQ	TrDumpFin
	MOVE.L	#TraceHdr,D2
	MOVE.L	#TraceBuf-TraceHdr,D3
	BSR	WRITEFILE
	MOVE.L	#TraceBuf,D2
	MOVE.L	#TraceBufEnd-TraceBuf,D3
	BSR	WRITEFILE
	MOVE.L	TraceHdr+16+(6*4),D2	; PagRead[6] + &HC000
	ADD.L	#$C000,D2
	MOVE.L	#$2000,D3
	BSR	WRITEFILE
	MOVE.L	TraceHdr+16+(7*4),D2	; PagRead[7] + &HE000
	ADD.L	#$E000,D2
	MOVE.L	#$2000,D3
	BSR	WRITEFILE
	MOVE.L	#DIRVRAM,D2		; And the whole 128Kb of VRAM.
	MOVE.L	#128*1024,D3
	BSR	WRITEFILE
	MOVE.L	#TrvPtr,D2		; Sprite-table event ring.
	MOVE.L	#TrvEnd-TrvPtr,D3
	BSR	WRITEFILE
	MOVE.L	GFXSPR,D2		; Sprite pattern areas: main (from
	SUB.L	#96,D2			; its header)...
	MOVE.L	#10240,D3
	BSR	WRITEFILE
	MOVE.L	GFXSPR8,D2		; ...and the 8x8 one (GFXSPRT).
	MOVE.L	#20480,D3
	BSR	WRITEFILE
	MOVE.L	#GFXSPR,D2		; Pointers: GFXSPR, GFXSPR8, GFXSPRT.
	MOVE.L	#8,D3
	BSR	WRITEFILE
	MOVE.L	#GFXSPRT,D2
	MOVE.L	#4,D3
	BSR	WRITEFILE
	MOVE.L	#FlDbg,D2		; (4.0) flash counters (last 12 bytes)
	MOVE.L	#12,D3
	BSR	WRITEFILE
	BSR	CLOSEFILE
	MOVE.L	#ScrDumpName,D1		; The SCREEN 2/4 bitmap (256 lines,
	MOVE.L	#$3EE,D2		; 4 interleaved planes): screen.bin.
	BSR	OPENFILE
	TST.L	D0
	BEQ.S	TrDumpFin
	MOVE.L	#SCREEN,D2		; (The one the copper shows.)
	MOVE.L	#32*32*8*4,D3
	BSR	WRITEFILE
	BSR	CLOSEFILE
TrDumpFin:
	RTS
TraceName:	DC.B	"AmiMSX:trace.bin",0
ScrDumpName:	DC.B	"AmiMSX:screen.bin",0
	EVEN
	ENDC
AutoCart:	DC.B	0		; Test hook flags (see ANEM).
AutoGo:		DC.B	0
AutoDisk:	DC.B	0		; CLI test hook: FILENOM is a disk image.
		EVEN
		CNOP	0,4
BUFERDSK:	DS.L	8
		CNOP	0,4
EXAMINE:	DS.B	520
*************************************************************
*************************************************************
*************************************************************


	CNOP	0,4
PROGRAMA:
	BSR	LoadPrefs

	BSR	PonPrefs

	BSR	LoadROMs
	BSR	LoadKanji

	BSR	LoadMapperId

	JSR	RtgInit			; (4.5) RTG ToolType: the modes; the menu
					; screen then opens on RTG too.
	TST.B	RtgWant			; (4.6) Not on RTG: RTG Scanlines greyed
	BNE.S	RtgScanMenuOn		; (NM_ITEMDISABLED, before the menus are
	OR.W	#$0010,MSX2NewMenu45b+10	; made).
RtgScanMenuOn:
	JSR	SETUPSCREEN
	TST.L	D0			; (4.0) No screen (low chip RAM): out.
	BNE	QUITAR

	TST.L	_ASLBASE
	BNE.S	SIHAYASL
	BSR	NeedASL
SIHAYASL:

;;	BSR	MiraAGA
;;	TST.L	D0
;;	BEQ	QUITAR

	BSR	MC68020
	TST.L	D0
	BEQ	QUITAR

	BSR	CheckAGA

; ------------------------------------------
	TST.B	LoROMBaDat(PC)		; �ROMs Base Leido Correctamente?
	BNE.S	SiEstaData2
	LEA	tErNoMSX2data,A0
	BSR	ImpError
SiEstaData2:

;;;	BSR	MiraROMDirectory
; ------------------------------------------

; ------------------------------------------
	IFEQ	Key_ON
	LEA	DirKeyBuff-$128(PC),A0
	LEA	DirPrefs+8(PC),A5
	MOVE.W	#($128)/8,D0
	MOVE.L	(A0,D0.W*8),A0
	MOVE.W	#($3C+8)/4,D0
	MOVE.L	([A0,D0.W*4]),(A5)+
	MOVE.L	([A0,D0.W*4],4.W),(A5)+
	ENDC
; ------------------------------------------

; ------------------------------------------
	BSR	ABREDEVICE

;;;	BSR	MiraSpeed

; ------------------------------------------

	IFD	SPLASH			; Matra splash: off by default in 4.0 (-DSPLASH=1).
	TST.B	AutoCart		; Test hook: no splash.
	BNE.S	NoShowMatra
	TST.B	AutoDisk
	BNE.S	NoShowMatra
	BSR	ShowMatra
NoShowMatra:
	ENDC

; ------------------------------------------

; ------------------------------------------


	MOVEM.L	MCEROS,D0-D7/A0-A6
	JSR	OPENMSX2WINDOW
	TST.L	D0			; (4.0) No main window: out.
	BNE	MSX2WFail

	IFND	MENU
	IFEQ	Usuario
	BSR	GOCONTOFF			; OFF de GO y Continue.
	ENDC
	ENDC

	MOVE.L	MSX2Wnd,TAGS0+4
	MOVE.L	MSX2Wnd,TAGS1+4
	MOVE.L	MSX2Wnd,TAGS2+4
	MOVE.L	MSX2Wnd,TAGS3+4

	MOVEQ	#0,D0
	MOVEQ	#0,D1
	move.l  Scr,a0
	move.l  40(a0),a1
	move.w  4(a1),D1
	MOVE.L	MSX2Wnd,A0
	LEA	DATMSXPIC,A1
	TST.B	RtgTall			; (4.5) RTG menu: the tall logo,
	BEQ.S	MsxPicN
	LEA	RtgTallPic,A1
	MOVE.B	55(A0),D1		; under the window's title bar.
MsxPicN:
	MOVE.L	50(A0),A0
	MOVE.L	_INTUITIONBASE,A6
	JSR	-114(A6)

	BSR	PONPREFS2


	TST.L	_ASLBASE
	BEQ.S	NOHAYASL2

	MOVEQ	#0,D0
	LEA	TAGS0(PC),A0
	MOVE.L	_ASLBASE,A6
	JSR	-$30(A6)	; AllocAslRequest.
	MOVE.L	D0,REQBASE

	MOVEQ	#0,D0
	LEA	TAGS3(PC),A0
	MOVE.L	_ASLBASE,A6
	JSR	-$30(A6)	; AllocAslRequest.
	MOVE.L	D0,REQBASETape

	MOVEQ	#0,D0
	LEA	TAGS1(PC),A0
	MOVE.L	_ASLBASE,A6
	JSR	-$30(A6)	; AllocAslRequest.
	MOVE.L	D0,ReqBaseVram

	MOVEQ	#0,D0
	LEA	TAGS2(PC),A0
	MOVE.L	_ASLBASE,A6
	JSR	-$30(A6)	; AllocAslRequest.
	MOVE.L	D0,ReqBaseSlot
NOHAYASL2:

	TST.B	AutoCart		; Test hook: Slot 1 cartridge, then GO.
	BEQ.S	NoAutoCart2
	BSR	InsertSl1
	BSR	AutoSlot2		; (4.5) and S2=: Slot 2.
	CMP.L	#"MENU",KEYNOM		; 'AmiMSX <cartridge> MENU': inserted, but
	BNE.S	AutoCartGo		; stay in the menu (the PC tester's
	TST.B	KEYNOM+4		; 'Open in AmiMSX menu'), no key script.
	BNE.S	AutoCartGo
	CLR.B	KEYNOM
	BRA.S	NoAutoCart2
AutoCartGo:
	ST	AutoGo
NoAutoCart2:
	TST.B	KEYNOM			; Test hook: key script from the CLI.
	BEQ.S	NoKeyScrL
	MOVE.L	#KEYNOM,D1
	MOVE.L	#$3ED,D2		; MODE_OLDFILE
	BSR	OPENFILE
	TST.L	D0
	BEQ.S	NoKeyScrL
	MOVE.L	#KeyScr,D2
	MOVE.L	#KEYSCRMAX*8,D3
	BSR	READFILE
	BSR	CLOSEFILE
	CLR.L	KeyFrN
	MOVE.L	#KeyScr,KeyScrPtr
NoKeyScrL:				; (Option records: KeyOptApply, at GO.)
	TST.B	AutoDisk		; Test hook: disk image in drive A, then GO.
	BEQ.S	NoAutoDisk
	SF	AutoDisk
	BSR	LOADVDAuto
	JSR	LoadDiskB		; (4.0) B=<image>: drive B.
	CMP.L	#"MENU",KEYNOM		; (4.0) 'AmiMSX <disk> MENU': the disk is in
	BNE.S	AutoDskGo		; drive A, but stay in the menu (the PC
	TST.B	KEYNOM+4		; tester's 'Open in AmiMSX menu').
	BNE.S	AutoDskGo
	CLR.B	KEYNOM
	BRA.S	NoAutoDisk
AutoDskGo:
	ST	AutoGo
NoAutoDisk:

BUCLEMENU:

; --------------------------
	LEA	DIRPrefs,A5
	MOVEQ	#0,D0
	MOVE.B	$1C(A5),D0
	JSR	COGEMEM
; --------------------------

	LEA	MSX2PUNTS,A1
	BSR.L	CONTROL
QUIT:
	TST.B	MVDMODIFI
	BNE	QUITMVD

	BSR	DISMOUSE
	MOVEM.L	MCEROS,D0-D7/A0-A6
	JSR	OPENQUITWINDOW
	LEA	QUITPUNTS,A1
	JSR	CONTROL			; (4.5: BSR out of range)
	JSR	CLOSEQUITWINDOW
	BSR	ENAMOUSE

	JSR	CLOSEMSX2WINDOW
QUITAR:
	JSR	RtgPlayClose		; (4.5) (none open: nothing)
; --------------------------
; --------------------------		; Screen mode on Exit.
	MOVE.L	4.W,A0			; (4.2) Quitting puts the system's own
	MOVEQ	#0,D1			; beam timing back (ExecBase VBlankFrequency:
	CMP.B	#50,$212(A0)		; 50 = PAL). A 60 Hz MSX game left BEAMCON0
	BNE.S	SysNTSC			; at NTSC, and AmigaOS doesn't restore it:
	MOVE.W	#$20,D1			; PAL screens opened afterwards ran at
SysNTSC:MOVE.W	D1,$DFF1DC		; 59.3 Hz and lost their bottom lines.
; --------------------------
	JSR	CLOSEDOWNSCREEN
	MOVE.L	_INTUITIONBASE,A6	; (4.2) Rebuild the display for the
	JSR	-384(A6)		; restored timing (RemakeDisplay).
	MOVEQ	#0,D0
	RTS
; (4.0) OpenMSX2Window failed: its menus and gadgets may exist without
; the window (CloseMSX2Window would ClearMenuStrip a NULL window).
MSX2WFail:
	TST.L	MSX2Wnd
	BEQ.S	MSX2WF1
	JSR	CLOSEMSX2WINDOW
	BRA	QUITAR
MSX2WF1:MOVE.L	_GadToolsBase,A6
	MOVE.L	MSX2Menus,D0
	BEQ.S	MSX2WF2
	MOVE.L	D0,A0
	JSR	-54(A6)			; FreeMenus
	CLR.L	MSX2Menus
MSX2WF2:MOVE.L	MSX2GList,D0
	BEQ	QUITAR
	MOVE.L	D0,A0
	JSR	-36(A6)			; FreeGadgets
	CLR.L	MSX2GList
	BRA	QUITAR
; ---
QUITMVD:
	BSR	DISMOUSE
	MOVEM.L	MCEROS(PC),D0-D7/A0-A6
	JSR	OPENQUITMVDWINDOW
	LEA	QUITMVDPUNTS,A1
	JSR	CONTROL		; (JSR: past BSR.W's reach)
	JSR	CLOSEQUITMVDWINDOW
	BSR	ENAMOUSE

	JSR	CLOSEMSX2WINDOW
	BRA	QUITAR

; -----------------------------------

	CNOP	0,8
AmiRET:	RTS

; -----------------------------------
	CNOP	0,4
NOQUIT:
	ADD.W	#16+4,SP
	JSR	CLOSEQUITWINDOW
	BSR	ENAMOUSE
	BRA	BUCLEMENU
; ---
	CNOP	0,4
NOQUITMVD:
	ADD.W	#16+4,SP
	JSR	CLOSEQUITMVDWINDOW
	BSR	ENAMOUSE
	BRA	BUCLEMENU
; -----------------------------------
	CNOP	0,4
SETPAL:
	MOVE.W	#$20,$DFF1DC
	RTS
; -----------------------------------
	CNOP	0,4
SETNTSC:
	MOVE.W	#0,$DFF1DC
	RTS
; -----------------------------------
	CNOP	0,4
NeedASL:
	LEA	TLEENOASL,A0
	BSR	IMPERROR
	RTS
; -----------------------------------
	CNOP	0,4
ErPowerON:
	LEA	TLeePowerON(PC),A0
	BSR	IMPERROR
	RTS
; -----------------------------------
	CNOP	0,4
ErCheatDisable:
	LEA	tErNoCheats(PC),A0
	BSR	ImpError
	RTS
; -----------------------------------
	CNOP	0,4
MC68020:
	MOVE.L	$4.w,A0
	MOVE.B	$129(A0),D0
	SMI	EsUn060
	MOVE.B	D0,D1			; (4.4) 68040 or 68060: SCREEN 2/4 tiles
	AND.B	#$88,D1			; by the CPU from caches in fast RAM.
	SNE	CpuTiles
	IFD	CPUTFORCE		; (test builds: -DCPUTFORCE=0 or 1)
	SF	CpuTiles
	IFNE	CPUTFORCE
	ST	CpuTiles
	ENDC
	ENDC
	TST.B	CpuTiles
	BEQ.S	MCNoCpuT
	MOVE.L	#GFXCAF,GfxCaAdr
	MOVE.L	#GFXCA2F,GfxCaAdr+4
	MOVE.L	#GFXCAF,GfxCaPtr
MCNoCpuT:

	AND.B	#$8E,D0
	BNE.S	MC68020RET

	MOVEM.L	MCEROS(PC),D0-D7/A0-A6
	JSR	OPENMC68020WINDOW
	LEA	MC68020PUNTS,A1
	BSR	CONTROL
	JSR	CLOSEMC68020WINDOW
MC68020RET:
	MOVEQ	#-1,D0
	RTS
MC68020SALIR:
	ADD.W	#16+4,SP
	JSR	CLOSEMC68020WINDOW
	MOVEQ	#0,D0
	RTS

; -----------------------------------
	CNOP	0,4
CheckAGA:
	LEA	$DFF000,A6
	MOVE.W	$7C(A6),D1
	MOVE.W	#30-1,D3
BucAGAc2:
	MOVE.W	$7C(A6),D2
	CMP.B	D2,D1
	BNE.s	NoAGAc2
	DBF	D3,BucAGAc2
	ORI.B	#$F0,D1
	CMPI.B	#$F8,D1
	BNE.s	NoAGAc2

	LEA	MSX2GTags,A0
	MOVE.W	#GD_MSX2Spr,D0
	MOVE.L	#$8003000E,D1
	MOVEQ	#0,D2
	BSR	ACTUTAGS
	RTS
NoAGAc2:
	CLR.W	DirPrefs+$16

;	LEA	MSX2GTags,A0
;	MOVE.W	#GD_MSX2Spr,D0
;	MOVE.L	#$8008000F,D1
;	MOVEQ	#0,D2
;	BSR	ACTUTAGS
	RTS
; -----------------------------------
	CNOP	0,4
MiraAGA:
	LEA	$DFF000,A6
	MOVE.W	$7C(A6),D1
	MOVE.W	#30-1,D3
BucAGA2:
	MOVE.W	$7C(A6),D2
	CMP.B	D2,D1
	BNE	NoAGA2
	DBF	D3,BucAGA2
	ORI.B	#$F0,D1
	CMPI.B	#$F8,D1
	BNE.s	NoAGA2
	MOVEQ	#-1,D0
	RTS
NoAGA2:
	MOVEM.L	MCEROS(PC),D0-D7/A0-A6
	JSR	OPENAGAChipWINDOW
	LEA	AGAChipPUNTS,A1
	BSR	CONTROL
	JSR	CLOSEAGAChipWINDOW
AGAChipRET:
	MOVEQ	#-1,D0
	RTS
AGAChipSALIR:
	ADD.W	#16+4,SP
	JSR	CLOSEAGAChipWINDOW
	MOVEQ	#0,D0
	RTS
; -----------------------------------
ABREDEVICE:
	MOVE.L	$4,A6
	SUB.L	A1,A1
	JSR	-$126(A6)
	LEA	DISKPORTI,A0
	MOVE.L	D0,16(A0)
	MOVEQ	#0,D0		; Unidad de disco.
	MOVEQ	#0,D1
	LEA	DISKIOREQI,A1
	MOVE.L	#DISKPORTI,14(A1)
	LEA	MFMDISK2,A0
	MOVE.L	$4,A6
	JSR	-$1BC(A6)	; Abre device.
	TST.L	D0
	SEQ	MFMDEVICE
	BEQ.S	NOERRORMFM

;;	LEA	MSX0GTags,A0
;;	MOVE.W	#GD_DRIVEA,D0
;;	MOVE.L	#$8008000F,D1
;;	MOVEQ	#4,D2
;;	BSR	ACTUTAGS

	MOVEM.L	MCEROS(PC),D0-D7/A0-A6
	JSR	OPENERRORMFMWINDOW
	LEA	ERRORMFMPUNTS,A1
	BSR	CONTROL
	JSR	CLOSEERRORMFMWINDOW
	BSR	ENAMOUSE
	RTS
NOERRORMFM:

;;	LEA	MSX0GTags,A0
;;	MOVE.W	#GD_DRIVEA,D0
;;	MOVE.L	#$8008000F,D1
;;	MOVEQ	#0,D2
;;	BSR	ACTUTAGS

	BSR	ENAMOUSE
	RTS
; -----------------------------------
; -----------------------------------
ShowMatra:
	BSR	DisMouse
	MOVEM.L	MCEROS(PC),D0-D7/A0-A6
	JSR	OPENMatraWINDOW

	move.l  Scr,a0			; Base de la Pantalla.
	move.l  40(a0),a1
	move.w  4(a1),D1
	MOVE.L	MatraWnd,A0		; Base de la Ventana
	MOVE.L	50(A0),A0
	LEA	DatsMatraPic,A1
	MOVE.L	#0,D0			; Coor X Base
	MOVE.L	#11,D1			; Coor Y Base
	MOVE.L	_IntuitionBase,A6
	JSR	-114(A6)		; Imprime Grafico.

	LEA	MatraPunts,A1
	BSR	Control
	JSR	CLOSEMatraWINDOW
	BSR	EnaMouse
	RTS
; -----------------------------------
REINTMODETAGS:				; (GA_Disabled)
	DC.L    $8003000E,1
	DC.L	0
GOCONTOFF:
	LEA	MSX2Gadgets,A0
	ADD.W	#(GD_GO*4),A0
	MOVE.L	(A0),A0
	MOVE.L	MSX2WND,A1
	SUB.L	A2,A2
	LEA	REINTMODETAGS,A3
	MOVE.L	#1,4(A3)
	MOVE.L	_GadToolsBase,A6
	JSR	-$2A(A6)

	LEA	MSX2Gadgets,A0
	ADD.W	#(GD_CONT*4),A0
	MOVE.L	(A0),A0
	MOVE.L	MSX2WND,A1
	SUB.L	A2,A2
	LEA	REINTMODETAGS,A3
	MOVE.L	#1,4(A3)
	MOVE.L	_GadToolsBase,A6
	JSR	-$2A(A6)
	RTS
; -----------------------------------
; -----------------------------------
	CNOP	0,8
MiraSpeed:
	MOVEQ	#0,D1
	MOVEQ	#73,D3
	LEA	$DFF006,A0
	MOVE.W	#$4000,$DFF09A
	MOVE.L	#$80000,D4
	MOVE.B	(A0),D0
sBUC3:	CMP.B	(A0),D0
	BNE.S	sBuc2
	SUBQ.L	#1,D4
	BNE.S	sBUC3
	MOVE.L	#$2000,D1
	BRA.S	sCONT
	CNOP	0,8
sBUC2:	MOVE.B	(A0),D0
sBUC:	ADDQ.L	#1,D1
	CMP.B	(A0),D0
	BEQ.S	sBUC
	DBF	D3,sBUC2
sCONT:	MOVE.W	#$C000,$DFF09A
	MOVE.L	D1,SpeedTest
	RTS
; -----------------------------------
	CNOP	0,4
DiskROMVer:
	LEA	MSX2Gadgets+(GD_DiskVer*4),A0
	MOVE.L	(A0),A1

	CMP.B	#2,$57(A1)
	BEQ.S	DiskROMVerOff

	MOVE.L	#TexDOS,D0
	BTST	#0,$57(A1)
	BEQ.S	EsDosRomC
	MOVE.L	#TexDOS2,D0
EsDosRomC:
	move.l  MSX2Wnd,a0
	lea	MSX2Text9,a1
	MOVE.L	D0,$0C(A1)
	BSR	TxtPrint

	RTS				; (4.6: Slot 2 stays available, InsertSl2Ask)

DiskROMVerOff:
	move.l  MSX2Wnd,a0
	lea	MSX2Text9,a1
	MOVE.L	#MSX2IText9,$0C(A1)
	BSR	TxtPrint

	RTS

TexDOS:	DC.B    'MSX Disk ROM  (DOS)      ',0
TexDOS2:DC.B    'MSX Disk ROM  (DOS2)     ',0
; -----------------------------------
TxtPrint:
	move.l  _IntuitionBase,a6
	move.b  54(a0),d0
	ext.w   d0
	move.b  55(a0),d1
	ext.w   d1
	move.l  50(a0),a0
	jsr     TallIText
	RTS
; -----------------------------------	; D0.l = 0 Off
	CNOP	0,4			; D0.l = 1 On
GadsOnOff:
	MOVE.L	D0,OnOffTAGS+4
	MOVE.L	(A0),A0
	SUB.L	A2,A2
	LEA	OnOffTAGS,A3
	MOVE.L	_GadToolsBase,A6
	JSR	-$2A(A6)
	RTS
	CNOP	0,4
OnOffTAGS:
	DC.L    $8003000E,1
	DC.L	0,0
; -----------------------------------
CanviTags:
	MOVE.L	D0,TAGSCanvi
	MOVE.L	D1,TAGSCanvi+4
	MOVE.L	(A0),A0
	SUB.L	A2,A2
	LEA	TAGSCanvi(PC),A3
	MOVE.L	_GadToolsBase,A6
	JSR	-$2A(A6)
	RTS
	CNOP	0,4
TAGSCanvi:
	DC.L    0,0
	DC.L	0,0
; -----------------------------------

; -----------------------------------
	IFEQ	Key_ON

	CNOP	0,8
LoadKey:
	MOVE.L	#NomKey,D1		; Open File
	MOVE.L	_DosBase,A6
	JSR	-$96(A6)		; LoadSeg
	LSL.L	#2,D0
	MOVE.L	D0,DirKeyFile
	BEQ.S	ReadKeyError

;;	MOVE.L	D0,A0
;;	MOVE.L	#$24216024,$1A(A0)	; Arraglo del STC.

	BSR	DesCriptKey

	JSR	([DirKeyFile.W,PC],$4.W)

	MOVE.L	A0,DirKeyBuff

	BSR.S	AnalizaKey

ReadKeyError:
	RTS

BorraKey:
	MOVE.L	DirKeyFile(PC),D1
	BEQ.S	NoHayKey
	LSR.L	#2,D1
	MOVE.L	_DosBase,A6
	JSR	-$9C(A6)		; UnLoadSeg
NoHayKey:
	RTS

NomKey:	DC.B	"S:AmiMSX2.key",0,0
; -----------------------------------

; -----------------------------------
	CNOP	0,4
AnalizaKey:
	MOVE.L	([DirKeyBuff.W,PC]),A0

	MOVE.L	A0,InfoText1+$C
	BSR	KeySigCero
	MOVE.L	A0,InfoText2+$C
	BSR	KeySigCero
	MOVE.L	A0,InfoText3+$C
	BSR	KeySigCero
	MOVE.L	A0,InfoText4+$C
	BSR	KeySigCero
	MOVE.L	A0,InfoText5+$C
	BSR	KeySigCero
	MOVE.L	A0,InfoText6+$C

	RTS

KeySigCero:
	TST.B	(A0)+
	BNE.S	KeySigCero
	RTS

	ENDC
; -----------------------------------

; -----------------------------------
	CNOP	0,4
MenuPoke:
	IFD	MENU
	TST.B	GoDat(PC)		; �MSX Encendido?
	BEQ	ErPowerON
	ENDC

	TST.B	DisCheaDat(PC)		; �Modo Cheat activo?
	BNE	ErCheatDisable

	BSR	DISMOUSE

	MOVEM.L	MCEROS(PC),D0-D7/A0-A6
	JSR	OPENPokeWINDOW
	LEA	PokePUNTS,A1
	BSR	CONTROL

	MOVE.L	([PokeGadgets+(GD_PokeAddress*4)],$50.w),A0
	MOVE.L	(A0)+,PokeAddressString
	MOVE.W	(A0)+,PokeAddressString+4
	MOVE.L	([PokeGadgets+(GD_PokeValue*4)],$50.w),A0
	MOVE.L	(A0)+,PokeValueString
	MOVE.L	([PokeGadgets+(GD_CheatSeaVal*4)],$50.w),A0
	MOVE.L	(A0)+,CheatSeaValString
	MOVE.L	([PokeGadgets+(GD_CheatComVal*4)],$50.w),A0
	MOVE.L	(A0)+,CheatComValString

	JSR	CLOSEPokeWINDOW
	BSR	ENAMOUSE
	RTS

	CNOP	0,4
DoPoke:

	MOVE.L	([PokeGadgets+(GD_PokeAddress*4)],$50.w),A0
	BSR	CalculPok
	MOVE.L	D0,-(SP)

	MOVE.L	([PokeGadgets+(GD_PokeValue*4)],$50.w),A0
	BSR	CalculPok

	MOVE.L	D0,D1
	MOVE.L	(SP)+,D0

	MOVE.L	D0,A0
	LSR.W	#8,D0
	LSR.B	#6,D0
	LEA	REGS,A3
	MOVE.L	TIPOS(A3,D0.W*8),D2
	BEQ.S	NoInitTipos
	CMP.L	PUNTS(A3,D0.W*8),D2
	BNE	PokeEsROM
	ADD.L	D2,A0
	MOVE.B	D1,(A0)
NoInitTipos:
	RTS

CalculPok:
	TST.B	(A0)
	BNE.S	PokBien
	MOVE.W	#$3000,(A0)
PokBien:
	MOVEQ	#0,D0
PokBuc1:
	TST.B	(A0)
	BEQ.S	PokCon1
	ADDQ	#1,A0
	ADDQ.W	#1,D0
	BRA.S	PokBuc1
PokCon1:
	LEA	BufTxt(PC),A1
	MOVE.L	#"0000",(A1)+
	MOVE.L	#"0000",(A1)+
	MOVE.W	#"00",(A1)+

PokBuc0:
	TST.B	(A0)
	BEQ.S	PokCon0
	CMP.B	#" ",(A0)
	BEQ.S	PokCon0
	MOVE.B	(A0),-(A1)
PokCon0:
	SUBQ	#1,A0
	DBF	D0,PokBuc0

	CMP.B	#"$",(A1)
	BEQ.S	EsHexade

	LEA	BufTxt(PC),A0
	BSR	PASHEX
	BRA	EsDecimal

	CNOP	0,4
EsHexade:
	MOVE.B	#"0",(A1)
	LEA	BufTxt+5(PC),A0

	MOVEQ	#0,D0
	MOVE.B	1(A0),D7
	BSR	Calcul
	MOVE.B	D7,D0
	MOVE.B	2(A0),D7
	BSR	Calcul
	MOVE.B	D7,D1
	MOVE.B	3(A0),D7
	BSR	Calcul
	MOVE.B	D7,D2
	MOVE.B	4(A0),D7
	BSR	Calcul
	MOVE.B	D7,D3
	BFINS	D0,D0{16:4}
	BFINS	D1,D0{20:4}
	BFINS	D2,D0{24:4}
	BFINS	D3,D0{28:4}
EsDecimal:
	RTS

Calcul:
	SUB.B	#"0",D7
	CMP.B	#10,D7
	BLT.S	CalcURet
	SUB.B	#"A"-"9"-1,D7
	CMP.B	#16,D7
	BLT.S	CalcURet
	SUB.B	#"a"-"F"-11,D7
CalcURet:RTS

Calcul2:
	CMP.B	#$A,D2
	BCS.S	NoEsNum
	ADD.B	#"A"-"9"-1,D2
NoEsNum:ADD.B	#"0",D2
	RTS

Calcul3:
	BFEXTU	D1{16:4},D2
	BSR	Calcul2
	MOVE.B	D2,(A2)+
	BFEXTU	D1{20:4},D2
	BSR	Calcul2
	MOVE.B	D2,(A2)+
	BFEXTU	D1{24:4},D2
	BSR	Calcul2
	MOVE.B	D2,(A2)+
	BFEXTU	D1{28:4},D2
	BSR	Calcul2
	MOVE.B	D2,(A2)+
	RTS

Calcul3b:
	BFEXTU	D1{24:4},D2
	BSR	Calcul2
	MOVE.B	D2,(A2)+
	BFEXTU	D1{28:4},D2
	BSR	Calcul2
	MOVE.B	D2,(A2)+
	RTS

PokeEsROM:
	BSR	ENAMOUSE
	LEA	TLeeEsROM,A0
	BSR	IMPERROR
	BSR	DISMOUSE
	RTS

BufTxt:	DS.B	14

; -=-=-

	CNOP	0,8
CheatSearch:
	MOVE.L	PokeWND,A0	; A0=Window
	BSR	PBUSY

	LEA	PokeIText3,A0
	LEA	PokeIText4,A1
	LEA	PokeIText5,A2
	LEA	PokeIText6,A3
PokeIbuc:
	MOVE.B	#" ",(A0)+
	MOVE.B	#" ",(A1)+
	MOVE.B	#" ",(A2)+
	MOVE.B	#" ",(A3)+
	TST.B	(A0)
	BNE.S	PokeIbuc

	LEA	PokeIText3,A0
	MOVE.L	#"Ok! ",(A0)

	LEA	CheatBuf,A0
	MOVE.W	#((8*1024)/4)-1,D0
CheBuc1:CLR.L	(A0)+
	DBF	D0,CheBuc1

	MOVE.L	([PokeGadgets+(GD_CheatSeaVal*4)],$50.w),A0
	BSR	CalculPok

	LEA	CheatBuf,A1
	MOVEQ	#0,D1
	LEA	REGS,A3
CheBuc0:
	MOVE.W	D1,D2
	LSR.W	#8,D2
	LSR.B	#6,D2
	MOVE.L	D1,A0
	ADD.L	TIPOS(A3,D2.W*8),A0
	CMP.B	(A0),D0
	BNE.S	NoEsIgual
	MOVE.W	D1,D2
	LSR.W	#3,D2
	BSET	D1,(A1,D2.W)
NoEsIgual:
	ADDQ.W	#1,D1
	BCC.S	CheBuc0

	move.l	_IntuitionBase,a6
	move.l	PokeWnd,a0
	move.b	54(a0),D0
	move.b	55(a0),D1
	extb.l	D0
	extb.l	D1
	move.l	50(a0),a0
	lea	PokeText3,a1
	jsr     TallIText

	MOVE.L	PokeWND,A0	; A0=Window
	BSR	PNORM
	RTS
; -=-
	CNOP	0,8
CheatCompare:
	CLR.W	CheatDir
CheatMore:
	MOVE.L	PokeWND,A0	; A0=Window
	BSR	PBUSY

	LEA	PokeGadgets+(GD_CheatMore*4),A0
	MOVE.L	PokeWND,A1
	MOVEQ	#1,D0
	BSR	GadsOnOff

	LEA	PokeIText3,A0
	LEA	PokeIText4,A1
	LEA	PokeIText5,A2
	LEA	PokeIText6,A3
PokeIbuc2:
	MOVE.B	#" ",(A0)+
	MOVE.B	#" ",(A1)+
	MOVE.B	#" ",(A2)+
	MOVE.B	#" ",(A3)+
	TST.B	(A0)
	BNE.S	PokeIbuc2

	LEA	PokeIText3,A0
	MOVE.L	#"None",(A0)
	MOVE.B	#".",4(A0)

	MOVE.L	([PokeGadgets+(GD_CheatComVal*4)],$50.w),A0
	BSR	CalculPok

	LEA	CheatBuf,A1
	LEA	PokeIText3,A2
	MOVEQ	#4,D4
	MOVEQ	#8,D3
	LEA	REGS,A3
	MOVEQ	#0,D1
	MOVE.W	CheatDir,D1
CheBuc2:
	MOVE.W	D1,D2
	LSR.W	#8,D2
	LSR.B	#6,D2
	MOVE.L	D1,A0
	ADD.L	TIPOS(A3,D2.W*8),A0
	CMP.B	(A0),D0
	BNE	NoEsIgual2
	MOVE.W	D1,D2
	LSR.W	#3,D2
	BTST	D1,(A1,D2.W)
	BEQ	NoEsIgual2
; -=-
	MOVE.B	#"$",(A2)+

	BSR	Calcul3

	SUBQ.W	#1,D3
	BNE.S	CheFinLin

	ADDQ	#1,A2
	MOVEQ	#8,D3

	SUBQ.W	#1,D4
	BNE.s	NoEsIgual2

	ADDQ.W	#1,D1
	BCS.S	CheatFinal
	MOVE.W	D1,CheatDir

	LEA	PokeGadgets+(GD_CheatMore*4),A0
	MOVE.L	PokeWND,A1
	MOVEQ	#0,D0
	BSR	GadsOnOff

	BRA.S	CheatFinal
CheFinLin:
	MOVE.B	#" ",(A2)+
; -=-
NoEsIgual2:
	ADDQ.W	#1,D1
	BCC.S	CheBuc2

CheatFinal:
	move.l	_IntuitionBase,a6
	move.l	PokeWnd,a0
	move.b	54(a0),D0
	move.b	55(a0),D1
	extb.l	D0
	extb.l	D1
	move.l	50(a0),a0
	lea	PokeText3,a1
	jsr     TallIText

	MOVE.L	PokeWND,A0	; A0=Window
	BSR	PNORM
	RTS

; -----------------------------------
	CNOP	0,4
MenuDebug:
	IFD	MENU
	TST.B	GoDat(PC)
	BEQ	ErPowerON
	ENDC

	TST.B	DisCheaDat(PC)		; �Modo Cheat activo?
	BNE	ErCheatDisable

	BSR	DISMOUSE

	LEA	REGS,A3

	LEA	DebugIText6,A2
	MOVE.W	DEBUG+30,D1	; A
	LSL.W	#8,D1
	MOVE.W	DEBUG+14,D3	; F
	MOVE.B	Flags_Push(A3,D3.W*4),D1
	BSR	CALCUL3
	ADDQ	#6,A2
	MOVE.W	DEBUG+22,D1	; BC
	BSR	CALCUL3
	ADDQ	#5,A2
	MOVE.W	DEBUG+34,D1	; IX
	BSR	CALCUL3
	ADDQ	#4,A2
	MOVE.B	I(A3),D1	; I
	BSR	CALCUL3b

	LEA	DebugIText7,A2
	MOVE.W	DEBUG+18,D1	; HL
	BSR	CALCUL3
	ADDQ	#6,A2
	MOVE.W	DEBUG+26,D1	; DE
	BSR	CALCUL3
	ADDQ	#5,A2
	MOVE.W	DEBUG+38,D1	; IY
	BSR	CALCUL3
	ADDQ	#4,A2
	MOVE.B	R(A3),D1	; R
	BSR	CALCUL3b

	LEA	DebugIText8,A2
	MOVE.W	DEBUG+28,D1	; A
	LSL.W	#8,D1
	MOVE.W	DEBUG+12,D3	; F
	MOVE.B	Flags_Push(A3,D3.W*4),D1
	BSR	CALCUL3
	ADDQ	#6,A2
	MOVE.W	PEXX+2(A3),D1	; BC'
	BSR	CALCUL3
	ADDQ	#5,A2
	MOVE.W	DEBUG+54,D1	; PC
	SUB.W	([DEBUG+60]),D1
	SUBQ.W	#1,D1
	BSR	CALCUL3

	MOVE.W	#"DI",3(A2)
	TST.B	IFF(A3)
	BEQ.S	DebugEsDi
	MOVE.W	#"EI",3(A2)
DebugEsDi:

	LEA	DebugIText9,A2
	MOVE.W	PEXX(A3),D1	; HL'
	BSR	CALCUL3
	ADDQ	#6,A2
	MOVE.W	PEXX+4(A3),D1	; DE'
	BSR	CALCUL3
	ADDQ	#5,A2
	MOVE.W	DEBUG+2,D1	; SP
	BSR	CALCUL3

	LEA	DebugIText9+25,A2
	MOVE.W	DEBUG+14,D3	; F
	MOVE.L	#"    ",(A2)
	LSR.B	#1,D3
	BCC.S	NoFlagC
	MOVE.B	#"C",3(A2)
NoFlagC:LSR.B	#1,D3
	BCC.S	NoFlagZ
	MOVE.B	#"Z",2(A2)
NoFlagZ:LSR.B	#1,D3
	BCC.S	NoFlagV
	MOVE.B	#"V",1(A2)
NoFlagV:LSR.B	#1,D3
	BCC.S	NoFlagS
	MOVE.B	#"S",(A2)
NoFlagS:

; -
	LEA	DebugGTags,A0
	MOVE.W	#GD_DebugScroll,D0
	MOVE.L	#$80080015,D1
	MOVEQ	#0,D2
	MOVE.W	DirMonitor,D2
	LSR.W	#4,D2
	BSR	ACTUTAGS
; -
	MOVE.B	REGS+DA8,D6
	LEA	DebugGTags,A0
	MOVE.L	#$8008000F,D1
	MOVE.W	#GD_DebugPage0,D0
	BFEXTU	D6{30:2},D2
	BSR	ACTUTAGS
	LEA	DebugGTags,A0
	MOVE.W	#GD_DebugPage1,D0
	BFEXTU	D6{28:2},D2
	BSR	ACTUTAGS
	LEA	DebugGTags,A0
	MOVE.W	#GD_DebugPage2,D0
	BFEXTU	D6{26:2},D2
	BSR	ACTUTAGS
	LEA	DebugGTags,A0
	MOVE.W	#GD_DebugPage3,D0
	BFEXTU	D6{24:2},D2
	BSR	ACTUTAGS
; -
	LEA	REGS,A3
	LEA	DebugMap0String,A2
	MOVE.B	#"$",(A2)+
	MOVE.B	DFC(A3),D1
	AND.W	MMAND(A3),D1
	BSR	CALCUL3b
	LEA	DebugMap1String,A2
	MOVE.B	#"$",(A2)+
	MOVE.B	DFD(A3),D1
	AND.W	MMAND(A3),D1
	BSR	CALCUL3b
	LEA	DebugMap2String,A2
	MOVE.B	#"$",(A2)+
	MOVE.B	DFE(A3),D1
	AND.W	MMAND(A3),D1
	BSR	CALCUL3b
	LEA	DebugMap3String,A2
	MOVE.B	#"$",(A2)+
	MOVE.B	DFF(A3),D1
	AND.W	MMAND(A3),D1
	BSR	CALCUL3b
; -

	LEA	PunterosSlot(PC),A1
	MOVE.L	Slot0+0,(A1)+
	MOVE.L	Slot1+0,(A1)+
	MOVE.L	Slot2+0,(A1)+
	MOVE.L	Slot3+0,(A1)+
	MOVE.L	Slot0+8,(A1)+
	MOVE.L	Slot1+8,(A1)+
	MOVE.L	Slot2+8,(A1)+
	MOVE.L	Slot3+8,(A1)+
	MOVE.L	Slot0+16,(A1)+
	MOVE.L	Slot1+16,(A1)+
	MOVE.L	Slot2+16,(A1)+
	MOVE.L	Slot3+16,(A1)+
	MOVE.L	Slot0+24,(A1)+
	MOVE.L	Slot1+24,(A1)+
	MOVE.L	Slot2+24,(A1)+
	MOVE.L	Slot3+24,(A1)+

	LEA	Regs+Punts,A3
	LEA	PunterosPage(PC),A2
	MOVE.L	(A3)+,(A2)+
	ADDQ.W	#04,A3
	MOVE.L	(A3)+,(A2)+
	ADDQ.W	#04,A3
	MOVE.L	(A3)+,(A2)+
	ADDQ.W	#04,A3
	MOVE.L	(A3)+,(A2)+

	MOVE.W	DirMonitor,D3			; Dir Address.
	BSR	PreparaPokes

	MOVEM.L	MCEROS(PC),D0-D7/A0-A6
	JSR	OPENDebugWINDOW
	LEA	DebugPUNTS,A1
	BSR	CONTROL

	MOVE.L	([DebugGadgets+(GD_DebugAddress*4)],$50.w),A0
	MOVE.L	(A0)+,DebugAddressString
	MOVE.W	(A0)+,DebugAddressString+4
	MOVE.L	([DebugGadgets+(GD_DebugFrom*4)],$50.w),A0
	MOVE.L	(A0)+,DebugFromString
	MOVE.W	(A0)+,DebugFromString+4
	MOVE.L	([DebugGadgets+(GD_DebugTo*4)],$50.w),A0
	MOVE.L	(A0)+,DebugToString
	MOVE.W	(A0)+,DebugToString+4

	JSR	CLOSEDebugWINDOW
	BSR	ENAMOUSE
	RTS
; -=-=-
	CNOP	0,4
DebugScroll:
	MOVE.W	DirMonitor,D3			; Dir Address.
	AND.W	#$000F,D3
	MOVE.W	([DebugGadgets+(GD_DebugScroll*4)],$50.w),D0
	LSL.W	#4,D0
	OR.B	D3,D0
	BRA.S	DebugScrollCon
; -=-=-
	CNOP	0,4
DebugAddressIzq:
	SUBQ.W	#1,DirMonitor
	MOVE.W	DirMonitor,D0			; Dir Address.
	BRA.S	DebugScrollCon
; -=-
DebugAddressDer:
	ADDQ.W	#1,DirMonitor
	MOVE.W	DirMonitor,D0			; Dir Address.
	BRA.S	DebugScrollCon
; -=-
DebugAddressArr:
	SUB.W	#16,DirMonitor
	MOVE.W	DirMonitor,D0			; Dir Address.
	BRA.S	DebugScrollCon
; -=-
DebugAddressDeb:
	ADD.W	#16,DirMonitor
	MOVE.W	DirMonitor,D0			; Dir Address.
	BRA.S	DebugScrollCon
; -=-
DebugAddressArr2:
	SUB.W	#160,DirMonitor
	MOVE.W	DirMonitor,D0			; Dir Address.
	BRA.S	DebugScrollCon
; -=-
DebugAddressDeb2:
	ADD.W	#160,DirMonitor
	MOVE.W	DirMonitor,D0			; Dir Address.
	BRA.S	DebugScrollCon
; -=-
DebugAddress:
	MOVE.L	([DebugGadgets+(GD_DebugAddress*4)],$50.w),A0
	BSR	CalculPok
DebugScrollCon:
	AND.L	#$FFFF,D0
	MOVE.W	D0,DirMonitor
	MOVE.L	D0,D3				; Dir Address.
	BSR.S	PreparaPokes
; ---
	LEA	DebugGadgets+(GD_DebugScroll*4),A0
	MOVE.L	DebugWND,A1
	MOVE.L	#$80080015,D0
	MOVEQ	#0,D1
	MOVE.W	DirMonitor,D1
	LSR.W	#4,D1
	BSR	CanviTAGS
; ---
	move.l	_IntuitionBase,a6
	move.l	DebugWnd,a0
	move.b	54(a0),D0
	move.b	55(a0),D1
	extb.l	D0
	extb.l	D1
	move.l	50(a0),a0
	LEA	DebugText11,a1
	jsr     TallIText
	RTS
; -=-=-
	CNOP	0,4
PreparaPokes:
	LEA	DebugIText11,A2
;
	MOVE.W	#(10)-1,D4
PreDEBuc1:
	MOVE.W	#(16)-1,D0
	MOVE.W	D3,D1			; Imp. Address
	BSR	CALCUL3
	ADDQ	#2,A2
	LEA	49(A2),A4
PreDEBuc0:
	MOVE.W	D3,D2
	LSR.W	#8,D2
	LSR.B	#6,D2
	MOVE.L	D3,A0
	ADD.L	(PunterosPage.W,PC,D2.W*4),A0
	MOVE.B	(A0),D1
	BSR	CALCUL3b
	TST.B	D1
	BNE.S	PreDECon0
	ADDQ.B	#1,D1
PreDECon0:
	MOVE.B	D1,(A4)+
	ADDQ.W	#1,D3
	ADDQ	#1,A2
	DBF	D0,PreDEBuc0
	ADD.W	#18,A2
	DBF	D4,PreDEBuc1
	RTS

; -=-=-

ActualizaPokes:
	BSR	DeActuPunts
	MOVE.W	DirMonitor,D0			; Dir Address.
	BRA	DebugScrollCon

; -=-=-

DeActuPunts:

	MOVE.L	([DebugGadgets+(GD_DebugMap0*4)],$50.w),A0
	BSR	CalculPok
	AND.W	Regs+MMAnd,D0
	MOVE.L	(MemoryMapper.L,D0.W*8),PunterosSlot+12

	MOVE.L	([DebugGadgets+(GD_DebugMap1*4)],$50.w),A0
	BSR	CalculPok
	AND.W	Regs+MMAnd,D0
	MOVE.L	(MemoryMapper.L,D0.W*8),PunterosSlot+28
	SUB.L	#$4000,PunterosSlot+28

	MOVE.L	([DebugGadgets+(GD_DebugMap2*4)],$50.w),A0
	BSR	CalculPok
	AND.W	Regs+MMAnd,D0
	MOVE.L	(MemoryMapper.L,D0.W*8),PunterosSlot+44
	SUB.L	#$8000,PunterosSlot+44

	MOVE.L	([DebugGadgets+(GD_DebugMap3*4)],$50.w),A0
	BSR	CalculPok
	AND.W	Regs+MMAnd,D0
	MOVE.L	(MemoryMapper.L,D0.W*8),PunterosSlot+60
	SUB.L	#$C000,PunterosSlot+60

; -=-=-=-

	MOVE.B	([DebugGadgets+(GD_DebugPage0*4)],$57.w),D0
	AND.W	#$0003,D0
	MOVE.L	(PunterosSlot,D0.W*4),PunterosPage

	MOVE.B	([DebugGadgets+(GD_DebugPage1*4)],$57.w),D0
	AND.W	#$0003,D0
	MOVE.L	(PunterosSlot+16,D0.W*4),PunterosPage+4

	MOVE.B	([DebugGadgets+(GD_DebugPage2*4)],$57.w),D0
	AND.W	#$0003,D0
	MOVE.L	(PunterosSlot+32,D0.W*4),PunterosPage+8

	MOVE.B	([DebugGadgets+(GD_DebugPage3*4)],$57.w),D0
	AND.W	#$0003,D0
	MOVE.L	(PunterosSlot+48,D0.W*4),PunterosPage+12

	RTS

	CNOP	0,4
PunterosPage:	DS.L	4
PunterosSlot:	DS.L	4*4
; -=-=-

DebugSaveMem:
	MOVE.L	([DebugGadgets+(GD_DebugTo*4)],$50.w),A0
	BSR	CalculPok
	AND.L	#$FFFF,D0
	MOVE.L	D0,-(SP)
	MOVE.L	([DebugGadgets+(GD_DebugFrom*4)],$50.w),A0
	BSR	CalculPok
	AND.L	#$FFFF,D0
	MOVE.L	(SP)+,D1

	CMP.L	D0,D1
	BGT.S	DebSMCon0
	EXG.L	D0,D1
DebSMCon0:
	MOVE.L	D0,DegugDirFrom
	MOVE.L	D1,DegugDirTo

; ------=====================----------------
	TST.L	_ASLBase(PC)
	BEQ	NeedASL

	BSR	DISMOUSE

	MOVE.L	REQBASEVRam,A0
	LEA	TAGSSaveRam,A1
	MOVE.L	_ASLBASE,A6
	JSR	-$3C(A6)	; RequestFile.

	MOVE.L	D0,-(SP)
	BSR	ENAMOUSE
	MOVE.L	(SP)+,D0

	TST.L	D0
	BEQ	SLCANCEL

	MOVE.L	ReqBaseVram,A2
	BSR	ArreglaNom
; ------=====================----------------

	BSR	OverWrite
	BEQ	NoOverwrite

	MOVE.L	#FILENOM,D1
	MOVE.L	#$3EE,D2
	BSR	OPENFILE
	BEQ	DISERROR

	BSR	DISMOUSE

	LEA	REGS,A3
	MOVE.L	DegugDirFrom,D0
	MOVE.L	DegugDirTo,D1
	MOVE.L	#$0000,D5
	MOVE.L	#$4000,D4
	MOVEQ	#4-1,D6
DeSavMemBuc:
	BSR	CalculSavPag
	BEQ.S	DebugNoSavPag

	MOVEM.L	D0-D6/A3,-(SP)

	MOVE.W	D2,D4
	LSR.W	#8,D4
	LSR.B	#6,D4
	ADD.L	(PunterosPage.W,PC,D4.W*4),D2
	BSR	WRITEFILE

	MOVEM.L	(SP)+,D0-D6/A3

DebugNoSavPag:
	ADD.L	#$4000,D5
	ADD.L	#$4000,D4
	DBF	D6,DeSavMemBuc

	BSR	CLOSEFILE
	BSR	ENAMOUSE
	RTS

CalculSavPag:
	CMP.L	D4,D0
	BGE.S	NoSavPag0

	MOVE.L	D0,D2

	CMP.L	D5,D0
	BGE.S	ConSavPag0
	MOVE.L	D5,D2
ConSavPag0:

	MOVE.L	D4,D3
	SUBQ.L	#1,D3

	CMP.L	D4,D1
	BGE.S	SiSavPag0

	MOVE.L	D1,D3

	CMP.L	D5,D1
	BGE.S	SiSavPag0
NoSavPag0:
	MOVEQ	#0,D3
	RTS
SiSavPag0:
	SUB.L	D2,D3
	ADDQ.L	#1,D3
	RTS

; -----------------------------------
	CNOP	0,4
Addresses:

	LEA	AddressesIText9,A2
	MOVE.L	#DirVRAM,D7		; VRAM
	SWAP	D7
	MOVE.W	D7,D1
	BSR	CALCUL3
	SWAP	D7
	MOVE.W	D7,D1
	BSR	CALCUL3

	LEA	AddressesIText5,A2
	MOVE.L	PunterosPage+0,D7		; Page 0
	SWAP	D7
	MOVE.W	D7,D1
	BSR	CALCUL3
	SWAP	D7
	MOVE.W	D7,D1
	BSR	CALCUL3

	LEA	AddressesIText6,A2
	MOVE.L	PunterosPage+4,D7		; Page 1
	ADD.L	#$4000,D7
	SWAP	D7
	MOVE.W	D7,D1
	BSR	CALCUL3
	SWAP	D7
	MOVE.W	D7,D1
	BSR	CALCUL3

	LEA	AddressesIText7,A2
	MOVE.L	PunterosPage+8,D7		; Page 2
	ADD.L	#$8000,D7
	SWAP	D7
	MOVE.W	D7,D1
	BSR	CALCUL3
	SWAP	D7
	MOVE.W	D7,D1
	BSR	CALCUL3

	LEA	AddressesIText8,A2
	MOVE.L	PunterosPage+12,D7	; Page 3
	ADD.L	#$C000,D7
	SWAP	D7
	MOVE.W	D7,D1
	BSR	CALCUL3
	SWAP	D7
	MOVE.W	D7,D1
	BSR	CALCUL3

	MOVEM.L	MCEROS(PC),D0-D7/A0-A6
	JSR	OPENAddressesWINDOW
	LEA	AddressesPUNTS,A1
	BSR	CONTROL

	JSR	CLOSEAddressesWINDOW
	RTS

; -----------------------------------
	CNOP	0,4
Overwrite:
	TST.B	DirPrefs+$6F(PC)
	BEQ.S	OverwriteOFF
	MOVEQ	#-1,D0
	RTS
OverwriteOFF:
	MOVEM.L	D0-D7/A0-A6,-(SP)

	MOVE.L	#FileNom,D1
	MOVEQ	#-2,D2
	MOVE.L	_DOSBASE,A6
	JSR	-$54(A6)		; Lock
	TST.L	D0
	BNE.S	SiExisteFile
	MOVEM.L	(SP)+,D0-D7/A0-A6
	MOVEQ	#-1,D0
	RTS
SiExisteFile:
	MOVE.L	D0,D1
	JSR	-$5A(A6)		; UnLock

	MOVEM.L	MCEROS(PC),D0-D7/A0-A6
	JSR	OPENOverwriteWINDOW
	LEA	OverwritePUNTS,A1
	BSR	CONTROL
	JSR	CLOSEOverwriteWINDOW
	MOVEM.L	(SP)+,D0-D7/A0-A6
	MOVEQ	#-1,D0
	RTS
OverwriteCancel:
	ADD.W	#16+4,SP
	JSR	CLOSEOverwriteWINDOW
	MOVEM.L	(SP)+,D0-D7/A0-A6
	MOVEQ	#0,D0
	RTS

NoOverwrite:
	BSR	ENAMOUSE
	RTS
; -----------------------------------


; -----------------------------------
; -----------------------------------
; -----------------------------------
; -----------------------------------



; -----------------------------------
	CNOP	0,4
UnProtect:
	BSR	DisMouse
	MOVEM.L	MCeros(PC),D0-D7/A0-A6
	JSR	OpenUnProtectWindow

	LEA	UnProtectPunts,A1
	BSR	Control

	OR.B	#$01,Debug+(3*4)+3		; Activa Flag C
	SF	Debug+(7*4)+3			; Pone a 0 D7

	JSR	CloseUnProtectWindow
	BSR	EnaMouse
	RTS

EsUnProtect:
	ADD.W	#16+4,SP

	SUBQ.L	#3,Debug+((8+5)*4)		; Registro PC.

	MOVE.L	#MN_WProt,D0
	BSR	COGECHECK
	BCLR	#0,$C(A0)		; MVD: Write UnProtected

	JSR	CloseUnProtectWindow
	BSR	EnaMouse
	RTS
; -----------------------------------

; -----------------------------------
	CNOP	0,4
ABOUT:
	BSR	DISMOUSE
	MOVEM.L	MCEROS(PC),D0-D7/A0-A6
	JSR	OPENABOUTWINDOW
	TST.L	D0			; (4.0) Window not open: no gadgets.
	BNE.S	ABOUTNoW
	LEA	ABOUTPUNTS,A1
	BSR	CONTROL
ABOUTNoW:
	JSR	CLOSEABOUTWINDOW
	BSR	ENAMOUSE
	RTS
; -----------------------------------
	CNOP	0,4
NoCartrID:
	BSR	DISMOUSE
	MOVEM.L	MCEROS(PC),D0-D7/A0-A6
	JSR	OPENCartNotIDWINDOW
	LEA	CartNotIDPUNTS,A1
	BSR	CONTROL
	JSR	CLOSECartNotIDWINDOW
	BSR	ENAMOUSE
	MOVEQ	#0,D0
	RTS
NoCartrIDSet:
	MOVE.W	#"AB",([DirCart])
NoCartrIDIgnore:
	ADD.W	#16+4,SP
	JSR	CLOSECartNotIDWINDOW
	BSR	ENAMOUSE
	MOVEQ	#-1,D0
	RTS
; -----------------------------------
	CNOP	0,4
MIRAMVDSA:
	TST.B	MVDMODIFI
	BNE.S	MIRAMVDSAC
	RTS
MIRAMVDSAC:
	BSR	DISMOUSE
	MOVEM.L	MCEROS(PC),D0-D7/A0-A6
	JSR	OPENDELMVDWINDOW
	LEA	DELMVDPUNTS,A1
	BSR	CONTROL
	JSR	CLOSEDELMVDWINDOW
	BSR	ENAMOUSE
	RTS
NODELMVD:
	ADD.W	#16+4,SP
	JSR	CLOSEDELMVDWINDOW
	BSR	ENAMOUSE
	ADD.W	#4,SP
	RTS
; -----------------------------------

; -----------------------------------
; -----------------------------------

; -----------------------------------
	CNOP	0,4
InitLoadTape:
	MOVE.L	DirCaset,LoadCaset
	MOVE.W	BucCaset,SizeCaset
	ST	ModoCaset
	RTS
; -----------------------------------
	CNOP	0,4
InitSaveTape:
	MOVE.L	DirCaset,SaveCaset
	CLR.W	BucCaset
	CLR.W	SizeCaset
	SF	ModoCaset

	MOVE.L	#MN_RewindTape,D0
	BSR	COGECHECK
	AND.W	#$FFEF,$C(A0)

	MOVE.L	#MN_SaveRec,D0
	BSR	COGECHECK
	OR.W	#$0010,$C(A0)
	RTS
; -----------------------------------
	CNOP	0,4
LoadTape:
	IFND	MENU
	RTS				; Desde el Menu No funciona.
	ENDC

	TST.L	_ASLBase(PC)
	BEQ	NeedASL

	BSR	DISMOUSE

	MOVE.L	REQBASETape,A0
	LEA	TAGSLoadTape,A1
	MOVE.L	_ASLBASE,A6
	JSR	-$3C(A6)	; RequestFile.

	MOVE.L	D0,-(SP)
	BSR	ENAMOUSE
	MOVE.L	(SP)+,D0

	TST.L	D0
	BEQ	SLCANCEL


	MOVE.L	ReqBaseTape,A2
	BSR	ArreglaNom


	MOVE.L	#FILENOM,D1
	MOVE.L	#$3ED,D2
	BSR	OPENFILE
	BEQ	DISERROR

	MOVE.L	#FileNom,D1
	BSR	LONGFILE
	MOVE.L	D0,TapeBUCFILE
	BEQ	DISERROR2

	MOVE.L	#(4*3),D3
	MOVE.L	#IDTapeBuf,D2
	BSR	READFILE

	LEA	TLeeNoTape,A0
	LEA	IDTapeBuf,A1
	CMP.L	#"MSX2",(A1)+
	BNE	ImpError
	CMP.L	#"Tape",(A1)+
	BNE	ImpError
	CMP.L	#"v1.0",(A1)+
	BNE	ImpError
	
	BSR	DISMOUSE

	LEA	TLoadTape2,A0
	BSR	IMPDISK

	MOVE.L	TapeBucFile,D3
	SUB.L	#(3*4),D3
	MOVE.W	D3,BucCaset
	MOVE.L	DirCaset,D2
	BSR	READFILE

	move.l  LOADDECWnd,a0
	BSR	PNORM
	JSR	CLOSELOADDECWINDOW

	BSR	CLOSEFILE
	BSR	ENAMOUSE

	MOVE.L	DirCaset,LoadCaset
	MOVE.W	BucCaset,SizeCaset
	ST	ModoCaset

	MOVE.L	#MN_RewindTape,D0
	BSR	COGECHECK
	OR.W	#$0010,$C(A0)

	MOVE.L	#MN_SaveRec,D0
	BSR	COGECHECK
	AND.W	#$FFEF,$C(A0)
	RTS
	CNOP	0,4
IDTapeBuf:DS.L	4
; -----------------------------------
	CNOP	0,4
SaveTape:
	TST.W	SizeCaset(PC)
	BNE.S	SiSaveTape

	LEA	TLeeNoTapeBuf,A0
	JMP	IMPERROR

SiSaveTape:
	TST.L	_ASLBase(PC)
	BEQ	NeedASL

	BSR	DISMOUSE

	MOVE.L	REQBASETape,A0
	LEA	TAGSSaveTape,A1
	MOVE.L	_ASLBASE,A6
	JSR	-$3C(A6)	; RequestFile.

	MOVE.L	D0,-(SP)
	BSR	ENAMOUSE
	MOVE.L	(SP)+,D0

	TST.L	D0
	BEQ	SLCANCEL


	MOVE.L	ReqBaseTape,A2
	BSR	ArreglaNom

	BSR	OverWrite
	BEQ	NoOverwrite

	MOVE.L	#FILENOM,D1
	MOVE.L	#$3EE,D2
	BSR	OPENFILE
	BEQ	DISERROR

	BSR	DISMOUSE

	LEA	TSaveTape2,A0
	BSR	IMPDISK

	MOVE.L	#(4*3),D3
	MOVE.L	#IDTape,D2
	BSR	WRITEFILE

	MOVEQ	#0,D3
	MOVE.W	SizeCaset,D3
	MOVE.L	DirCaset,D2
	BSR	WRITEFILE

	move.l  LOADDECWnd,a0
	BSR	PNORM
	JSR	CLOSELOADDECWINDOW

	BSR	CLOSEFILE
	BSR	ENAMOUSE
	RTS
	CNOP	0,4
IDTape:	DC.L	"MSX2"
	DC.L	"Tape"
	DC.L	"v1.0"
	DC.L	0
; -----------------------------------

	CNOP	0,8
Sl1MapOp0:
	SF	DirPrefs+$76
	MOVEQ	#$01,D3
	BRA.S	Sl1MapRut
Sl1MapOp1:
	MOVE.B	#$01,DirPrefs+$76
	MOVEQ	#$02,D3
	BRA.S	Sl1MapRut
Sl1MapOp2:
	MOVE.B	#$02,DirPrefs+$76
	MOVEQ	#$04,D3
	BRA.S	Sl1MapRut
Sl1MapOp3:
	MOVE.B	#$03,DirPrefs+$76
	MOVEQ	#$08,D3
	BRA.S	Sl1MapRut
Sl1MapOp4:
	MOVE.B	#$04,DirPrefs+$76
	MOVEQ	#$10,D3
	BRA.S	Sl1MapRut
Sl1MapOp5:
	MOVE.B	#$05,DirPrefs+$76
	MOVEQ	#$20,D3
	BRA.S	Sl1MapRut
Sl1MapOp6:
	MOVE.B	#$06,DirPrefs+$76
	MOVEQ	#$40,D3
	BRA.S	Sl1MapRut
Sl1MapOp7:				; (4.5) R-Type
	MOVE.B	#$07,DirPrefs+$76
	MOVE.L	#$80,D3
Sl1MapRut:
	MOVE.L	#MN_Map1None,D0		; the first of its sub-items
	MOVEQ	#NS_Map1-1,D4		; (4.5: 8 items, R-Type)

	BRA.S	PoneOptMenus



	CNOP	0,8
Sl2MapOp0:
	SF	DirPrefs+$77
	MOVEQ	#$01,D3
	BRA.S	Sl2MapRut
Sl2MapOp1:
	MOVE.B	#$01,DirPrefs+$77
	MOVEQ	#$02,D3
	BRA.S	Sl2MapRut
Sl2MapOp2:
	MOVE.B	#$02,DirPrefs+$77
	MOVEQ	#$04,D3
	BRA.S	Sl2MapRut
Sl2MapOp3:
	MOVE.B	#$03,DirPrefs+$77
	MOVEQ	#$08,D3
	BRA.S	Sl2MapRut
Sl2MapOp4:
	MOVE.B	#$04,DirPrefs+$77
	MOVEQ	#$10,D3
	BRA.S	Sl2MapRut
Sl2MapOp5:
	MOVE.B	#$05,DirPrefs+$77
	MOVEQ	#$20,D3
	BRA.S	Sl2MapRut
Sl2MapOp6:
	MOVE.B	#$06,DirPrefs+$77
	MOVEQ	#$40,D3
	BRA.S	Sl2MapRut
Sl2MapOp7:				; (4.5) R-Type
	MOVE.B	#$07,DirPrefs+$77
	MOVE.L	#$80,D3
Sl2MapRut:
	MOVE.L	#MN_Map2None,D0		; the first of its sub-items
	MOVEQ	#NS_Map2-1,D4		; (4.5: 8 items, R-Type)

	NOP			; was: BRA.S	PoneOptMenus (zero-length short branch)

; -----------------------------------

; -----------------------------------


PoneOptMenus:
;;	MOVEQ	#$40,D3			; D3 = Bits a 0 = OFF, bit a 1 = ON
;;	MOVE.L	#(0*$40)+1,D0		; D0 = N� L�nea. (Sub-Item+Item)
;;	MOVEQ	#3,D1			; D1 = N� menu.
;;	MOVEQ	#7-1,D4			; D4 = N� de L�neas en Men�
PoOpMeBuc:
	MOVEM.L	D0-D4,-(SP)
	BSR	COGECHECK
	MOVEM.L	(SP)+,D0-D4

	BCLR	#0,$C(A0)
	LSR.B	#1,D3
	BCC.S	PoOpMeCon
	BSET	#0,$C(A0)
PoOpMeCon:
	ADD.W	#(1<<11),D0		; the next sub-item
	DBF	D4,PoOpMeBuc
	RTS

; -----------------------------------


; -----------------------------------
; -----------------------------------

	CNOP	0,8
SaveMappID1:
	MOVEQ	#0,D0
	MOVE.B	DirPrefs+$76(PC),D0
	MOVE.L	CheckIdS1,MapperNuevo
	MOVE.L	BucCartS1,BucCart
	BRA.S	SaveMappID

SaveMappID2:
	MOVEQ	#0,D0
	MOVE.B	DirPrefs+$77(PC),D0
	MOVE.L	CheckIdS2,MapperNuevo
	MOVE.L	BucCartS2,BucCart

SaveMappID:
	MOVE.L	DirPrefs+$8,MapperIDInit+$14	; Usuario Reg.

	CMP.L	#($2080*5),BucCart	; �Es mayor de 40Kb?
	BCC.S	SaveMappIdRut
	RTS

SaveMappIdRut:
	MOVE.L	MapperNuevo,CheckId
	SUBQ.B	#1,D0
	BMI	AmiRET
	ROR.L	#3,D0
	OR.L	MapperNuevo,D0
	MOVE.L	D0,MapperNuevo

	BSR	MiConMapper

	TST.B	SiNewMapp(PC)
	BNE.S	SiNewMapp2

	MOVE.L	MapperNuevo,D0
	CMP.L	(A0),D0
	BNE.S	NoNewMappModi
	RTS
NoNewMappModi:
	MOVE.L	D0,(A0)
SiNewMapp2:

	LEA	tErNoMasMapper,A0
	CMP.W	#-1,MapperIDInit+$10		; �M�ximo de mappers?
	BEQ	ImpError

	MOVE.L	#AmiMSX2mapper,D1
	MOVE.L	#$3EE,D2
	BSR	OpenFile
	BEQ	NoAmiSavMapp

	TST.B	SiNewMapp(PC)
	BEQ.S	NoNewMapp2
	ADDQ.W	#1,MapperIdInit+$10		; Suma un Mapper m�s.
NoNewMapp2:
	MOVE.L	#MapperIdInit,D2		; Graba Cabezera.
	MOVE.L	#($18),D3
	BSR	WriteFile

	MOVE.L	DirMapper,D2			; Graba mappers
	MOVE.L	BucMapper,D3
	BSR	WriteFile

	TST.B	SiNewMapp(PC)
	BEQ.S	NoNewMapp

	MOVE.L	#MapperNuevo,D2			; Graba Nuevo mapper ID.
	MOVE.L	#($4),D3
	BSR	WriteFile
NoNewMapp:
	BSR	CloseFile

	BSR	LoadMapperId

NoAmiSavMapp:
	RTS

MapperNuevo:	DC.L	0

; -----------------------------------
; -----------------------------------




; -----------------------------------




; -----------------------------------

	CNOP	0,8
EjectSl1:
	MOVE.L	#MN_Sl1Eject,D0
	BSR	COGECHECK
	AND.W	#$FFEF,$C(A0)

	LEA	TNOFile,A0
	LEA	MSX2IText8,a1		; Slot 1 texo.
	BSR	PONOM

	MOVE.L	MSX2Wnd,a0
	LEA	MSX2Text8,a1		; Slot 1 texo.
	BSR	TxtPrint

	MOVE.L	DirCartS1(PC),DirCart
	MOVE.L	BucCartS1(PC),BucCart
	MOVE.L	BucCartAddS1(PC),BucCartAdd
	CLR.L	DirCartS1
	CLR.L	BucCartS1
	CLR.W	PagCartS1
	CLR.L	CheckIdS1
	ST	Slot1Cart
	TST.B	GPActive		; (4.0) The cartridge's own settings go
	BEQ.S	Eject			; with it (Space Manbow's SCC stayed for
	BSR	GPRestore		; a disk game loaded next: Bombaman).
	BRA.S	Eject
EjectSl2:
	MOVE.L	#MN_Sl2Eject,D0
	BSR	COGECHECK
	AND.W	#$FFEF,$C(A0)

	LEA	TNOFile,A0
	LEA	MSX2IText9,a1		; Slot 2 texo.
	BSR	PONOM

	MOVE.L	MSX2Wnd,a0
	LEA	MSX2Text9,a1		; Slot 2 texo.
	BSR	TxtPrint

	MOVE.L	DirCartS2(PC),DirCart
	MOVE.L	BucCartS2(PC),BucCart
	MOVE.L	BucCartAddS2(PC),BucCartAdd
	CLR.L	DirCartS2
	CLR.L	BucCartS2
	CLR.W	PagCartS2
	CLR.L	CheckIdS2
	ST	Slot2Cart
Eject:
	MOVE.L	BucCart(PC),D0
	BEQ.S	NoHayCartEj
	ADD.L	BucCartAdd(PC),D0
	MOVE.L	DirCart(PC),A1
	MOVE.L	$4.W,A6
	JSR	-$D2(A6)		; Libera memoria.
	CLR.L	BucCart
NoHayCartEj:
	RTS

; -----------------------------------

	CNOP	0,8
InsertSl1:
	MOVE.L	#MSX2IText8,DatTxt
	MOVE.L	#MN_Sl1Eject,DatItem

	MOVE.L	DirCartS1(PC),DirCart
	MOVE.L	BucCartS1(PC),BucCart
	MOVE.L	BucCartAddS1(PC),BucCartAdd2
	MOVE.W	PagCartS1(PC),PagCart
	MOVE.L	#Slot1Cart,SlotxCart

	SF	CartLoadOK
	BSR	Insert

	BSR	MiraCheckCart
	ADDQ.B	#1,D0
	MOVE.B	D0,DirPrefs+$76
	MOVEQ	#1,D3
	LSL.W	D0,D3
	BSR	Sl1MapRut

	MOVE.L	DirCart(PC),DirCartS1
	MOVE.L	BucCart(PC),BucCartS1
	MOVE.L	BucCartAdd(PC),BucCartAddS1
	MOVE.W	PagCart(PC),PagCartS1
	MOVE.L	CheckId(PC),CheckIdS1
	JSR	FlashLoad		; (4.0) a flash cartridge's saved sectors
	JSR	SramLoad		; (4.4) and an SRAM cartridge's SRAM
	TST.B	CartLoadOK		; The cartridge's own settings, if it
	BEQ.S	InsSl1NoGP		; has any (GPLoad).
	BSR	GPLoad
InsSl1NoGP:
	RTS

; ---------------------------------------------------------------------
; Per-game settings (4.0). A file next to the Slot 1 cartridge, named after
; it plus ".prefs" (Lilly.rom.prefs), holds the settings that make sense per
; game: "AMXG", version 1, sound chip (DirPrefs+$1D), MSX2 sprites
; (DirPrefs+$16), sprite collisions (DirPrefs+$6C), mask screen edges
; (PrefMask: 0, 8 or 16 dots since 4.2; FFh in older files = 8), audio
; filter, a byte that was 4.0-4.1's auto mask (written 0 and ignored since
; 4.2) and (4.1.1, bytes 12-13) the CD32 pad setting of each joystick port,
; and (4.4, byte 14) the machine (DirPrefs+$10; byte 15 is FFh). Inserting a cartridge applies its
; file (GUI included, as GO copies the GUI over DirPrefs); a cartridge
; without one brings the global settings back, with the SCC sound chip
; for a Konami SCC cartridge and (4.4) the ROM database's machine for an
; MSX2, MSX2+ or turbo R game (RomDbMach; per-game defaults). Save Prefs always writes the global
; settings. A 4.0/4.1 file is 12 bytes: the pad bytes read as 0
; (Standard); a 4.1.1-4.3 file is 14: the machine is left as it is.
GP_LEN=16
GP_LEN41=12				; A 4.0/4.1 file's length.

; DirPrefs -> the 12-byte block at A1, and back.
GPFromPrefs:
	MOVE.L	#"AMXG",(A1)
	MOVE.B	#1,4(A1)
	MOVE.B	DirPrefs+$1D,5(A1)
	MOVE.W	DirPrefs+$16,6(A1)
	MOVE.B	DirPrefs+$6C,8(A1)
	MOVE.B	PrefMask,9(A1)
	MOVE.B	PrefFilter,10(A1)
	CLR.B	11(A1)			; (4.0-4.1 auto mask: unused since 4.2)
	MOVE.B	PrefCD32,12(A1)		; (4.1.1; 0 in older files: Standard)
	MOVE.B	PrefCD32M,13(A1)
	MOVE.B	DirPrefs+$10,14(A1)	; (4.4) the machine
	ST	15(A1)
	RTS
GPToPrefs:
	MOVE.B	5(A1),DirPrefs+$1D
	MOVE.W	6(A1),DirPrefs+$16
	MOVE.B	8(A1),DirPrefs+$6C
	MOVE.B	9(A1),PrefMask
	BSR	MaskNorm		; (an older file's FFh = 8 dots)
	MOVE.B	10(A1),PrefFilter
	MOVE.B	12(A1),PrefCD32
	MOVE.B	13(A1),PrefCD32M
	CMP.B	#$FF,14(A1)		; (4.4) the machine, unless FFh (a file
	BEQ.S	GPToP1			; from before 4.4)
	MOVE.B	14(A1),DirPrefs+$10
GPToP1:	RTS

; Those settings from the GUI into DirPrefs (ACTUPREFS for just these: all
; of ACTUPREFS also rewrote the Slot 1 mapper the load had just set, and
; Nemesis 2 boot-looped).
GPGUIToPrefs:
	MOVE.B	([MSX2Gadgets+(GD_ROM*4)],$57.w),DirPrefs+$10	; (4.4)
	MOVE.B	([MSX2Gadgets+(GD_Sound*4)],$57.w),DirPrefs+$1D
	MOVE.W	([MSX2Gadgets+(GD_MSX2Spr*4)],$56.w),DirPrefs+$16
	SF	DirPrefs+$6C		; ('Collisions always': gone in 4.0.)
	BSR	MaskFromGUI		; Mask screen edges (4.2: 3 sub-items).
	MOVE.L	#MN_Filter,D0		; Audio filter.
	BSR	COGECHECK
	SNE	PrefFilter
	MOVE.L	#MN_Pad2CD32,D0		; JoyPort 2 pad: CD32 pad (4.1.1).
	BSR	COGECHECK
	SNE	PrefCD32
	MOVE.L	#MN_Pad1CD32,D0		; JoyPort 1 pad.
	BSR	COGECHECK
	SNE	PrefCD32M
	RTS

; The GUI from DirPrefs for those settings (gadgets and menu checkmarks).
GPShowGUI:
	LEA	MSX2Gadgets+(GD_ROM*4),A0	; (4.4) the machine
	MOVE.L	MSX2WND,A1
	MOVE.L	#$8008000F,D0
	MOVEQ	#0,D1
	MOVE.B	DirPrefs+$10,D1
	BSR	CanviTags
	LEA	MSX2Gadgets+(GD_SOUND*4),A0
	MOVE.L	MSX2WND,A1
	MOVE.L	#$8008000F,D0
	MOVEQ	#0,D1
	MOVE.B	DirPrefs+$1D,D1
	BSR	CanviTags
	LEA	MSX2Gadgets+(GD_MSX2Spr*4),A0
	MOVE.L	MSX2WND,A1
	MOVE.L	#$8008000F,D0
	MOVEQ	#0,D1
	MOVE.W	DirPrefs+$16,D1
	BSR	CanviTags
	MOVE.L	#MN_MaskOff,D0		; Mask screen edges (4.2): Off,
					; 8 dots or 16 dots ticked.
	BSR	COGECHECK
	BCLR	#0,$C(A0)
	TST.B	PrefMask
	BNE.S	GPShow2
	BSET	#0,$C(A0)
GPShow2:
	MOVE.L	#MN_Mask8,D0
	BSR	COGECHECK
	BCLR	#0,$C(A0)
	CMP.B	#8,PrefMask
	BNE.S	GPShow2b
	BSET	#0,$C(A0)
GPShow2b:
	MOVE.L	#MN_Mask16,D0
	BSR	COGECHECK
	BCLR	#0,$C(A0)
	CMP.B	#16,PrefMask
	BNE.S	GPShow2c
	BSET	#0,$C(A0)
GPShow2c:
	MOVE.L	#MN_Filter,D0		; Audio filter.
	BSR	COGECHECK
	BCLR	#0,$C(A0)
	TST.B	PrefFilter
	BEQ.S	GPShow4
	BSET	#0,$C(A0)
GPShow4:
	MOVEM.L	D2/D3,-(SP)
	MOVE.L	#MN_Pad2Std,D2		; JoyPort 2 pad (4.1.1): one of its
	MOVE.B	PrefCD32,D3		; two sub-items ticked.
	BSR	GPShowPad
	MOVE.L	#MN_Pad1Std,D2		; JoyPort 1 pad.
	MOVE.B	PrefCD32M,D3
	BSR	GPShowPad
	MOVEM.L	(SP)+,D2/D3
	RTS
; (4.6) Emulation > Speed from the menu: prefs $7E, 0 Normal, 1 Overclock,
; 2 No Limit.
SpeedFromGUI:
	CLR.B	DIRPrefs+$7E
	MOVE.L	#MN_SpeedOC,D0
	BSR	COGECHECK
	BEQ.S	SpeedFG1
	MOVE.B	#1,DIRPrefs+$7E
SpeedFG1:
	MOVE.L	#MN_SpeedNoLimit,D0
	BSR	COGECHECK
	BEQ.S	SpeedFG2
	MOVE.B	#2,DIRPrefs+$7E
SpeedFG2:
	RTS
; (4.2) Mask screen edges from the menu: sub-item 4 of item 15 = 8 dots,
; 5 = 16 dots, else (3) Off.
MaskFromGUI:
	CLR.B	PrefMask
	MOVE.L	#MN_Mask8,D0
	BSR	COGECHECK
	BEQ.S	MaskFG1
	MOVE.B	#8,PrefMask
MaskFG1:
	MOVE.L	#MN_Mask16,D0
	BSR	COGECHECK
	BEQ.S	MaskFG2
	MOVE.B	#16,PrefMask
MaskFG2:
	RTS
; (4.2) PrefMask as 0, 8 or 16 (dots each side): an older prefs or per-game
; file's FFh (4.0-4.1 'Mask screen edges (always)') reads as 8.
MaskNorm:
	TST.B	PrefMask
	BEQ.S	MaskNormR
	CMP.B	#16,PrefMask
	BEQ.S	MaskNormR
	MOVE.B	#8,PrefMask
MaskNormR:
	RTS
; D2 = a pad's Standard sub-item: the CD32 pad sub-item after it ticked when
; D3 is not 0, Standard otherwise.
GPShowPad:
	MOVE.L	D2,D0
	ADD.W	#MN_Pad2CD32-MN_Pad2Std,D0
	BSR	COGECHECK
	BCLR	#0,$C(A0)
	TST.B	D3
	BEQ.S	GPShowPad1
	BSET	#0,$C(A0)
GPShowPad1:
	MOVE.L	D2,D0
	BSR	COGECHECK
	BSET	#0,$C(A0)
	TST.B	D3
	BEQ.S	GPShowPad2
	BCLR	#0,$C(A0)
GPShowPad2:
	RTS

; GPName = FILENOM + ".prefs".
GPBuild:
	LEA	FILENOM,A0
	LEA	GPName,A1
	MOVE.W	#$200-1,D0
GPBuild1:
	MOVE.B	(A0)+,(A1)+
	DBEQ	D0,GPBuild1
	SUBQ.W	#1,A1
	LEA	GPExt(PC),A0
GPBuild2:
	MOVE.B	(A0)+,(A1)+
	BNE.S	GPBuild2
	RTS

GPLoad:
	BSR	GPBuild
	MOVE.L	#GPName,D1
	MOVE.L	#1005,D2
	BSR	OPENFILE
	BEQ.S	GPLoadNone
	CLR.W	GPBuf+12		; (4.1.1) The pad bytes: 0 unless the
	MOVE.W	#$FFFF,GPBuf+14		; file has them; (4.4) the machine: FFh
	MOVE.L	#GPBuf,D2		; (keep) unless it has it.
	MOVEQ	#GP_LEN,D3
	BSR	READFILE
	CMP.L	#GP_LEN41,D0		; A 12-byte (4.0/4.1) file is fine too.
	SCC	GPOk
	BSR	CLOSEFILE
	TST.B	GPOk
	BEQ.S	GPLoadNone
	CMP.L	#"AMXG",GPBuf
	BNE.S	GPLoadNone
	TST.B	GPActive		; Keep the global settings aside (once).
	BNE.S	GPLoadSet
	BSR	GPGUIToPrefs
	LEA	GPSaved,A1
	BSR	GPFromPrefs
	ST	GPActive
GPLoadSet:
	LEA	GPBuf,A1
	BSR	GPToPrefs
	BRA	GPShowGUI
GPLoadNone:
	MOVE.B	RomDbMach,D0		; (4.4) No game file: an MSX2/MSX2+/turbo
	BEQ.S	GPNoMach		; R game in the ROM database gets that
	TST.B	GPActive		; machine over the global settings (MSX1
	BNE.S	GPMach1			; games and unknown ones keep them).
	BSR	GPGUIToPrefs
	LEA	GPSaved,A1
	BSR	GPFromPrefs
	ST	GPActive
GPMach1:LEA	GPSaved,A1
	BSR	GPToPrefs
	MOVE.B	RomDbMach,D0		; (D0 went in the calls above)
	BSR	GDMach
	CMP.B	#5,DirPrefs+$76		; (and the SCC rule below)
	BCS	GPShowGUI
	CMP.B	#6,DirPrefs+$76
	BHI	GPShowGUI
	TST.B	DirPrefs+$1D
	BEQ.S	GPMach2
	CMP.B	#3,DirPrefs+$1D
	BCS	GPShowGUI
GPMach2:MOVE.B	#1,DirPrefs+$1D
	BRA	GPShowGUI
; (4.4) D0 = the database's machine (1 MSX2, 2 MSX2+, 3 turbo R: MSX2+, the
; nearest AmiMSX has) into DirPrefs+$10.
GDMach:	CMP.B	#3,D0
	BCS.S	GDMach1
	MOVEQ	#2,D0
GDMach1:MOVE.B	D0,DirPrefs+$10
	RTS
GPNoMach:
	CMP.B	#5,DirPrefs+$76		; No game file, but a Konami SCC mapper
	BCS.S	GPNoScc			; (5 = SCC 1, 6 = SCC 2): the global
	CMP.B	#6,DirPrefs+$76		; settings with the SCC sound chip, if
	BHI.S	GPNoScc			; they have the PSG or PSG+FM (SCC+
					; is kept).
	TST.B	GPActive
	BNE.S	GPScc1
	BSR	GPGUIToPrefs
	LEA	GPSaved,A1
	BSR	GPFromPrefs
	ST	GPActive
GPScc1:	LEA	GPSaved,A1
	BSR	GPToPrefs
	TST.B	DirPrefs+$1D
	BEQ.S	GPScc3
	CMP.B	#3,DirPrefs+$1D
	BCS.S	GPScc2			; (3, 4: PSG+FM, lite)
GPScc3:	MOVE.B	#1,DirPrefs+$1D
GPScc2:	BRA	GPShowGUI
GPNoScc:
	TST.B	GPActive		; None: the global settings again.
	BEQ.S	GPLoadRet
GPRestore:
	LEA	GPSaved,A1
	BSR	GPToPrefs
	SF	GPActive
	BRA	GPShowGUI
GPLoadRet:
	RTS

GameSave:
	TST.L	DirCartS1
	BEQ.S	GPNoCart
	BSR	GPGUIToPrefs
	TST.B	GPActive		; Not yet a game's: these are the global
	BNE.S	GameSave1		; settings, kept for the next cartridge.
	LEA	GPSaved,A1
	BSR	GPFromPrefs
	ST	GPActive
GameSave1:
	LEA	GPBuf,A1
	BSR	GPFromPrefs
	BSR	GPBuild
	MOVE.L	#GPName,D1
	MOVE.L	#1006,D2
	BSR	OPENFILE
	BEQ.S	GPWriteErr
	MOVE.L	#GPBuf,D2
	MOVEQ	#GP_LEN,D3
	BSR	WRITEFILE
	SNE	GPOk
	BSR	CLOSEFILE
	TST.B	GPOk
	BNE.S	GPWriteErr2
	RTS
GPWriteErr:
	LEA	TGPWRITE,A0
	BRA	IMPERROR
GPWriteErr2:
	LEA	TGPWRITE,A0
	BRA	IMPERROR
GPNoCart:
	LEA	TGPNOCART,A0
	BRA	IMPERROR

GameForget:
	TST.L	DirCartS1
	BEQ.S	GPNoCart
	BSR	GPBuild
	MOVE.L	#GPName,D1
	MOVE.L	_DOSBASE,A6
	JSR	-72(A6)			; DeleteFile
	TST.B	GPActive
	BNE.W	GPRestore
	RTS

GPExt:		DC.B	".prefs",0
TGPNOCART:	DC.B	"   No cartridge in Slot 1.    ",0
TGPWRITE:	DC.B	" Can't write the game file.   ",0
GPActive:	DC.B	0		; A game's settings are in force.
GPOk:		DC.B	0
CartLoadOK:	DC.B	0		; Set by Insert when the ROM loaded.
CliCart:	DC.B	0		; This insert came from the CLI.
		CNOP	0,4
GPBuf:		DS.B	GP_LEN		; A game's settings (file image).
GPSaved:	DS.B	GP_LEN		; The global ones while it is in force.
GPName:		DS.B	$200+8

; (4.5) Test hook 'S2=<cartridge>' (Main: ROMS2NOM): the Disk ROM gadget to
; None (Slot 2 is off while a Disk ROM is chosen), then that cartridge in
; Slot 2, as Insert Cartridge would with the file requester.
AutoSlot2:
	TST.B	ROMS2NOM
	BEQ.S	AutoS2R
	LEA	ROMS2NOM,A0
	LEA	FILENOM,A1
AutoS2Cp:
	MOVE.B	(A0)+,(A1)+
	BNE.S	AutoS2Cp
	CLR.B	ROMS2NOM
	LEA	MSX2Gadgets+(GD_DiskVer*4),A0
	MOVE.L	MSX2WND,A1
	MOVE.L	#$8008000F,D0		; GTCY_Active: 2 = None
	MOVEQ	#2,D1
	BSR	CanviTags
	BSR	DiskROMVer
	ST	AutoCart
	BSR	InsertSl2
AutoS2R:
	RTS

; (4.6) Slot 2 > Insert and the Slot 2 button are always there. A Disk ROM
; takes Slot 2: with one chosen, ask first. Yes: Disk ROM None (as AutoSlot2),
; then the insert; No: nothing.
	CNOP	0,4
InsertSl2Ask:
	LEA	MSX2Gadgets+(GD_DiskVer*4),A0
	MOVE.L	(A0),A1
	CMP.B	#2,$57(A1)
	BEQ	InsertSl2
	MOVE.L	MSX2Wnd,A0
	LEA	Sl2AskES(PC),A1
	SUB.L	A2,A2
	SUB.L	A3,A3
	MOVE.L	_IntuitionBase,A6
	JSR	-$24C(A6)		; EasyRequestArgs: 1 = Yes, 0 = No
	TST.L	D0
	BEQ.S	InsertSl2AskNo
	LEA	MSX2Gadgets+(GD_DiskVer*4),A0
	MOVE.L	MSX2WND,A1
	MOVE.L	#$8008000F,D0		; GTCY_Active: 2 = None
	MOVEQ	#2,D1
	BSR	CanviTags
	BSR	DiskROMVer
	BRA	InsertSl2
InsertSl2AskNo:
	RTS
Sl2AskES:	DC.L	20,0,Sl2AskTitle,Sl2AskText,Sl2AskGads
Sl2AskTitle:	DC.B	"AmiMSX",0
Sl2AskText:	DC.B	"Slot 2 is used by the Disk ROM.",10
		DC.B	"Switch the Disk ROM off?",0
Sl2AskGads:	DC.B	"Yes|No",0

	CNOP	0,8
InsertSl2:
	MOVE.L	#MSX2IText9,DatTxt
	MOVE.L	#MN_Sl2Eject,DatItem

	MOVE.L	DirCartS2(PC),DirCart
	MOVE.L	BucCartS2(PC),BucCart
	MOVE.L	BucCartAddS2(PC),BucCartAdd2
	MOVE.W	PagCartS2(PC),PagCart
	MOVE.L	#Slot2Cart,SlotxCart

	BSR	Insert

	BSR	MiraCheckCart
	ADDQ.B	#1,D0
	MOVE.B	D0,DirPrefs+$77
	MOVEQ	#1,D3
	LSL.W	D0,D3
	BSR	Sl2MapRut

	MOVE.L	DirCart(PC),DirCartS2
	MOVE.L	BucCart(PC),BucCartS2
	MOVE.L	BucCartAdd(PC),BucCartAddS2
	MOVE.W	PagCart(PC),PagCartS2
	MOVE.L	CheckId(PC),CheckIdS2
	RTS

	CNOP	0,8
Insert:
	SF	CliCart
	TST.B	AutoCart		; Test hook: FILENOM set from the CLI.
	BEQ.S	InsertReq
	SF	AutoCart
	ST	CliCart			; (Label from FILENOM, not the requester.)
	BSR	DisMouse
	BRA.S	InsertAuto
InsertReq:
	TST.L	_ASLBase(PC)
	BEQ	NeedASL

	BSR	DisMouse

	MOVE.L	ReqBaseSlot,A0
	LEA	TAGSSlot,A1
	MOVE.L	_AslBase,A6
	JSR	-$3C(A6)	; RequestFile.

	TST.L	D0
	BEQ	ReqCancel


	MOVE.L	ReqBaseSlot,A2
	BSR	ArreglaNom
InsertAuto:

;	--------------------
	TST.L	_xpkBase(PC)		; Mira si es un xpk.
	BEQ.S	NoXpkFile

	LEA	XpkFibBase,A0		; �Fichero xpk?
	LEA	xpkTags0(PC),A1
	MOVE.L	_xpkBase,A6
	JSR	-54(A6)		; xpkOpen
	BNE.S	NoXpkFile

	MOVE.L	XpkFibBase,A0		; �Comprimido con xpk?
	CMP.L	#1,(A0)
	BNE.S	NoXpkFile

	MOVE.L	4(A0),-(SP)

	MOVE.L	XpkFibBase,A0
	MOVE.L	_xpkBase,A6
	JSR	-78(A6)		; xpkClose

	MOVE.L	(SP)+,D0
	MOVE.L	D0,BucFileCart
	BSR	MiraMSXCartSize
	BEQ.S	NoXpkFile

	MOVE.B	#$7F,Comprimido
	BRA	EsXpkFile
NoXpkFile:

;	--------------------
	MOVE.L	#FileNom,D1		; Open File
	MOVE.L	#$3ED,D2
	BSR	OpenFile
	BEQ	OpenError

	MOVE.L	#FileNom,D1
	BSR	LongFile		; Mira Size.
	MOVE.L	D0,BucFileCart
	BEQ	ReadError

	MOVE.L	#(4*4),D3
	MOVE.L	#CabFileBuf,D2
	BSR	ReadFile
	BNE	ReadError

	CMP.L	#"IMP!",CabFileBuf
	BNE.S	NoImpComp
	MOVE.L	CabFileBuf+$04(PC),D0
	BSR	MiraMSXCartSize
	BEQ.S	NoImpComp

	MOVE.B	#1,Comprimido
	BRA.S	SiImpComp
NoImpComp:

	CMP.W	#"S4",CabFileBuf
	BNE.S	NoStcComp
	MOVE.L	CabFileBuf+$08(PC),D0
	BSR	MiraMSXCartSize
	BEQ.S	NoStcComp

	TST.L	_StcBase(PC)
	BEQ	ErNoStc

	ST	Comprimido
	BRA.S	SiStcComp
NoStcComp:

;	--------------------
	MOVE.L	BucFileCart(PC),D0
	BSR	MiraMSXCartSize
	BEQ	NoMSXCart
	SF	Comprimido
SiImpComp:
SiStcComp:
EsXpkFile:
	MOVE.W	D0,PagCart
	LSL.W	#1,D0			; Pasa de 16Kb a 8Kb pages.
	MULU	#$2080,D0
	ADD.L	#$80,D0
	MOVE.L	D0,-(SP)

	MOVE.L	BucCart(PC),D0
	BEQ.S	NoHayCart
	ADD.L	BucCartAdd2(PC),D0
	MOVE.L	DirCart(PC),A1
	MOVE.L	$4.W,A6
	JSR	-$D2(A6)		; Libera memoria.
	CLR.L	BucCart

	ST	([SlotxCart])

NoHayCart:
	MOVE.L	(SP)+,BucCart

	MOVE.L	#$00010001,D1
	MOVE.L	BucCart(PC),D0
	ADD.L	BucCartAdd(PC),D0
	MOVE.L	4.W,A6
	JSR	-$C6(A6)		; Requiere memoria.
	MOVE.L	D0,DirCart
	BEQ	OutOfMem2

;	--------------------

	CMP.B	#$7F,Comprimido
	BNE.S	NoDescomXpk

	LEA	xpkTags1(PC),A0
	MOVE.L	DirCart(PC),$0C(A0)
	ADD.L	#$80,$0C(A0)
	MOVE.L	BucCart(PC),D0		; tendria que ser BucFile
	ADD.L	BucCartAdd(PC),D0
	MOVE.L	D0,$14(A0)
	MOVE.L	_xpkBASE,A6
	JSR	-48(A6)		; xpkUnPack
;;	B??  error

	BRA	NoCompri0
NoDescomXpk:

;	--------------------
	LEA	CabFileBuf(PC),A1
	MOVE.L	DirCart,A0
	TST.B	Comprimido(PC)
	BNE.S	SiCompri0
	ADD.W	#$80,A0
SiCompri0:
	MOVE.L	(A1)+,(A0)+
	MOVE.L	(A1)+,(A0)+
	MOVE.L	(A1)+,(A0)+
	MOVE.L	(A1)+,(A0)+
	MOVE.L	A0,D2
	MOVE.L	BucFileCart(PC),D3
	SUB.L	#(4*4),D3
	BSR	ReadFile
;;	BNE	ReadError2

	BSR	CloseFile
; -=-=-

	TST.B	Comprimido(PC)
	BEQ.S	NoCompri0

	CMP.B	#1,Comprimido
	BEQ.S	DesImplo

;	--------------------
	MOVE.L	DirCart,A1
	LEA	$80(A1),A0
	MOVE.L	_StcBase,A6
	JSR	-$24(A6)
	MOVE.L	DirCart,A0
	MOVE.W	#($80/4)-1,D0
DesStcBuc:
	CLR.L	(A0)+
	DBF	D0,DesStcBuc
	MOVE.L	CabFileBuf+$08,BucFileCart

	BRA.S	NoCompri0
; -=-=-
DesImplo:
	MOVE.L	DirCart,A0
	LEA	$80(A0),A1
	BSR	Explode
	MOVE.L	DirCart,A0
	MOVE.W	#($80/4)-1,D0
DesImpBuc:
	CLR.L	(A0)+
	DBF	D0,DesImpBuc
	MOVE.L	CabFileBuf+$04,BucFileCart

	NOP			; was: BRA.S	NoCompri0 (zero-length short branch)
; -=-=-
NoCompri0:
; -=-=-
	TST.B	Cart8K			; (4.0) 8 Kb file: mirror it to 16 Kb.
	BEQ.S	NoCart8K
	CMP.L	#$2000,BucFileCart
	BNE.S	NoCart8K
	MOVE.L	DirCart,A0
	ADD.W	#$80,A0
	LEA	$2000(A0),A1
	MOVE.W	#($2000/4)-1,D0
Cart8KBuc:
	MOVE.L	(A0)+,(A1)+
	DBF	D0,Cart8KBuc
NoCart8K:
	BSR	CalCheckCart		; Calcula Check-Sum
	JSR	RomDbCheck		; (4.0) ROM database (mapper by SHA-1).
; -=-=-
	MOVE.L	DirCart,A0		;;	Mirar ID
	CMP.W	#"AB",$80(A0)
	BEQ.S	IDCorrecta
	MOVE.W	PagCart,D0		; Linear 48/64Kb cart: "AB" at &H4000.
	SUBQ.W	#3,D0			; (8Kb pages not spaced out yet)
	CMP.W	#1,D0
	BHI.S	NoIDLineal
	CMP.W	#"AB",$80+$4000(A0)
	BEQ.S	IDCorrecta
NoIDLineal:
	BSR	RTypeID			; (4.5) R-Type: "AB" in its fixed bank?
	BEQ.S	IDCorrecta
	BSR	NoCartrID
	BNE.S	IDCorrecta

	MOVE.L	BucCart(PC),D0		; Libera Memoria por Cancel en ID.
	ADD.L	BucCartAdd(PC),D0
	MOVE.L	DirCart(PC),A1
	MOVE.L	$4.W,A6
	JSR	-$D2(A6)		; Libera memoria.
	CLR.L	BucCart

	LEA	TNOFile,A0
	BRA.W	NoInsert
IDCorrecta:
; -=-=-
	MOVE.L	DirCart,A0
	ADD.W	#$80,A0
	MOVE.W	PagCart,D0
	LSL.W	#1,D0			; Pasa de 16Kb a 8Kb pages.
	MOVE.W	D0,D1
	MULU	#$2080,D1
	LEA	(A0,D1.L),A1
	MOVE.W	D0,D1
	MULU	#$2000,D1
	LEA	(A0,D1.L),A0
	SUBQ.W	#1,D0
ArrROMPagBuc0:
	MOVEQ	#($80/4)-1,D1
ArrROMPagBuc1:
	CLR.L	-(A1)
	DBF	D1,ArrROMPagBuc1
	MOVE.W	#($2000/4)-1,D1
ArrROMPagBuc2:
	MOVE.L	-(A0),-(A1)
	DBF	D1,ArrROMPagBuc2
	DBF	D0,ArrROMPagBuc0

; -=-=-=-
					; Todo Correcto!

	ST	CartLoadOK		; (Per-game settings: loaded.)
	MOVE.L	DatItem,D0		; the slot's Eject
	BSR	COGECHECK
	OR.W	#$0010,$C(A0)

; -=-=-=-

	MOVE.L	REQBASESLOT,A2
	MOVE.L	4(A2),A0
	TST.B	CliCart			; From the CLI: the file part of FILENOM
	BEQ.S	NoInsert		; (the requester was never used).
	LEA	FILENOM,A0
	MOVE.L	A0,A1
CliNomB:
	MOVE.B	(A1)+,D0
	BEQ.S	NoInsert
	CMP.B	#"/",D0
	BEQ.S	CliNomS
	CMP.B	#":",D0
	BNE.S	CliNomB
CliNomS:
	MOVE.L	A1,A0
	BRA.S	CliNomB
NoInsert:
	MOVE.L	DatTxt,A1
	BSR	PONOM

	move.l  _IntuitionBase,a6
	move.l  MSX2Wnd,a0
	move.b  54(a0),d0
	ext.w   d0
	move.b  55(a0),d1
	ext.w   d1
	move.l  50(a0),a0
	lea	MSX2Text8,a1
	jsr     TallIText


;	LEA	GameBoyGadgets+(GD_Continue*4),A0
;	MOVE.L	GameBoyWND,A1
;	MOVEQ	#1,D0
;	BSR	GadsOnOff



	BSR	EnaMouse
	RTS


; (4.5) An R-Type mapper cartridge (the ROM database's code 6, or a saved
; R-Type mapper) has its "AB" header in the bank fixed at 4000h (17h, or the
; last bank of a smaller ROM; 5C000h in the 384 KB R-Type), not at 0.
; The file is still linear here. Out: Z set if the header is there.
RTypeID:
	MOVEM.L	D0-D2/A0,-(SP)
	CMP.B	#6,RomDbCode
	BEQ.S	RTypeID1
	BSR	MiConMapper		; A saved mapper (code 6: R-Type)?
	TST.B	SiNewMapp(PC)
	BNE.S	RTypeIDN
	CMP.B	#6,D0
	BNE.S	RTypeIDN
RTypeID1:
	MOVEQ	#$17,D0
	CMP.W	PagCart(PC),D0
	BCS.S	RTypeID2
	MOVE.W	PagCart(PC),D0
	SUBQ.W	#1,D0
RTypeID2:
	MULU	#$4000,D0
	MOVE.L	DirCart(PC),A0
	ADD.L	D0,A0
	CMP.W	#"AB",$80(A0)
	BRA.S	RTypeIDX
RTypeIDN:
	MOVEQ	#1,D0			; (Z clear)
RTypeIDX:
	MOVEM.L	(SP)+,D0-D2/A0		; (MOVEM keeps the flags)
	RTS

MiraMSXCartSize:
	SF	Cart8K
	CMP.L	#$2000,D0		; (4.0) 8-16 Kb: one 16 Kb page (an 8 Kb
	BCS.S	NoMSXCartCon		; file is mirrored to fill it, as on
	CMP.L	#$4000,D0		; the cartridge).
	BCC.S	MiCaS16
	ST	Cart8K
	CLR.L	BucCartAdd
	MOVEQ	#1,D0
	MOVEQ	#-1,D1
	RTS
MiCaS16:
	MOVE.L	D0,D1
	AND.L	#$3FFF,D1
	MOVE.L	D1,BucCartAdd

	CMP.L	#$4000,D0		; mira m�nimo 16Kb
	BCS.S	NoMSXCartCon

	LSR.L	#8,D0
	LSR.L	#6,D0
	CMP.L	#$100,D0			; mira m�ximo 4Mb (ASCII16: 256 x 16Kb)
	BGT.S	NoMSXCartCon
	MOVEQ	#-1,D1
	RTS
NoMSXCartCon:
	MOVEQ	#0,D1
	RTS

ReqCancel:
	BSR	EnaMouse
	RTS

ErNoStc:
	BSR	CloseFile
	LEA	tErNoStc,A0
	BRA	ImpError
OpenError:
	LEA	tErOpenFile,A0
	BRA	ImpError
ReadError:
	BSR	CloseFile
	LEA	tErReadFile,A0
	BRA	ImpError
NoMSXCart:
	BSR	CloseFile
	LEA	tErNoGBCart,A0
	BRA	ImpError
OutOfMem2:
	CLR.L	BucCart
	BSR	CloseFile
	LEA	tErOutOfMem,A0
	BRA	ImpError

; -=-=-=-=-=-

	CNOP	0,8
CalCheckCart:
	MOVE.L	DirCart(PC),A0
	ADD.W	#$80,A0
	MOVE.W	PagCart(PC),D0
	MULU	#($4000/2),D0
	MOVEQ	#0,D1
	MOVEQ	#0,D2
CaChCaBuc:
	MOVE.W	(A0)+,D1
	ADD.L	D1,D2
	SUBQ.L	#1,D0
	BNE.S	CaChCaBuc
	AND.L	#$1FFFFFFF,D2
	MOVE.L	D2,CheckId		; Guarda Check-Sum.
	RTS


	CNOP	0,8
MiraCheckCart:

	CMP.L	#($2080*5),BucCart	; �Es mayor de 40Kb?
	BCC.S	MiConMapper0
MiStdMapper:
	MOVE.W	#-1,D0			; Mapper Standard.
	RTS

MiConMapper0:
	MOVE.L	DirCart(PC),A0		; Linear 48/64Kb cart: Standard.
	MiraLin	A0,BucCart,D0
	BNE.S	MiStdMapper
	BSR	MiConMapper		; Mapper saved for this cartridge?
	TST.B	SiNewMapp(PC)
	BEQ.S	MiConMapFin
	TST.B	RomDbHit		; (4.0) No: the ROM database (found
	BEQ.S	MiConNoDb		; at load, RomDbCheck)?
	SF	RomDbHit
	MOVEQ	#0,D0
	MOVE.B	RomDbCode,D0
	BNE.S	MiConMapFin
	MOVE.W	#-1,D0			; (0: standard)
	BRA.S	MiConMapFin
MiConNoDb:
	BSR	TagMapper		; No: a mapper tag in the file name?
	BNE.S	MiConMapFin
	BSR	GuessMapper		; No: guess it like openMSX does.
MiConMapFin:
	RTS

MiConMapper:
;;	LEA	MegaROMsId,A0
;;	MOVE.W	-2(A0),D1
;;	BSR	MiChCaRut

	MOVE.L	DirMapper,A0
	MOVE.W	MapperIDBuf+$10(PC),D1
	BSR	MiChCaRut

	RTS

MiChCaRut:
	SUBQ.W	#1,D1
	BCS.S	MiChCaFin
	MOVE.L	CheckId,D0
MiChCaBuc:
	CMP.W	2(A0),D0
	BEQ.S	MiChCaCon0
MiChCaCon1:
	ADDQ.W	#4,A0
	DBF	D1,MiChCaBuc
MiChCaFin:
	MOVEQ	#4,D0			; Mapper SCC 1.

	ST	SiNewMapp
	RTS

MiChCaCon0:
	MOVE.L	(A0),D2
	AND.L	#$1FFFFFFF,D2
	CMP.L	D2,D0
	BNE.S	MiChCaCon1

	MOVEQ	#0,D0
	MOVE.B	(A0),D0
	LSR.B	#5,D0			; Mapper Guardado.

	SF	SiNewMapp
	RTS

; -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
; Guess the MegaROM mapper like openMSX (RomFactory.cc guessRomType): count
; the LD (nn),A writes to each mapper's bank registers; ties go to the later
; type in openMSX's order ASCII8, ASCII16, Konami, Konami SCC.
; Out: D0 = saved-mapper code (1 Konami 2, 2 ASCII 1 = ASCII8,
; 3 ASCII 2 = ASCII16, 4 SCC 1 = Konami SCC, also used when nothing matches).
	CNOP	0,4
GuessMapper:
	MOVEM.L	D1-D6/A0-A1,-(SP)
	MOVE.L	DirCart(PC),A0
	MOVE.L	A0,A1
	ADD.L	BucCart(PC),A1
	SUBQ.L	#2,A1
	LEA	$80(A0),A0
	MOVEQ	#0,D3			; Konami SCC
	MOVEQ	#0,D4			; Konami
	MOVEQ	#0,D5			; ASCII8
	MOVEQ	#0,D6			; ASCII16
GuMaBuc:
	CMP.L	A1,A0
	BCC.S	GuMaFin
	CMP.B	#$32,(A0)+		; LD (nn),A
	BNE.S	GuMaBuc
	MOVE.B	1(A0),D1
	LSL.W	#8,D1
	MOVE.B	(A0),D1
	CMP.W	#$5000,D1
	BEQ.S	GuMaSCC
	CMP.W	#$9000,D1
	BEQ.S	GuMaSCC
	CMP.W	#$B000,D1
	BEQ.S	GuMaSCC
	CMP.W	#$4000,D1
	BEQ.S	GuMaKon
	CMP.W	#$8000,D1
	BEQ.S	GuMaKon
	CMP.W	#$A000,D1
	BEQ.S	GuMaKon
	CMP.W	#$6800,D1
	BEQ.S	GuMaAs8
	CMP.W	#$7800,D1
	BEQ.S	GuMaAs8
	CMP.W	#$77FF,D1
	BEQ.S	GuMaAs16
	CMP.W	#$6000,D1
	BNE.S	GuMa7000
	ADDQ.L	#1,D4
	ADDQ.L	#1,D5
	ADDQ.L	#1,D6
	BRA.S	GuMaBuc
GuMa7000:
	CMP.W	#$7000,D1
	BNE.S	GuMaBuc
	ADDQ.L	#1,D3
	ADDQ.L	#1,D5
	ADDQ.L	#1,D6
	BRA.S	GuMaBuc
GuMaSCC:
	ADDQ.L	#1,D3
	BRA.S	GuMaBuc
GuMaKon:
	ADDQ.L	#1,D4
	BRA.S	GuMaBuc
GuMaAs8:
	ADDQ.L	#1,D5
	BRA.S	GuMaBuc
GuMaAs16:
	ADDQ.L	#1,D6
	BRA.S	GuMaBuc

GuMaFin:
	TST.L	D5			; openMSX: ASCII8 count - 1.
	BEQ.S	GuMaEle
	SUBQ.L	#1,D5
GuMaEle:
	MOVEQ	#4,D0			; Nothing found: SCC 1, as v3.1 did.
	MOVEQ	#0,D2			; Best count so far.
	TST.L	D5
	BEQ.S	GuMaEle1
	MOVE.L	D5,D2
	MOVEQ	#2,D0			; ASCII 1 (ASCII8)
GuMaEle1:
	TST.L	D6
	BEQ.S	GuMaEle2
	CMP.L	D2,D6
	BCS.S	GuMaEle2
	MOVE.L	D6,D2
	MOVEQ	#3,D0			; ASCII 2 (ASCII16)
GuMaEle2:
	TST.L	D4
	BEQ.S	GuMaEle3
	CMP.L	D2,D4
	BCS.S	GuMaEle3
	MOVE.L	D4,D2
	MOVEQ	#1,D0			; Konami 2
GuMaEle3:
	TST.L	D3
	BEQ.S	GuMaEle4
	CMP.L	D2,D3
	BCS.S	GuMaEle4
	MOVEQ	#4,D0			; SCC 1 (Konami SCC)
GuMaEle4:
	MOVEM.L	(SP)+,D1-D6/A0-A1
	RTS

; -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
; Mapper tag in the file name, as in the MiSTer/openMSX sets: "[KonamiSCC]",
; "[SCC]", "[Konami]", "[Konami4]", "[ASCII8]", "[ASCII16]" (any case).
; Monster Hunter switches banks with LD (HL),A, so the guess can't see it.
; Out: D0 = saved-mapper code and NE, or EQ (no tag).
	CNOP	0,4
TagMapper:
	MOVEM.L	D1-D2/A0-A2,-(SP)
	LEA	FILENOM(PC),A0
TgMaBuc:
	MOVE.B	(A0)+,D1
	BEQ.S	TgMaNo
	CMP.B	#'[',D1
	BNE.S	TgMaBuc
	LEA	TagMapTab(PC),A2
TgMaEnt:
	MOVEQ	#0,D0
	MOVE.B	(A2)+,D0		; Code, 0: end of table.
	BEQ.S	TgMaBuc
	MOVE.L	A0,A1
TgMaCmp:
	MOVE.B	(A2)+,D1
	BEQ.S	TgMaEnd
	MOVE.B	(A1)+,D2
	OR.B	#$20,D2			; (Lower case.)
	CMP.B	D2,D1
	BEQ.S	TgMaCmp
TgMaSkip:
	TST.B	(A2)+
	BNE.S	TgMaSkip
	BRA.S	TgMaEnt
TgMaEnd:
	CMP.B	#']',(A1)
	BNE.S	TgMaEnt
	TST.B	D0
	BRA.S	TgMaFin
TgMaNo:
	MOVEQ	#0,D0
TgMaFin:
	MOVEM.L	(SP)+,D1-D2/A0-A2	; (Flags kept.)
	RTS

TagMapTab:
	DC.B	4,"konamiscc",0
	DC.B	4,"scc",0
	DC.B	1,"konami",0
	DC.B	1,"konami4",0
	DC.B	2,"ascii8",0
	DC.B	3,"ascii16",0
	DC.B	0
	EVEN

; -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

	CNOP	0,8
	DC.W	0
	DC.W	MegaROMsIdBuc
MegaROMsId:
	DC.L	$1A0BE6E0+(4*$20000000)		; Nemesis I
	DC.L	$06521A69+(4*$20000000)		; Nemesis II
	DC.L	$0256E6AB+(4*$20000000)		; Nemesis III
	DC.L	$0815423B+(4*$20000000)		; Salamander
	DC.L	$09C6DE18+(4*$20000000)		; Parodius
	DC.L	$1D664ABB+(2*$20000000)		; Bubble Bobble
	DC.L	$083A5C71+(2*$20000000)		; Xevious
	DC.L	$16135C55+(3*$20000000)		; The Return of Ishtar
	DC.L	$184A0C42+(2*$20000000)		; Out-Run
	DC.L	$0FA15306+(0*$20000000)		; Andorogynous
	DC.L	$122E943A+(1*$20000000)		; Shalom
	DC.L	$1F546671+(5*$20000000)		; Solid Snake
MegaROMsIdFin:

MegaROMsIdBuc=(MegaROMsIdFin-MegaROMsId)/4

	CNOP	0,8

; -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

tErNoSTC:	DC.B	"    stc.library not found.    ",0
tErOpenFile:	DC.B	"       Open file failed.      ",0
tErReadFile:	DC.B	"   Error while loading file.  ",0
tErNoGBCart:	DC.B	"    Bad MSX Cartridge size.   ",0
tErOutOfMem:	DC.B	"   -=>  Out of memory!  <=-   ",0

tNoFile:	DC.B	"None.",0

; -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-


	CNOP	0,8
xpkTags0:
	DC.L	$80005851,FileNom	; Nombre del Fichero a abrir.
	DC.L	0

xpkTags1:
	DC.L	$80005851,FileNom	; Nombre del Fichero a abrir.
	DC.L	$80005862,0
	DC.L	$80005871,0
	DC.L	0

;	DC.L	$80005851,Nombre del Fichero a abrir.
;	DC.L	$80005852,FileHandle (retorno del dosOpen) lectura.
;	DC.L	$80005853,Bloque de memor�a donde leer.
;	DC.L	$80005860,Nombre del Fichero a crear/reescribir.
;	DC.L	$80005861,FileHandle (retorno del dosOpen) escritura.
;	DC.L	$80005862,Bloque de memor�a donde escribir.
;	DC.L	$80005870,Size del bufer donde leer.
;	DC.L	$80005871,Size del bufer donde escribir.
;	DC.L	$80005877,=1 Soportar leer ficheros no xpkeados!

; ------------------------------------------





; -----------------------------------
	CNOP	0,4
; (4.0) Load a disk image into drive B (its own virtual disk; Left Amiga
; swaps A and B in play). Replaces the one there.
LOADVDB:
	TST.L	_ASLBase(PC)
	BEQ	NeedASL
	BSR	DISMOUSE
	MOVE.L	REQBASE,A0
	LEA	TAGSLoadMVD,A1
	MOVE.L	_ASLBASE,A6
	JSR	-$3C(A6)		; RequestFile.
	MOVE.L	D0,-(SP)
	BSR	ENAMOUSE
	MOVE.L	(SP)+,D0
	TST.L	D0
	BEQ	SLCANCEL
	MOVE.L	REQBASE,A2
	LEA	DISKBNOM,A1
	MOVE.W	#$100-1,D0
	MOVE.L	8(A2),A0
	TST.B	(A0)
	BEQ.S	LdVBNm
	BSR	COPYNOM
	SUBQ	#1,A1
	CMP.B	#":",-1(A1)
	BEQ.S	LdVBNm
	MOVE.B	#"/",(A1)+
LdVBNm:	MOVE.W	#$100-1,D0
	MOVE.L	4(A2),A0
	BSR	COPYNOM
	BSR	FreeDiskB		; The one before goes.
	JSR	LoadDiskB
	TST.B	DISKBNOM		; Refused (an MVD, an odd size): say so.
	BNE.S	LdVBOk
	LEA	TLEEDKB,A0
	BSR	IMPERROR
LdVBOk:	RTS

LOADVD0:
	TST.L	_ASLBase(PC)
	BEQ	NeedASL

	BSR	MIRAMVDSA

	BSR	DISMOUSE

	MOVE.L	REQBASE,A0
	LEA	TAGSLoadMVD,A1
	MOVE.L	_ASLBASE,A6
	JSR	-$3C(A6)	; RequestFile.

	MOVE.L	D0,-(SP)
	BSR	ENAMOUSE
	MOVE.L	(SP)+,D0

	TST.L	D0
	BEQ	SLCANCEL


	MOVE.L	REQBASE,A2
	LEA	FILENOM(PC),A1
	MOVE.W	#$100-1,D0
	MOVE.L	8(A2),A0
	TST.B	(A0)
	BEQ.S	CHAPUZ0
	BSR	COPYNOM
	SUBQ	#1,A1
	CMP.B	#":",-1(A1)
	BEQ.S	CHAPUZ0
	MOVE.B	#"/",(A1)+
CHAPUZ0:
	MOVE.W	#$100-1,D0
	MOVE.L	4(A2),A0
	BSR	COPYNOM


LOADVDAuto:				; (CLI test hook: FILENOM already set.)
	MOVE.L	#FILENOM,D1
	MOVE.L	#$3ED,D2
	BSR	OPENFILE
	BEQ	DISERROR


	MOVEQ	#$0C,D3
	MOVE.L	#BUFERDSK,D2
	BSR	READFILE

	LEA	BUFERDSK,A0
	CMP.W	#"S4",(A0)
	SEQ	FILECOMP
	BNE.S	NOESSTC

	MOVE.L	#FileNom,D1
	BSR	LONGFILE
	MOVE.L	D0,BYTEFILE
	BEQ	DISERROR2

	MOVE.L	BUFERDSK+$8,D0
	MOVE.L	#TLOADDEC,DIRTXTLOD
	BRA.S	SIESSTC

	CNOP	0,4
NOESSTC:
	CMP.L	#"IMP!",(A0)
	BNE.S	NOESIMP

	MOVE.L	#FileNom,D1
	BSR	LONGFILE
	MOVE.L	D0,BYTEFILE
	BEQ	DISERROR2

	MOVE.L	BUFERDSK+$4,D0
	MOVE.L	#TLOADDEC,DIRTXTLOD
	BRA.S	SIESSTC
NOESIMP:
	MOVE.L	#TLOADNOR,DIRTXTLOD
	MOVE.L	#FileNom,D1
	BSR	LONGFILE
	MOVE.L	D0,BYTEFILE
	BEQ	DISERROR2
SIESSTC:
	MOVE.L	#721*1024,-(SP)
	CMP.L	#720*1024,D0
	BEQ.S	DISKCONT
	MOVE.L	#361*1024,(SP)
	CMP.L	#360*1024,D0
	BEQ.S	DISKCONT
	ADDQ	#4,SP
	BSR	CLOSEFILE
	LEA	TLEENOTMD,A0
	BSR	IMPERROR
	RTS
DISKCONT:

	MOVE.L	DIRFILE,A1
	MOVE.L	BUCFILE,D0
	BEQ.S	NOHAYMEM
	MOVE.L	4.W,A6
	JSR	-$D2(A6)		; Libera memoria.
	CLR.L	DIRFILE
	CLR.L	BUCFILE

	SF	MVDMODIFI			; Pasa de grabar!
NOHAYMEM:

	MOVE.L	(SP)+,BUCFILE

	MOVE.L	#$10000,D1
	MOVE.L	BUCFILE,D0
	MOVE.L	4.W,A6
	JSR	-$C6(A6)		; Requiere memoria.
	MOVE.L	D0,DIRFILE
	BNE.S	DISKCONT1

	CLR.L	BUCFILE
	BSR	CLOSEFILE
	LEA	TLEEMEMORY,A0
	BSR	IMPERROR
	MOVE.L	#TVD0BEM,A0
	MOVE.L	#MSX2IText7,A1
	BSR	COPYNOM2
	BRA	FINALOAD


DISKCONT1:
	BSR	DISMOUSE
	MOVE.L	DIRTXTLOD,A0
	BSR	IMPDISK


	MOVE.L	BYTEFILE,D3
	SUB.L	#$C,D3
	MOVE.L	DIRFILE,A0
	LEA	BUFERDSK,A1
	MOVE.L	(A1)+,(A0)+
	MOVE.L	(A1)+,(A0)+
	MOVE.L	(A1)+,(A0)+
	MOVE.L	A0,D2
	BSR	READFILE
	BEQ.S	DiskReadOK
	BSR	CLOSEFILE		; Incomplete: no disk rather than a
	MOVE.L	DIRFILE,A1		; partly empty one.
	MOVE.L	BUCFILE,D0
	MOVE.L	4.W,A6
	JSR	-$D2(A6)		; FreeMem
	CLR.L	DIRFILE
	CLR.L	BUCFILE
	LEA	TLEEREAD,A0
	BSR	IMPERROR
	MOVE.L	#TVD0BEM,A0
	MOVE.L	#MSX2IText7,A1
	BSR	COPYNOM2
	BRA	FINALOAD
DiskReadOK:
	BSR	CLOSEFILE


	TST.B	FILECOMP(PC)
	BEQ	NORL
; ---------------------------------
STONE:
	MOVE.L	DIRFILE,A1
	LEA	$100(A1),A0
	MOVE.L	_STCBASE,D0
	BEQ.S	NOSTCLIB2
	MOVE.L	D0,A6
	JSR	-$24(A6)
	BRA.S	SISTCLIB2
NOSTCLIB2:
	EXG.L	A0,A1
	BSR	STONE_DEPAC
SISTCLIB2:
	MOVE.L	DIRFILE,A1
	LEA	$100(A1),A0
	MOVE.L	BUCFILE,D0
	SUB.L	#1024,D0
	LSR.L	#2,D0
STONEBUC:
	MOVE.L	(A0)+,(A1)+
	SUBQ.L	#1,D0
	BNE.S	STONEBUC
	BRA.S	CONTINEW2
; ---------------------------------
;PPACKER:
;	MOVE.L	DIRFILE,A0
;	LEA	$100(A0),A1
;	MOVE.L	BYTEFILE,D0
;	BSR	PP20_DECRUNCH
;	BRA.S	CONTINEW2
; ---------------------------------
NORL:
	MOVE.L	DIRFILE,A0
	MOVE.L	A0,A1
	BSR	Explode
; ---------------------------------
CONTINEW2:
	JSR	DiskDbCheck		; (4.4) The disk database's machine.

; <=----------------
	MOVE.L	DIRFILE,A0
	CMP.B	#$F8,$15(A0)
	BNE.S	NoChapuza1DD
	CMP.L	#721*1024,BUCFILE
	BNE.S	NoChapuza1DD
	MOVE.L	A0,A1
	MOVE.W	#(80)-1,D0
NC1DDB0:
	MOVE.W	#((512*9)/8)-1,D1
NC1DDB1:
	MOVE.L	(A0)+,(A1)+
	MOVE.L	(A0)+,(A1)+
	DBF	D1,NC1DDB1
	ADD.W	#(512*9),A0
	DBF	D0,NC1DDB0
NoChapuza1DD:
; <=----------------

	move.l  LOADDECWnd,a0
	BSR	PNORM
	JSR	CLOSELOADDECWINDOW
	BSR	ENAMOUSE

	MOVE.L	REQBASE,A2
	MOVE.L	4(A2),A0
	MOVE.L	#MSX2IText7,A1
	BSR	PONOM
FINALOAD:
	move.l  _IntuitionBase,a6
	move.l  MSX2Wnd,a0
	move.b  54(a0),d0
	ext.w   d0
	move.b  55(a0),d1
	ext.w   d1
	move.l  50(a0),a0
	lea	MSX2Text7,a1
	jsr     TallIText
SLCANCEL:
	RTS

DISERROR2:
	BSR	CLOSEFILE
DISERROR:
	LEA	TLEECANTO,A0
	BSR	IMPERROR
	RTS

; --------------------------------------
	CNOP	0,4
FORMAT1DD:
	MOVE.L	#361*1024,FmtSize
	BRA.S	FmtAsk
FORMAT2DD:
	MOVE.L	#721*1024,FmtSize
; (4.6) Tools > New Blank Disk: which drive? Drive A: as ever. Drive B: its
; own image, with no file behind it (no Save for B yet: writes last until
; it's ejected, replaced or AmiMSX quits).
FmtAsk:
	MOVE.L	MSX2Wnd,A0
	LEA	FmtAskES(PC),A1
	SUB.L	A2,A2
	SUB.L	A3,A3
	MOVE.L	_IntuitionBase,A6
	JSR	-$24C(A6)		; EasyRequestArgs: 1 A, 2 B, 0 Cancel
	CMP.L	#2,D0
	BEQ	FmtDriveB
	TST.L	D0
	BNE.S	FmtDriveA
	RTS
FmtDriveA:
	SF	MVDMODIFI			; MVD cambiado.
	MOVE.L	FmtSize(PC),-(SP)
	MOVE.L	DIRFILE,A1
	MOVE.L	BUCFILE,D0
	BEQ.S	NOHAYMEM2D
	MOVE.L	4.W,A6
	JSR	-$D2(A6)		; Libera memoria.
	CLR.L	DIRFILE
	CLR.L	BUCFILE
NOHAYMEM2D:
	MOVE.L	(SP)+,BUCFILE

	MOVE.L	#$10000,D1
	MOVE.L	BUCFILE,D0
	MOVE.L	4.W,A6
	JSR	-$C6(A6)		; Requiere memoria.
	MOVE.L	D0,DIRFILE
	BNE.S	FOR2DCONT

	CLR.L	BUCFILE
	LEA	TLEEMEMORY,A0
	BSR	IMPERROR
	MOVE.L	#TVD0BEM,A0
	MOVE.L	#MSX2IText7,A1
	BSR	COPYNOM2
	BRA	FINALOAD

FOR2DCONT:
	MOVE.L	D0,A1

	MOVE.L	BUCFILE,D0
	LSR.L	#3,D0
FOR2DBUC2:
	CLR.L	(A1)+
	CLR.L	(A1)+
	SUBQ.L	#1,D0
	BNE.S	FOR2DBUC2

	MOVE.L	DIRFILE,A1

	MOVE.L	REQBASE,A2
	MOVE.L	4(A2),A0
	SF	(A0)

	LEA	BOOT2DD,A2
	LEA	TFORMAT2DD(PC),A0
	MOVE.L	#$F9FFFF00,D0
	CMP.L	#721*1024,BUCFILE
	BEQ.S	FOR2DDCON3
	LEA	BOOT1DD,A2
	LEA	TFORMAT1DD(PC),A0
	MOVE.L	#$F8FFFF00,D0
FOR2DDCON3:

	MOVE.L	D0,$200(A1)
	MOVE.L	D0,$800(A1)

	MOVE.W	#($B8/4)-1,D0
FOR2DBUC:
	MOVE.L	(A2)+,(A1)+
	DBF	D0,FOR2DBUC

	LEA	MSX2IText7,A1
	BSR	COPYNOM2
	BRA	FINALOAD

TFORMAT2DD:	DC.B	"MSX 2DD Format.            ",0
TFORMAT1DD:	DC.B	"MSX 1DD Format.            ",0
	CNOP	0,4
FmtSize:	DC.L	0		; bytes, a little spare as ever
FmtAskES:	DC.L	20,0,FmtAskTitle,FmtAskText,FmtAskGads
FmtAskTitle:	DC.B	"AmiMSX",0
FmtAskText:	DC.B	"Put the blank disk in which drive?",0
FmtAskGads:	DC.B	"Drive A|Drive B|Cancel",0

	CNOP	0,4
FmtDriveB:
	BSR	FreeDiskB
	CLR.B	DISKBNOM		; (no file behind it)
	MOVE.L	FmtSize(PC),D0
	MOVE.L	D0,BUCFILEB
	MOVE.L	#$10000,D1
	MOVE.L	4.W,A6
	JSR	-$C6(A6)		; AllocMem (cleared)
	MOVE.L	D0,DIRFILEB
	BNE.S	FmtBOk
	CLR.L	BUCFILEB
	LEA	TLEEMEMORY,A0
	BSR	IMPERROR
	JMP	ShowDiskB
FmtBOk:	MOVE.L	D0,A1
	MOVE.L	FmtSize(PC),D0
	SUB.L	#1024,D0
	MOVE.L	D0,DskBSize
	SF	DskDirtyB
	LEA	BOOT2DD,A2
	LEA	TFORMAT2DD(PC),A0
	MOVE.L	#$F9FFFF00,D0
	CMP.L	#721*1024,FmtSize
	BEQ.S	FmtBFat
	LEA	BOOT1DD,A2
	LEA	TFORMAT1DD(PC),A0
	MOVE.L	#$F8FFFF00,D0
FmtBFat:
	MOVE.L	D0,$200(A1)
	MOVE.L	D0,$800(A1)
	MOVE.W	#($B8/4)-1,D0
FmtBBoot:
	MOVE.L	(A2)+,(A1)+
	DBF	D0,FmtBBoot
	JSR	DiskBGad
	JMP	ShowDiskBT

; --------------------------------------
	CNOP	0,4
CLEARVD0:
	BSR	MIRAMVDSA
	SF	MVDMODIFI			; Pasa de grabar!

	MOVE.L	DIRFILE,A1
	MOVE.L	BUCFILE,D0
	BEQ.S	NOHAYMEM3
	MOVE.L	4.W,A6
	JSR	-$D2(A6)		; Libera memoria.
	CLR.L	DIRFILE
	CLR.L	BUCFILE
NOHAYMEM3:
	MOVE.L	#TVD0BEM,A0
	MOVE.L	#MSX2IText7,A1
	BSR	COPYNOM2
	BRA	FINALOAD

	CNOP	0,4
TVD0BEM:DC.B    'Buffer Empty.              ',0

; (4.6) Disks > Drive B > Eject.
	CNOP	0,4
CLEARVDB:
	BSR	FreeDiskB
	CLR.B	DISKBNOM
	SF	DskDirtyB
	JMP	ShowDiskB
FreeDiskB:
	MOVE.L	BUCFILEB,D0
	BEQ.S	FreeDkBR
	MOVE.L	DIRFILEB,A1
	MOVE.L	4.W,A6
	JSR	-$D2(A6)		; FreeMem
	CLR.L	BUCFILEB
	CLR.L	DIRFILEB
FreeDkBR:
	RTS

; -----------------------------------
	CNOP	0,4
SAVEVD0:
	TST.L	_ASLBase(PC)
	BEQ	NeedASL

	TST.L	BUCFILE
	BNE.S	SAVEVD0C

	LEA	TLEENOFILE,A0
	BSR	IMPERROR
	RTS

	CNOP	0,4
SAVEVD0C:
	BSR	DISMOUSE

	MOVE.L	REQBASE,A0
	LEA	TAGSSaveMVD,A1
	MOVE.L	_ASLBASE,A6
	JSR	-$3C(A6)	; RequestFile.

	MOVE.L	D0,-(SP)
	BSR	ENAMOUSE
	MOVE.L	(SP)+,D0

	TST.L	D0
	BEQ	SLCANCEL

	MOVE.L	REQBASE,A2
	LEA	FILENOM(PC),A1
	MOVE.W	#$100-1,D0
	MOVE.L	8(A2),A0
	TST.B	(A0)
	BEQ.S	CHAPUZ1
	BSR	COPYNOM
	SUBQ	#1,A1
	CMP.B	#":",-1(A1)
	BEQ.S	CHAPUZ1
	MOVE.B	#"/",(A1)+
CHAPUZ1:
	MOVE.W	#$100-1,D0
	MOVE.L	4(A2),A0
	BSR	COPYNOM


	BSR	OverWrite
	BEQ	NoOverwrite

	MOVE.L	#FILENOM,D1
	MOVE.L	#$3EE,D2
	BSR	OPENFILE
	BEQ	DISERROR

	BSR	DISMOUSE
	LEA	TSAVEDEC,A0
	BSR	IMPDISK

	MOVE.L	BUCFILE,D3
; <=----------------
	MOVE.L	DIRFILE,A0
	CMP.B	#$F8,$15(A0)
	BNE.S	NoChapuzaS1DD
	MOVE.L	#361*1024,D3
NoChapuzaS1DD:
; <=----------------
	SUB.L	#1024,D3
	MOVE.L	DIRFILE,D2
	BSR	WRITEFILE
	BSR	CLOSEFILE

	move.l  LOADDECWnd,a0
	BSR	PNORM
	JSR	CLOSELOADDECWINDOW
	BSR	ENAMOUSE

	SF	MVDMODIFI		; MVD ya grabado.

	RTS

; -----------------------------------
;	CNOP	0,4
;MiraROMDirectory:
;	MOVE.L	#tDirROMd,D1
;	MOVEQ	#-2,D2
;	MOVE.L	_DOSBASE,A6
;	JSR	-$54(A6)		; Lock
;	TST.L	D0
;	BEQ.S	NoROMDirec
;	MOVE.L	D0,D1
;	JSR	-$5A(A6)		; UnLock
;	RTS
;NoROMDirec:
;	LEA	TLeeNoROMFileD,A0
;	BSR	IMPERROR
;	RTS
;tDirROMd:	DC.B	"PROGDIR:ROM_Files/",0,0
; -----------------------------------

	CNOP	0,4
LONGFILE:				; D1 = Nombre del fichero.
	MOVEQ	#-2,D2
	MOVE.L	_DOSBASE,A6
	JSR	-$54(A6)		; Lock
	TST.L	D0
	BEQ.S	LONGFILER
	MOVE.L	D0,-(SP)

	MOVE.L	D0,D1
	move.L	#EXAMINE,d2
	MOVE.L	_DOSBASE,A6
	JSR	-$66(A6)		; Examine

	MOVE.L	(SP)+,D1
	JSR	-$5A(A6)		; UnLock

	MOVE.L	EXAMINE+$7C,D0
LONGFILER:
	RTS

; -----------------------------------
	CNOP	0,4
SaveSprites:
	IFD	MENU
	TST.B	GoDat(PC)
	BEQ	ErPowerON
	ENDC

	TST.L	_ASLBase(PC)
	BEQ	NeedASL

	MOVEQ	#0,D0
	MOVE.B	ScrModo+Regs,D0
	TST.L	(IFFTabScr+4.W,PC,D0.W*8)
	BNE.S	SiSavSpr

	LEA	TLEENOSavSpr,A0
	BSR	IMPERROR
	RTS

	CNOP	0,4
SiSavSpr:
	BSR	DISMOUSE

	MOVE.L	ReqBaseVram,A0
	LEA	TAGSSprites,A1
	MOVE.L	_ASLBASE,A6
	JSR	-$3C(A6)	; RequestFile.

	MOVE.L	D0,-(SP)
	BSR	ENAMOUSE
	MOVE.L	(SP)+,D0

	TST.L	D0
	BEQ	SLCANCEL

	MOVE.L	ReqBaseVram,A2
	BSR	ArreglaNom

	BSR	OverWrite
	BEQ	NoOverwrite

	MOVE.L	#FILENOM,D1
	MOVE.L	#$3EE,D2
	BSR	OPENFILE
	BEQ	DISERROR

	BSR	DISMOUSE
	LEA	TSAVESprites,A0
	BSR	IMPDISK

	MOVEQ	#0,D0
	MOVE.B	ScrModo+Regs,D0
	MOVE.L	(IFFTabScr+4.W,PC,D0.W*8),D0	; Screen 8?
	CMP.L	#2,D0
	BNE.S	NoEsScr8
	LEA	MSX2palScr8,A0
	BRA.S	SiEsScr8
NoEsScr8:
	LEA	MSX2pal,A0
SiEsScr8:
	LEA	ILBM4+$30,A1
	MOVE.W	#(16)-1,D0
PALCBUC:
	MOVE.B	(A0)+,D1
	LSL.B	#4,D1
	MOVE.B	D1,(A1)+
	MOVE.B	(A0),D1
	AND.B	#$F0,D1
	MOVE.B	D1,(A1)+
	MOVE.B	(A0)+,D1
	LSL.B	#4,D1
	MOVE.B	D1,(A1)+
	DBF	D0,PALCBUC

	MOVE.W	#256,ILBM4+20
	MOVE.W	#224,ILBM4+22
	MOVE.W	#320,ILBM4+36
	MOVE.W	#256,ILBM4+38
	MOVE.B	#4,ILBM4+28
	MOVE.L	#$00001000,ILBM4+104
	MOVE.L	#(32*224*4),ILBM4+112

	MOVE.L	#(116),D3
	MOVE.L	#ILBM4,D2
	BSR	WRITEFILE

	MOVE.W	DirSprit0+2,D0
	SWAP	D0
	MOVE.W	DirSprit0+6,D0
	MOVE.L	D0,A0
	ADD.W	#(16*15),A0
SPR5CON:
	MOVE.W	#(224/32)-1,D4
SPR5BUC:
	LEA	ILBMraw,A1
	MOVE.W	#(32)-1,D2
SPR5BUC1:
	MOVE.L	A0,A2
	MOVE.W	#(2)-1,D3
SPR5BUC0:
	MOVE.L	A2,A3
	REPT	4
	MOVE.L	(A3)+,(A1)+
	MOVE.L	(A3)+,(A1)+
	ADD.L	#OTRSPR-8,A3
	ENDR
	MOVE.L	A2,A3
	ADDQ	#8,A3
	REPT	4
	MOVE.L	(A3)+,(A1)+
	MOVE.L	(A3)+,(A1)+
	ADD.L	#OTRSPR-8,A3
	ENDR
	ADD.L	#NEXSPR,A2
	DBF	D3,SPR5BUC0
	ADD.W	#(32/4)*2,A0
	DBF	D2,SPR5BUC1
	MOVEM.L	D0-D4/A0-A1,-(SP)
	MOVE.L	#ILBMraw,D2
	MOVE.L	#(4*1024),D3
	BSR	WRITEFILE
	MOVEM.L	(SP)+,D0-D4/A0-A1
	DBF	D4,SPR5BUC

	BSR	CLOSEFILE

	move.l  LOADDECWnd,a0
	BSR	PNORM
	JSR	CLOSELOADDECWINDOW
	BSR	ENAMOUSE
	RTS

MSX2palScr8:
	DC.W	$000,$005,$700,$705,$070,$075,$770,$775
	DC.W	$F95,$00F,$F00,$F0F,$0F0,$0FF,$FF0,$FFF

; -----------------------------------
	CNOP	0,4
SaveVRAM:
	IFD	MENU
	TST.B	GoDat(PC)
	BEQ	ErPowerON
	ENDC

	TST.L	_ASLBase(PC)
	BEQ	NeedASL

	MOVEQ	#0,D0
	MOVE.B	ScrModo+Regs,D0
	TST.L	(IFFTabScr.W,PC,D0.W*8)
	BNE.S	SiSavVram

	LEA	TLEENOSavVram,A0
	BSR	IMPERROR
	RTS

	CNOP	0,4
SiSavVram:
	BSR	DISMOUSE

	MOVE.L	ReqBaseVram,A0
	LEA	TAGSVRAM,A1
	MOVE.L	_ASLBASE,A6
	JSR	-$3C(A6)	; RequestFile.

	MOVE.L	D0,-(SP)
	BSR	ENAMOUSE
	MOVE.L	(SP)+,D0

	TST.L	D0
	BEQ	SLCANCEL

	MOVE.L	ReqBaseVram,A2
	BSR	ArreglaNom

	BSR	OverWrite
	BEQ	NoOverwrite

	MOVE.L	#FILENOM,D1
	MOVE.L	#$3EE,D2
	BSR	OPENFILE
	BEQ	DISERROR

	BSR	DISMOUSE
	LEA	TSAVEVRAM,A0
	BSR	IMPDISK

	LEA	MSX2pal,A0
	LEA	ILBM4+$30,A1
	MOVE.W	#(16)-1,D0
PALSBUC:
	MOVE.B	(A0)+,D1
	LSL.B	#4,D1
	MOVE.B	D1,(A1)+
	MOVE.B	(A0),D1
	AND.B	#$F0,D1
	MOVE.B	D1,(A1)+
	MOVE.B	(A0)+,D1
	LSL.B	#4,D1
	MOVE.B	D1,(A1)+
	DBF	D0,PALSBUC

	MOVEQ	#0,D0
	MOVE.B	ScrModo+Regs,D0
	JSR	([IFFTabScr.W,PC,D0.W*8])

	BSR	CLOSEFILE

	move.l  LOADDECWnd,a0
	BSR	PNORM
	JSR	CLOSELOADDECWINDOW
	BSR	ENAMOUSE
	RTS

	CNOP	0,8
IFFTabScr:
	DC.L	IFFScr2,0	; 1 1G	00 000
	DC.L	IFFScr2,0	; 2 2G	00 001
	DC.L	IFFScr2,1	; 4 3G	00 010
	DC.L	IFFScr5,1	; 5 4G	00 011
	DC.L	IFFScr6,1	; 6 5G	00 100
	DC.L	IFFScr7,1	; 7 6G	00 101
	DC.L	0,0		;	00 110
	DC.L	IFFScr8,2	; 8 7G	00 111
	DC.L	IFFScr2,0	; 3 M	01 000 (Modo 3)
	REPT	7
	DC.L	0,0
	ENDR
	DC.L	0,0		; 0 1T	10 000 (Modo 40 columnas)
	DC.L	0,0
	DC.L	0,0		; 1 2T	10 010 (Modo 80 columnas)
	REPT	5+8+2
	DC.L	0,0
	ENDR


	CNOP	0,4
IFFScr2:
	MOVE.W	#256,ILBM4+20
	MOVE.W	#192,ILBM4+22
	MOVE.W	#320,ILBM4+36
	MOVE.W	#256,ILBM4+38
	MOVE.B	#4,ILBM4+28
	MOVE.L	#$00001000,ILBM4+104
	MOVE.L	#(32*192*4),ILBM4+112

	MOVE.L	#(116),D3
	MOVE.L	#ILBM4,D2
	BSR	WRITEFILE

	MOVE.L	#(32*192*4),D3
	MOVE.L	#SCREEN,D2
	BSR	WRITEFILE
	RTS

	CNOP	0,4
IFFScr5:
	MOVE.W	#256,ILBM4+20
	MOVE.W	#1024,ILBM4+22
	MOVE.W	#320,ILBM4+36
	MOVE.W	#256,ILBM4+38
	MOVE.B	#4,ILBM4+28
	MOVE.L	#$00001000,ILBM4+104
	MOVE.L	#$00020000,ILBM4+112

	MOVE.L	#(116),D3
	MOVE.L	#ILBM4,D2
	BSR	WRITEFILE

	LEA	SCR0,A0
	MOVE.W	#(1024/32)-1,D4
SVR5BUC:
	LEA	ILBMraw,A1
	MOVE.W	#(32)-1,D2
SVR5BUC1:
	MOVE.W	#(4)-1,D3
	MOVE.L	A0,A2
SVR5BUC0:
	REPT	32/4
	MOVE.L	(A2)+,(A1)+
	ENDR
	ADD.W	#32*1023,A2
	DBF	D3,SVR5BUC0
	ADD.W	#32,A0
	DBF	D2,SVR5BUC1
	MOVEM.L	D0-D4/A0-A1,-(SP)
	MOVE.L	#ILBMraw,D2
	MOVE.L	#(4*1024),D3
	BSR	WRITEFILE
	MOVEM.L	(SP)+,D0-D4/A0-A1
	DBF	D4,SVR5BUC
	RTS

	CNOP	0,4
IFFScr7:
	MOVE.W	#512,ILBM4+20
	MOVE.W	#512,ILBM4+22
	MOVE.W	#640,ILBM4+36
	MOVE.W	#256,ILBM4+38
	MOVE.B	#4,ILBM4+28
	MOVE.L	#$00009000,ILBM4+104
	MOVE.L	#$00020000,ILBM4+112

	MOVE.L	#(116),D3
	MOVE.L	#ILBM4,D2
	BSR	WRITEFILE

	LEA	SCR0,A0
	MOVE.W	#(512/16)-1,D4
SVR7BUC:
	LEA	ILBMraw,A1
	MOVE.W	#(16)-1,D2
SVR7BUC1:
	MOVE.W	#(4)-1,D3
	MOVE.L	A0,A2
SVR7BUC0:
	REPT	64/4
	MOVE.L	(A2)+,(A1)+
	ENDR
	ADD.W	#64*511,A2
	DBF	D3,SVR7BUC0
	ADD.W	#64,A0
	DBF	D2,SVR7BUC1
	MOVEM.L	D0-D4/A0-A1,-(SP)
	MOVE.L	#ILBMraw,D2
	MOVE.L	#(4*1024),D3
	BSR	WRITEFILE
	MOVEM.L	(SP)+,D0-D4/A0-A1
	DBF	D4,SVR7BUC
	RTS

	CNOP	0,4
IFFScr6:
	MOVE.W	#512,ILBM4+20
	MOVE.W	#1024,ILBM4+22
	MOVE.W	#640,ILBM4+36
	MOVE.W	#256,ILBM4+38
	MOVE.B	#2,ILBM4+28
	MOVE.L	#$00009000,ILBM4+104
	MOVE.L	#$00020000,ILBM4+112

	MOVE.L	#(116),D3
	MOVE.L	#ILBM4,D2
	BSR	WRITEFILE

	LEA	SCR0,A0
	MOVE.W	#(1024/32)-1,D4
SVR6BUC:
	LEA	ILBMraw,A1
	MOVE.W	#(32)-1,D2
SVR6BUC1:
	MOVE.W	#(2)-1,D3
	MOVE.L	A0,A2
SVR6BUC0:
	REPT	64/4
	MOVE.L	(A2)+,(A1)+
	ENDR
	ADD.L	#64*1023,A2
	DBF	D3,SVR6BUC0
	ADD.W	#64,A0
	DBF	D2,SVR6BUC1
	MOVEM.L	D0-D4/A0-A1,-(SP)
	MOVE.L	#ILBMraw,D2
	MOVE.L	#(4*1024),D3
	BSR	WRITEFILE
	MOVEM.L	(SP)+,D0-D4/A0-A1
	DBF	D4,SVR6BUC
	RTS

	CNOP	0,4
IFFScr8:
	MOVE.L	#(836),D3
	MOVE.L	#ILBM8,D2
	BSR	WRITEFILE

	LEA	SCR0,A0
	MOVE.W	#(512/16)-1,D4
SVR8BUC:
	LEA	ILBMraw,A1
	MOVE.W	#(16)-1,D2
SVR8BUC1:
	MOVE.W	#(8)-1,D3
	MOVE.L	A0,A2
SVR8BUC0:
	REPT	32/4
	MOVE.L	(A2)+,(A1)+
	ENDR
	ADD.W	#32*511,A2
	DBF	D3,SVR8BUC0
	ADD.W	#32,A0
	DBF	D2,SVR8BUC1
	MOVEM.L	D0-D4/A0-A1,-(SP)
	MOVE.L	#ILBMraw,D2
	MOVE.L	#(4*1024),D3
	BSR	WRITEFILE
	MOVEM.L	(SP)+,D0-D4/A0-A1
	DBF	D4,SVR8BUC
	RTS

	CNOP	0,8
ILBM4:
	DC.L	$464F524D,$0002006C,$494C424D,$424D4844,$00000014
	DC.L	$01000400,$00000000,$04000000,$00002C2C,$01400400
	DC.L	$434D4150,$00000030,$000000FF,$000000FF,$000000FF
	DC.L	$1F1F1F27,$27272F2F,$2F373737,$3F3F3F47,$47474F4F
	DC.L	$4F575757,$5F5F5F67,$67676F6F,$6F777777,$43414D47
	DC.L	$00000004,$00021000,$424F4459,$00020000
ILBM8:
	DC.L	$464F524D,$0002033C,$494C424D,$424D4844,$00000014
	DC.L	$01000200,$00000000,$08000000,$00002C2C,$01400200
	DC.L	$434D4150,$00000300,$00000000,$00440000,$990000EE
	DC.L	$22000022,$00442200,$992200EE,$44000044,$00444400
	DC.L	$994400EE,$66000066,$00446600,$996600EE,$88000088
	DC.L	$00448800,$998800EE,$AA0000AA,$0044AA00,$99AA00EE
	DC.L	$CC0000CC,$0044CC00,$99CC00EE,$EE0000EE,$0044EE00
	DC.L	$99EE00EE,$00220000,$22440022,$990022EE,$22220022
	DC.L	$22442222,$992222EE,$44220044,$22444422,$994422EE
	DC.L	$66220066,$22446622,$996622EE,$88220088,$22448822
	DC.L	$998822EE,$AA2200AA,$2244AA22,$99AA22EE,$CC2200CC
	DC.L	$2244CC22,$99CC22EE,$EE2200EE,$2244EE22,$99EE22EE
	DC.L	$00440000,$44440044,$990044EE,$22440022,$44442244
	DC.L	$992244EE,$44440044,$44444444,$994444EE,$66440066
	DC.L	$44446644,$996644EE,$88440088,$44448844,$998844EE
	DC.L	$AA4400AA,$4444AA44,$99AA44EE,$CC4400CC,$4444CC44
	DC.L	$99CC44EE,$EE4400EE,$4444EE44,$99EE44EE,$00660000
	DC.L	$66440066,$990066EE,$22660022,$66442266,$992266EE
	DC.L	$44660044,$66444466,$994466EE,$66660066,$66446666
	DC.L	$996666EE,$88660088,$66448866,$998866EE,$AA6600AA
	DC.L	$6644AA66,$99AA66EE,$CC6600CC,$6644CC66,$99CC66EE
	DC.L	$EE6600EE,$6644EE66,$99EE66EE,$00880000,$88440088
	DC.L	$990088EE,$22880022,$88442288,$992288EE,$44880044
	DC.L	$88444488,$994488EE,$66880066,$88446688,$996688EE
	DC.L	$88880088,$88448888,$998888EE,$AA8800AA,$8844AA88
	DC.L	$99AA88EE,$CC8800CC,$8844CC88,$99CC88EE,$EE8800EE
	DC.L	$8844EE88,$99EE88EE,$00AA0000,$AA4400AA,$9900AAEE
	DC.L	$22AA0022,$AA4422AA,$9922AAEE,$44AA0044,$AA4444AA
	DC.L	$9944AAEE,$66AA0066,$AA4466AA,$9966AAEE,$88AA0088
	DC.L	$AA4488AA,$9988AAEE,$AAAA00AA,$AA44AAAA,$99AAAAEE
	DC.L	$CCAA00CC,$AA44CCAA,$99CCAAEE,$EEAA00EE,$AA44EEAA
	DC.L	$99EEAAEE,$00CC0000,$CC4400CC,$9900CCEE,$22CC0022
	DC.L	$CC4422CC,$9922CCEE,$44CC0044,$CC4444CC,$9944CCEE
	DC.L	$66CC0066,$CC4466CC,$9966CCEE,$88CC0088,$CC4488CC
	DC.L	$9988CCEE,$AACC00AA,$CC44AACC,$99AACCEE,$CCCC00CC
	DC.L	$CC44CCCC,$99CCCCEE,$EECC00EE,$CC44EECC,$99EECCEE
	DC.L	$00EE0000,$EE4400EE,$9900EEEE,$22EE0022,$EE4422EE
	DC.L	$9922EEEE,$44EE0044,$EE4444EE,$9944EEEE,$66EE0066
	DC.L	$EE4466EE,$9966EEEE,$88EE0088,$EE4488EE,$9988EEEE
	DC.L	$AAEE00AA,$EE44AAEE,$99AAEEEE,$CCEE00CC,$EE44CCEE
	DC.L	$99CCEEEE,$EEEE00EE,$EE44EEEE,$99EEEEEE,$43414D47
	DC.L	$00000004,$00021000,$424F4459,$00020000

	CNOP	0,8
ILBMraw:DS.B	4*1024

; -----------------------------------
	CNOP 	0,4
; -----------------------------------

	CNOP	0,4
TAGS0:
	DC.L	$80080002,0
	DC.L	$80080012,tOK
	DC.L	$80080003,165
	DC.L	$80080004,11
	DC.L	$80080006,196
	DC.L	$8008003C,1	; No muestra los "#?.info"
;;	DC.L	$80080009,DirMVD
	DC.L	$80080009,DirPrefs+$080
	DC.L	0

	CNOP	0,4
TAGS1:
	DC.L	$80080002,0
	DC.L	$80080012,tOK
	DC.L	$80080003,165
	DC.L	$80080004,11
	DC.L	$80080006,196
	DC.L	$8008003C,1	; No muestra los "#?.info"
	DC.L	0

	CNOP	0,4
TAGS2:
	DC.L	$80080002,0
	DC.L	$80080012,tOK
	DC.L	$80080003,165
	DC.L	$80080004,11
	DC.L	$80080006,196
	DC.L	$8008003C,1	; No muestra los "#?.info"
;;	DC.L	$80080009,DirCartr
	DC.L	$80080009,DirPrefs+$180
	DC.L	0

	CNOP	0,4
TAGS3:
	DC.L	$80080002,0
	DC.L	$80080012,tOK
	DC.L	$80080003,165
	DC.L	$80080004,11
	DC.L	$80080006,196
	DC.L	$8008003C,1	; No muestra los "#?.info"
;;	DC.L	$80080009,DirTape
	DC.L	$80080009,DirPrefs+$280
	DC.L	0


;	DC.L	$80080001,Texto Ventana
;	DC.L	$80080002,Screen WND donde aparece el requester.
;	DC.L	$80080003,Coor X
;	DC.L	$80080004,Coor Y
;	DC.L	$80080005,Size X
;	DC.L	$80080006,Size Y
;	DC.L	$80080009,Directorio
;	DC.L	$8008000A,Patr�n
;	DC.L	$80080012,Texto Ok
;	DC.L	$80080013,Texto Cancel
;	DC.L	$80080014,Patron On=1/Off=0
;	DC.L	$8008002C,1	; 1=Modo Save.
;	DC.L	$8008003C,1	; 1=No muestra los "#?.info"

	CNOP	0,4
TAGSLoadMVD:
	DC.L	$80080012,tLoad
	DC.L	$80080001,tMVDLoad
	DC.L	$8008002C,0		; 1=Modo Load.
	DC.L	0

TAGSSaveMVD:
	DC.L	$80080012,tSave
	DC.L	$80080001,tMVDSave
	DC.L	$8008002C,1		; 1=Modo Save.
	DC.L	0

TAGSSlot:
	DC.L	$80080012,tLoad
	DC.L	$80080001,tSlot
	DC.L	$8008002C,0		; 1=Modo Load.
	DC.L	0

TAGSVram:
	DC.L	$80080012,tSave
	DC.L	$80080001,tSavVram
	DC.L	$8008002C,1		; 1=Modo Save.
	DC.L	0

TAGSSaveRam:
	DC.L	$80080012,tSave
	DC.L	$80080001,tSavRam
	DC.L	$8008002C,1		; 1=Modo Save.
	DC.L	0

TAGSSprites:
	DC.L	$80080012,tSave
	DC.L	$80080001,tSavSpr
	DC.L	$8008002C,1		; 1=Modo Save.
	DC.L	0

TAGSLoadTape:
	DC.L	$80080012,tLoad
	DC.L	$80080001,tLoadTape
	DC.L	$8008002C,0		; 1=Modo Load.
	DC.L	0

TAGSSaveTape:
	DC.L	$80080012,tSave
	DC.L	$80080001,tSaveTape
	DC.L	$8008002C,1		; 1=Modo Save.
	DC.L	0


	CNOP	0,4
DirMVD:	DC.B	"MVD_Files",0,0
DirCartr:DC.B	"Cartridges",0,0
DirTape:DC.B	"Tape",0,0

	CNOP	0,4
tLOAD:	DC.B	"Load",0,0
tSAVE:	DC.B	"Save",0,0
tOK:	DC.B	"�Ok!",0,0

tMVDLoad:DC.B	"Load MSX Virtual Disk File.",0,0
tMVDSave:DC.B	"Save MSX Virtual Disk File.",0,0
tSlot:	DC.B	"Load MSX Cartridge File.",0,0
tSavVRAM:DC.B	"Save VRAM/Screen.",0,0
tSavRAM:DC.B	"Save MSX RAM.",0,0
tSavSpr:DC.B	"Save Sprites.",0,0
tLoadTape:DC.B	"Load Tape File.",0,0
tSaveTape:DC.B	"Save Tape File.",0,0

; --------------------------------------
; -----------------------------------


;	--------------------------
;	Refresca el Relog interno.
;	--------------------------

	CNOP	0,8
RefrescaReloj:
	LEA	battclockreso(PC),A1
	MOVE.L	$4.w,A6
	JSR	-$1F2(A6)		; Open Resource.
	MOVE.L	D0,A2
	MOVE.L	A2,D0
	BEQ.S	RefRelFin

	LEA	TimeBuffer(PC),A1
	LEA	timerdevice(PC),A0
	MOVEQ	#0,D0
	MOVE.L	D0,D1
	JSR	-$1BC(A6)		; Open Device.
	MOVE.L	D0,D6
	BNE.S	RefRelFin


	MOVEQ	#0,D7
	MOVEQ	#0,D0
	LEA	TimeBuffer(PC),A0
	MOVE.W	D0,$8(A0)
	SUB.L	A1,A1
	MOVE.L	A1,$A(A0)
	MOVE.L	A1,$E(A0)
	CLR.L	$24(A0)

	MOVE.L	A2,A6
	JSR	-$C(A6)
	LEA	TimeBuffer(PC),A0
	MOVE.L	D0,$20(A0)
	MOVE.W	#$B,$1C(A0)
	MOVE.L	A0,A1
	MOVE.L	$4.w,A6
	JSR	-$1C8(A6)		; DoIO.

	LEA	TimeBuffer(PC),A1
;	MOVE.L	$4.w,A6
	JSR	-$1C2(A6)		; Close Device.
RefRelFin:
	RTS

	CNOP	0,8
battclockreso:	DC.B	'battclock.resource',0,0
timerdevice:	DC.B	'timer.device',0,0

	CNOP	0,8
TimeBuffer:	DS.B	$30
***************************************************************

; -----------------------------------
	CNOP	0,8
RINICI:
	LEA	MSXVIRTUALGadgets,A0
	ADD.W	#(GD_Discodev*4),A0
	MOVE.L	(A0),A1
	MOVEQ	#0,D0
	MOVE.B	$57(A1),D0
	MOVE.L	D0,-(SP)
	MOVE.B	D0,D1
	ADD.B	#"0",D1
	MOVE.B	D1,TLEEnodsk+$19

	MOVE.L	$4,A6
	SUB.L	A1,A1
	JSR	-$126(A6)
	LEA	DISKPORT2,A0
	MOVE.L	D0,16(A0)
	MOVE.L	(SP)+,D0	; Unidad de disco.

	LEA	MFMDISK2,A0
	CMP.W	#4,D0		; Mira si es RAMSX:
	BNE.S	RiNoEsRAMSX
	MOVEQ	#2,D0
	LEA	StatDev2,A0
RiNoEsRAMSX:

	MOVEQ	#0,D1
	LEA	DISKIOREQ2,A1
	MOVE.L	#DISKPORT2,14(A1)
	MOVE.L	$4,A6
	JSR	-$1BC(A6)	; Abre device.
	TST.L	D0
	BEQ.S	SIDEVBI
	ADDQ	#4,SP
	LEA	TLEENOPD(PC),A0
	BRA	IMPERROR

	CNOP	0,4
SIDEVBI:
	LEA	DISKIOREQ2,A1	; Mira si hay disco.
	MOVE.W	#14,28(A1)
	MOVE.L	$4.w,A6
	JSR	-$1C8(A6)
	LEA	DISKIOREQ2,A1
	LEA	TLEENODSK(PC),A0
	TST.L	32(A1)
	BNE	ERRSALI

	LEA	DISKIOREQ2,A1		A2=Dir de Mem.
	MOVE.W	#2,28(A1)		Comando Read.
	MOVE.L	#1*$200,36(A1)
	MOVE.L	#0*$200,44(A1)
	MOVE.L	#BUF512,40(A1)
	MOVE.L	$4.w,A6
	JSR	-$1C8(A6)
	TST.L	D0
	RTS

NOESMSXDSK:
	SUBQ	#4,SP
	LEA	TLEENOMSX(PC),A0
ERRSALI:
	ADDQ	#4,SP
ERRSALI2:
	MOVE.L	A0,-(SP)

	LEA	DISKIOREQ2,A1		; Motor OFF.
	MOVE.W	#$9,28(A1)
	MOVE.L	#$0,36(A1)
	MOVE.L	$4,A6
	JSR	-$1C8(A6)

	LEA	DISKIOREQ2,A1		; Cierra Device.
	MOVE.L	$4,A6
	JSR	-$1C2(A6)	
	MOVE.L	(SP)+,A0
	BSR	IMPERROR
	RTS

; --------------------------------------
	CNOP	0,4
LOADDISK:
	BSR	MIRAMVDSA

	MOVE.L	#TMVloaddisk,MSXvirtualNGads+8
	BSR	ABREVIRTUAL

	BSR	RINICI
	BNE	NOESMSXDSK

	MOVE.L	DIRFILE,A1
	MOVE.L	BUCFILE,D0
	BEQ.S	NOHAYMEM4
	MOVE.L	4.W,A6
	JSR	-$D2(A6)		; Libera memoria.
	CLR.L	DIRFILE
	CLR.L	BUCFILE

	SF	MVDMODIFI			; Pasa de grabar!
NOHAYMEM4:

	MOVE.L	#361*1024,BUCFILE
	CMP.B	#$F8,BUF512+$15
	BEQ.S	LODSIM
	MOVE.L	#721*1024,BUCFILE
LODSIM:

	MOVE.L	#$10000,D1
	MOVE.L	BUCFILE,D0
	MOVE.L	4.W,A6
	JSR	-$C6(A6)		; Requiere memoria.
	MOVE.L	D0,DIRFILE
	BNE.S	LDISKCON1

	CLR.L	BUCFILE
	LEA	TLEEMEMORY,A0
	BSR	ERRSALI2		; �Cuidado!

	MOVE.L	#TVD0BEM,A0
	MOVE.L	#MSX2IText7,A1
	BSR	COPYNOM2
	BRA	FINALOAD

LDISKCON1:
	MOVE.L	#"  0 ",TLOADTRA+$10
	BSR	DISMOUSE
	LEA	TLOADTRA,A0
	BSR	IMPDISK
	
	MOVE.L	DIRFILE,A0
	MOVEQ	#0,D1
	MOVE.W	#9,D4
	CMP.L	#361*1024,BUCFILE
	BEQ.S	LODSIM2
	LSL.W	#1,D4
LODSIM2:
	SUBQ.W	#1,D4
	MOVEQ	#0,D3

	SF	DISKERRORES

	MOVE.W	#80-1,D0
LODIBUC2:
	MOVEM.L	D0-D5/A0,-(SP)
	MOVE.L	D3,D0
	BSR	PASDEC
	MOVE.B	8(A0),TLOADTRA+$11
	MOVE.B	9(A0),TLOADTRA+$12
	move.l  LOADDECWnd,a0
	move.b  54(a0),d0
	ext.w   d0
	move.b  55(a0),d1
	ext.w   d1
	move.l  50(a0),a0
	lea     LOADDECTextO(PC),a1
	move.l  _IntuitionBase,a6
	JSR     TallIText
	MOVEM.L	(SP)+,D0-D5/A0

	MOVE.W	D4,D2
LODIBUC:
	MOVEM.L	D0-D5/A0,-(SP)
	LEA	DISKIOREQ2,A1		A2=Dir de Mem.
	MOVE.W	#2,28(A1)		Comando READ.
	MOVE.L	#1*$200,36(A1)
	MOVE.L	D1,44(A1)
	MOVE.L	A0,40(A1)
	MOVE.L	$4.w,A6
	JSR	-$1C8(A6)
; ---
	TST.L	D0
	BEQ.S	NoDSKErrores2
	ST	DISKERRORES
NoDSKErrores2:
; ---
	MOVEM.L	(SP)+,D0-D5/A0
	ADD.W	#$200,A0
	ADD.L	#$200,D1
	DBF	D2,LODIBUC
	ADDQ	#1,D3
	DBF	D0,LODIBUC2

	LEA	DISKIOREQ2,A1		; Motor OFF.
	MOVE.W	#$9,28(A1)
	MOVE.L	#$0,36(A1)
	MOVE.L	$4,A6
	JSR	-$1C8(A6)
	move.l  LOADDECWnd,a0
	BSR	PNORM
	JSR	CLOSELOADDECWINDOW
	BSR	ENAMOUSE

; ---
	TST.B	DISKERRORES(PC)
	BEQ.S	NoDiskErroes
	LEA	TLeeDskErres(PC),A0
	BSR	IMPERROR
NoDiskErroes
; ---

	MOVE.L	REQBASE,A2
	MOVE.L	4(A2),A0
	SF	(A0)

	LEA	BUFERDSK,A0
	MOVE.L	DIRFILE,A1
	MOVE.L	3(A1),(A0)
	MOVE.L	7(A1),4(A0)
	SF	8(A0)
	LEA	MSX2IText7,A1
	BSR	PONOM
	BRA	FINALOAD

; --------------------------------------
	CNOP	0,4
SAVEDISK:
	TST.L	BUCFILE
	BNE.S	SAVEDISC

	LEA	TLEENOFILE,A0
	BSR	IMPERROR
	RTS

	CNOP	0,4
SAVEDISC:
	MOVE.L	#TMVsavedisk,MSXvirtualNGads+8
	BSR	ABREVIRTUAL

	MOVE.B	#$F9,BUF512+$15
	BSR	RINICI

	LEA	DISKIOREQ2,A1		A2=Dir de Mem.
	MOVE.W	#15,28(A1)		Comando ProtStatus.
	MOVE.L	$4.w,A6
	JSR	-$1C8(A6)
	LEA	DISKIOREQ2,A1
	LEA	TLEEPROT(PC),A0
	TST.L	32(A1)
	BNE	ERRSALI2

	MOVE.L	#"  0 ",TSAVETRA+$10
	BSR	DISMOUSE
	LEA	TSAVETRA,A0
	BSR	IMPDISK
	
	CMP.B	#$F9,BUF512+$15
	BEQ.S	SADES2DD

	MOVE.L	DIRFILE,A0
	MOVE.W	#0,D4
	MOVE.L	#(9*$200),D5
	CMP.L	#361*1024,BUCFILE
	BEQ.S	SADES2DDB
; <=----------------
	CMP.B	#$F8,$15(A0)		; Chapuza de 1DD de 720Kb
	BEQ.S	SADES2DDB
; <=----------------

	LEA	DISKIOREQ2,A1		; Motor OFF.
	MOVE.W	#$9,28(A1)
	MOVE.L	#$0,36(A1)
	MOVE.L	$4,A6
	JSR	-$1C8(A6)
	move.l  LOADDECWnd,a0
	BSR	PNORM
	JSR	CLOSELOADDECWINDOW
	BSR	ENAMOUSE
	LEA	TLEEnomsx2D,A0
	BSR	IMPERROR
	RTS

SADES2DD:
	MOVE.L	DIRFILE,A0
	MOVE.W	#0,D4
	MOVE.L	#(18*$200),D5
	CMP.L	#361*1024,BUCFILE
	BEQ.S	SADES2DDB
; <=----------------
	CMP.B	#$F8,$15(A0)		; Chapuza de 1DD de 720Kb
	BEQ.S	SADES2DDB
; <=----------------
	MOVE.W	#1,D4
	MOVE.L	#(9*$200),D5
SADES2DDB:

	MOVEQ	#0,D1
	MOVEQ	#0,D3
	MOVE.W	#80-1,D0
SADIBUC2:
	MOVEM.L	D0-D5/A0,-(SP)
	MOVE.L	D3,D0
	BSR	PASDEC
	MOVE.B	8(A0),TSAVETRA+$11
	MOVE.B	9(A0),TSAVETRA+$12
	move.l  LOADDECWnd,a0
	move.b  54(a0),d0
	ext.w   d0
	move.b  55(a0),d1
	ext.w   d1
	move.l  50(a0),a0
	lea     LOADDECTextO(PC),a1
	move.l  _IntuitionBase,a6
	JSR     TallIText
	MOVEM.L	(SP)+,D0-D5/A0

	MOVE.W	D4,D2
SADIBUC:
	MOVEM.L	D0-D5/A0,-(SP)
	LEA	DISKIOREQ2,A1		A2=Dir de Mem.
	MOVE.W	#11,28(A1)		Comando Format.
	MOVE.L	#9*$200,36(A1)
	MOVE.L	D1,44(A1)
	MOVE.L	A0,40(A1)
	MOVE.L	$4.w,A6
	JSR	-$1C8(A6)
	MOVEM.L	(SP)+,D0-D5/A0
	ADD.W	#(9*$200),A0
	ADD.L	D5,D1			; Seg�n 1DD o 2DD
	DBF	D2,SADIBUC
	ADDQ	#1,D3
	DBF	D0,SADIBUC2

	LEA	DISKIOREQ2,A1		; Motor OFF.
	MOVE.W	#$9,28(A1)
	MOVE.L	#$0,36(A1)
	MOVE.L	$4,A6
	JSR	-$1C8(A6)
	move.l  LOADDECWnd,a0
	BSR	PNORM
	JSR	CLOSELOADDECWINDOW
	BSR	ENAMOUSE

	SF	MVDMODIFI		; MVD ya grabado.
	
	RTS

; --------------------------------------
	CNOP	0,4
ABREVIRTUAL:
	BSR	DISMOUSE

	LEA	MSXVIRTUALGTags,A0
	MOVE.W	#GD_Discodev,D0
	MOVE.L	#$8008000F,D1
	MOVEQ	#0,D2
	LEA	DIRPrefs(PC),a5
	MOVE.B	$60(A5),D2
	BSR	ACTUTAGS

	MOVEM.L	MCEROS(PC),D0-D7/A0-A6
	JSR	OPENMSXVIRTUALWINDOW

	LEA	MSXVIRTUALPUNTS,A1
	BSR	CONTROL

	LEA	MSXVIRTUALGadgets,A0
	ADD.W	#(GD_Discodev*4),A0
	MOVE.L	(A0),A1
	LEA	DIRPrefs(PC),a5
	MOVE.B	$57(A1),$60(A5)

	JSR	CLOSEMSXVIRTUALWINDOW
	BSR	ENAMOUSE
	ADD.W	#4,SP
	RTS

INSTALARCON:
	ADD.W	#16+4,SP
	LEA	MSXVIRTUALGadgets,A0
	ADD.W	#(GD_Discodev*4),A0
	MOVE.L	(A0),A1
	LEA	DIRPrefs(PC),a5
	MOVE.B	$57(A1),$60(A5)
	JSR	CLOSEMSXVIRTUALWINDOW
	BSR	ENAMOUSE
	RTS
; --------------------------------------
	CNOP	0,4
INSTALAR:
	MOVE.L	#TMVInstalar,MSXvirtualNGads+8
	BSR	ABREVIRTUAL

	BSR	RINICI
	BNE	NOESMSXDSK

	LEA	DISKIOREQ2,A1		A2=Dir de Mem.
	MOVE.W	#15,28(A1)		Comando ProtStatus.
	MOVE.L	$4.w,A6
	JSR	-$1C8(A6)
	LEA	DISKIOREQ2,A1
	LEA	TLEEPROT(PC),A0
	TST.L	32(A1)
	BNE	ERRSALI2

	BSR	DISMOUSE
	LEA	TINSTALL,A0
	BSR	IMPDISK

	LEA	DISKIOREQ2,A1		; Motor OFF.
	MOVE.W	#$9,28(A1)
	MOVE.L	#$0,36(A1)
	MOVE.L	$4,A6
	JSR	-$1C8(A6)


	LEA	BOOT1DD,A0
	CMP.B	#$02,DirPrefs+$6D
	BEQ.S	INSSIM
	LEA	BOOT2DD,A0
	CMP.B	#$04,DirPrefs+$6D
	BEQ.S	INSSIM

	LEA	BOOT1DD,A0
	CMP.B	#$F8,BUF512+$15
	BEQ.S	INSSIM
	LEA	BOOT2DD,A0
INSSIM:

	LEA	DISKIOREQ2,A1		A2=Dir de Mem.
	MOVE.W	#3,28(A1)		Comando Write.
	MOVE.L	#1*$200,36(A1)
	MOVE.L	#0*$200,44(A1)
	MOVE.L	A0,40(A1)
	MOVE.L	$4.w,A6
	JSR	-$1C8(A6)

	LEA	DISKIOREQ2,A1		A2=Dir de Mem.
	MOVE.W	#4,28(A1)		Comando UpDate.
	MOVE.L	#1*$200,36(A1)
	MOVE.L	#0*$200,44(A1)
	MOVE.L	$4.w,A6
	JSR	-$1C8(A6)

	LEA	DISKIOREQ2,A1		; Motor OFF.
	MOVE.W	#$9,28(A1)
	MOVE.L	#$0,36(A1)
	MOVE.L	$4,A6
	JSR	-$1C8(A6)

	LEA	DISKIOREQ2,A1		; Cierra Device.
	MOVE.L	$4,A6
	JSR	-$1C2(A6)	

	move.l  LOADDECWnd,a0
	BSR	PNORM
	JSR	CLOSELOADDECWINDOW
	BSR	ENAMOUSE
	RTS
; -----------------------------------
InternalError:
	LEA	tErInterError,A0
	BSR	ImpError
	BRA.S	InternalError
; -----------------------------------
IMPERROR:
	MOVE.L	A0,ERRDIRTXT
	BSR	DISMOUSE
	MOVEM.L	MCEROS(PC),D0-D7/A0-A6
	JSR	OPENERRORWINDOW
	move.l  ErrorWnd,a0
	move.b  54(a0),d0
	ext.w   d0
	move.b  55(a0),d1
	ext.w   d1
	move.l  50(a0),a0
	lea     ErrorTextO(PC),a1
	move.l  _IntuitionBase,a6
	JSR     TallIText
	LEA	ERRORPUNTS,A1
	BSR	CONTROL
	JSR	CLOSEERRORWINDOW
	BSR	ENAMOUSE
	RTS
	CNOP	0,4
ErrorTextO:
    DC.B    4,0
    DC.B    $01
    DC.B    0
    DC.W    14,12
    DC.L    topaz8
ERRDIRTXT:
    DC.L    TLEEnomfm
    DC.L    0
	CNOP	0,4
TLEEnomfm:	DC.B	"   I need DEVS:mfm.device!    ",0
TLEENOPD:	DC.B	"     I can't open device      ",0
TLEEnodsk:	DC.B	"  I need a MSX disk in DF0:   ",0
TLEEprot:	DC.B	"   Disk is write-protected    ",0
TLEEnomsx:	DC.B	"  I need a MSX Format disk!   ",0
TLEEnomsx2D:	DC.B	" I need a MSX 2DD Format disk ",0
TLEETIEMPO:	DC.B	"  --=>  OUT  OF  TIME!  <=--  ",0
TLEEMEMORY:	DC.B	"  --=>  Out of memory!  <=--  ",0
TLEECHECK:	DC.B	"   MSX ROM  Checksum error!   ",0
TLEESTACK:	DC.B	"    MSX's Stack gets crazy!   ",0
TLEEprefs:	DC.B	"    Preferences not saved!    ",0
TLEENOTMD:	DC.B	"     Not a MSX Disk File.     ",0
TLEECANTO:	DC.B	"      I Can't open file.      ",0
TLEEDKB:	DC.B	" Drive B: 360K/720K DSK only. ",0
TLEEREAD:	DC.B	"   File read error: aborted.  ",0
TLEENOFILE:	DC.B	"     MVD: buffer is empty.    ",0
TLEENOASL:	DC.B	"   I can't open ASL.library.  ",0
TLeeDskErres:	DC.B	"CAUTION: Some Sectors are bad!",0
TLeeNOcart:	DC.B	"    Bad MSX cartridge Size.   ",0
TLEENOSavVram:	DC.B	"I can't save this screen mode!",0
TLEENOSavSpr:	DC.B	"  I can't save MSX1 Sprites!  ",0
TLeeEsROM:	DC.B	"      This Page is ROM!!      ",0
TLeeNoTapeBuf:	DC.B	"     Tape buffer is empty.    ",0
TLeeNoTape:	DC.B	"       Not a Tape File.       ",0
TLEENOCarID:	DC.B	"  I cannot find Cartridge ID  ",0
TLeeNoROM:	DC.B	"  I can't open MSX ROM file.  ",0
TLeeNoROMFileD:	DC.B	"ROM_Files Directory not found!",0
TLeePowerON:	DC.B	" Please,  Power ON MSX first! ",0

tErMVDModif:	DC.B	"   MVD:  has been modified!   ",0
tErNoCheats:	DC.B	" Power ON with Cheats enabled!",0
tErInterError:	DC.B	"       Internal Error!!       ",0
tErNoMSX2data:	DC.B	"   AmiMSX2.data  not found!   ",0
tErNoMasMapper:	DC.B	" I cannot save more mappers!! ",0
tErNoKeyFile:	DC.B	" I  NEED  S:AmiMSX2.key  file ",0



	CNOP	0,4
TMVinstalar:	dc.b	"Install",0
TMVloaddisk:	dc.b	"Load",0
TMVsavedisk:	dc.b	"Save",0

; -----------------------------------

; -----------------------------------
	CNOP	0,4
IMPDISK:
	MOVE.L	A0,LOADDECDIRTXT
	MOVEM.L	MCEROS(PC),D0-D7/A0-A6
	JSR	OPENLOADDECWINDOW

	move.l  LOADDECWnd,a0
	BSR	PBUSY

	move.l  LOADDECWnd,a0
	move.b  54(a0),d0
	ext.w   d0
	move.b  55(a0),d1
	ext.w   d1
	move.l  50(a0),a0
	lea     LOADDECTextO(PC),a1
	move.l  _IntuitionBase,a6
	JSR     TallIText
	RTS

	CNOP	0,4
LoaddecTextO:
    DC.B    7,0
    DC.B    $01
    DC.B    0
    DC.W    17,10
    DC.L    topaz8
LOADDECDIRTXT:
    DC.L    LoaddecIText0
    DC.L    0

	CNOP	0,4
TLOADNOR:	DC.B	"Loading MSX Disk File",0
TLOADDEC:	DC.B	"Loading & Decrunching",0
TSAVEDEC:	DC.B	"Saving MSX Disk File.",0
TSAVEVRAM:	DC.B	" Saving VRAM/Screen  ",0
TSAVESprites:	DC.B	"   Saving Sprites    ",0
TLOADTRA:	DC.B	"  Loading Track: 00  ",0
TSAVETRA:	DC.B	"  Saving  Track: 00  ",0
TVERITRA:	DC.B	" Verifing Track: 00  ",0
TINSTALL:	DC.B	" Installing MSX Disk ",0
TSaveTape2:	DC.B	" Saving Tape Buffer. ",0
TLoadTape2:	DC.B	" Loading Tape Buffer ",0

	DS.L	8
; -----------------------------------

; -----------------------------------
	CNOP	0,8
LoadROMsBase:
	MOVE.L	#AmiMSX2Data,D1
	MOVE.L	#$3ED,D2
	BSR	OpenFile
	BEQ.S	LoadROMsBaseEr

	MOVE.L	#DirBaseROM,D2
	MOVE.L	#(16*4),D3
	BSR	ReadFile
	BNE.S	LoadROMsBaseEr

	ST	LoROMBaDat		; ROMs Base Leido Correctamente.

LoadROMsBaseEr:
	BSR	CloseFile
	RTS

	CNOP	0,8
AmiMSX2Data:	DC.B	"PROGDIR:AmiMSX2.data",0,0
	CNOP	0,8
AmiMSX2Mapper:	DC.B	"PROGDIR:AmiMSX2.mapper",0,0

	CNOP	0,8
		DS.L	2
DirBaseROM:	DS.L	16
		DS.L	6
; -----------------------------------

; -----------------------------------
	CNOP	0,8
LoadROMs:

	BSR	LoadROMsBase

	TST.B	LoROMBaDat(PC)		; �ROMs Base Leido Correctamente?
	BNE.S	LoadROMsRut
	RTS

LoadROMsRut:
	MOVE.L	#AmiMSX2Data,D1
	MOVE.L	#$3ED,D2
	BSR	OpenFile
	BEQ	NoHayROMs
;	--------------
	LEA	DIRPrefs,A5
	CLAMPM
	MOVEQ	#0,D0
	MOVE.B	$10(A5),D0				; Tipo ROM.
	CMP.B	ActuROM,D0
	BEQ.s	YaEstaROM

	LEA	(DirBaseROM+$18.W,PC,D0.W*4),A0
	MOVE.L	(A0),D2
	ADD.L	#$40,D2		; Suma ROMs Base buffer.

	MOVE.L	A0,-(SP)

	MOVEQ	#-1,D3		; Seek Beginnig.
	MOVE.L	DisBase(PC),D1
	MOVE.L	_DosBase(PC),A6
	JSR	-$42(A6)	; Seek (file,position,offset)(D1/D2/D3)

	MOVE.L	(SP)+,A0

	MOVE.L	4(A0),D3
	SUB.L	(A0),D3		; Size.
	MOVE.L	D3,-(SP)

	MOVE.L	#DirROM,D2
	BSR	ReadFile

	MOVE.L	(SP)+,D0
	LEA	DirROM,A0
	BSR	DesenCript

	MOVE.B	$10(A5),ActuROM		; Tipo ROM.
YaEstaROM:
;	--------------
	LEA	DIRPrefs,A5
	MOVEQ	#0,D0
	MOVE.B	$65(A5),D0				; Tipo DOS.
	CMP.B	ActuDOS,D0
	BEQ.S	NoHayDOSs
	CMP.B	#2,D0
	BEQ.S	NoHayDOSs

	LEA	(DirBaseROM+$10.W,PC,D0.W*4),A0
	MOVE.L	(A0),D2
	ADD.L	#$40,D2		; Suma ROMs Base buffer.

	MOVE.L	A0,-(SP)

	MOVEQ	#-1,D3		; Seek Beginnig.
	MOVE.L	DisBase(PC),D1
	MOVE.L	_DosBase(PC),A6
	JSR	-$42(A6)	; Seek (file,position,offset)(D1/D2/D3)

	MOVE.L	(SP)+,A0

	MOVE.L	4(A0),D3
	SUB.L	(A0),D3		; Size.
	MOVE.L	D3,-(SP)

	MOVE.L	#DirDOS,D2
	BSR	ReadFile

	MOVE.L	(SP)+,D0
	LEA	DirDOS,A0
	BSR.S	DesenCript

	MOVE.B	$65(A5),ActuDOS		; Tipo DOS.

	LEA	DirDOS,A0
	MOVE.L	A0,A1
	BSR	Explode
NoHayDOSs:
;	--------------
	BSR	CloseFile
;	--------------
	LEA	DirROM,A0
	MOVE.L	A0,A1
	BSR	Explode
;	--------------
NoHayROMs:
	RTS
; -----------------------------------

; -----------------------------------
	CNOP	0,4
DesenCript:
	MOVE.L	#$17DB03A5,D1		; Password.
	LSR.L	#2,D0
	SUBQ.W	#1,D0
DesenCriptBuc:
	EOR.L	D1,(A0)+
	DBF	D0,DesenCriptBuc
	RTS
; -----------------------------------

; -----------------------------------
	CNOP	0,4
LoadKanji:
	TST.B	DirPrefs+$7B(PC)	; �Usar Kanji ROM?
	BEQ	AmiRET
	TST.B	KanjiDat(PC)		; �Est� ya residente?
	BNE	AmiRET


	MOVE.L	#AmiMSX2Data,D1
	MOVE.L	#$3ED,D2
	BSR	OpenFile
	BEQ	KanNoAmiData

	MOVE.L	#$00010001,D1
	MOVE.L	#(128*1024),D0		; 128Kb
	MOVE.L	D0,BucKanji
	MOVE.L	4.W,A6
	JSR	-$C6(A6)		; Requiere memoria.
	MOVE.L	D0,DirKanji
	BEQ	KanOutOfMem

	LEA	DirBaseROM+$24(PC),A0
	MOVE.L	(A0),D2
	ADD.L	#$40,D2		; Suma ROMs Base buffer.

	MOVE.L	A0,-(SP)

	MOVEQ	#-1,D3		; Seek Beginnig.
	MOVE.L	DisBase(PC),D1
	MOVE.L	_DosBase(PC),A6
	JSR	-$42(A6)	; Seek (file,position,offset)(D1/D2/D3)

	MOVE.L	(SP)+,A0

	MOVE.L	4(A0),D3
	SUB.L	(A0),D3		; Size.
	MOVE.L	D3,-(SP)

	MOVE.L	DirKanji,D2
	BSR	ReadFile

	MOVE.L	(SP)+,D0
	MOVE.L	DirKanji,A0
	BSR	DesenCript

	MOVE.L	DirKanji,A0
	MOVE.L	A0,A1
	BSR	Explode

	ST	KanjiDat
KanOutOfMem:
	BSR	CloseFile
KanNoAmiData:
	RTS
; -----------------------------------


; -----------------------------------
LoadMapperID:
	CLR.L	MapperIDBuf+$08		; Borra lo de "mapp"
	CLR.W	MapperIDInit+$10	; Borra N� de mappers guardados.

	MOVE.L	BucMapper(PC),D0
	BEQ.S	NoHayMapper2
	MOVE.L	DirMapper(PC),A1
	MOVE.L	$4.W,A6
	JSR	-$D2(A6)		; Libera memoria.
	CLR.L	DirMapper
	CLR.L	BucMapper
NoHayMapper2:

	MOVE.L	#AmiMSX2mapper,D1
	MOVE.L	#$3ED,D2
	BSR	OpenFile
	BEQ	NoAmiMapp

	MOVE.L	#MapperIDBuf,D2
	MOVE.L	#($18),D3
	BSR	ReadFile

	CMP.L	#"Mapp",MapperIDBuf+$08
	BNE.S	MappOutOfMem

	MOVEQ	#0,D0
	MOVE.W	MapperIDBuf+$10,D0	; N� de mappers guardados.
	LSL.L	#2,D0

	MOVE.L	#$00010001,D1
	MOVE.L	D0,BucMapper
	MOVE.L	4.W,A6
	JSR	-$C6(A6)		; Requiere memoria.
	MOVE.L	D0,DirMapper
	BEQ.S	MappOutOfMem

	MOVE.L	DirMapper,D2
	MOVE.L	BucMapper,D3
	BSR	ReadFile

	MOVE.W	MapperIDBuf+$10,MapperIDInit+$10  ; N� de mappers guardados.

MappOutOfMem:
	BSR	CloseFile
NoAmiMapp:
	RTS

	CNOP	0,4
MapperIdBuf:
	DC.B	"AmiMSX2",0	; $00
	DC.B	"Mappers",0	; $08	Size = $18
	DC.W	0,0		; $10
	DC.L	0		; $14

	CNOP	0,4
MapperIdInit:
	DC.B	"AmiMSX2",0	; $00
	DC.B	"Mappers",0	; $08	Size = $18
	DC.W	0,0		; $10
	DC.L	0		; $14

	DC.L	0
; -----------------------------------


; -----------------------------------
; Workbench start (A2 = WBStartup): if the last argument's icon (the project
; icon a preset was started from, or AmiMSX's own icon) has a PREFS=<file>
; ToolType, that file replaces S:AmiMSX2.prefs for loading and saving.
; A relative name is taken from the icon's drawer.
; D5 = IconBase, D4 = DiskObject, A2 = WBArg.
	CNOP	0,4
WBToolTypes:
	MOVEM.L	D2-D5/A2/A6,-(SP)
	MOVE.L	$1C(A2),D2		; sm_NumArgs
	BEQ	WBTTRet
	MOVE.L	$24(A2),A2		; sm_ArgList
	SUBQ.L	#1,D2
	LSL.L	#3,D2
	ADD.L	D2,A2			; Last WBArg.
	MOVEQ	#0,D0
	LEA	ICONNOM(PC),A1
	MOVE.L	4.W,A6
	JSR	-$228(A6)		; OpenLibrary
	MOVE.L	D0,D5
	BEQ	WBTTRet
	MOVE.L	(A2),D1			; wa_Lock
	MOVE.L	_DOSBASE,A6
	JSR	-$7E(A6)		; CurrentDir
	MOVE.L	4(A2),A0		; wa_Name
	MOVE.L	D5,A6
	JSR	-$4E(A6)		; GetDiskObject
	MOVE.L	D0,D4
	BEQ	WBTTClose
	MOVE.L	D4,A0			; (4.5) RTG: the RTG display (RtgInit).
	MOVE.L	$36(A0),A0
	LEA	TTRTG(PC),A1
	JSR	-$60(A6)		; FindToolType
	TST.L	D0
	BEQ.S	WBTTNoRtg
	ST	RtgWant
WBTTNoRtg:
	MOVE.L	D4,A0			; (4.5) SCANLINES[=n]: on the RTG play
	MOVE.L	$36(A0),A0		; screen at 2x every second row n%
	LEA	TTSCAN(PC),A1		; darker (no value: 50; at most 90),
	JSR	-$60(A6)		; or blended: SCANLINES=blendlight,
	TST.L	D0			; blend or blendstrong (any case).
	BEQ.S	WBTTNoSc		; (A choice in the prefs, PrefScan,
	MOVE.L	D0,A0			; wins: PONPREFS.)
	JSR	ScanWord
	TST.B	D0
	BEQ.S	WBTTScW
	JSR	ScanSet
	BRA.S	WBTTNoSc
WBTTScW:MOVEQ	#0,D0
	MOVEQ	#0,D1
	MOVEQ	#0,D2
WBTTSc:	MOVE.B	(A0)+,D1
	SUB.B	#'0',D1
	CMP.B	#9,D1
	BHI.S	WBTTScE
	MULU.W	#10,D0
	ADD.W	D1,D0
	ADDQ.W	#1,D2
	CMP.W	#3,D2
	BCS.S	WBTTSc
WBTTScE:TST.W	D2
	BNE.S	WBTTScN
	MOVEQ	#50,D0
WBTTScN:CMP.W	#90,D0
	BLS.S	WBTTScS
	MOVEQ	#90,D0
WBTTScS:MOVE.B	D0,RtgScan
	SF	RtgBlnd
WBTTNoSc:
	MOVE.L	D4,A0
	MOVE.L	$36(A0),A0		; do_ToolTypes
	LEA	TTPREFS(PC),A1
	JSR	-$60(A6)		; FindToolType
	MOVE.L	D0,D2
	BEQ.S	WBTTFree
	MOVE.L	D0,A0
	TST.B	(A0)
	BEQ.S	WBTTFree
	MOVE.L	_DOSBASE,A6
	MOVE.L	(A2),D1			; The icon's drawer...
	BEQ.S	WBTTName
	MOVE.L	D2,-(SP)
	MOVE.L	#NomPrefs,D2
	MOVE.L	#NOMPREFSLEN,D3
	JSR	-$192(A6)		; NameFromLock
	MOVE.L	(SP)+,D2
	TST.L	D0
	BEQ.S	WBTTName
	MOVE.L	#NomPrefs,D1		; ...plus the name (AddPart keeps
	MOVE.L	#NOMPREFSLEN,D3		; an absolute name as it is).
	JSR	-$372(A6)		; AddPart
	TST.L	D0
	BNE.S	WBTTFree
WBTTName:
	MOVE.L	D2,A0			; No drawer name: the name as given.
	LEA	NomPrefs,A1
	MOVE.W	#NOMPREFSLEN-2,D0
WBTTCopy:
	MOVE.B	(A0)+,(A1)+
	DBEQ	D0,WBTTCopy
	CLR.B	(A1)
WBTTFree:
	MOVE.L	D5,A6
	MOVE.L	D4,A0
	JSR	-$5A(A6)		; FreeDiskObject
WBTTClose:
	MOVE.L	D5,A1
	MOVE.L	4.W,A6
	JSR	-$19E(A6)		; CloseLibrary
WBTTRet:
	MOVEM.L	(SP)+,D2-D5/A2/A6
	RTS

ICONNOM:
	DC.B	"icon.library",0
TTPREFS:
	DC.B	"PREFS",0
TTRTG:	DC.B	"RTG",0
TTSCAN:	DC.B	"SCANLINES",0

; -----------------------------------
	CNOP	0,4
LOADPREFS:
	MOVE.L	#NomPrefs,D1
	MOVE.L	#1005,D2
	BSR	OPENFILE
;;	BNE.S	PREFCont
;;
;;	MOVE.L	#NomPrefsOld,D1
;;	MOVE.L	#1005,D2
;;	BSR	OPENFILE
	BEQ.S	PREFSRET
PREFCont:
	MOVE.L	#BUFPREFS,D2
	MOVE.L	#BUCPREFS,D3
	BSR	READFILE
;;	BNE	CLOSEFILE

	BSR	CLOSEFILE
	LEA	BUFPREFS,A0
	CMP.L	#"MSX2",(A0)
	BNE.S	PREFSRET
	CMP.L	#"v2.5",4(A0)
	BEQ.S	PREFSOK
;-;	CMP.L	#"v2.3",4(A0)
;-;	BEQ.S	PREFv23
PREFSRET:
	RTS
PREFSOK:
	MOVE.L	#"v2.5",4(A0)
	LEA	DIRPREFS,A1
	MOVE.W	#BUCPREFS-1,D0
COPIPREFS:
	MOVE.B	(A0)+,(A1)+
	DBF	D0,COPIPREFS
	RTS

PREFv23:
	MOVE.L	#"v2.5",4(A0)
	LEA	DIRPREFS,A1
	MOVE.W	#$6A-1,D0
COPIPREF23:
	MOVE.B	(A0)+,(A1)+
	DBF	D0,COPIPREF23
	RTS


	CNOP	0,4
SAVEPREFS:
	BSR	ACTUPREFS

	MOVE.W	DirPrefs+$74(PC),D0
	ROR.W	#5,D0
	ADDQ.W	#1,D0
	ROL.W	#5,D0
	MOVE.W	D0,DirPrefs+$74

	TST.B	GPActive		; A game's settings in force: write the
	BEQ.S	SavePrefsG		; global ones (and keep the game's).
	LEA	GPTmp,A1
	BSR	GPFromPrefs
	LEA	GPSaved,A1
	BSR	GPToPrefs
SavePrefsG:
	MOVE.L	#NOMPREFS,D1
	MOVE.L	#1006,D2
	BSR	OPENFILE
	BEQ.S	SavePrefsE

	MOVE.L	#DIRPREFS,D2
	MOVE.L	#BUCPREFS,D3
	BSR	WRITEFILE
	SNE	GPOk
	BSR	SavePrefsBack
	TST.B	GPOk
	BNE.S	ERDEVICE2

	BSR	CLOSEFILE
	RTS
SavePrefsE:
	BSR	SavePrefsBack
	BRA.S	ERDEVICE2
SavePrefsBack:
	TST.B	GPActive
	BEQ.S	SavePrefsB1
	LEA	GPTmp,A1
	BSR	GPToPrefs
SavePrefsB1:
	RTS
GPTmp:	DS.B	GP_LEN
	EVEN

	CNOP	0,4
ERDEVICE2:
	BSR	CLOSEFILE
	LEA	TLEEprefs(PC),A0
	BRA	IMPERROR
	RTS

	CNOP	0,8
NOMPREFSLEN=256
NomPrefs:
	DC.B	"S:AmiMSX2.prefs",0	; Or the PREFS ToolType (WBToolTypes).
	DS.B	NOMPREFSLEN-16
	CNOP	0,8
NomPrefsOld:
	DC.B	"S:MSX2emulator.prefs",0,0,0,0

	CNOP	0,4
; -----------------------------------
OPENFILE:
	MOVE.L	_DOSBASE,A6
	JSR	-30(A6)			; OPEN
	MOVE.L	D0,DISBASE
	RTS
CLOSEFILE:
	MOVE.L	_DOSBASE,A6
	MOVE.L	DISBASE,D1
	BEQ.S	CLOSEFNo		; (4.0, as v3.2: no file open, no Close)
	JSR	-36(A6)			; CLOSE
	CLR.L	DISBASE
CLOSEFNo:
	RTS
WRITEFILE:
	MOVE.L	_DOSBASE,A6
	MOVE.L	DISBASE,D1
	MOVE.L	D3,-(SP)
	JSR	-48(A6)			; WRITE
	MOVE.L	(SP)+,D3
	CMP.L	D0,D3
	RTS
; D2 = buffer, D3 = bytes. Reads until all are in, the end of the file or an
; error: AmigaDOS Read may return fewer bytes than asked, and a short or
; failed read of a disk image left the MSX booting a partly empty disk.
; Out: D0 = bytes read, Z set if all of them.
READFILE:
	MOVEM.L	D2-D4,-(SP)
	MOVE.L	D3,D4			; Bytes still to read.
RFBuc:	TST.L	D4
	BEQ.S	RFFin
	MOVE.L	_DOSBASE,A6
	MOVE.L	DISBASE,D1
	MOVE.L	D4,D3
	JSR	-42(A6)			; READ
	TST.L	D0
	BLE.S	RFFin			; End of file (0) or error (-1).
	ADD.L	D0,D2
	SUB.L	D0,D4
	BRA.S	RFBuc
RFFin:	MOVE.L	4(SP),D0		; Bytes asked (the saved D3)...
	SUB.L	D4,D0			; ...less those not read.
	MOVEM.L	(SP)+,D2-D4
	CMP.L	D0,D3
	RTS

; -----------------------------------
	CNOP	0,4
PONOM:
	MOVE.L	A1,A2
NTXTYA0:
	TST.B	(A2)
	BEQ.S	COPYNOM2
	MOVE.B	#" ",(A2)+
	BRA.S	NTXTYA0
	CNOP	0,4
COPYNOM2:
	MOVE.B	(A0)+,D0
	BEQ.S	PONOMS
	TST.B	(A1)
	BEQ.S	PONOMS
	MOVE.B	D0,(A1)+
	BRA.S	COPYNOM2
PONOMS:	RTS
	CNOP	0,4
COPYNOM:
	MOVE.B	(A0)+,(A1)+
	DBEQ	D0,COPYNOM
	RTS
; -----------------------------------
	CNOP	0,4
ArreglaNom:
	LEA	FILENOM(PC),A1
	MOVE.W	#$100-1,D0
	MOVE.L	8(A2),A0
	TST.B	(A0)
	BEQ.S	CHAPUZRut
	BSR	COPYNOM
	SUBQ	#1,A1
	CMP.B	#":",-1(A1)
	BEQ.S	CHAPUZRut
	MOVE.B	#"/",(A1)+
CHAPUZRut:
	MOVE.W	#$100-1,D0
	MOVE.L	4(A2),A0
	BSR	COPYNOM
	RTS
; -----------------------------------
BootTypeCheck:
	MOVE.B	#$01,DirPrefs+$6D
	MOVE.L	#MN_BootAuto,D0
	BSR	COGECHECK
	BSET	#0,$C(A0)
	MOVE.L	#MN_Boot1DD,D0
	BSR	COGECHECK
	BCLR	#0,$C(A0)
	MOVE.L	#MN_Boot2DD,D0
	BSR	COGECHECK
	BCLR	#0,$C(A0)
	RTS
BootType1DD:
	MOVE.B	#$02,DirPrefs+$6D
	MOVE.L	#MN_BootAuto,D0
	BSR	COGECHECK
	BCLR	#0,$C(A0)
	MOVE.L	#MN_Boot1DD,D0
	BSR	COGECHECK
	BSET	#0,$C(A0)
	MOVE.L	#MN_Boot2DD,D0
	BSR	COGECHECK
	BCLR	#0,$C(A0)
	RTS
BootType2DD:
	MOVE.B	#$04,DirPrefs+$6D
	MOVE.L	#MN_BootAuto,D0
	BSR	COGECHECK
	BCLR	#0,$C(A0)
	MOVE.L	#MN_Boot1DD,D0
	BSR	COGECHECK
	BCLR	#0,$C(A0)
	MOVE.L	#MN_Boot2DD,D0
	BSR	COGECHECK
	BSET	#0,$C(A0)
	RTS
; -----------------------------------
	CNOP	0,4
PONPREFS:
	LEA	DIRPrefs,A5

	LEA	MSX2GTags,A0
	MOVE.W	#GD_ROM,D0
	MOVE.L	#$8008000F,D1
	MOVEQ	#0,D2
	CLAMPM
	MOVE.B	$10(A5),D2
	BSR	ACTUTAGS

	LEA	MSX2GTags,A0
	MOVE.W	#GD_SCRMODE,D0
	MOVE.L	#$8008000F,D1
	MOVEQ	#0,D2
	MOVE.B	$11(A5),D2
	BSR	ACTUTAGS

	LEA	MSX2GTags,A0
	MOVE.W	#GD_INTER,D0
	MOVE.L	#$8008000F,D1
	MOVEQ	#0,D2
	MOVE.W	$14(A5),D2
	BSR	ACTUTAGS

	LEA	MSX2GTags,A0
	MOVE.W	#GD_MSX2Spr,D0
	MOVE.L	#$8008000F,D1
	MOVEQ	#0,D2
	MOVE.W	$16(A5),D2
	BSR	ACTUTAGS

	LEA	MSX2GTags,A0
	MOVE.W	#GD_DRIVEA,D0
	MOVE.L	#$8008000F,D1
	MOVEQ	#0,D2
	MOVE.B	$18(A5),D2
	BSR	ACTUTAGS

	LEA	MSX2GTags,A0
	MOVE.W	#GD_DRIVEB,D0
	MOVE.L	#$8008000F,D1
	MOVEQ	#0,D2
	MOVE.B	$19(A5),D2
	BSR	ACTUTAGS

	LEA	MSX2GTags,A0
	MOVE.W	#GD_DiskVER,D0
	MOVE.L	#$8008000F,D1
	MOVEQ	#0,D2
	MOVE.B	$65(A5),D2
	BSR	ACTUTAGS

;	LEA	MSX2GTags,A0		; Slider Velocidad.
;	MOVE.W	#GD_VELOZ,D0
;	MOVE.L	#$80080028,D1
;	MOVEQ	#0,D2
;	MOVE.W	$1A(A5),D2
;	BSR	ACTUTAGS

	LEA	MSX2GTags,A0
	MOVE.W	#GD_RAM,D0
	MOVE.L	#$8008000F,D1
	MOVEQ	#0,D2
	MOVE.B	$1C(A5),D2
	BSR	ACTUTAGS

	LEA	MSX2GTags,A0
	MOVE.W	#GD_SOUND,D0
	MOVE.L	#$8008000F,D1
	MOVEQ	#0,D2
	MOVE.B	$1D(A5),D2
	BSR	ACTUTAGS

	LEA	MSXVIRTUALGTags,A0
	MOVE.W	#GD_Discodev,D0
	MOVE.L	#$8008000F,D1
	MOVEQ	#0,D2
	MOVE.B	$60(A5),D2
	BSR	ACTUTAGS



	MOVE.B	$13(A5),D0
	BFINS	D0,MSX2NewMenu17+10{7:1}	; JoyStick On.

	MOVE.B	$6A(A5),D0
	BFINS	D0,MSX2NewMenu18+10{7:1}	; Swap JoyPorts.

	MOVE.B	PrefCD32,D0			; (4.1.1) JoyPort 2 pad: CD32 pad
	BFINS	D0,MSX2NewMenu18c+10{7:1}	; or Standard (one of the two).
	NOT.B	D0
	BFINS	D0,MSX2NewMenu18b+10{7:1}
	MOVE.B	PrefCD32M,D0			; JoyPort 1 pad.
	BFINS	D0,MSX2NewMenu18f+10{7:1}
	NOT.B	D0
	BFINS	D0,MSX2NewMenu18e+10{7:1}
; -=-
	MOVE.B	$12(A5),D0
	BFINS	D0,MSX2NewMenu20+10{7:1}	; M-Key.

	MOVE.B	$1E(A5),D0
	BFINS	D0,MSX2NewMenu21+10{7:1}	; DEL como pausa.

	MOVE.B	$62(A5),D0
	BFINS	D0,MSX2NewMenu22+10{7:1}	; L.Shift as Space

	MOVE.B	$63(A5),D0
	BFINS	D0,MSX2NewMenu23+10{7:1}	; R.Shift as Space
; -=-
	MOVE.B	$7A(A5),D0
	BFINS	D0,MSX2NewMenu25+10{7:1}	; Use Japanese ID

	MOVE.B	$7B(A5),D0
	BFINS	D0,MSX2NewMenu26+10{7:1}	; Use Kanji ROM
; -=-
	MOVE.B	$61(A5),D0
	BFINS	D0,MSX2NewMenu29+10{7:1}	; MVD Write Protected.

	MOVE.B	$78(A5),D0
	BFINS	D0,MSX2NewMenu31+10{7:1}	; Avisar al intentar Escribir.

	MOVE.B	$79(A5),D0
	BFINS	D0,MSX2NewMenu32+10{7:1}	; Avisar al Salir si MVD modificado.
; -=-
	MOVE.B	$64(A5),D0
	BFINS	D0,MSX2NewMenu38+10{7:1}	; MSX2 Sprites Y.

	MOVE.B	$6B(A5),D0
	BFINS	D0,MSX2NewMenu39+10{7:1}	; 100% Refresh

	MOVE.B	$6E(A5),D0
	BFINS	D0,MSX2NewMenu41+10{7:1}	; VDP 'TR bit' always ready

	BSR	MaskNorm			; Mask screen edges (4.2): one
	TST.B	PrefMask			; of Off / 8 dots / 16 dots.
	SEQ	D0
	BFINS	D0,MSX2NewMenu41b+10{7:1}
	CMP.B	#8,PrefMask
	SEQ	D0
	BFINS	D0,MSX2NewMenu41e+10{7:1}
	CMP.B	#16,PrefMask
	SEQ	D0
	BFINS	D0,MSX2NewMenu41f+10{7:1}
	MOVE.B	PrefFilter,D0
	BFINS	D0,MSX2NewMenu41c+10{7:1}	; Audio filter (4.0)
	MOVE.B	PrefDbuf,D0
	BFINS	D0,MSX2NewMenu41d+10{7:1}	; Smooth display (4.0)
	MOVE.B	PrefScan,D0			; RTG scanlines (Emulation > RTG Scanlines):
	JSR	ScanSet				; the prefs' choice, if one, wins
	JSR	ScanCode			; over the ToolType SCANLINES;
	MOVE.L	D0,D1				; one of the seven ticked, or none
	CMP.B	#1,D1				; (another percentage).
	SEQ	D0
	BFINS	D0,MSX2NewMenu45c+10{7:1}	; Off
	CMP.B	#2,D1
	SEQ	D0
	BFINS	D0,MSX2NewMenu45d+10{7:1}	; Hard 25%
	CMP.B	#3,D1
	SEQ	D0
	BFINS	D0,MSX2NewMenu45e+10{7:1}	; Hard 50%
	CMP.B	#4,D1
	SEQ	D0
	BFINS	D0,MSX2NewMenu45f+10{7:1}	; Hard 75%
	CMP.B	#5,D1
	SEQ	D0
	BFINS	D0,MSX2NewMenu45g+10{7:1}	; Blended light
	CMP.B	#6,D1
	SEQ	D0
	BFINS	D0,MSX2NewMenu45h+10{7:1}	; Blended
	CMP.B	#7,D1
	SEQ	D0
	BFINS	D0,MSX2NewMenu45i+10{7:1}	; Blended strong
; -=-
	MOVE.B	$7D(A5),D0
	BFINS	D0,MSX2NewMenu43+10{7:1}	; Disable Cheats

	MOVE.B	$1F(A5),D0
	BFINS	D0,MSX2NewMenu44+10{7:1}	; Ask for Reset.

	MOVE.B	$6F(A5),D0
	BFINS	D0,MSX2NewMenu45+10{7:1}	; Overwrite

; -=-

	MOVE.B	$6D(A5),D0
	BFINS	D0,MSX2NewMenu55+10{7:1}	; MSX Boot Type 'Check'
	LSR.B	#1,D0
	BFINS	D0,MSX2NewMenu56+10{7:1}	; MSX Boot Type '1DD'
	LSR.B	#1,D0
	BFINS	D0,MSX2NewMenu57+10{7:1}	; MSX Boot Type '2DD'

; -=-

	TST.B	$7E(A5)				; Emulation > Speed: 0 Normal,
	SEQ	D0				; 1 Overclock, 2 No Limit.
	BFINS	D0,MSX2NewMenu_SpeedN+10{7:1}
	CMP.B	#1,$7E(A5)
	SEQ	D0
	BFINS	D0,MSX2NewMenu_SpeedO+10{7:1}
	CMP.B	#2,$7E(A5)
	SEQ	D0
	BFINS	D0,MSX2NewMenu_SpeedL+10{7:1}

; -=-

;;	MOVE.B	$68(A5),D0
;;	BFINS	D0,MSX2NewMenu58+10{7:1}	; ROM/RAM Slot 1
;;
;;	MOVE.B	$69(A5),D0
;;	BFINS	D0,MSX2NewMenu64+10{7:1}	; ROM/RAM Slot 2


	RTS

; -----------------------------------
	CNOP	0,4
PONPREFS2:
	BSR	DiskROMVer
	BSR	VELOZRUT

	RTS
; -----------------------------------
	CNOP	0,4
; Option records (row $FE) of a loaded key script: settings for the test run,
; applied after ACTUPREFS (which copies the GUI over DirPrefs at every GO).
; 1 = sprite frames (DirPrefs+$16: 1 every frame, 2...), 2 = sprite
; collisions option (DirPrefs+$6C), 3 = mask screen edges (PrefMask: 0
; Off, 16 = 16 dots, other values 8 dots),
; 4 = sound chip (DirPrefs+$1D).
KeyOptApply:
	TST.L	KeyScrPtr
	BEQ	KeyOptFin
	LEA	KeyScr,A0
KeyOptBuc:
	CMP.L	#-1,(A0)
	BEQ	KeyOptFin
	CMP.B	#$FE,4(A0)
	BNE	KeyOptNx
	CMP.B	#1,5(A0)
	BNE.S	KeyOpt2
	MOVE.W	6(A0),DirPrefs+$16
KeyOpt2:
	CMP.B	#2,5(A0)
	BNE.S	KeyOpt3
	MOVE.B	7(A0),DirPrefs+$6C
KeyOpt3:
	CMP.B	#3,5(A0)		; 3 = mask screen edges (PrefMask).
	BNE.S	KeyOpt4
	MOVE.B	7(A0),PrefMask
	BSR	MaskNorm
KeyOpt4:
	CMP.B	#4,5(A0)		; 4 = sound chip (DirPrefs+$1D: 0 PSG,
	BNE.S	KeyOpt5			; 1 SCC, 2 SCC+, 3 PSG+FM, 4 lite).
	MOVE.B	7(A0),DirPrefs+$1D
KeyOpt5:
	CMP.B	#5,5(A0)		; 5 = machine (DirPrefs+$10: 0 MSX,
	BNE.S	KeyOpt6			; 1 MSX2, 2 MSX2+).
	MOVE.B	7(A0),DirPrefs+$10
KeyOpt6:
	CMP.B	#6,5(A0)		; 6 = display frequency (DirPrefs+$11:
	BNE.S	KeyOpt7			; 0 From VDP, 1 No Change, 2 NTSC, 3 PAL).
	MOVE.B	7(A0),DirPrefs+$11
KeyOpt7:
	CMP.B	#7,5(A0)		; 7 = audio filter (PrefFilter).
	BNE.S	KeyOpt8
	TST.B	7(A0)
	SNE	PrefFilter
KeyOpt8:
	CMP.B	#8,5(A0)		; 8 = smooth display (PrefDbuf).
	BNE.S	KeyOpt9
	TST.B	7(A0)
	SNE	PrefDbuf
KeyOpt9:
	CMP.B	#9,5(A0)		; 9 = RTG scanlines, a PrefScan code
	BNE.S	KeyOptNx		; (this run only).
	MOVE.L	D0,-(SP)
	MOVE.B	7(A0),D0
	JSR	ScanSet
	MOVE.L	(SP)+,D0
KeyOptNx:
	ADDQ.W	#8,A0
	BRA	KeyOptBuc
KeyOptFin:
	RTS

ACTUPREFS:
	LEA	DIRPrefs,A5

	MOVE.B	([MSX2Gadgets+(GD_ROM*4)],$57.w),$10(A5)	; Tipo ROM.
	MOVE.B	([MSX2Gadgets+(GD_SCRMODE*4)],$57.w),$11(A5)	; Frecuencia Pantalla.
	MOVE.W	([MSX2Gadgets+(GD_INTER*4)],$56.w),$14(A5)	; Interrupciones.
	MOVE.W	([MSX2Gadgets+(GD_MSX2Spr*4)],$56.w),$16(A5)	; MSX2 Sprites.
	MOVE.B	([MSX2Gadgets+(GD_DRIVEA*4)],$57.w),$18(A5)	; Drive A
	MOVE.B	([MSX2Gadgets+(GD_DRIVEB*4)],$57.w),$19(A5)	; Drive B

;;;	LEA	MSXVIRTUALGadgets,A0	; No hacer
;;;	ADD.W	#(GD_Discodev*4),A0	; por bug.
;;;	MOVE.L	(A0),A1
;;;	MOVE.B	$57(A1),$60(A5)

	MOVE.B	([MSX2Gadgets+(GD_Sound*4)],$57.w),$1D(A5)	; Chip de Sonido.
	MOVE.B	([MSX2Gadgets+(GD_RAM*4)],$57.w),$1C(A5)	; Cantidad de RAM.
;;	MOVE.W	([MSX2Gadgets+(GD_Veloz*4)],$54.w),$1A(A5)	; Retardo.
	MOVE.B	([MSX2Gadgets+(GD_DiskVer*4)],$57.w),$65(A5)	; Disk ROM.
	BSR	SpeedFromGUI		; Emulation > Speed.


	MOVE.L	#MN_Joy2,D0
	BSR	COGECHECK
	SNE	$13(A5)			; JoyStick 2 ON

	MOVE.L	#MN_SwapJoy,D0
	BSR	COGECHECK
	SNE	$6A(A5)			; Swap JoyPorts

	MOVE.L	#MN_Pad2CD32,D0		; (4.1.1) JoyPort 2 pad: CD32 pad
					; ticked (else Standard).
	BSR	COGECHECK
	SNE	PrefCD32

	MOVE.L	#MN_Pad1CD32,D0		; JoyPort 1 pad.
	BSR	COGECHECK
	SNE	PrefCD32M
; -=- (4.1.1: the items from here on are two further down the menu)
	MOVE.L	#MN_MultiKey,D0
	BSR	COGECHECK
	SNE	$12(A5)			; Multi-Key ON

	MOVE.L	#MN_DelPause,D0
	BSR	COGECHECK
	SNE	$1E(A5)			; DEL como Pausa

	MOVE.L	#MN_LShift,D0
	BSR	COGECHECK
	SNE	$62(A5)			; L.Shift as Space

	MOVE.L	#MN_RShift,D0
	BSR	COGECHECK
	SNE	$63(A5)			; R.Shift as Space
; -=-
	MOVE.L	#MN_JapID,D0
	BSR	COGECHECK
	SNE	$7A(A5)			; Use Japanese ID

	MOVE.L	#MN_Kanji,D0
	BSR	COGECHECK
	SNE	$7B(A5)			; Use Kanji ROM.
; -=-
	MOVE.L	#MN_WProt,D0
	BSR	COGECHECK
	SNE	$61(A5)			; Write Protected

	MOVE.L	#MN_WarnProt,D0
	BSR	COGECHECK
	SNE	$78(A5)			; Avisar al intentar Escribir.

	MOVE.L	#MN_WarnChg,D0
	BSR	COGECHECK
	SNE	$79(A5)			; Avisar al Salir si MVD modificado.
; -=-
	MOVE.L	#MN_SprLate,D0
	BSR	COGECHECK
	SNE	$64(A5)			; Sprites Base 2

	MOVE.L	#MN_FullRedraw,D0
	BSR	COGECHECK
	SNE	$6B(A5)			; 100% Refresh Screen

	SF	$6C(A5)			; 'Sprites collisions ON (always)': the
					; menu item is gone in 4.0 (the real
					; collision check always runs, and the
					; old forced flag broke most games).
	MOVE.L	#MN_TRBit,D0
	BSR	COGECHECK
	SNE	$6E(A5)			; VDP 'TR bit'

	BSR	MaskFromGUI		; Sub-items 3-5 of item 15: mask screen
					; edges Off / 8 / 16 dots (4.2).
	MOVE.L	#MN_Filter,D0		; Sub-item 6: audio filter (4.0).
	BSR	COGECHECK
	SNE	PrefFilter
	MOVE.L	#MN_Smooth,D0		; Sub-item 7: smooth display (4.0).
	BSR	COGECHECK
	SNE	PrefDbuf
	MOVEQ	#0,D2			; RTG scanlines: sub-items 0-6 =
ScnFG:	MOVE.L	D2,D0			; PrefScan 1-7 (none ticked: as it
	ROR.W	#5,D0			; was, PrefScan 0 and the ToolType's
	ADD.W	#MN_ScanOff,D0		; percentage). (D2 << 11: sub-item.)
	BSR	COGECHECK
	BEQ.S	ScnFGN
	MOVE.L	D2,D0
	ADDQ.B	#1,D0
	MOVE.B	D0,PrefScan
	JSR	ScanSet
ScnFGN:	ADDQ.W	#1,D2
	CMP.W	#NS_Scan,D2
	BCS.S	ScnFG
; -=-
	MOVE.L	#MN_LockCheats,D0
	BSR	COGECHECK
	SNE	$7D(A5)			; Disable Cheats

	MOVE.L	#MN_AskReset,D0
	BSR	COGECHECK
	SNE	$1F(A5)			; Ask for Reset

	MOVE.L	#MN_Overwrite,D0
	BSR	COGECHECK
	SNE	$6F(A5)			; Overwrite
; -=-
;;	MOVE.L	#(3*$40)+0,D0		; N� L�nea. (Sub-Item+Item)
;;	MOVEQ	#3,D1			; N� menu.
;;	BSR	COGECHECK
;;	SNE	$68(A5)			; ROM memory (Slot 1)
;;
;;	MOVE.L	#(3*$40)+2,D0		; N� L�nea. (Sub-Item+Item)
;;	MOVEQ	#3,D1			; N� menu.
;;	BSR	COGECHECK
;;	SNE	$69(A5)			; ROM memory (Slot 2)
; -=-

	MOVE.L	ReqBase(PC),A0
	LEA	$080(A5),A1
	BSR	CopiaRuta

	MOVE.L	ReqBaseSlot(PC),A0
	LEA	$180(A5),A1
	BSR	CopiaRuta

	MOVE.L	ReqBaseTape(PC),A0
	LEA	$280(A5),A1
	BSR	CopiaRuta

	RTS

; -----------------------------------
CopiaRuta:
	MOVE.L	8(A0),A0
	MOVE.W	#($100/8)-1,D0
ActPreBuc0:
	MOVE.L	(A0)+,(A1)+
	MOVE.L	(A0)+,(A1)+
	DBF	D0,ActPreBuc0
	RTS

; -----------------------------------
	CNOP	0,4
; D0 = a menu line's number (MN_ names, AmiMSX_MenuPos.i): A0 = its MenuItem,
; Z clear when it is ticked.
COGECHECK:
	MOVE.L	MSX2MENUS,A0
	MOVE.L	_intuitionbase,A6
	JSR	-$90(A6)		; ItemAddress (A0,d0)
	MOVE.L	D0,A0
	BTST	#0,$C(A0)
	RTS
; -----------------------------------
	CNOP	0,8
DIRPrefs:
	DC.L	"MSX2"
	DC.L	"v2.5"
	DC.L	Usuario*261	; Usuario Registrado Codificado #1.
	DC.L	Usuario*173	; Usuario Registrado Codificado #2.
	DC.B	1	; $10 - Tipo de ROM.
	DC.B	1	; $11 - Modo de resoluci�n. (Frecuencia)
	DC.B	0	; $12 - Multi-Key On.
	DC.B	0	; $13 - Port 0 On.
	DC.W	0	; $14 - Interrupciones.
	DC.W	1	; $16 - MSX2 Sprites. (4.0: every frame; was 2.)
	DC.B	5	; $18 - Drive A:
	DC.B	4	; $19 - Drive B:
	DC.W	0	; $1A - Retardo.
	DC.B	1	; $1C - Cantidad de RAM.
	DC.B	0	; $1D - Chip de sonido.
	DC.B	0	; $1E - DEL como Pausa.
	DC.B	0	; $1F - Ask for Go?
TABLAB4:
	DC.L	$F6F2F8F4,$F0F2F5F7,$F2F0F1F7,$F8F0F0F0	; $20 - Pila MSX.
	DC.L	$F0F0F0F0,$F0F0F0F0,$F0F0F1F3,$F0F1F0F0
	DC.L	$FAF0F0F0,$F0F5FFF4,$F4F3F3F0,$F7F2F0F0
	DC.L	$F2FFF4FB,$F6F0F0F0,$F0F0F0F0,$F0F3F0F0

	DC.B	0	; $60 - Drive para instalar.
	DC.B	$00	; $61 - Write Protected (4.1: off by default, so disk games can save).
	DC.B	0	; $62 - R.Shift as Space.
	DC.B	0	; $63 - L.Shift as Space.
	DC.B	0	; $64 - Sprites Base 2
	DC.B	0	; $65 - Disk ROM.
	DC.B	2	; $66 - (the Imploder's efficiency until 4.5: unused)
	DC.B	0	; $67 - Modo AntiCrack 1.
	DC.B	$FF	; $68 - Slot 1 ROM/RAM
	DC.B	$FF	; $69 - Slot 2 ROM/RAM
	DC.B	0	; $6A - Swap JoyPorts			<=- v2.3
	DC.B	$FF	; $6B - 100% Refresh in Screen Changes
	DC.B	0	; $6C - Sprite Collisions ON
	DC.B	$01	; $6D - MSX Boot type
	DC.B	$FF	; $6E - VDP 'TR bit' always ready
	DC.B	0	; $6F - Overwrite

	DC.L	0	; $70 - Tiempo jugando al AmiMSX2.
	DC.W	0	; $74 - Contador de grabaciones de Prefs.

	DC.B	0	; $76 - Mapper en Slot 1
	DC.B	0	; $77 - Mapper en Slot 2

	DC.B	0	; $78 - Avisar al intentar grabar.
	DC.B	0	; $79 - Avisar al Salir de escrituras.

	DC.B	0	; $7A - Use Japanese ID
	DC.B	0	; $7B - Use Kanji ROM

	DC.B	1	; $7C - Screen on Exit.

	DC.B	0	; $7D - Disable Cheats

	DC.B	0	; $7E - CPU Speed

	DC.B	0	; $7F - Modo AntiCrack 2.

	DC.B	"MVD_Files"	; $080
	DS.B	$100-9

	DS.B	$100		; $180 (4.0: empty = the program's drawer,
				; where the ROMs usually are; the release
				; has no Cartridges drawer)

	DS.B	$100		; $280 (4.0: empty, as $180)

	CNOP	0,4
	DC.B	" -*(  AmiMSX2 Emulator By:  Juan Antonio G�mez G�lvez  )*- "
	CNOP	0,4
; 4.0 settings, after the original block: a prefs file from an older version
; is shorter, so these stay 0 (BUFPREFS starts cleared).
PrefMask:	DC.B	0		; Mask screen edges: dots hidden each side,
					; 0 (Off), 8 or 16 (4.2; FFh before = 8).
PrefFilter:	DC.B	0		; Audio filter (Amiga low-pass, the power
					; LED bit): FFh = on while a game runs.
PrefDbuf:	DC.B	0		; Smooth display: FFh = SCREEN 4 double-
					; buffered (AmiMSX_Dbuf_v4.asm).
PrefMaskNoAuto:	DC.B	0		; 4.0-4.1's Auto mask setting: unused
					; since 4.2 (kept for the file layout).
PrefCD32:	DC.B	0		; (4.1.1) CD32 pad in the joystick port
					; (Amiga port 2): FFh. 0 = Standard.
PrefCD32M:	DC.B	0		; (4.1.1) CD32 pad in the mouse port
					; (Amiga port 1): FFh. 0 = Standard.
PrefScan:	DC.B	0		; RTG scanlines (Emulation > RTG Scanlines): 0 =
					; not set (the ToolType SCANLINES, else
					; Off), 1 = Off, 2-4 = hard 25/50/75%,
					; 5-7 = blended light/normal/strong.
FINPREFS:
BUCPREFS=FINPREFS-DIRPREFS

	DS.L	10
	CNOP	0,8
BUFPREFS:
	DS.B	BUCPREFS
	DS.L	10


; -----------------------------------
	CNOP	0,4
REGOCANCEL:
	ADD.W	#16+4,SP
	JSR	CLOSEREGOWINDOW
	BSR	ENAMOUSE
	RTS
; -----------------------------------
	CNOP	0,4
MSX_CONT:
	IFD	MENU
	TST.B	GoDat(PC)		; �MSX Encendido?
	BEQ	ErPowerON
	ENDC

	BSR	ACTUPREFS
	SF	D3
	BRA.S	R_GOCONT

MSX_Reset:
	IFD	MENU
	TST.B	GoDat(PC)		; �MSX Encendido?
	BEQ	ErPowerON
	ENDC

	SF	EsReset				; Pone que es Reset.
	BRA.S	MSX_GoCon

MSX_GO:
	IFEQ	Key_ON
	LEA	tErNoKeyFile,A0
	TST.L	DirKeyFile(PC)
	BEQ	ImpError
	ENDC

	ST	EsReset				; Pone que es HardReset.

MSX_GoCon:
	BSR	ACTUPREFS
	BSR	KeyOptApply		; Key-script options over the GUI prefs.
	MOVE.B	DIRPrefs+$7D(PC),DisCheaDat	; Refresca Disable Cheats.

	TST.B	GODAT(PC)
	BEQ.S	NOASKGO

	LEA	DIRPrefs,A5
	TST.B	$1F(A5)
	BEQ.S	NOASKGO

	BSR	DISMOUSE
	MOVEM.L	MCEROS(PC),D0-D7/A0-A6
	JSR	OPENREGOWINDOW

	LEA	REGOPUNTS,A1
	BSR	CONTROL

	BSR	ENAMOUSE
	JSR	CLOSEREGOWINDOW
NOASKGO:
	ST	D3
R_GOCONT:
	MOVE.W	D3,-(SP)
	BSR	DISMOUSE
	MOVE.W	(SP)+,D3

;	--------------

	LEA	DIRPrefs(PC),A5
	CLAMPM
	MOVE.B	$10(A5),D0				; Tipo ROM.
	CMP.B	ActuROM,D0
	BNE.S	NoEstaROM

	MOVE.B	$65(A5),D0				; Tipo DOS.
	CMP.B	#2,D0
	BEQ.S	YaEstaTodo
	CMP.B	ActuDOS,D0
	BEQ.S	YaEstaTodo
NoEstaROM:
	MOVE.W	D3,-(SP)
	BSR	LoadROMs
	MOVE.W	(SP)+,D3
YaEstaTodo:

	LEA	tErNoMSX2data,A0
	TST.B	LoROMBaDat(PC)		; �ROMs Base Leido Correctamente?
	BEQ	ImpError

;	--------------

	MOVE.W	D3,-(SP)
	BSR	LoadKanji		; Lee la Kanji ROM si es usada.
	MOVE.W	(SP)+,D3

;	--------------

	MOVE.W	D3,-(SP)
	LEA	DIRPrefs,A5
	MOVEQ	#0,D0
	MOVE.B	$1C(A5),D0
	BSR	LIBMEM

	LEA	DIRPrefs,A5
	MOVEQ	#0,D0
	MOVE.B	$1C(A5),D0
	BSR	COGEMEM
	MOVE.W	(SP)+,D3

;	--------------

	LEA	DIRPrefs,A5
	CLAMPM
	MOVE.B	$10(A5),D2		; Tipo ROM.
	LSL.L	#8,D2

	MOVE.B	$11(A5),D0		; Frecuencia pantalla.
	SEQ	D2
	BEQ.S	MODOWB
	SUBQ.B	#1,D0
	BEQ.S	MODOWB
	MOVEQ	#0,D1
	CMP.B	#1,D0
	BEQ.S	ESNTSC
	MOVE.W	#$20,D1
ESNTSC:	MOVE.W	D1,$DFF1DC
MODOWB:
	LSL.L	#8,D2

	MOVE.B	$12(A5),D2		; Multi-Key.
	LSL.L	#8,D2

	MOVE.B	$13(A5),D2		; Port. A On.
	NOT.B	D2

	MOVE.W	$14(A5),D0		; Inter.
	MOVE.B	(REXEINTAB.W,PC,D0.W),D0

	MOVE.W	$16(A5),D1		; Re-Inter.
	MOVE.B	(REXEINTAB.W,PC,D1.W),D1

	MOVEQ	#0,D5
	MOVE.B	$18(A5),D5		; Drive A.

	MOVEQ	#0,D6
	MOVE.B	$19(A5),D6		; Drive B.

	MOVEQ	#0,D7
	MOVE.B	$1C(A5),D7		; RAM.
	MOVE.B	(PAGIN.W,PC,D7.W),D7
	LSL.W	#8,D7

	MOVE.B	$1D(A5),D7		; Chip de Sonido.
	SWAP	D7


	MOVE.W	$1A(A5),D7		; Retardo.


	TST.B	$64(A5)
	BNE.S	SIREINTM
	MOVE.B	D0,D1
SIREINTM:

	MOVE.L	DirKeyBuff(PC),A4

	MOVE.B	$1E(A5),D4
	ST	GODAT

	MOVE.L	DIRFILE,A0

	MOVE.L	DIRFILEB,DIRVD1		; (4.0) drive B's virtual disk.
	IFD	MENU
	JSR	MSXEMUL			; A5=Dir Prefs.
	JSR	RtgPlayClose		; (4.5) the RTG play screen, OS back.
	ENDC
	IFD	PERF
	JSR	PerfDump		; (4.0) also after a Power ON run
	ENDC
	IFD	KEYKEEP			; (test builds) The key script runs again
	CLR.L	KeyFrN			; from its start at each Continue/Power ON
	BSET	#2,REGS+KEY+14		; (its Help released)
	ELSE				; (menu tests: its HELP comes back each time).
	CLR.L	KeyScrPtr		; (4.0) A key script drives one run:
	ENDC
					; later games get the keyboard and
					; joystick back (Measure on BigMig).
	JSR	FlashSave		; (4.0) back in the menu: flash sectors
	JSR	SramSave		; (4.4) cartridge SRAM,
	JSR	DiskBSave		; and drive B's image, if changed.

	MOVE.L	D7,-(SP)
	BSR	RefrescaReloj
	BSR	ENAMOUSE
	MOVE.L	(SP)+,D7
;  -------------------------

;  -------------------------
	TST.B	ProtectDat(PC)		; Modo Avisar si est� Write Protected.
	BEQ.S	NoEsProtect
	SF	ProtectDat
	BSR	UnProtect
	BRA	MSX_CONT
NoEsProtect:
;  -------------------------


;  -------------------------		; Mira Si el MVD se ha modificado.
	TST.B	DirPrefs+$79		; �Activada la opci�n en menu?
	BEQ.S	NoMVDModificado
	TST.B	MVDModifi(PC)		; �Se ha modificado el MVD?
	BEQ.S	NoMVDModificado
	MOVE.L	D7,-(SP)
	LEA	tErMVDModif,A0
	BSR	ImpError		; Pon el mensaje.
	MOVE.L	(SP)+,D7
NoMVDModificado:
;  -------------------------

;  -------------------------
;	IFEQ	USUARIO
;	MOVE.L	D7,-(SP)
;
;	BSR	DISMOUSE
;	MOVEM.L	MCEROS(PC),D0-D7/A0-A6
;	BSR	OPENTiempoWINDOW
;	LEA	TiempoPUNTS,A1
;	BSR	CONTROL
;	BSR	CLOSETiempoWINDOW
;	BSR	ENAMOUSE
;
;	MOVE.L	(SP)+,D7
;	ENDC

;  -------------------------

	TST.B	D7
	BEQ.S	NOERSTACK
	MOVE.L	D7,-(SP)
	LEA	TLEESTACK(PC),A0
	BSR	IMPERROR
	MOVE.L	(SP)+,D7
NOERSTACK:
	LSR.W	#8,D7
	TST.B	D7
	BEQ.S	RETEMUL
	LEA	TLEECHECK(PC),A0
	BRA	IMPERROR
RETEMUL:RTS

	CNOP	0,4
REXEINTAB:DC.B	0,1,2,3,4,5
	CNOP	0,4
PAGIN:	DC.B	$F8,$F0,$E0,$C0,$80,$00,0,0,0,0
	CNOP	0,4
; -----------------------------------
	CNOP	0,4
VELOZRUT:
;	LEA	MSX2Gadgets,A0
;	ADD.W	#(GD_VELOZ*4),A0
;	MOVE.L	(A0),A1
;	MOVEQ	#0,D0
;	MOVE.W	$54(A1),D0
;	BSR	PASDEC
;	MOVE.B	8(A0),MSX2IText6
;	MOVE.B	9(A0),MSX2IText6+1
;	move.l  MSX2Wnd,a0
;	move.b  54(a0),d0
;	ext.w   d0
;	move.b  55(a0),d1
;	ext.w   d1
;	move.l  50(a0),a0
;	lea     MSX2Text6(PC),a1
;	move.l  _IntuitionBase,a6
;	JSR     PrintIText(a6)
	RTS
; -----------------------------------
;	Pasa Decimal  &  Pasa Hexa v1.0
;	(PD)  Juan Antonio Gomez Galvez
;	(Codigo texto para DEVPAC II),(3-X-92)

;	- D0=Numero que se va a pasar a decimal.
;	- Resultado: D0 y A0 tienen el puntero del buffer
;	  de los numeros en ASCII en decimal.  (10 bytes)

PASDEC:
	LEA	DSUMA(PC),A0
	CLR.L	(A0)+
	CLR.L	(A0)+
	CLR.W	(A0)+

	MOVE.W	#$08-1,D1
	LEA	DATOSSUMA(PC),A0
SUMBUC01:
	MOVEM.L	D0-D1/A0,-(SP)
	AND.L	#$000F,D0
	TST.B	D0
	BEQ	SUMCON00
SUMBUC02:
	MOVEM.L	D0/A0,-(SP)
	LEA	DSUMA(PC),A1
	BSR	SUMDEC
	MOVEM.L	(SP)+,D0/A0
	SUBQ.B	#$01,D0
	BNE.S	SUMBUC02
SUMCON00:
	MOVEM.L	(SP)+,D0-D1/A0
	LSR.L	#$04,D0
	ADD.L	#$0A,A0
	DBF	D1,SUMBUC01

	LEA	DSUMA(PC),A0
	ADD.L	#$30303030,(A0)+
	ADD.L	#$30303030,(A0)+
	ADD.W	#$3030,(A0)+

	LEA	DSUMA(PC),A0
SUMBUC03:
	TST.B	(A0)
	BEQ	SUMCON01
	MOVE.B	(A0),D0
	CMP.B	#$30,D0
	BNE.S	FINRET
	MOVE.B	#$20,(A0)+
	BRA	SUMBUC03
SUMCON01:
	MOVE.B	#"0",-(A0)
	BRA.S	FINRET
SUMDEC:
	MOVEQ.L	#$0A-1,D1
	ADD.L	#$0A,A0
	ADD.L	#$0A,A1
SUMBUC00:
	MOVE.B	-(A0),D3
	ADD.B	D3,-(A1)
	MOVE.B	(A1),D0
	SUB.B	#$0A,D0
	BCS.S	SUMBIEN00
	MOVE.B	D0,(A1)
	ADD.B	#$01,-1(A1)
	DBF	D1,SUMBUC00
	RTS
SUMBIEN00:
	CLR.L	D0
	DBF	D1,SUMBUC00
	RTS
FINRET:
	LEA	DSUMA(PC),A0
	MOVE.L	A0,D0
	RTS


;	- A0 el puntero del buffer de los
;	  numeros en ASCII en decimal. (10 bytes)
;	- Resultado: D0=Numero en hexadecimal.

PASHEX:
	CLR.L	D5
	LEA	PUNTERO(PC),A1
	MOVE.L	A0,(A1)
	MOVEQ.L	#$0A-1,D0
PASBUC02:
	SUB.B	#$30,(A0)+
	BCC.S	PASCON00
	CLR.B	-$01(A0)
PASCON00:
	CMP.B	#$0A,-$01(A0)
	BLT.S	PASCON01
	CLR.B	-$01(A0)
PASCON01:
	DBF	D0,PASBUC02
	MOVE.L	PUNTERO(PC),A0
	LEA	FDATOSSUMA(PC),A1
	MOVEQ.L	#$08-1,D4
	MOVE.L	#$10000000,D3
PHEBUC01:
	MOVEQ.L	#-1,D7
PHEBUC00:
	ADD.L	#$01,D7
	BSR	COPY1
	BSR	RESTAD
	CMP.B	#$09,D0
	BNE.S	PHEBUC00
	BSR	COPY2
	CLR.L	D6
	TST.L	D7
	BEQ.S	PHECON00
PHEBUC02:
	ADD.L	D3,D6
	SUB.L	#$01,D7
	BNE.S	PHEBUC02
	ADD.L	D6,D5
PHECON00:
	LSR.L	#$04,D3
	SUB.L	#$0A,A1
	DBF	D4,PHEBUC01
	MOVE.L	D5,D0
	RTS
COPY1:
	MOVE.L	PUNTERO(PC),A6
	LEA	DSUMA2(PC),A5
COPCON00:
	MOVE.L	(A6)+,(A5)+
	MOVE.L	(A6)+,(A5)+
	MOVE.W	(A6)+,(A5)+
	RTS
COPY2:
	MOVE.L	PUNTERO(PC),A5
	LEA	DSUMA2(PC),A6
	BRA.S	COPCON00
RESTAD:
	MOVEM.L	A0-A1,-(SP)
	ADD.L	#$0A,A0
	ADD.L	#$0A,A1
	CLR.L	D0
	ROXR.L	#$1,D0		; FLAG X=0
	MOVE.L	#$0A-1,D0
RESBUC00:
	SBCD.B	-(A1),-(A0)
	AND.B	#$0F,(A0)
	DBF	D0,RESBUC00
	MOVE.B	(A0),D0
	MOVEM.L	(SP)+,A0-A1
	RTS

	DC.L	0
DSUMA:
	DS.B	$0A
	DC.L	0
DSUMA2:
	DS.B	$0A
	DC.L	0
DATOSSUMA:
	DC.B	0,0,0,0,0,0,0,0,0,1
	DC.B	0,0,0,0,0,0,0,0,1,6
	DC.B	0,0,0,0,0,0,0,2,5,6
	DC.B	0,0,0,0,0,0,4,0,9,6
	DC.B	0,0,0,0,0,6,5,5,3,6
	DC.B	0,0,0,1,0,4,8,5,7,6
	DC.B	0,0,1,6,7,7,7,2,1,6
FDATOSSUMA:
	DC.B	0,2,6,8,4,3,5,4,5,6
	DC.L	0
PUNTERO:
	DC.L	0

;	Fin del codigo texto.

; -----------------------------------

DISMOUSE:
	TST.L	MSX2WND(PC)
	BEQ.S	NoDisMouse
	TST.L	WREQBASE
	BEQ.S	SiDisMouse
NoDisMouse:
	RTS
SiDisMouse:
	MOVEQ	#$70,D0
	MOVE.L	#$10001,D1
	MOVE.L	$4.W,A6
	JSR	-$2AC(A6)		; AllocVec
	MOVE.L	D0,VECBASE
	BEQ.S	ERVEC
	MOVE.L	D0,A0
	MOVE.L	MSX2WND,A1
	MOVE.L	_intuitionbase,A6
	JSR	-$F0(A6)		; Request
ERVEC:
	MOVE.L	D0,WREQBASE
	BRA.S	DISMOUSEG
; --------------------------------------------------------
ENAMOUSE:
	TST.L	WREQBASE
	BEQ.S	ERVEC3
	MOVE.L	VECBASE(PC),A0
	MOVE.L	MSX2WND,A1
	MOVE.L	_intuitionbase,A6
	JSR	-$78(A6)		; EndRequest
ERVEC3:
	MOVE.L	VECBASE(PC),D0
	BEQ.S	ERVEC2
	MOVE.L	D0,A1
	MOVE.L	$4.W,A6
	JSR	-$2B2(A6)		; FreeVec

	CLR.L	VECBASE
	CLR.L	WREQBASE
	BRA.S	ENAMOUSEG
ERVEC2:
	CLR.L	VECBASE
	CLR.L	WREQBASE
	RTS
	CNOP	0,4
VECBASE:DC.L	0
WREQBASE:DC.L	0
; -----------------------------------
DISMOUSEG:
	MOVE.L	MSX2WND,A0	; A0=Window
	BRA.S	PBUSY
ENAMOUSEG:
	MOVE.L	MSX2WND,A0	; A0=Window
	BRA.S	PNORM
; -----------------------------------
PBUSY:
;;;	MOVE.L	MSX2WND,A0	; A0=Window
	LEA	BUSYGFX,A1
	MOVE.L	#16,D0
	MOVE.L	#16,D1
	MOVEQ	#0,D2
	MOVEQ	#0,D3
	MOVE.L	_intuitionbase,A6
	JMP	-$10E(A6)

PNORM:
;;;	MOVE.L	MSX2WND,A0	; A0=Window
	MOVE.L	_intuitionbase,A6
	JMP	-$3C(A6)
; -----------------------------------



*************************************************************
*************************************************************
*************************************************************
	CNOP	0,4
MFMDISK2:DC.B	"mfm.device",0,0
	CNOP	0,4
StatDev2:DC.B	"statram.device",0,0

	CNOP	0,8
DISKIOREQI:	DS.L	20+2
	CNOP	0,8
DISKPORTI:	DS.L	8+2

	CNOP	0,8
DISKIOREQ2:	DS.L	20+2
	CNOP	0,8
DISKPORT2:	DS.L	8+2

MSXBOOTBLOCK:
	DC.L	$EBFE904D,$53582D45,$4D554C00,$2020100,$27000A0
	DC.L	$5F90300,$9000200,$D0ED,$5359C032,$C4C03656,$2336C031
	DC.L	$1FF5119F,$C00E0FCD,$7DF33CCA,$63C01100,$10E1ACD
	DC.L	$7DF32101,$22ADC0,$21003F11,$9FC00E27,$CD7DF3C3
	DC.L	$158C0,$CD000079,$E6FEFE02,$C26AC03A,$C4C0A7CA
	DC.L	$22401179,$C00E09CD,$7DF30E07,$CD7DF318,$B2426F6F
	DC.L	$74206572,$726F720D,$A507265,$73732061,$6E79206B
	DC.L	$65792066,$6F722072,$65747279,$D0A2400,$4D535844
	DC.L	$4F532020,$53595300,$0,$0,$0,$0,$0,$0,$0,$0,$0,$0,$0
	DCB.L	$3F,$0
	DCB.L	$A,$0
	DC.L	$0
	DS.B	20
	CNOP	0,4
BUF512:	DS.B	512
	DS.B	20
*************************************************************
*************************************************************
*************************************************************


; <=-------------------------------------------------------=>
;	 Rutina de control de lectura de Gadgets.
;	<= -------------------------------------=>
;	    A1 = SaltosGadgets.	; Para salir hacer:  ADD.L  #16+4,SP
;	-12(A1)= Window Handle.
;	 -8(A1)= Punteros Gadgets.
;	 -4(A1)= N� de Gadgets-1
CONTROL:
	CLR.W	ControlKeys
	MOVE.L	-8(A1),-(SP)
	MOVE.L	A1,-(SP)
	MOVE.L	-12(A1),A0
	MOVE.L	(A0),-(SP)
	TST.B	AutoGo			; Test hook: press GO once.
	BEQ	BUCONTROL
	CMP.L	#MSX2PUNTS,4(SP)
	BNE	BUCONTROL
	SF	AutoGo
	TST.L	KeyScrPtr		; Scripted test run: start at the top of
	BEQ.S	AutoGoNow		; an Amiga frame, so the run is the same
AutoGoW1:				; every time (file loading ends at host-
	MOVE.L	$DFF004,D0		; dependent moments).
	LSR.L	#8,D0
	AND.W	#$1FF,D0
	CMP.W	#20,D0
	BCS.S	AutoGoW1
AutoGoW2:
	MOVE.L	$DFF004,D0
	LSR.L	#8,D0
	AND.W	#$1FF,D0
	BNE.S	AutoGoW2
AutoGoNow:
	JSR	MSX_GO
	IFD	TRACE
	JSR	TraceDump		; Trap fired, or Ctrl+Alt: last 4096
	ENDC				; instructions before leaving.
	IFD	PERF
	JSR	PerfDump		; Frame timing windows.
	ENDC
	TST.B	ROM2NOM			; (4.5) Test hook 'R2=': a second run, the
	BEQ.S	BUCONTROL		; next cartridge with the same key script.
	LEA	ROM2NOM,A0
	LEA	FILENOM,A1
Rom2Cp:	MOVE.B	(A0)+,(A1)+
	BNE.S	Rom2Cp
	CLR.B	ROM2NOM
	ST	AutoCart
	MOVEM.L	D0-D7/A0-A6,-(SP)
	BSR	InsertSl1
	MOVEM.L	(SP)+,D0-D7/A0-A6
	CLR.L	KeyFrN
	MOVE.L	#KeyScr,KeyScrPtr
	BRA	AutoGoNow
BUCONTROL:
	MOVE.L	(SP),A0
	MOVE.L	$56(A0),A0
	MOVE.L	$4,A6
	JSR	-$180(A6)	; Wait Port. (iport)(A0)

	MOVE.L	(SP),A0
	MOVE.L	$56(A0),A0
	MOVE.L	_GADTOOLSBASE,A6
	JSR	-$48(A6)	; GT_GetIMsg(iport)(A0)
	TST.L	D0
	BEQ.S	BUCONTROL

	MOVE.L	D0,-(SP)
	MOVE.L	D0,A1
	MOVE.L	$1C(A1),-(SP)
	MOVE.L	$14(A1),-(SP)

	MOVE.L	_GADTOOLSBASE,A6
	JSR	-$4E(A6)	; GT_ReplyIMsg(imsg)(A1)

	MOVEM.L	(SP)+,D0-D1/A1

	CMP.W	#$200,D0	; CloseGadget.
	BEQ	CONTROLNOGADS

	CMP.W	#$100,D0	; �Es Men�?
	BEQ	ESMENU

	CMP.W	#$010,D0	; �Es Slider?
	BEQ	ESGADGET

	CMP.W	#$040,D0	; �Es Gadget?
	BEQ.S	ESGADGET

	CMP.W	#$400,D0	; �Es Teclado?
	BEQ.S	EsTeclado

	BRA.S	BUCONTROL

	CNOP	0,4
EsTeclado:
	MOVEQ	#0,D1
	MOVE.W	ControlKeys,D1
	MOVE.B	$19(A1),D1	; Tecla.
	MOVE.L	4(SP),A1
	MOVE.L	-16(A1),D0
	BEQ.S	BUCONTROL

	CMP.B	#$60,D1		; Shift Izquierdo Pulsado.
	BEQ.S	ShiftPul
	CMP.B	#$61,D1		; Shift Derecho Pulsado.
	BEQ.S	ShiftPul
	CMP.B	#$E0,D1		; Shift Izquierdo Soltado.
	BEQ.S	ShiftSol
	CMP.B	#$E1,D1		; Shift Derecho Soltado.
	BEQ.S	ShiftSol

	MOVE.L	D0,A1
EsTeclaBuc:
	CMP.L	#$100,(A1)
	BEQ.S	EsFullTecla
	TST.L	(A1)
	BMI	BUCONTROL
	CMP.L	(A1)+,D1
	ADDQ	#4,A1
	BNE.S	EsTeclaBuc

	MOVE.L	-4(A1),A1
	JSR	(A1)
	BRA	BUCONTROL

EsFullTecla:
	MOVE.L	4(A1),A1
	JSR	(A1)
	BRA	BUCONTROL


	CNOP	0,4
ShiftPul:
	BSET	#0,ControlKeys
	BRA	BUCONTROL
	CNOP	0,4
ShiftSol:
	BCLR	#0,ControlKeys
	BRA	BUCONTROL
; -=-=-

	CNOP	0,4
ESGADGET:
	MOVE.L	4(SP),A1	; Es Gadget.
	MOVE.L	8(SP),A0

	SUBQ.L	#4,A1
	MOVE.L	(A1),D0
	BMI.S	CONTROLNOGADS
	MOVE.L	#$FFFF,D2
CONBUCP:
	ADDQ.W	#1,D2
	CMP.L	(A0)+,D1
	DBEQ	D0,CONBUCP
	TST.W	D0
	BMI	BUCONTROL

	MOVE.L	(A1),D0
CONBUCP2:
	ADDQ.L	#4,A1
	TST.L	4(A1)
	BEQ	BUCONTROL
	CMP.L	(A1)+,D2
	DBEQ	D0,CONBUCP2
	TST.W	D0
	BMI	BUCONTROL

	MOVE.L	(A1),A1
	JSR	(A1)
	BRA	BUCONTROL
CONTROLRET:
	ADDQ.W	#4,SP
	BRA	BUCONTROL
CONTROLSALIR:
	ADD.W	#16,SP
	RTS
CONTROLNOGADS:
	ADD.W	#12,SP
	RTS

	CNOP	0,4
ESMENU:
	MOVE.L	$14(A1),D0
	MOVE.W	$18(A1),D1
	MOVE.L	$1C(A1),A0

	BFEXTU	D1{27:5},D2
	BFEXTU	D1{21:6},D3
	BFEXTU	D1{16:5},D4

	CMP.W	#$1F,D2
	BEQ	BUCONTROL
	MOVE.L	(PUNTEROSMENU.W,PC,D2.W*4),A0
	CMP.W	#$2F,D3
	BEQ	BUCONTROL
	CMP.W	#$1F,D4
	BEQ.S	EJECMENU
	MOVE.L	(A0,D3.W*4),A0
	MOVE.W	D4,D3
EJECMENU:
	JSR	([A0,D3.W*4])
	BRA	BUCONTROL


	CNOP	0,4
; Menu picks (ESMENU): one table per menu, one entry per line, separators
; included; an item with sub-items points at its own table, one entry per
; sub-item. MJ/MJS check each entry's place against its name and MJEND the
; length (AmiMSX_MenuPos.i), so the build stops if a table and the menu differ.
; Tick lines do nothing when picked: ACTUPREFS reads the ticks (Continue, Power
; ON, Save Settings).
PUNTEROSMENU:
	DC.L	MM_Project
	DC.L	MM_Emulation
	DC.L	MM_Input
	DC.L	MM_Disks
	DC.L	MM_Carts
	DC.L	MM_Tape
	DC.L	MM_Tools
	MJEND	PUNTEROSMENU,NM_Menus

MM_Project:
	MJ	MM_Project,MN_About,ABOUT
	MJ	MM_Project,MN_ProjectBar0,CONTROLRET
	MJ	MM_Project,MN_SavePrefs,SAVEPREFS
	MJ	MM_Project,MN_GameSave,GameSave
	MJ	MM_Project,MN_GameForget,GameForget
	MJ	MM_Project,MN_ProjectBar1,CONTROLRET
	MJ	MM_Project,MN_AskReset,CONTROLRET
	MJ	MM_Project,MN_Overwrite,ActuPrefs
	MJ	MM_Project,MN_ProjectBar2,CONTROLRET
	MJ	MM_Project,MN_Quit,CONTROLSALIR
	MJEND	MM_Project,NI_Project

MM_Emulation:
	MJ	MM_Emulation,MN_Speed,MS_Speed
	MJ	MM_Emulation,MN_JapID,CONTROLRET
	MJ	MM_Emulation,MN_Kanji,CONTROLRET
	MJ	MM_Emulation,MN_Filter,CONTROLRET
	MJ	MM_Emulation,MN_EmulationBar0,CONTROLRET
	MJ	MM_Emulation,MN_Mask,MS_Mask
	MJ	MM_Emulation,MN_Smooth,CONTROLRET
	MJ	MM_Emulation,MN_Scan,MS_Scan
	MJ	MM_Emulation,MN_ScrMode,MS_ScrMode
	MJ	MM_Emulation,MN_Internal,MS_Internal
	MJEND	MM_Emulation,NI_Emulation

MM_Input:
	MJ	MM_Input,MN_Joy2,CONTROLRET
	MJ	MM_Input,MN_SwapJoy,CONTROLRET
	MJ	MM_Input,MN_Pad2,MS_Pad2
	MJ	MM_Input,MN_Pad1,MS_Pad1
	MJ	MM_Input,MN_InputBar0,CONTROLRET
	MJ	MM_Input,MN_MultiKey,CONTROLRET
	MJ	MM_Input,MN_DelPause,CONTROLRET
	MJ	MM_Input,MN_LShift,CONTROLRET
	MJ	MM_Input,MN_RShift,CONTROLRET
	MJEND	MM_Input,NI_Input

MM_Disks:
	MJ	MM_Disks,MN_DriveA,MS_DriveA
	MJ	MM_Disks,MN_DriveB,MS_DriveB
	MJ	MM_Disks,MN_DisksBar0,CONTROLRET
	MJ	MM_Disks,MN_WProt,CONTROLRET
	MJ	MM_Disks,MN_WarnProt,CONTROLRET
	MJ	MM_Disks,MN_WarnChg,CONTROLRET
	MJ	MM_Disks,MN_DisksBar1,CONTROLRET
	MJ	MM_Disks,MN_Floppy,MS_Floppy
	MJEND	MM_Disks,NI_Disks

MM_Carts:
	MJ	MM_Carts,MN_Slot1,MS_Slot1
	MJ	MM_Carts,MN_Map1,MS_Map1
	MJ	MM_Carts,MN_CartsBar0,CONTROLRET
	MJ	MM_Carts,MN_Slot2,MS_Slot2
	MJ	MM_Carts,MN_Map2,MS_Map2
	MJEND	MM_Carts,NI_Carts

MM_Tape:
	MJ	MM_Tape,MN_LoadTape,LoadTape
	MJ	MM_Tape,MN_RewindTape,InitLoadTape
	MJ	MM_Tape,MN_TapeBar0,CONTROLRET
	MJ	MM_Tape,MN_NewRec,InitSaveTape
	MJ	MM_Tape,MN_SaveRec,SaveTape
	MJEND	MM_Tape,NI_Tape

MM_Tools:
	MJ	MM_Tools,MN_Cheat,MenuPoke
	MJ	MM_Tools,MN_Debug,MenuDebug
	MJ	MM_Tools,MN_LockCheats,CONTROLRET
	MJ	MM_Tools,MN_ToolsBar0,CONTROLRET
	MJ	MM_Tools,MN_SaveScreen,SAVEVRAM
	MJ	MM_Tools,MN_SaveSprites,SAVESprites
	MJ	MM_Tools,MN_ToolsBar1,CONTROLRET
	MJ	MM_Tools,MN_NewDisk,MS_NewDisk
	MJEND	MM_Tools,NI_Tools

MS_Mask:
	MJS	MS_Mask,MN_MaskOff,CONTROLRET
	MJS	MS_Mask,MN_Mask8,CONTROLRET
	MJS	MS_Mask,MN_Mask16,CONTROLRET
	MJEND	MS_Mask,NS_Mask

MS_Scan:
	MJS	MS_Scan,MN_ScanOff,CONTROLRET
	MJS	MS_Scan,MN_ScanH25,CONTROLRET
	MJS	MS_Scan,MN_ScanH50,CONTROLRET
	MJS	MS_Scan,MN_ScanH75,CONTROLRET
	MJS	MS_Scan,MN_ScanBL,CONTROLRET
	MJS	MS_Scan,MN_ScanB,CONTROLRET
	MJS	MS_Scan,MN_ScanBS,CONTROLRET
	MJEND	MS_Scan,NS_Scan

MS_Speed:
	MJS	MS_Speed,MN_SpeedNormal,CONTROLRET
	MJS	MS_Speed,MN_SpeedOC,CONTROLRET
	MJS	MS_Speed,MN_SpeedNoLimit,CONTROLRET
	MJEND	MS_Speed,NS_Speed

MS_ScrMode:
	MJS	MS_ScrMode,MN_SetPAL,SETPAL
	MJS	MS_ScrMode,MN_SetNTSC,SETNTSC
	MJEND	MS_ScrMode,NS_ScrMode

MS_Internal:
	MJS	MS_Internal,MN_SprLate,CONTROLRET
	MJS	MS_Internal,MN_FullRedraw,CONTROLRET
	MJS	MS_Internal,MN_TRBit,CONTROLRET
	MJEND	MS_Internal,NS_Internal

MS_Pad2:
	MJS	MS_Pad2,MN_Pad2Std,CONTROLRET
	MJS	MS_Pad2,MN_Pad2CD32,CONTROLRET
	MJEND	MS_Pad2,NS_Pad2

MS_Pad1:
	MJS	MS_Pad1,MN_Pad1Std,CONTROLRET
	MJS	MS_Pad1,MN_Pad1CD32,CONTROLRET
	MJEND	MS_Pad1,NS_Pad1

MS_DriveA:
	MJS	MS_DriveA,MN_LoadImg,LOADVD0
	MJS	MS_DriveA,MN_SaveImg,SAVEVD0
	MJS	MS_DriveA,MN_EjectImg,CLEARVD0
	MJEND	MS_DriveA,NS_DriveA

MS_DriveB:
	MJS	MS_DriveB,MN_LoadImgB,LOADVDB
	MJS	MS_DriveB,MN_EjectImgB,CLEARVDB
	MJEND	MS_DriveB,NS_DriveB

MS_NewDisk:
	MJS	MS_NewDisk,MN_Fmt2DD,FORMAT2DD
	MJS	MS_NewDisk,MN_Fmt1DD,FORMAT1DD
	MJEND	MS_NewDisk,NS_NewDisk

MS_Floppy:
	MJS	MS_Floppy,MN_ReadFloppy,LOADDISK
	MJS	MS_Floppy,MN_WriteFloppy,SAVEDISK
	MJS	MS_Floppy,MN_FloppyBar0,CONTROLRET
	MJS	MS_Floppy,MN_InstBoot,INSTALAR
	MJS	MS_Floppy,MN_FloppyBar1,CONTROLRET
	MJS	MS_Floppy,MN_BootAuto,BootTypeCheck
	MJS	MS_Floppy,MN_Boot1DD,BootType1DD
	MJS	MS_Floppy,MN_Boot2DD,BootType2DD
	MJEND	MS_Floppy,NS_Floppy

MS_Slot1:
	MJS	MS_Slot1,MN_Sl1Insert,InsertSl1
	MJS	MS_Slot1,MN_Sl1Eject,EjectSl1
	MJS	MS_Slot1,MN_Slot1Bar0,CONTROLRET
	MJS	MS_Slot1,MN_Sl1SaveMap,SaveMappID1
	MJEND	MS_Slot1,NS_Slot1

MS_Map1:
	MJS	MS_Map1,MN_Map1None,Sl1MapOp0
	MJS	MS_Map1,MN_Map1Gen16,Sl1MapOp1
	MJS	MS_Map1,MN_Map1Konami,Sl1MapOp2
	MJS	MS_Map1,MN_Map1Asc8,Sl1MapOp3
	MJS	MS_Map1,MN_Map1Asc16,Sl1MapOp4
	MJS	MS_Map1,MN_Map1SCC,Sl1MapOp5
	MJS	MS_Map1,MN_Map1SCCs,Sl1MapOp6
	MJS	MS_Map1,MN_Map1RType,Sl1MapOp7
	MJEND	MS_Map1,NS_Map1

MS_Slot2:
	MJS	MS_Slot2,MN_Sl2Insert,InsertSl2Ask
	MJS	MS_Slot2,MN_Sl2Eject,EjectSl2
	MJS	MS_Slot2,MN_Slot2Bar0,CONTROLRET
	MJS	MS_Slot2,MN_Sl2SaveMap,SaveMappID2
	MJEND	MS_Slot2,NS_Slot2

MS_Map2:
	MJS	MS_Map2,MN_Map2None,Sl2MapOp0
	MJS	MS_Map2,MN_Map2Gen16,Sl2MapOp1
	MJS	MS_Map2,MN_Map2Konami,Sl2MapOp2
	MJS	MS_Map2,MN_Map2Asc8,Sl2MapOp3
	MJS	MS_Map2,MN_Map2Asc16,Sl2MapOp4
	MJS	MS_Map2,MN_Map2SCC,Sl2MapOp5
	MJS	MS_Map2,MN_Map2SCCs,Sl2MapOp6
	MJS	MS_Map2,MN_Map2RType,Sl2MapOp7
	MJEND	MS_Map2,NS_Map2



; <=-------------------------------------------------------=>
; <=-------------------------------------------------------=>
; <=-------------------------------------------------------=>


; <=-------------------------------------------------------=>
	IFEQ	Key_ON
	CNOP	0,8
DesCriptKey:
	MOVE.L	DirKeyFile,D0
	BEQ	AmiRET
	MOVE.L	D0,A0
	MOVE.L	(A0),D0
	LSL.L	#2,D0
	MOVE.L	D0,A0
	ADD.W	#$204-$78,A0

	MOVEQ	#(3)-1,D2
BUCLE1:
	MOVE.L	A0,A2
	LEA	Buffer(PC),A1
	MOVEQ	#(256/8)-1,D0
BUCLE0:
	MOVE.L	(A2)+,(A1)+
	MOVE.L	(A2)+,(A1)+
	DBF	D0,BUCLE0

	LEA	Buffer(PC),A1
	LEA	Encript(PC),A2
	MOVE.W	#(256)-1,D0
	MOVEQ	#0,D1
BUCLE2:
	MOVE.B	(A2)+,D1
	MOVE.B	(A1)+,(A0,D1.W)
	DBF	D0,BUCLE2
	ADD.W	#$100,A0
	DBF	D2,BUCLE1
	RTS
	ENDC
; <=-------------------------------------------------------=>


; <=-------------------------------------------------------=>
	CNOP	0,8
CrakCheck:
	MOVE.B	(A0,D2.W),D3
	BEQ.S	CrakChkFin
	SUB.W	D3,D1
	ADDQ.W	#1,D2
	BRA.S	CrakCheck
CrakChkFin:
	RTS
; <=-------------------------------------------------------=>


	CNOP	0,8
COGEMEM:
;	-------------------------
;	MOVEQ	#0,D1
;	LEA	MSX2WTitle-$46(PC),A0
;	MOVE.L	18+$46(A0),-(SP)
;	MOVEQ	#0,D3
;	MOVEQ	#$46,D2
;	MOVE.L	D3,18+$46(A0)
;	BSR	CrakCheck
;	MOVE.L	(SP)+,18+$46(A0)
;	LEA	MSX2STitle-$72(PC),A0
;	MOVEQ	#$72,D2
;	BSR	CrakCheck
;	LEA	DirPrefs+$216(PC),A0
;	CMP.W	#$E849,D1
;	BEQ.S	EstaBien
;	ST	$7F-$216(A0)		; Modo AntiCrack 2.
;EstaBien:
;	-------------------------

	LEA	PUNTSRAM,A0
	MOVE.W	D0,D1
	BEQ.S	COGMRET
	MOVEQ	#0,D0
COGMBUC0:
	MOVE.L	(A0)+,A2
	MOVE.L	(A0)+,D2
COGMBUC1:
	MOVEM.L	D0-D2/A0,-(SP)
	MOVE.L	(A2),D0
	BNE.S	COGNOREQ
	MOVE.L	A2,-(SP)
	MOVE.L	#$10001,D1
	MOVE.L	#($4100*8)+$100,D0
	MOVE.L	4.W,A6
	JSR	-$C6(A6)		; Requiere memoria.
	MOVE.L	(SP)+,A2
COGNOREQ:
	MOVE.L	D0,(A2)+
	BEQ.S	OUTOFMEM

	MOVEM.L	(SP)+,D0-D2/A0

	DBF	D2,COGMBUC1
	ADDQ.W	#1,D0
	DBF	D1,COGMBUC0
COGMRET:RTS

; ----------------------------------
OUTOFMEM:
	MOVEM.L	(SP)+,D0-D2/A0

	LEA	NOMEMIText1+6,A1
	SUBQ.W	#1,D0
	MOVE.L	(MEMTEXT.L,D0.W*4),(A1)

	MOVE.B	D0,DIRPrefs+$1C

	BSR	LIBMEM

	BSR	DISMOUSE
	MOVEM.L	MCEROS(PC),D0-D7/A0-A6
	JSR	OPENNOMEMWINDOW
	LEA	NOMEMPUNTS,A1
	BSR	CONTROL
	JSR	CLOSENOMEMWINDOW
; ---
	LEA	MSX2Gadgets+(GD_RAM*4),A0
	MOVE.L	MSX2WND,A1
	MOVE.L	#$8008000F,D0
	MOVEQ	#0,D1
	MOVE.B	DIRPrefs+$1C,D1
	BSR	CanviTAGS
; ---
	BSR	ENAMOUSE

;;	ADDQ	#4,SP
	RTS

	CNOP	0,8
MEMTEXT:DC.B	" 128"," 256"," 512","1024","2048","4096"

; ----------------------------------

	CNOP	0,8
LIBMEM:
	LEA	PUNTSRAM+(8*6),A0
	MOVEQ	#6-2,D1
	SUB.W	D0,D1
	BCS	COGMRET
LIBMBUC0:
	MOVE.L	-(A0),D2
	MOVE.L	-(A0),A2
LIBMBUC1:
	MOVEM.L	D0-D2/A0-A2,-(SP)
	MOVE.L	(A2)+,D0
	BEQ.S	LIBNOREQ
	MOVE.L	D0,A1
	MOVE.L	#($4100*8)+$100,D0
	MOVE.L	4.W,A6
	JSR	-$D2(A6)		; Libera memoria.
LIBNOREQ:
	MOVEM.L	(SP)+,D0-D2/A0-A2

	CLR.L	(A2)+
	DBF	D2,LIBMBUC1
	DBF	D1,LIBMBUC0
	RTS

; ----------------------------------
;-----------------------------------------------------------------------------
;S404 highly optimized data_decruncher_lib 1.0_turbo for use in stc.library
;23.11.93 by Marcus 'Cozine' Ottosson
;-----------------------------------------------------------------------------
;S404 data_decruncher v0.2
;(c) 1993 by Jouni 'Mr.Spiv' Korhonen (SWSW)
;-----------------------------------------------------------------------------
; Arreglos y opci�n de A0=A1 por Juan Antonio G�mez (007!)
;-----------------------------------------------------------------------------
;call with registers:
;                       ***   A0 = crunched data        ***
;			***   A1 = destination address  ***
;
;  Para usar un solo bufer:  como m�nimo  a1=a0+$10  (16 Bytes)  o  a1=a0
;-----------------------------------------------------------------------------
;Uses d0-d7/a0-a6		$08(a0).l = Size fichero descomp.
;				Fichero comprimido M�ximo de 1024Kb.

		CNOP	0,4
Stone_Depac:
		CMP.L	#"S404",(a0)	; ID
		BNE	lexit

		CMP.L	A0,A1
		BNE.S	edNOIGUAL
		MOVE.L	08(A0),D1
		MOVE.L	12(A0),D2
		LEA	$10(A0),A2
		MOVE.L	D2,D0
		LSR.L	#4,D0
		ADDQ.L	#1,D0
		MOVE.W	#4*4,D3
edBUCCOPY:
		MOVEM.L	(A2)+,D4-D7
		MOVEM.L	D4-D7,(A1)
		ADD.W	D3,A1
		SUBQ.L	#1,D0
		BNE.S	edBUCCOPY
		MOVE.L	A0,A1
		MOVE.L	A0,A5
		ADD.L	D1,A1
		ADD.L	D2,A0
		SUBQ	#4,A0
		BRA.S	edDCopyableStart2
edNOIGUAL:
		addq	#8,a0
edDCopyableStart:
		move.l	a1,a5
		add.l	(a0)+,a1
		add.l	(a0),a0
edDCopyableStart2:
		moveq	#0,d4
		moveq	#16,d5
		movem	(a0),d2/d6/d7
		not	d4
		lea	loff6(pc),a3
		lea	llen5a(pc),a4
		moveq	#1,d0
		moveq	#-1,d3
		bra.s	ltest1

		cnop	0,8			; Use if main loop>=244 bytes
;*** Here's the start of the instruction cache

lins:		subq	#8,d7
		bpl.s	lins2
lins1:		move	d7,d1
		addq	#8,d7
		lsl.l	d7,d6
		move	-(a0),d6
		neg	d1
		lsl.l	d1,d6
		addq	#8,d7
		swap	d6
		move.b	d6,-(a1)
		swap	d6
		cmp.l	a1,a5
		dbhs	d7,lmain
		bra.s	lexma

lins2:		rol	#8,d6
		move.b	d6,-(a1)
ltest1:		cmp.l	a1,a5
		dbhs	d7,lmain
lexma		bhs.s	lexit

lmain1:		move	-(a0),d6
		moveq	#15,d7
lmain:		add	d6,d6
		bcc.s	lins

		dbf	d7,llen1
		move	-(a0),d6
		moveq	#15,d7
llen1:		add	d6,d6
		bcs.s	llen6
		moveq	#2,d1
		moveq	#4-2,d3
		dbf	d7,llen2
		move	-(a0),d6
		moveq	#15,d7
llen2:		add	d6,d6
		bcs.s	llen5
		dbf	d7,llen3
		move	-(a0),d6
		moveq	#15,d7
llen3:		add	d6,d6
		bcc.s	llen4
		moveq	#4,d1
		moveq	#8-2,d3
		lea	llen3a(pc),a6
		bra.s	lbits
llen3a:		add	d1,d3
		cmp	#15,d1
		blo.s	loff1

		moveq	#5,d1
		moveq	#14-1,d3
		lea	llen3b(pc),a6
		bra.s	lbits

llen4:		moveq	#23-2,d3
lloop:		moveq	#8,d1
llen5:		move.l	a4,a6
		bra.s	lbits
llen5a:		add	d1,d3
		not.b	d1
		dbeq	d7,loff2
		bne.s	loff2a
		bra.s	lloop

loff6:		add	d1,a2
		move.b	(a2),-(a1)
lcopy:		move.b	-(a2),-(a1)
		dbf	d3,lcopy
ltest:		cmp.l	a1,a5
		dbhs	d7,lmain
		blo.s	lmain1
lexit:		rts

llen6:		dbf	d7,llen7
		move	-(a0),d6
		moveq	#15,d7
llen7:		add	d6,d6
		addx	d0,d3
loff1:		dbf	d7,loff2
loff2a:		move	-(a0),d6
		moveq	#15,d7
loff2:		add	d6,d6
		bcs.s	loff3

		dbf	d7,loff4
		move	-(a0),d6
		moveq	#15,d7
loff4:		moveq	#9,d1
		lea	32(a1),a2
		add	d6,d6
		bcc.s	loff5
		moveq	#5,d1
		move.l	a1,a2
		bra.s	loff5
loff3:		lea	544(a1),a2
		move	d2,d1
loff5:		move.l	a3,a6

lbits:		and.l	d4,d6
		sub	d1,d7
		bpl.s	lbits2
		add	d7,d1
		lsl.l	d1,d6
		move	d7,d1
		move	-(a0),d6
		neg	d1
		add	d5,d7
lbits2:		lsl.l	d1,d6
		move.l	d6,d1
		swap	d1
		jmp	(a6)

; This part is not executed very often.  Some files may decrunch much slower
; on the 68020/68030.

llen3b:		add	d1,d3
l2ins:		subq	#8,d7
		bmi.s	l2ins1
		rol	#8,d6
		move.b	d6,-(a1)
		dbf	d3,l2ins
		bra.s	ltest

l2ins1:		move	d7,d1
		addq	#8,d7
		lsl.l	d7,d6
		move	-(a0),d6
		neg	d1
		lsl.l	d1,d6
		addq	#8,d7
		swap	d6
		move.b	d6,-(a1)
		swap	d6
		dbf	d3,l2ins
		bra	ltest
**********************************************************
; ----------------------------------

;	Explode Routine. (DATA)	(For The FILE IMPLODER v1.3)
;	Code for DEVPAC II, ASM-ONE.  (MC68000)
;	In  A0  The address of imploded datas.  ( dc.b	"IMP!" or "JAGG")
;	In  A1  The address of destination data.
;	(A0 and A1 can be equals) NOTE: $04(A0).L is size of file exploded.
; RETURN: If D0=0 Then error while exploding. or  "Z" of SR=1

	CNOP	0,4
EXPLODE:
	MOVE.L	A0,A3
	MOVE.L	A1,A4
	CMP.L	#"IMP!",(A0)+
	BEQ.S	FI_BIEN
	MOVEQ	#0,D0
	RTS
	CNOP	0,4
FI_BIEN:
	ADD.L	(A0)+,A4
	ADD.L	(A0)+,A3
	MOVE.L	A3,A2
	MOVE.L	(A2)+,-(A0)
	MOVE.L	(A2)+,-(A0)
	MOVE.L	(A2)+,-(A0)
	MOVE.L	(A2)+,D2
	MOVE.W	(A2)+,D3
	BMI.S	FI_CONT00
	SUBQ.L	#1,A3
FI_CONT00:
	LEA	-$1C(SP),SP
	MOVE.L	A1,A0
	MOVE.L	SP,A1
	MOVEQ	#6,D0
FI_BUC00:
	MOVE.L	(A2)+,(A1)+
	DBF	D0,FI_BUC00
	MOVE.L	SP,A1
	MOVEQ	#0,D4
FI_CONT02:
	TST.L	D2
	BEQ.S	FI_CONT01
FI_BUC01:
	MOVE.B	-(A3),-(A4)
	SUBQ.L	#1,D2
	BNE.S	FI_BUC01
FI_CONT01:
	CMP.L	A4,A0
	BCS.S	FI_RUT00
	LEA	$1C(SP),SP
	MOVEQ	#-$1,D0
	CMP.L	A3,A0
	BEQ.S	FI_FIN
FI_ERROR:
	MOVEQ	#0,D0
FI_FIN:
	TST.L	D0
	RTS
FI_RUT00:
	ADD.B	D3,D3
	BNE.S	FI_CONT03
	MOVE.B	-(A3),D3
	ADDX.B	D3,D3
FI_CONT03:
	BCC.S	FI_CONT15
	ADD.B	D3,D3
	BNE.S	FI_CONT04
	MOVE.B	-(A3),D3
	ADDX.B	D3,D3
FI_CONT04:
	BCC.S	FI_CONT14
	ADD.B	D3,D3
	BNE.S	FI_CONT05
	MOVE.B	-(A3),D3
	ADDX.B	D3,D3
FI_CONT05:
	BCC.S	FI_CONT13
	ADD.B	D3,D3
	BNE.S	FI_CONT06
	MOVE.B	-(A3),D3
	ADDX.B	D3,D3
FI_CONT06:
	BCC.S	FI_CONT12
	ADD.B	D3,D3
	BNE.S	FI_CONT07
	MOVE.B	-(A3),D3
	ADDX.B	D3,D3
FI_CONT07:
	BCC.S	FI_CONT08
	MOVE.B	-(A3),D4
	MOVEQ	#3,D0
	BRA.S	FI_CONT16
FI_CONT08:
	ADD.B	D3,D3
	BNE.S	FI_CONT09
	MOVE.B	-(A3),D3
	ADDX.B	D3,D3
FI_CONT09:
	ADDX.B	D4,D4
	ADD.B	D3,D3
	BNE.S	FI_CONT10
	MOVE.B	-(A3),D3
	ADDX.B	D3,D3
FI_CONT10:
	ADDX.B	D4,D4
	ADD.B	D3,D3
	BNE.S	FI_CONT11
	MOVE.B	-(A3),D3
	ADDX.B	D3,D3
FI_CONT11:
	ADDX.B	D4,D4
	ADDQ.B	#6,D4
	MOVEQ	#3,D0
	BRA.S	FI_CONT16
FI_CONT12:
	MOVEQ	#5,D4
	MOVEQ	#3,D0
	BRA.S	FI_CONT16
FI_CONT13:
	MOVEQ	#4,D4
	MOVEQ	#2,D0
	BRA.S	FI_CONT16
FI_CONT14:
	MOVEQ	#3,D4
	MOVEQ	#1,D0
	BRA.S	FI_CONT16
FI_CONT15:
	MOVEQ	#2,D4
	MOVEQ	#0,D0
FI_CONT16:
	MOVEQ	#0,D5
	MOVE.W	D0,D1
	ADD.B	D3,D3
	BNE.S	FI_CONT17
	MOVE.B	-(A3),D3
	ADDX.B	D3,D3
FI_CONT17:
	BCC.S	FI_CONT20
	ADD.B	D3,D3
	BNE.S	FI_CONT18
	MOVE.B	-(A3),D3
	ADDX.B	D3,D3
FI_CONT18:
	BCC.S	FI_CONT19
	MOVE.B	FI_DATOS0(PC,D0.W),D5
	ADDQ.B	#8,D0
	BRA.S	FI_CONT20
FI_CONT19:
	MOVEQ	#2,D5
	ADDQ.B	#4,D0
FI_CONT20:
	MOVE.B	FI_DATOS1(PC,D0.W),D0
FI_CONT21:
	ADD.B	D3,D3
	BNE.S	FI_CONT22
	MOVE.B	-(A3),D3
	ADDX.B	D3,D3
FI_CONT22:
	ADDX.W	D2,D2
	SUBQ.B	#1,D0
	BNE.S	FI_CONT21
	ADD.W	D5,D2
	MOVEQ	#0,D5
	MOVE.L	D5,A2
	MOVE.W	D1,D0
	ADD.B	D3,D3
	BNE.S	FI_CONT23
	MOVE.B	-(A3),D3
	ADDX.B	D3,D3
FI_CONT23:
	BCC.S	FI_CONT26
	ADD.W	D1,D1
	ADD.B	D3,D3
	BNE.S	FI_CONT24
	MOVE.B	-(A3),D3
	ADDX.B	D3,D3
FI_CONT24:
	BCC.S	FI_CONT25
	MOVE.W	8(A1,D1.W),A2
	ADDQ.B	#8,D0
	BRA.S	FI_CONT26
FI_CONT25:
	MOVE.W	0(A1,D1.W),A2
	ADDQ.B	#4,D0
FI_CONT26:
	MOVE.B	$10(A1,D0.W),D0
FI_CONT27:
	ADD.B	D3,D3
	BNE.S	FI_CONT28
	MOVE.B	-(A3),D3
	ADDX.B	D3,D3
FI_CONT28:
	ADDX.L	D5,D5
	SUBQ.B	#1,D0
	BNE.S	FI_CONT27
	ADDQ.W	#1,A2
	ADD.L	D5,A2
	ADD.L	A4,A2
FI_CONT29:
	MOVE.B	-(A2),-(A4)
	SUBQ.B	#1,D4
	BNE.S	FI_CONT29
	BRA	FI_CONT02
FI_DATOS0:
	dc.b	6,10,10,$12
FI_DATOS1:
	dc.b	1,1,1,1,2,3,3,4,4,5,7,14
	EVEN

; ----------------------------------


;	 ********************************
;	**  Power-Packer Data decrunch  **
;	 ********************************
PPCOLOR=0		; 0=Si color mientras descompacta.
COLOR_REG=$DFF1A2	; Registro destino Hardware para el color.
;	A0=Origen.	(Todo en *.l)
;	A1=Destino.	(Para un solo bufer: A1 mayor 2.l (8 Bytes) que A0)
;	D0=Size del Fichero.	Total. (Grabacion DATA de Power-Packer.)
;	** Resultado: **	(D0.l=00: Mal!)	(D0.l=-1 Bien)
;	** Nota:  Dejar 8 bytes libres detras de Origen. (Modo un bufer)

	CNOP	0,4
PP20_Decrunch:
	CMP.L	#"PP20",(A0)
	BEQ.S	PP20BIEN
	MOVEQ	#0,D0
	RTS
PP20BIEN:
	MOVE.L	A1,A3
	LEA	PP4026C(PC),A5
	MOVE.L	4(A0),(A5)
	ADD.L	D0,A0
	MOVE.L	(A5),D0
	MOVEQ	#3,D6
	MOVEQ	#1,D4
	MOVEQ	#7,D7
	MOVEQ	#1,D5
	MOVE.L	A3,A2
	MOVE.L	-(A0),D1
	TST.B	D1
	BEQ.S	PP401E6
	BSR.S	PP4020A
	SUB.L	D4,D1
	LSR.L	D1,D5
PP401E6:
	LSR.L	#8,D1
	ADD.L	D1,A3
PP401EA:
	BSR.S	PP4020A
	BCS.S	PP4022C
	MOVEQ	#0,D2
PP401F0:
	MOVE.W	D4,D0
	BSR.S	PP40218
	ADD.W	D1,D2
	CMP.W	D6,D1
	BEQ.S	PP401F0
PP401FA:
	MOVEQ	#7,D0
	BSR.S	PP40218
	MOVE.B	D1,-(A3)
	DBF	D2,PP401FA
	CMP.L	A3,A2
	BCS.S	PP4022C
	RTS
PP4020A:
	LSR.L	D4,D5
	BEQ.S	PP40210
	RTS
PP40210:
	MOVE.L	-(A0),D5
	ROXR.L	D4,D5
	RTS
PP40216:
	SUB.W	D4,D0
PP40218:
	MOVEQ	#0,D1
PP4021A:
	LSR.L	D4,D5
	BEQ.S	PP40226
PP4021E:
	ROXL.L	D4,D1
	DBF	D0,PP4021A
	RTS
PP40226:
	MOVE.L	-(A0),D5
	ROXR.L	D4,D5
	BRA.S	PP4021E
PP4022C:
	MOVE.W	D4,D0
	BSR.S	PP40218
	MOVEQ	#0,D0
	MOVE.B	0(A5,D1.W),D0
	MOVE.W	D1,D2
	CMP.W	D6,D2
	BNE.S	PP40252
	BSR.S	PP4020A
	BCS.S	PP40242
	MOVEQ	#7,D0
PP40242:
	BSR.S	PP40216
	MOVE.W	D1,D3
PP40246:
	MOVEQ	#2,D0
	BSR.S	PP40218
	ADD.W	D1,D2
	CMP.W	D7,D1
	BEQ.S	PP40246
	BRA.S	PP40256
PP40252:
	BSR.S	PP40216
	MOVE.W	D1,D3
PP40256:
	ADD.W	D4,D2
PP40258:
	MOVE.B	0(A3,D3.W),-(A3)
	DBF	D2,PP40258
	IFEQ	PPCOLOR
	MOVE.W	A3,COLOR_REG
	ENDC
	CMP.L	A3,A2
	BCS.S	PP401EA
	MOVEQ	#-1,D0
	RTS
PP4026C:	dc.l	$90A0B0B,$4C50,$4E468280
*************************************************


; ----------------------------------

	CNOP	0,8
PUNTSRAM:
	DC.L	PUNRAM0,0		; 128
	DC.L	PUNRAM1,0		; 256
	DC.L	PUNRAM2,1		; 512
	DC.L	PUNRAM3,3		; 1024
	DC.L	PUNRAM4,7		; 2048
	DC.L	PUNRAM5,15		; 4096

	CNOP	0,8
PUNRAM0:DC.L	RAM00-$100
PUNRAM1:DS.L	1
PUNRAM2:DS.L	2
PUNRAM3:DS.L	4
PUNRAM4:DS.L	8
PUNRAM5:DS.L	16

; <=-------------------------------------------------------=>
; <=-------------------------------------------------------=>
; <=-------------------------------------------------------=>

	CNOP	0,8
MCEROS:	DS.L	16

	CNOP	0,4
	DC.L	0
	DC.L	MSX2WND
	DC.L	MSX2GADGETS
	DC.L	MSX2_CNT-1
MSX2PUNTS:
	DC.L	GD_GO,MSX_GO
	DC.L	GD_MSX_Reset,MSX_Reset
	DC.L	GD_EXIT,CONTROLSALIR
	DC.L	GD_CONT,MSX_CONT
	DC.L	GD_MSX2Spr,CONTROLRET
	DC.L	GD_SCRMODE,CONTROLRET
	DC.L	GD_DRIVEA,CONTROLRET
	DC.L	GD_DRIVEB,CONTROLRET
	DC.L	GD_DiskVer,DiskROMVer
	DC.L	GD_INTER,CONTROLRET
;;	DC.L	GD_VELOZ,VELOZRUT
	DC.L	GD_ROM,CONTROLRET
	DC.L	GD_RAM,CONTROLRET
	DC.L	GD_SOUND,CONTROLRET
	DC.L	GD_MSXVD0,LOADVD0
	DC.L	GD_MVD2,LOADVDB
	DC.L	GD_Slot1,InsertSl1
	DC.L	GD_Slot2,InsertSl2Ask
	DC.L	0,0


	CNOP	0,4
	DC.L	0
	DC.L	MSXVIRTUALWND
	DC.L	MSXVIRTUALGADGETS
	DC.L	MSXVIRTUAL_CNT-1
MSXVIRTUALPUNTS:
	DC.L	GD_Instalar,INSTALARcon
	DC.L	GD_InsCancel,CONTROLSALIR
	DC.L	0,0


	CNOP	0,4
	DC.L	0
	DC.L	QUITWND
	DC.L	QUITGADGETS
	DC.L	QUIT_CNT-1
QUITPUNTS:
	DC.L	GD_Quityes,CONTROLSALIR
	DC.L	GD_Quitno,NOQUIT
	DC.L	0,0


	CNOP	0,4
	DC.L	0
	DC.L	QUITMVDWND
	DC.L	QUITMVDGADGETS
	DC.L	QUITMVD_CNT-1
QUITMVDPUNTS:
	DC.L	GD_QuitMVDyes,CONTROLSALIR
	DC.L	GD_QuitMVDno,NOQUITMVD
	DC.L	0,0


	CNOP	0,4
	DC.L	0
	DC.L	DELMVDWND
	DC.L	DELMVDGADGETS
	DC.L	DELMVD_CNT-1
DELMVDPUNTS:
	DC.L	GD_DELMVDCONT,CONTROLSALIR
	DC.L	GD_DELMVDCANCEL,NODELMVD
	DC.L	0,0


	CNOP	0,4
	DC.L	0
	DC.L	REGOWND
	DC.L	REGOGADGETS
	DC.L	REGO_CNT-1
REGOPUNTS:
	DC.L	GD_REGOyes,CONTROLSALIR
	DC.L	GD_REGOno,REGOCANCEL
	DC.L	0,0


	CNOP	0,4
	DC.L	0
	DC.L	PokeWND
	DC.L	PokeGADGETS
	DC.L	Poke_CNT-1
PokePUNTS:
	DC.L	GD_PokeAddress,ControlRet
	DC.L	GD_PokeValue,ControlRet
	DC.L	GD_Poke,DoPoke
	DC.L	GD_CheatSeaVal,CheatSearch
	DC.L	GD_CheatComVal,CheatCompare
	DC.L	GD_CheatMore,CheatMore
	DC.L	GD_PokeExit,ControlSalir
	DC.L	0,0


	CNOP	0,4
	DC.L	BebugKeys
	DC.L	DebugWND
	DC.L	DebugGADGETS
	DC.L	Debug_CNT-1
DebugPUNTS:
	DC.L	GD_DebugScroll,DebugScroll
	DC.L	GD_DebugAddress,DebugAddress
	DC.L	GD_DebugIzq,DebugAddressIzq
	DC.L	GD_DebugDer,DebugAddressDer
	DC.L	GD_DebugSaveMem,DebugSaveMem
	DC.L	GD_DebugAddresses,Addresses
	DC.L	GD_DebugPage0,ActualizaPokes
	DC.L	GD_DebugPage1,ActualizaPokes
	DC.L	GD_DebugPage2,ActualizaPokes
	DC.L	GD_DebugPage3,ActualizaPokes
	DC.L	GD_DebugMap0,ActualizaPokes
	DC.L	GD_DebugMap1,ActualizaPokes
	DC.L	GD_DebugMap2,ActualizaPokes
	DC.L	GD_DebugMap3,ActualizaPokes
	DC.L	0,0
BebugKeys:
	DC.L	$004C,DebugAddressArr
	DC.L	$004D,DebugAddressDeb
	DC.L	$004F,DebugAddressIzq
	DC.L	$004E,DebugAddressDer
	DC.L	$014C,DebugAddressArr2
	DC.L	$014D,DebugAddressDeb2
	DC.L	$014F,DebugAddressIzq
	DC.L	$014E,DebugAddressDer
	DC.L	-1,-1


	CNOP	0,4
	DC.L	MatraKeys
	DC.L	MatraWND
	DC.L	MatraGADGETS
	DC.L	Matra_CNT-1
MatraPunts:
	DC.L	GD_MatraStart,ControlSalir
	DC.L	0,0
MatraKeys:
	DC.L	$40,ControlSalir
	DC.L	-1,-1


	CNOP	0,4
	DC.L	0
	DC.L	AddressesWND
	DC.L	AddressesGADGETS
	DC.L	Addresses_CNT-1
AddressesPUNTS:
	DC.L	GD_AddressesExit,ControlSalir
	DC.L	0,0


	CNOP	0,4
	DC.L	0
	DC.L	OverwriteWND
	DC.L	OverwriteGADGETS
	DC.L	Overwrite_CNT-1
OverwritePUNTS:
	DC.L	GD_OverYes,ControlSalir
	DC.L	GD_OverCancel,OverwriteCancel
	DC.L	0,0


	CNOP	0,4
	DC.L	0
	DC.L	CartNotIDWND
	DC.L	CartNotIDGADGETS
	DC.L	CartNotID_CNT-1
CartNotIDPUNTS:
	DC.L	GD_CIDSet,NoCartrIDSet
	DC.L	GD_CIDIgn,NoCartrIDIgnore
	DC.L	GD_CIDCan,ControlSalir
	DC.L	0,0


	CNOP	0,4
	DC.L	0
	DC.L	UnProtectWND
	DC.L	UnProtectGADGETS
	DC.L	UnProtect_CNT-1
UnProtectPunts:
	DC.L	GD_UnProtect,EsUnProtect
	DC.L	GD_Protect,ControlSalir
	DC.L	0,0


	CNOP	0,4
	DC.L	0
	DC.L	ABOUTWND
	DC.L	ABOUTGADGETS
	DC.L	ABOUT_CNT-1
ABOUTPUNTS:
	DC.L	GD_ABOUTEXIT,CONTROLSALIR
	DC.L	0,0


	CNOP	0,4
	DC.L	0
	DC.L	MC68020WND
	DC.L	MC68020GADGETS
	DC.L	MC68020_CNT-1
MC68020PUNTS:
	DC.L	GD_MContinue,MC68020SALIR	; (4.0) no 68020: no Continue
	DC.L	GD_MexitWB,MC68020SALIR
	DC.L	0,0


	CNOP	0,4
	DC.L	0
	DC.L	AGAChipWND
	DC.L	AGAChipGADGETS
	DC.L	AGAChip_CNT-1
AGAChipPUNTS:
	DC.L	GD_AGAContinue,CONTROLSALIR
	DC.L	GD_AGAexitWB,AGAChipSALIR
	DC.L	0,0


	CNOP	0,4
	DC.L	0
	DC.L	ERRORMFMWND
	DC.L	ERRORMFMGADGETS
	DC.L	ERRORMFM_CNT-1
ERRORMFMPUNTS:
	DC.L	GD_ERRORMFM,CONTROLSALIR
	DC.L	0,0


	CNOP	0,4
	DC.L	ErrorKeys
	DC.L	ERRORWND
	DC.L	ERRORGADGETS
	DC.L	ERROR_CNT-1
ERRORPUNTS:
	DC.L	GD_EContinue,CONTROLSALIR
	DC.L	0,0
ErrorKeys:
	DC.L	$40,ControlSalir
	DC.L	-1,-1


	CNOP	0,4
	DC.L	0
	DC.L	NOMEMWND
	DC.L	NOMEMGADGETS
	DC.L	NOMEM_CNT-1
NOMEMPUNTS:
	DC.L	GD_EMContinue,CONTROLSALIR


; ----------------------------------------------
	DS.L	10
; ----------------------------------------------



; ----------------------------------------------
****************************************************************************
	CNOP	0,4
BOOT2DD:
	DC.L	$EBFE9041,$4D494741,$0,$2020100,$27000A0,$5F90300
	DC.L	$9000200,$D0ED,$5359C032,$D0C03656,$2336C031
	DC.L	$1FF511AB,$C00E0FCD,$7DF33CCA,$63C01100,$10E1ACD
	DC.L	$7DF32101,$22B9C0,$21003F11,$ABC00E27,$CD7DF3C3
	DC.L	$158C0,$CD000079,$E6FEFE02,$C26AC03A,$D0C0A7CA
	DC.L	$22401185,$C0CD77C0,$E07CD7D,$F318B41A,$B7C8D55F
	DC.L	$E06CD7D,$F3D11318,$F2426F6F,$74206572,$726F720D
	DC.L	$A507265,$73732061,$6E79206B,$65792066,$6F722072
	DC.L	$65747279,$D0A0000,$4D535844,$4F532020,$53595300,0
	DS.B	512-118
****************************************************************************
	CNOP	0,4
BOOT1DD:
	DC.L	$EBFE9041,$4D494741,$0,$2020100,$27000D0,$2F80200
	DC.L	$9000100,$D0ED,$5359C032,$D0C03656,$2336C031
	DC.L	$1FF511AB,$C00E0FCD,$7DF33CCA,$63C01100,$10E1ACD
	DC.L	$7DF32101,$22B9C0,$21003F11,$ABC00E27,$CD7DF3C3
	DC.L	$158C0,$CD000079,$E6FEFE02,$C26AC03A,$D0C0A7CA
	DC.L	$22401185,$C0CD77C0,$E07CD7D,$F318B41A,$B7C8D55F
	DC.L	$E06CD7D,$F3D11318,$F2426F6F,$74206572,$726F720D
	DC.L	$A507265,$73732061,$6E79206B,$65792066,$6F722072
	DC.L	$65747279,$D0A0000,$4D535844,$4F532020,$53595300,0
	DS.B	512-118
****************************************************************************
; ----------------------------------------------

; -----------------------------------
	CNOP	0,4
DATMSXPIC:
	DC.W	26,12
	DC.W	351,45
	DC.W	3
	DC.L	MSXPIC
	DC.B	$7,0
	DC.L	0

DatsMatraPic:
	DC.W	0,0		; X,Y Iniciales
	DC.W	640,201		; X,Y Finales
	DC.W	4		; Bit-Planos
	DC.L	MatraPic	; Gfx Bitmap.
	DC.B	$F,0
	DC.L	0

; -----------------------------------

; -----------------------------------
	IFEQ	Key_ON
Encript:
	DC.L	$DC123152,$7AAD0B29,$4C79B214,$37649B01,$27548BCC
	DC.L	$3A6CB826,$5793DE24,$70B7285F,$A5184F90,$E03071C1
	DC.L	$3E7FD436,$88DD4791,$0A4A9A6F,$C62066BC,$94167EE3
	DC.L	$46105D19,$951C6ACE,$338C38B1,$45A3348E,$1B74F89C
	DC.L	$50B34ED3,$43A787FC,$7DF572EA,$67DAA03D,$AB92B058
	DC.L	$D04DC08A,$2FEBEC76,$F9845CDF,$69BA3F5B,$68FD8FC9
	DC.L	$48C753D5,$C3AC40E2,$80621AA1,$2ACF23E4,$8649C260
	DC.L	$AF7535CB,$C497B9A2,$416B51F2,$A64BB477,$2E56CA78
	DC.L	$82F40DEE,$A4E142E8,$81E69E7C,$22E59FD9,$550425C5
	DC.L	$7B32FF2D,$FED8ED2C,$FA008D05,$1F2BA9AE,$9659CDA8
	DC.L	$BF3C111D,$F7E76115,$0EDB5EF0,$BB631EEF,$E9134489
	DC.L	$D1730806,$0302B5AA,$395A3BD2,$21F10C07,$FB098317
	DC.L	$C8D79998,$D6859DBE,$656D6EBD,$B6F30FF6

Buffer:	DS.B	256

	ENDC
; -----------------------------------

; -----------------------------------
;	Datos GadToolsBox:

	CNOP	0,8
	INCLUDE	"GadToolsBox/AmiMSX_v3.1.s"
; -----------------------------------

; -----------------------------------
	CNOP	0,8
CheatBuf:	DS.B	8*1024
; -----------------------------------

****************************************************************


	IFND	MENU
	SECTION	GFX,DATA_C

MSXPIC:	INCBIN	"Gfx/AmiMSX_Logo.raw"	; 351*45

MatraPic:INCBIN	"Gfx/MatraLogo.raw"	; 640*201

DEBUG:
IFF=0
I=0
R=0
PEXX=2
Flags_Push=0
SCREEN:
MSX2pal:
DirVRAM:
MemoryMapper:
Tipos=0
Punts=0
Regs:
	DS.L	8
ScrModo=0

BUSYGFX:
	dc.w	$0000,$0000
	dc.w	$0400,$07C0
	dc.w	$0000,$07C0
	dc.w	$0100,$0380
	dc.w	$0000,$07E0
	dc.w	$07C0,$1FF8
	dc.w	$1FF0,$3FEC
	dc.w	$3FF8,$7FDE
	dc.w	$3FF8,$7FBE
	dc.w	$7FFC,$FF7F
	dc.w	$7EFC,$FFFF
	dc.w	$7FFC,$FFFF
	dc.w	$3FF8,$7FFE
	dc.w	$3FF8,$7FFE
	dc.w	$1FF0,$3FFC
	dc.w	$07C0,$1FF8
	dc.w	$0000,$07E0
	dc.w	$0000,$0000
	dc.w	$0000,$0000
	dc.w	$0000,$0000
RAM00:
Slot0:
Slot1:
Slot2:
Slot3:
SCR0:
DirSprit0:
NEXSPR=0
OTRSPR=0
DA8=0
DFC=0
DFD=0
DFE=0
DFF=0
MMAND=0

	SECTION	ROM,BSS
DirROM:
DirDOS:
	DS.B	128*1024
	ENDC

; --------------------------------

	CNOP	0,8
; (4.0) 'AmiMSX <disk> B=<image>': the second image goes in drive B, as a
; virtual disk (MVD) of its own; Left Amiga swaps A and B in play (Main,
; Emula1Frame). Plain 360/720 Kb images only. Writes go to memory only:
; drive B's image isn't saved back.
	CNOP	0,4
LoadDiskB:
	TST.B	DISKBNOM
	BEQ	LdDkBR
	MOVE.L	#DISKBNOM,D1
	JSR	LONGFILE
	CMP.L	#720*1024,D0
	BEQ.S	LdDkBS
	CMP.L	#360*1024,D0
	BNE	LdDkBBad
LdDkBS:	MOVE.L	D0,D7
	MOVE.L	#DISKBNOM,D1		; Open first, then the memory.
	MOVE.L	#$3ED,D2
	JSR	OPENFILE
	BEQ	LdDkBBad
	MOVE.L	D7,D0
	ADD.L	#1024,D0		; (as drive A: a little spare)
	MOVE.L	D0,BUCFILEB
	MOVE.L	#$10000,D1
	MOVE.L	4.W,A6
	JSR	-$C6(A6)		; AllocMem
	MOVE.L	D0,DIRFILEB
	BEQ.S	LdDkBNo
	MOVE.L	D0,D2
	MOVE.L	D7,D3
	JSR	READFILE
	JSR	CLOSEFILE
	MOVE.L	D7,DskBSize		; (for DiskBSave)
	SF	DskDirtyB
	BSR	ShowDiskB
DiskBGad:
	MOVE.B	#5,DirPrefs+$19		; Drive B: MVD (and the gadget,
	TST.L	MSX2WND			; so Power ON keeps it).
	BEQ.S	LdDkBW
	MOVEM.L	D0-D7/A0-A6,-(SP)
	LEA	MSX2Gadgets+(GD_DRIVEB*4),A0
	MOVE.L	MSX2WND,A1
	MOVE.L	#$8008000F,D0
	MOVEQ	#5,D1
	JSR	CanviTags
	MOVEM.L	(SP)+,D0-D7/A0-A6
LdDkBW:	RTS
LdDkBNo:
	CLR.L	BUCFILEB
	JSR	CLOSEFILE
LdDkBBad:
	CLR.B	DISKBNOM		; (no image: the Drive B row says so)
	BSR	ShowDiskB
LdDkBR:	RTS

; (4.6) The Drive B row of the main window: drive B's file name, without its
; path, or 'Buffer Empty.' (ShowDiskBT: the text at A0).
	CNOP	0,4
ShowDiskB:
	MOVEM.L	D0-D7/A0-A6,-(SP)
	LEA	DISKBNOM,A0
	MOVE.L	A0,A1
	TST.B	(A0)
	BNE.S	ShDkBN
	LEA	TVD0BEM,A0
	BRA.S	ShDkBT
ShDkBN:	MOVE.B	(A1)+,D0
	BEQ.S	ShDkBT
	CMP.B	#":",D0
	BEQ.S	ShDkBP
	CMP.B	#"/",D0
	BNE.S	ShDkBN
ShDkBP:	MOVE.L	A1,A0
	BRA.S	ShDkBN
ShDkBT:	BSR.S	ShowDiskBT
	MOVEM.L	(SP)+,D0-D7/A0-A6
	RTS
ShowDiskBT:
	LEA	MSX2IText10,A1
	JSR	PONOM
	MOVE.L	MSX2Wnd,D0
	BEQ.S	ShDkBR
	MOVE.L	D0,A0
	LEA	MSX2Text10,A1
	JMP	TxtPrint
ShDkBR:	RTS

	CNOP	0,4
	INCLUDE	"AmiMSX_Saves_v4.asm"	; (4.0) flash and drive B saves.
	CNOP	0,4
	INCLUDE	"AmiMSX_RomDb_v4.asm"	; (4.0) ROM database (mapper by SHA-1).

MSXEMUL:
