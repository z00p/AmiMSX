# openMSX: run the tools/make_hrtest.py cartridge and save RAM 8000h-F0FFh to
# ::OUT once the "HRDONE" marker is there (checked every second, up to 60 s).
set renderer none
set throttle off
proc ::hr_check {n} {
    if {[debug read_block memory 0xF008 6] eq "HRDONE" || $n >= 60} {
        set f [open $::OUT wb]
        puts -nonewline $f [debug read_block memory 0x8000 0x7100]
        close $f
        exit
    }
    after time 1 [list ::hr_check [expr {$n + 1}]]
}
after time 5 [list ::hr_check 5]
