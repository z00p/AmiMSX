# openMSX: log resets (breakpoint at $0000) and take screenshots at emulated times.
# Set ::out (output prefix) and ::times before sourcing, e.g. via -command.
set ::log [open "${::out}.log" w]
debug set_bp 0x0000 {} {
    puts $::log [format "reset-bp t=%.2fs sp=%04X" [machine_info time] [reg sp]]
    flush $::log
}
foreach t $::times {
    after time $t "screenshot ${::out}_${t}s.png"
}
after time [expr {[lindex $::times end] + 1}] {close $::log; exit}
set throttle off
