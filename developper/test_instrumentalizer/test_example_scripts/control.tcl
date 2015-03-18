set v 123

while {$v<200} {
	incr v
	puts $v
}

while {$v<10} {incr v}

while {$v<10} {
	incr v}

for {set v 123} {$v<200} {incr v} {
	puts $v
}

foreach v {1 2 4 8 10} {
	puts $v
}

if {v>100} {
	puts Bigger
} else {
	puts Smaller
}

switch -- $v {
	99 {puts Smaller}
	100 {puts Equal}
	101 {puts Bigger}
	- {
		puts Nothing found
		return
	}
}

