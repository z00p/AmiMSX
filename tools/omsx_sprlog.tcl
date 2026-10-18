# openMSX: per-frame sprite attribute log, for sprite-position questions
# (Manbow 2's ship, Lotus F3's car, Bombaman's characters). Needs ::out,
# ::from (emulated s), ::frames, ::nspr before this file.
#
# Each frame (at the vertical interrupt) one line:
#   F <frame> R18=<r18> R23=<r23> R5=<r5> R11=<r11> R2=<r2> mode=<1|2>
#     cmds=<9B writes> attw=<writes into the attribute table> attl=<first..last rel line>
#     s<i>:Y,X,P[,C] ...       (sprite i of the first ::nspr)
# and for each port-99 write that changes R#18/R#23/R#5/R#2/R#8:
#   W <frame> <rel line> R#<n> <old> -> <new>
# "rel line" counts 64 us lines from the vertical interrupt (the end of the
# active area): active line a = rel - (313-212) at 50 Hz, rel - (262-212) at 60.
set ::log [open "${::out}.spr.txt" w]
set ::vbl 0.0
set ::active 0
set ::frame 0
set ::ncmd 0
set ::attw 0
set ::attl0 -1
set ::attl1 -1
set ::attbase -1
set ::watch {}
array set ::regs {}
foreach i {2 5 8 11 18 23} { set ::regs($i) [vdpreg $i] }
proc ::line {} { return [expr {int(([machine_info time] - $::vbl) / 0.000064)}] }
proc ::mode2 {} {
    # Sprite mode 2 in SCREEN 4-8 (R#0 M3-M5 bits with R#1 M1/M2 clear).
    set r0 [vdpreg 0]
    set r1 [vdpreg 1]
    if {($r1 & 0x18) != 0} { return 0 }
    set m [expr {($r0 >> 1) & 7}]
    return [expr {$m >= 2 ? 1 : 0}]
}
proc ::attbase {} {
    set r5 [vdpreg 5]
    set r11 [vdpreg 11]
    if {[::mode2]} { return [expr {(($r11 & 3) << 15) | (($r5 & 0xFC) << 7)}] }
    return [expr {(($r11 & 3) << 15) | ($r5 << 7)}]
}
proc ::setwatch {} {
    set b [::attbase]
    if {$b == $::attbase} return
    foreach w $::watch { debug remove_watchpoint $w }
    set ::watch {}
    set ::attbase $b
    set lo [expr {[::mode2] ? $b - 512 : $b}]
    set hi [expr {$b + 128 - 1}]
    lappend ::watch [debug set_watchpoint write_mem [list $lo $hi] {} {
        if {$::active} {
            incr ::attw
            set l [::line]
            if {$::attl0 < 0} { set ::attl0 $l }
            set ::attl1 $l
        }
    }]
}
proc ::reg_diff {} {
    foreach i {2 5 8 11 18 23} {
        set v [vdpreg $i]
        if {$v != $::regs($i)} {
            puts $::log [format "W %d %3d R#%-2d %02X -> %02X" $::frame [::line] $i $::regs($i) $v]
            set ::regs($i) $v
            if {$i == 5 || $i == 11} { ::setwatch }
        }
    }
}
set ::ntlast ""
proc ::ntchanged {} {
    # Name-table bytes changed since the last frame (mode 1 modes: 768 bytes at R#2).
    set nt [expr {([vdpreg 2] & 0x7F) << 10}]
    set blk [debug read_block VRAM $nt 768]
    set n 0
    if {$::ntlast ne ""} {
        binary scan $blk cu* a
        binary scan $::ntlast cu* b
        foreach x $a y $b { if {$x != $y} { incr n } }
    }
    set ::ntlast $blk
    return $n
}
proc ::frame_line {} {
    set b [::attbase]
    set m2 [::mode2]
    set s ""
    set blk [debug read_block VRAM $b [expr {4 * $::nspr}]]
    binary scan $blk cu* a
    if {$m2} {
        set cblk [debug read_block VRAM [expr {$b - 512}] [expr {16 * $::nspr}]]
        binary scan $cblk cu* c
    }
    for {set i 0} {$i < $::nspr} {incr i} {
        set y [lindex $a [expr {4*$i}]]
        set x [lindex $a [expr {4*$i+1}]]
        set p [lindex $a [expr {4*$i+2}]]
        if {$m2} {
            append s [format " s%d:%d,%d,%d,%02X" $i $y $x $p [lindex $c [expr {16*$i}]]]
        } else {
            append s [format " s%d:%d,%d,%d,%02X" $i $y $x $p [lindex $a [expr {4*$i+3}]]]
        }
    }
    set nt [expr {$m2 ? -1 : [::ntchanged]}]
    puts $::log [format "F %d R18=%02X R23=%02X R5=%02X R11=%02X R2=%02X R8=%02X mode=%d cmds=%d nt=%d%s" \
        $::frame [vdpreg 18] [vdpreg 23] [vdpreg 5] [vdpreg 11] [vdpreg 2] [vdpreg 8] [expr {$m2 ? 2 : 1}] \
        $::ncmd $nt $s]
    if {$::frame % 50 == 0} {
        set r {}
        for {set i 0} {$i < 24} {incr i} { lappend r [format "R#%d=%02X" $i [vdpreg $i]] }
        puts $::log "regs $r n98=$::n98"
    }
    set ::n98 0
}
debug probe set_bp VDP.IRQvertical {[debug probe read VDP.IRQvertical] == 1} {
    if {$::active} {
        ::reg_diff
        ::frame_line
        incr ::frame
        set ::ncmd 0
        set ::attw 0
        set ::attl0 -1
        set ::attl1 -1
    }
    set ::vbl [machine_info time]
    if {$::active && $::frame >= $::frames} { close $::log; exit }
}
debug set_watchpoint write_io 0x99 {} { if {$::active} { ::reg_diff } }
debug set_watchpoint write_io 0x9B {} { if {$::active} { incr ::ncmd } }
set ::n98 0
debug set_watchpoint write_io 0x98 {} { if {$::active} { incr ::n98 } }
after time $::from {
    set ::active 1
    foreach i {2 5 8 11 18 23} { set ::regs($i) [vdpreg $i] }
    ::setwatch
    set r {}
    for {set i 0} {$i < 24} {incr i} { lappend r [format "R#%d=%02X" $i [vdpreg $i]] }
    puts $::log "start t=[machine_info time] $r"
}
set throttle off
