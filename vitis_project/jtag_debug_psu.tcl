catch {disconnect}
after 2000
connect
puts "INFO: targets=[targets]"
targets -set -filter {name == "PSU"}
configparams force-mem-accesses 1
puts "INFO: target=PSU"
puts "INFO: read FFCA5000"
puts [mrd -force 0xFFCA5000]
puts "INFO: read FFD80000"
puts [mrd -force 0xFFD80000]
puts "INFO: done"

