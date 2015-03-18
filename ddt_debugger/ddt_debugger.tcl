##########################################################################
# DDT - Dynamic Debugging for Tcl
##########################################################################
# sdebugger.tcl - Simple Debugger based on the DDT package
# 
# Simple debugger that demonstrates the usage of the DDT package.
#
# Copyright (C) 2014 Andreas Drollinger
##########################################################################
# See the file "license.terms" for information on usage and redistribution
# of this file, and for a DISCLAIMER OF ALL WARRANTIES.
##########################################################################


#### Load the DDT library, initialize some main variables ####

	package require Tk
	source ../ddt.tcl
	
	# Variables
	set DebugPwd [pwd]
	array set DisplayArray {}
	set WatchList {}
	set CurrentFileName ""
	
#### Tool configuration ####

	proc ToolConfiguration {RW} {
		lappend ParList {"Colors"} \
			{::Config(VarRowBG,0) gray95 "Variable display, even rows"} \
			{::Config(VarRowBG,1) gray90 "Variable display, odd rows"}
		lappend ParList {"Geometry"} \
			{::Config(Geometry,main) {1024x786+0+0} "Main Window's geometry"} \
			{::Config(MainPan,sash_position) {000 1} "Left/right side organization"}
		lappend ParList {"Others"} \
			{::Config(Path,TkCon) {} "Full qualified path of TkCon"}
		lappend ParList {"Ddt configuration"} \
			{::ddt::Config(-Mode) enable "Enable debugging"} \
			{::ddt::Config(-UseSI) 1 "Use slave interpreter"} \
			{::ddt::Config(-InitVars) "" "Initialization variables"} \
			{::ddt::Config(-InitScript) "" "Initialization script"}
	
		# Define the configuration file
		set ConfigFile ""
		foreach n {USERPROFILE HOME} {
			if {$ConfigFile=="" && [info exists ::env($n)]} {
				if {$::tcl_platform(platform)=={windows}} {
					set ConfigFile [file join $::env($n) TclDebug.config]
				} else {
					set ConfigFile [file join $::env($n) .TclDebug_config]
				}
			}
		}
	
		# Read the configuration file
		if {$RW=="R"} {
			# Define the default values of the debugger variables
			foreach r $ParList {
				set [subst [lindex $r 0]] [lindex $r 1]
			}
			# Try now to source the configuration file
			if {[file exists $ConfigFile]} {
				if {[catch {source $ConfigFile}]} {
					puts stderr "\nERROR: Configuration file $ConfigFile is corrupted!\n  $::errorInfo\n"
				}
			}
		}
	
		# Write the configuration file
		if {$RW=="W"} {
			catch {set ::Config(MainPan,sash_position) [.p sash coord 0]}
			catch {set ::Config(Geometry,main) [wm geometry .]}
	
			# Open the configuration file and write all parameters
			set f [open $ConfigFile w]
			puts $f "# TclDebug configuration file - [clock format [clock seconds]]"
			foreach r $ParList {
				if {[llength $r]==1} {
					puts $f "\n######## [lindex $r 0] ########"
				} else {
					puts $f "\n\t\# [lindex $r 2]:"
					puts $f "\tset [subst [lindex $r 0]] {[set [subst [lindex $r 0]]]}"
				}
			}
			close $f
		}
	}
	
	# Load the tool configuration. Make sure the tool configuration is stored when
	# the debugger is stopped.
	
	ToolConfiguration R
	
	proc Exit {} {
		ToolConfiguration W
		exit
	}

	
#### Debug commands ####

	proc Run {} {
		if {[::ddt::GetExecState]==""} {
			set Msg [::ddt::Run $::CurrentFileName]
		} else {
			set Msg [::ddt::Cont]
		}
		#if {$Msg!=""} {
		#	puts ErrTxt:$Msg
		#}
	}
	
	proc Step {} {
		::ddt::Step
	}
	
	proc Stop {} {
		.p.src.t tag remove error 0.0 end
		.p.src.t tag remove current 0.0 end
		::ddt::Stop
	}
	
	proc Refresh {} {
		::ddt::Refresh
	}
	
	proc AddWatch {} {
		catch {destroy .addwatch}
		toplevel .addwatch
		grid [label .addwatch.txt1 -text "Specify the watch expression"] -row 0 -column 0 -columnspan 2 -sticky ew
		grid [entry .addwatch.entry] -row 1 -column 0 -columnspan 2 -sticky ew
		grid [button .addwatch.ok -text OK -command "set ::CtrlAddWatch OK"] -row 2 -column 0 -sticky ew
		grid [button .addwatch.cancel -text Cancel -command "set ::CtrlAddWatch Cancel"] -row 2 -column 1 -sticky ew
		grid columnconfigure .addwatch 0 -weight 1
		grid columnconfigure .addwatch 1 -weight 1
		focus .addwatch.entry
		bind .addwatch <Key-Return> "set ::CtrlAddWatch OK"
		bind .addwatch <Key-Escape> "set ::CtrlAddWatch Cancel"
		set ::CtrlAddWatch ""
	
		vwait ::CtrlAddWatch
		
		if {$::CtrlAddWatch=="OK" && [.addwatch.entry get]!=""} {
			lappend ::WatchList [.addwatch.entry get]
			::ddt::Refresh
		}
		destroy .addwatch
	}
	
	proc RemoveWatch {WatchNbr} {
		set ::WatchList [lreplace $::WatchList $WatchNbr $WatchNbr]
		::ddt::Refresh
	}
	
	proc SwapBreakPoint {LineNbr} {
		global CurrentFileName
		if {[::ddt::GetBPLocations $CurrentFileName $LineNbr]=={}} return; # No breakpoint location
		if {[::ddt::SwapBP $CurrentFileName $LineNbr]} {
			.p.src.t tag add breakpoint $LineNbr.0 $LineNbr.1
		} else {
			.p.src.t tag remove breakpoint $LineNbr.0 $LineNbr.1
		}
		.p.src.t tag remove breakpoint_cond $LineNbr.0 $LineNbr.1
	}
	
	proc DefineBreakPoint {LineNbr} {
		global CurrentFileName
		if {[::ddt::GetBPLocations $CurrentFileName $LineNbr]=={}} return; # No breakpoint location
		set Condition [::ddt::GetBP $CurrentFileName $LineNbr]
		
		toplevel .bpdef
		grid [label .bpdef.cnd_l -text "Condition"] -row 0 -column 0
		grid [entry .bpdef.cnd_e] -row 0 -column 1 -sticky ew
			.bpdef.cnd_e insert 1 $Condition
		grid [frame .bpdef.control] -row 3 -column 0 -columnspan 2
		pack [button .bpdef.control.ok -text OK -command {set BpDefChoice OK}] -side left
		pack [button .bpdef.control.cancel -text Cancel -command {set BpDefChoice Cancel}] -side left
	
		set ::BpDefChoice ""
		vwait ::BpDefChoice
		if {$::BpDefChoice=="OK"} {
			set Condition [::ddt::SetBP $CurrentFileName $LineNbr [.bpdef.cnd_e get]]
	
			.p.src.t tag remove breakpoint $LineNbr.0 $LineNbr.1
			.p.src.t tag remove breakpoint_cond $LineNbr.0 $LineNbr.1
			if {$Condition=="1"} {
				.p.src.t tag add breakpoint $LineNbr.0 $LineNbr.1
			} elseif {$Condition!="" && $Condition!=0} {
				.p.src.t tag add breakpoint_cond $LineNbr.0 $LineNbr.1
			}
		}
		unset ::BpDefChoice
		destroy .bpdef
	}

#### Source code and debugging location display ####

	proc ShowSource {FileName {LineNbr ""}} {
		global CurrentFileName
	
		.p.src.t tag remove error 0.0 end
		.p.src.t tag remove current 0.0 end
		if {$FileName==$CurrentFileName} return
		
		set CurrentFileName $FileName
		set Script [::ddt::GetSource $FileName]
		regsub -line -all {^} $Script {  } Script
		#regsub -line -all {\t} $Script {   } Script
	
		.p.src.t delete 0.0 end;
		.p.src.t insert 0.0 $Script
	
		set NbrLines [regexp -all {\n} $Script]
		for {set LineNbr 1} {$LineNbr<=$NbrLines+1} {incr LineNbr} {
			if {[::ddt::GetBPLocations $CurrentFileName $LineNbr]!={}} {
				.p.src.t tag add border_bp $LineNbr.0 $LineNbr.1
			} else {
				.p.src.t tag add border $LineNbr.0 $LineNbr.1
			}
		}
		
		if {$LineNbr!=""} {
			update
			.p.src.t see $LineNbr.0
		}
	
		ShowIFile
	}
	
	proc Position {Status {FileName ""} {LineNbr ""} {ColNbr ""}} {
		global DisplayArray Config
		.p.st.t delete 0.0 end
		set Font [.p.st.t cget -font]
	
		if {$FileName=="" || $LineNbr==""} {
			if {$Status=="error"} {
				.p.st.t insert end "Error: $::errorInfo"
			} elseif {$Status=="ended"} {
				.p.st.t insert end "Done"
			}
			return
		}
	
		ShowSource $FileName $LineNbr
		
		foreach LNbr [::ddt::GetBP $FileName] {
			set LNbr [lindex $LNbr 0]
			.p.src.t tag add breakpoint $LNbr.0 $LNbr.1
		}
	
		.p.st.t insert end "    Status\n" section
		.p.st.t insert end "File: [file tail $FileName] (dir: [file dirname $FileName])\nLine:$LineNbr\n"
		if {$Status=="error"} {
			.p.src.t tag add error $LineNbr.0 "$LineNbr.0 lineend + 1 chars"
			.p.st.t insert end "Status: Error\nDetails: $::errorInfo\n"
			return
		} elseif {$Status=="break"} {
			if {$ColNbr} {
				incr ColNbr
			}
			.p.src.t tag add current "$LineNbr.$ColNbr + 1 chars" "$LineNbr.1 lineend + 1 chars"
			.p.src.t see $LineNbr.0
			.p.st.t insert end "Status: Break\n"
		} elseif {$Status=="ended"} {
			.p.st.t insert end "Status: Done"
			return
		}
	
		set RowNbr 0
	
		.p.st.t insert end "\n"
		.p.st.t insert end "    Watches\n" section
		set WatchNbr 0
		foreach Watch $::WatchList {
			incr RowNbr
			set BG $Config(VarRowBG,[expr {$RowNbr%2}])
			.p.st.t window create end -window [button .p.st.t.b$RowNbr -pady 0 -text "X" -command "RemoveWatch $WatchNbr"]
			.p.st.t window create end -window [entry .p.st.t.l$RowNbr -width 17 -bd 2 -font $Font -bg $BG]
			.p.st.t.l$RowNbr insert end $Watch
			.p.st.t window create end -window [entry .p.st.t.v$RowNbr -width 100 -bd 2 -font $Font -bg $BG]
			set ExprError [catch {::ddt::Eval expr $Watch} value]
			.p.st.t.v$RowNbr insert end $value
			if {$ExprError} {
				.p.st.t.v$RowNbr config -fg red
			}
			.p.st.t insert end "\n"
			incr WatchNbr
		}
	
		.p.st.t insert end "\n"
		.p.st.t insert end "    Variables\n" section
		foreach var [lsort -dictionary [::ddt::Eval info vars]] {
			if {[string index $var 0]=="."} continue; # Ignore variables created by Tk widgets
			if {![::ddt::Eval info exists $var]} continue
	
			incr RowNbr
			set BG $Config(VarRowBG,[expr {$RowNbr%2}])
			.p.st.t window create end -window [entry .p.st.t.l$RowNbr -width 20 -bd 2 -font $Font -bg $BG]
			.p.st.t.l$RowNbr insert end $var
			# .p.st.t.l$RowNbr config -state disable
			if {[::ddt::Eval array exists $var]} {
				set ArrSize [::ddt::Eval array size $var]
				.p.st.t insert end " Array size: $ArrSize"
				if {[info exists DisplayArray($var)]} {
					set ShowArray $DisplayArray($var)
				} else {
					set ShowArray [expr {$ArrSize<=5}]
				}
	
				button .p.st.t.b$RowNbr -pady 0 -text [expr $ShowArray?"Hide":"Show"] -command "set DisplayArray($var) [expr !$ShowArray]; ::ddt::Refresh"
				.p.st.t window create end -window .p.st.t.b$RowNbr
				.p.st.t insert end "\n"
	
				if {!$ShowArray} continue
	
				foreach {idx value} [::ddt::Eval array get $var] {
					incr RowNbr
					set BG $Config(VarRowBG,[expr {$RowNbr%2}])
					.p.st.t insert end "   "
					.p.st.t window create end -window [entry .p.st.t.l$RowNbr -width 17 -bd 2 -font $Font -bg $BG]
					.p.st.t.l$RowNbr insert end $idx
					# .p.st.t.l$RowNbr config -state disable
					.p.st.t window create end -window [entry .p.st.t.v$RowNbr -width 100 -bd 2 -font $Font -bg $BG]
					bind .p.st.t.v$RowNbr <KeyPress> "ModifyVariable %W"
					bind .p.st.t.v$RowNbr <Leave> "UpdateVariable %W ${var}($idx)"
					.p.st.t.v$RowNbr insert end $value
					.p.st.t insert end "\n"
				}
			} else {
				set val ?
				catch {set val [::ddt::Eval set $var]}
				.p.st.t window create end -window [entry .p.st.t.v$RowNbr -width 100 -bd 2 -font $Font -bg $BG]
				bind .p.st.t.v$RowNbr <KeyPress> "ModifyVariable %W"
				bind .p.st.t.v$RowNbr <Leave> "UpdateVariable %W $var"
				.p.st.t.v$RowNbr insert end $val
				.p.st.t insert end "\n"
			}
		}
	}
	
	set EditedWidget ""
	
	proc ModifyVariable {ValueWidget} {
		set ::EditedWidget $ValueWidget
	}
	
	proc UpdateVariable {ValueWidget var} {
		if {$ValueWidget==$::EditedWidget} {
			#puts "UpdateVariable $ValueWidget $var"
			set Value [$ValueWidget get]
			ddt::Exec set $var $Value
		}
		set ::EditedWidget ""
	}

#### Load and display files/instrumentalized files ####

	proc LoadFile {} {
		set types { {"TCL Scripts" .tcl} {"All Files" *} }
		set FileName [tk_getOpenFile -initialdir [pwd] -filetypes $types]
		if {$FileName==""} return
		
		::ddt::Instrumentalize $FileName
		ShowSource $FileName
		cd [file dirname $FileName]
	}
	
	proc ShowIFile { {Force 0} } {
		if {[winfo exists .ifile]} {
			.ifile.src.t delete 0.0 end
		} else {
			if {!$Force} return
			toplevel .ifile
			menu .ifile.menu -tearoff 0
			.ifile configure -menu .ifile.menu
			   .ifile.menu add cascade -label File -menu .ifile.menu.file
			      menu .ifile.menu.file -tearoff 0
			      .ifile.menu.file add command -label "Close" -command {destroy .ifile}
			pack [stext .ifile.src -wrap none] -expand yes -fill both
			.ifile.src.t config -tabs "[expr {$::TextCharWidth*3}] left" -tabstyle wordprocessor
		}
		
		if {$::CurrentFileName==""} return
		
		regsub -line -all {\t} $[::ddt::GetInstrumentalizedSource $::CurrentFileName] {   } IScript
		.ifile.src.t insert 0.0 $IScript
	}
	
	proc ShowFile {FileName} {
		::ddt::Instrumentalize $FileName
		ShowSource $FileName
	}

#### Miscellaneous ####

	proc UpdateFileListMenu {} {
		.menu.filelist delete 0 end
		foreach SourceFile $::ddt::SourceFiles {
			.menu.filelist add command -label $SourceFile -command "ShowFile \"$SourceFile\""
		}
	}
	
	proc Balloon {Cmd {RefW ""} {Text ""}} {
		catch {after cancel $::BalloonId}
		catch {destroy .balloon}
		switch -- $Cmd {
			trigger {
				set ::BalloonId [after 1000 "Balloon show $RefW \"$Text\""]
			}
			reset {
			}
			show {
				toplevel .balloon -bd 1 -bg black
				wm transient .balloon
				wm overrideredirect .balloon 1
				wm geometry .balloon "+[expr [winfo rootx $RefW]+[winfo width $RefW]/2]+[expr [winfo rooty $RefW]+[winfo height $RefW]/2]"
				pack [label .balloon.l -bg yellow -text $Text]
				set ::BalloonId [after 4000 "Balloon reset"]
			}
		}
	}
	
	proc DefInit {} {
		catch  {destroy destroy .idef}
		array set InitVars $::ddt::Config(-InitVars)
		set InitScript $::ddt::Config(-InitScript)
		toplevel .idef
		grid [label .idef.argv0_l -text "Argv0"] -row 0 -column 0
		grid [entry .idef.argv0_e] -row 0 -column 1 -sticky ew
			.idef.argv0_e insert 0 $InitVars(argv0)
		grid [label .idef.argv_l -text "Argv"] -row 1 -column 0
		grid [entry .idef.argv_e] -row 1 -column 1 -sticky ew
			.idef.argv_e insert 0 $InitVars(argv)
		grid [label .idef.script_l -text "Script"] -row 2 -column 0
		grid [text .idef.script_e -height 6 -width 40] -row 2 -column 1 -sticky news
			.idef.script_e insert 0.0 $InitScript
		grid [frame .idef.control] -row 3 -column 0 -columnspan 2
		pack [button .idef.control.ok -text OK -command {set DefInitChoice OK}] -side left
		pack [button .idef.control.cancel -text Cancel -command {set DefInitChoice Cancel}] -side left
	
		set ::DefInitChoice ""
		vwait ::DefInitChoice
		if {$::DefInitChoice=="OK"} {
			set ::ddt::Config(-InitVars) [list argv0 [.idef.argv0_e get] argv [.idef.argv_e get]]
			set ::ddt::Config(-InitScript) [.idef.script_e get 0.0 end]
		}
		unset ::DefInitChoice
		destroy .idef
	}
	
	ddt::Configure -BreakCallback ::Position
	ddt::Configure -InitVars {argv0 "" argv ""}
	
	proc stext {w args} {
		frame $w
	   grid [text $w.t -yscrollcommand "$w.scrolly set" -xscrollcommand "$w.scrollx set" {*}$args] -row 0 -column 0 -sticky news -padx 2 -pady 2
	   grid [scrollbar $w.scrolly -command "$w.t yview" -orient vertical] -row 0 -column 1 -sticky ns
	   grid [scrollbar $w.scrollx -command "$w.t xview" -orient horizontal] -row 1 -column 0 -sticky ew
	   grid rowconfigure $w 0 -weight 1
	   grid columnconfigure $w 0 -weight 1
		
		return $w
	}
	
	# Open the console (preferable tkcon, otherwise the Windows console if available)
	proc OpenConsole {} {
		global Config tcl_platform

		# Hide the standard console (only windows)
		catch {console hide}

		# Just Deiconify TkCon if it is already loaded
		if {[info exists ::tkcon::PRIV(root)]} {
			if {![catch {wm deiconify $::tkcon::PRIV(root)}]} return
		}

		# Evaluate the full path of TkCon
		set TkConPath $Config(Path,TkCon)
		regsub {^"(.*)"$} $Config(Path,TkCon) {\1} TkConPath; # Remove double quotes from the TkCon path:
		if {![file exists $TkConPath]} {
			catch {set TkConPath [exec csh -f -c {which tkcon.tcl}]}}
		if {![file exists $TkConPath]} {
			catch {set TkConPath [exec csh -f -c {which tkcon}]}}
		if {![file exists $TkConPath]} {
			catch {
				package require registry
			   set TkConPath [registry get {HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths\tclsh.exe} Path]/tkcon.tcl
			   regsub -all {\\} $TkConPath {/} TkConPath
			}
		}

		# Source and initialize TkCon if the executable exists
		if {[file exists $TkConPath]} { # TkCon is available
			# define PRIV(root) to an existing window to avoid a console creation
			namespace eval ::tkcon {
				set PRIV(root) .tkcon
				array set OPT {exec "" slaveexit "close"}
			}
			
			# Source tkcon. "Usually" this should also start the tkcon window.
			set ::argv ""
			uplevel #0 "source \"$TkConPath\""

			# TkCon versions have been observed that doesn't open the tkcon window during sourcing of tkcon. Initialize
			# tkcon explicitly:
			if {[lsearch [winfo children .] ".tkcon"]<0 && [lsearch [namespace children ::] "::tkcon"]} {
				::tkcon::Init
			}
			tkcon show

			# Save the used TkCon path inside the configuration array
			set Config(Path,TkCon) "\"$TkConPath\""
			return
		}
		
		# TkCon is not available, open the windows console if available
		set TkConPath "";  # TkCon couldn't be found, delete the currently configured path
		if {$tcl_platform(platform)=={windows}} { # The Tcl shell console can be displayed on Windows 
			console show
		} else {
			error "Cannot source tkcon.tcl. Please add the path to the environement variable \"PATH\""
		}
	}

	
#### Main GUI ####

	catch {destroy {*}[winfo children .]}
	
	pack [frame .cmd -padx 3] -expand no -fill x
	pack [panedwindow .p -handlesize 10 -sashrelief raised -sashwidth 3 -showhandle 1] -expand yes -fill both
	
	.p add [stext .p.src -wrap none] -stretch always -sticky news
		set TextCharWidth [font measure [.p.src.t cget -font] x]
		.p.src.t config -tabs [list [expr {$TextCharWidth*5}] left [expr {$TextCharWidth*8}] left] -tabstyle wordprocessor
	.p add [stext .p.st -width 40 -wrap none] -stretch always -sticky news
		.p.st.t config -tabs "[expr {$TextCharWidth*3}] left" -tabstyle wordprocessor
	
	bind .p.src.t <Double-3> {SwapBreakPoint [expr int([::tk::TextClosestGap %W %x %y])]}
	bind .p.src.t <Control-Double-3> {DefineBreakPoint [expr int([::tk::TextClosestGap %W %x %y])]}
	
	.p.src.t tag configure border -background gray
	.p.src.t tag configure border_bp -background skyblue
	.p.src.t tag configure error -background orange
	.p.src.t tag configure breakpoint -background blue
	.p.src.t tag configure breakpoint_cond -background blue4
	.p.src.t tag configure current -background red
	
	.p.st.t tag configure section -background gray30 -foreground white
	
	menu .menu -tearoff 0
	. configure -menu .menu
		.menu add cascade -label File -menu .menu.file
			menu .menu.file -tearoff 0
			.menu.file add command -label "Load" -command LoadFile
			.menu.file add command -label "Show instrumentalized file" -command "ShowIFile 1"
			.menu.file add command -label "Exit" -command Exit
		.menu add cascade -label "File list" -menu .menu.filelist
			menu .menu.filelist -tearoff 0 -postcommand UpdateFileListMenu
		.menu add cascade -label "Debug" -menu .menu.debug
			menu .menu.debug -tearoff 0
		.menu add cascade -label "Config" -menu .menu.config
			menu .menu.config -tearoff 0
			.menu.config add checkbutton -label "Use slave interpreter" -variable ::ddt::Config(-UseSI)
			.menu.config add command -label "Define initialization variables and script" -command ::DefInit
	
	foreach {Label Text Binding Command} {
		run       "Run/continue"         Key-F5 Run
		step      "Step"                 Key-F6 Step
		bp_toggle "Set/unset breakpoint" Key-F8 {SwapBreakPoint [expr int([.p.src.t index insert])]}
		bp_add    "Define  breakpoint"   Shift-Key-F8 {DefineBreakPoint [expr int([.p.src.t index insert])]}
		refresh   "Refresh"              Key-F9 Refresh
		stop      "Stop"                 Shift-Key-F5 Stop
		watch_add "Add watch"            F7 AddWatch
	} {
		image create photo $Label -file images/$Label.gif
		pack [button .cmd.$Label -image $Label -command $Command] -side left
		bind .cmd.$Label <Enter> "Balloon trigger .cmd.$Label \"$Text\""
		bind .cmd.$Label <Leave> "Balloon reset"
		bind . <$Binding> $Command
		.menu.debug add command -label "$Text ($Binding)" -command $Command
	}
	
	catch {wm geometry . $Config(Geometry,main)}
	catch {.mainpan sash place 0 {*}$Config(MainPan,sash_position)}
	wm protocol . WM_DELETE_WINDOW Exit
		
	OpenConsole
