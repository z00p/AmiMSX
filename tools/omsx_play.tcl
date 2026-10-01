# openMSX: press Space (keyboard row 8 bit 0) on a schedule and take screenshots.
# Needs ::out ::shots ::spacefrom ::spaceto before this file.
proc ::tap_space {} {
    keymatrixdown 8 0x01
    after time 0.1 { keymatrixup 8 0x01 }
}
for {set t $::spacefrom} {$t <= $::spaceto} {incr t 2} { after time $t ::tap_space }
foreach t $::shots { after time $t "screenshot ${::out}_${t}s.png" }
after time [expr {[lindex $::shots end] + 1}] exit
set throttle off
