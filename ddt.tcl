##########################################################################
# DDT - Dynamic Debugging for Tcl
##########################################################################
# ddt.tcl - DDT's main package
# 
# DDT provides all the necessary functionalities to perform dynamic 
# debugging of Tcl programs.
#
# Copyright (C) 2014 Andreas Drollinger
##########################################################################
# See the file "license.terms" for information on usage and redistribution
# of this file, and for a DISCLAIMER OF ALL WARRANTIES.
##########################################################################

# Title: DDT - Dynamic Debugging for Tcl
# This package provides dynamic debugging support for Tcl 8.5 or higher. It 
# provides mainly commands to run Tcl files or scripts and to step through them, 
# to define breakpoints, and to access variables in the context of the debugged 
# code.
#
# DDT instrumentalizes the debugged code by inserting debugging helper 
# commands. This is transparent (=invisible) to the user except he checks the 
# procedure bodies for example with 'info body'. DDT uses the "unsupported"
# disassemble function of Tcl 8.5 and 8.6 to analyse the code to debug, to
# identify potential program execution stop locations.

# SubTitle: Dynamic Debugging for Tcl

# Footer: DDT - Dynamic Debugging for Tcl

# Create the ddt namespace.
namespace eval ::ddt {}

# This is the following DDT version:
variable ddt::version 0.1.0

# Specify the DDT version that is provided by this file:
package provide ddt $ddt::version

################ API ################

# Group: API
#    DDT exposes the following API commands.

	##########################
	# Proc: ddt::Configure
	#    Configure DDT, or return the current configuration. If no argument is
	#    provided the current configuration is returned. If a single argument 
	#    referring a configuration parameter is provided the configuration for
	#    this parameter is returned. Pairs of parameter names and values need 
	#    to be provided if a new configuration needs to be defined. The 
	#    available configurations are described in section <Configuration>.
	#
	# Parameters:
	#    [args] - Configuration definition list
	#
	# Returns:
	#    Returns the configuration if no new configuration is defined
	#    
	# Examples:
	#    > ddt::Configure -BreakCallback DebugGuiUpdate
	#    > ddt::Configure -InitVars {argv0 {} argv {}} -InitScript "package require Tk"
	#    > ddt::Configure -Mode disable
	#    
	# See also:
	#    <Configuration>
	##########################
	
	proc ddt::Configure {args} {
		variable Config
		switch -- [llength $args] {
			0       {return [array get Config]}
			1       {return $Config($args)}
			default {array set Config $args; return}
		}
	}
	
	
	##########################
	# Proc: ddt::Run
	#    Starts the execution of a file or of a script. If breakpoints are 
	#    defined the debug environment is initialized. If the configuration 
	#    *-SI* is set the file or script is executed by a slave interpreter that
	#    is created.
	#
	#    The two arguments allow using this command in 2 ways.
	#    * A file is provided but not a script: The file is executed.
	#    * A file and a script is provided. The script is executed. The file 
	#      name is just used as identifier.
	#
	# Parameters:
	#    FileName - File name (can also be a fictitious identifier)
	#    [Script] - If provided this script will be executed
	#
	# Returns:
	#    Result returned by the file/script
	#
	# See Also:
	#    <ddt::Cont>, <ddt::Step>, <ddt::Stop>, <ddt::SetBP>
	##########################

	proc ddt::Run {FileName {Script {}}} {
		variable ExecState
		variable Config
		variable BP
		variable SI

		# Check the current program execution state, and quit this procedure if 
		# an execution is ongoing.
		if {$ExecState!=""} return
	
		# Variable declaration and initialization
		variable SourceFiles
		variable SourceIScript
		variable ExecLineNbr -1
		set ExecState "cont"
		set ExecFile $FileName

		# No breakpoints are defined: Perform a normal execution of a script or 
		# a file (without providing debug support):
		if {[array size BP]==0 || $Config(-Mode)!="enable"} {
			# Initialize the run environment without debug support
			RunEnvironment_Init 0

			# Execute either the file or the script, either in the main 
			# interpreter or in a slave interpreter
			if {$SI=={} && $Script=={}} {
				set ResultCode [catch {uplevel #0 source \{$FileName\}} Result]
			} elseif {$SI=={} && $Script!={}} {
				set ResultCode [catch {uplevel #0 $Script} Result]
			} elseif {$SI!={} && $Script!={}} {
				set ResultCode [catch {interp eval $SI source \{$FileName\}} Result]
			} elseif {$SI!={} && $Script!={}} {
				set ResultCode [catch {interp eval $SI $Script} Result]
			}

		# Breakpoints are defined: Perform the execution of a script or a file in 
		# debug mode:
		} else {
			# Instrumentalize the file/script
			variable ExecSourceId [Instrumentalize $FileName $Script]
	
			# Initialize the run environment
			RunEnvironment_Init 1
			RunEnvironment_Resume
			interp eval $SI "set ::ddt::CurrentSourcedFile \"$FileName\""
			
			# Execute the instrumentalized script
			if {$SI=={}} {
				set ResultCode [catch {uplevel #0 $SourceIScript($ExecSourceId)} Result]
			} else {
				set ResultCode [catch {interp eval $SI $SourceIScript($ExecSourceId)} Result]
			}
			set ExecFile [lindex $SourceFiles $ExecSourceId]; # Recover the last executed file
		}

		# Destroy the run environment
		RunEnvironment_Distroy
	
		# Depending the execution result, call the call back command either with 
		# the 'error' or the 'ended' argument:
		if {$ResultCode && $ExecState!="stop"} {
			set ExecState ""
			#uplevel #0 $Config(-BreakCallback) error \{$ExecFile\} $ExecLineNbr
			eval $Config(-BreakCallback) error \{$ExecFile\} $ExecLineNbr
		} else {
			set ExecState ""
			#uplevel #0 $Config(-BreakCallback) ended \{$ExecFile\} $ExecLineNbr
			eval $Config(-BreakCallback) ended \{$ExecFile\} $ExecLineNbr
			set Result ""
		}
		return $Result
	}

	
	##########################
	# Proc: ddt::Cont
	#    Continues the execution of the program that is stopped on a breakpoint.
	#
	# Returns:
	#    Returns always the execution state 'cont'.
	#
	# See Also:
	#    <ddt::Run>, <ddt::Step>, <ddt::Stop>, <ddt::SetBP>
	##########################
	
	proc ddt::Cont {} {
		variable ExecState
		if {$ExecState==""} return
		set ExecState "cont"
	}
	
	
	##########################
	# Proc: ddt::Step
	#    Performs a single step in a program that is stopped on a breakpoint.
	#
	# Returns:
	#    Returns always the execution state 'step'.
	#
	# See Also:
	#    <ddt::Run>, <ddt::Cont>, <ddt::Stop>, <ddt::SetBP>
	##########################
	
	proc ddt::Step {} {
		variable ExecState
		if {$ExecState==""} return
		set ExecState "step"
	}
	
	
	##########################
	# Proc: ddt::Refresh
	#    Forces the callback function to be re-executed. A refresh of the 
	#    application UI's status can be forced in this way.
	#
	# Returns:
	#    Returns always the execution state 'refresh'.
	##########################
	
	proc ddt::Refresh {} {
		variable ExecState
		if {$ExecState==""} return
		set ExecState "refresh"
	}
	
	
	##########################
	# Proc: ddt::Stop
	#    Stops the execution of a program that is currently either running or 
	#    stopped on a breakpoint.
	#
	# Returns:
	#    Returns always the execution state 'stop'.
	#
	# See Also:
	#    <ddt::Run>, <ddt::Cont>, <ddt::Step>, <ddt::SetBP>
	##########################
	
	proc ddt::Stop {} {
		variable ExecState
		set ExecState "stop"
	}
	
	
	##########################
	# Proc: ddt::Eval
	#    Evaluates a command sequence in the context of the executed procedure 
	#    of  the debugged program. Returns the result of the command sequence.
	#    This command can be used by the callback function to inspect the status 
	#    of the debugged program or procedure. However, this command cannot be 
	#    used by functions that are interactively executed (e.g. via buttons).
	#
	# Parameters:
	#    args - Command sequence
	#
	# Returns:
	#    Result returned by the command sequence, or any error generated by it
	#
	# See Also:
	#    <ddt::Exec>
	##########################
	
	proc ddt::Eval {args} {
		variable SI
		
		# A slave interpreter is used: Evaluate the command sequence via 
		# 'interp eval'
		if {$SI!={}} {
			set Code [catch {interp eval $SI $args} Result]
		
		# No slave interpreter is used: Evaluate the stack level of a known 
		# command (e.g. ddt::Brk), and execute the command sequence a level 
		# below (witch is in the currently debugged program/procedure).
		# ToDo: Check also for ddt::Run
		} else {
			# Evaluate the level of the procedure that is currently debugged
			# Example:
			#   Level 0: ::ddt::Eval     ...   (this is this eval function)
			#   Level 1: ::Position break ...  (this is the callback function)
			#   Level 2: ::ddt::Brk 0 9 1 ...  (this is the Brk function that should be recognized)
			#   Level 3:  MyDebuggedFunction . (this is the function that is debugged)
			# Try just evaluating the command in level 3 if the break level cannot 
			# be found.
			set BrkLevel 2
			catch {
				for {set Bl 2} {1} {incr Bl} {
					if {[lindex [info level -$Bl] 0]=="::ddt::Brk"} {
						set BrkLevel Bl
					}
				}
			}
			set Code [catch {uplevel 3 $args} Result]
		}
		return -code $Code $Result
	}
	
	
	##########################
	# Proc: ddt::Exec
	#    Evaluates a command sequence in the context of the executed procedure 
	#    of  the debugged program. Returns always an empty string.
	#    This command can be used by the callback function as well as by a 
	#    function that is interactively executed (e.g. via buttons).
	#
	# Parameters:
	#    args - Command sequence
	#
	# Returns:
	#    -
	#
	# See Also:
	#    <ddt::Eval>
	##########################
	
	proc ddt::Exec {args} {
		variable SI
	
		# A slave interpreter is used: Evaluate the command sequence via 
		# 'interp eval'
		if {$SI!={}} {
			interp eval $SI $args
	
		# No slave interpreter is used: Force returning to the ddt::Brk procedure 
		# to execute the command sequence in the context of the debugged 
		# procedure/program.
		} else {
			# Define the code sequence, and set ExecState to 'exec': This will 
			# make ddt:Brk executing the code sequence.
			variable ExecCmd [concat {*}$args]
			variable ExecState "exec"
		}
		return
	}
	
	
	##########################
	# Proc: ddt::SetBP
	#    Set or delete a breakpoint in a specified file at a specified line. If 
	#    no condition is explicitly specified, or if the condition is 1, a non 
	#    conditional breakpoint is defined. If the condition is 0 or '' an  
	#    eventually defined breakpoint is deleted. The provided condition will 
	#    be used in all other cases as a dynamic breakpoint condition.
	#
	# Parameters:
	#    FileName - File to apply the breakpoint definitions
	#    LineNbr -  Line to which the breakpoint definition
	#    [Condition] - Optional condition
	#
	# Returns:
	#    Returns the new breakpoint condition
	#
	# See Also:
	#    <ddt::GetBP>, <ddt::SwapBP>
	##########################
	
	proc ddt::SetBP {FileName LineNbr {Condition 1}} {
		variable BP
		set SrcId [GetSourceId $FileName]
		
		# Delete an eventual breakpoint if the condition is 0 or '':
		if {$Condition=="0" || $Condition==""} {
			array unset BP $SrcId,$LineNbr
			return 0
	
		# Store otherwise the breakpoint condition (this includes also hard 
		# breakpoints):
		} else {
			set BP($SrcId,$LineNbr) $Condition
			return $Condition
		}
	}


	##########################
	# Proc: ddt::GetBP
	#    Returns for a specified file the breakpoint definitions. If no line is 
	#    specified GetBP returns for all breakpoint for the file, otherwise only
	#    the ones for the specified line. The returned breakpoint definitions 
	#    is a list composed by pairs of line numbers and breakpoint conditions.
	#
	# Parameters:
	#    FileName -  File for which the breakpoint definitions have to be
	#                returned
	#    [LineNbr] - If defined only the breakpoint definitions are returned
	#                only for this line
	#
	# Returns:
	#    Breakpoint definition list
	#
	# See Also:
	#    <ddt::SetBP>, <ddt::SwapBP>
	##########################
	
	proc ddt::GetBP {FileName {LineNbr ""}} {
		variable BP
		set SrcId [GetSourceId $FileName]
		
		# Line number is specified: Return 0 if no breakpoint is specified. 
		# Return the breakpoint condition otherwise.
		if {$LineNbr!=""} {
			if {[info exists BP($SrcId,$LineNbr)]} {
				return $BP($SrcId,$LineNbr)
			} else {
				return 0
			}
	
		# Line number is not specified: Return a list of line numbers/breakpoint
		# conditions for the specified file.
		} else {
			set LineNbrList {}
			foreach BpIdx [array names BP $SrcId,*] {
				regexp {,(\d+)$} $BpIdx {} LineNbr; # Extract the line number from the break point array index
				lappend LineNbrList [list $LineNbr $BP($BpIdx)]
			}
			return $LineNbrList
		}
	}
	
	
	##########################
	# Proc: ddt::SwapBP
	#    Swaps a breakpoint in a specified line of a specified file. If no
	#    breakpoint (conditional or non conditional) exists, a non conditional
	#    breakpoint will be created. Otherwise the existing breakpoint will be 
	#    deleted.
	#
	# Parameters:
	#    FileName - File for which the breakpoint definitions needs to be applied
	#    LineNbr -  Line for which the breakpoint definition needs to be applied
	#
	# Returns:
	#    Returns the new breakpoint condition
	#
	# See Also:
	#    <dt::GetBP>, <dt::SetBP>
	##########################
	
	proc ddt::SwapBP {FileName LineNbr} {
		SetBP $FileName $LineNbr [expr {[GetBP $FileName $LineNbr]=="0"}]
	}
	
	
	##########################
	# Proc: ddt::GetBPLocations
	#    Returns for a specified file the possible breakpoint locations. If a 
	#    line is specified GetBPLocations returns the breakpoint locations just 
	#    for this line.
	#
	# Parameters:
	#    FileName -  File for which the breakpoint locations have to be returned
	#    [LineNbr] - If defined: Line for which the breakpoint locations have to 
	#                be returned
	#
	# Returns:
	#    Breakpoint location list
	##########################
	
	proc ddt::GetBPLocations {FileName {LineNbr ""}} {
		variable BP
		set SrcId [GetSourceId $FileName]
		if {$LineNbr==""} {
			return $::ddt::CommandPosListRC($SrcId)
		} else {
			return [lsearch -all -inline -exact -integer -index 0 $::ddt::CommandPosListRC($SrcId) $LineNbr]
		}
	}
	
	
	##########################
	# Proc: ddt::GetExecState
	#    Returns the execution state of the currently debugged file or script. 
	#    The following states exist:
	#    * "" (initialization state)
	#    * cont (continuous running)
	#    * step (single instruction execution)
	#    * stop (stop request)
	#    * refresh (refresh request), 
	#    * exec (command sequence execution request)
	#    * stopped (state while the Brk instruction is executed)
	#
	# Returns:
	#    Returns the current execution state.
	##########################
	
	proc ddt::GetExecState {} {
		variable ExecState
		return $ExecState
	}
	
	
################ Configuration ################

# Group: Configuration
#    DDT is configured via the <ddt::Configure> command. The configuration is 
#    stored by DDT inside the *Config* array variable. DDT uses the following 
#    configurations:

	# Var: ddt::Config(-BreakCallback)
	#    Callback function configuration. Defines the callback function that 
	#    will be called each time the execution of the debugged program is 
	#    stopped.
	#    
	# Example:
	#    > ddt::Configure -BreakCallback DebugGuiUpdate

	set ddt::Config(-BreakCallback) ""

	# Var: ddt::Config(-UseSI)
	#    Slave interpreter setting. If set to 1 (default) a slave interpreter 
	#    will be used, if set to 0 the master interpreter will be used.
	#    
	# Example:
	#    > ddt::Configure -UseSI 1
	set ddt::Config(-UseSI) 1

	# Var: ddt::Config(-InitVars)
	#    Initialization variable definition. The variable initializations, defined 
	#    as pairs of variable names/values, will be executed in the context of 
	#    the debugged program prior to the program start.
	#    
	# Example:
	#    > ddt::Configure -InitVars {argv0 "" argv ""}
	set ddt::Config(-InitVars) {}

	# Var: ddt::Config(-InitScript)
	#    Initialization script. The defined script will be executed in the 
	#    context of the debugged program prior to the program start.
	#    
	# Example:
	#    > ddt::Configure -InitScript {}
	set ddt::Config(-InitScript) {}

	# Var: ddt::Config(-Mode)
	#    Enables/disables debugging. Valid settings are 'enable' (default), and 
	#    'disable'.
	#    
	# Example:
	#    > ddt::Configure -Mode enable
	set ddt::Config(-Mode) enable

################ Internal variables and commands ################

# Group: DDT internal variables
#    Here is some information about the internal variables.
#    The following array variables contain information about the 
#    instrumentalized source scripts and files. All of them are using the 
#    source identifier as array index.
#
#    DisassembleInfo  - Disassemble information of the source
#    SourceScript     - Source script
#    SourceIScript    - Instrumentalized source script
#    CommandPosListN  - List of character positions that correspond to a command 
#                       begin
#    CommandPosListRC - List of line/column positions that correspond to a 
#                       command begin
#
# Registered source files and breakpoints.
#
#    SourceFiles - Source file name list
#    BP          - Breakpoint array
#
#    The following variables contain information about the execution state of
#    the program being debugged.
#
#    ExecSourceId - Source identifier
#    ExecLineNbr - Currently executed line number
#    ExecState - Execution state (see <ddt::GetExecState>)


# Group: DDT internal commands
#    Internal commands used by DDT.

	##########################
	# Proc: ddt::Init
	#    Initializes, or re-initializes all variables used internally by DDT. 
	#    The source file list and the defined breakpoints will be kept unless
	#    a full initialization is performed.
	#
	# Parameters:
	#    [FullInit] - A full initialization will be performed if set to 1
	#
	# Returns:
	#    -
	#
	# See Also:
	#    <DDT internal variables>
	##########################
	
	proc ddt::Init { {FullInit 0} } {
		# Array variables containing information about the instrumentalized 
		# files. They will be deleted.
		foreach var {
			DisassembleInfo
			SourceScript SourceIScript CommandPosListN CommandPosListRC
		} {
			variable $var
			catch {unset $var}
		}
	
		# Variables defining the execution state of the debugged file
		variable ExecSourceId 0
		variable ExecLineNbr ""
		variable ExecState ""
		
		# The file indexes and defined breakpoints are only initialized when a 
		# full/first initialization is performed
		if {$FullInit} {
			variable SourceFiles {}
			catch {variable BP; unset BP}
		}
		return
	}
	
	# Perform the initial variable initialization
	ddt::Init 1
	
################ Source file handling ################
	
	##########################
	# Proc: ddt::GetSourceId
	#    Returns the source identifier for a file. The source identifier is an
	#    integer.
	#
	# Parameters:
	#    FileName - File name (can also be a fictitious identifier)
	#
	# Returns:
	#    Source identifier
	#
	# See Also:
	#    <ddt::GetSource>
	##########################
	
	proc ddt::GetSourceId {FileName} {
		variable SourceFiles
		if {[file exists $FileName]} {
			set FileName [file normalize $FileName]
		}
		set SrcId [lsearch -exact $SourceFiles $FileName]
		if {$SrcId<0} {
			set SrcId [llength $SourceFiles]
			lappend SourceFiles $FileName
		}
		return $SrcId
	}
	
	
	##########################
	# Proc: ddt::GetSource
	#    Returns the source (e.g. script) designated by the file name.
	#
	# Parameters:
	#    FileName - File name (can also be a fictitious identifier)
	#
	# Returns:
	#    Source script
	#
	# See Also:
	#    <ddt::GetSourceId>
	##########################

	proc ddt::GetSource {FileName} {
		variable SourceScript
		set SrcId [GetSourceId $FileName]
		return $SourceScript($SrcId)
	}
	
	
	##########################
	# Proc: ddt::GetInstrumentalizedSource
	#    Get the instrumentalized source script of a file or of a script. This 
	#    command can be used in 2 ways.
	#    * Just a file is provided but not a script: In this case the file  
	#      content is read, instrumentalized and returned.
	#    * A file and a script is provided. The provided script is  
	#      instrumentalized and returned in this case. The file name is used as 
	#      identifier to cache instrumentalized source script.
	#
	# Parameters:
	#    FileName - File name (can also be a fictitious identifier)
	#    [Script] - If provided this script will be instrumentalized
	#
	# Returns:
	#    Instrumentalized source script
	#
	# See Also:
	#    <ddt::Run>, <ddt::Instrumentalize>, <ddt::GetSourceId>,  <ddt::GetSource>
	##########################

	proc ddt::GetInstrumentalizedSource {FileName {Script {}}} {
		variable SourceIScript
		set SrcId [Instrumentalize $FileName $Script]
		return $SourceIScript($SrcId)
	}
	
################ Script source handling ################
	
	##########################
	# Proc: ddt::source_debug
	#    Tcl source command patch. This command instrumentalizes the sourced 
	#    files and execute them then in debug mode if the following conditions 
	#    are satisfied:
	#    * Currently executed code is part of the debugged program (not part of 
	#      the debug environment)
	#    * Sourced file is not sourced from a package
	#    * The source command is not called with the -encoding option
	#    * The sourced file is not pkgIndex.tcl
	#    If one of these conditions is not satisfied, source_debug will source 
	#    the file via the normal source command.
	#
	# Parameters:
	#    args - Arguments normally provided to *source*
	#
	# Returns:
	#    Return value normally provided by *source*
	#
	# See Also:
	#    <ddt::package_debug>, <ddt::info_debug>
	##########################
	
	proc ddt::source_debug {args} {
		# Get information about the current debugging state and about eventual 
		# packages sourced on a higher stack level. Store the previous sourced 
		# file.
		set ExecState [::ddt::GetExecState]
		set PastSourceFile $::ddt::CurrentSourcedFile
		set EvalResult ""
	
		# Source the file via the initial source command if one of the debug 
		# conditions is not satisfied
		if {$::ddt::PackageCommandIsExecuted || [llength $args]>1 ||
		    ($ExecState!="cont" && $ExecState!="step") || 
		    [file tail [lindex $args end]]=="pkgIndex.tcl"} {
			set ::ddt::CurrentSourcedFile ""; # With this definition the initial 'info script' will be used
			set EvalCode [catch {uplevel 1 [concat ::ddt::source_orig $args]} EvalResult]
		
		# Instrumentalize the script and execute this instrumentalized script if 
		# the specified debug conditions are satisfied
		} else {
			set ::ddt::CurrentSourcedFile [lindex $args end]
			set SourceIScript [::ddt::GetInstrumentalizedSource [lindex $args end]]
			set EvalCode [catch {uplevel 1 $SourceIScript} EvalResult]
		}
	
		# Restore the previous source file, and return the result from the 
		# original source command
		set ::ddt::CurrentSourcedFile $PastSourceFile
		return -code $EvalCode $EvalResult
	}
	
	
	##########################
	# Proc: ddt::package_debug
	#    Tcl package command patch. This command keeps track about packages that 
	#    are going to be loaded. This information is used by the patched source 
	#    command (<ddt::source_debug>) to disable the instrumentalization of 
	#    sourced files if they are sourced by the package command.
	#
	# Parameters:
	#    args - Arguments of the *package* command
	#
	# Returns:
	#    Return value of the *package* command
	#
	# See Also:
	#    <ddt::source_debug>, <ddt::info_debug>
	##########################
	
	proc ddt::package_debug {args} {
		incr ::ddt::PackageCommandIsExecuted
		set EvalResult ""
		set EvalCode [catch {uplevel 1 [concat ::ddt::package_orig $args]} EvalResult]
		incr ::ddt::PackageCommandIsExecuted -1
		return -code $EvalCode $EvalResult
	}
	
	
	##########################
	# Proc: ddt::info_debug
	#    Patches the info command. The 'info script' command doesn't work for 
	#    scripts that are sourced in debug mode (e.g. executed as 
	#    instrumentalized script). This patch corrects this behaviour.
	#
	# Parameters:
	#    args - Arguments to the *info* command
	#
	# Returns:
	#    Return value of the *info* command
	#
	# See Also:
	#    <ddt::source_debug>, <ddt::package_debug>
	##########################
	
	proc ddt::info_debug {args} {
		# Return the name of the currently executed instrumentalized script
		if {[lindex $args 0]=="script" && $::ddt::CurrentSourcedFile!=""} {
			set EvalResult $::ddt::CurrentSourcedFile
			set EvalCode 0
		# Execute the initial info command otherwise
		} else {
			set EvalCode [catch {uplevel 1 [concat ::ddt::info_orig $args]} EvalResult]
		}
		return -code $EvalCode $EvalResult
	}
	
################ Instrumentalizer ################
	
	##########################
	# Proc: ddt::BuildCommandPositionsCmdString
	#    Identifies the command positions in a command's last argument.
	#    *BuildCommandPositionsCmdString* extracts the scripts provided as 
	#    last arguments to a commands (ex 'proc', 'foreach' and 
	#    'namespace eval' and evaluates the position of the commands contained 
	#    inside the script. *BuildCommandPositionsCmdString* calls 
	#    *BuildCommandPositions* to get the command positions, after removing 
	#    the {} or "" that encloses the scripts.
	#
	# Parameters:
	#    CmdString - Command string that has as last argument a script
	#    SrcId - Source identifier of the script
	#    Offset - Position offset, used for the analysis of sub-scripts
	#
	# Returns:
	#    -
	#
	# See Also:
	#    <ddt::BuildCommandPositions>, <ddt::Instrumentalize>
	##########################
	
	proc ddt::BuildCommandPositionsCmdString {CmdString SrcId Offset} {
		# Extract the script inside the last argument of the command string. 
		# Ignore the command if cannot be handled by list commands
		if {[catch {set LastArg [lindex $CmdString end]}]} return

		# Extract the script collection ({} or "") and whitespaces around the 
		# script
		#         CmdString: '  proc a  { puts 1; puts 2 }     '
		#                           Lead/\____LastArg___/\Tail/
		
		# Don't instrumentalize the last argument's script if it is not embedded 
		# into {} or "".
		regexp {.\s*$} $CmdString Tail
		set RelOffset [expr [string length $CmdString]-\
			[string length $Tail]-[string length $LastArg]-1]
		set Lead [string index $CmdString $RelOffset]
		if {$Lead!="\{"} return; # Last argument is not starting with \{, don't instrumentalize this part
		
		# Call BuildCommandPositions to evaluate the script's command position. 
		# Provide the absolute offset of this script
		BuildCommandPositions $LastArg $SrcId [expr $Offset+$RelOffset+1]
		return
	}
	
	
	##########################
	# Proc: ddt::BuildCommandPositions
	#    Identifies the positions of the commands that are present in a script.
	#    These positions are stored inside the array variables *CommandPosListN*
	#    and *CommandPosListRC*.
	#    
	#    To identify the command position BuildCommandPositions uses the 
	#    outputs from Tcl's ::tcl::unsupported::disassemble command. This output
	#    is stored inside the array variable *DisassembleInfo*.
	#    
	#    BuildCommandPositions is recursively called for code sections that 
	#    are not byte compiled (e.g. proc, namespace, foreach). The optional
	#    argument *Offset* defines the offset position of the sub script inside
	#    the full script.
	# Parameters:
	#    Script - Script for which the command positions have to be analysed
	#    SrcId - Source identifier of the script
	#    [Offset] - Position offset, used for the analysis of sub-scripts
	#
	# Returns:
	#    -
	#
	# See Also:
	#    <ddt::BuildCommandPositionsCmdString>, <ddt::Instrumentalize>
	##########################
	
	proc ddt::BuildCommandPositions {Script SrcId {Offset 0}} {
		variable CommandPosListN
		variable CommandPosListRC
		variable DisassembleInfo
	
		# Initialize the command position variables and disassemble info variable
		# if BuildCommandPositions is called for the full script (e.g. offset=0)
		if {$Offset==0} {
			set CommandPosListN($SrcId) {}
			set CommandPosListRC($SrcId) {}
			set DisassembleInfo($SrcId) ""
		}
		
		# Replace line extensions by spaces, the character positions of the 
		# commands will not be changed in this way
		regsub -all {\\\n} $Script {  } CleanedScript;
	
		# Disassemble the script, and add this info to the disassemble info array:
		set DisAssScript [::tcl::unsupported::disassemble script $CleanedScript]
		append DisassembleInfo($SrcId) "$DisAssScript\n"
		append DisassembleInfo($SrcId) "[string repeat * 40]\n"
		
		# Parse the the command position inside the 'Commands' section.
		#    Commands 22:
		#         1: pc 0-5, src 0-8   	      2: pc 6-49, src 11-49
		#         3: pc 17-30, src 31-36   	   4: pc 31-37, src 41-47
		#         5: pc 50-85, src 52-73   	   6: pc 61-73, src 67-72
		#     Command 1: "set v 123"
		# Return if the script doesn't contain any commands (empty procedure, 
		# empty script).
		if {![regexp {\n\s*Commands \d+:(.*)\n\s*Command 1:} $DisAssScript {} CommandLocationMatches]} {
			return
		}
		
		# Extract from the command position string (e.g. 'src 31-36') the command
		# start and end positions.
		foreach {str p0 p1} [regexp -inline -all {, src (\d+)-(\d+)} $CommandLocationMatches] {
			lappend CommandLocations [list $p0 $p1]
		}
	
		# Loop through all positions, from the script end to the script begin.
		# If the command contains as argument a sub script that is not 
		# disassembled, call 'BuildCommandPositionsCmdString' that will handle this
		# sub script (by calling recursively again 'BuildCommandPositions').
		foreach Location [lsort -decreasing -integer -index 0 $CommandLocations] {
			# Extract the full command, including the arguments, inside the 
			# script, and extract further the command and the eventual sub command.
			set ScriptSnip [string range $CleanedScript [lindex $Location 0] [lindex $Location 1]]
			if {![regexp {^([^\s]+)\s*(\w*)} $ScriptSnip {} Command SubCommand]} {
				continue; # This should never happen. Let's just ignore this problem.
			}
			
			# Evaluate the absolute command start and end position (that includes 
			# the offset).
			set NewOrig [expr {$Offset+[lindex $Location 0]}]
			set NewEnd [expr {$Offset+[lindex $Location 1]}]

			# Check if the command uses as arguments scripts that are not handled
			# (in this run) by the disassembler. Handle this code section in this 
			# case via 'BuildCommandPositionsCmdString'. Otherwise, add the absolute
			# command positions ot the variable 'CommandPosListN'.
			if {$Command=="proc"} {
				BuildCommandPositionsCmdString $ScriptSnip $SrcId $NewOrig
			} elseif {$Command=="namespace" && $SubCommand=="eval"} {
				BuildCommandPositionsCmdString $ScriptSnip $SrcId $NewOrig
			} elseif {$Command=="dict" && $SubCommand=="for"} {
				BuildCommandPositionsCmdString $ScriptSnip $SrcId $NewOrig
			} elseif {$Command=="foreach"} {
				BuildCommandPositionsCmdString $ScriptSnip $SrcId $NewOrig
				lappend CommandPosListN($SrcId) [list $NewOrig $NewEnd]
			} else {
				lappend CommandPosListN($SrcId) [list $NewOrig $NewEnd]
			}
		}
		
		# Filter the command positions. This step will happen only on a script 
		# top level and will be skipped if a sub-script is processed (e.g. offset
		# not 0).
		# The filtering will retain only the positions of the main commands of a 
		# script, and remove the positions of sub commands (e.g. only the 
		# position for 'set' is retained, but not the position for 'expr').
		#    set Var [expr {$Var*2}]
	
		if {$Offset!=0} return
	
		# Order the command position list
		set CommandPosListN($SrcId) [lsort -increasing -integer -index 0 $CommandPosListN($SrcId)]
	
		# Evaluate the character positions of all line begins
		set LineBeginPosList [regexp -line -all -indices -inline {^} $Script]
		lappend LineBeginPosList [string length $Script]
		
		# Initialize the variables used for the filtering and row/col evaluation
		set LastCommandEndPos -1; # End position of the previous command
		set LineNbr 0; # Counts the processed lines
		set LineBeginPos 0; # Absolute position of the currently processed line
		set NextLineBeginPos [lindex $LineBeginPosList 1 0]; # .. and of the next line
		set CommandPosListRC2 {}; # Command position list (row/col info)
		set CommandPosListN2 {}; # Command position list (absolute char position)
		
		# Loop through the command positions, starting at the script end
		foreach CommandPos $CommandPosListN($SrcId) {
			set CommandEndPos [lindex $CommandPos 1]
			set CommandPos [lindex $CommandPos 0]
			
			# If the new command is in a new line, update the line start position
			while {$CommandPos>=$NextLineBeginPos} {
				set LineBeginPos $NextLineBeginPos
				incr LineNbr
				set NextLineBeginPos [lindex $LineBeginPosList $LineNbr+1 0]
			}
	
			# Skip the new command sequence if it is part of the last command (sub 
			# call) and if it starts not with "\{' or '\"'. The debug break 
			# command can not be inserted correctly into the code in this case.
			# Examples:
			# - if {$a>10} continue   -> if {$a>10} ::ddt::Brk; continue   : Wrong!
			# - if {$a>10} {continue} -> if {$a>10} {::ddt::Brk; continue} : OK
			if {$CommandPos<=$LastCommandEndPos} {
				set LastCommandSequenceBegin [expr {$CommandPos-1}]
				while {[string is space [string index $Script $LastCommandSequenceBegin]]} {
					incr LastCommandSequenceBegin -1
				}
				if {[string index $Script $LastCommandSequenceBegin]!="\{" &&
				    [string index $Script $LastCommandSequenceBegin]!="\""} continue
			}
	
			# Add the new position to the command position lists. The row/column
			# information can be calculated via the begin position of the current 
			# line
			lappend CommandPosListRC2 [list [expr {$LineNbr+1}] [expr {$CommandPos-$LineBeginPos}]]
			lappend CommandPosListN2 $CommandPos
			#set LastStopLine $LineNbr
			set LastCommandEndPos $CommandEndPos
		}
		
		set CommandPosListRC($SrcId) $CommandPosListRC2
		set CommandPosListN($SrcId) $CommandPosListN2
		return
	}


	##########################
	# Proc: ddt::Instrumentalize
	#    Instrumentalizes a file or a script. This command can be used in 2 ways.
	#    * Just a file is provided but not a script: In this case the file 
	#      content is read and instrumentalized.
	#    * A file and a script is provided. The provided script is 
	#      instrumentalized in this case and the file name is just used as identifier.
	#
	# Parameters:
	#    FileName - File name (can also be a fictitious identifier)
	#    [Script] - If provided this script will be instrumentalized
	#
	# Returns:
	#    File/script source identifier
	#
	# See Also:
	#    <GetInstrumentalizedSource>
	##########################
	
	proc ddt::Instrumentalize {FileName {Script {}}} {
		variable SourceScript
		variable SourceIScript
		variable CommandPosListN
		variable CommandPosListRC
		
		# Check if the file has already been instrumentalized. Don't perform a 
		# new instrumentalization if this is the case
		set SrcId [GetSourceId $FileName]
		if {[info exists SourceScript($SrcId)]} {
			return $SrcId
		}
		
		# Get the script from the file if no script is explicitly provided
		if {$Script=={}} {
			set f [open $FileName r]
			set Script [read $f]
			close $f
		}
		
		# Generate the command positions
		BuildCommandPositions $Script $SrcId 0
		
		# Patch the script: Insert break statements (::ddt::Brk) in front of 
		# each command. Perform this insertion starting from the script's end
		# to avoid that the non handled positions are affected by the inserted
		# breaks.
		set InstrScript $Script
		foreach CommandPos [lreverse $CommandPosListN($SrcId)] StopPos [lreverse $CommandPosListRC($SrcId)] {
			set PrgBegin [lindex $CommandPos 0]
			set PrgEnd [lindex $CommandPos 1]
			set LineNbr [lindex $StopPos 0]
			set ColNbr [lindex $StopPos 1]
			
			# Add an additional column parameter to ddt::Brk if the processed 
			# command is not the first one in the line.
			set ColInfo ""
			if {![string is space [string range $InstrScript $PrgBegin-$ColNbr $PrgBegin-1]]} {
				set ColInfo " $ColNbr"
			}
			
			# Insert the ddt::Brk statement
			set InstrScript [string replace $InstrScript $PrgBegin $PrgBegin "::ddt::Brk $SrcId ${LineNbr}${ColInfo}; [string index $InstrScript $PrgBegin]"]
		}
	
		# Update the script cache variables, and return the source identifier
		set SourceScript($SrcId) $Script
		set SourceIScript($SrcId) $InstrScript
		return $SrcId
	}
	
################ Debugging environment control ################
	
	##########################
	# Proc: ddt::RunEnvironment_Init
	#    Initializes the run environment for the slave program. If an execution 
	#    in a slave interpreter is required, this one is created. Then, the 
	#    initialization variables are defined and the initialization scripts 
	#    executed.
	#    If debugging is required, e.g. if break points are set, the patched 
	#    commands (source, package, info) are activated.
	#    If debugging is required and if the execution happens by a slave 
	#    interpreter the required set of debug commands are created in the ::ddt
	#    namespace of the slave interpreter.
	#
	# Parameters:
	#    [DebugSupport] - Indicates if debugging is required
	#
	# Returns:
	#    -
	#
	# See Also:
	#    <ddt::RunEnvironment_Stop>, <ddt::RunEnvironment_Resume>, <ddt::RunEnvironment_Distroy>
	##########################
	
	proc ddt::RunEnvironment_Init { {DebugSupport 0} } {
		variable Config
		variable SI
		
		# Delete an eventual still existing slave interpreter, and create a new 
		# one if the execution is made by a slave interpreter
		catch {interp delete $SI}
		if {$Config(-UseSI)} {
			set SI [interp create]
		} else {
			set SI ""
		}
		#interp debug $SI -frame 1

		# The following commands are already defined if multiple debugging runs 
		# happen in the main interpreter
		foreach Cmd {source package info} {
			if {[interp eval $SI info commands ::ddt::${Cmd}_orig]==""} {
				interp eval $SI rename ::$Cmd ::ddt::${Cmd}_orig
				interp eval $SI "interp alias {} ::$Cmd {} ::ddt::${Cmd}_orig"; # Point to the original command for the moment
			}
		}
		
		# Define the initialization variables and execute the initialization 
		# script
		foreach {VarName VarValue} $Config(-InitVars) {
			interp eval $SI set $VarName "\{$VarValue\}"
		}
		interp eval $SI $Config(-InitScript)
		
		# The initialization is completed if no debug support is required
		variable Enabled $DebugSupport
		if {!$Enabled} return
	
		# Create the ::ddt namespace (required if a slave interpreter is used), 
		# and initialize the required state variables in the ddt namespace.
		interp eval $SI {namespace eval ::ddt {}}
		interp eval $SI {set ::ddt::PackageCommandIsExecuted 0}; # Variable that tells if a package is executed
		interp eval $SI {set ::ddt::CurrentSourcedFile ""}; # Variable used to manage the files that are sourced during the execution of the debugged program
	
		# Define the required set of debug commands for a slave interpreter
		if {$Config(-UseSI)} {
			# Create the patched commands (source, packge, info) for the slave interpreter
			interp eval $SI "proc ::ddt::source_debug \{[info args source_debug]\} \{[info body source_debug]\}"
			interp eval $SI "proc ::ddt::package_debug \{[info args package_debug]\} \{[info body package_debug]\}"
			interp eval $SI "proc ::ddt::info_debug \{[info args info_debug]\} \{[info body info_debug]\}"
			interp eval $SI "proc ::ddt::Log \{[info args info_debug]\} \{[info body Log]\}"
	
			# Alias the other required debug commands to the slave interpreter. 
			# They will be executed in the context of the main interpreter.
			foreach Cmd {
				Brk GetInstrumentalizedSource GetExecState LogDirect
				RunEnvironment_Init RunEnvironment_Stop RunEnvironment_Resume RunEnvironment_Distroy
			} {
				interp alias $SI ::ddt::$Cmd {} ::ddt::$Cmd
			}
		}
	}
	
	
	##########################
	# Proc: ddt::RunEnvironment_Stop
	#    Switches the run environment into non-debugging mode
	#
	# Parameters:
	#    -
	#
	# Returns:
	#    -
	#
	# See Also:
	#    <ddt::RunEnvironment_Init>, <ddt::RunEnvironment_Resume>, <ddt::RunEnvironment_Distroy>
	##########################
	
	proc ddt::RunEnvironment_Stop {} {
		variable SI
		foreach Cmd {source package info} {
			interp eval $SI "interp alias {} ::$Cmd {} ::ddt::${Cmd}_orig"
		}
	}
	
	
	##########################
	# Proc: ddt::RunEnvironment_Resume
	#    Resumes the debugging mode of the run environment
	#
	# Parameters:
	#    -
	#
	# Returns:
	#    -
	#
	# See Also:
	#    <ddt::RunEnvironment_Init>, <ddt::RunEnvironment_Stop>, <ddt::RunEnvironment_Distroy>
	##########################
	
	proc ddt::RunEnvironment_Resume {} {
		variable SI
		foreach Cmd {source package info} {
			interp eval $SI "interp alias {} ::$Cmd {} ::ddt::${Cmd}_debug"
		}
	}
	
	
	##########################
	# Proc: ddt::RunEnvironment_Distroy
	#    Destroys the debugging run environment
	#
	# Parameters:
	#    -
	#
	# Returns:
	#    -
	#
	# See Also:
	#    <ddt::RunEnvironment_Init>, <ddt::RunEnvironment_Stop>, <ddt::RunEnvironment_Resume>
	##########################
	
	proc ddt::RunEnvironment_Distroy {} {
		RunEnvironment_Stop
		
		# Don't kill the slave interpreter. It's useful to be able to check its
		# state!
		# variable SI
		# catch {interp delete $SI}
	}
	
	
	##########################
	# Proc: ddt::Brk
	#    This procedure will be inserted in front of each command inside the 
	#    debugged source files and scripts. It will need to decide if a 
	#    continuously executed program needs to stop due to a breakpoint that 
	#    is set or because a program sequence is executed in single step mode.
	#    Brk will call an application specific callback function that allows 
	#    inspecting the status of the debugged program or procedure. By calling 
	#    the procedure Refresh, Brk will explicitly call this callback function. 
	#    By calling the procedure Exec, Brk will execute a command sequence in 
	#    the context of the debugged program/procedure.
	#
	# Parameters:
	#    SrcId - Source identifier of the script
	#    LineNbr - Line where this break command is inserted
	#    [ColNbr] - Optional column where this break command is inserted. Only 
	#               defined if not at the first location in the line.
	#
	# Returns:
	#    
	#
	# See Also:
	#    
	##########################
	
	proc ddt::Brk {SrcId LineNbr {ColNbr 0}} {
		# Part 1: Check if Brk don't need to stop the execution of the debugged 
		# program/procedure, because the program execution is continuously, and 
		# because no breakpoint is set at the current location.
		variable ExecState
		variable BP
		variable SI
		variable Enabled
	
		# Save the current debug location (file and line info)
		variable ExecSourceId $SrcId
		variable ExecLineNbr $LineNbr
		
		# Ignore this break command if debugging is disabled
		if {!$Enabled} return
	
		if {$ExecState=="cont"} {
			# Continue the execution if no breakpoint is set at the current location
			# Stop only on the first breakpoint location in a line (ignore 
			# additional breakpoints if commands are executed in continuous mode).
			if {$ColNbr || ![info exists BP($SrcId,$LineNbr)]} return;
	
			# Continue the execution if the breakpoint is disabled (0 or '').
			set BpCondition $BP($SrcId,$LineNbr)
			if {$BpCondition=="0" || $BpCondition==""} return
			
			# If the breakpoint definition is not '1' it defines a condition that 
			# needs to be evaluated. Evaluate this condition in the context of the
			# executed program/procedure, and continue the execution if the 
			# condition is not satisfied. Continue the execution also if the 
			# condition evaluation fails.
			if {$BpCondition!="1"} {
				if {$SI=={}} {
					set BpConditionResultCode [catch {uplevel 1 "expr $BpCondition"} BpConditionResult]
				} else {
					set BpConditionResultCode [catch {set BpConditionResult [interp eval $SI "expr $BpCondition"]}]
				}
				if {$BpConditionResultCode} return; # Condition evaluation failed
				if {$BpConditionResult!="" && $BpConditionResult!="1"} return; # Condition not satisfied
			}
		}
	
		# Brk will stop the execution of the debugged program/procedure.
		
		# Set the debug state to 'stopped'
		variable ExecState "stopped"
	
		# Switch the run environment from debug into normal mode
		RunEnvironment_Stop
	
		# Call the callback function
		variable Config
		if {$Config(-BreakCallback)!=""} {
			variable SourceFiles
			set ExecFile [lindex $SourceFiles $SrcId]
			#uplevel 1 $Config(-BreakCallback) break \{$ExecFile\} $LineNbr $ColNbr
			eval $Config(-BreakCallback) break \{$ExecFile\} $LineNbr $ColNbr
		}
	
		# Continue staying in this Brk procedure, unless the program execution is 
		# not resumed.
		while {1} {
			# Wait on an update of the execution state
			vwait ::ddt::ExecState
	
			# Handle the execution of command sequences (requested by Exec) and 
			# the refresh (explicit call of the callback function). Continue the
			# program execution if other execution states are requested.
			switch -- $ExecState {
				"exec" {
					variable ExecCmd
					catch {uplevel 1 $ExecCmd}}
				"refresh" {
					if {$Config(-BreakCallback)!=""} {
						# Call the callback function. ExecFile is already defined.
						#uplevel 1 $Config(-BreakCallback) break \{$ExecFile\} $LineNbr $ColNbr
						eval $Config(-BreakCallback) break \{$ExecFile\} $LineNbr $ColNbr
					} }
				default {
					break}
			}
		}
	
		# Generate an artificial error if debugging should be stopped.
		if {$ExecState=="stop"} {
			error "Execution stopped"
		}
	
		# Switch the run environment back into debug mode
		RunEnvironment_Resume
		return
	}
	
	
	##########################
	# Proc: ddt::Log
	#    Log the information provided as argument. This procedure is 
	#    implemented in the ddc namespace of the slave interpreter. It calls 
	#    LogDirect that will perform the log inside the main interpreter.
	#
	# Parameters:
	#    args - The list elements are concatenated
	#
	# Returns:
	#    -
	#
	# See Also:
	#    <ddt::LogDirect>
	##########################
	
	proc ddt::Log {args} {
		LogDirect [string repeat " " [info frame]] {*}$args
	}
	
	
	##########################
	# Proc: ddt::LogDirect
	#    Logs the information provided as argument in the context of the main 
	#    interpreter. LogDirect will be aliased from the main interpreter to 
	#    the slave interpreter.
	#
	# Parameters:
	#    args - The list elements are concatenated
	#
	# Returns:
	#    -
	#
	# See Also:
	#    <ddt::Log>
	##########################
	
	proc ddt::LogDirect {args} {
		puts [join $args " "]
	}
