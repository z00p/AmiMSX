
;	Menu para MSX2 Emulator.
;	Por: Juan Antonio Gómez

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
	JSR	-$19E(A6)	; Libera Librería.
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
	TST.W	D0		; D0=Número de gadget.
	BEQ.S	ACTAGCON	; D1=Número de Tag a modificar.
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
	DC.L	INFOTEXT0,382
	DC.L	INFOTEXT1,382
	DC.L	INFOTEXT2,382
	DC.L	INFOTEXT3,382
	DC.L	INFOTEXT4,382
	DC.L	INFOTEXT5,382
	DC.L	INFOTEXT6,382
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
	DC.L	ShareInfoText0,352+2
	DC.L	ShareInfoText1,352
	DC.L	ShareInfoText2,352
	DC.L	ShareInfoText3,352
	DC.L	ShareInfoText4,352
	DC.L	ShareInfoText5,352
	DC.L	ShareInfoText6,352
	DC.L	ShareInfoText7,352
	DC.L	ShareInfoText8,352+2
	DC.L	ShareInfoText9,352
	DC.L	OutTimeText0,264
	DC.L	OutTimeText1,264
	DC.L	OutTimeText2,264
	DC.L	OutTimeText3,264+2
	DC.L	OutTimeText4,264
	DC.L	RegisterText0,558
	DC.L	RegisterText1,558
	DC.L	RegisterText2,558
	DC.L	RegisterText3,558
	DC.L	RegisterText4,558
	DC.L	RegisterText5,558
	DC.L	RegisterText18,558
	DC.L	RegisterText19,558
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
EFFICIEN:	DC.B	0
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
BucFileCart:	DC.L	0
DirKeyFile:	DC.L	0
BucKeyFile:	DC.L	0
DirKeyBuff:	DC.L	0
BYTEFILE:	DC.L	0
SLBUCFILE:	DC.L	0
TapeBUCFILE:	DC.L	0
BUCPROG:	DC.L	0
DIRIMPFILE:	DC.L	0
DirCaset:	DC.L	0
LoadCaset:	DC.L	0
SaveCaset:	DC.L	0
BucCaset:	DC.W	0
ModoCaset:	DC.B	0,0
SizeCaset:	DC.W	0
CheatDir:	DC.W	0
DirMonitor:	DC.W	0
IMPFILE:	DC.L	0
SpeedTest:	DC.L	0
		DC.L	0
FILENOM:	DS.B	$208
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
	BEQ.S	TrDumpFin
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
	BSR	CLOSEFILE
TrDumpFin:
	RTS
TraceName:	DC.B	"AmiMSX:trace.bin",0
	EVEN
	ENDC
AutoCart:	DC.B	0		; Test hook flags (see ANEM).
AutoGo:		DC.B	0
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

	JSR	SETUPSCREEN

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
	TST.B	LoROMBaDat(PC)		; ¿ROMs Base Leido Correctamente?
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
;	BSR	Password
; ------------------------------------------

	BSR	ABREDEVICE

;;;	BSR	MiraSpeed

; ------------------------------------------

	TST.B	AutoCart		; Test hook: no splash.
	BNE.S	NoShowMatra
	BSR	ShowMatra
NoShowMatra:

; ------------------------------------------

	IFNE	Usuario=-99
	BSR	ShowShareInfo		; Modo Shareware.
	OR.W	#$0010,MSX2NEWMENU14+$A
	ELSEIF
	IFEQ	Key_ON
;	BSR	ShowInfo		; Modo Key ON.
	ELSEIF
	IFNE	Usuario
	BSR	ShowInfo		; Modo Registrado.
	ENDC
	ENDC
	ENDC

; ------------------------------------------


	MOVEM.L	MCEROS,D0-D7/A0-A6
	JSR	OPENMSX2WINDOW

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
	MOVE.L	50(A0),A0
	LEA	DATMSXPIC,A1
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
	ST	AutoGo
NoAutoCart2:

BUCLEMENU:

; --------------------------
	LEA	DIRPrefs,A5
	MOVEQ	#0,D0
	MOVE.B	$1C(A5),D0
	BSR	COGEMEM
; --------------------------

	LEA	MSX2PUNTS,A1
	BSR	CONTROL
QUIT:
	TST.B	MVDMODIFI
	BNE	QUITMVD

	BSR	DISMOUSE
	MOVEM.L	MCEROS,D0-D7/A0-A6
	JSR	OPENQUITWINDOW
	LEA	QUITPUNTS,A1
	BSR	CONTROL
	JSR	CLOSEQUITWINDOW
	BSR	ENAMOUSE

	JSR	CLOSEMSX2WINDOW
QUITAR:
; --------------------------
; --------------------------		; Screen mode on Exit.
	MOVE.B	DirPrefs+$7C(PC),D0
	LSR.B	#1,D0
	BEQ.S	NoChangeCon
	MOVEQ	#0,D1
	LSR.B	#1,D0
	BNE.S	EsNTSC2
	MOVE.W	#$20,D1
EsNTSC2:MOVE.W	D1,$DFF1DC
NoChangeCon:
; --------------------------
	JSR	CLOSEDOWNSCREEN
	MOVEQ	#0,D0
	RTS
; ---
QUITMVD:
	BSR	DISMOUSE
	MOVEM.L	MCEROS(PC),D0-D7/A0-A6
	JSR	OPENQUITMVDWINDOW
	LEA	QUITMVDPUNTS,A1
	BSR	CONTROL
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
SHOWINFO:
	BSR	DisMouse
	MOVEM.L	MCEROS(PC),D0-D7/A0-A6
	JSR	OPENINFOWINDOW
	LEA	INFOPUNTS,A1
	BSR	CONTROL
	JSR	CLOSEINFOWINDOW
	BSR	EnaMouse
	RTS
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
ShowShareInfo:
	BSR	DisMouse
	MOVEM.L	MCEROS(PC),D0-D7/A0-A6
	JSR	OPENShareInfoWINDOW
	LEA	ShareInfoPUNTS,A1
	BSR	CONTROL
	JSR	CLOSEShareInfoWINDOW
	BSR	EnaMouse
	RTS
ShowRegisterShare:
	JSR	CLOSEShareInfoWINDOW
	BSR	EnaMouse
	ADD.W	#16+4,SP
	BRA.S	ShowRegister
; -----------------------------------
ShowOutTime:
	BSR	DisMouse
	MOVEM.L	MCEROS(PC),D0-D7/A0-A6
	JSR	OPENOutTimeWINDOW
	LEA	OutTimePUNTS,A1
	BSR	CONTROL
	JSR	CLOSEOutTimeWINDOW
	BSR	ENAMOUSE
	RTS
ShowRegisterOut:
	JSR	CLOSEOutTimeWINDOW
	BSR	EnaMouse
	ADD.W	#16+4,SP
	NOP			; was: BRA.S	ShowRegister (zero-length short branch)
; -----------------------------------
ShowRegister:
	BSR	DisMouse
	MOVEM.L	MCEROS(PC),D0-D7/A0-A6
	JSR	OPENRegisterWINDOW
	LEA	RegisterPUNTS,A1
	BSR	CONTROL
	JSR	CLOSERegisterWINDOW
	BSR	EnaMouse
	RTS
; -----------------------------------
NOIMP:
	BSR	DISMOUSE
	LEA	TLEEnoimp(PC),A0
	BRA	IMPERROR
	BSR	ENAMOUSE
	RTS
; -----------------------------------
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
REINTMODE:
	CLR.L	REINTMODETAGS+4
	MOVEQ	#12,D0			; Nº Línea.
	MOVEQ	#1,D1			; Nº menu.
	BSR	COGECHECK
	BNE.S	REINTMOFF
	MOVE.L	#1,REINTMODETAGS+4
REINTMOFF:
	LEA	MSX2Gadgets,A0
	ADD.W	#(GD_MSX2Spr*4),A0
	MOVE.L	(A0),A0
	MOVE.L	MSX2WND,A1
	SUB.L	A2,A2
	LEA	REINTMODETAGS,A3
	MOVE.L	_GadToolsBase,A6
	JSR	-$2A(A6)
	RTS

REINTMODETAGS:
	DC.L    $8003000E,1
	DC.L	0
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

	MOVEQ	#(0*$40)+3,D0		; Nº Línea. (Sub-Item+Item)
	MOVEQ	#3,D1			; Nº menu.
	BSR	COGECHECK
	AND.W	#$FFEF,$C(A0)

	LEA	MSX2Gadgets+(GD_Slot2*4),A0
	MOVE.L	MSX2WND,A1
	MOVEQ	#1,D0
	BSR	GadsOnOff
	RTS

DiskROMVerOff:
	move.l  MSX2Wnd,a0
	lea	MSX2Text9,a1
	MOVE.L	#MSX2IText9,$0C(A1)
	BSR	TxtPrint

	MOVEQ	#(0*$40)+3,D0		; Nº Línea. (Sub-Item+Item)
	MOVEQ	#3,D1			; Nº menu.
	BSR	COGECHECK
	OR.W	#$0010,$C(A0)

	LEA	MSX2Gadgets+(GD_Slot2*4),A0
	MOVE.L	MSX2WND,A1
	MOVEQ	#0,D0
	BSR	GadsOnOff
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
	jsr     PrintIText(a6)
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
	TST.B	GoDat(PC)		; ¿MSX Encendido?
	BEQ	ErPowerON
	ENDC

	TST.B	DisCheaDat(PC)		; ¿Modo Cheat activo?
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
	jsr     PrintIText(a6)

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
	jsr     PrintIText(a6)

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

	TST.B	DisCheaDat(PC)		; ¿Modo Cheat activo?
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
	jsr     PrintIText(a6)
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
	CNOP	0,4
Password:
	BSR	DisMouse
	MOVEM.L	MCeros(PC),D0-D7/A0-A6
	JSR	OpenPasswordWindow
	LEA	PasswordPunts,A1
	BSR	Control
	JSR	ClosePasswordWindow
	BSR	EnaMouse
	RTS
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

	MOVE.L	#(0*$40)+11,D0		; Nº Línea. (Sub-Item+Item)
	MOVEQ	#1,D1			; Nº menu.
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
	LEA	ABOUTPUNTS,A1
	BSR	CONTROL
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
ADDRESS2:
	ADD.W	#16+4,SP
	JSR	CLOSEABOUTWINDOW
	BRA.S	ADDRESSC
ADDRESS:
	ADD.W	#16+4,SP
	JSR	CLOSEABOUTWINDOW
ADDRESSC:
;;;	BSR	DISMOUSE		; ya lo hace About (sino bug)
	MOVEM.L	MCEROS(PC),D0-D7/A0-A6
	JSR	OPENADDRESSWINDOW
	LEA	ADDRESSPUNTS,A1
	BSR	CONTROL
	JSR	CLOSEADDRESSWINDOW
	BSR	ENAMOUSE
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

	MOVEQ	#(0*$40)+0,D0		; Nº Línea. (Sub-Item+Item)
	MOVEQ	#4,D1			; Nº menu.
	BSR	COGECHECK
	AND.W	#$FFEF,$C(A0)

	MOVEQ	#(0*$40)+4,D0		; Nº Línea. (Sub-Item+Item)
	MOVEQ	#4,D1			; Nº menu.
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

	MOVEQ	#(0*$40)+0,D0		; Nº Línea. (Sub-Item+Item)
	MOVEQ	#4,D1			; Nº menu.
	BSR	COGECHECK
	OR.W	#$0010,$C(A0)

	MOVEQ	#(0*$40)+4,D0		; Nº Línea. (Sub-Item+Item)
	MOVEQ	#4,D1			; Nº menu.
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
Sl1MapRut:
	MOVE.L	#(0*$40)+1,D0		; Nº Línea. (Sub-Item+Item)
	MOVEQ	#3,D1			; Nº menu.
	MOVEQ	#7-1,D4

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
Sl2MapRut:
	MOVE.L	#(0*$40)+4,D0		; Nº Línea. (Sub-Item+Item)
	MOVEQ	#3,D1			; Nº menu.
	MOVEQ	#7-1,D4

	NOP			; was: BRA.S	PoneOptMenus (zero-length short branch)

; -----------------------------------

; -----------------------------------


PoneOptMenus:
;;	MOVEQ	#$40,D3			; D3 = Bits a 0 = OFF, bit a 1 = ON
;;	MOVE.L	#(0*$40)+1,D0		; D0 = Nº Línea. (Sub-Item+Item)
;;	MOVEQ	#3,D1			; D1 = Nº menu.
;;	MOVEQ	#7-1,D4			; D4 = Nº de Líneas en Menú
PoOpMeBuc:
	MOVEM.L	D0-D4,-(SP)
	BSR	COGECHECK
	MOVEM.L	(SP)+,D0-D4

	BCLR	#0,$C(A0)
	LSR.B	#1,D3
	BCC.S	PoOpMeCon
	BSET	#0,$C(A0)
PoOpMeCon:
	ADD.W	#(1*$40),D0
	DBF	D4,PoOpMeBuc
	RTS

; -----------------------------------


NoChange:
	MOVEQ	#$01,D3
	MOVE.B	D3,DirPrefs+$7C
	BRA.S	SetScrExit
ForcePAL:
	MOVEQ	#$02,D3
	MOVE.B	D3,DirPrefs+$7C
	BRA.S	SetScrExit
ForceNTSC:
	MOVEQ	#$04,D3
	MOVE.B	D3,DirPrefs+$7C
SetScrExit:
	MOVE.L	#(0*$40)+12,D0		; Nº Línea. (Sub-Item+Item)
	MOVEQ	#1,D1			; Nº menu.
	MOVEQ	#3-1,D4

	BRA.S	PoneOptMenus
	
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

	CMP.L	#($2080*5),BucCart	; ¿Es mayor de 40Kb?
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
	CMP.W	#-1,MapperIDInit+$10		; ¿Máximo de mappers?
	BEQ	ImpError

	MOVE.L	#AmiMSX2mapper,D1
	MOVE.L	#$3EE,D2
	BSR	OpenFile
	BEQ	NoAmiSavMapp

	TST.B	SiNewMapp(PC)
	BEQ.S	NoNewMapp2
	ADDQ.W	#1,MapperIdInit+$10		; Suma un Mapper más.
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
	MOVEQ	#(1*$40)+0,D0		; Nº Línea. (Sub-Item+Item)
	MOVEQ	#3,D1			; Nº menu.
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
	BRA.S	Eject
EjectSl2:
	MOVEQ	#(1*$40)+3,D0		; Nº Línea. (Sub-Item+Item)
	MOVEQ	#3,D1			; Nº menu.
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
	MOVE.L	#(1*$40)+0,DatItem

	MOVE.L	DirCartS1(PC),DirCart
	MOVE.L	BucCartS1(PC),BucCart
	MOVE.L	BucCartAddS1(PC),BucCartAdd2
	MOVE.W	PagCartS1(PC),PagCart
	MOVE.L	#Slot1Cart,SlotxCart

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
	RTS

	CNOP	0,8
InsertSl2:
	MOVE.L	#MSX2IText9,DatTxt
	MOVE.L	#(1*$40)+3,DatItem

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
	TST.B	AutoCart		; Test hook: FILENOM set from the CLI.
	BEQ.S	InsertReq
	SF	AutoCart
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

	LEA	XpkFibBase,A0		; ¿Fichero xpk?
	LEA	xpkTags0(PC),A1
	MOVE.L	_xpkBase,A6
	JSR	-54(A6)		; xpkOpen
	BNE.S	NoXpkFile

	MOVE.L	XpkFibBase,A0		; ¿Comprimido con xpk?
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
	BSR	CalCheckCart		; Calcula Check-Sum
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
	BSR	NoCartrID
	BNE.S	IDCorrecta

	MOVE.L	BucCart(PC),D0		; Libera Memoria por Cancel en ID.
	ADD.L	BucCartAdd(PC),D0
	MOVE.L	DirCart(PC),A1
	MOVE.L	$4.W,A6
	JSR	-$D2(A6)		; Libera memoria.
	CLR.L	BucCart

	LEA	TNOFile,A0
	BRA.S	NoInsert
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

	MOVE.L	DatItem,D0		; Nº Línea. (Sub-Item+Item)
	MOVEQ	#3,D1			; Nº menu.
	BSR	COGECHECK
	OR.W	#$0010,$C(A0)

; -=-=-=-

	MOVE.L	REQBASESLOT,A2
	MOVE.L	4(A2),A0
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
	jsr     PrintIText(a6)


;	LEA	GameBoyGadgets+(GD_Continue*4),A0
;	MOVE.L	GameBoyWND,A1
;	MOVEQ	#1,D0
;	BSR	GadsOnOff



	BSR	EnaMouse
	RTS


MiraMSXCartSize:
	MOVE.L	D0,D1
	AND.L	#$3FFF,D1
	MOVE.L	D1,BucCartAdd

	CMP.L	#$4000,D0		; mira mínimo 16Kb
	BCS.S	NoMSXCartCon

	LSR.L	#8,D0
	LSR.L	#6,D0
	CMP.L	#$100,D0			; mira máximo 4Mb (ASCII16: 256 x 16Kb)
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

	CMP.L	#($2080*5),BucCart	; ¿Es mayor de 40Kb?
	BCC.S	MiConMapper0
MiStdMapper:
	MOVE.W	#-1,D0			; Mapper Standard.
	RTS

MiConMapper0:
	MOVE.L	DirCart(PC),A0		; Linear 48/64Kb cart: Standard.
	MiraLin	A0,BucCart,D0
	BNE.S	MiStdMapper
	BSR.S	MiConMapper		; Mapper saved for this cartridge?
	TST.B	SiNewMapp(PC)
	BEQ.S	MiConMapFin
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
;	DC.L	$80005853,Bloque de memoría donde leer.
;	DC.L	$80005860,Nombre del Fichero a crear/reescribir.
;	DC.L	$80005861,FileHandle (retorno del dosOpen) escritura.
;	DC.L	$80005862,Bloque de memoría donde escribir.
;	DC.L	$80005870,Size del bufer donde leer.
;	DC.L	$80005871,Size del bufer donde escribir.
;	DC.L	$80005877,=1 Soportar leer ficheros no xpkeados!

; ------------------------------------------





; -----------------------------------
	CNOP	0,4
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
	jsr     PrintIText(a6)
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
	SF	MVDMODIFI			; MVD cambiado.
	MOVE.L	#361*1024,-(SP)
	BRA.S	FOR2DDCON2
FORMAT2DD:
	SF	MVDMODIFI			; MVD cambiado.
	MOVE.L	#721*1024,-(SP)
FOR2DDCON2:
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
	DC.W	$000,$004,$600,$604,$060,$064,$660,$664
	DC.W	$E84,$00E,$E00,$E0E,$0E0,$0EE,$EE0,$EEE

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
SaveCartridge:
	IFD	MENU
	TST.B	GoDat(PC)
	BEQ	ErPowerON
	ENDC

	MOVE.L	Slot3+8,A0
	ADD.L	#$4000,A0
	CMP.W	#"AB",(A0)
	BEQ.S	SavePage12

	MOVE.L	Slot3+16,A0
	ADD.L	#$8000,A0
	CMP.W	#"AB",(A0)
	BEQ.S	SavePage2

	LEA	TLEENOCarID,A0
	JMP	IMPERROR

	CNOP 	0,4
SavePage1:
	IFD	MENU
	TST.B	GoDat(PC)
	BEQ	ErPowerON
	ENDC

	MOVE.L	Slot3+8,IniSlot3s
	ADD.L	#$4000,IniSlot3s
	SF	MulSavePage
	BRA.S	SavePageCon
SavePage2:
	IFD	MENU
	TST.B	GoDat(PC)
	BEQ	ErPowerON
	ENDC

	MOVE.L	Slot3+16,IniSlot3s
	ADD.L	#$8000,IniSlot3s
	SF	MulSavePage
	BRA.S	SavePageCon
SavePage12:
	IFD	MENU
	TST.B	GoDat(PC)
	BEQ	ErPowerON
	ENDC

	MOVE.L	Slot3+8,IniSlot3s
	ADD.L	#$4000,IniSlot3s
	ST	MulSavePage
SavePageCon:
	BSR	DISMOUSE

	MOVE.L	ReqBaseSlot,A0
	LEA	TAGSavPage,A1
	MOVE.L	_ASLBASE,A6
	JSR	-$3C(A6)	; RequestFile.

	MOVE.L	D0,-(SP)
	BSR	ENAMOUSE
	MOVE.L	(SP)+,D0

	TST.L	D0
	BEQ	SLCANCEL

	MOVE.L	ReqBaseSlot,A2
	LEA	FILENOM(PC),A1
	MOVE.W	#$100-1,D0
	MOVE.L	8(A2),A0
	TST.B	(A0)
	BEQ.S	CHAPUZ2p
	BSR	COPYNOM
	SUBQ	#1,A1
	CMP.B	#":",-1(A1)
	BEQ.S	CHAPUZ2p
	MOVE.B	#"/",(A1)+
CHAPUZ2p:
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

	MOVE.L	#(16*1024),D3
	MOVE.L	IniSlot3s,D2
	BSR	WRITEFILE

	TST.B	MulSavePage(PC)
	BEQ.S	SavePageCon0

	MOVE.L	#(16*1024),D3
	MOVE.L	Slot3+16,D2
	ADD.L	#$8000,D2
	BSR	WRITEFILE
SavePageCon0:

	BSR	CLOSEFILE
	BSR	ENAMOUSE
	RTS

	CNOP	0,4
IniSlot3s:	DC.L	0
MulSavePage:	DC.B	0,0
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
;	DC.L	$8008000A,PatrÓn
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

TAGSSaveImp:
	DC.L	$80080012,tSave
	DC.L	$80080001,tSavImp
	DC.L	$8008002C,1		; 1=Modo Save.
	DC.L	0

TAGSavPage:
	DC.L	$80080012,tSave
	DC.L	$80080001,tSavPage
	DC.L	$8008002C,1		; 1=Modo Save.
	DC.L	0


	CNOP	0,4
DirMVD:	DC.B	"MVD_Files",0,0
DirCartr:DC.B	"Cartridges",0,0
DirTape:DC.B	"Tape",0,0

	CNOP	0,4
tLOAD:	DC.B	"Load",0,0
tSAVE:	DC.B	"Save",0,0
tOK:	DC.B	"¡Ok!",0,0

tMVDLoad:DC.B	"Load MSX Virtual Disk File.",0,0
tMVDSave:DC.B	"Save MSX Virtual Disk File.",0,0
tSlot:	DC.B	"Load MSX Cartridge File.",0,0
tSavVRAM:DC.B	"Save VRAM/Screen.",0,0
tSavRAM:DC.B	"Save MSX RAM.",0,0
tSavSpr:DC.B	"Save Sprites.",0,0
tSavImp:DC.B	"Save Imploded MVD File.",0,0
tSavPage:DC.B	"Save MSX Cartridge File.",0,0
tLoadTape:DC.B	"Load Tape File.",0,0
tSaveTape:DC.B	"Save Tape File.",0,0

; --------------------------------------
	CNOP	0,4
IMPLODER:
	TST.L	BUCFILE
	BNE.S	IMPLODERC

	LEA	TLEENOFILE,A0
	BSR	IMPERROR
	RTS

	CNOP	0,4
IMPLODERC:
	ST	EFFICIEN
	BSR	DISMOUSE

	LEA	IMPLODERGTags,A0
	MOVE.W	#GD_EFFIMP,D0
	MOVE.L	#$8008000F,D1
	MOVEQ	#0,D2
	LEA	DIRPrefs(PC),a5
	MOVE.B	$66(A5),D2
	BSR	ACTUTAGS

	MOVEM.L	MCEROS(PC),D0-D7/A0-A6
	JSR	OPENIMPLODERWINDOW

	LEA	IMPLODERPUNTS,A1
	BSR	CONTROL

	LEA	IMPLODERGadgets,A0
	ADD.W	#(GD_EFFIMP*4),A0
	MOVE.L	(A0),A1
	LEA	DIRPrefs(PC),a5
	MOVE.B	$57(A1),$66(A5)

	MOVE.L	DIRIMPFILE,D0
	BEQ.S	NOHAYMEM2DX
	MOVE.L	D0,A1
	MOVE.L	BUCFILE,D0
	MOVE.L	4.W,A6
	JSR	-$D2(A6)		; Libera memoria.
	CLR.L	DIRIMPFILE
NOHAYMEM2DX:

	JSR	CLOSEIMPLODERWINDOW
	BSR	ENAMOUSE
	RTS


	CNOP	0,4
IMPLODING:
	LEA	IMPLODERGadgets,A0
	ADD.W	#(GD_EFFIMP*4),A0
	MOVE.L	(A0),A1
	MOVEQ	#0,D1
	MOVE.B	$57(A1),D1
	MOVE.B	(EFFICI.W,PC,D1.W),D1
	MOVE.B	D1,DIRPrefs+$66

	CMP.B	EFFICIEN,D1
	BNE.S	IMPLODINGCON
	RTS

IMPLODINGCON:
	ST	EFFICIEN

	MOVE.L	IMPLODERWND,A0
	BSR	PBUSY

	MOVE.L	DIRIMPFILE,D0
	BEQ.S	NOHAYMEM2DXH
	MOVE.L	D0,A1
	MOVE.L	BUCFILE,D0
	MOVE.L	4.W,A6
	JSR	-$D2(A6)		; Libera memoria.
	CLR.L	DIRIMPFILE
NOHAYMEM2DXH:
	MOVE.L	#$10000,D1
	MOVE.L	BUCFILE,D0
	MOVE.L	4.W,A6
	JSR	-$C6(A6)		; Requiere memoria.
	MOVE.L	D0,DIRIMPFILE
	BNE.S	IMPLODINGC

	MOVE.L	#TIMPTXT4,IMPLODERDIRTXT
	MOVE.L	#1,SAIMPLOTAGS+4
	BRA	IMPLOERROR

IMPLODINGC:
	MOVE.L	DIRFILE,A0
	MOVE.L	DIRIMPFILE,A1
	MOVE.L	BUCFILE,D0
	LSR.L	#2,D0
IMPCOPYBUC:
	MOVE.L	(A0)+,(A1)+
	SUBQ.L	#1,D0
	BNE.S	IMPCOPYBUC

	MOVE.L	#"   0",TIMPTXT1+$0D
	MOVE.W	#"  ",TIMPTXT1+$19
	MOVE.L	#"   0",TIMPTXT1+$1B
	MOVE.L	#TIMPTXT1,IMPLODERDIRTXT
	move.l  IMPLODERWnd,a0
	move.b  54(a0),d0
	ext.w   d0
	move.b  55(a0),d1
	ext.w   d1
	move.l  50(a0),a0
	lea     IMPLODERTextO(PC),a1
	move.l  _IntuitionBase,a6
	JSR     PrintIText(a6)


	MOVE.L	DIRIMPFILE,A0
	MOVE.L	BUCFILE,D0
	SUB.L	#(1024),D0
	MOVE.L	D0,BUCPROG
	LEA	IMPCONTROL,A1

	MOVEQ	#0,D1
	MOVE.B	DIRPrefs+$66,D1

	MOVE.L	#1,SAIMPLOTAGS+4
	BSR	CAMBIAGADS
; ---
	BSR	IMPLODE
; ---
	CLR.L	SAIMPLOTAGS+4
	BSR	CAMBIAGADS


	MOVE.L	#TIMPTXT3,IMPLODERDIRTXT
	MOVE.L	#1,SAIMPLOTAGS+4

	MOVE.L	D0,IMPFILE
	BEQ	IMPLOERROR
	BMI	IMPLOERROR

	BSR	PASDEC
	MOVE.W	4(A0),TIMPTXT2+$9
	MOVE.L	6(A0),TIMPTXT2+$B

	MOVE.L	BUCPROG,D0
	MOVE.L	D0,D2
	MOVE.L	IMPFILE,D1
	SUB.L	D1,D0
	MOVE.L	BUCPROG,D2
	DIVU	#100,D2
	DIVU	D2,D0
	AND.L	#$FFFF,D0
	BSR	PASDEC
	MOVE.B	8(A0),TIMPTXT2+$12
	MOVE.B	9(A0),TIMPTXT2+$13

	MOVE.L	#TIMPTXT2,IMPLODERDIRTXT
	CLR.L	SAIMPLOTAGS+4

	MOVE.B	DIRPrefs+$66,EFFICIEN

IMPLOERROR:
	LEA	IMPLODERGadgets,A0
	ADD.W	#(GD_SAVEIMP*4),A0
	MOVE.L	(A0),A0
	MOVE.L	IMPLODERWND,A1
	SUB.L	A2,A2
	LEA	SAIMPLOTAGS(PC),A3
	MOVE.L	_GadToolsBase,A6
	JSR	-$2A(A6)

	move.l  IMPLODERWnd,a0
	move.b  54(a0),d0
	ext.w   d0
	move.b  55(a0),d1
	ext.w   d1
	move.l  50(a0),a0
	lea     IMPLODERTextO(PC),a1
	move.l  _IntuitionBase,a6
	JSR     PrintIText(a6)

	MOVE.L	IMPLODERWND,A0
	BSR	PNORM
	RTS

SAIMPLOTAGS:
	DC.L    $8003000E,0
	DC.L	0

	CNOP	0,4
EFFICI:	DC.B	1,4,7,9,10,11,11
	CNOP	0,4
TIMPTXT0:DC.B	"       The File Imploder.       ",0
TIMPTXT1:DC.B	" Imploding...  26% Done, 737280 ",0,0
TIMPTXT2:DC.B	"   Size: 000000,   0% gained.   ",0
TIMPTXT3:DC.B	"      I cannot implode it!      ",0
TIMPTXT4:DC.B	"    -=>  Out of Memory!  <=-    ",0

; -----------------------------------
	ds.l	10
; -----------------------------------

; -----------------------------------
	CNOP	0,4
SAVEIMPLODED:
	TST.L	_ASLBase(PC)
	BEQ	NeedASL

	MOVE.L	REQBASE,A0
	LEA	TAGSSaveImp(PC),A1
	MOVE.L	_ASLBASE,A6
	JSR	-$3C(A6)	; RequestFile.

	TST.L	D0
	BEQ	SLCANCEL

	MOVE.L	REQBASE,A2
	LEA	FILENOM(PC),A1
	MOVE.W	#$100-1,D0
	MOVE.L	8(A2),A0
	TST.B	(A0)
	BEQ.S	CHAPUZ2V
	BSR	COPYNOM
	SUBQ	#1,A1
	CMP.B	#":",-1(A1)
	BEQ.S	CHAPUZ2V
	MOVE.B	#"/",(A1)+
CHAPUZ2V:
	MOVE.W	#$100-1,D0
	MOVE.L	4(A2),A0
	BSR	COPYNOM

	BSR	OverWrite
	BEQ	NoOverwrite

	MOVE.L	#FILENOM,D1
	MOVE.L	#$3EE,D2
	BSR	OPENFILE
	BEQ	DISERROR

	LEA	TSAVEIMP,A0
	BSR	IMPDISK

	MOVE.L	IMPFILE,D3
	MOVE.L	DIRIMPFILE,D2
	BSR	WRITEFILE
	BSR	CLOSEFILE

	move.l  LOADDECWnd,a0
	BSR	PNORM
	JSR	CLOSELOADDECWINDOW

	SF	MVDMODIFI		; MVD ya grabado.

	RTS

	CNOP	0,4
CAMBIAGADS:
	MOVEM.L	D0-D7/A0-A6,-(SP)
	MOVE.W	#(GD_IMPLODE*4),D0
	BSR	CAMHAZLO
	MOVE.W	#(GD_CANCELIMP*4),D0
	BSR	CAMHAZLO
	MOVE.W	#(GD_EFFIMP*4),D0
	BSR	CAMHAZLO
	MOVE.W	#(GD_SAVEIMP*4),D0
	BSR	CAMHAZLO
	MOVEM.L	(SP)+,D0-D7/A0-A6
	RTS

CAMHAZLO:
	LEA	IMPLODERGadgets,A0
	MOVE.L	(A0,D0.W),A0
	MOVE.L	IMPLODERWND,A1
	SUB.L	A2,A2
	LEA	SAIMPLOTAGS(PC),A3
	MOVE.L	_GadToolsBase,A6
	JMP	-$2A(A6)

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
	BSR	ERRSALI2		; ¡Cuidado!

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
	JSR     PrintIText(a6)
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
	JSR     PrintIText(a6)
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
	ADD.L	D5,D1			; Según 1DD o 2DD
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
	JSR     PrintIText(a6)
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
TLEEnoimp:	DC.B	"       Not implemented!       ",0
TLEEprefs:	DC.B	"    Preferences not saved!    ",0
TLEENOTMD:	DC.B	"     Not a MSX Disk File.     ",0
TLEECANTO:	DC.B	"      I Can't open file.      ",0
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
	JSR     PrintIText(a6)
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
TSAVEIMP:	DC.B	" Saving Imploded MVD ",0
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

	TST.B	LoROMBaDat(PC)		; ¿ROMs Base Leido Correctamente?
	BNE.S	LoadROMsRut
	RTS

LoadROMsRut:
	MOVE.L	#AmiMSX2Data,D1
	MOVE.L	#$3ED,D2
	BSR	OpenFile
	BEQ	NoHayROMs
;	--------------
	LEA	DIRPrefs,A5
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
	TST.B	DirPrefs+$7B(PC)	; ¿Usar Kanji ROM?
	BEQ	AmiRET
	TST.B	KanjiDat(PC)		; ¿Está ya residente?
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
	CLR.W	MapperIDInit+$10	; Borra Nº de mappers guardados.

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
	MOVE.W	MapperIDBuf+$10,D0	; Nº de mappers guardados.
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

	MOVE.W	MapperIDBuf+$10,MapperIDInit+$10  ; Nº de mappers guardados.

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

	MOVE.L	#NOMPREFS,D1
	MOVE.L	#1006,D2
	BSR	OPENFILE
	BEQ.S	ERDEVICE2

	MOVE.L	#DIRPREFS,D2
	MOVE.L	#BUCPREFS,D3
	BSR	WRITEFILE
	BNE.S	ERDEVICE2

	BSR	CLOSEFILE
	RTS

	CNOP	0,4
ERDEVICE2:
	BSR	CLOSEFILE
	LEA	TLEEprefs(PC),A0
	BRA	IMPERROR
	RTS

	CNOP	0,8
NomPrefs:
	DC.B	"S:AmiMSX2.prefs",0,0,0,0
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
	JSR	-36(A6)			; CLOSE
	CLR.L	DISBASE
	RTS
WRITEFILE:
	MOVE.L	_DOSBASE,A6
	MOVE.L	DISBASE,D1
	MOVE.L	D3,-(SP)
	JSR	-48(A6)			; WRITE
	MOVE.L	(SP)+,D3
	CMP.L	D0,D3
	RTS
READFILE:
	MOVE.L	_DOSBASE,A6
	MOVE.L	DISBASE,D1
	MOVE.L	D3,-(SP)
	JSR	-42(A6)			; READ
	MOVE.L	(SP)+,D3
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
	MOVE.L	#(0*$40)+7,D0		; Nº Línea. (Sub-Item+Item)
	MOVEQ	#2,D1			; Nº menu.
	BSR	COGECHECK
	BSET	#0,$C(A0)
	MOVE.L	#(1*$40)+7,D0		; Nº Línea. (Sub-Item+Item)
	MOVEQ	#2,D1			; Nº menu.
	BSR	COGECHECK
	BCLR	#0,$C(A0)
	MOVE.L	#(2*$40)+7,D0		; Nº Línea. (Sub-Item+Item)
	MOVEQ	#2,D1			; Nº menu.
	BSR	COGECHECK
	BCLR	#0,$C(A0)
	RTS
BootType1DD:
	MOVE.B	#$02,DirPrefs+$6D
	MOVE.L	#(0*$40)+7,D0		; Nº Línea. (Sub-Item+Item)
	MOVEQ	#2,D1			; Nº menu.
	BSR	COGECHECK
	BCLR	#0,$C(A0)
	MOVE.L	#(1*$40)+7,D0		; Nº Línea. (Sub-Item+Item)
	MOVEQ	#2,D1			; Nº menu.
	BSR	COGECHECK
	BSET	#0,$C(A0)
	MOVE.L	#(2*$40)+7,D0		; Nº Línea. (Sub-Item+Item)
	MOVEQ	#2,D1			; Nº menu.
	BSR	COGECHECK
	BCLR	#0,$C(A0)
	RTS
BootType2DD:
	MOVE.B	#$04,DirPrefs+$6D
	MOVE.L	#(0*$40)+7,D0		; Nº Línea. (Sub-Item+Item)
	MOVEQ	#2,D1			; Nº menu.
	BSR	COGECHECK
	BCLR	#0,$C(A0)
	MOVE.L	#(1*$40)+7,D0		; Nº Línea. (Sub-Item+Item)
	MOVEQ	#2,D1			; Nº menu.
	BSR	COGECHECK
	BCLR	#0,$C(A0)
	MOVE.L	#(2*$40)+7,D0		; Nº Línea. (Sub-Item+Item)
	MOVEQ	#2,D1			; Nº menu.
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

	LEA	MSX2GTags,A0
	MOVE.W	#GD_CPUspd,D0
	MOVE.L	#$8008000F,D1
	MOVEQ	#0,D2
	MOVE.B	$7E(A5),D2
	BSR	ACTUTAGS


	MOVE.B	$13(A5),D0
	BFINS	D0,MSX2NewMenu17+10{7:1}	; JoyStick On.

	MOVE.B	$6A(A5),D0
	BFINS	D0,MSX2NewMenu18+10{7:1}	; Swap JoyPorts.
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

	MOVE.B	$6C(A5),D0
	BFINS	D0,MSX2NewMenu40+10{7:1}	; Sprites Collisions

	MOVE.B	$6E(A5),D0
	BFINS	D0,MSX2NewMenu41+10{7:1}	; VDP 'TR bit' always ready
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

	MOVE.B	$7C(A5),D0
	BFINS	D0,MSX2NewMenu34+10{7:1}	; Set Screen on Exit 'No Change'
	LSR.B	#1,D0
	BFINS	D0,MSX2NewMenu35+10{7:1}	; Set Screen on Exit 'Force PAL'
	LSR.B	#1,D0
	BFINS	D0,MSX2NewMenu36+10{7:1}	; Set Screen on Exit 'Force NTSC'

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

;;;	BSR	REINTMODE
	RTS
; -----------------------------------
	CNOP	0,4
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
	MOVE.B	([MSX2Gadgets+(GD_CPUspd*4)],$57.w),$7E(A5)	; Emulation Speed.


	MOVEQ	#0,D0			; Nº Línea.
	MOVEQ	#1,D1			; Nº menu.
	BSR	COGECHECK
	SNE	$13(A5)			; JoyStick 2 ON

	MOVEQ	#1,D0			; Nº Línea.
	MOVEQ	#1,D1			; Nº menu.
	BSR	COGECHECK
	SNE	$6A(A5)			; Swap JoyPorts
; -=-
	MOVEQ	#3,D0			; Nº Línea.
	MOVEQ	#1,D1			; Nº menu.
	BSR	COGECHECK
	SNE	$12(A5)			; Multi-Key ON

	MOVEQ	#4,D0			; Nº Línea.
	MOVEQ	#1,D1			; Nº menu.
	BSR	COGECHECK
	SNE	$1E(A5)			; DEL como Pausa

	MOVEQ	#5,D0			; Nº Línea.
	MOVEQ	#1,D1			; Nº menu.
	BSR	COGECHECK
	SNE	$62(A5)			; L.Shift as Space

	MOVEQ	#6,D0			; Nº Línea.
	MOVEQ	#1,D1			; Nº menu.
	BSR	COGECHECK
	SNE	$63(A5)			; R.Shift as Space
; -=-
	MOVE.L	#(0*$40)+8,D0		; Nº Línea. (Sub-Item+Item)
	MOVEQ	#1,D1			; Nº menu.
	BSR	COGECHECK
	SNE	$7A(A5)			; Use Japanese ID

	MOVE.L	#(0*$40)+9,D0		; Nº Línea. (Sub-Item+Item)
	MOVEQ	#1,D1			; Nº menu.
	BSR	COGECHECK
	SNE	$7B(A5)			; Use Kanji ROM.
; -=-
	MOVE.L	#(0*$40)+11,D0		; Nº Línea. (Sub-Item+Item)
	MOVEQ	#1,D1			; Nº menu.
	BSR	COGECHECK
	SNE	$61(A5)			; Write Protected

	MOVE.L	#(2*$40)+11,D0		; Nº Línea. (Sub-Item+Item)
	MOVEQ	#1,D1			; Nº menu.
	BSR	COGECHECK
	SNE	$78(A5)			; Avisar al intentar Escribir.

	MOVE.L	#(3*$40)+11,D0		; Nº Línea. (Sub-Item+Item)
	MOVEQ	#1,D1			; Nº menu.
	BSR	COGECHECK
	SNE	$79(A5)			; Avisar al Salir si MVD modificado.
; -=-
	MOVE.L	#(0*$40)+13,D0		; Nº Línea. (Sub-Item+Item)
	MOVEQ	#1,D1			; Nº menu.
	BSR	COGECHECK
	SNE	$64(A5)			; Sprites Base 2

	MOVE.L	#(1*$40)+13,D0		; Nº Línea. (Sub-Item+Item)
	MOVEQ	#1,D1			; Nº menu.
	BSR	COGECHECK
	SNE	$6B(A5)			; 100% Refresh Screen

	MOVE.L	#(2*$40)+13,D0		; Nº Línea. (Sub-Item+Item)
	MOVEQ	#1,D1			; Nº menu.
	BSR	COGECHECK
	SNE	$6C(A5)			; Sprites Collisions ON

	MOVE.L	#(3*$40)+13,D0		; Nº Línea. (Sub-Item+Item)
	MOVEQ	#1,D1			; Nº menu.
	BSR	COGECHECK
	SNE	$6E(A5)			; VDP 'TR bit'
; -=-
	MOVEQ	#15,D0			; Nº Línea.
	MOVEQ	#1,D1			; Nº menu.
	BSR	COGECHECK
	SNE	$7D(A5)			; Disable Cheats

	MOVEQ	#16,D0			; Nº Línea.
	MOVEQ	#1,D1			; Nº menu.
	BSR	COGECHECK
	SNE	$1F(A5)			; Ask for Reset

	MOVEQ	#17,D0			; Nº Línea.
	MOVEQ	#1,D1			; Nº menu.
	BSR	COGECHECK
	SNE	$6F(A5)			; Overwrite
; -=-
;;	MOVE.L	#(3*$40)+0,D0		; Nº Línea. (Sub-Item+Item)
;;	MOVEQ	#3,D1			; Nº menu.
;;	BSR	COGECHECK
;;	SNE	$68(A5)			; ROM memory (Slot 1)
;;
;;	MOVE.L	#(3*$40)+2,D0		; Nº Línea. (Sub-Item+Item)
;;	MOVEQ	#3,D1			; Nº menu.
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
COGECHECK:
	MOVE.L	MSX2MENUS,A0
	MOVE.L	_intuitionbase,A6
	LSL.W	#5,D0	
	OR.W	D1,D0
	JSR	-$90(A6)		; ItemAdress (A0,d0)
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
	DC.B	1	; $11 - Modo de resolución. (Frecuencia)
	DC.B	0	; $12 - Multi-Key On.
	DC.B	0	; $13 - Port 0 On.
	DC.W	0	; $14 - Interrupciones.
	DC.W	2	; $16 - MSX2 Sprites.
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
	DC.B	$FF	; $61 - Write Protected.
	DC.B	0	; $62 - R.Shift as Space.
	DC.B	0	; $63 - L.Shift as Space.
	DC.B	0	; $64 - Sprites Base 2
	DC.B	0	; $65 - Disk ROM.
	DC.B	2	; $66 - Imploding Efficiency.
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

	DC.B	"Cartridges"	; $180
	DS.B	$100-10

	DC.B	"Tape"		; $280
	DS.B	$100-4

	CNOP	0,4
	DC.B	" -*(  AmiMSX2 Emulator By:  Juan Antonio Gómez Gálvez  )*- "
	CNOP	0,4
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
	TST.B	GoDat(PC)		; ¿MSX Encendido?
	BEQ	ErPowerON
	ENDC

	BSR	ACTUPREFS
	SF	D3
	BRA.S	R_GOCONT

MSX_Reset:
	IFD	MENU
	TST.B	GoDat(PC)		; ¿MSX Encendido?
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
	TST.B	LoROMBaDat(PC)		; ¿ROMs Base Leido Correctamente?
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

	IFD	MENU
	JSR	MSXEMUL			; A5=Dir Prefs.
	ENDC

	MOVE.L	D7,-(SP)
	BSR	RefrescaReloj
	BSR	ENAMOUSE
	MOVE.L	(SP)+,D7
;  -------------------------

;  -------------------------
	TST.B	ProtectDat(PC)		; Modo Avisar si está Write Protected.
	BEQ.S	NoEsProtect
	SF	ProtectDat
	BSR	UnProtect
	BRA	MSX_CONT
NoEsProtect:
;  -------------------------

;  -------------------------
	IFNE	Usuario=-99
	MOVE.L	D7,-(SP)
	BSR	ShowOutTime
	MOVE.L	(SP)+,D7
	ENDC
;  -------------------------

;  -------------------------		; Mira Si el MVD se ha modificado.
	TST.B	DirPrefs+$79		; ¿Activada la opción en menu?
	BEQ.S	NoMVDModificado
	TST.B	MVDModifi(PC)		; ¿Se ha modificado el MVD?
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
;	 -4(A1)= Nº de Gadgets-1
CONTROL:
	CLR.W	ControlKeys
	MOVE.L	-8(A1),-(SP)
	MOVE.L	A1,-(SP)
	MOVE.L	-12(A1),A0
	MOVE.L	(A0),-(SP)
	TST.B	AutoGo			; Test hook: press GO once.
	BEQ.S	BUCONTROL
	CMP.L	#MSX2PUNTS,4(SP)
	BNE.S	BUCONTROL
	SF	AutoGo
	JSR	MSX_GO
	IFD	TRACE
	TST.B	TraceFrozen
	BEQ.S	BUCONTROL
	BSR	TraceDump
	ENDC
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

	CMP.W	#$100,D0	; ¿Es Menú?
	BEQ	ESMENU

	CMP.W	#$010,D0	; ¿Es Slider?
	BEQ	ESGADGET

	CMP.W	#$040,D0	; ¿Es Gadget?
	BEQ.S	ESGADGET

	CMP.W	#$400,D0	; ¿Es Teclado?
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
PUNTEROSMENU:
	DC.L	MPROJECT
	DC.L	MOPTIONS
	DC.L	MMSXVD0
	DC.L	MCartridges
	DC.L	MTape
	DC.L	0

MPROJECT:
	DC.L	ABOUT			; About
	DC.L	ShowInfo		; Register
	DC.L	CONTROLRET		; -----
;;	DC.L	CONTROLRET		; Load Freezed
;;	DC.L	CONTROLRET		; Save Freezed
;;	DC.L	CONTROLRET		; -----
	DC.L	MENUSCREEN		; Set Screen
	DC.L	MenuPoke		; Poke mode
	DC.L	MenuDebug		; Debug mode
	DC.L	CONTROLRET		; -----
;;	DC.L	CONTROLRET		; Resident ROMs
;;	DC.L	CONTROLRET		; MSX2 Clock
;;	DC.L	CONTROLRET		; -----
	DC.L	SAVEVRAM		; Save VRAM.
	DC.L	SAVESprites		; Save Sprites.
	DC.L	CONTROLRET		; -----
	DC.L	SAVEPREFS		; Save Prefs.
	DC.L	CONTROLRET		; -----
	DC.L	CONTROLSALIR		; Quit

	DC.L	CONTROLRET
	DC.L	CONTROLRET
	DC.L	CONTROLRET
	DC.L	CONTROLRET
	DC.L	0

MOPTIONS:
	DC.L	CONTROLRET		; JoyStick 2 ON
	DC.L	CONTROLRET		; Swap JoyPorts
	DC.L	CONTROLRET		; -----
	DC.L	CONTROLRET		; Multi-Key
	DC.L	CONTROLRET		; DEL for Pause
	DC.L	CONTROLRET		; L.Shift as Space
	DC.L	CONTROLRET		; R.Shift as Space
	DC.L	CONTROLRET		; -----
	DC.L	CONTROLRET		; Use Japanese ID
	DC.L	CONTROLRET		; Use Kanji ROM
	DC.L	CONTROLRET		; -----
	DC.L	MenuMVD			; MSX Virtual Disk
	DC.L	MenuScrExit		; Screen mode on exit
	DC.L	MenuInternal		; Internal Emulation
	DC.L	CONTROLRET		; -----
	DC.L	CONTROLRET		; Disable Cheats
	DC.L	CONTROLRET		; Ask for Reset
	DC.L	ActuPrefs		; Overwrite
	DC.L	CONTROLRET		; -----

MenuScrExit:
	DC.L	NoChange		; No Change.
	DC.L	ForcePAL		; Force to PAL
	DC.L	ForceNTSC		; Force to NTSC
	DC.L	CONTROLRET		; ----

MenuMVD:
	DC.L	CONTROLRET		; Write Protected
	DC.L	CONTROLRET		; ----
	DC.L	CONTROLRET		; Autoexit on atten to save
	DC.L	CONTROLRET		; Warm on writes to exit
	DC.L	CONTROLRET		; ----

MenuInternal:
	DC.L	CONTROLRET		; Sprites Y coor. from Line Interrupt
	DC.L	CONTROLRET		; 100% refresh in screen changes
	DC.L	CONTROLRET		; Sprites collisions ON (always)
	DC.L	CONTROLRET		; VDP 'TR bit' always ready
	DC.L	CONTROLRET

MENUSCREEN:
	DC.L	SETPAL			; Set PAL
	DC.L	SETNTSC			; Set NTSC
	DC.L	CONTROLRET

MMSXVD0:
	DC.L	LOADVD0			; Load MSX Disk File
	DC.L	SAVEVD0			; Save MSX Disk File
	DC.L	CONTROLRET		; -----
	DC.L	LOADDISK		; Load MSX Disk
	DC.L	SAVEDISK		; Save MSX Disk
	DC.L	CONTROLRET		; -----
	DC.L	INSTALAR		; Instalar
	DC.L	SUBINSTALAR		; MSX Boot Type.
	DC.L	CONTROLRET		; -----
	DC.L	IMPLODER		; Imploder
	DC.L	CONTROLRET		; -----
	DC.L	FORMAT2DD		; Format as 2DD
	DC.L	FORMAT1DD		; Format as 1DD
	DC.L	CONTROLRET		; -----
	DC.L	CLEARVD0		; Clear bufer

SUBINSTALAR:
	DC.L	BootTypeCheck		; Check
	DC.L	BootType1DD		; 1DD Side
	DC.L	BootType2DD		; 2DD Side
	DC.L	CONTROLRET
	DC.L	0

MCartridges:
	DC.L	SMSlot1			; Slot 1
	DC.L	MenuMapper1		; Mapper
	DC.L	CONTROLRET		; -----
	DC.L	SMSlot2			; Slot 2
	DC.L	MenuMapper2		; Mapper
	DC.L	CONTROLRET		; -----
	DC.L	SMSlot3			; Slot 3
	DC.L	CONTROLRET
	DC.L	0

MenuMapper1:
	DC.L	Sl1MapOp0		; Standard
	DC.L	Sl1MapOp1		; Konami 1
	DC.L	Sl1MapOp2		; Konami 2
	DC.L	Sl1MapOp3		; ASCII 1
	DC.L	Sl1MapOp4		; ASCII 2
	DC.L	Sl1MapOp5		; SCC 1
	DC.L	Sl1MapOp6		; SCC 2
	DC.L	CONTROLRET		; -----

MenuMapper2:
	DC.L	Sl2MapOp0		; Standard
	DC.L	Sl2MapOp1		; Konami 1
	DC.L	Sl2MapOp2		; Konami 2
	DC.L	Sl2MapOp3		; ASCII 1
	DC.L	Sl2MapOp4		; ASCII 2
	DC.L	Sl2MapOp5		; SCC 1
	DC.L	Sl2MapOp6		; SCC 2
	DC.L	CONTROLRET		; -----

SMSlot1:
	DC.L	InsertSl1		; Insert Cartridge
	DC.L	EjectSl1		; Eject  Cartridge
	DC.L	CONTROLRET		; -----
	DC.L	SaveMappID1		; Save Mapper ID
	DC.L	CONTROLRET		; -----

SMSlot2:
	DC.L	InsertSl2		; Insert Cartridge
	DC.L	EjectSl2		; Eject  Cartridge
	DC.L	CONTROLRET		; -----
	DC.L	SaveMappID2		; Save Mapper ID
	DC.L	CONTROLRET		; -----

SMSlot3:
	DC.L	SaveCartridge		; Save Cartridge
	DC.L	CONTROLRET
	DC.L	SavePage1		; Save Page 1
	DC.L	SavePage2		; Save Page 2
	DC.L	SavePage12		; Save Page 1 & 2
	DC.L	CONTROLRET

MTape:
	DC.L	InitLoadTape		; Init Tape File
	DC.L	LoadTape		; Load Tape File
	DC.L	CONTROLRET		; -----
	DC.L	InitSaveTape		; Init Tape buffer
	DC.L	SaveTape		; Save Tape buffer
	DC.L	CONTROLRET


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
; Arreglos y opción de A0=A1 por Juan Antonio Gómez (007!)
;-----------------------------------------------------------------------------
;call with registers:
;                       ***   A0 = crunched data        ***
;			***   A1 = destination address  ***
;
;  Para usar un solo bufer:  como mínimo  a1=a0+$10  (16 Bytes)  o  a1=a0
;-----------------------------------------------------------------------------
;Uses d0-d7/a0-a6		$08(a0).l = Size fichero descomp.
;				Fichero comprimido Máximo de 1024Kb.

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
	DC.L	GD_Slot1,InsertSl1
	DC.L	GD_Slot2,InsertSl2
	DC.L	0,0


	CNOP	0,4
	DC.L	0
	DC.L	INFOWND
	DC.L	INFOGADGETS
	DC.L	INFO_CNT-1
INFOPUNTS:
	DC.L	GD_TRigth,CONTROLSALIR
	DC.L	0,0


	CNOP	0,4
	DC.L	0
	DC.L	ShareInfoWND
	DC.L	ShareInfoGADGETS
	DC.L	ShareInfo_CNT-1
ShareInfoPUNTS:
	DC.L	GD_ShareRegister,ShowRegisterShare
	DC.L	GD_ShareThats,CONTROLSALIR
	DC.L	0,0


	CNOP	0,4
	DC.L	0
	DC.L	RegisterWND
	DC.L	RegisterGADGETS
	DC.L	Register_CNT-1
RegisterPUNTS:
	DC.L	GD_ContRegister,CONTROLSALIR
	DC.L	0,0


	CNOP	0,4
	DC.L	0
	DC.L	OutTimeWND
	DC.L	OutTimeGADGETS
	DC.L	OutTime_CNT-1
OutTimePUNTS:
	DC.L	GD_OutTimeRegister,ShowRegisterOut
	DC.L	GD_OutTimeWell,CONTROLSALIR
	DC.L	0,0


	CNOP	0,4
	DC.L	0
	DC.L	IMPLODERWND
	DC.L	IMPLODERGADGETS
	DC.L	IMPLODER_CNT-1
IMPLODERPUNTS:
	DC.L	GD_IMPLODE,IMPLODING
	DC.L	GD_SAVEIMP,SAVEIMPLODED
	DC.L	GD_CANCELIMP,CONTROLSALIR
	DC.L	GD_ABORTIMP,CONTROLRET
	DC.L	GD_EFFIMP,CONTROLRET
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
	DC.L	PasswordWND
	DC.L	PasswordGADGETS
	DC.L	Password_CNT-1
PasswordPunts:
	DC.L	GD_Password,ControlSalir
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
	DC.L	GD_ABOUTMORE,ADDRESS
	DC.L	GD_ABOUTEXIT,CONTROLSALIR
	DC.L	0,0


	CNOP	0,4
	DC.L	0
	DC.L	ADDRESSWND
	DC.L	ADDRESSGADGETS
	DC.L	ADDRESS_CNT-1
ADDRESSPUNTS:
	DC.L	GD_ADDRESSEXIT,CONTROLSALIR
	DC.L	0,0


	CNOP	0,4
	DC.L	0
	DC.L	MC68020WND
	DC.L	MC68020GADGETS
	DC.L	MC68020_CNT-1
MC68020PUNTS:
	DC.L	GD_MContinue,CONTROLSALIR
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


;	IMPLODER 1.0 (CRUNCH)
;	---------------------
;	RESULTADO:
;	D0=-1  ABORTADO
;	D0=00  IMPOSIBLE DE COMPACTAR.

;	ENTRADA:
;	A0=DIR. DEL SOURCE
;	D0=SIZE DEL SOURCE
;	D1=MODE (de $00 a $0B)
;	A1=RUTINA A EJECUTAR A VECES. 

	CNOP	0,4
lbL000D38:
	dc.l	$20002
	dc.l	$20002
	dc.l	$6000A
	dc.l	$A0012
	dc.l	$16002A
	dc.l	$8A4012
lbL000D50:
	dc.l	$1010101
	dc.l	$2030304
	dc.l	$405070E
lbL000D5C:
	dc.l	$2060E
	dc.l	$1020304
lbL000D64:
	dc.l	$80
	dc.l	$100
	dc.l	$200
	dc.l	$400
	dc.l	$700
	dc.l	$D00
	dc.l	$1500
	dc.l	$2500
	dc.l	$5100
	dc.l	$9200
	dc.l	$10900
	dc.l	$21200
lbL000D94:
	dc.l	$5050505
	dc.l	$5050505
	dc.l	$6060606
	dc.l	$5060707
	dc.l	$6060606
	dc.l	$7070606
	dc.l	$5060707
	dc.l	$7070707
	dc.l	$8080808
	dc.l	$5060708
	dc.l	$7070808
	dc.l	$8080909
	dc.l	$6070708
	dc.l	$7080909
	dc.l	$8090A0A
	dc.l	$6070708
	dc.l	$709090A
	dc.l	$80A0B0B
	dc.l	$6070808
	dc.l	$709090A
	dc.l	$80A0B0C
	dc.l	$6070808
	dc.l	$709090A
	dc.l	$90A0C0D
	dc.l	$6070708
	dc.l	$709090C
	dc.l	$90A0C0E
	dc.l	$6070809
	dc.l	$7090A0C
	dc.l	$90B0D0F
	dc.l	$6070808
	dc.l	$70A0B0B
	dc.l	$90C0D10
	dc.l	$6080809
	dc.l	$70B0C0C
	dc.l	$90D0E11

lbC000E24:
	MOVE.L	8(A6),D0
	BEQ.S	lbC000E56
	MOVE.L	D0,A0
	MOVE.L	$10(A6),D0
	SUB.L	$2C(A6),D0
	MOVE.L	$2C(A6),D1
	SUB.L	$30(A6),D1
	MOVEQ	#0,D2
	MOVE.B	1(A6),D2
	EXT.W	D2
	SWAP	D2
	MOVE.B	2(A6),D2
	MOVE.L	4(A6),A5
	MOVE.L	A6,-(SP)
	JSR	(A0)
	MOVE.L	(SP)+,A6
	NOT.L	D0
lbC000E56:
	TST.L	D0
	RTS

lbC000E5A:
	MOVEM.L	D2/A2-A4,-(SP)
	MOVEQ	#4,D0
	SWAP	D0
	MOVEQ	#1,D1
	SWAP	D1
	MOVE.L	A6,-(SP)
	MOVE.L	4,A6
	JSR	-$C6(A6)
	MOVE.L	(SP)+,A6
	MOVE.L	D0,$20(A6)
	BEQ	lbC000F14
	SUB.L	A2,A2
	MOVE.L	$1C(A6),D2
	ADD.L	D2,D2
	ADD.L	D2,D2
	MOVE.L	D2,D0
	ADD.L	D2,D2
	ADD.L	D0,D2
lbC000E8A:
	MOVE.L	#$960,D0
	SUB.L	D0,D2
	BPL.S	lbC000E98
	ADD.L	D2,D0
	MOVEQ	#0,D2
lbC000E98:
	ADDQ.L	#8,D0
	MOVEQ	#0,D1
	MOVE.L	D0,-(SP)
	MOVE.L	A6,-(SP)
	MOVE.L	4,A6
	JSR	-$C6(A6)
	MOVE.L	(SP)+,A6
	MOVE.L	(SP)+,D1
	TST.L	D0
	BEQ.S	lbC000F14
	MOVE.L	D0,$24(A6)
	MOVE.L	D0,A0
	MOVE.L	D1,(A0)
	MOVE.L	A2,4(A0)
	MOVE.L	A0,A2
	TST.L	D2
	BNE.S	lbC000E8A
	MOVE.L	$20(A6),A0
	MOVE.L	12(A6),A1
	ADD.L	$1C(A6),A1
	MOVE.L	$24(A6),A2
lbC000ED2:
	MOVE.L	A2,A3
	ADD.L	(A3),A3
	ADDQ.W	#8,A2
lbC000ED8:
	MOVEQ	#0,D0
	MOVE.B	-1(A1),D0
	LSL.W	#8,D0
	MOVE.B	(A1),D0
	LSL.L	#2,D0
	MOVE.L	0(A0,D0.L),A4
	MOVE.L	A4,-(A3)
	BEQ.S	lbC000EF2
	MOVE.L	A1,-(A3)
	MOVE.L	-(A4),-(A3)
	BRA.S	lbC000EF6

lbC000EF2:
	MOVE.L	A1,-(A3)
	MOVE.L	A3,-(A3)
lbC000EF6:
	MOVE.L	A3,0(A0,D0.L)
	ADDQ.L	#4,0(A0,D0.L)
	SUBQ.W	#1,A1
	CMP.L	A2,A3
	BHI.S	lbC000ED8
	MOVE.L	-(A2),A2
	MOVE.L	A2,D0
	BNE.S	lbC000ED2
	MOVEQ	#-$1,D0
lbC000F0C:
	MOVEM.L	(SP)+,D2/A2-A4
	TST.L	D0
	RTS

lbC000F14:
	MOVEQ	#0,D0
	BRA.S	lbC000F0C

lbC000F18:
	MOVEM.L	A2,-(SP)
	MOVE.L	$20(A6),D0
	BEQ.S	lbC000F36
	MOVE.L	D0,A1
	MOVE.L	#$40000,D0
	MOVE.L	A6,-(SP)
	MOVE.L	4,A6
	JSR	-$D2(A6)
	MOVE.L	(SP)+,A6
lbC000F36:
	MOVE.L	$24(A6),A2
lbC000F3A:
	MOVE.L	A2,D0
	BEQ.S	lbC000F54
	MOVE.L	(A2),D0
	MOVE.L	4(A2),A1
	EXG	A2,A1
	MOVE.L	A6,-(SP)
	MOVE.L	4,A6
	JSR	-$D2(A6)
	MOVE.L	(SP)+,A6
	BRA.S	lbC000F3A

lbC000F54:
	CLR.L	$24(A6)
	CLR.L	$20(A6)
	MOVEM.L	(SP)+,A2
	RTS

lbC000F62:
	MOVE.L	$10(A6),D5
	MOVE.L	$2C(A6),A5
	MOVEQ	#1,D7
	MOVE.L	$20(A6),A3
	MOVEQ	#0,D0
	MOVE.B	(A5)+,D0
	LSL.W	#8,D0
	MOVE.B	(A5)+,D0
	LSL.L	#2,D0
	ADD.L	D0,A3
	MOVE.L	(A3),A0
	MOVE.L	A0,$28(A6)
	MOVE.L	4(A0),A1
	MOVE.L	A1,(A3)
	BEQ.S	lbC000FF8
	MOVE.L	A1,A4
	MOVE.L	-(A0),-(A1)
	LEA	$46(A6),A3
	CLR.L	-(A3)
	CLR.L	-(A3)
	BRA.S	lbC000F9E

lbC000F98:
	MOVE.L	(A4),D0
	BEQ.S	lbC000FF8
	MOVE.L	D0,A4
lbC000F9E:
	MOVE.L	(A4)+,A2
	MOVE.L	A5,A0
	LEA	1(A2),A1
	CMPM.B	(A0)+,(A1)+
	BNE.S	lbC000FBE
	CMPM.B	(A0)+,(A1)+
	BNE.S	lbC000FB8
	MOVE.W	#$FB,D0
lbC000FB2:
	CMPM.B	(A0)+,(A1)+
	DBNE	D0,lbC000FB2

lbC000FB8:
	CMP.L	D5,A1
	BLS.S	lbC000FBE
	MOVE.L	D5,A1
lbC000FBE:
	MOVE.L	A1,D6
	SUB.L	A2,D6
	CMP.W	D6,D7
	BCC.S	lbC000F98
	MOVE.W	D6,D7
	CMP.W	#8,D6
	BHI.S	lbC000FE6
	TST.B	-2(A3,D6.W)
	BNE.S	lbC000F98
	MOVE.B	D6,-2(A3,D6.W)
	MOVE.L	A2,D0
	SUB.L	A5,D0
	MOVE.W	D6,D1
	LSL.W	#2,D1
	MOVE.L	D0,0(A3,D1.W)
	BRA.S	lbC000F98

lbC000FE6:
	MOVE.B	D6,7(A3)
	MOVE.L	A2,D0
	SUB.L	A5,D0
	MOVE.L	D0,$24(A3)
	CMP.B	#$FF,D6
	BNE.S	lbC000F98
lbC000FF8:
	ADD.L	$1C(A6),A5
	CMP.L	D5,A5
	BCC.S	lbC001032
	SUBQ.L	#2,A5
	MOVE.L	$20(A6),A0
	MOVE.L	$28(A6),A1
	MOVEQ	#0,D0
	MOVE.B	(A5)+,D0
	LSL.W	#8,D0
	MOVE.B	(A5),D0
	LSL.L	#2,D0
	MOVE.L	A5,(A1)
	CLR.L	4(A1)
	ADD.L	D0,A0
	MOVE.L	(A0),D1
	BEQ.S	lbC00102E
	EXG	D1,A1
	MOVE.L	-(A1),A0
	MOVE.L	D1,4(A0)
	MOVE.L	D1,(A1)
	SUBQ.B	#1,D7
	RTS

lbC00102E:
	MOVE.L	A1,(A0)
	MOVE.L	A1,-(A1)
lbC001032:
	SUBQ.B	#1,D7
	RTS

lbC001036:
	MOVE.L	$2C(A6),A5
	MOVE.L	$10(A6),D5
	MOVE.L	A5,D0
	ADD.L	$1C(A6),D0
	CMP.L	D5,D0
	BLS.S	lbC00104A
	MOVE.L	D5,D0
lbC00104A:
	MOVE.L	D0,D4
	MOVE.L	A5,A2
	ADDQ.L	#1,A2
	MOVE.L	A2,A4
	MOVEQ	#1,D7
	MOVE.B	(A5),D3
	LEA	$46(A6),A3
	CLR.L	-(A3)
	CLR.L	-(A3)
lbC00105E:
	CMP.B	(A2)+,D3
	BEQ.S	lbC0010A4
	CMP.B	(A2)+,D3
	BEQ.S	lbC0010A4
	CMP.B	(A2)+,D3
	BEQ.S	lbC0010A4
	CMP.B	(A2)+,D3
	BEQ.S	lbC0010A4
	CMP.B	(A2)+,D3
	BEQ.S	lbC0010A4
	CMP.B	(A2)+,D3
	BEQ.S	lbC0010A4
	CMP.B	(A2)+,D3
	BEQ.S	lbC0010A4
	CMP.B	(A2)+,D3
	BEQ.S	lbC0010A4
	CMP.B	(A2)+,D3
	BEQ.S	lbC0010A4
	CMP.B	(A2)+,D3
	BEQ.S	lbC0010A4
	CMP.B	(A2)+,D3
	BEQ.S	lbC0010A4
	CMP.B	(A2)+,D3
	BEQ.S	lbC0010A4
	CMP.B	(A2)+,D3
	BEQ.S	lbC0010A4
	CMP.B	(A2)+,D3
	BEQ.S	lbC0010A4
	CMP.B	(A2)+,D3
	BEQ.S	lbC0010A4
	CMP.B	(A2)+,D3
	BEQ.S	lbC0010A4
	CMP.L	A2,D4
	BHI.S	lbC00105E
lbC0010A2:
	RTS

lbC0010A4:
	CMP.L	A2,D4
	BLS.S	lbC0010A2
	MOVE.L	A4,A0
	MOVE.L	A2,A1
	CMPM.B	(A0)+,(A1)+
	BNE.S	lbC00105E
	CMPM.B	(A0)+,(A1)+
	BNE.S	lbC0010C8
	CMPM.B	(A0)+,(A1)+
	BNE.S	lbC0010C2
	MOVE.W	#$FB,D0
lbC0010BC:
	CMPM.B	(A0)+,(A1)+
	DBNE	D0,lbC0010BC

lbC0010C2:
	CMP.L	D5,A1
	BLS.S	lbC0010C8
	MOVE.L	D5,A1
lbC0010C8:
	MOVE.L	A1,D6
	SUB.L	A2,D6
	CMP.W	D6,D7
	BCC.S	lbC00105E
	MOVE.W	D6,D7
	CMP.W	#8,D6
	BHI.S	lbC0010F4
	TST.B	-2(A3,D6.W)
	BNE.S	lbC00105E
	MOVE.B	D6,-2(A3,D6.W)
	MOVE.L	A2,D0
	SUB.L	A5,D0
	SUBQ.L	#2,D0
	MOVE.W	D6,D1
	LSL.W	#2,D1
	MOVE.L	D0,0(A3,D1.W)
	BRA	lbC00105E

lbC0010F4:
	MOVE.B	D6,7(A3)
	MOVE.L	A2,D0
	SUB.L	A5,D0
	SUBQ.L	#2,D0
	MOVE.L	D0,$24(A3)
	CMP.B	#$FF,D6
	BNE	lbC00105E
	RTS

lbC00110C:
	MOVE.B	$36(A6),D2
	MOVE.B	$37(A6),D3
	MOVE.L	$30(A6),A0
lbC001118:
	LSR.L	#1,D1
	ROXR.B	#1,D2
	SUBQ.B	#1,D3
	BPL.S	lbC001126
	MOVEQ	#7,D3
	MOVE.B	D2,(A0)+
	MOVEQ	#0,D2
lbC001126:
	SUBQ.B	#1,D0
	BNE.S	lbC001118
	MOVE.L	A0,$30(A6)
	MOVE.B	D3,$37(A6)
	MOVE.B	D2,$36(A6)
	RTS

lbC001138:
	AND.W	#$FF,D0
	CMP.B	#13,D0
	BHI.S	lbC00116E
	CMP.B	#5,D0
	BHI.S	lbC00115C
	LEA	lbL000D5C(PC),A0
	ADD.W	D0,A0
	MOVE.B	-2(A0),$7B(A6)
	MOVE.B	2(A0),$73(A6)
	BRA.S	lbC001180

lbC00115C:
	SUBQ.B	#6,D0
	OR.B	#$F0,D0
	MOVE.B	D0,$7B(A6)
	MOVE.B	#8,$73(A6)
	BRA.S	lbC00117E

lbC00116E:
	MOVE.B	#$1F,$7A(A6)
	MOVE.B	D0,$7B(A6)
	MOVE.B	#13,$73(A6)
lbC00117E:
	MOVEQ	#5,D0
lbC001180:
	SUBQ.B	#2,D0
	MOVE.L	$3A(A6),D2
	LEA	lbL000D50(PC),A1
	LEA	lbL000D38(PC),A0
	ADD.W	D0,A0
	ADD.W	D0,A0
	CMP.W	(A0),D2
	BCC.S	lbC0011A8
	MOVE.B	0(A1,D0.W),D6
	MOVE.B	D6,D3
	ADDQ.B	#1,D3
	MOVE.B	#0,$7D(A6)
	MOVEQ	#0,D4
	BRA.S	lbC0011DC

lbC0011A8:
	CMP.W	8(A0),D2
	BCC.S	lbC0011C0
	MOVE.B	4(A1,D0.W),D6
	MOVE.B	D6,D3
	ADDQ.B	#2,D3
	MOVE.B	#2,$7D(A6)
	MOVE.W	(A0),D4
	BRA.S	lbC0011DC

lbC0011C0:
	CMP.W	$10(A0),D2
	BCS.S	lbC0011CA
	MOVEQ	#0,D0
	RTS

lbC0011CA:
	MOVE.B	8(A1,D0.W),D6
	MOVE.B	D6,D3
	ADDQ.B	#2,D3
	MOVE.B	#3,$7D(A6)
	MOVE.W	8(A0),D4
lbC0011DC:
	MOVE.B	D3,$74(A6)
	SUB.W	D4,D2
	MOVEQ	#$10,D5
	SUB.B	D6,D5
	LSL.W	D5,D2
lbC0011E8:
	ADD.W	D2,D2
	ROXL	$7C(A6)
	SUBQ.B	#1,D6
	BNE.S	lbC0011E8
	LEA	$AE(A6),A1
	LEA	$7E(A6),A0
	ADD.W	D0,A0
	ADD.W	D0,A0
	ADD.W	D0,A0
	ADD.W	D0,A0
	CMP.L	(A0),D1
	BCC.S	lbC001214
	MOVE.B	0(A1,D0.W),D6
	MOVE.B	D6,D3
	ADDQ.B	#1,D3
	MOVEQ	#0,D7
	MOVEQ	#0,D4
	BRA.S	lbC001240

lbC001214:
	CMP.L	$10(A0),D1
	BCC.S	lbC001228
	MOVE.B	4(A1,D0.W),D6
	MOVE.B	D6,D3
	ADDQ.B	#2,D3
	MOVEQ	#2,D7
	MOVE.L	(A0),D4
	BRA.S	lbC001240

lbC001228:
	CMP.L	$20(A0),D1
	BCS.S	lbC001232
	MOVEQ	#0,D0
	RTS

lbC001232:
	MOVE.B	8(A1,D0.W),D6
	MOVE.B	D6,D3
	ADDQ.B	#2,D3
	MOVEQ	#3,D7
	MOVE.L	$10(A0),D4
lbC001240:
	MOVE.B	D3,$72(A6)
	SUB.L	D4,D1
	MOVEQ	#$20,D5
	SUB.B	D6,D5
	LSL.L	D5,D1
lbC00124C:
	ADD.L	D1,D1
	ADDX.L	D7,D7
	SUBQ.B	#1,D6
	BNE.S	lbC00124C
	MOVE.L	D7,$76(A6)
	MOVEQ	#-$1,D0
	RTS

lbC00125C:
	CLR.W	$34(A6)
	CLR.W	$38(A6)
	LEA	$3E(A6),A2
	LEA	$46(A6),A3
lbC00126C:
	MOVE.L	(A3)+,D1
	MOVE.B	(A2)+,D0
	BEQ.S	lbC0012B2
	BSR	lbC001138
	BEQ.S	lbC0012B2
	MOVEQ	#0,D0
	MOVEQ	#0,D1
	MOVE.B	-1(A2),D0
	LSL.W	#3,D0
	ADD.B	$73(A6),D1
	ADD.B	$72(A6),D1
	ADD.B	$74(A6),D1
	SUB.W	D1,D0
	BMI.S	lbC0012B2
	CMP.W	$34(A6),D0
	BCS.S	lbC0012B2
	MOVE.W	D0,$34(A6)
	MOVE.B	-1(A2),$39(A6)
	LEA	$66(A6),A0
	LEA	$72(A6),A1
	MOVEQ	#11,D1
lbC0012AC:
	MOVE.B	(A1)+,(A0)+
	DBRA	D1,lbC0012AC

lbC0012B2:
	MOVE.L	A2,D0
	SUB.L	A6,D0
	CMP.W	#$46,D0
	BNE.S	lbC00126C
	TST.W	$38(A6)
	RTS

	SWAP	D1
	BSET	#7,D1
	BRA.S	lbC0012D0

IMPLODE:
	OR.L	#$80000000,D1
	SWAP	D1
	BCLR	#7,D1
lbC0012D0:
	MOVEM.L	D2-D7/A2-A6,-(SP)
	MOVE.W	#$5C,D2
lbC0012D8:
	CLR.W	-(SP)
	DBRA	D2,lbC0012D8

	MOVE.L	SP,A6
	MOVE.L	A5,4(A6)
	CMP.L	#$40,D0
	BCS	lbC0015E2
	LSR.L	#8,D1
	SCS	(A6)
	LSR.L	#8,D1
	SCS	1(A6)
	CMP.B	#12,D1
	BCS.S	lbC001300
	MOVEQ	#0,D1
lbC001300:
	MOVE.L	A1,8(A6)
	MOVE.L	A0,12(A6)
	MOVE.L	A0,$2C(A6)
	MOVE.L	A0,$30(A6)
	MOVE.L	D0,$14(A6)
	ADD.L	D0,A0
	MOVE.L	A0,$10(A6)
	LEA	lbL000D64(PC),A0
	LSL.W	#2,D1
	MOVE.L	0(A0,D1.W),D1
	ADDQ.L	#1,D1
	CMP.L	D0,D1
	BLS.S	lbC00132E
	MOVE.L	D0,D1
	SUBQ.L	#1,D1
lbC00132E:
	MOVE.L	D1,$1C(A6)
	SUBQ.L	#1,D1
	MOVEQ	#0,D0
lbC001336:
	CMP.L	(A0)+,D1
	BLS.S	lbC00133E
	ADDQ.B	#1,D0
	BRA.S	lbC001336

lbC00133E:
	MOVE.B	D0,2(A6)
	LEA	$AE(A6),A1
	MOVEQ	#12,D1
	MULU	D1,D0
	LEA	lbL000D94(PC),A0
	ADD.L	D0,A0
	SUBQ.W	#1,D1
lbC001352:
	MOVE.B	(A0)+,(A1)+
	DBRA	D1,lbC001352

	LEA	$7E(A6),A1
	LEA	$AE(A6),A0
	MOVEQ	#11,D1
lbC001362:
	MOVE.B	(A0)+,D0
	MOVEQ	#0,D2
	BSET	D0,D2
	MOVE.L	D2,(A1)+
	DBRA	D1,lbC001362

	LEA	$7E(A6),A0
	LEA	$8E(A6),A1
	MOVEQ	#7,D1
lbC001378:
	MOVE.L	(A0)+,D0
	ADD.L	D0,(A1)+
	DBRA	D1,lbC001378

	TST.B	(A6)
	BEQ.S	lbC00139E
	LEA	$7E(A6),A1
	MOVEQ	#7,D0
lbC00138A:
	MOVE.L	(A1)+,D1
	MOVE.W	D1,(A2)+
	DBRA	D0,lbC00138A

	LEA	$AE(A6),A1
	MOVEQ	#11,D0
lbC001398:
	MOVE.B	(A1)+,(A2)+
	DBRA	D0,lbC001398

lbC00139E:
	MOVE.B	#7,$37(A6)
	TST.B	1(A6)
	BEQ.S	lbC0013B8
	BSR	lbC000E5A
	BNE.S	lbC0013B8
	SF	1(A6)
	BSR	lbC000F18
lbC0013B8:
	MOVE.L	$10(A6),D0
	SUBQ.L	#2,D0
	CMP.L	$2C(A6),D0
	BLS	lbC0014C6
	BSR	lbC000E24
	BNE	lbC0015DE
	TST.B	1(A6)
	BNE.S	lbC0013DA
	BSR	lbC001036
	BRA.S	lbC0013E0

lbC0013DA:
	BSR	lbC000F62
	BEQ.S	lbC0013E6
lbC0013E0:
	BSR	lbC00125C
	BNE.S	lbC00140A
lbC0013E6:
	MOVE.L	$2C(A6),A0
	MOVE.L	$30(A6),A1
	MOVE.B	(A0),(A1)
	ADDQ.L	#1,$2C(A6)
	ADDQ.L	#1,$30(A6)
	ADDQ.L	#1,$3A(A6)
	CMP.L	#$4012,$3A(A6)
	BCS.S	lbC0013B8
	BRA	lbC0014C6

lbC00140A:
	CLR.L	$3A(A6)
	TST.B	1(A6)
	BEQ.S	lbC001480
	MOVE.L	$2C(A6),A2
	ADDQ.L	#1,A2
	MOVE.L	A2,A3
	ADD.L	$1C(A6),A3
	MOVE.W	$38(A6),D3
	SUBQ.W	#1,D3
	MOVE.L	$10(A6),D2
	SUB.L	A3,D2
	SUBQ.L	#1,D2
	BPL.S	lbC001432
	MOVEQ	#0,D2
lbC001432:
	MOVE.L	$20(A6),A4
	MOVEQ	#0,D0
	MOVE.B	(A2)+,D0
	LSL.W	#8,D0
	MOVE.B	(A2),D0
	LSL.L	#2,D0
	ADD.L	D0,A4
	MOVE.L	(A4),A5
	MOVE.L	4(A5),A0
	MOVE.L	A0,(A4)
	BEQ.S	lbC001450
	MOVE.L	-4(A5),-(A0)
lbC001450:
	SUBQ.L	#1,D2
	BMI.S	lbC00147C
	SUB.L	D0,A4
	MOVEQ	#0,D0
	MOVE.B	(A3)+,D0
	LSL.W	#8,D0
	MOVE.B	(A3),D0
	LSL.L	#2,D0
	ADD.L	D0,A4
	MOVE.L	A3,(A5)
	CLR.L	4(A5)
	MOVE.L	(A4),D1
	BEQ.S	lbC001478
	EXG	D1,A5
	MOVE.L	-(A5),A0
	MOVE.L	D1,4(A0)
	MOVE.L	D1,(A5)
	BRA.S	lbC00147C

lbC001478:
	MOVE.L	A5,(A4)
	MOVE.L	A5,-(A5)
lbC00147C:
	SUBQ.W	#1,D3
	BNE.S	lbC001432
lbC001480:
	MOVE.W	$38(A6),D0
	EXT.L	D0
	ADD.L	D0,$2C(A6)
	MOVE.B	$66(A6),D0
	MOVE.L	$6A(A6),D1
	BSR	lbC00110C
	MOVE.B	$68(A6),D0
	MOVE.W	$70(A6),D1
	BSR	lbC00110C
	MOVE.B	$67(A6),D0
	MOVE.W	$6E(A6),D1
	CMP.B	#13,D0
	BNE.S	lbC0014BE
	MOVE.L	$30(A6),A0
	MOVE.B	D1,(A0)
	ADDQ.L	#1,$30(A6)
	MOVEQ	#5,D0
	MOVEQ	#$1F,D1
lbC0014BE:
	BSR	lbC00110C
	BRA	lbC0013B8

lbC0014C6:
	BSR	lbC000E24
	BNE	lbC0015DE
	MOVE.L	$2C(A6),A0
	MOVE.L	$30(A6),A1
	MOVE.B	(A0),(A1)
	ADDQ.L	#1,$2C(A6)
	ADDQ.L	#1,$30(A6)
	ADDQ.L	#1,$3A(A6)
	MOVE.L	$2C(A6),D0
	CMP.L	$10(A6),D0
	BNE.S	lbC0014C6
	BSR	lbC000E24
	BNE	lbC0015DE
	TST.B	(A6)
	BNE	lbC00159A
	MOVE.L	$30(A6),D0
	SUB.L	12(A6),D0
	CMP.L	#12,D0
	BCS	lbC0015E2
	MOVE.L	$14(A6),D1
	SUB.L	D0,D1
	CMP.L	#$36,D1
	BLS	lbC0015E2
	MOVE.L	12(A6),A1
	MOVE.L	$30(A6),A0
	MOVE.L	#$FF00,D7
	BTST	#0,D0
	BEQ.S	lbC001538
	MOVEQ	#0,D7
	ADDQ.L	#1,D0
	CLR.B	(A0)+
lbC001538:
	MOVE.L	(A1),8(A0)
	MOVE.L	#$494D5021,(A1)
	MOVE.L	4(A1),4(A0)
	MOVE.L	$14(A6),4(A1)
	MOVE.L	8(A1),(A0)
	MOVE.L	D0,8(A1)
	ADD.L	#$2E,D0
	MOVE.L	D0,$18(A6)
	MOVE.L	$3A(A6),12(A0)
	MOVE.B	$36(A6),D1
	AND.W	#$FE,D1
	MOVE.B	$37(A6),D0
	BSET	D0,D1
	OR.W	D7,D1
	MOVE.W	D1,$10(A0)
	LEA	$7E(A6),A1
	ADD.W	#$12,A0
	MOVEQ	#7,D0
lbC001584:
	MOVE.L	(A1)+,D1
	MOVE.W	D1,(A0)+
	DBRA	D0,lbC001584

	LEA	$AE(A6),A1
	MOVEQ	#11,D0
lbC001592:
	MOVE.B	(A1)+,(A0)+
	DBRA	D0,lbC001592

	BRA.S	lbC0015E2

lbC00159A:
	MOVE.L	$30(A6),D0
	SUB.L	12(A6),D0
	MOVE.L	$14(A6),D1
	SUB.L	D0,D1
	CMP.L	#6,D1
	BLS.S	lbC0015E2
	MOVE.B	$36(A6),D1
	AND.B	#$FE,D1
	MOVE.B	$37(A6),D2
	BSET	D2,D1
	MOVE.L	$30(A6),A0
	BTST	#0,D0
	BEQ.S	lbC0015D0
	MOVE.B	D1,(A0)+
	MOVE.L	$3A(A6),(A0)
	BRA.S	lbC0015D6

lbC0015D0:
	MOVE.L	$3A(A6),(A0)+
	MOVE.B	D1,(A0)
lbC0015D6:
	ADDQ.L	#5,D0
	MOVE.L	D0,$18(A6)
	BRA.S	lbC0015E2

lbC0015DE:
	MOVEQ	#-$1,D0
	BRA.S	lbC0015E6

lbC0015E2:
	MOVE.L	$18(A6),D0
lbC0015E6:
	MOVEM.L	D0,-(SP)
	BSR	lbC000F18
	MOVEM.L	(SP)+,D0
	MOVE.W	#$5C,D2
lbC0015F6:
	CLR.W	(SP)+
	DBRA	D2,lbC0015F6

	MOVEM.L	(SP)+,D2-D7/A2-A6
	TST.L	D0
	RTS

	CNOP	0,4
IMPCONTROL:
	MOVE.L	D2,-(SP)

	MOVE.L	BUCPROG,D2
	DIVU	#100,D2
	DIVU	D2,D0

	CMP.B	ULTINPOR(PC),D0
	BNE.S	IMPCONTROLC
	MOVE.L	(SP)+,D2
	MOVEQ	#-1,D0
	RTS

	CNOP	0,4
ULTINPOR:DC.L	-1

	CNOP	0,4
IMPCONTROLC:
	MOVE.B	D0,ULTINPOR
	MOVEM.L	D1/D3-D7/A0-A6,-(SP)

	MOVEQ	#100,D2
	SUB.W	D0,D2

	MOVE.L	BUCPROG,D0
	SUB.L	D1,D0

	BSR	PASDEC
	MOVE.W	4(A0),TIMPTXT1+$19
	MOVE.L	6(A0),TIMPTXT1+$1B

	MOVE.L	D2,D0
	BSR	PASDEC
	MOVE.L	6(A0),TIMPTXT1+$0D


	move.l  IMPLODERWnd,a0
	move.b  54(a0),d0
	ext.w   d0
	move.b  55(a0),d1
	ext.w   d1
	move.l  50(a0),a0
	lea     IMPLODERTextO(PC),a1
	move.l  _IntuitionBase,a6
	JSR     PrintIText(a6)

	MOVEM.L	(SP)+,D1/D3-D7/A0-A6
	MOVE.L	(SP)+,D2
	MOVEQ	#-1,D0
	RTS

	CNOP	0,4
IMPLODERTextO:
    DC.B    7,0
    DC.B    $01
    DC.B    0
    DC.W    23,8
    DC.L    topaz8
IMPLODERDIRTXT:
    DC.L    TIMPTXT1
    DC.L    0

*********************************************

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
MSXEMUL:
