# openMSX: log raw VDP port writes (98 counted, 99 and 9B logged) with frame
# and line, for tools/vdpio_decode.py (rebuilds registers, commands, modes).
# Needs ::out, ::from (emulated s), ::frames before this file.
set ::log [open "${::out}.vdpio.txt" w]
set ::vbl 0.0
set ::active 0
set ::frame 0
set ::n98 0
proc ::line {} { return [expr {int(([machine_info time] - $::vbl) / 0.000064)}] }
debug probe set_bp VDP.IRQvertical {[debug probe read VDP.IRQvertical] == 1} {
    if {$::active} { puts $::log "V $::frame $::n98"; incr ::frame; set ::n98 0 }
    set ::vbl [machine_info time]
    if {$::active && $::frame >= $::frames} { close $::log; exit }
}
debug set_watchpoint write_io 0x99 {} { if {$::active} { puts $::log [format "9 %d %d %02X" $::frame [::line] $::wp_last_value] } }
debug set_watchpoint write_io 0x9B {} { if {$::active} { puts $::log [format "B %d %d %02X" $::frame [::line] $::wp_last_value] } }
debug set_watchpoint read_io 0x99 {} { if {$::active} { puts $::log [format "r %d %d 00" $::frame [::line]] } }
debug set_watchpoint write_io 0x98 {} { if {$::active} { incr ::n98 } }
after time $::from {
    set ::active 1
    set r {}
    for {set i 0} {$i < 47} {incr i} { lappend r [format %02X [vdpreg $i]] }
    puts $::log "R $r"
}
set throttle off
