# openMSX: record which VDP features a title uses (for the regression coverage
# table). Needs ::out (result file) and ::secs (run length) set before this
# file; key-script lines (tools/keyscript.py --tcl, without its exit) may come
# before it. Writes one line of Tcl-dict text to ::out.
# Nothing before ::from seconds counts (C-BIOS draws its boot logo in SCREEN 5
# with VDP commands).
if {![info exists ::from]} { set ::from 5.0 }
proc ::on {} { expr {[machine_info time] > $::from} }
set ::frame 0
set ::vbl 0.0
set ::modes [dict create]
set ::midregs [dict create]
set ::vblregs [dict create]
set ::cmds [dict create]
set ::palmid 0
set ::palvbl 0
set ::ie1 0
set ::sprframes 0
set ::magframes 0
set ::regs {}
for {set i 0} {$i < 47} {incr i} { lappend ::regs [vdpreg $i] }
proc ::mode {} {
    set r0 [vdpreg 0]; set r1 [vdpreg 1]
    set m [expr {(($r0 >> 1) & 7) | ($r1 & 0x18)}]
    set names {0 S1 1 S2 2 S4 3 S5 4 S6 5 S7 7 S8 8 S3 16 S0 18 S0w80}
    if {[dict exists $names $m]} { return [dict get $names $m] }
    return M$m
}
proc ::dline {} {
    # Display line now (approx.): lines since the VBlank IRQ minus the lines
    # between the end of the display and the start of the next one.
    set l [expr {int(([machine_info time] - $::vbl) / 0.000064)}]
    set nd [expr {([vdpreg 9] & 0x80) ? 212 : 192}]
    return [expr {$l - (313 - $nd)}]
}
proc ::regdiff {} {
    set d [::dline]
    for {set i 0} {$i < 47} {incr i} {
        set v [vdpreg $i]
        if {$v != [lindex $::regs $i]} {
            if {[::on]} {
                if {$d > 2 && $d < 190} { dict incr ::midregs $i } else { dict incr ::vblregs $i }
                if {$i == 46} { dict incr ::cmds [format %X [expr {$v >> 4}]] }
                if {$i == 0 && ($v & 0x10)} { set ::ie1 1 }
            }
            lset ::regs $i $v
        }
    }
}
debug set_watchpoint write_io 0x99 {} { ::regdiff }
debug set_watchpoint write_io 0x9A {} {
    if {![::on]} { return }
    set d [::dline]
    if {$d > 2 && $d < 190} { incr ::palmid } else { incr ::palvbl }
}
debug probe set_bp VDP.IRQvertical {[debug probe read VDP.IRQvertical] == 1} {
    ::regdiff
    set ::vbl [machine_info time]
    if {![::on]} { return }
    incr ::frame
    dict incr ::modes [::mode]
    if {!([vdpreg 8] & 0x02) && ([vdpreg 1] & 0x40)} {
        incr ::sprframes
        if {[vdpreg 1] & 0x01} { incr ::magframes }
    }
    if {[vdpreg 0] & 0x10} { set ::ie1 1 }
    set ::vbl [machine_info time]
}
after time $::secs {
    set f [open $::out w]
    puts $f [list frames $::frame modes $::modes ie1 $::ie1 midregs $::midregs vblregs $::vblregs cmds $::cmds palmid $::palmid palvbl $::palvbl sprframes $::sprframes magframes $::magframes]
    close $f
    exit
}
set throttle off
