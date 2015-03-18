set v 123
puts $v
set v [expr $v*3]
set v [expr {$v*3}]

set x 123; set y 123
set z {1 2
	5 6 7 9
	0 10
}

puts [lindex $z end]; puts [lrange $z 0 5]

return $v

