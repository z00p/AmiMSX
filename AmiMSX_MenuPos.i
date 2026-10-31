; AmiMSX menu positions (4.6). One name per menu line, separators included, in
; menu order. A name's value is the line's Intuition menu number: menu (bits
; 0-4), item (bits 5-10), sub-item (bits 11-15; 0 for an item without
; sub-items, as before), as COGECHECK (ItemAddress) takes it.
; The menu data (GadToolsBox/AmiMSX_v3.1.s: MDT/MDI/MDS before each NewMenu
; entry) and the jump tables (AmiMSX_Menu_v3.1.asm: MJ/MJS/MJEND) check
; themselves against this list when built: a line added, removed or moved in
; one place and not the others stops the build. Moving a line: move it here,
; in the menu data and in its jump table; code uses the names only.
; NI_<menu> = the number of items of a menu, NS_<item> = of an item's
; sub-items.

_MM	SET	-1
_DM	SET	-1
MTITLE	MACRO			; name: the next menu
_MM	SET	_MM+1
_MI	SET	0
\1	EQU	_MM
	ENDM
MITEM	MACRO			; name: the next item of this menu
\1	EQU	_MM+(_MI<<5)
_MI	SET	_MI+1
_MS	SET	0
	ENDM
MSUB	MACRO			; name: the next sub-item of the last item
\1	EQU	_MM+((_MI-1)<<5)+(_MS<<11)
_MS	SET	_MS+1
	ENDM
MICOUNT	MACRO			; name = the items of this menu so far
\1	EQU	_MI
	ENDM
MSCOUNT	MACRO			; name = the sub-items of the last item
\1	EQU	_MS
	ENDM

; Menu data checks, each before its NewMenu entry.
MDT	MACRO			; a title: menu \1
_DM	SET	_DM+1
_DI	SET	0
	IFNE	(\1)-_DM
	FAIL	"menu data: title \1 out of place"
	ENDC
	ENDM
MDI	MACRO			; item \1
	IFNE	(\1)-(_DM+(_DI<<5))
	FAIL	"menu data: item \1 out of place"
	ENDC
_DI	SET	_DI+1
_DS	SET	0
	ENDM
MDS	MACRO			; sub-item \1
	IFNE	(\1)-(_DM+((_DI-1)<<5)+(_DS<<11))
	FAIL	"menu data: sub-item \1 out of place"
	ENDC
_DS	SET	_DS+1
	ENDM
MDICNT	MACRO			; after a menu's last item: \1 items
	IFNE	(\1)-_DI
	FAIL	"menu data: not \1 items"
	ENDC
	ENDM
MDSCNT	MACRO			; after an item's last sub-item: \1 of them
	IFNE	(\1)-_DS
	FAIL	"menu data: not \1 sub-items"
	ENDC
	ENDM

; Jump tables (ESMENU): MJ table,item,handler for an item's entry; MJS
; table,sub-item,handler for a sub-item's; MJEND table,count after the last.
MJ	MACRO
	IFNE	(*-\1)-((((\2)>>5)&63)*4)
	FAIL	"menu table \1: \2 out of place"
	ENDC
	DC.L	\3
	ENDM
MJS	MACRO
	IFNE	(*-\1)-((((\2)>>11)&31)*4)
	FAIL	"menu table \1: \2 out of place"
	ENDC
	DC.L	\3
	ENDM
MJEND	MACRO
	IFNE	(*-\1)-((\2)*4)
	FAIL	"menu table \1: not \2 entries"
	ENDC
	ENDM
	MTITLE	MT_Project		; Project
	MITEM	MN_About		; About...
	MITEM	MN_ProjectBar0		; ---
	MITEM	MN_SavePrefs		; Save Settings
	MITEM	MN_GameSave		; Save Game Settings
	MITEM	MN_GameForget		; Forget Game Settings
	MITEM	MN_ProjectBar1		; ---
	MITEM	MN_AskReset		; Confirm Reset
	MITEM	MN_Overwrite		; Always Overwrite
	MITEM	MN_ProjectBar2		; ---
	MITEM	MN_Quit		; Quit
	MICOUNT	NI_Project

	MTITLE	MT_Emulation		; Emulation
	MITEM	MN_Speed		; Speed
	MSUB	MN_SpeedNormal		;   Normal
	MSUB	MN_SpeedOC		;   Overclock
	MSUB	MN_SpeedNoLimit		;   No Limit
	MSCOUNT	NS_Speed
	MITEM	MN_JapID		; Japanese Machine (60 Hz)
	MITEM	MN_Kanji		; Kanji ROM
	MITEM	MN_Filter		; Audio Filter (less hiss)
	MITEM	MN_EmulationBar0		; ---
	MITEM	MN_Mask		; Mask Screen Edges
	MSUB	MN_MaskOff		;   Off
	MSUB	MN_Mask8		;   8 dots
	MSUB	MN_Mask16		;   16 dots
	MSCOUNT	NS_Mask
	MITEM	MN_Smooth		; Smooth Display (fast CPUs)
	MITEM	MN_Scan		; RTG Scanlines
	MSUB	MN_ScanOff		;   Off
	MSUB	MN_ScanH25		;   Hard 25%
	MSUB	MN_ScanH50		;   Hard 50%
	MSUB	MN_ScanH75		;   Hard 75%
	MSUB	MN_ScanBL		;   Blended light
	MSUB	MN_ScanB		;   Blended
	MSUB	MN_ScanBS		;   Blended strong
	MSCOUNT	NS_Scan
	MITEM	MN_ScrMode		; Amiga Video
	MSUB	MN_SetPAL		;   Menu in PAL
	MSUB	MN_SetNTSC		;   Menu in NTSC
	MSCOUNT	NS_ScrMode
	MITEM	MN_Internal		; Compatibility
	MSUB	MN_SprLate		;   Sprites a Frame Late
	MSUB	MN_FullRedraw		;   Full Redraw on Mode Change
	MSUB	MN_TRBit		;   VDP Always Ready (TR bit)
	MSCOUNT	NS_Internal
	MICOUNT	NI_Emulation

	MTITLE	MT_Input		; Input
	MITEM	MN_Joy2		; MSX Joystick 2 in Mouse Port
	MITEM	MN_SwapJoy		; Swap Joystick Ports
	MITEM	MN_Pad2		; Joystick Port
	MSUB	MN_Pad2Std		;   Standard (2 buttons)
	MSUB	MN_Pad2CD32		;   CD32 Pad
	MSCOUNT	NS_Pad2
	MITEM	MN_Pad1		; Mouse Port
	MSUB	MN_Pad1Std		;   Standard (2 buttons)
	MSUB	MN_Pad1CD32		;   CD32 Pad
	MSCOUNT	NS_Pad1
	MITEM	MN_InputBar0		; ---
	MITEM	MN_MultiKey		; Multi-Key (A1200 keyboard)
	MITEM	MN_DelPause		; DEL Pauses
	MITEM	MN_LShift		; Left Shift as Space
	MITEM	MN_RShift		; Right Shift as Space
	MICOUNT	NI_Input

	MTITLE	MT_Disks		; Disks
	MITEM	MN_DriveA		; Drive A
	MSUB	MN_LoadImg		;   Load...
	MSUB	MN_SaveImg		;   Save...
	MSUB	MN_EjectImg		;   Eject
	MSCOUNT	NS_DriveA
	MITEM	MN_DriveB		; Drive B
	MSUB	MN_LoadImgB		;   Load...
	MSUB	MN_EjectImgB		;   Eject
	MSCOUNT	NS_DriveB
	MITEM	MN_DisksBar0		; ---
	MITEM	MN_WProt		; Write-Protect Disk Image
	MITEM	MN_WarnProt		; Warn if Protected
	MITEM	MN_WarnChg		; Warn if Changed
	MITEM	MN_DisksBar1		; ---
	MITEM	MN_Floppy		; Real MSX Floppy
	MSUB	MN_ReadFloppy		;   Read Floppy into Image...
	MSUB	MN_WriteFloppy		;   Write Image to Floppy...
	MSUB	MN_FloppyBar0		;   ---
	MSUB	MN_InstBoot		;   Install Boot Sector...
	MSUB	MN_FloppyBar1		;   ---
	MSUB	MN_BootAuto		;   Boot Sector: Auto
	MSUB	MN_Boot1DD		;   Boot Sector: 1DD
	MSUB	MN_Boot2DD		;   Boot Sector: 2DD
	MSCOUNT	NS_Floppy
	MICOUNT	NI_Disks

	MTITLE	MT_Carts		; Cartridges
	MITEM	MN_Slot1		; Slot 1
	MSUB	MN_Sl1Insert		;   Insert...
	MSUB	MN_Sl1Eject		;   Eject
	MSUB	MN_Slot1Bar0		;   ---
	MSUB	MN_Sl1SaveMap		;   Remember Mapper for This ROM
	MSCOUNT	NS_Slot1
	MITEM	MN_Map1		; Slot 1 Mapper
	MSUB	MN_Map1None		;   None
	MSUB	MN_Map1Gen16		;   Generic 16K
	MSUB	MN_Map1Konami		;   Konami
	MSUB	MN_Map1Asc8		;   ASCII 8K
	MSUB	MN_Map1Asc16		;   ASCII 16K
	MSUB	MN_Map1SCC		;   Konami SCC
	MSUB	MN_Map1SCCs		;   Konami SCC (strict)
	MSUB	MN_Map1RType		;   R-Type
	MSCOUNT	NS_Map1
	MITEM	MN_CartsBar0		; ---
	MITEM	MN_Slot2		; Slot 2
	MSUB	MN_Sl2Insert		;   Insert...
	MSUB	MN_Sl2Eject		;   Eject
	MSUB	MN_Slot2Bar0		;   ---
	MSUB	MN_Sl2SaveMap		;   Remember Mapper for This ROM
	MSCOUNT	NS_Slot2
	MITEM	MN_Map2		; Slot 2 Mapper
	MSUB	MN_Map2None		;   None
	MSUB	MN_Map2Gen16		;   Generic 16K
	MSUB	MN_Map2Konami		;   Konami
	MSUB	MN_Map2Asc8		;   ASCII 8K
	MSUB	MN_Map2Asc16		;   ASCII 16K
	MSUB	MN_Map2SCC		;   Konami SCC
	MSUB	MN_Map2SCCs		;   Konami SCC (strict)
	MSUB	MN_Map2RType		;   R-Type
	MSCOUNT	NS_Map2
	MICOUNT	NI_Carts

	MTITLE	MT_Tape		; Tape
	MITEM	MN_LoadTape		; Load Tape File...
	MITEM	MN_RewindTape		; Rewind Tape
	MITEM	MN_TapeBar0		; ---
	MITEM	MN_NewRec		; Start New Recording
	MITEM	MN_SaveRec		; Save Recording...
	MICOUNT	NI_Tape

	MTITLE	MT_Tools		; Tools
	MITEM	MN_Cheat		; Cheats and Pokes...
	MITEM	MN_Debug		; Debugger...
	MITEM	MN_LockCheats		; Lock Cheats and Debugger
	MITEM	MN_ToolsBar0		; ---
	MITEM	MN_SaveScreen		; Save Screen as IFF...
	MITEM	MN_SaveSprites		; Save Sprites as IFF...
	MITEM	MN_ToolsBar1		; ---
	MITEM	MN_NewDisk		; New Blank Disk
	MSUB	MN_Fmt2DD		;   720K (2DD)
	MSUB	MN_Fmt1DD		;   360K (1DD)
	MSCOUNT	NS_NewDisk
	MICOUNT	NI_Tools
NM_Menus	EQU	_MM+1		; menus
