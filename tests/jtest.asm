; jtest: MSX joystick and key-matrix readout (sjasmplus --raw=jtest.rom).
; Shows PSG R#14 for joystick 1 and 2 and keyboard rows 4, 6, 7, 8 and 10
; as bits (0 = pressed), plus a frame counter, in SCREEN 0. Used for the
; CD32 pad tests in WinUAE (Docs/open_issues.md, CD32 entries): a test
; build (vasm -DCD32TEST=1) dumps the raw pad byte into row 10.
	DEVICE NONE
	ORG $4000
	DB "AB"
	DW Init
	DS 12,0

CHPUT	EQU $00A2
INITXT	EQU $006C
LDIRVM	EQU $005C
SNSMAT	EQU $0141
BUF	EQU $C000			; 12 rows x 40 columns
FRAME	EQU $C400

Init:
	LD A,40
	LD ($F3AE),A			; LINL40
	CALL INITXT
	LD HL,BUF
	LD DE,BUF+1
	LD BC,12*40-1
	LD (HL),' '
	LDIR
	LD HL,Labels
	LD DE,BUF
	LD BC,LabelsEnd-Labels
	LDIR
	LD HL,0
	LD (FRAME),HL
Loop:
	EI
	HALT
	LD HL,(FRAME)
	INC HL
	LD (FRAME),HL
	LD A,15
	OUT ($A0),A
	LD A,$8F			; joystick 1 on R#14
	OUT ($A1),A
	LD A,14
	OUT ($A0),A
	IN A,($A2)
	LD HL,BUF+2*40+8
	CALL Bits
	LD A,15
	OUT ($A0),A
	LD A,$CF			; joystick 2
	OUT ($A1),A
	LD A,14
	OUT ($A0),A
	IN A,($A2)
	LD HL,BUF+3*40+8
	CALL Bits
	LD A,4
	CALL SNSMAT
	LD HL,BUF+5*40+8
	CALL Bits
	LD A,6
	CALL SNSMAT
	LD HL,BUF+6*40+8
	CALL Bits
	LD A,7
	CALL SNSMAT
	LD HL,BUF+7*40+8
	CALL Bits
	LD A,8
	CALL SNSMAT
	LD HL,BUF+8*40+8
	CALL Bits
	LD A,10
	CALL SNSMAT
	LD HL,BUF+9*40+8
	CALL Bits
	LD A,(FRAME+1)
	LD HL,BUF+11*40+8
	CALL Bits
	LD A,(FRAME)
	LD HL,BUF+11*40+18
	CALL Bits
	LD HL,BUF
	LD DE,0
	LD BC,12*40
	CALL LDIRVM
	JP Loop

; A = byte, HL = buffer: 8 characters '0'/'1', bit 7 first.
Bits:
	LD B,8
Bits1:
	RLCA
	PUSH AF
	LD A,'0'
	ADC A,0
	LD (HL),A
	INC HL
	POP AF
	DJNZ Bits1
	RET

Labels:
	DB "AMIMSX PAD TEST  bits 7..0, 0 = pressed "
	DB "                                        "
	DB "JOY1    ........  BA RLDU               "
	DB "JOY2    ........                        "
	DB "                                        "
	DB "ROW4    ........  M = bit 2             "
	DB "ROW6    ........  F1 = bit 5            "
	DB "ROW7    ........  F5 = bit 1            "
	DB "ROW8    ........  SPACE = bit 0         "
	DB "ROW10   ........  CD32 raw (test build) "
	DB "                                        "
	DB "FRAME   ........  ........              "
LabelsEnd:
	DS $8000-$,0
