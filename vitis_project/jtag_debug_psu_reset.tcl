catch {disconnect}
after 2000
connect
puts "INFO: targets=[targets]"
catch {targets -set -filter {name =~ "Cortex-A53 #0"}}
catch {stop -timeout 3000}
targets -set -filter {name == "PS TAP"}
rst -system
after 5000
if {[catch {targets -set -filter {name == "PL"}} err]} { puts "ERROR: select PL $err"; exit 1 }
if {[catch {fpga -file zynq_imgproc_platform hw imgproc_top_ov5640.bit} err]} { puts "ERROR: fpga $err" }
if {[catch {targets -set -filter {name == "PSU"}} err]} { puts "ERROR: select PSU $err"; exit 1 }
configparams force-mem-accesses 1
puts "INFO: mrd FFCA5000"
puts [mrd -force 0xFFCA5000]
puts "INFO: mrd FFD80000"
puts [mrd -force 0xFFD80000]
puts "INFO: done"
