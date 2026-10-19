# openMSX (-script): Gradius III Legends, explore the title menu. Output (screenshots,
# pm2_log.txt, pm2.vdpio.txt for tools/vdpio_decode.py) in build/g3l_menu: mkdir it first.
# Usage: openmsx -machine AmiMSX_MSX2P_Disk_NoFM -diska run/Disks/020_GradiusIIILegends.dsk
#        -script tools/omsx_g3l_menu.tcl
# The game seeds from the RTC, so the title's time varies run to run (81-86 s, or much later):
# the script waits for it instead of using fixed times. Edit ::seq for other key sequences.
# Gradius III Legends: explore the title menu. Space every 2 s until the title shows (raw
# screenshot > 6 KB), then a key sequence with 1.5 s between keys, screenshots every 0.5 s,
# and the VDP I/O logged from the title on (omsx_vdpio.tcl, activated here).
set ::d "C:/AMD/amimsx/build/g3l_menu"
set ::out "$::d/pm2"
set ::from 100000
set ::frames 100000
source "C:/AMD/amimsx/tools/omsx_vdpio.tcl"
set ::lg [open "$::d/pm2_log.txt" w]
set ::phase 0
set ::tlast 0.0
# key, delay before it (s)
set ::seq {DOWN 1.5 DOWN 1.5 UP 1.5 RIGHT 1.5 LEFT 1.5 SPACE 1.5 DOWN 1.5 UP 1.5 RIGHT 1.5 LEFT 1.5 SPACE 1.5 DOWN 1.5 UP 1.5 RIGHT 1.5 LEFT 1.5 SPACE 1.5 SPACE 3 END 4}
array set ::K {SPACE 0x01 LEFT 0x10 UP 0x20 DOWN 0x40 RIGHT 0x80}
set ::si 0
set maxframeskip 0
proc ::tap {bit} { keymatrixdown 8 $bit; after time 0.1 [list keymatrixup 8 $bit] }
proc ::poll {} {
    set t [machine_info time]
    set f [format "%s/pm2_%06.2f.png" $::d $t]
    screenshot -raw $f
    set sz [file size $f]
    puts $::lg "poll $t sz $sz phase $::phase"; flush $::lg
    if {$::phase == 0} {
        if {$sz > 6000} {
            set ::phase 1; set ::tlast $t
            set ::active 1
            set r {}
            for {set i 0} {$i < 47} {incr i} { lappend r [format %02X [vdpreg $i]] }
            puts $::log "R $r"
            puts $::lg "title at $t"
        } elseif {$t - $::tlast >= 2.0} {
            ::tap 0x01; set ::tlast $t
        }
        if {$sz <= 6000} { file delete $f }
    } else {
        set key [lindex $::seq $::si]
        set dly [lindex $::seq [expr {$::si + 1}]]
        if {$t - $::tlast >= $dly} {
            if {$key eq "END"} { catch {close $::log}; close $::lg; exit }
            ::tap $::K($key); set ::tlast $t; incr ::si 2
            puts $::lg "$key at $t (frame $::frame)"; flush $::lg
        }
    }
    after time 0.5 ::poll
}
after time 14 ::poll
after time 300 { catch {close $::log}; close $::lg; exit }
set throttle off
