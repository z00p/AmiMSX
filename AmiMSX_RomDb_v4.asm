;	 --------------------------------------------
;	- ROM database: mapper by SHA-1 (4.0) -
;	 --------------------------------------------
;
; AmiMSX4.romdb (tools/make_romdb.py, from openMSX's software database plus
; local extras): 8-byte entries sorted by the first 4 bytes of the ROM's
; SHA-1, with the AmiMSX mapper code (0 standard, 1 Konami, 2 ASCII8,
; 3 ASCII16, 4 Konami SCC, 6 R-Type (4.5); $FE: a type AmiMSX doesn't
; emulate).
;
; At load (RomDbCheck, while the file is still linear in memory), for
; MegaROMs that have no saved mapper: look in the cache (AmiMSX4.romcache:
; AmiMSX checksum + size -> answer), else hash the file and look it up, and
; cache the answer, so each ROM is hashed once (a 68020 needs seconds for a
; big ROM). MiConMapper0 then uses it after a saved mapper and before the
; file-name tag and the guess. Part of the menu (normal stack, the OS runs).

RDB_CACHEMAX=512		; cache entries (8 bytes: CheckId.L, PagCart.W,
				; code.B, 0)

	CNOP	0,4
RomDbCheck:
	SF	RomDbHit
	CLR.B	RomDbSram		; (4.4)
	CLR.B	RomDbMach		; (4.4) Every ROM now (the machine, for
	MOVEM.L	D0-D7/A0-A6,-(SP)	; the per-game defaults; the mapper for
					; MegaROMs only, as MiraCheckCart).
	JSR	MiConMapper		; A saved mapper wins (4.4: the lookup
					; still runs, for the SRAM flags).
	BSR	RomDbLoadFile		; (4.4) The database first: the cache
	BSR	RomCacheLoad		; must come from the same one.
	MOVE.L	RomCacheDir,D0		; Cached answer?
	BEQ.S	RomDbHash
	MOVE.L	D0,A0
	MOVE.W	RomCacheN,D1
	BRA.S	RomDbC2
RomDbC1:
	MOVE.L	(A0),D0
	CMP.L	CheckId,D0
	BNE.S	RomDbC3
	MOVE.W	4(A0),D0
	CMP.W	PagCart,D0
	BNE.S	RomDbC3
	BTST	#7,7(A0)		; (4.4) No flags (cached before 4.4):
	BEQ.S	RomDbC3			; look it up again.
	MOVE.B	6(A0),RomDbCode
	MOVE.B	7(A0),RomDbFlags
	BRA	RomDbGot
RomDbC3:
	ADDQ.L	#8,A0
RomDbC2:
	DBF	D1,RomDbC1
RomDbHash:
	BSR	RomDbLoadFile		; No: the SHA-1 of the file, looked
	MOVE.L	DirCart,A0		; up in the database.
	ADD.W	#$80,A0
	MOVE.L	BucFileCart,D0
	BSR	Sha1
	MOVE.B	#$FF,RomDbCode		; ($FF: not in the database)
	CLR.B	RomDbFlags
	MOVE.L	RomDbDir,D0
	BEQ.S	RomDbAdd
	MOVE.L	D0,A0
	MOVE.L	Sha1Out,D2		; Binary search on the key.
	MOVEQ	#0,D3			; low
	MOVE.L	RomDbN,D4		; high (exclusive)
RomDbBs:
	CMP.L	D4,D3
	BCC.S	RomDbAdd
	MOVE.L	D3,D5
	ADD.L	D4,D5
	LSR.L	#1,D5
	MOVE.L	(A0,D5.L*8),D6
	CMP.L	D2,D6
	BEQ.S	RomDbFound
	BCS.S	RomDbLo
	MOVE.L	D5,D4
	BRA.S	RomDbBs
RomDbLo:
	MOVE.L	D5,D3
	ADDQ.L	#1,D3
	BRA.S	RomDbBs
RomDbFound:
	MOVE.B	4(A0,D5.L*8),RomDbCode
	MOVE.B	5(A0,D5.L*8),RomDbType
	MOVE.B	6(A0,D5.L*8),RomDbFlags
RomDbAdd:
	BSR	RomCacheAdd
RomDbGot:
	MOVE.B	RomDbFlags,D0		; (4.4) SRAM: bits 4-6 (size, ASCII16).
	LSR.B	#4,D0
	AND.B	#7,D0
	MOVE.B	D0,RomDbSram
	MOVE.B	RomDbFlags,D0		; (4.4) The machine: bits 2-3 (1 MSX2,
	LSR.B	#2,D0			; 2 MSX2+, 3 turbo R).
	AND.B	#3,D0
	MOVE.B	D0,RomDbMach
	CMP.L	#($2080*5),BucCart	; (4.4) The mapper: MegaROMs only.
	BCS.S	RomDbX
	TST.B	SiNewMapp		; A saved mapper: not the database's.
	BEQ.S	RomDbX
	CMP.B	#6,RomDbCode		; $FE (not emulated) / $FF (unknown):
	BHI.S	RomDbX			; the tag and the guess decide. (4.5:
					; 6 = R-Type, menu index 7; 5 unused)
	ST	RomDbHit
RomDbX:
	MOVEM.L	(SP)+,D0-D7/A0-A6
RomDbRts:
	RTS

; -------------------------------------> Disks (4.4).
; AmiMSX4.diskdb (tools/make_diskdb.py): the machine for disk games by a cheap
; fingerprint of the image (no SHA-1: a 720 KB image takes seconds on a
; 68020), the 16-bit word sum of the whole image (29 bits, as CalCheckCart)
; and its size in KB. "AMXDD1",0,0, count.L, then 8-byte entries: sum.L,
; KB.W, machine.B (1 MSX2, 2 MSX2+, 3 turbo R), 0. DiskDbCheck runs as drive A
; loads an image (DIRFILE, BUCFILE - 1 KB): a game in it gets that machine,
; over the settings in force (kept aside as for a cartridge's own file).
DiskDbCheck:
	MOVEM.L	D0-D7/A0-A6,-(SP)
	MOVE.L	BUCFILE,D3
	SUB.L	#1024,D3		; The image's size.
	MOVE.L	D3,D0
	LSR.L	#1,D0
	BEQ	DkDbX
	MOVE.L	DIRFILE,A0
	MOVEQ	#0,D1
	MOVEQ	#0,D2
DkDbS:	MOVE.W	(A0)+,D1
	ADD.L	D1,D2
	SUBQ.L	#1,D0
	BNE.S	DkDbS
	AND.L	#$1FFFFFFF,D2
	LSR.L	#8,D3
	LSR.L	#2,D3			; KB
	IFD	DKDBLOG			; (debug: the key into AmiMSX:diskdb.log)
	MOVEM.L	D2-D3,DkDbLogB
	MOVEM.L	D2-D3,-(SP)
	MOVE.L	#DkDbLogN,D1
	MOVE.L	#$3EE,D2
	JSR	OpenFile
	BEQ.S	DkDbLg1
	MOVE.L	#DkDbLogB,D2
	MOVEQ	#8,D3
	JSR	WriteFile
	JSR	CloseFile
DkDbLg1:MOVEM.L	(SP)+,D2-D3
	ENDC
	MOVEM.L	D2-D3,-(SP)		; (DiskDbLoad uses them)
	BSR	DiskDbLoad
	MOVEM.L	(SP)+,D2-D3
	MOVE.L	DiskDbDir,D0
	BEQ	DkDbX
	MOVE.L	D0,A0
	MOVE.L	DiskDbN,D1
	BRA.S	DkDbL2
DkDbL1:	CMP.L	(A0),D2
	BNE.S	DkDbL3
	CMP.W	4(A0),D3
	BEQ.S	DkDbHit
DkDbL3:	ADDQ.L	#8,A0
DkDbL2:	SUBQ.L	#1,D1
	BPL.S	DkDbL1
	BRA.S	DkDbX
DkDbHit:MOVEQ	#0,D0
	MOVE.B	6(A0),D0
	BEQ.S	DkDbX
	MOVE.L	D0,-(SP)
	TST.B	GPActive		; The settings in force aside (once),
	BNE.S	DkDbH1
	JSR	GPGUIToPrefs
	LEA	GPSaved,A1
	JSR	GPFromPrefs
	ST	GPActive
DkDbH1:	JSR	GPGUIToPrefs		; then the machine over them.
	MOVE.L	(SP)+,D0
	JSR	GDMach
	JSR	GPShowGUI
	IFD	DKDBLOG
	MOVE.B	DirPrefs+$10,DkDbLogB+6
	MOVE.B	#$EE,DkDbLogB+7
	MOVE.L	#DkDbLogN,D1
	MOVE.L	#$3EE,D2
	JSR	OpenFile
	BEQ.S	DkDbX
	MOVE.L	#DkDbLogB,D2
	MOVEQ	#8,D3
	JSR	WriteFile
	JSR	CloseFile
	ENDC
DkDbX:	MOVEM.L	(SP)+,D0-D7/A0-A6
	RTS

	IFD	DKDBLOG
DkDbLogB:	DS.L	2
DkDbLogN:	DC.B	"AmiMSX:diskdb.log",0
	EVEN
	ENDC

DiskDbLoad:
	TST.B	DiskDbTried
	BNE	DkDbLR
	ST	DiskDbTried
	MOVE.L	#tDiskDb,D1
	MOVE.L	#$3ED,D2
	JSR	OpenFile
	BEQ	DkDbLR
	MOVE.L	#RomDbHdr,D2
	MOVE.L	#12,D3
	JSR	ReadFile
	CMP.L	#"AMXD",RomDbHdr
	BNE.S	DkDbLC
	CMP.W	#"D1",RomDbHdr+4
	BNE.S	DkDbLC
	MOVE.L	RomDbHdr+8,D0
	BEQ.S	DkDbLC
	CMP.L	#65536,D0		; (sanity)
	BHI.S	DkDbLC
	LSL.L	#3,D0
	MOVE.L	D0,DiskDbSize
	MOVE.L	#$00010000,D1
	MOVE.L	4.W,A6
	JSR	-$C6(A6)		; AllocMem
	MOVE.L	D0,DiskDbDir
	BEQ.S	DkDbLC
	MOVE.L	D0,D2
	MOVE.L	DiskDbSize,D3
	JSR	ReadFile
	MOVE.L	RomDbHdr+8,DiskDbN
DkDbLC:	JSR	CloseFile
DkDbLR:	RTS

; -------------------------------------> The database file (once).
RomDbLoadFile:
	TST.B	RomDbTried
	BNE	RomDbLfR
	ST	RomDbTried
	MOVE.L	#tRomDb,D1
	MOVE.L	#$3ED,D2
	JSR	OpenFile
	BEQ	RomDbLfR
	MOVE.L	#RomDbHdr,D2
	MOVE.L	#12,D3
	JSR	ReadFile
	CMP.L	#"AMXD",RomDbHdr
	BNE.S	RomDbLfC
	MOVE.L	RomDbHdr+8,D0
	BEQ.S	RomDbLfC
	LSL.L	#3,D0
	MOVE.L	D0,RomDbSize
	MOVE.L	#$00010000,D1
	MOVE.L	4.W,A6
	JSR	-$C6(A6)		; AllocMem
	MOVE.L	D0,RomDbDir
	BEQ.S	RomDbLfC
	MOVE.L	D0,D2
	MOVE.L	RomDbSize,D3
	JSR	ReadFile
	MOVE.L	RomDbHdr+8,RomDbN
	MOVE.L	RomDbDir,A0		; (4.4) Its sum, for the cache's stamp.
	MOVE.L	RomDbN,D0
	MOVE.L	D0,D1
	ADD.L	D0,D0			; longs
	BRA.S	RomDbSm2
RomDbSm1:ADD.L	(A0)+,D1
RomDbSm2:SUBQ.L	#1,D0
	BPL.S	RomDbSm1
	MOVE.L	D1,RomDbSum
RomDbLfC:
	JSR	CloseFile
RomDbLfR:
	RTS

; -------------------------------------> The cache (once; written on change).
RomCacheLoad:
	TST.L	RomCacheDir
	BNE	RomCaLR
	MOVE.L	#RDB_CACHEMAX*8,D0
	MOVE.L	#$00010000,D1
	MOVE.L	4.W,A6
	JSR	-$C6(A6)		; AllocMem
	MOVE.L	D0,RomCacheDir
	BEQ	RomCaLR
	CLR.W	RomCacheN
	MOVE.L	#tRomCache,D1
	JSR	LongFile		; (0 if there's no file yet)
	TST.L	D0
	BEQ	RomCaLR
	CMP.L	#RDB_CACHEMAX*8,D0
	BLS.S	RomCaL1
	MOVE.L	#RDB_CACHEMAX*8,D0
RomCaL1:
	LSR.L	#3,D0
	MOVE.W	D0,RomCacheN
	MOVE.L	#tRomCache,D1
	MOVE.L	#$3ED,D2
	JSR	OpenFile
	BEQ.S	RomCaLN
	MOVE.L	RomCacheDir,D2
	MOVEQ	#0,D3
	MOVE.W	RomCacheN,D3
	LSL.L	#3,D3
	JSR	ReadFile
	JSR	CloseFile
	MOVE.L	RomCacheDir,A0		; (4.4) Entry 0 stamps the database the
	CMP.L	#"RDB4",(A0)		; answers came from (RomDbSum); another
	BNE.S	RomCaLN			; one (or a cache from before 4.4):
	MOVE.L	4(A0),D0		; start again.
	CMP.L	RomDbSum,D0
	BNE.S	RomCaLN
	RTS
RomCaLN:
	CLR.W	RomCacheN
RomCaLR:
	RTS

RomCacheAdd:
	MOVE.L	RomCacheDir,D0
	BEQ	RomCaAR
	MOVE.L	D0,A0
	TST.W	RomCacheN		; (4.4) A new cache: the stamp first
	BNE.S	RomCaA0			; ("RDB4", the database's sum; it never
	MOVE.L	#"RDB4",(A0)		; matches a CheckId, 29 bits).
	MOVE.L	RomDbSum,4(A0)
	MOVE.W	#1,RomCacheN
RomCaA0:MOVEQ	#0,D0
	MOVE.W	RomCacheN,D0
	CMP.W	#RDB_CACHEMAX,D0	; Full: overwrite the oldest (ring,
	BCS.S	RomCaA1			; not the stamp).
	MOVE.W	RomCacheRing,D0
	BNE.S	RomCaRg
	MOVEQ	#1,D0
RomCaRg:MOVE.W	D0,RomCacheRing
	ADDQ.W	#1,RomCacheRing
	AND.W	#RDB_CACHEMAX-1,RomCacheRing
	BRA.S	RomCaA2
RomCaA1:
	ADDQ.W	#1,RomCacheN
RomCaA2:
	LEA	(A0,D0.L*8),A1
	MOVE.L	CheckId,(A1)+
	MOVE.W	PagCart,(A1)+
	MOVE.B	RomDbCode,(A1)+
	MOVE.B	RomDbFlags,D0		; (4.4) the flags, bit 7: they're there
	BSET	#7,D0
	MOVE.B	D0,(A1)
	MOVE.L	#tRomCache,D1
	MOVE.L	#$3EE,D2
	JSR	OpenFile
	BEQ.S	RomCaAR
	MOVE.L	RomCacheDir,D2
	MOVEQ	#0,D3
	MOVE.W	RomCacheN,D3
	LSL.L	#3,D3
	JSR	WriteFile
	JSR	CloseFile
RomCaAR:
	RTS

; -------------------------------------> Free (at exit).
RomDbFree:
	MOVE.L	4.W,A6
	MOVE.L	RomDbDir,D0
	BEQ.S	RomDbF1
	MOVE.L	D0,A1
	MOVE.L	RomDbSize,D0
	JSR	-$D2(A6)		; FreeMem
	CLR.L	RomDbDir
RomDbF1:
	MOVE.L	RomCacheDir,D0
	BEQ.S	RomDbF2
	MOVE.L	D0,A1
	MOVE.L	#RDB_CACHEMAX*8,D0
	JSR	-$D2(A6)
	CLR.L	RomCacheDir
RomDbF2:
	MOVE.L	DiskDbDir,D0		; (4.4)
	BEQ.S	RomDbF3
	MOVE.L	D0,A1
	MOVE.L	DiskDbSize,D0
	JSR	-$D2(A6)
	CLR.L	DiskDbDir
RomDbF3:
	RTS

; -------------------------------------> SHA-1.
; A0 = data (even address), D0.L = length in bytes -> Sha1Out (20 bytes).
	CNOP	0,4
Sha1:
	MOVEM.L	D0-D7/A0-A3,-(SP)
	MOVE.L	D0,Sha1Len
	LEA	Sha1H,A2
	MOVE.L	#$67452301,(A2)
	MOVE.L	#$EFCDAB89,4(A2)
	MOVE.L	#$98BADCFE,8(A2)
	MOVE.L	#$10325476,12(A2)
	MOVE.L	#$C3D2E1F0,16(A2)
	MOVE.L	A0,A3
	MOVE.L	D0,D7
	LSR.L	#6,D7			; whole 64-byte blocks
	BEQ.S	Sha1Tl
Sha1Bl:	MOVE.L	A3,A1
	BSR	Sha1Block
	LEA	64(A3),A3
	SUBQ.L	#1,D7
	BNE.S	Sha1Bl
Sha1Tl:	LEA	Sha1Pad,A1		; The rest, 80h, zeros, bit length.
	MOVEQ	#128/4-1,D1
Sha1Cl:	CLR.L	(A1)+
	DBF	D1,Sha1Cl
	LEA	Sha1Pad,A1
	MOVE.L	Sha1Len,D0
	AND.W	#63,D0
	MOVE.W	D0,D1
	BRA.S	Sha1Cp2
Sha1Cp:	MOVE.B	(A3)+,(A1)+
Sha1Cp2:
	DBF	D1,Sha1Cp
	MOVE.B	#$80,(A1)
	LEA	Sha1Pad+56,A1		; One block, or two if the rest is 56+.
	CMP.W	#56,D0
	BCS.S	Sha1L1
	LEA	Sha1Pad+120,A1
Sha1L1:	MOVE.L	Sha1Len,D1
	MOVE.L	D1,D2
	MOVEQ	#29,D3
	LSR.L	D3,D2			; bits 32-63
	LSL.L	#3,D1			; bits 0-31
	MOVE.L	D2,(A1)+
	MOVE.L	D1,(A1)
	LEA	Sha1Pad,A1
	BSR	Sha1Block
	CMP.W	#56,D0
	BCS.S	Sha1Dn
	LEA	Sha1Pad+64,A1
	BSR	Sha1Block
Sha1Dn:	LEA	Sha1H,A0
	LEA	Sha1Out,A1
	MOVEQ	#5-1,D1
Sha1Oc:	MOVE.L	(A0)+,(A1)+
	DBF	D1,Sha1Oc
	MOVEM.L	(SP)+,D0-D7/A0-A3
	RTS

; One round step: temp = ROL5(a) + f(D5) + e + K + W[t]; e = d; d = c;
; c = ROL30(b); b = a; a = temp. (D0-D4 = a-e.)
SHA1STEP:	MACRO
	ADD.L	#\1,D5
	ADD.L	(A0)+,D5
	ADD.L	D4,D5
	MOVE.L	D0,D6
	ROL.L	#5,D6
	ADD.L	D6,D5
	MOVE.L	D3,D4
	MOVE.L	D2,D3
	MOVE.L	D1,D2
	ROR.L	#2,D2
	MOVE.L	D0,D1
	MOVE.L	D5,D0
	ENDM

; A1 = 64-byte block (even address).
Sha1Block:
	MOVEM.L	D0-D7/A0-A1,-(SP)
	LEA	Sha1W,A0		; W[0..15] = the block,
	MOVEQ	#16-1,D7
Sha1W1:	MOVE.L	(A1)+,(A0)+
	DBF	D7,Sha1W1
	MOVEQ	#64-1,D7		; W[t] = ROL1(W[t-3]^W[t-8]^W[t-14]^W[t-16])
Sha1W2:	MOVE.L	-12(A0),D0
	MOVE.L	-32(A0),D1
	EOR.L	D1,D0
	MOVE.L	-56(A0),D1
	EOR.L	D1,D0
	MOVE.L	-64(A0),D1
	EOR.L	D1,D0
	ROL.L	#1,D0
	MOVE.L	D0,(A0)+
	DBF	D7,Sha1W2
	MOVEM.L	Sha1H,D0-D4
	LEA	Sha1W,A0
	MOVEQ	#20-1,D7		; 0-19: (b & c) | (~b & d)
Sha1R1:	MOVE.L	D1,D5
	AND.L	D2,D5
	MOVE.L	D1,D6
	NOT.L	D6
	AND.L	D3,D6
	OR.L	D6,D5
	SHA1STEP	$5A827999
	DBF	D7,Sha1R1
	MOVEQ	#20-1,D7		; 20-39: b ^ c ^ d
Sha1R2:	MOVE.L	D1,D5
	EOR.L	D2,D5
	EOR.L	D3,D5
	SHA1STEP	$6ED9EBA1
	DBF	D7,Sha1R2
	MOVEQ	#20-1,D7		; 40-59: majority
Sha1R3:	MOVE.L	D1,D5
	AND.L	D2,D5
	MOVE.L	D1,D6
	AND.L	D3,D6
	OR.L	D6,D5
	MOVE.L	D2,D6
	AND.L	D3,D6
	OR.L	D6,D5
	SHA1STEP	$8F1BBCDC
	DBF	D7,Sha1R3
	MOVEQ	#20-1,D7		; 60-79: b ^ c ^ d
Sha1R4:	MOVE.L	D1,D5
	EOR.L	D2,D5
	EOR.L	D3,D5
	SHA1STEP	$CA62C1D6
	DBF	D7,Sha1R4
	LEA	Sha1H,A1
	ADD.L	D0,(A1)+
	ADD.L	D1,(A1)+
	ADD.L	D2,(A1)+
	ADD.L	D3,(A1)+
	ADD.L	D4,(A1)
	MOVEM.L	(SP)+,D0-D7/A0-A1
	RTS

	CNOP	0,4
Sha1H:		DS.L	5
Sha1Out:	DS.L	5
Sha1Len:	DS.L	1
Sha1W:		DS.L	80
Sha1Pad:	DS.B	128
RomDbHdr:	DS.L	3		; "AMXDB1",0,0, count
RomDbDir:	DC.L	0
RomDbSize:	DC.L	0
RomDbN:		DC.L	0
RomCacheDir:	DC.L	0
RomCacheN:	DC.W	0
RomCacheRing:	DC.W	0
RomDbHit:	DC.B	0		; RomDbCheck found a mapper for this load
RomDbCode:	DC.B	0
RomDbType:	DC.B	0		; openMSX type number (AmiMSX4_types.txt)
RomDbFlags:	DC.B	0		; (4.4) its flags (make_romdb.py)
	EVEN
RomDbSum:	DC.L	0		; (4.4) the database's sum (the cache's stamp)
RomDbSram:	DC.B	0		; (4.4) SRAM: bits 0-1 size, bit 2 ASCII16
RomDbMach:	DC.B	0		; (4.4) machine: 0 MSX/unknown, 1 MSX2, 2 MSX2+, 3 turbo R
RomDbTried:	DC.B	0
Cart8K:		DC.B	0		; (8-16 Kb file: one 16 Kb page)
	EVEN
tRomDb:		DC.B	"PROGDIR:AmiMSX4.romdb",0
tRomCache:	DC.B	"PROGDIR:AmiMSX4.romcache",0
tDiskDb:	DC.B	"PROGDIR:AmiMSX4.diskdb",0
	EVEN
DiskDbDir:	DC.L	0		; (4.4) the disk database, its size, entries
DiskDbSize:	DC.L	0
DiskDbN:	DC.L	0
DiskDbTried:	DC.B	0
	EVEN
