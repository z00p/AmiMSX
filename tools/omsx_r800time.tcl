# openMSX (Panasonic_FS-A1GT or _FS-A1ST): run the code of tools/make_r800time.py
# from RAM and log every instruction's cost. Needs ::BIN (code file), ::END
# (the end address from make_r800time.py) and ::OUT (log file) set before this
# file. At the BASIC prompt (40 s after power on, no disk) the code is written
# to 8000h and run once per CPU mode, chosen through S1990 register 6: 60h Z80,
# 00h R800 DRAM mode, 40h R800 ROM mode. Log lines: "== mode" then
# "pc cycles" (cycles of the CPU's clock before the instruction at pc: the
# previous instruction's cost; R800 cycles at 7.16 MHz, Z80 T-states at
# 3.58 MHz).
set renderer none
set throttle off
set ::F [open $::OUT w]
set fh [open $::BIN rb]; set ::CODE [read $fh]; close $fh
set ::last 0
proc ::rec {} {
    set t [machine_info time]
    puts $::F [format "%04X %d" [reg pc] [expr {round(($t - $::last) * $::HZ)}]]
    set ::last $t
    if {[reg pc] == $::END} { debug remove_condition $::c; set ::busy 0 }
}
proc ::run {mode v hz} {
    debug write "S1990 regs" 6 $v
    after time 0.05 [list ::go $mode $hz]
}
proc ::go {mode hz} {
    debug write_block memory 0x8000 $::CODE
    set ::HZ $hz
    puts $::F "== $mode [get_active_cpu]"
    reg pc 0x8000
    set ::last [machine_info time]
    set ::c [debug set_condition "\[reg pc\] >= 0x8000 && \[reg pc\] <= $::END" ::rec]
}
after time 40 { ::run Z80 0x60 3579545.0 }
after time 42 { ::run R800DRAM 0x00 7159090.0 }
after time 44 { ::run R800ROM 0x40 7159090.0 }
after time 46 { close $::F; exit }
