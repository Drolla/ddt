proc p1 {} {
	puts Hello
}

	proc p2 {args} {
		foreach a $args {
			puts r:$a
		}
		puts Completed
	}

namespace eval ::ns {
	variable v1 123

	proc p3 {args} {
		puts $args
	}
	
	p3
}
	
proc ::ns::p4 {args} {
	puts $args
}
	
p1
p2 1 10 100