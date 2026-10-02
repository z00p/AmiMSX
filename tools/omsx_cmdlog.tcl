# openMSX: log every VDP command as it starts (VDP.commandExecuting) with R#32-46,
# the frame and line. Needs ::out, ::from (emulated s), ::frames.
set ::log [open "${::out}.cmd.txt" w]
set ::vbl 0.0
set ::active 0
set ::frame 0
proc ::cmdlog {v} {
    set line [expr {int(([machine_info time] - $::vbl) / 0.000064)}]
    set sx [expr {[vdpreg 32] + 256*[vdpreg 33]}]; set sy [expr {[vdpreg 34] + 256*[vdpreg 35]}]
    set dx [expr {[vdpreg 36] + 256*[vdpreg 37]}]; set dy [expr {[vdpreg 38] + 256*[vdpreg 39]}]
    set nx [expr {[vdpreg 40] + 256*[vdpreg 41]}]; set ny [expr {[vdpreg 42] + 256*[vdpreg 43]}]
    puts $::log [format "f%d l%3d cmd %02X  S(%d,%d) D(%d,%d) N(%d,%d) CLR %02X ARG %02X" $::frame $line $v $sx $sy $dx $dy $nx $ny [vdpreg 44] [vdpreg 45]]
}
debug probe set_bp VDP.IRQvertical {[debug probe read VDP.IRQvertical] == 1} {
    if {$::active} { incr ::frame; puts $::log "--- vblank (frame $::frame) R#2=[format %02X [vdpreg 2]]" }
    set ::vbl [machine_info time]
    if {$::active && $::frame >= $::frames} { close $::log; exit }
}
debug probe set_bp VDP.commandExecuting {[debug probe read VDP.commandExecuting] == 1} {
    if {$::active} { ::cmdlog [vdpreg 46] }
}
after time $::from { set ::active 1; puts $::log "start t=[machine_info time]" }
after time [expr {$::from + 5}] { catch {close $::log}; exit }
set throttle off
