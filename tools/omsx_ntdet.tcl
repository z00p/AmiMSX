# openMSX: every OUT (98h) as "W <period> <line from the VBlank IRQ> <VRAM address> <value> <PC>",
# "V <period>" at each VBlank IRQ and "NT0 <hex>" (the name table at 3800h when the log starts).
# Needs ::out ::from ::frames ::spacefrom ::spaceto (Space taps every 2 s); ::shots 1 also takes a
# screenshot at each VBlank (run with throttle on for a picture per frame). Read by tools/n2_tearmodel.py.
set ::log [open "${::out}.ntdet.txt" w]
set ::active 0
set ::frame 0
set ::vbl 0.0
debug set_watchpoint write_io 0x98 {} {
    if {$::active} {
        set p [expr {[debug read {VRAM pointer} 0] | ([debug read {VRAM pointer} 1] << 8)}]
        puts $::log [format "W %d %d %04X %02X %04X" $::frame [expr {int(([machine_info time] - $::vbl) / 0.0000635)}] [expr {($p - 1) & 0x3FFF}] $::wp_last_value [reg PC]]
    }
}
proc ::onvbl {} {
    if {$::active} {
        puts $::log "V $::frame"
        if {[info exists ::shots] && $::shots} { screenshot [format "%s_%04d.png" $::out $::frame] }
        incr ::frame
        if {$::frame >= $::frames} { close $::log; exit }
    }
    set ::vbl [machine_info time]
}
debug probe set_bp VDP.IRQvertical {[debug probe read VDP.IRQvertical] == 1} {
    if {[catch ::onvbl err]} { puts $::log "ERR $err"; flush $::log }
}
proc ::tap {} { keymatrixdown 8 0x01; after time 0.1 { keymatrixup 8 0x01 } }
for {set t $::spacefrom} {$t <= $::spaceto} {incr t 2} { after time $t ::tap }
after time $::from {
    set ::active 1
    set b [debug read_block VRAM 0x3800 0x300]
    binary scan $b H* hx
    puts $::log "NT0 $hx"
}
set maxframeskip 0
set throttle off
