# openMSX: report which frames change a VRAM area, with per-frame I/O counts
# and the VDP command registers. Needs ::out ::from ::frames ::addr ::len.
set ::log [open "${::out}.vram.txt" w]
set ::active 0
set ::frame 0
array set ::cnt {98 0 99 0 9A 0 9B 0}
set ::last ""
foreach p {98 99 9A 9B} {
    debug set_watchpoint write_io 0x$p {} "if {\$::active} { incr ::cnt($p) }"
}
debug probe set_bp VDP.IRQvertical {[debug probe read VDP.IRQvertical] == 1} {
    if {!$::active} return
    set blk [debug read_block VRAM $::addr $::len]
    if {$blk ne $::last} {
        set regs ""
        foreach r {0 1 2 8 9 14 32 33 34 35 36 37 38 39 40 41 42 43 44 45 46} { append regs [format "R%d=%02X " $r [vdpreg $r]] }
        puts $::log [format "frame %4d t=%.2f CHANGED  out98=%d out99=%d out9A=%d out9B=%d  %s" $::frame [machine_info time] $::cnt(98) $::cnt(99) $::cnt(9A) $::cnt(9B) $regs]
        set ::last $blk
    }
    array set ::cnt {98 0 99 0 9A 0 9B 0}
    incr ::frame
    if {$::frame >= $::frames} { close $::log; exit }
}
after time $::from { set ::active 1; set ::last [debug read_block VRAM $::addr $::len] }
set throttle off

