; AmiMSX_Lupa_v4.asm - a game named at start: the Shell, a script, a game
; launcher such as Lupa, or a Workbench project icon (the launch contract
; shared with the other Amiga emulators). Left out with
; -DNO_LUPA=1 (then the 4.x test hook parser in ANEM is used as before).
;
;   AmiMSX [game] [keyscript] [driveB] [AGA|RTG] [ONEGAME] [MENU]
;          [PROFILE=030|FAST|AUTO] [PREFS=<file>|P=<file>] [RTGMODE=<mode>]
;          [B=<disk>] [R2=<cartridge>] [S2=<cartridge>]
;
; Words: any case. KEY=value and KEY value both work for the value words;
; a word may be "quoted" (spaces), or carry quotes after the = (B="a b.dsk").
; A quoted AGA, RTG, ONEGAME or MENU is a file name, not the switch.
; Positional words (not keywords), in order: the game (FILENOM), a key script
; (KEYNOM, the regression harness's test input), drive B's image (DISKBNOM).
; The game: *.dsk goes to drive A, *.cas to the cassette (Load Tape File's
; format), anything else into cartridge Slot 1; it is loaded as the menu
; would load it and powered on at once (MENU: loaded, the menu stays).
; ONEGAME: leaving the game (Help) quits the program; a game that can't be
; loaded shows the menu's error, then quits with return code 10.
; AGA / RTG: the display for this run, over the RTG ToolType.
; PROFILE: 030 = the AGA 030 preset's settings (PROGDIR:AGA 030), FAST = the
; AGA preset's (PROGDIR:AGA), or the RTG preset's (PROGDIR:RTG) on RTG, AUTO =
; FAST on a 68040/68060, else 030. PREFS= / P= (or a PREFS ToolType) wins
; over PROFILE; with no PROFILE the settings are S:AmiMSX2.prefs as before
; (S:AmiMSXTurboR.prefs in the TURBOR build, 5.1).
; PROFILE=030 in the TURBOR build (AmiMSX Turbo R) loads the AGA 030
; settings in that build: there is no re-exec of PROGDIR:AmiMSX, as both programs
; have about 1.1 MB of chip RAM hunks (2.2 MB together, more than an AGA
; machine has), so the second one could not load while the first waits.
; RTGMODE= is accepted and not used yet (no RTG mode choice in AmiMSX).
; Workbench: a project icon whose default tool is AmiMSX (sm_ArgList[1]) is
; the game when its file exists and is not a settings file (a preset icon
; such as "AGA 030" names its own settings file); the project's ToolTypes may
; hold AGA, ONEGAME, MENU and PROFILE= too (RTG, SCANLINES and PREFS are
; read by WBToolTypes as before).
; Before the machine is taken over for a game named at start, AmiMSX waits
; (at most about 1 s) until no key, mouse button or fire button is held, so
; the Return or click that started it in a launcher isn't stuck down while
; the OS is off (LupaSettle). RTG asked for but not available: the menu
; window's title says "RTG not available: AGA" (LupaRtgNote).
; ONEGAME and Help: the cartridge's flash and SRAM and drive B are saved on
; the way back as always; a changed drive A (MVD) gets the usual "MVD: buffer
; not saved! Are you sure to Quit?" requester: Yes quits, No stays in the
; menu (to save the disk), where Quit or the next Help then quits.
; Return codes: 0 normal, 5 ran with a fallback (RTG asked for but not
; available; the PROFILE's settings file not there; TURBOR: a turbo R
; machine in the settings without the firmware, run as the MSX2+,
; TRMClamp), 10 the game could not be loaded (ONEGAME), 20 AmiMSX can't
; run here (no 68020, no screen or window, a missing library).

	CNOP	0,4
; ---------------------------------------------------------------------------
; LupaArgs (ANEM, program start): D0 = the length, A0 = the argument line.
; Shell only (pr_CLI); nothing open yet, no DOS calls.
LupaArgs:
	MOVEM.L	D0-D7/A0-A6,-(SP)
	MOVE.L	D0,D7
	MOVE.L	A0,A5
	SUB.L	A1,A1
	MOVE.L	4.W,A6
	JSR	-294(A6)		; FindTask(0)
	MOVE.L	D0,A1
	TST.L	$AC(A1)			; pr_CLI = 0: Workbench (LupaWB).
	BEQ	.x
	LEA	LupaLine,A1		; The line, NUL-terminated.
	MOVE.W	#LupaLineMax-2,D1
.cp:	SUBQ.L	#1,D7
	BMI.S	.ce
	MOVE.B	(A5)+,D0
	BEQ.S	.ce
	MOVE.B	D0,(A1)+
	DBF	D1,.cp
.ce:	CLR.B	(A1)
	LEA	LupaLine,A2
	MOVEQ	#0,D6			; D6 = positional words so far.
.next:	BSR	LupaWord		; -> LupaW, D0 = -1 at the end
	TST.L	D0
	BMI	.end
	MOVE.B	D2,D4			; D4 = "quoted"
	BSR	LupaKey			; D0 = keyword or -1, A1 = value or 0
	TST.L	D0
	BMI	.pos
	CMP.W	#LK_VAL,D0
	BCC.S	.val
	TST.B	D4			; A quoted switch word: a file name.
	BNE	.pos
	ADD.W	D0,D0
	MOVE.W	.sw(PC,D0.W),D0
	JMP	.sw(PC,D0.W)
.sw:	DC.W	.aga-.sw,.rtg-.sw,.one-.sw,.menu-.sw
.aga:	MOVE.B	#1,LupaDisp
	BRA.S	.next
.rtg:	MOVE.B	#2,LupaDisp
	BRA.S	.next
.one:	ST	LupaOne
	BRA.S	.next
.menu:	ST	LupaMenu
	BRA.S	.next
.val:	MOVE.L	D0,D5			; D5 = the keyword
	MOVE.L	A1,D1
	BNE.S	.hv
	BSR	LupaWord		; KEY value: the next word
	TST.L	D0
	BMI	.end
	LEA	LupaW,A1
.hv:	MOVE.L	D5,D0
	SUB.W	#LK_VAL,D0
	ADD.W	D0,D0
	MOVE.W	.vt(PC,D0.W),D0
	JMP	.vt(PC,D0.W)
.vt:	DC.W	.prof-.vt,.prefs-.vt,.prefs-.vt,.next2-.vt
	DC.W	.b-.vt,.r2-.vt,.s2-.vt,.d2-.vt
.prof:	BSR	LupaProfWord
.next2:	BRA	.next
.prefs:	LEA	NomPrefs,A0
	MOVE.W	#NOMPREFSLEN-2,D1
	BSR	LupaCopy
	ST	LupaPrefsSet
	BRA	.next
.b:	LEA	DISKBNOM,A0
	BRA.S	.c255
.r2:	LEA	ROM2NOM,A0
	BRA.S	.c255
.s2:	LEA	ROMS2NOM,A0
	BRA.S	.c255
.d2:	LEA	DSK2NOM,A0		; (5.6, test) D2=<a>[|<b>]: Disk2Next.
.c255:	MOVE.W	#256-2,D1
	BSR	LupaCopy
	BRA	.next
.pos:	LEA	LupaW,A1		; Positional: game, key script, drive B.
	MOVE.W	#256-2,D1
	LEA	KEYNOM,A0
	CMP.W	#1,D6
	BEQ.S	.pc
	LEA	DISKBNOM,A0
	CMP.W	#2,D6
	BEQ.S	.pc
	BHI.S	.pn			; (more: not used)
	LEA	FILENOM,A0
	MOVE.W	#$200-2,D1
.pc:	BSR	LupaCopy
.pn:	ADDQ.W	#1,D6
	BRA	.next
.end:	BSR	LupaKind
.x:	MOVEM.L	(SP)+,D0-D7/A0-A6
	RTS

; LupaWord: A2 = the line -> the next word in LupaW (at most 255
; characters), A2 past it. D0 = its length, -1 at the end of the line;
; D2 = 1 when it began with a quote. Quotes inside a word are taken out
; and keep spaces in (B="a b.dsk").
LupaWord:
	LEA	LupaW,A1
	MOVEQ	#0,D2
	MOVEQ	#0,D3			; D3 = inside quotes
	MOVE.W	#256-2,D1
.sp:	MOVE.B	(A2),D0
	BEQ.S	.end
	CMP.B	#10,D0
	BEQ.S	.end
	CMP.B	#' ',D0
	BHI.S	.st
	ADDQ.L	#1,A2
	BRA.S	.sp
.st:	CMP.B	#'"',D0
	BNE.S	.ch
	MOVEQ	#1,D2
.ch:	MOVE.B	(A2),D0
	BEQ.S	.done
	CMP.B	#10,D0
	BEQ.S	.done
	CMP.B	#'"',D0
	BNE.S	.nq
	ADDQ.L	#1,A2
	NOT.B	D3
	BRA.S	.ch
.nq:	TST.B	D3
	BNE.S	.put
	CMP.B	#' ',D0
	BLS.S	.done
.put:	ADDQ.L	#1,A2
	SUBQ.W	#1,D1
	BMI.S	.ch			; (too long: the rest is dropped)
	MOVE.B	D0,(A1)+
	BRA.S	.ch
.done:	CLR.B	(A1)
	MOVE.L	A1,D0
	SUB.L	#LupaW,D0
	RTS
.end:	MOVEQ	#-1,D0
	RTS

; LupaKey: LupaW against LupaKeys (any case; the word is the key, or the key
; then '=') -> D0 = its number or -1, A1 = the value after '=' or 0. D1, D3.
LupaKey:
	LEA	LupaKeys(PC),A1
	MOVEQ	#0,D0
.k:	TST.B	(A1)
	BEQ.S	.no
	LEA	LupaW,A0
.c:	MOVE.B	(A0)+,D1
	CMP.B	#'a',D1
	BCS.S	.u
	CMP.B	#'z',D1
	BHI.S	.u
	SUB.B	#32,D1
.u:	MOVE.B	(A1)+,D3
	BEQ.S	.ke			; The key ends: the word must end or go on with '='.
	CMP.B	D3,D1
	BEQ.S	.c
.sk:	TST.B	(A1)+			; The next key.
	BNE.S	.sk
	ADDQ.L	#1,D0
	BRA.S	.k
.ke:	TST.B	D1			; (A1 is at the next key now.)
	BEQ.S	.y0
	CMP.B	#'=',D1
	BNE.S	.nx
	MOVE.L	A0,A1			; KEY=value
	RTS
.y0:	SUB.L	A1,A1
	RTS
.nx:	ADDQ.L	#1,D0
	BRA.S	.k
.no:	MOVEQ	#-1,D0
	RTS

; LupaCopy: A1 -> A0, at most D1+1 characters, then a NUL.
LupaCopy:
.c:	MOVE.B	(A1)+,(A0)+
	DBEQ	D1,.c
	CLR.B	-1(A0)			; (the NUL, or the last that fits)
	RTS

; LupaProfWord: A1 = PROFILE's value -> LupaProf 1 (030), 2 (FAST), 3 (AUTO);
; another value is ignored.
LupaProfWord:
	MOVE.L	(A1),D0			; (any alignment on the 68020)
	CMP.L	#$30333000,D0		; "030",0
	BEQ.S	.p1
	TST.B	4(A1)			; (FAST, AUTO: four letters)
	BNE.S	.x
	OR.L	#$20202020,D0
	CMP.L	#'fast',D0
	BEQ.S	.p2
	CMP.L	#'auto',D0
	BNE.S	.x
	MOVE.B	#3,LupaProf
	RTS
.p1:	MOVE.B	#1,LupaProf
	RTS
.p2:	MOVE.B	#2,LupaProf
.x:	RTS

; LupaKind: FILENOM -> AutoCart (a cartridge), AutoDisk (*.dsk, drive A)
; or LupaTape (*.cas, the cassette); LupaGame when there is a name.
LupaKind:
	SF	AutoCart
	SF	AutoDisk
	SF	LupaTape
	LEA	FILENOM,A0
	TST.B	(A0)
	SNE	LupaGame
	BEQ.S	.x
	ST	AutoCart
.e:	TST.B	(A0)+
	BNE.S	.e
	SUBQ.L	#1,A0			; A0 = the NUL.
	MOVE.L	A0,D0
	SUB.L	#FILENOM,D0
	CMP.W	#5,D0
	BCS.S	.x
	MOVE.L	-4(A0),D0		; The last four characters.
	OR.L	#$00202020,D0
	CMP.L	#'.dsk',D0
	BEQ.S	.dsk
	CMP.L	#'.cas',D0
	BNE.S	.x
	SF	AutoCart
	ST	LupaTape
	RTS
.dsk:	SF	AutoCart
	ST	AutoDisk
.x:	RTS

; ---------------------------------------------------------------------------
; LupaWB (the menu's start, Workbench, after WBToolTypes): A2 = WBStartup.
LupaWB:
	MOVEM.L	D0-D7/A0-A6,-(SP)
	MOVE.L	A2,A4
	MOVE.L	$24(A4),A3		; sm_ArgList
	CMP.L	#2,$1C(A4)		; sm_NumArgs: the tool and a project
	BCS	.tt
	MOVE.L	8(A3),D1		; wa_Lock of the project
	BEQ	.tt
	MOVE.L	_DOSBASE,A6
	MOVE.L	#FILENOM,D2
	MOVE.L	#$200,D3
	JSR	-402(A6)		; NameFromLock
	TST.L	D0
	BEQ	.bad
	MOVE.L	#FILENOM,D1
	MOVE.L	12(A3),D2		; wa_Name
	MOVE.L	#$200,D3
	JSR	-882(A6)		; AddPart
	TST.L	D0
	BEQ.S	.bad
	MOVE.L	#FILENOM,D1		; Only a file that is there (a drawer
	MOVE.L	#1005,D2		; or a project with no file: no game)...
	JSR	-30(A6)			; Open
	MOVE.L	D0,D4
	BEQ.S	.bad
	CLR.L	LupaW
	CLR.L	LupaW+4
	MOVE.L	D4,D1
	MOVE.L	#LupaW,D2
	MOVEQ	#8,D3
	JSR	-42(A6)			; Read
	MOVE.L	D4,D1
	JSR	-36(A6)			; Close
	CMP.L	#"MSX2",LupaW		; ...and not a settings file: a preset
	BNE.S	.game			; icon (AGA 030, AGA, RTG) names its own.
	CMP.L	#"v2.5",LupaW+4
	BEQ.S	.bad
.game:	BSR	LupaKind
	BRA.S	.tt
.bad:	CLR.B	FILENOM
.tt:	MOVE.L	$1C(A4),D2		; The last WBArg's ToolTypes (the project's
	BEQ	.x			; icon, or AmiMSX's own).
	SUBQ.L	#1,D2
	LSL.L	#3,D2
	ADD.L	D2,A3
	MOVE.L	4.W,A6
	LEA	LupaIconNom(PC),A1
	MOVEQ	#36,D0
	JSR	-552(A6)		; OpenLibrary
	MOVE.L	D0,D5
	BEQ	.x
	MOVE.L	(A3),D1			; wa_Lock
	MOVE.L	_DOSBASE,A6
	JSR	-126(A6)		; CurrentDir
	MOVE.L	D0,D3
	MOVE.L	4(A3),A0		; wa_Name
	MOVE.L	D5,A6
	JSR	-78(A6)			; GetDiskObject
	MOVE.L	D0,D4
	MOVE.L	D3,D1
	MOVE.L	_DOSBASE,A6
	JSR	-126(A6)		; CurrentDir back
	TST.L	D4
	BEQ.S	.cl
	MOVE.L	D5,A6
	LEA	LupaKAga(PC),A1
	BSR.S	.find
	BEQ.S	.t1
	MOVE.B	#1,LupaDisp
.t1:	LEA	LupaKOne(PC),A1
	BSR.S	.find
	BEQ.S	.t2
	ST	LupaOne
.t2:	LEA	LupaKMenu(PC),A1
	BSR.S	.find
	BEQ.S	.t3
	ST	LupaMenu
.t3:	LEA	LupaKProf(PC),A1
	BSR.S	.find
	BEQ.S	.t4
	MOVE.L	D0,A1
	BSR	LupaProfWord
.t4:	MOVE.L	D4,A0
	JSR	-90(A6)			; FreeDiskObject
.cl:	MOVE.L	D5,A1
	MOVE.L	4.W,A6
	JSR	-414(A6)		; CloseLibrary
.x:	MOVEM.L	(SP)+,D0-D7/A0-A6
	RTS
.find:	MOVE.L	D4,A0			; A1 = the name -> D0 = its value or 0 (Z).
	MOVE.L	$36(A0),A0		; do_ToolTypes
	JSR	-96(A6)			; FindToolType
	TST.L	D0
	RTS

; ---------------------------------------------------------------------------
; LupaPrep (PROGRAMA, before LoadPrefs and RtgInit): the display for this
; run, then the PROFILE's settings file.
LupaPrep:
	MOVEM.L	D0-D7/A0-A6,-(SP)
	MOVE.B	LupaDisp,D0
	BEQ.S	.d
	SUBQ.B	#1,D0
	SNE	RtgWant			; 1 AGA, 2 RTG
.d:	MOVE.B	RtgWant,LupaAskRtg
	MOVE.B	LupaProf,D0
	BEQ.S	.x
	TST.B	LupaPrefsSet		; PREFS= / P= / the PREFS ToolType win.
	BNE.S	.x
	CMP.B	#3,D0
	BNE.S	.p
	MOVE.L	4.W,A0			; AUTO: a 68040 or 68060 is FAST,
	MOVEQ	#1,D0			; anything else 030.
	MOVE.B	$129(A0),D1		; AttnFlags
	AND.B	#$88,D1
	BEQ.S	.p
	MOVEQ	#2,D0
.p:	LEA	LupaP030(PC),A2
	CMP.B	#1,D0
	BEQ.S	.f
	LEA	LupaPAga(PC),A2
	TST.B	RtgWant
	BEQ.S	.f
	LEA	LupaPRtg(PC),A2
.f:	MOVE.L	A2,D1
	MOVEQ	#-2,D2			; SHARED_LOCK
	MOVE.L	_DOSBASE,A6
	JSR	-84(A6)			; Lock: is the preset's file there?
	TST.L	D0
	BEQ.S	.miss
	MOVE.L	D0,D1
	JSR	-90(A6)			; UnLock
	MOVE.L	A2,A1
	LEA	NomPrefs,A0
	MOVE.W	#NOMPREFSLEN-2,D1
	BSR	LupaCopy
	BRA.S	.x
.miss:	MOVEQ	#5,D0			; Not there: the settings as without
	BSR	LupaSetRC		; PROFILE, return code 5.
.x:	MOVEM.L	(SP)+,D0-D7/A0-A6
	RTS

; LupaRtgCheck (PROGRAMA, after RtgInit): RTG asked for, but not there.
LupaRtgCheck:
	MOVE.L	D0,-(SP)
	TST.B	LupaAskRtg
	BEQ.S	.x
	TST.B	RtgWant
	BNE.S	.x
	MOVEQ	#5,D0
	BSR	LupaSetRC
.x:	MOVE.L	(SP)+,D0
	RTS

; LupaRtgNote (PROGRAMA, the menu window just opened): RTG asked for, but
; not there: the window's title says so (the screen's title stays).
LupaRtgNote:
	TST.B	LupaAskRtg
	BEQ.S	.x
	TST.B	RtgWant
	BNE.S	.x
	MOVEM.L	D0-D1/A0-A2/A6,-(SP)
	MOVE.L	MSX2Wnd,D0
	BEQ.S	.n
	MOVE.L	D0,A0
	LEA	LupaRtgTxt(PC),A1
	SUB.L	A2,A2
	SUBQ.L	#1,A2			; (-1: the screen's title as it is)
	MOVE.L	_INTUITIONBASE,A6
	JSR	-276(A6)		; SetWindowTitles
.n:	MOVEM.L	(SP)+,D0-D1/A0-A2/A6
.x:	RTS

; LupaSettle (CONTROL, the start's GO, before MSX_GO takes the machine
; over): a game named at start waits, at most about 1 s, until no key
; (keyboard.device's matrix, Caps Lock aside), no mouse button and no fire
; button is held: the Return or click that started it in a launcher must not
; stay down while the OS is off.
LupaSettle:
	TST.B	LupaGame
	BEQ	.x
	TST.B	LupaSettled
	BNE	.x
	ST	LupaSettled
	MOVEM.L	D0-D7/A0-A6,-(SP)
	MOVE.L	4.W,A6
	MOVEQ	#0,D6			; D6 = the IORequest (0: buttons only)
	JSR	-666(A6)		; CreateMsgPort
	MOVE.L	D0,D7
	BEQ.S	.go
	MOVE.L	D0,A0
	MOVEQ	#48,D0			; (an IOStdReq)
	JSR	-654(A6)		; CreateIORequest
	MOVE.L	D0,D6
	BEQ.S	.go
	LEA	LupaKbdNom(PC),A0
	MOVEQ	#0,D0
	MOVE.L	D6,A1
	MOVEQ	#0,D1
	JSR	-444(A6)		; OpenDevice
	TST.B	D0
	BEQ.S	.go
	MOVE.L	D6,A0			; (not open: buttons only)
	JSR	-660(A6)		; DeleteIORequest
	MOVEQ	#0,D6
.go:	MOVEQ	#50,D5			; at most 50 ticks
.lp:	TST.L	D6
	BEQ.S	.bt
	MOVE.L	D6,A1
	MOVE.W	#10,28(A1)		; KBD_READMATRIX (CMD_NONSTD+1)
	MOVE.L	#16,36(A1)		; io_Length
	MOVE.L	#LupaMatrix,40(A1)	; io_Data
	CLR.L	LupaMatrix
	CLR.L	LupaMatrix+4
	CLR.L	LupaMatrix+8
	CLR.L	LupaMatrix+12
	JSR	-456(A6)		; DoIO
	AND.B	#$FB,LupaMatrix+12	; (Caps Lock, 62h: down while it is on)
	LEA	LupaMatrix,A0
	MOVE.L	(A0)+,D0
	OR.L	(A0)+,D0
	OR.L	(A0)+,D0
	OR.L	(A0),D0
	BNE.S	.held
.bt:	MOVE.B	$BFE001,D0		; CIA-A: the fire buttons (port 1's is
	NOT.B	D0			; the left mouse button), low = held
	AND.B	#$C0,D0
	BNE.S	.held
	BTST	#2,$DFF016		; POTGOR: the right mouse button
	BNE.S	.done
.held:	SUBQ.W	#1,D5
	BEQ.S	.done
	MOVE.L	_DOSBASE,A6
	MOVEQ	#1,D1
	JSR	-198(A6)		; Delay(1)
	MOVE.L	4.W,A6
	BRA.S	.lp
.done:	TST.L	D6
	BEQ.S	.np
	MOVE.L	D6,A1
	JSR	-450(A6)		; CloseDevice
	MOVE.L	D6,A0
	JSR	-660(A6)		; DeleteIORequest
.np:	TST.L	D7
	BEQ.S	.y
	MOVE.L	D7,A0
	JSR	-672(A6)		; DeleteMsgPort
.y:	MOVEM.L	(SP)+,D0-D7/A0-A6
.x:	RTS

; LupaSetRC: D0 = a return code; the highest one stays.
LupaSetRC:
	CMP.L	LupaRC,D0
	BLS.S	.x
	MOVE.L	D0,LupaRC
.x:	RTS

; LupaNoRun: AmiMSX can't run here (no 68020, no screen, no window).
LupaNoRun:
	MOVEQ	#20,D0
	BSR	LupaSetRC
	JMP	QUITAR

; LupaExitRC (the program's end, libraries closed) -> D0 = the return code:
; 20 when a library AmiMSX needs didn't open.
LupaExitRC:
	MOVEQ	#20,D0
	TST.L	_DOSBASE
	BEQ.S	.x
	TST.L	_INTUITIONBASE
	BEQ.S	.x
	TST.L	_GADTOOLSBASE
	BEQ.S	.x
	MOVE.L	LupaRC,D0
.x:	RTS

; ---------------------------------------------------------------------------
; LupaTapeLoad (the menu's start, after the cartridge and disk): a *.cas
; game into the cassette, as Load Tape File (the file checked first, so a
; file of another kind is closed again), then GO unless MENU.
LupaTapeLoad:
	TST.B	LupaTape
	BEQ.S	.x
	SF	LupaTape
	CLR.L	IDTapeBuf
	MOVE.L	#FILENOM,D1
	MOVE.L	#$3ED,D2
	JSR	OPENFILE
	BEQ.S	.err
	MOVE.L	#4*3,D3
	MOVE.L	#IDTapeBuf,D2
	JSR	READFILE
	JSR	CLOSEFILE
	LEA	IDTapeBuf,A1
	CMP.L	#"MSX2",(A1)+
	BNE.S	.not
	CMP.L	#"Tape",(A1)+
	BNE.S	.not
	CMP.L	#"v1.0",(A1)+
	BNE.S	.not
	JSR	LoadTapeF		; (Load Tape File after the requester.)
	TST.B	LupaErr
	BNE.S	.x
	TST.B	LupaMenu
	BNE.S	.x
	ST	AutoGo
.x:	RTS
.err:	LEA	TLEECANTO,A0
	JMP	IMPERROR
.not:	LEA	TLeeNoTape,A0
	JMP	IMPERROR

; LupaAfterLoad (the menu's start, after every load): a game that didn't
; load stays out of GO (its error is in the menu); with ONEGAME the program
; quits with 10.
LupaAfterLoad:
	TST.B	LupaGame
	BEQ.S	.x
	TST.B	LupaErr
	BEQ.S	.x
	SF	AutoGo
	TST.B	LupaOne
	BEQ.S	.x
	MOVEQ	#10,D0
	BSR	LupaSetRC
	ST	LupaQuit
.x:	RTS

; LupaQuitNow: ONEGAME: the program quits, no Quit requester.
LupaQuitNow:
	JSR	CLOSEMSX2WINDOW
	JMP	QUITAR

LupaLineMax=512
LK_VAL=4				; LupaKeys from here on take a value.
LupaKeys:	DC.B	"AGA",0,"RTG",0,"ONEGAME",0,"MENU",0
		DC.B	"PROFILE",0,"PREFS",0,"P",0,"RTGMODE",0
		DC.B	"B",0,"R2",0,"S2",0,"D2",0,0
LupaKAga:	DC.B	"AGA",0
LupaKOne:	DC.B	"ONEGAME",0
LupaKMenu:	DC.B	"MENU",0
LupaKProf:	DC.B	"PROFILE",0
LupaIconNom:	DC.B	"icon.library",0
LupaP030:	DC.B	"PROGDIR:AGA 030",0
LupaPAga:	DC.B	"PROGDIR:AGA",0
LupaPRtg:	DC.B	"PROGDIR:RTG",0
LupaKbdNom:	DC.B	"keyboard.device",0
LupaRtgTxt:	DC.B	"RTG not available: AGA",0
LupaDisp:	DC.B	0		; 0 as the icon says, 1 AGA, 2 RTG
LupaAskRtg:	DC.B	0		; RTG wanted when RtgInit looked
LupaProf:	DC.B	0		; 0 none, 1 030, 2 FAST, 3 AUTO
LupaPrefsSet:	DC.B	0		; PREFS= / P= given (WBToolTypes: the ToolType)
LupaOne:	DC.B	0		; ONEGAME
LupaMenu:	DC.B	0		; MENU
LupaGame:	DC.B	0		; a game was named
LupaTape:	DC.B	0		; it is a tape (*.cas)
LupaErr:	DC.B	0		; IMPERROR showed an error (the game's load)
LupaQuit:	DC.B	0		; quit without the Quit requester (ONEGAME)
LupaSettled:	DC.B	0		; LupaSettle has run (once)
	CNOP	0,4
LupaRC:		DC.L	0		; the program's return code
LupaMatrix:	DS.B	16		; keyboard.device's key matrix (LupaSettle)
LupaW:		DS.B	256
LupaLine:	DS.B	LupaLineMax
	CNOP	0,4
