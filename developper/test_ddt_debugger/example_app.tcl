set InfoScript [info script]
puts script:$InfoScript

source example_src.tcl

set g1 hello
array set g2 {a 1 b 2}

package require Tk

proc B {} {
	puts Begin:B([info script])
	global g1 g2
	C
	puts End:B
}

package require tepam

B

proc A {} {
	puts Begin:A
	global tcl_platform tcl_patchLevel
	for {set k 0} {$k<3} {incr k} {
		if {$k<2} {
			B; C
		} else {
			x
		}
		if {$k==1} B
	}
	puts End:A
}

A
#package require Tk
