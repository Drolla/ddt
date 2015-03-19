**DDT**, **Dynamic Debugging for Tcl***, provides dynamic debugging support for Tcl 8.5 or higher.  It provides mainly commands to run Tcl files or scripts and to step through them, to define breakpoints, and to access variables in the context of the debugged code.

DDT instrumentalizes the debugged code by inserting debugging helper commands.  This is transparent (=invisible) to the user except he checks the procedure bodies for example with ‘info body’. DDT uses the “unsupported” disassemble function of Tcl 8.5 and 8.6 to analyse the code to debug, to identify potential program execution stop locations.

A simple graphical Tcl debugger is also provided that demonstrates the way the DDT can be used.

![DDT debugger](https://github.com/Drolla/ddt/blob/master/developper/doc/ddt_debugger.gif)
