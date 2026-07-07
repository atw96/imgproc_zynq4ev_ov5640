catch {disconnect}
after 1000
connect
if {[targets] eq ""} {
    puts "FAIL: no JTAG targets (check power and cable)"
    exit 1
}
puts "PASS: JTAG targets found:"
puts [targets]
catch {disconnect}
exit 0
