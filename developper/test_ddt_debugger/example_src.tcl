set InfoScript [info script]
puts script:$InfoScript

proc C {} {
	set var 123
	array set arr {1 aa 2 bb 3 cc}
	puts Begin:C
	puts Hello
	puts End:C
}

puts "example_src.tcl is now sourced"