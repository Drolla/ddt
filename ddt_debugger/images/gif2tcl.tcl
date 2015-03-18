package require base64

set fTcl [open images.tcl w]
foreach GifFile [glob *.gif] {
	set fGif [open $GifFile r]
	fconfigure $fGif -encoding binary -translation binary
	set Data [read $fGif]
	close $fGif

	set DataBase64 [base64::encode -maxlen 150 -wrapchar "\n   " $Data]
	regexp {(\w+)\.*} $GifFile {} ImageName
	puts $fTcl "image create photo $ImageName -data \{\n   $DataBase64\}"
}
close $fTcl
exit