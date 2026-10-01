# openMSX: log VDP register changes with their scanline, for a short window.
# Needs ::out, ::from (emulated s), ::frames before this file.
set ::log [open "${::out}.vdp.txt" w]
set ::vbl 0.0
set ::active 0
set ::frame 0
set ::regs {}
for {set i 0} {$i < 47} {incr i} { lappend ::regs [vdpreg $i] }
proc ::vdp_diff {} {
    set line [expr {int(([machine_info time] - $::vbl) / 0.000064)}]
    for {set i 0} {$i < 47} {incr i} {
        set v [vdpreg $i]
        if {$v != [lindex $::regs $i]} {
            puts $::log [format "frame %d line %3d  R#%-2d %02X -> %02X" $::frame $line $i [lindex $::regs $i] $v]
            lset ::regs $i $v
        }
    }
}
debug probe set_bp VDP.IRQvertical {[debug probe read VDP.IRQvertical] == 1} {
    if {$::active} { ::vdp_diff; incr ::frame; puts $::log "--- vblank (frame $::frame)" }
    set ::vbl [machine_info time]
    if {$::active && $::frame >= $::frames} { close $::log; exit }
}
debug set_watchpoint write_io 0x99 {} { if {$::active} { ::vdp_diff } }
after time $::from {
    set ::active 1
    puts $::log "start t=[machine_info time]"
    for {set i 0} {$i < 28} {incr i} { puts -nonewline $::log [format "R#%d=%02X " $i [vdpreg $i]] }
    puts $::log ""
}
after time [expr {$::from + 5}] { catch {close $::log}; exit }
set throttle off

