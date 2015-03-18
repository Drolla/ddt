if {![package vsatisfies [package provide Tcl] 8.5]} {return}
package ifneeded ddt 0.1.0 [list source [file join $dir ddt.tcl]]
