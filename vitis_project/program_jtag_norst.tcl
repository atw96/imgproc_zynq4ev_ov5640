# Alias of program_jtag.tcl — same canonical HOT sequence.
# Kept so burn_silent.bat / historical norst callers stay valid.
# Sequence: psu_init → fpga → halt A53 (bootloop+clear-registers) → dow
source [file join [file dirname [file normalize [info script]]] program_jtag.tcl]
