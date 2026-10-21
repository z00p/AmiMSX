# openMSX (-script): Gradius III Legends, the POWER METER SELECT screen.
# The screen is AUTOEXEC.BAS's fighter selection (BLOAD "select.sr5",S, then BASIC LINE ,B
# boxes), shown at boot BEFORE the title, so Space presses from 14 s (g3l.keys) skip it.
# No keys until ::t0, then ::seq (key, delay before it in s); logs the VDP I/O
# (omsx_vdpio.tcl format, for tools/vdpio_decode.py), every VDP command as it starts
# (omsx_cmdlog.tcl format), screenshots every 0.5 s and a VRAM dump before each key.
# ::t0 < 0: start at the first non-black screen after -::t0 s. Output in ::d (mkdir it first).
# Usage: openmsx -machine AmiMSX_MSX2P_Disk_NoFM -diska <dsk> -script tools/omsx_g3l_pm.tcl
if {![info exists ::d]} { set ::d "C:/AMD/amimsx/build/g3pm/omsx" }
set ::out "$::d/pm"
set ::from 4
set ::frames 100000
source "C:/AMD/amimsx/tools/omsx_vdpio.tcl"
set ::clog [open "$::d/pm.cmd.txt" w]
set ::lg [open "$::d/pm_log.txt" w]
if {![info exists ::t0]} { set ::t0 24.0 }
set ::tlast $::t0
if {![info exists ::seq]} {
    set ::seq {DOWN 0 DOWN 3 DOWN 3 UP 3 UP 3 END 3}
}
array set ::K {SPACE 0x01 LEFT 0x10 UP 0x20 DOWN 0x40 RIGHT 0x80}
set ::si 0
set maxframeskip 0
proc ::tap {bit} { keymatrixdown 8 $bit; after time 0.1 [list keymatrixup 8 $bit] }
proc ::cmdlog {v} {
    set line [::line]
    set sx [expr {[vdpreg 32] + 256*[vdpreg 33]}]; set sy [expr {[vdpreg 34] + 256*[vdpreg 35]}]
    set dx [expr {[vdpreg 36] + 256*[vdpreg 37]}]; set dy [expr {[vdpreg 38] + 256*[vdpreg 39]}]
    set nx [expr {[vdpreg 40] + 256*[vdpreg 41]}]; set ny [expr {[vdpreg 42] + 256*[vdpreg 43]}]
    puts $::clog [format "t%.3f f%d l%3d cmd %02X  S(%d,%d) D(%d,%d) N(%d,%d) CLR %02X ARG %02X R2 %02X" [machine_info time] $::frame $line $v $sx $sy $dx $dy $nx $ny [vdpreg 44] [vdpreg 45] [vdpreg 2]]
}
debug probe set_bp VDP.commandExecuting {[debug probe read VDP.commandExecuting] == 1} {
    if {$::active} { ::cmdlog [vdpreg 46] }
}
proc ::poll {} {
    set t [machine_info time]
    set f [format "%s/pm_%06.2f.png" $::d $t]
    screenshot -raw $f
    set sz [file size $f]
    puts $::lg [format "poll %s frame %s PC %04X sz %d" $t $::frame [reg PC] $sz]; flush $::lg
    # ::t0 < 0: start the sequence at the first non-black screen after -::t0 s
    if {$::t0 < 0 && $t > -$::t0 && $sz > 1100} { set ::t0 $t; set ::tlast $t; puts $::lg "screen at $t" }
    if {$::t0 >= 0 && $t >= $::t0} {
        set key [lindex $::seq $::si]
        set dly [lindex $::seq [expr {$::si + 1}]]
        if {$t - $::tlast >= $dly} {
            save_debuggable VRAM [format "%s/vram_%02d_%s.bin" $::d $::si $key]
            if {$key eq "END"} { catch {close $::log}; close $::clog; close $::lg; exit }
            ::tap $::K($key); set ::tlast $t; incr ::si 2
            puts $::lg "$key at $t (frame $::frame)"; flush $::lg
            puts $::clog "=== $key at $t frame $::frame"; flush $::clog
        }
    }
    after time 0.5 ::poll
}
after time 4 ::poll
after time 600 { catch {close $::log}; close $::clog; close $::lg; exit }
set throttle off
