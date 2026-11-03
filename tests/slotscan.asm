; Slot scan test cartridge: prints EXPTBL, then for every slot (and sub-slot of
; an expanded slot) what a game sees through RDSLT at 4018h and 6018h, where
; the MSX-MUSIC ID (APRLOPLL) and FM-PAC ID (PAC2OPLL) live.
; sjasmplus --raw=run/Roms/slotscan.rom tests/slotscan.asm

RDSLT   equ 000Ch
CHGMOD  equ 005Fh
CHPUT   equ 00A2h
LINL40  equ 0F3AEh
EXPTBL  equ 0FCC1h
slot    equ 0E000h
sub     equ 0E001h
count   equ 0E002h

        org 4000h
        db "AB"
        dw start
        ds 12,0

start:  ld a,40
        ld (LINL40),a
        xor a
        call CHGMOD
        ld hl,tExp
        call puts
        ld hl,EXPTBL
        ld b,4
.exp:   ld a,(hl)
        call hex
        ld a,' '
        call CHPUT
        inc hl
        djnz .exp
        call crlf

        xor a
        ld (slot),a
.slots: ld a,(slot)
        ld e,a
        ld d,0
        ld hl,EXPTBL
        add hl,de
        ld a,(hl)
        and 80h
        jr nz,.subs
        ld a,(slot)
        call row
        jr .next
.subs:  xor a
        ld (sub),a
.subl:  ld a,(sub)
        add a,a
        add a,a
        ld e,a
        ld a,(slot)
        or e
        or 80h
        call row
        ld a,(sub)
        inc a
        ld (sub),a
        cp 4
        jr nz,.subl
.next:  ld a,(slot)
        inc a
        ld (slot),a
        cp 4
        jr nz,.slots
        ei
.hang:  jr .hang

; A = slot id: prints id, 8 bytes at 4018h, 8 bytes at 6018h
row:    push af
        call hex
        ld a,' '
        call CHPUT
        pop af
        push af
        ld hl,4018h
        call eight
        ld a,' '
        call CHPUT
        pop af
        ld hl,6018h
        call eight
crlf:   ld a,13
        call CHPUT
        ld a,10
        jp CHPUT

eight:  ld c,a
        ld a,8
        ld (count),a
.l:     ld a,c
        push bc
        push hl
        call RDSLT
        ei
        pop hl
        pop bc
        cp 32
        jr c,.dot
        cp 127
        jr c,.ok
.dot:   ld a,'.'
.ok:    call CHPUT
        inc hl
        ld a,(count)
        dec a
        ld (count),a
        jr nz,.l
        ret

hex:    push af
        rrca
        rrca
        rrca
        rrca
        call .n
        pop af
.n:     and 15
        add a,'0'
        cp '9'+1
        jr c,.p
        add a,7
.p:     jp CHPUT

puts:   ld a,(hl)
        or a
        ret z
        call CHPUT
        inc hl
        jr puts

tExp:   db "EXPTBL ",0

        ds 8000h-$,0FFh
