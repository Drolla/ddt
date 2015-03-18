proc incr_v {} {incr ::v}
set v [expr {123}]

if {$v==156} incr_v
if {$v==1} B
if {
	$v==1} B

while {$v<10} {incr v}
while {$v<10} {  incr v  }
while {$v<20} "incr v"
while {$v<40} incr_v
while {$v<40} \
	incr_v
while {$v<40} "incr_v"
while {$v<40} "\
	incr_v"

for {set v 123} {$v<200} {incr v} {
	if {$v==154} break
	if {$v==156} incr_v
}

for {set v 123} {$v<100} {incr v} {puts $v}
for "set v 123" {$v<100} "incr v" "puts $v"

foreach v {1 2 4 8 10} {puts $v}
foreach v "1 2 4 8 10" "puts $v"
foreach v "1 2 4 8 10" incr_v

if {$v>100} {puts Bigger}
if "$v>100" {puts Bigger}

set PName MyProc
set Args {a b c}
set Body {puts "$a, $b, $c"}

proc MyProc {a b c} {puts "$a, $b, $c"}
proc [set PName] [set Args] {puts "$a, $b, $c"}
proc MyProc {a b c} $Body

switch -- $v {
	99 incr_v
	- return
}

