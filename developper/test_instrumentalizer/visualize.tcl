##########################################################################
# DDT - Dynamic Debugging for Tcl
##########################################################################
# visualize.tcl - Application to visualize the instrumentalized Tcl source files
# 
# This application visualizes the instrumentalized Tcl source files as 
# well as the disassembled information that is used by the instrumentalizer.
#
# Copyright (C) 2014 Andreas Drollinger
##########################################################################
# See the file "license.terms" for information on usage and redistribution
# of this file, and for a DISCLAIMER OF ALL WARRANTIES.
##########################################################################

package require Tk
source ../../ddt.tcl

destroy {*}[winfo children .]

pack [panedwindow .p] -expand yes -fill both
foreach w {f1 f2 f3} {
	.p add [frame .p.$w] -stretch always -sticky news
	grid [text .p.$w.t \
	       -wrap none \
			 -yscrollcommand ".p.$w.sy set" -xscrollcommand ".p.$w.sx set" -width 10] -row 0 -column 0 -sticky news
   grid [scrollbar .p.$w.sy -command ".p.$w.t yview" -orient vertical] -row 0 -column 1 -sticky ns
   grid [scrollbar .p.$w.sx -command ".p.$w.t xview" -orient horizontal] -row 1 -column 0 -sticky new
	grid columnconfigure .p.$w 0 -weight 1
	grid rowconfigure    .p.$w 0 -weight 1
}
wm geometry . 1500x800+0+0

.p.f1.t tag configure cmdstart -background red

proc Instrumentalize {} {
	set MainScript [.p.f1.t get 0.0 end]
	
	ddt::Init
	set SrcId [ddt::Instrumentalize "" $MainScript]
	
	.p.f2.t delete 0.0 end
	.p.f2.t insert 0.0 $ddt::SourceIScript($SrcId)

	.p.f3.t delete 0.0 end
	.p.f3.t insert 0.0 $ddt::DisassembleInfo($SrcId)
	
	foreach CommandPosN $ddt::CommandPosListN($SrcId) {
		.p.f1.t tag add cmdstart "0.0 + [lindex $CommandPosN 0] chars"
	}
}

proc LoadFile {} {
	set types { {"TCL Scripts" .tcl} {"All Files" *} }
	set FileName [tk_getOpenFile -initialdir [pwd] -filetypes $types]
	
	set f [open $FileName r]
	set MainScript [read $f]
	close $f
	
	regsub -all {\t} $MainScript {   } MainScript
	
	.p.f1.t delete 0.0 end
	.p.f1.t insert 0.0 $MainScript
	Instrumentalize
}

menu .menu -tearoff 0
. configure -menu .menu
   .menu add cascade -label File -menu .menu.file
      menu .menu.file -tearoff 0
      .menu.file add command -label "Load" -command LoadFile
      .menu.file add command -label "Instrumentalize currently loaded script" -command Instrumentalize
      .menu.file add command -label "Exit" -command exit
wm protocol . WM_DELETE_WINDOW exit