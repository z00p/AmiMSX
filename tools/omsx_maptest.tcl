# openMSX: run the mapping test cartridge until its end loop, dump the 128 KB VRAM.
# Needs ::out (dump file) and ::endpc (end loop address).
debug set_bp $::endpc {} {
    set f [open $::out w]
    fconfigure $f -translation binary
    puts -nonewline $f [debug read_block {physical VRAM} 0 0x20000]
    close $f
    exit
}
after time 60 { exit }
set throttle off
