from pathlib import Path
pj = Path(r"d:/Project/Vivado/zynq4ev/imgproc_mpsoc/vitis_project/program_jtag.tcl")
t = pj.read_text(encoding="utf-8")
old = "proc step {msg} { puts $msg; flush stdout }"
new = """proc step {msg} {
    puts [format {%s %s} [clock format [clock seconds] -format {%H:%M:%S}] $msg]
    flush stdout
}"""
if old in t:
    pj.write_text(t.replace(old, new), encoding="utf-8")
    print("program_jtag.tcl ok")
else:
    print("program_jtag.tcl skip")
